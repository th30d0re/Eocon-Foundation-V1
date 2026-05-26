#!/usr/bin/env bash

# Phase 5: BuildAgent
# Orchestrates code generation via Cursor CLI with build verification loop
# Based on: Foundation-Constitution.tex Phase 5 (Execution)
#
# Workflow:
#   1. Gather context (plan/prompt + MD files + Swift docs)
#   2. Send to Cursor CLI for code generation
#   3. Run BuildLint.sh to verify
#   4. If errors, feed back to Cursor CLI (max 3 attempts)
#   5. On success: emit build.log | On failure: emit human_intervention.md
#
# Exit Codes:
#   0  - Success
#   10 - Build failed after max retries
#   11 - Misconfiguration
#   20 - Human intervention required

set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────────────────────────────────────

# Expand bare ~ in BUILDAGENT_USE_CWD (mirrors XcodeBuildMCP XCODEBUILDMCP_CWD fix)
BUILDAGENT_USE_CWD="${BUILDAGENT_USE_CWD/#\~/$HOME}"

# When script is in PATH, use current working directory as project root
# Otherwise, calculate from script location
if [ -n "${BUILDAGENT_USE_CWD:-}" ] || [ "${PWD}" != "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" ]; then
    # Script is likely in PATH, use current working directory
    PROJECT_ROOT="${PROJECT_ROOT:-$PWD}"
else
    # Script is run from its own directory, calculate relative path
    PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)}"
fi

# Resolve symlinks to get actual script directory (supports running via symlink in PATH)
SOURCE="${BASH_SOURCE[0]}"
while [ -L "$SOURCE" ]; do
    SCRIPT_DIR="$(cd "$(dirname "$SOURCE")" && pwd)"
    SOURCE="$(readlink "$SOURCE")"
    [[ $SOURCE != /* ]] && SOURCE="$SCRIPT_DIR/$SOURCE"
done
SCRIPT_DIR="$(cd "$(dirname "$SOURCE")" && pwd)"
WORK_DIR="$PWD"  # Current working directory where user invoked the command

# Find Foundation lib directory (check multiple locations)
find_foundation_lib() {
    local lib_locations=(
        "${FOUNDATION_LIB_PATH:-}"
        "${PROJECT_ROOT}/.Foundation/lib"
        "${PROJECT_ROOT}/.foundation/lib"
        "${WORK_DIR}/.Foundation/lib"
        "${WORK_DIR}/.Foundation/lib"
        "${HOME}/.foundation/lib"
        "/Users/emmanuel/Dev/Tools/Eocon-Foundation-V1/.Foundation/lib"
    )

    for loc in "${lib_locations[@]}"; do
        if [ -n "$loc" ] && [ -d "$loc" ]; then
            echo "$loc"
            return 0
        fi
    done
    return 1
}

FOUNDATION_LIB_DIR=$(find_foundation_lib) || FOUNDATION_LIB_DIR=""

# Load helper libraries
if [ -n "$FOUNDATION_LIB_DIR" ]; then
    HELPERS_LIB="${FOUNDATION_LIB_DIR}/helpers.sh"
    ERRORS_LIB="${FOUNDATION_LIB_DIR}/errors.sh"
    AI_PROVIDER_LIB="${FOUNDATION_LIB_DIR}/ai_provider.sh"
else
    HELPERS_LIB=""
    ERRORS_LIB=""
    AI_PROVIDER_LIB=""
fi

if [ -n "$HELPERS_LIB" ] && [ -f "$HELPERS_LIB" ]; then
    # shellcheck disable=SC1090
    source "$HELPERS_LIB"

    # Check shell compatibility
    if type check_shell_compatibility &>/dev/null; then
        check_shell_compatibility || exit 11
    fi
fi

if [ -n "$ERRORS_LIB" ] && [ -f "$ERRORS_LIB" ]; then
    # shellcheck disable=SC1090
    source "$ERRORS_LIB"
fi

# Build queue coordination library (prevents concurrent write/build conflicts)
BUILD_QUEUE_ENABLED="${BUILD_QUEUE_ENABLED:-true}"  # Set to false to disable coordination
BUILD_QUEUE_LIB=""
if [ -n "$FOUNDATION_LIB_DIR" ]; then
    BUILD_QUEUE_LIB="${FOUNDATION_LIB_DIR}/BuildQueue.sh"
fi

if [ -n "$BUILD_QUEUE_LIB" ] && [ -f "$BUILD_QUEUE_LIB" ] && [ "$BUILD_QUEUE_ENABLED" = "true" ]; then
    # shellcheck disable=SC1090
    source "$BUILD_QUEUE_LIB"
    BUILD_QUEUE_AVAILABLE=true
else
    BUILD_QUEUE_AVAILABLE=false
fi

# Load defaults configuration file (unless disabled)
LOAD_DEFAULTS="${LOAD_DEFAULTS:-true}"
PHASE5_DIR="${SCRIPT_DIR}"
DEFAULTS_CONF="${PHASE5_DIR}/defaults.conf"
if [ "$LOAD_DEFAULTS" = "true" ] && [ -f "$DEFAULTS_CONF" ]; then
    # shellcheck disable=SC1090,SC1091
    source "$DEFAULTS_CONF"
fi

# Load Phase 5 UI libraries (optional - graceful degradation if not available)
PHASE5_LIB_DIR="${SCRIPT_DIR}/lib"
if [ -f "${PHASE5_LIB_DIR}/ui_themes.sh" ]; then
    # shellcheck disable=SC1090
    source "${PHASE5_LIB_DIR}/ui_themes.sh"
fi
if [ -f "${PHASE5_LIB_DIR}/ui_components.sh" ]; then
    # shellcheck disable=SC1090
    source "${PHASE5_LIB_DIR}/ui_components.sh"
fi
if [ -f "${PHASE5_LIB_DIR}/witty_phrases.sh" ]; then
    # shellcheck disable=SC1090
    source "${PHASE5_LIB_DIR}/witty_phrases.sh"
fi
if [ -f "${PHASE5_LIB_DIR}/session_store.sh" ]; then
    # shellcheck disable=SC1090
    source "${PHASE5_LIB_DIR}/session_store.sh"
fi
if [ -f "${PHASE5_LIB_DIR}/platform.sh" ]; then
    # shellcheck disable=SC1090
    source "${PHASE5_LIB_DIR}/platform.sh"
fi

# Colors (fallback if helpers not loaded)
RED="${RED:-\033[0;31m}"
GREEN="${GREEN:-\033[0;32m}"
YELLOW="${YELLOW:-\033[1;33m}"
BLUE="${BLUE:-\033[0;34m}"
CYAN="${CYAN:-\033[0;36m}"
MAGENTA="${MAGENTA:-\033[0;35m}"
NC="${NC:-\033[0m}"

# BuildLint script
BUILD_LINT_SCRIPT="${SCRIPT_DIR}/BuildLint.sh"

# Default artifact output directory
ARTIFACTS_DIR="${ARTIFACTS_DIR:-${PROJECT_ROOT}/Artifacts}"
LOGS_DIR=""
STATUS_DIR=""
ARTIFACTS_RUN_DIR=""  # Root of the per-run artifact directory (parent of logs/ and status/)
BUILT_PRODUCTS_DIR_CAPTURED=""  # Populated after a successful build (read from built_products_dir.txt)

# Input configuration
PLAN_FILE=""
PROMPT_FILE=""
PROMPT_STRING=""
PROMPT_CONTENT=""  # Cached content (read immediately to avoid temp file deletion)
CONTEXT_PATHS=()
SWIFT_DOCS_PATH="${PROJECT_ROOT}/Docs/swiftDocs"

# Build configuration (passed to BuildLint.sh)
TARGET_ID=""
DESTINATION=""
SCHEME=""
BUILD_CONFIGURATION="${BUILD_CONFIGURATION:-Debug}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-}"
XCODE_WORKSPACE=""  # Auto-detected workspace path
XCODE_PROJECT=""    # Auto-detected project path

# Repair loop configuration
MAX_REPAIR_ATTEMPTS="${MAX_REPAIR_ATTEMPTS:-3}"
CURRENT_ATTEMPT=0
REPAIR_FROM_ERRORS_FILE=""  # Path to argent errors JSON file (set by --repair-from-errors)

# Session configuration (maintains context between attempts)
SESSION_ID=""
SESSION_FILE=""
CURSOR_CHAT_ID=""  # Cursor CLI chat session ID for --resume
AI_PROVIDER="${AI_PROVIDER:-copilot}"  # AI CLI provider: copilot, codex, cursor, claude, gemini
AI_CMD=""          # Detected AI CLI command
AI_MODEL="${AI_MODEL:-}"  # Specific AI model (provider-dependent)

# Flags
VERBOSE="${VERBOSE:-false}"
DRY_RUN="${DRY_RUN:-false}"
SKIP_LINT="${SKIP_LINT:-false}"
STREAM_OUTPUT="${STREAM_OUTPUT:-true}"
CURSOR_STREAM_SUPPORTED="false"
SKIP_CHAT_ID_CAPTURE="${SKIP_CHAT_ID_CAPTURE:-false}"  # Skip cursor chat ID capture (can be slow/unreliable)
YOLO_MODE="${YOLO_MODE:-false}"  # Automation mode: enables verbose, skip-chat-id, stream output
LINT_ONLY_MODE="${LINT_ONLY_MODE:-false}"  # No AI input - just run lint and build
SMART_DOCS="${SMART_DOCS:-true}"  # Use cursor-agent RAG to filter relevant swift docs

# Verbosity control
LOG_LEVEL="${LOG_LEVEL:-info}"  # error, warning, info, debug

# Multi-platform build configuration
PLATFORM=""  # Specific platform to build for (empty = auto-detect)
MULTI_PLATFORM_FAIL_FAST="${MULTI_PLATFORM_FAIL_FAST:-false}"  # Stop on first platform failure
AUTO_MULTI_PLATFORM="${AUTO_MULTI_PLATFORM:-true}"  # Auto-detect and build for all platforms
JSON_OUTPUT="${JSON_OUTPUT:-false}"  # Output results in JSON format
MCP_CALLER="${MCP_CALLER:-false}"  # Set by MCP server when calling BuildAgent

# UI configuration (can be overridden by environment or command-line)
BUILDAGENT_FANCY_UI="${BUILDAGENT_FANCY_UI:-true}"
BUILDAGENT_THEME="${BUILDAGENT_THEME:-dark}"
BUILDAGENT_SPINNER_STYLE="${BUILDAGENT_SPINNER_STYLE:-braille}"
BUILDAGENT_WITTY_PHRASES="${BUILDAGENT_WITTY_PHRASES:-true}"
BUILDAGENT_SHOW_TIPS="${BUILDAGENT_SHOW_TIPS:-true}"

# Letta Memory integration (set by BuildVerify.sh orchestrator)
LETTA_MEMORY_AGENT="${LETTA_MEMORY_AGENT:-}"  # Memory agent name
LETTA_MEMORY_SCRIPT="${LETTA_MEMORY_SCRIPT:-}"  # Path to letta_memory.py
LETTA_MEMORY_CONTEXT=""  # Retrieved memory context (populated at runtime)

# Spinner state
SPINNER_PID=""

# Unbuffering configuration (for streaming mode)
UNBUFFER_METHOD=""  # Detected at runtime: stdbuf, unbuffer, script, or none

# ─────────────────────────────────────────────────────────────────────────────
# Logging Functions
# ─────────────────────────────────────────────────────────────────────────────

log_info() {
    if [ "${BUILDAGENT_FANCY_UI:-false}" = "true" ] && type get_icon &>/dev/null && type get_color &>/dev/null; then
        local info_color
        info_color=$(get_color "info")
        local reset
        reset=$(get_color "reset")
        local icon
        icon=$(get_icon "info")
        echo -e "${info_color}${icon}${reset} $1" >&2
    else
        echo -e "${BLUE}[INFO]${NC} $1" >&2
    fi
}

log_success() {
    if [ "${BUILDAGENT_FANCY_UI:-false}" = "true" ] && type get_icon &>/dev/null && type get_color &>/dev/null; then
        local success_color
        success_color=$(get_color "success")
        local reset
        reset=$(get_color "reset")
        local icon
        icon=$(get_icon "success")
        echo -e "${success_color}${icon}${reset} $1" >&2
    else
        echo -e "${GREEN}[SUCCESS]${NC} $1" >&2
    fi
}

log_warning() {
    if [ "${BUILDAGENT_FANCY_UI:-false}" = "true" ] && type get_icon &>/dev/null && type get_color &>/dev/null; then
        local warning_color
        warning_color=$(get_color "warning")
        local reset
        reset=$(get_color "reset")
        local icon
        icon=$(get_icon "warning")
        echo -e "${warning_color}${icon}${reset} $1" >&2
    else
        echo -e "${YELLOW}[WARNING]${NC} $1" >&2
    fi
}

log_error() {
    if [ "${BUILDAGENT_FANCY_UI:-false}" = "true" ] && type get_icon &>/dev/null && type get_color &>/dev/null; then
        local error_color
        error_color=$(get_color "error")
        local reset
        reset=$(get_color "reset")
        local icon
        icon=$(get_icon "error")
        echo -e "${error_color}${icon}${reset} $1" >&2
    else
        echo -e "${RED}[ERROR]${NC} $1" >&2
    fi
}

log_section() {
    if [ "${BUILDAGENT_FANCY_UI:-false}" = "true" ] && type get_icon &>/dev/null && type get_color &>/dev/null; then
        local section_color
        section_color=$(get_color "section")
        local reset
        reset=$(get_color "reset")
        local icon
        icon=$(get_icon "section")
        echo -e "${section_color}${icon}${reset} $1" >&2
    else
        echo -e "${CYAN}[BUILD-AGENT]${NC} $1" >&2
    fi
}

log_attempt() {
    if [ "${BUILDAGENT_FANCY_UI:-false}" = "true" ] && type get_icon &>/dev/null && type get_color &>/dev/null; then
        local ai_color
        ai_color=$(get_color "ai")
        local reset
        reset=$(get_color "reset")
        local icon
        icon=$(get_icon "ai")
        echo -e "${ai_color}${icon} [${CURRENT_ATTEMPT}/${MAX_REPAIR_ATTEMPTS}]${reset} $1" >&2
    else
        echo -e "${MAGENTA}[ATTEMPT ${CURRENT_ATTEMPT}/${MAX_REPAIR_ATTEMPTS}]${NC} $1" >&2
    fi
}

log_verbose() {
    if [ "$VERBOSE" = "true" ]; then
        if [ "${BUILDAGENT_FANCY_UI:-false}" = "true" ] && type get_icon &>/dev/null && type get_color &>/dev/null; then
            local debug_color
            debug_color=$(get_color "debug")
            local reset
            reset=$(get_color "reset")
            local icon
            icon=$(get_icon "debug")
            echo -e "${debug_color}${icon}${reset} $1" >&2
        else
            echo -e "${CYAN}[VERBOSE]${NC} $1" >&2
        fi
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# JSON Output Functions (for MCP Integration)
# ─────────────────────────────────────────────────────────────────────────────

# Output structured JSON result for MCP server consumption
# Arguments:
#   $1 - success (true/false)
#   $2 - output message
#   $3 - error message (optional, "null" if not provided)
#   $4 - duration in ms (optional, 0 if not provided)
#   $5 - additional metadata JSON (optional)
#   $6 - nextSteps JSON array (optional, e.g. '["step 1","step 2"]')
output_json_result() {
    local success="$1"
    local output="$2"
    local error="${3:-null}"
    local duration="${4:-0}"
    local extra_metadata="${5:-{}}"
    local next_steps="${6:-[]}"

    if [ "$JSON_OUTPUT" != "true" ]; then
        return 0
    fi

    # Escape special characters for JSON
    output=$(echo "$output" | jq -Rs '.' 2>/dev/null | sed 's/^"//;s/"$//' || echo "$output")

    if [ "$error" != "null" ]; then
        error=$(echo "$error" | jq -Rs '.' 2>/dev/null | sed 's/^"//;s/"$//' || echo "$error")
    fi

    # Build metadata object
    local metadata
    if command -v jq &>/dev/null; then
        metadata=$(jq -n \
            --arg logs_dir "${LOGS_DIR:-}" \
            --arg status_dir "${STATUS_DIR:-}" \
            --argjson attempts "${CURRENT_ATTEMPT:-0}" \
            --arg scheme "${SCHEME:-}" \
            --arg platform "${PLATFORM:-}" \
            --arg configuration "${BUILD_CONFIGURATION:-}" \
            --argjson extra "$extra_metadata" \
            '{
                logsDir: $logs_dir,
                statusDir: $status_dir,
                attempts: $attempts,
                scheme: $scheme,
                platform: $platform,
                configuration: $configuration
            } + $extra')
    else
        metadata="{\"logsDir\":\"${LOGS_DIR:-}\",\"statusDir\":\"${STATUS_DIR:-}\",\"attempts\":${CURRENT_ATTEMPT:-0}}"
    fi

    # Output JSON result (schemaVersion 2 adds nextSteps for agent consumers)
    if command -v jq &>/dev/null; then
        jq -n \
            --argjson success "$success" \
            --arg output "$output" \
            --arg error "$error" \
            --argjson duration "$duration" \
            --argjson metadata "$metadata" \
            --argjson next_steps "$next_steps" \
            '{
                schemaVersion: 2,
                success: $success,
                output: $output,
                error: (if $error == "null" then null else $error end),
                duration: $duration,
                metadata: $metadata,
                exitCode: (if $success then 0 else 1 end),
                nextSteps: $next_steps
            }'
    else
        # Fallback without jq
        local error_json
        if [ "$error" = "null" ]; then
            error_json="null"
        else
            error_json="\"$error\""
        fi

        cat <<EOF
{
  "schemaVersion": 2,
  "success": $success,
  "output": "$output",
  "error": $error_json,
  "duration": $duration,
  "metadata": $metadata,
  "exitCode": $([ "$success" = "true" ] && echo 0 || echo 1),
  "nextSteps": $next_steps
}
EOF
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Build Queue Coordination Functions
# ─────────────────────────────────────────────────────────────────────────────

# Initialize build queue for this session
init_build_queue() {
    if [ "$BUILD_QUEUE_AVAILABLE" != "true" ]; then
        log_verbose "Build queue coordination disabled or unavailable"
        return 0
    fi

    # Initialize queue for this project
    bq_init "$WORK_DIR" "buildagent_${SESSION_ID}"
    log_info "Build queue initialized (coordination enabled)"

    # Start heartbeat to keep locks alive during long operations
    bq_start_heartbeat
}

# Acquire write lock (for code generation) - blocks until available
acquire_write_access() {
    if [ "$BUILD_QUEUE_AVAILABLE" != "true" ]; then
        return 0
    fi

    log_verbose "Acquiring write lock for code generation..."

    if ! bq_acquire_write_lock; then
        log_warning "Write lock not immediately available, waiting..."
        echo "" >&2
        log_info "Another BuildAgent instance is active. Waiting for access..."
        log_info "Queue status: $(bq_get_state)"

        # Start spinner while waiting
        start_spinner "Waiting for write access"

        if ! bq_wait_for_write; then
            stop_spinner
            log_error "Timeout waiting for write lock"
            return 1
        fi

        stop_spinner
        log_success "Write lock acquired after waiting"
    else
        log_verbose "Write lock acquired immediately"
    fi

    return 0
}

# Release write lock
release_write_access() {
    if [ "$BUILD_QUEUE_AVAILABLE" != "true" ]; then
        return 0
    fi

    bq_release_write_lock
    log_verbose "Write lock released"
}

# Acquire build lock (for compilation) - blocks until available
acquire_build_access() {
    if [ "$BUILD_QUEUE_AVAILABLE" != "true" ]; then
        return 0
    fi

    log_verbose "Acquiring build lock for compilation..."

    if ! bq_acquire_build_lock; then
        log_warning "Build lock not immediately available, waiting..."
        log_info "Another agent is modifying code. Waiting for stability..."

        start_spinner "Waiting for code changes to complete"

        if ! bq_wait_for_build; then
            stop_spinner
            log_error "Timeout waiting for build lock"
            return 1
        fi

        stop_spinner
        log_success "Build lock acquired after waiting"
    else
        log_verbose "Build lock acquired immediately"
    fi

    return 0
}

# Release build lock
release_build_access() {
    if [ "$BUILD_QUEUE_AVAILABLE" != "true" ]; then
        return 0
    fi

    bq_release_build_lock
    log_verbose "Build lock released"
}

# Check if we're blocked by another operation
check_queue_status() {
    if [ "$BUILD_QUEUE_AVAILABLE" != "true" ]; then
        return 1  # Not blocked (queue not available)
    fi

    if bq_is_blocked; then
        log_info "Build queue status: $(bq_get_state)"
        return 0  # Blocked
    fi

    return 1  # Not blocked
}

# ─────────────────────────────────────────────────────────────────────────────
# Spinner/Progress Functions
# ─────────────────────────────────────────────────────────────────────────────

# Spinner characters (braille pattern for smooth animation)
SPINNER_CHARS="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"

# Alternative spinner styles
SPINNER_DOTS="⣾⣽⣻⢿⡿⣟⣯⣷"
SPINNER_ARROWS="←↖↑↗→↘↓↙"
SPINNER_BOUNCE="⠁⠂⠄⠂"

# Current spinner message (for reference)
SPINNER_MESSAGE=""

# Start spinner with message - format: [WORKING] Message ⠹
start_spinner() {
    local message="$1"
    SPINNER_MESSAGE="$message"

    # Use enhanced spinner when fancy UI is enabled
    if [ "${BUILDAGENT_FANCY_UI:-false}" = "true" ] && type start_enhanced_spinner &>/dev/null; then
        start_enhanced_spinner "$message"
        return
    fi

    # Don't start spinner if not a TTY (but allow it in stream mode)
    if [ ! -t 2 ]; then
        echo -e "${CYAN}[WORKING]${NC} $message ..." >&2
        return
    fi

    # Kill any existing spinner
    stop_spinner 2>/dev/null || true

    # In stream mode, use a newline approach so spinner doesn't interfere with streamed output
    if [ "$STREAM_OUTPUT" = "true" ]; then
        # Start spinner on a new line that will be updated in place
        echo "" >&2  # Ensure we're on a new line
        (
            local i=0
            local spin_len=${#SPINNER_CHARS}
            local elapsed=0
            while true; do
                local char="${SPINNER_CHARS:$i:1}"
                # Format: [WORKING] Message ⠹ (Xs) - use \r to overwrite same line
                if [ $elapsed -ge 5 ]; then
                    printf "\r\033[K${CYAN}[WORKING]${NC} %s ${YELLOW}%s${NC} ${BLUE}(%ds)${NC}" "$message" "$char" "$elapsed" >&2
                else
                    printf "\r\033[K${CYAN}[WORKING]${NC} %s ${YELLOW}%s${NC}" "$message" "$char" >&2
                fi
                i=$(( (i + 1) % spin_len ))
                sleep 0.1
                # Update elapsed time every 10 iterations (1 second)
                if [ $(( (i + 1) % 10 )) -eq 0 ]; then
                    elapsed=$((elapsed + 1))
                fi
            done
        ) &
        SPINNER_PID=$!
        disown $SPINNER_PID 2>/dev/null || true
    else
        # Normal mode - spinner overwrites same line
        (
            local i=0
            local spin_len=${#SPINNER_CHARS}
            local elapsed=0
            while true; do
                local char="${SPINNER_CHARS:$i:1}"
                # Format: [WORKING] Message ⠹ (Xs)
                if [ $elapsed -ge 5 ]; then
                    printf "\r\033[K${CYAN}[WORKING]${NC} %s ${YELLOW}%s${NC} ${BLUE}(%ds)${NC}" "$message" "$char" "$elapsed" >&2
                else
                    printf "\r\033[K${CYAN}[WORKING]${NC} %s ${YELLOW}%s${NC}" "$message" "$char" >&2
                fi
                i=$(( (i + 1) % spin_len ))
                sleep 0.1
                # Update elapsed time every 10 iterations (1 second)
                if [ $(( (i + 1) % 10 )) -eq 0 ]; then
                    elapsed=$((elapsed + 1))
                fi
            done
        ) &
        SPINNER_PID=$!
        disown $SPINNER_PID 2>/dev/null || true
    fi
}

# Stop spinner with optional completion message
stop_spinner() {
    local completion_msg="${1:-}"

    # Use enhanced spinner stop when fancy UI is enabled
    if [ "${BUILDAGENT_FANCY_UI:-false}" = "true" ] && type stop_enhanced_spinner &>/dev/null; then
        stop_enhanced_spinner
        if [ -n "$completion_msg" ]; then
            echo -e "$completion_msg" >&2
        fi
        return
    fi

    if [ -n "$SPINNER_PID" ]; then
        kill $SPINNER_PID 2>/dev/null || true
        wait $SPINNER_PID 2>/dev/null || true
        SPINNER_PID=""
        # Clear the spinner line
        printf "\r\033[K" >&2

        # Show completion message if provided
        if [ -n "$completion_msg" ]; then
            echo -e "$completion_msg" >&2
        fi
    fi
}

# Stop spinner with success message
spinner_success() {
    local message="${1:-$SPINNER_MESSAGE}"

    # Use enhanced spinner done when fancy UI is enabled
    if [ "${BUILDAGENT_FANCY_UI:-false}" = "true" ] && type spinner_done &>/dev/null; then
        spinner_done "$message"
        return
    fi

    stop_spinner
    echo -e "${GREEN}[DONE]${NC} $message ${GREEN}✓${NC}" >&2
}

# Stop spinner with error message
spinner_error() {
    local message="${1:-$SPINNER_MESSAGE}"

    # Use enhanced spinner fail when fancy UI is enabled
    if [ "${BUILDAGENT_FANCY_UI:-false}" = "true" ] && type spinner_fail &>/dev/null; then
        spinner_fail "$message"
        return
    fi

    stop_spinner
    echo -e "${RED}[FAILED]${NC} $message ${RED}✗${NC}" >&2
}

# Update spinner message (stops and restarts with new message)
update_spinner() {
    local message="$1"
    stop_spinner
    start_spinner "$message"
}

# Cleanup on exit (spinner + build queue locks)
cleanup_all() {
    # Stop both legacy and enhanced spinners
    stop_spinner 2>/dev/null || true
    if [ "${BUILDAGENT_FANCY_UI:-false}" = "true" ] && type stop_enhanced_spinner &>/dev/null; then
        stop_enhanced_spinner 2>/dev/null || true
    fi
    # Release any held build queue locks
    if [ "$BUILD_QUEUE_AVAILABLE" = "true" ]; then
        bq_cleanup 2>/dev/null || true
    fi
}
trap cleanup_all EXIT INT TERM

# ─────────────────────────────────────────────────────────────────────────────
# Unbuffered Output Functions (for streaming mode)
# ─────────────────────────────────────────────────────────────────────────────

# Detect best available unbuffering method
detect_unbuffer_method() {
    if command -v stdbuf >/dev/null 2>&1; then
        echo "stdbuf"
    elif command -v unbuffer >/dev/null 2>&1; then
        echo "unbuffer"
    elif command -v script >/dev/null 2>&1; then
        echo "script"
    else
        echo "none"
    fi
}

# Run command with unbuffered output
run_unbuffered() {
    local cmd="$1"

    case "$UNBUFFER_METHOD" in
        stdbuf)
            # Line-buffered mode (best performance, most compatible)
            stdbuf -oL -eL bash -c "$cmd"
            ;;
        unbuffer)
            # expect's unbuffer (may not preserve exit codes well)
            unbuffer bash -c "$cmd"
            ;;
        script)
            # BSD/macOS script command (more portable but can be verbose)
            # -q flag suppresses start/done messages
            script -q /dev/null bash -c "$cmd"
            ;;
        none)
            # No unbuffering available - run normally (may be buffered)
            bash -c "$cmd"
            ;;
    esac
}

# Unbuffer tee specifically (tee adds its own buffering layer)
unbuffered_tee() {
    local output_file="$1"

    case "$UNBUFFER_METHOD" in
        stdbuf)
            stdbuf -oL -eL tee "$output_file"
            ;;
        script)
            # script with tee (less ideal but works)
            script -q /dev/null tee "$output_file"
            ;;
        *)
            # Fallback: use regular tee (may be buffered)
            tee "$output_file"
            ;;
    esac
}

# ─────────────────────────────────────────────────────────────────────────────
# Letta Memory Functions
# ─────────────────────────────────────────────────────────────────────────────

# Check if Letta memory is available
letta_memory_available() {
    [ -n "$LETTA_MEMORY_AGENT" ] && [ -n "$LETTA_MEMORY_SCRIPT" ] && [ -f "$LETTA_MEMORY_SCRIPT" ]
}

# Retrieve memory context for build
retrieve_memory_context() {
    if ! letta_memory_available; then
        return 0
    fi

    log_verbose "Retrieving memory context from Letta..."

    # Search for relevant error patterns and learnings
    local search_result
    search_result=$(python3 "$LETTA_MEMORY_SCRIPT" search \
        --agent "$LETTA_MEMORY_AGENT" \
        --query "error patterns solutions Swift SwiftUI build" 2>/dev/null || echo "")

    if [ -n "$search_result" ] && [ "$search_result" != "[]" ]; then
        LETTA_MEMORY_CONTEXT="
=== LEARNED PATTERNS FROM PREVIOUS SESSIONS ===
The following patterns and solutions were learned from previous build sessions:

$search_result

Use these patterns to avoid repeating past mistakes.
=== END LEARNED PATTERNS ===
"
        log_info "Retrieved memory context from previous sessions"
    fi
}

# Store build result to memory
store_build_result() {
    local status="$1"  # success or failure
    local error_info="${2:-}"

    if ! letta_memory_available; then
        return 0
    fi

    log_verbose "Storing build result to memory: $status"

    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    if [ "$status" = "success" ]; then
        local data
        data=$(cat << EOF
{
    "status": "success",
    "session_id": "$SESSION_ID",
    "scheme": "${DETECTED_SCHEME:-unknown}",
    "attempts": $CURRENT_ATTEMPT,
    "ai_provider": "$AI_PROVIDER",
    "timestamp": "$timestamp"
}
EOF
)
        python3 "$LETTA_MEMORY_SCRIPT" store \
            --agent "$LETTA_MEMORY_AGENT" \
            --block "success_patterns" \
            --data "$data" >/dev/null 2>&1 || true

        # Also remember the successful approach for implicit learning
        python3 "$LETTA_MEMORY_SCRIPT" remember \
            --agent "$LETTA_MEMORY_AGENT" \
            --content "Build succeeded for scheme ${DETECTED_SCHEME:-unknown} after $CURRENT_ATTEMPT attempts using $AI_PROVIDER" >/dev/null 2>&1 || true
    else
        local data
        data=$(cat << EOF
{
    "status": "failure",
    "session_id": "$SESSION_ID",
    "scheme": "${DETECTED_SCHEME:-unknown}",
    "attempts": $CURRENT_ATTEMPT,
    "max_attempts": $MAX_REPAIR_ATTEMPTS,
    "ai_provider": "$AI_PROVIDER",
    "error_summary": "${error_info:0:500}",
    "timestamp": "$timestamp"
}
EOF
)
        python3 "$LETTA_MEMORY_SCRIPT" store \
            --agent "$LETTA_MEMORY_AGENT" \
            --block "error_patterns" \
            --data "$data" >/dev/null 2>&1 || true
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Usage
# ─────────────────────────────────────────────────────────────────────────────

show_usage() {
    # Show logo if fancy UI is enabled
    if [ "${BUILDAGENT_FANCY_UI:-false}" = "true" ] && type show_logo &>/dev/null; then
        show_logo "auto" >&2
        echo "" >&2
    fi

    cat << EOF
Phase 5: BuildAgent - AI-Powered Code Generation & Build Verification

DESCRIPTION:
    BuildAgent orchestrates AI-powered code generation with automatic build
    verification and repair loops. Supports multiple AI providers with auto-
    detection of project configuration.

    PROJECT ROOT:
    When script is in PATH, it uses your current working directory (PWD) as
    the project root. You can override with: export PROJECT_ROOT=/path/to/project

USAGE:
    $0 [OPTIONS]

INPUT OPTIONS (optional - if none provided, runs lint/build only):
    --plan <file.md>        Path to plan markdown file
    --prompt <file.txt>     Path to prompt text file
    --prompt-string <str>   Prompt string directly (or use stdin)
    --stdin                 Read prompt from stdin

    If no input is provided, BuildAgent runs in auto-detect mode:
    - First runs lint/build to check for errors
    - If build passes: exits successfully (no AI needed)
    - If build fails: uses the errors as AI input and starts repair loop

CONTEXT OPTIONS:
    --context <path>        MD file or directory with MD files (can be repeated)
    --swift-docs <path>     Path to Swift documentation (auto-detected if not provided)
    --no-swift-docs         Skip Swift docs context (disables auto-detection)
    --no-smart-docs         Disable smart docs filtering (include all docs instead of RAG-selected)

    Smart docs filtering (enabled by default):
      Automatically selects only relevant Swift docs for the task, dramatically
      reducing context size. Uses cascading fallback:
        1. cursor-agent RAG (if available)
        2. claude CLI (if available)
        3. Keyword-based filtering (extracts types/frameworks from errors)
        4. All docs (final fallback)

    Auto-detection and auto-update:
      • Primary: /Users/emmanuel/Dev/Tools/Eocon-Foundation-V1/.Foundation/Docs/swiftDocs
        - Auto-clones from https://github.com/th30d0re/swiftDocs.git if missing
        - Auto-updates on each run (checks for new commits)
      • Fallback search locations:
        - Docs/swiftDocs, docs/swiftDocs
        - Documentation/swiftDocs, documentation/swiftDocs
        - .foundation/docs/swiftDocs, .Foundation/docs/swiftDocs
        - And more...

AI PROVIDER OPTIONS:
    --ai-provider <name>    AI CLI provider to use (default: cursor)

                            Supported providers:
                              cursor  - Cursor AI (default)
                              claude  - Anthropic Claude
                              codex   - OpenAI Codex
                              gemini  - Google Gemini
                              aider   - Aider AI pair programming
                              letta   - Letta stateful agents (persistent memory)
                              copilot - GitHub Copilot CLI

                            Auto-installation:
                              If a provider is not installed, the script will
                              attempt to install it automatically!
                              - Letta: via npm (requires Node.js 18+)
                              - Copilot: via npm (@githubnext/github-copilot-cli)
                              - Others: via Cursor AI assistance

                            Auto-approval flags (for unattended operation):
                              copilot → --allow-all-tools --allow-all-paths
                              cursor  → --force
                              claude  → --dangerously-skip-permissions
                              codex   → --full-auto
                              gemini  → --yolo
                              aider   → --yes
                              letta   → --yolo

    --ai-model <model>      Specific AI model to use (provider-dependent)
                            Example: --ai-model gemini-2.0-pro
                            For Letta: set LETTA_MODEL env var instead

BUILD OPTIONS:
    --target-id <id>        Device/Simulator UDID (e.g., 00008150-001D5822210A401C)
    --destination <dest>    Full destination string (overrides --target-id)
                            Example: "platform=iOS Simulator,name=iPhone 16"
    --scheme <scheme>       Xcode scheme to build (auto-detected if not provided)
                            Auto-detection searches for .xcworkspace or .xcodeproj
    --configuration <cfg>   Build configuration (default: Debug)
    --derived-data <path>   Custom DerivedData/build folder path
                            Auto-detects: phase5/Build folder if exists
    --skip-lint             Skip SwiftLint checks

EXECUTION OPTIONS:
    --max-attempts <n>      Max repair attempts (default: 3)
    --artifacts-dir <dir>   Artifacts output directory
    --stream                Stream AI CLI output in real-time
    --yolo                  Automation mode: max-attempts=5, verbose, skip-chat-id, streaming
    --skip-chat-id          Skip cursor chat ID capture (faster, but no session resume)
    --dry-run               Show what would be done without executing
    --verbose               Enable verbose output
    --no-defaults           Skip loading defaults.conf (for testing)
    --fancy-ui              Enable fancy terminal UI (colors, icons, progress bars)
    --no-fancy-ui           Disable fancy UI (plain text, CI/CD friendly)
    --help                  Show this help message

SESSION MANAGEMENT:
    --session-show          Display current session defaults
    --session-clear <key>   Clear a specific session default (e.g., scheme, platform)
    --session-clear-all     Clear all session defaults

    Session defaults are saved in .foundation-session.json and automatically
    applied when flags are not provided. After using a flag 3+ times in 7 days,
    you'll be prompted to save it as a default.

EXIT CODES:
    0   Success
    10  Build failed after max retries
    11  Misconfiguration
    20  Human intervention required

OUTPUTS:
    logs/build.log              - Build success log
    logs/error.log              - Error details (on failure)
    logs/coder.log              - AI CLI output
    status/success.txt          - On successful completion
    status/human_intervention.md - When human help needed

AUTHENTICATION:
    Each AI provider requires authentication. If you see an authentication
    error, the script will provide provider-specific setup instructions.

    Quick setup:
      cursor:  Already authenticated if Cursor IDE is logged in
      claude:  export ANTHROPIC_API_KEY=sk-ant-...
      codex:   export OPENAI_API_KEY=sk-...
      gemini:  export GOOGLE_API_KEY=...
      aider:   export OPENAI_API_KEY=... or ANTHROPIC_API_KEY=...
      letta:   export LETTA_API_KEY=letta-...
               Optional: export LETTA_BASE_URL=http://localhost:8283 (self-hosted)
      copilot: Uses GitHub authentication (gh auth login)

ENVIRONMENT VARIABLES:
    PROJECT_ROOT            Override project root directory (default: $PWD)
    BUILDAGENT_USE_CWD      Force use of current working directory
    BUILD_CONFIGURATION     Default build configuration (default: Debug)
    MAX_REPAIR_ATTEMPTS     Default max repair attempts (default: 3)
    AI_PROVIDER             Default AI provider (default: copilot)

    UI CUSTOMIZATION:
    BUILDAGENT_FANCY_UI     Enable fancy terminal UI (default: true)
    BUILDAGENT_THEME        Color theme: dark or light (default: dark)
    BUILDAGENT_SPINNER_STYLE Spinner style: braille, dots, arrows, bounce, etc. (default: braille)
    BUILDAGENT_WITTY_PHRASES Show witty loading phrases (default: true)
    BUILDAGENT_SHOW_TIPS    Show helpful tips on startup (default: true)

EXAMPLES:

    ┌─────────────────────────────────────────────────────────────────────┐
    │ Basic Usage (Auto-Detection)                                        │
    └─────────────────────────────────────────────────────────────────────┘

    # Lint/build only - no AI, just verify the build
    $0
    BuildAgent.sh  # When in PATH

    # Minimal - auto-detects scheme, Swift docs, uses Cursor
    $0 --plan Plans/plan1/plan1.md

    # When script is in PATH, run from your project directory
    cd /path/to/your/project
    BuildAgent.sh --plan plan.md

    # Explicitly specify scheme (overrides auto-detection)
    $0 --plan Plans/plan1/plan1.md --scheme MyApp

    ┌─────────────────────────────────────────────────────────────────────┐
    │ Different AI Providers                                               │
    └─────────────────────────────────────────────────────────────────────┘

    # Use Claude (automatically adds --dangerously-skip-permissions)
    $0 --plan plan.md --ai-provider claude

    # Use Gemini with specific model (automatically adds --yolo)
    $0 --plan plan.md --ai-provider gemini --ai-model gemini-2.0-pro

    # Use Codex (automatically adds --full-auto)
    $0 --plan plan.md --ai-provider codex

    # Use Letta (stateful agent with persistent memory)
    $0 --plan plan.md --ai-provider letta

    # Use Letta with specific model
    LETTA_MODEL=sonnet-4.5 $0 --plan plan.md --ai-provider letta

    # Use Letta with self-hosted instance
    LETTA_BASE_URL=http://localhost:8283 $0 --plan plan.md --ai-provider letta

    ┌─────────────────────────────────────────────────────────────────────┐
    │ Build Configuration                                                  │
    └─────────────────────────────────────────────────────────────────────┘

    # Custom build folder
    $0 --plan plan.md --derived-data ./CustomBuild

    # Physical device with Release build
    $0 --plan plan.md --target-id 00008150-001D5822210A401C --configuration Release

    # Simulator with specific destination
    $0 --plan plan.md --destination "platform=iOS Simulator,name=iPhone 16"

    ┌─────────────────────────────────────────────────────────────────────┐
    │ Input Methods                                                        │
    └─────────────────────────────────────────────────────────────────────┘

    # From prompt string
    $0 --prompt-string "Add a login button" --context Guides/

    # From stdin
    echo "Fix the bug in AuthManager" | $0 --stdin

    # With additional context files
    $0 --plan plan.md --context Docs/ --context Guidelines/

    ┌─────────────────────────────────────────────────────────────────────┐
    │ UI Customization                                                     │
    └─────────────────────────────────────────────────────────────────────┘

    # Enable fancy UI with custom theme
    $0 --plan plan.md --fancy-ui
    BUILDAGENT_THEME=light $0 --plan plan.md

    # Disable fancy UI for CI/CD (plain text output)
    $0 --plan plan.md --no-fancy-ui

    # Custom spinner style
    BUILDAGENT_SPINNER_STYLE=dots $0 --plan plan.md

    # Quiet mode (disables fancy UI automatically)
    $0 --plan plan.md --quiet

    ┌─────────────────────────────────────────────────────────────────────┐
    │ Automation & CI/CD                                                   │
    └─────────────────────────────────────────────────────────────────────┘

    # YOLO mode - 10 retries, verbose, streaming (zero user interaction)
    $0 --plan plan.md --ai-provider claude --yolo

    # Custom retry count with automation
    $0 --plan plan.md --max-attempts 20 --yolo

    # Stream output in real-time (good for CI/CD logs)
    $0 --plan plan.md --stream --verbose

NOTES:
    • Auto-detection is non-fatal; falls back gracefully if nothing found
    • Auto-approval flags enable unattended operation (use in trusted environments)
    • Missing AI providers will be auto-installed using Cursor (if available)
    • All options can be combined as needed
    • Exit codes are designed for CI/CD integration

For more information, see: .Foundation/docs/BuildAgent.md
EOF
}

# ─────────────────────────────────────────────────────────────────────────────
# Setup Functions
# ─────────────────────────────────────────────────────────────────────────────

setup_directories() {
    start_spinner "Setting up artifacts directory"

    local run_id
    run_id="$(date +%Y%m%d_%H%M%S)"
    local run_dir="${ARTIFACTS_DIR}/build_${run_id}"

    LOGS_DIR="${run_dir}/logs"
    STATUS_DIR="${run_dir}/status"
    ARTIFACTS_RUN_DIR="${run_dir}"

    if ! mkdir -p "$LOGS_DIR"; then
        spinner_error "Setting up artifacts directory"
        log_error "Failed to create logs directory: $LOGS_DIR"
        exit 11
    fi

    if ! mkdir -p "$STATUS_DIR"; then
        spinner_error "Setting up artifacts directory"
        log_error "Failed to create status directory: $STATUS_DIR"
        exit 11
    fi

    # Create session ID for maintaining context across attempts
    SESSION_ID="build_session_${run_id}"
    SESSION_FILE="${LOGS_DIR}/session_context.md"

    spinner_success "Setting up artifacts directory"

    log_verbose "Run directory: $run_dir"
    log_verbose "Logs directory: $LOGS_DIR"
    log_verbose "Status directory: $STATUS_DIR"
    log_verbose "Artifacts run directory: $ARTIFACTS_RUN_DIR"
    log_verbose "Session ID: $SESSION_ID"
    log_verbose "AI CLI Command: $AI_CMD"
}

# Validate that a user-supplied identifier contains only safe characters.
# Prevents shell injection / predicate injection for scheme names, build
# configurations, and bundle IDs that are interpolated into commands.
validate_identifier() {
    local value="$1"
    local label="${2:-identifier}"
    if [ -z "$value" ]; then
        return 0
    fi
    if [[ ! "$value" =~ ^[a-zA-Z0-9._\ \-]+$ ]]; then
        log_error "$label contains invalid characters: '$value'"
        return 1
    fi
    return 0
}

validate_inputs() {
    # IMMEDIATELY cache prompt/plan content before any slow operations
    # Traycer deletes temp files after 30 seconds, so read them NOW
    if [ -n "$PROMPT_FILE" ] && [ -f "$PROMPT_FILE" ] && [ -z "$PROMPT_CONTENT" ]; then
        PROMPT_CONTENT=$(cat "$PROMPT_FILE" 2>/dev/null || true)
        log_verbose "Cached prompt content (${#PROMPT_CONTENT} chars)"
    elif [ -n "$PLAN_FILE" ] && [ -f "$PLAN_FILE" ] && [ -z "$PROMPT_CONTENT" ]; then
        PROMPT_CONTENT=$(cat "$PLAN_FILE" 2>/dev/null || true)
        log_verbose "Cached plan content (${#PROMPT_CONTENT} chars)"
    elif [ -n "$PROMPT_STRING" ] && [ -z "$PROMPT_CONTENT" ]; then
        PROMPT_CONTENT="$PROMPT_STRING"
    fi

    start_spinner "Validating configuration"

    # Check if any input is provided - if not, run in lint-only mode
    # REPAIR_FROM_ERRORS_FILE is AI-driven even though it carries no prompt text
    if [ -z "$PLAN_FILE" ] && [ -z "$PROMPT_FILE" ] && [ -z "$PROMPT_STRING" ] && [ -z "$PROMPT_CONTENT" ] && [ -z "$REPAIR_FROM_ERRORS_FILE" ]; then
        LINT_ONLY_MODE="true"
        log_info "No AI input provided - running in auto-detect mode (build first, AI repair if needed)"
    fi

    # Explicitly force AI-driven mode for --repair-from-errors
    if [ -n "$REPAIR_FROM_ERRORS_FILE" ]; then
        LINT_ONLY_MODE="false"
        log_verbose "Repair-from-errors mode: AI provider required"
    fi

    # Validate plan file if provided (skip if already cached)
    if [ -n "$PLAN_FILE" ] && [ -z "$PROMPT_CONTENT" ] && [ ! -f "$PLAN_FILE" ]; then
        spinner_error "Validating configuration"
        log_error "Plan file not found: $PLAN_FILE"
        return 1
    fi

    # Validate prompt file if provided (skip if already cached)
    if [ -n "$PROMPT_FILE" ] && [ -z "$PROMPT_CONTENT" ] && [ ! -f "$PROMPT_FILE" ]; then
        spinner_error "Validating configuration"
        log_error "Prompt file not found: $PROMPT_FILE"
        return 1
    fi

    # Validate context paths
    if [ ${#CONTEXT_PATHS[@]} -gt 0 ]; then
        for ctx_path in "${CONTEXT_PATHS[@]}"; do
            if [ ! -e "$ctx_path" ]; then
                log_warning "Context path not found: $ctx_path"
            fi
        done
    fi

    # Auto-detect Swift docs if not disabled
    if [ -z "$SWIFT_DOCS_PATH" ] || [ "$SWIFT_DOCS_PATH" != "DISABLED" ]; then
        detect_swift_docs || true  # Non-fatal if not found
    fi

    # Auto-detect Xcode project/workspace (always run, even if scheme is provided)
    detect_xcode_project_path || true  # Non-fatal if not found

    # Auto-scope DerivedData per workspace/project when not explicitly set.
    # Mirrors XcodeBuildMCP's workspace-scoped DerivedData behaviour (v2.5.0) so
    # parallel multi-project builds don't clobber each other's output folders.
    if [ -z "$DERIVED_DATA_PATH" ]; then
        local _scope_input="${XCODE_WORKSPACE:-${XCODE_PROJECT:-}}"
        if [ -n "$_scope_input" ]; then
            local _scope_hash
            _scope_hash=$(printf '%s' "$_scope_input" | md5 2>/dev/null || printf '%s' "$_scope_input" | md5sum 2>/dev/null | cut -c1-8)
            _scope_hash="${_scope_hash:0:8}"
            DERIVED_DATA_PATH="${WORK_DIR}/.derived-data-${_scope_hash}"
            log_verbose "Auto-scoped DerivedData: $DERIVED_DATA_PATH"
        fi
    fi

    # Check/initialize git repository
    ensure_git_repo || true  # Non-fatal if initialization fails

    # Auto-detect scheme if not provided
    if [ -z "$SCHEME" ]; then
        if ! detect_scheme; then
            log_warning "Could not auto-detect scheme. Build may require --scheme parameter."
        fi
    fi

    # Validate user-supplied identifiers to block shell/predicate injection
    if ! validate_identifier "${SCHEME:-}" "Scheme"; then
        spinner_error "Validating configuration"
        return 1
    fi
    if ! validate_identifier "${BUILD_CONFIGURATION:-}" "Build configuration"; then
        spinner_error "Validating configuration"
        return 1
    fi

    # Check BuildLint.sh exists
    if [ ! -x "$BUILD_LINT_SCRIPT" ]; then
        spinner_error "Validating configuration"
        log_error "BuildLint.sh not found or not executable: $BUILD_LINT_SCRIPT"
        return 1
    fi

    # Detect and configure AI provider (skip in lint-only mode)
    if [ "$LINT_ONLY_MODE" = "false" ]; then
        if ! detect_ai_provider; then
            spinner_error "Validating configuration"
            log_error "AI provider detection failed; no provider available for the requested operation"
            return 11
        fi
    fi

    # Detect unbuffering method for streaming mode
    UNBUFFER_METHOD=$(detect_unbuffer_method)

    # Log streaming configuration if enabled
    if [ "$STREAM_OUTPUT" = "true" ]; then
        log_verbose "Streaming mode enabled"
        log_verbose "Unbuffering method: $UNBUFFER_METHOD"

        if [ "$UNBUFFER_METHOD" = "none" ]; then
            log_warning "No unbuffering tool available (stdbuf/unbuffer/script)"
            log_warning "Output may appear delayed or buffered"
        fi

        # Log provider streaming capability
        case "$AI_PROVIDER" in
            cursor)
                if [ "$AI_CMD" = "cursor-agent" ]; then
                    if [ "$CURSOR_STREAM_SUPPORTED" = "true" ]; then
                        log_verbose "Using cursor-agent native --stream flag"
                    else
                        log_warning "cursor-agent --stream not supported; falling back to standard output"
                    fi
                fi
                ;;
            letta)
                log_verbose "Using letta --output-format stream-json"
                ;;
            codex)
                log_verbose "Using codex with line-buffered output"
                ;;
            copilot|github-copilot)
                log_verbose "Using GitHub Copilot with line-buffered output"
                ;;
            *)
                log_verbose "Provider streaming via shell unbuffering (no native support)"
                ;;
        esac
    fi

    spinner_success "Validating configuration"
    return 0
}

# ─────────────────────────────────────────────────────────────────────────────
# Auto-detection Functions
# ─────────────────────────────────────────────────────────────────────────────

# Ensure swiftDocs is cloned and up-to-date in Foundation directory
# Clones from https://github.com/th30d0re/swiftDocs.git if missing
# Checks for updates and pulls if available
ensure_swift_docs_repo() {
    local foundation_swift_docs="/Users/emmanuel/Dev/Tools/Eocon-Foundation-V1/.Foundation/Docs/swiftDocs"
    local swift_docs_repo="https://github.com/th30d0re/swiftDocs.git"
    
    # Check if git is available
    if ! command -v git >/dev/null 2>&1; then
        log_verbose "Git not available, skipping swiftDocs repo management"
        return 0
    fi
    
    # Create parent directory if needed
    local parent_dir="$(dirname "$foundation_swift_docs")"
    if [ ! -d "$parent_dir" ]; then
        log_verbose "Creating docs directory: $parent_dir"
        mkdir -p "$parent_dir" 2>/dev/null || true
    fi
    
    # Check if directory exists and is a git repo
    if [ -d "$foundation_swift_docs" ]; then
        if [ -d "$foundation_swift_docs/.git" ]; then
            # Check the remote URL
            local current_remote
            current_remote=$(cd "$foundation_swift_docs" 2>/dev/null && git remote get-url origin 2>/dev/null || echo "")
            
            if [ -n "$current_remote" ]; then
                # Check if it's the expected repo (handle both https and git URLs)
                if echo "$current_remote" | grep -q "th30d0re/swiftDocs"; then
                    log_verbose "Checking for swiftDocs updates..."
                    (
                        cd "$foundation_swift_docs" 2>/dev/null || exit 0
                        
                        # Fetch updates quietly
                        if git fetch origin --quiet 2>/dev/null; then
                            # Check if we're behind
                            local local_commit=$(git rev-parse HEAD 2>/dev/null)
                            local remote_commit=$(git rev-parse origin/main 2>/dev/null || git rev-parse origin/master 2>/dev/null)
                            
                            if [ -n "$local_commit" ] && [ -n "$remote_commit" ] && [ "$local_commit" != "$remote_commit" ]; then
                                log_info "Updating swiftDocs from repository..."
                                if git pull --quiet 2>/dev/null; then
                                    log_success "swiftDocs updated successfully"
                                else
                                    log_verbose "Could not update swiftDocs (continuing with current version)"
                                fi
                            else
                                log_verbose "swiftDocs is up to date"
                            fi
                        fi
                    )
                else
                    # Different repo - just use it as-is
                    log_verbose "swiftDocs exists from different repo: $current_remote (using as-is)"
                fi
            else
                log_verbose "swiftDocs directory is a git repo without origin (using as-is)"
            fi
        else
            # Directory exists but is not a git repo - check if it's empty
            if [ -z "$(ls -A "$foundation_swift_docs" 2>/dev/null)" ]; then
                log_info "Cloning swiftDocs repository..."
                if git clone --quiet "$swift_docs_repo" "$foundation_swift_docs" 2>/dev/null; then
                    log_success "swiftDocs cloned successfully"
                else
                    log_warning "Failed to clone swiftDocs repository"
                fi
            else
                log_verbose "swiftDocs directory exists but is not a git repo (using as-is)"
            fi
        fi
    else
        # Directory doesn't exist - clone it
        log_info "Cloning swiftDocs repository..."
        if git clone --quiet "$swift_docs_repo" "$foundation_swift_docs" 2>/dev/null; then
            log_success "swiftDocs cloned to: $foundation_swift_docs"
        else
            log_warning "Failed to clone swiftDocs repository"
        fi
    fi
    
    return 0
}

# Auto-detect Swift documentation path
# Searches up to 5 levels deep for swiftDocs directories, excludes dependency folders,
# and prioritizes the main project's docs (shortest path)
detect_swift_docs() {
    # First, ensure Foundation swiftDocs repo is available and updated
    ensure_swift_docs_repo
    
    if [ -n "$SWIFT_DOCS_PATH" ] && [ -d "$SWIFT_DOCS_PATH" ]; then
        log_verbose "Using provided Swift docs path: $SWIFT_DOCS_PATH"
        return 0
    fi

    log_verbose "Searching for Swift documentation..."

    local docs_path=""
    local search_dirs=("$WORK_DIR")

    # Also search PROJECT_ROOT if different from WORK_DIR
    if [ "$WORK_DIR" != "$PROJECT_ROOT" ]; then
        search_dirs+=("$PROJECT_ROOT")
    fi

    # Search each directory for swiftDocs
    for search_dir in "${search_dirs[@]}"; do
        if [ -n "$docs_path" ]; then
            break
        fi

        # Find directories named "swiftDocs" or "SwiftDocs", excluding dependency folders
        # Sort by path length (shortest first = main project)
        local found_paths
        found_paths=$(find "$search_dir" -maxdepth 5 -type d \( -name "swiftDocs" -o -name "SwiftDocs" \) \
            -not -path "*/.build/*" \
            -not -path "*/Pods/*" \
            -not -path "*/Carthage/*" \
            -not -path "*/checkouts/*" \
            -not -path "*/DerivedData/*" \
            -not -path "*/Build/*" \
            -not -path "*/Ref/*" \
            -not -path "*/Reference/*" \
            -not -path "*/.planning/*" \
            2>/dev/null | \
            awk '{ print length, $0 }' | \
            sort -n | \
            cut -d' ' -f2-) || true

        # Check each found path for .md files, use first valid one
        while IFS= read -r path; do
            if [ -n "$path" ] && [ -d "$path" ]; then
                # Check if at least one .md file exists (use -print -quit to avoid pipefail issues)
                local first_md
                first_md=$(find "$path" -maxdepth 2 -name "*.md" -type f -print -quit 2>/dev/null) || true
                if [ -n "$first_md" ]; then
                    docs_path="$path"
                    break
                fi
            fi
        done <<< "$found_paths"
    done

    # Also check .Foundation directories explicitly (hidden dirs might be missed by main search)
    if [ -z "$docs_path" ]; then
        local foundation_paths=(
            "/Users/emmanuel/Dev/Tools/Eocon-Foundation-V1/.Foundation/Docs/swiftDocs"
            "${WORK_DIR}/.Foundation/Docs/swiftDocs"
            "${WORK_DIR}/.Foundation/.Foundation/Docs/swiftDocs"
            "${WORK_DIR}/.foundation/docs/swiftDocs"
            "${PROJECT_ROOT}/.Foundation/Docs/swiftDocs"
            "${PROJECT_ROOT}/.Foundation/.Foundation/Docs/swiftDocs"
            "${PROJECT_ROOT}/.foundation/docs/swiftDocs"
        )
        for fpath in "${foundation_paths[@]}"; do
            if [ -d "$fpath" ]; then
                local first_md
                first_md=$(find "$fpath" -maxdepth 2 -name "*.md" -type f -print -quit 2>/dev/null) || true
                if [ -n "$first_md" ]; then
                    docs_path="$fpath"
                    break
                fi
            fi
        done
    fi

    if [ -n "$docs_path" ]; then
        SWIFT_DOCS_PATH="$docs_path"
        log_info "Auto-detected Swift docs: $SWIFT_DOCS_PATH"
        return 0
    fi

    log_verbose "No Swift documentation found, continuing without docs context"
    SWIFT_DOCS_PATH=""
    return 1
}

# Auto-detect Xcode project/workspace path (separate from scheme detection)
# Searches up to 5 levels deep, excludes dependency directories, and prioritizes
# the "main" project (shortest path, not in build/dependency folders)
detect_xcode_project_path() {
    log_verbose "Searching for Xcode project/workspace..."

    # Common directories to exclude (dependencies, caches, etc.)
    local exclude_patterns=(
        "*/.*"                    # Hidden directories
        "*/.build/*"              # Swift Package Manager build
        "*/Pods/*"                # CocoaPods
        "*/Carthage/*"            # Carthage
        "*/checkouts/*"           # SPM checkouts
        "*/DerivedData/*"         # Xcode derived data
        "*/Build/*"               # Build folders
        "*/Docs/*"                # Documentation
        "*/docs/*"                # Documentation (lowercase)
        "*/Reference/*"           # Reference projects
        "*/Ref/*"                 # Reference projects (short)
        "*/Examples/*"            # Example projects
        "*/Samples/*"             # Sample projects
    )

    # Build find exclude arguments
    local find_excludes=""
    for pattern in "${exclude_patterns[@]}"; do
        find_excludes="$find_excludes -not -path \"$pattern\""
    done

    # Function to find the best (shortest path) project/workspace
    find_best_xcode_path() {
        local search_dir="$1"
        local extension="$2"
        local max_depth="${3:-5}"

        # Find all matching paths, sort by path length (shortest first)
        eval "find \"$search_dir\" -maxdepth $max_depth -name \"*.$extension\" $find_excludes 2>/dev/null" | \
            awk '{ print length, $0 }' | \
            sort -n | \
            cut -d' ' -f2- | \
            head -1
    }

    # Look for workspace first (preferred) - search in WORK_DIR first, then PROJECT_ROOT
    local workspace
    workspace=$(find_best_xcode_path "$WORK_DIR" "xcworkspace" 5)

    # Exclude project.xcworkspace (inside .xcodeproj) - we want standalone workspaces
    if [ -n "$workspace" ] && echo "$workspace" | grep -q "\.xcodeproj/"; then
        workspace=""
    fi

    if [ -z "$workspace" ] && [ "$WORK_DIR" != "$PROJECT_ROOT" ]; then
        workspace=$(find_best_xcode_path "$PROJECT_ROOT" "xcworkspace" 5)
        if [ -n "$workspace" ] && echo "$workspace" | grep -q "\.xcodeproj/"; then
            workspace=""
        fi
    fi

    local project=""
    if [ -z "$workspace" ]; then
        # Fall back to project - search in WORK_DIR first, then PROJECT_ROOT
        project=$(find_best_xcode_path "$WORK_DIR" "xcodeproj" 5)

        if [ -z "$project" ] && [ "$WORK_DIR" != "$PROJECT_ROOT" ]; then
            project=$(find_best_xcode_path "$PROJECT_ROOT" "xcodeproj" 5)
        fi
    fi

    if [ -n "$workspace" ]; then
        log_info "Found Xcode workspace: $workspace"
        XCODE_WORKSPACE="$workspace"
        return 0
    elif [ -n "$project" ]; then
        log_info "Found Xcode project: $project"
        XCODE_PROJECT="$project"
        return 0
    else
        log_verbose "No Xcode workspace or project found in $WORK_DIR"
        if [ "$WORK_DIR" != "$PROJECT_ROOT" ]; then
            log_verbose "Also checked: $PROJECT_ROOT"
        fi
        return 1
    fi
}

# Ensure git repository exists (initialize if needed)
ensure_git_repo() {
    # Check if we're in a git repository
    if git rev-parse --git-dir >/dev/null 2>&1; then
        log_verbose "Git repository found"
        return 0
    fi

    log_warning "No git repository found in $WORK_DIR"
    log_info "Git repository is recommended for SwiftLint to work properly"

    # Check if git is available
    if ! command -v git >/dev/null 2>&1; then
        log_warning "Git is not installed - skipping initialization"
        return 1
    fi

    # Ask user if they want to initialize (or auto-initialize in YOLO mode)
    if [ "$YOLO_MODE" = "true" ] || [ "$DRY_RUN" = "true" ]; then
        log_info "Auto-initializing git repository..."

        if [ "$DRY_RUN" = "true" ]; then
            log_info "[DRY RUN] Would run: git init && git add . && git commit -m 'Initial commit'"
            return 0
        fi

        # Initialize git repo
        if git init >/dev/null 2>&1; then
            log_success "✓ Initialized empty git repository"

            # Add all files and make initial commit
            if git add . >/dev/null 2>&1 && git commit -m "Initial commit by BuildAgent" >/dev/null 2>&1; then
                log_success "✓ Created initial commit"
                log_info "Git repository ready for SwiftLint"
                return 0
            else
                log_warning "Git initialized but initial commit failed"
                return 1
            fi
        else
            log_error "Failed to initialize git repository"
            return 1
        fi
    else
        log_info "Run 'git init' to initialize a repository for better linting"
        return 1
    fi
}

# Auto-detect Xcode scheme by looking for .xcodeproj or .xcworkspace
detect_scheme() {
    if [ -n "$SCHEME" ]; then
        log_verbose "Using provided scheme: $SCHEME"
        return 0
    fi

    log_verbose "Attempting to auto-detect Xcode scheme..."

    # Use already-detected project/workspace if available
    local workspace="$XCODE_WORKSPACE"
    local project="$XCODE_PROJECT"

    # If not already detected, run detect_xcode_project_path first
    if [ -z "$workspace" ] && [ -z "$project" ]; then
        detect_xcode_project_path || true
        workspace="$XCODE_WORKSPACE"
        project="$XCODE_PROJECT"
    fi

    # Build xcodebuild argument array (no eval — avoids CWE-78 shell injection)
    local xcode_cmd_args=("xcodebuild")
    if [ -n "$workspace" ]; then
        xcode_cmd_args+=("-workspace" "$workspace")
        log_verbose "Using workspace: $workspace"
    elif [ -n "$project" ]; then
        xcode_cmd_args+=("-project" "$project")
        log_verbose "Using project: $project"
    else
        log_verbose "No Xcode workspace or project found"
        return 1
    fi

    # Get list of schemes
    local schemes_output
    schemes_output=$("${xcode_cmd_args[@]}" -list 2>/dev/null || true)

    # Extract first scheme from output
    SCHEME=$(echo "$schemes_output" | awk '/Schemes:/{found=1; next} found && /^[[:space:]]+[^[:space:]]/{print $1; exit}')

    if [ -n "$SCHEME" ]; then
        log_info "Auto-detected scheme: $SCHEME"
        return 0
    fi

    log_verbose "Could not auto-detect scheme"
    return 1
}

# ─────────────────────────────────────────────────────────────────────────────
# Multi-Platform Detection
# ─────────────────────────────────────────────────────────────────────────────

# Detected platforms (array)
DETECTED_PLATFORMS=()

# Detect all platforms supported by the project
# Parses project.pbxproj for SUPPORTED_PLATFORMS and SDKROOT
detect_project_platforms() {
    if [ "$AUTO_MULTI_PLATFORM" != "true" ]; then
        log_verbose "Multi-platform detection disabled"
        return 0
    fi

    log_verbose "Detecting supported platforms..."

    local project_file=""

    # Find the project.pbxproj file
    if [ -n "$XCODE_WORKSPACE" ]; then
        # For workspaces, look for the main project inside
        local proj_in_workspace
        proj_in_workspace=$(find "$(dirname "$XCODE_WORKSPACE")" -maxdepth 2 -name "*.xcodeproj" -not -path "*/.build/*" 2>/dev/null | head -1)
        if [ -n "$proj_in_workspace" ]; then
            project_file="${proj_in_workspace}/project.pbxproj"
        fi
    elif [ -n "$XCODE_PROJECT" ]; then
        project_file="${XCODE_PROJECT}/project.pbxproj"
    fi

    if [ ! -f "$project_file" ]; then
        log_verbose "Could not find project.pbxproj for platform detection"
        DETECTED_PLATFORMS=("iOS Simulator")  # Default fallback
        return 0
    fi

    # Parse SUPPORTED_PLATFORMS from pbxproj
    local supported_platforms
    supported_platforms=$(grep -E "SUPPORTED_PLATFORMS\s*=" "$project_file" 2>/dev/null | head -1 | sed 's/.*=\s*"\?\([^";]*\)"\?.*/\1/' || echo "")

    if [ -n "$supported_platforms" ]; then
        log_verbose "Found SUPPORTED_PLATFORMS: $supported_platforms"

        # Parse the platform list
        local platforms_list
        platforms_list=$(echo "$supported_platforms" | tr ',' '\n' | tr ' ' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | grep -v '^$')

        while IFS= read -r plat; do
            case "$plat" in
                iphoneos)
                    # iOS Device (we'll use simulator for builds typically)
                    DETECTED_PLATFORMS+=("iOS Simulator")
                    ;;
                iphonesimulator)
                    DETECTED_PLATFORMS+=("iOS Simulator")
                    ;;
                macosx)
                    DETECTED_PLATFORMS+=("macOS")
                    ;;
                watchos)
                    DETECTED_PLATFORMS+=("watchOS Simulator")
                    ;;
                watchsimulator)
                    DETECTED_PLATFORMS+=("watchOS Simulator")
                    ;;
                appletvos)
                    DETECTED_PLATFORMS+=("tvOS Simulator")
                    ;;
                appletvsimulator)
                    DETECTED_PLATFORMS+=("tvOS Simulator")
                    ;;
                xros)
                    DETECTED_PLATFORMS+=("visionOS Simulator")
                    ;;
                xrsimulator)
                    DETECTED_PLATFORMS+=("visionOS Simulator")
                    ;;
            esac
        done <<< "$platforms_list"
    else
        # Try parsing SDKROOT as fallback
        local sdkroot
        sdkroot=$(grep -E "SDKROOT\s*=" "$project_file" 2>/dev/null | head -1 | sed 's/.*=\s*"\?\([^";]*\)"\?.*/\1/' || echo "")

        if [ -n "$sdkroot" ]; then
            case "$sdkroot" in
                iphoneos*)
                    DETECTED_PLATFORMS+=("iOS Simulator")
                    ;;
                macosx*)
                    DETECTED_PLATFORMS+=("macOS")
                    ;;
                watchos*)
                    DETECTED_PLATFORMS+=("watchOS Simulator")
                    ;;
                appletvos*)
                    DETECTED_PLATFORMS+=("tvOS Simulator")
                    ;;
                xros*)
                    DETECTED_PLATFORMS+=("visionOS Simulator")
                    ;;
            esac
        fi
    fi

    # Remove duplicates
    if [ ${#DETECTED_PLATFORMS[@]} -gt 0 ]; then
        local unique_platforms=()
        local -A seen=()
        for p in "${DETECTED_PLATFORMS[@]}"; do
            if [ -z "${seen[$p]:-}" ]; then
                unique_platforms+=("$p")
                seen[$p]=1
            fi
        done
        DETECTED_PLATFORMS=("${unique_platforms[@]}")
    else
        # Default to iOS Simulator if nothing detected
        DETECTED_PLATFORMS=("iOS Simulator")
    fi

    # Filter to only iOS and macOS platforms (default behavior)
    local filtered_platforms=()
    for p in "${DETECTED_PLATFORMS[@]}"; do
        case "$p" in
            "iOS Simulator"|"macOS")
                filtered_platforms+=("$p")
                ;;
            *)
                log_verbose "Skipping platform: $p (only iOS and macOS enabled by default)"
                ;;
        esac
    done
    
    # Update DETECTED_PLATFORMS with filtered list
    if [ ${#filtered_platforms[@]} -gt 0 ]; then
        DETECTED_PLATFORMS=("${filtered_platforms[@]}")
    else
        # Fallback to iOS Simulator if filtering removed all platforms
        DETECTED_PLATFORMS=("iOS Simulator")
    fi

    log_info "Detected platforms: ${DETECTED_PLATFORMS[*]}"
    return 0
}

# ─────────────────────────────────────────────────────────────────────────────
# UI Initialization
# ─────────────────────────────────────────────────────────────────────────────

# Initialize UI system (called in main)
init_ui() {
    # Skip UI initialization if disabled or not available
    if [ "${BUILDAGENT_FANCY_UI:-false}" != "true" ]; then
        return 0
    fi

    # Detect terminal capabilities
    if type detect_terminal_capabilities &>/dev/null; then
        detect_terminal_capabilities
    fi

    # Select theme
    if type select_theme &>/dev/null; then
        select_theme "${BUILDAGENT_THEME:-dark}"
    fi

    # Enable phrase cycling for spinner
    if type enable_phrase_cycling &>/dev/null && [ "${BUILDAGENT_WITTY_PHRASES:-true}" = "true" ]; then
        enable_phrase_cycling
    fi
}

# Show startup UI (logo, banner, tip)
show_startup_ui() {
    if [ "${BUILDAGENT_FANCY_UI:-false}" != "true" ]; then
        return 0
    fi

    # Show logo
    if type show_logo &>/dev/null; then
        show_logo "auto"
    fi

    # Show banner
    if type show_banner &>/dev/null; then
        show_banner "Foundation BuildAgent" "AI-Powered Build Verification"
    fi

    # Show random tip
    if type get_random_tip_formatted &>/dev/null && [ "${BUILDAGENT_SHOW_TIPS:-true}" = "true" ]; then
        local tip
        tip=$(get_random_tip_formatted)
        echo "" >&2
        echo "$tip" >&2
        echo "" >&2
    fi
}

# Show configuration box
show_config_box() {
    if [ "${BUILDAGENT_FANCY_UI:-false}" != "true" ]; then
        return 0
    fi

    if ! type draw_box &>/dev/null; then
        return 0
    fi

    local config_content=""
    config_content+="Scheme: ${SCHEME:-auto-detect}\n"
    config_content+="Configuration: ${BUILD_CONFIGURATION:-Debug}\n"
    config_content+="AI Provider: ${AI_PROVIDER:-copilot}\n"
    config_content+="Max Attempts: ${MAX_REPAIR_ATTEMPTS:-3}"

    if [ -n "$DESTINATION" ]; then
        config_content+="\nDestination: $DESTINATION"
    fi

    if [ ${#DETECTED_PLATFORMS[@]} -gt 1 ]; then
        config_content+="\nPlatforms: ${DETECTED_PLATFORMS[*]}"
    fi

    draw_box "Configuration" "$config_content"
}

# ─────────────────────────────────────────────────────────────────────────────
# AI Provider Detection & Configuration
# ─────────────────────────────────────────────────────────────────────────────

# Attempt to install missing AI provider using Cursor CLI
install_ai_provider() {
    local provider="$1"
    local install_cmd="$2"

    log_warning "AI provider '$provider' not found"

    # Check if cursor-agent is available for installation
    if ! command -v cursor-agent >/dev/null 2>&1; then
        log_error "Cannot auto-install: cursor-agent not available"
        log_info "Please install manually: $install_cmd"
        return 1
    fi

    echo "" >&2
    log_section "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_section "AUTO-INSTALLATION ATTEMPT"
    log_section "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "" >&2

    log_info "Attempting to install '$provider' using Cursor AI..."
    log_info "Install command: $install_cmd"
    echo "" >&2

    # Create installation prompt for Cursor
    local install_prompt="Please install the $provider CLI tool by running this command:

$install_cmd

After running the command, verify the installation by running:
command -v ${provider}

Respond with 'INSTALLED' when complete."

    # Save prompt to temp file
    local prompt_file="/tmp/buildagent_install_${provider}_$$.txt"
    echo "$install_prompt" > "$prompt_file"

    log_info "Asking Cursor AI to install $provider..."

    # Run cursor-agent to install (in WORK_DIR where user invoked the command)
    local cursor_output
    if cursor_output=$(cd "$WORK_DIR" && cursor-agent --force --print --output-format text "$install_prompt" 2>&1); then
        log_verbose "Cursor response received"

        # Wait a moment for installation to complete
        sleep 2

        # Check if the provider is now available
        if command -v "$provider" >/dev/null 2>&1; then
            echo "" >&2
            log_success "✓ Successfully installed $provider!"
            echo "" >&2
            rm -f "$prompt_file"
            return 0
        else
            log_warning "Installation attempted but $provider not found in PATH"
            log_info "You may need to restart your terminal or source your profile"
            log_info "Manual installation: $install_cmd"
            rm -f "$prompt_file"
            return 1
        fi
    else
        log_error "Cursor AI installation attempt failed"
        log_info "Please install manually: $install_cmd"
        rm -f "$prompt_file"
        return 1
    fi
}

# Auto-install Letta Code CLI
# Handles nvm environments, Node.js version validation, and PATH issues
install_letta() {
    log_info "Letta CLI not found. Attempting auto-installation..."

    # Check for Node.js
    if ! command -v node >/dev/null 2>&1; then
        # Try to load nvm if available
        if [ -f "$HOME/.nvm/nvm.sh" ]; then
            log_info "Loading nvm..."
            export NVM_DIR="$HOME/.nvm"
            # shellcheck disable=SC1091
            . "$NVM_DIR/nvm.sh"
        elif [ -f "/usr/local/opt/nvm/nvm.sh" ]; then
            # Homebrew nvm location
            export NVM_DIR="/usr/local/opt/nvm"
            # shellcheck disable=SC1091
            . "$NVM_DIR/nvm.sh"
        elif [ -f "/opt/homebrew/opt/nvm/nvm.sh" ]; then
            # Apple Silicon Homebrew location
            export NVM_DIR="/opt/homebrew/opt/nvm"
            # shellcheck disable=SC1091
            . "$NVM_DIR/nvm.sh"
        fi
    fi

    # Verify Node.js is available
    if ! command -v node >/dev/null 2>&1; then
        log_error "Node.js not found. Install Node.js 18+ first:"
        echo "  brew install node" >&2
        echo "  # or" >&2
        echo "  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash" >&2
        echo "  nvm install 18" >&2
        return 1
    fi

    # Check Node.js version (requires 18+)
    local node_version
    node_version=$(node -v | sed 's/v//' | cut -d. -f1)
    if [ "$node_version" -lt 18 ]; then
        log_error "Node.js 18+ required. Current version: $(node -v)"
        echo "  nvm install 18 && nvm use 18" >&2
        return 1
    fi

    # Check for npm
    if ! command -v npm >/dev/null 2>&1; then
        log_error "npm not found. Install npm or reinstall Node.js"
        return 1
    fi

    # Install Letta Code CLI globally
    log_info "Installing @letta-ai/letta-code via npm..."
    local install_log="/tmp/letta-install-$$.log"
    if npm install -g @letta-ai/letta-code 2>&1 | tee "$install_log"; then
        # Verify installation
        if command -v letta >/dev/null 2>&1; then
            log_success "Letta Code CLI installed successfully: $(letta --version 2>/dev/null || echo 'installed')"
            rm -f "$install_log"
            return 0
        else
            # Check if npm global bin is in PATH
            local npm_bin
            npm_bin=$(npm bin -g 2>/dev/null)
            if [ -n "$npm_bin" ] && [ -x "$npm_bin/letta" ]; then
                log_warning "Letta installed but not in PATH. Adding temporarily..."
                export PATH="$npm_bin:$PATH"
                if command -v letta >/dev/null 2>&1; then
                    log_success "Letta Code CLI available: $(letta --version 2>/dev/null || echo 'installed')"
                    rm -f "$install_log"
                    return 0
                fi
            fi
            log_error "Letta installed but 'letta' command not found in PATH"
            echo "  Add npm global bin to PATH: export PATH=\"\$(npm bin -g):\$PATH\"" >&2
            rm -f "$install_log"
            return 1
        fi
    else
        log_error "Failed to install Letta. Check $install_log for details"
        return 1
    fi
}

# Initialize or resume directory-specific Letta agent
# Each project directory gets its own dedicated agent with persistent memory
init_letta_directory_agent() {
    local project_dir="${1:-$WORK_DIR}"
    local project_name
    project_name=$(basename "$project_dir")
    local letta_config="$project_dir/.letta/settings.local.json"

    # Check if agent already exists for this directory
    if [ -f "$letta_config" ]; then
        # Letta auto-resumes the pinned agent when run from this directory
        log_verbose "Resuming Letta agent for: $project_name"
        return 0
    fi

    # First run: Create and initialize new agent
    log_info "Creating new Letta agent for: $project_name"

    # Create agent with project-specific name and initialize memory
    # Use --new to create a fresh agent, run /init to learn the codebase
    if (cd "$project_dir" && echo "You are the build agent for '$project_name'. Please run /init to learn this codebase structure." | letta --new --yolo -p 2>/dev/null); then
        # Pin agent locally to this directory
        if (cd "$project_dir" && echo "/pin -l ${project_name}-builder" | letta 2>/dev/null); then
            log_success "Letta agent initialized and pinned locally for: $project_name"
            return 0
        else
            log_warning "Agent created but local pinning failed - agent will still work"
            return 0
        fi
    else
        log_warning "Could not initialize Letta agent - will use default agent"
        return 1
    fi
}

# Detect whether cursor-agent supports the --stream flag
detect_cursor_stream_support() {
    CURSOR_STREAM_SUPPORTED="false"

    if [ "$AI_CMD" != "cursor-agent" ]; then
        return 0
    fi

    local help_output=""
    if help_output=$(cursor-agent --help 2>/dev/null); then
        if echo "$help_output" | grep -q -- '--stream'; then
            CURSOR_STREAM_SUPPORTED="true"
        fi
    fi
}

# Detect and configure AI CLI provider
detect_ai_provider() {
    local provider
    provider=$(echo "$AI_PROVIDER" | tr '[:upper:]' '[:lower:]')  # Convert to lowercase

    log_verbose "Detecting AI provider: $provider"
    CURSOR_STREAM_SUPPORTED="false"

    case "$provider" in
        cursor)
            if command -v cursor-agent >/dev/null 2>&1; then
                AI_CMD="cursor-agent"
                detect_cursor_stream_support
                log_info "Using Cursor AI (cursor-agent)"
                return 0
            elif command -v cursor >/dev/null 2>&1; then
                AI_CMD="cursor agent"
                log_info "Using Cursor AI (cursor)"
                return 0
            else
                log_error "Cursor CLI not found. Install from https://cursor.sh"
                log_info "Cursor is required - it cannot auto-install itself"
                return 1
            fi
            ;;

        claude)
            if command -v claude >/dev/null 2>&1; then
                AI_CMD="claude"
                log_info "Using Claude CLI (with --dangerously-skip-permissions)"
                return 0
            else
                # Attempt auto-installation
                if install_ai_provider "claude" "npm install -g @anthropic-ai/claude-cli"; then
                    AI_CMD="claude"
                    log_info "Using Claude CLI (with --dangerously-skip-permissions)"
                    return 0
                fi
                return 1
            fi
            ;;

        codex|openai)
            if command -v codex >/dev/null 2>&1; then
                AI_CMD="codex"
                log_info "Using OpenAI Codex CLI (with --full-auto)"
                return 0
            elif command -v openai >/dev/null 2>&1; then
                AI_CMD="openai"
                log_info "Using OpenAI CLI (with --full-auto)"
                return 0
            else
                # Attempt auto-installation
                if install_ai_provider "openai" "pip install openai-cli"; then
                    if command -v openai >/dev/null 2>&1; then
                        AI_CMD="openai"
                        log_info "Using OpenAI CLI (with --full-auto)"
                        return 0
                    fi
                fi
                return 1
            fi
            ;;

        gemini|google)
            if command -v gemini >/dev/null 2>&1; then
                AI_CMD="gemini"
                log_info "Using Google Gemini CLI (with --yolo)"
                return 0
            elif command -v gcloud >/dev/null 2>&1; then
                AI_CMD="gcloud ai"
                log_info "Using Google Cloud AI CLI (with --yolo)"
                return 0
            else
                # Attempt auto-installation (gemini CLI)
                if install_ai_provider "gemini" "npm install -g @google/generative-ai-cli"; then
                    AI_CMD="gemini"
                    log_info "Using Google Gemini CLI (with --yolo)"
                    return 0
                fi
                return 1
            fi
            ;;

        aider)
            if command -v aider >/dev/null 2>&1; then
                AI_CMD="aider"
                log_info "Using Aider CLI"
                return 0
            else
                # Attempt auto-installation
                if install_ai_provider "aider" "pip install aider-chat"; then
                    AI_CMD="aider"
                    log_info "Using Aider CLI"
                    return 0
                fi
                return 1
            fi
            ;;

        letta)
            if command -v letta >/dev/null 2>&1; then
                AI_CMD="letta"
                log_info "Using Letta Code CLI: $(letta --version 2>/dev/null || echo 'installed')"
                log_info "Letta provides stateful agents with persistent memory"
                return 0
            else
                # Attempt auto-installation via npm
                if install_letta; then
                    AI_CMD="letta"
                    return 0
                fi
                return 1
            fi
            ;;

        copilot|github-copilot)
            # GitHub Copilot CLI - new @github/copilot npm package
            # Check for the new copilot command that supports -p flag
            if command -v copilot >/dev/null 2>&1; then
                # Verify it's the correct copilot (has -p option)
                if copilot --help 2>&1 | grep -q "\-p, --prompt"; then
                    AI_CMD="copilot"
                    log_info "Using GitHub Copilot CLI (@github/copilot)"
                    return 0
                fi
            fi

            # Try to install via npm
            log_info "GitHub Copilot CLI not found, attempting to install..."
            if install_ai_provider "copilot" "npm install -g @github/copilot"; then
                if command -v copilot >/dev/null 2>&1; then
                    AI_CMD="copilot"
                    log_info "GitHub Copilot CLI installed successfully"
                    return 0
                fi
            fi

            log_error "Failed to install GitHub Copilot CLI"
            log_info "Install manually: npm install -g @github/copilot"
            log_info "Requires Node.js 18+ and active Copilot subscription"
            return 1
            ;;

        *)
            log_error "Unknown AI provider: $provider"
            log_info "Supported providers: cursor, claude, codex, gemini, aider, letta, copilot"
            return 1
            ;;
    esac
}

# Check for authentication errors in AI CLI output
check_auth_error() {
    local output="$1"
    local provider
    provider=$(echo "$AI_PROVIDER" | tr '[:upper:]' '[:lower:]')  # Convert to lowercase

    # Common authentication error patterns
    local auth_patterns=(
        "not authenticated"
        "authentication failed"
        "not logged in"
        "please sign in"
        "please login"
        "invalid api key"
        "api key not found"
        "unauthorized"
        "401"
        "403 Forbidden"
        "authentication required"
        "token expired"
        "credentials not found"
        "no api key"
    )

    local output_lower
    output_lower=$(echo "$output" | tr '[:upper:]' '[:lower:]')  # Convert to lowercase for case-insensitive matching

    for pattern in "${auth_patterns[@]}"; do
        if echo "$output_lower" | grep -q "$pattern"; then
            log_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            log_error "AUTHENTICATION ERROR DETECTED"
            log_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "" >&2
            log_error "The AI CLI ($provider) requires authentication."
            echo "" >&2

            # Provider-specific instructions
            case "$provider" in
                cursor)
                    log_info "To authenticate Cursor:"
                    echo "  1. Open Cursor application" >&2
                    echo "  2. Sign in with your account" >&2
                    echo "  3. Try running: cursor-agent --help" >&2
                    ;;
                claude)
                    log_info "To authenticate Claude CLI:"
                    echo "  1. Get your API key from: https://console.anthropic.com/" >&2
                    echo "  2. Set environment variable: export ANTHROPIC_API_KEY=your_key" >&2
                    echo "  3. Or run: claude auth login" >&2
                    ;;
                codex|openai)
                    log_info "To authenticate OpenAI:"
                    echo "  1. Get your API key from: https://platform.openai.com/api-keys" >&2
                    echo "  2. Set environment variable: export OPENAI_API_KEY=your_key" >&2
                    echo "  3. Or run: openai auth login" >&2
                    ;;
                gemini|google)
                    log_info "To authenticate Gemini:"
                    echo "  1. Get your API key from: https://makersuite.google.com/app/apikey" >&2
                    echo "  2. Set environment variable: export GOOGLE_API_KEY=your_key" >&2
                    echo "  3. Or run: gcloud auth login" >&2
                    ;;
                aider)
                    log_info "To authenticate Aider:"
                    echo "  1. Get your API key from your AI provider" >&2
                    echo "  2. Set environment variable (e.g., OPENAI_API_KEY, ANTHROPIC_API_KEY)" >&2
                    echo "  3. Or run: aider --help for setup instructions" >&2
                    ;;
                letta)
                    log_info "To authenticate Letta Code:"
                    echo "  1. Get your API key from: https://app.letta.com/api-keys" >&2
                    echo "  2. Set environment variable: export LETTA_API_KEY=your_key" >&2
                    echo "  3. Or run: letta (first run prompts for authentication)" >&2
                    if [ -n "${LETTA_BASE_URL:-}" ]; then
                        echo "" >&2
                        echo "  Self-hosted instance detected: $LETTA_BASE_URL" >&2
                        echo "  Ensure your API key is valid for this server." >&2
                    fi
                    ;;
                copilot|github-copilot)
                    log_info "To authenticate GitHub Copilot CLI:"
                    echo "  1. Copilot CLI uses GitHub authentication" >&2
                    echo "  2. Run: gh auth login (or copilot auth if standalone)" >&2
                    echo "  3. Ensure you have a GitHub Copilot subscription" >&2
                    echo "  4. Install: npm install -g @github/copilot" >&2
                    ;;
            esac

            echo "" >&2
            log_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            return 0  # Auth error detected
        fi
    done

    return 1  # No auth error
}

# ─────────────────────────────────────────────────────────────────────────────
# Context Gathering Functions
# ─────────────────────────────────────────────────────────────────────────────

# Read all MD files from a directory
read_md_files_from_dir() {
    local dir="$1"
    local content=""

    if [ ! -d "$dir" ]; then
        return
    fi

    while IFS= read -r -d '' md_file; do
        local filename
        filename=$(basename "$md_file")
        content+="
--- FILE: $filename ---
$(cat "$md_file")
--- END FILE ---
"
    done < <(find "$dir" -maxdepth 2 -name "*.md" -type f -print0 2>/dev/null)

    echo "$content"
}

# Extract keywords from error messages or prompts for doc filtering
# Returns lowercase keywords, one per line
extract_keywords_for_docs() {
    local input="$1"
    local keywords=()

    # Extract Swift type names (PascalCase identifiers)
    local types
    types=$(echo "$input" | grep -oE '\b[A-Z][a-zA-Z0-9]+\b' | sort -u)
    while IFS= read -r type; do
        [ -n "$type" ] && keywords+=("$(echo "$type" | tr '[:upper:]' '[:lower:]')")
    done <<< "$types"

    # Extract framework names from imports or common patterns
    local frameworks
    frameworks=$(echo "$input" | grep -oE '\b(SwiftUI|UIKit|Foundation|SwiftData|CoreData|Vision|AVFoundation|CoreImage|CoreML|Combine|CoreAnimation|Metal|MapKit|PhotosUI|StoreKit|CloudKit|HealthKit|HomeKit|LocalAuthentication|Security|Keychain|PDFKit|VisionKit|Charts)\b' | sort -u | tr '[:upper:]' '[:lower:]')
    while IFS= read -r fw; do
        [ -n "$fw" ] && keywords+=("$fw")
    done <<< "$frameworks"

    # Extract common Swift patterns from errors
    if echo "$input" | grep -qiE 'singleton|shared|\.shared'; then
        keywords+=("singleton" "shared" "class")
    fi
    if echo "$input" | grep -qiE '@Observable|@State|@Binding|@Environment'; then
        keywords+=("observable" "state" "binding" "swiftui")
    fi
    if echo "$input" | grep -qiE '@Model|SwiftData|PersistentModel'; then
        keywords+=("swiftdata" "model" "persistent")
    fi
    if echo "$input" | grep -qiE 'async|await|Task|actor'; then
        keywords+=("async" "concurrency" "actor" "task")
    fi
    if echo "$input" | grep -qiE 'View|body|some View'; then
        keywords+=("view" "swiftui")
    fi

    # Remove duplicates and output
    printf '%s\n' "${keywords[@]}" | sort -u | head -20
}

# Filter docs using keyword matching (fast, no AI dependency)
# Matches keywords against filenames and optionally file content
filter_docs_by_keywords() {
    local docs_dir="$1"
    shift
    local keywords=("$@")
    local matched_files=()
    local max_files=20

    if [ ${#keywords[@]} -eq 0 ]; then
        return 1
    fi

    log_verbose "Filtering docs by keywords: ${keywords[*]}"

    # Build grep pattern from keywords
    local pattern
    pattern=$(printf '%s\|' "${keywords[@]}" | sed 's/\\|$//')

    # First pass: match filenames (fast)
    while IFS= read -r -d '' file; do
        local filename
        filename=$(basename "$file" | tr '[:upper:]' '[:lower:]')
        for kw in "${keywords[@]}"; do
            if [[ "$filename" == *"$kw"* ]]; then
                matched_files+=("$file")
                break
            fi
        done
    done < <(find "$docs_dir" -name "*.md" -type f -print0 2>/dev/null)

    # If we have enough matches from filenames, return early
    if [ ${#matched_files[@]} -ge 5 ]; then
        printf '%s\n' "${matched_files[@]}" | head -$max_files
        return 0
    fi

    # Second pass: search file contents for remaining keywords (slower but thorough)
    local content_matches
    content_matches=$(grep -l -i -E "$pattern" "$docs_dir"/*.md "$docs_dir"/**/*.md 2>/dev/null | head -$((max_files - ${#matched_files[@]})) || true)

    while IFS= read -r file; do
        if [ -n "$file" ] && [ -f "$file" ]; then
            # Avoid duplicates
            local is_dup=false
            for existing in "${matched_files[@]}"; do
                if [ "$existing" = "$file" ]; then
                    is_dup=true
                    break
                fi
            done
            if [ "$is_dup" = false ]; then
                matched_files+=("$file")
            fi
        fi
    done <<< "$content_matches"

    if [ ${#matched_files[@]} -eq 0 ]; then
        return 1
    fi

    printf '%s\n' "${matched_files[@]}" | head -$max_files
    return 0
}

# Filter swift docs using AI RAG (cursor-agent or claude)
# Falls back to keyword filtering if AI unavailable
filter_swift_docs_via_ai() {
    local prompt="$1"
    local docs_dir="$2"
    local filtered_files=()

    # Try cursor-agent first (has RAG index)
    if command -v cursor-agent >/dev/null 2>&1; then
        log_verbose "Trying cursor-agent for smart docs filtering..."

        local selector_prompt="Given this task: $prompt

List ONLY the absolute file paths from $docs_dir that are most relevant to this task.
Output one path per line, nothing else. Maximum 15 files."

        local cursor_output
        cursor_output=$(cursor-agent --print --force --output-format text --workspace "$WORK_DIR" "$selector_prompt" 2>/dev/null || true)

        while IFS= read -r line; do
            local cleaned_path
            cleaned_path=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | grep -E '\.md$' || true)
            if [ -n "$cleaned_path" ] && [ -f "$cleaned_path" ]; then
                filtered_files+=("$cleaned_path")
            elif [ -n "$cleaned_path" ]; then
                local rel_path="${docs_dir}/${cleaned_path#./}"
                if [ -f "$rel_path" ]; then
                    filtered_files+=("$rel_path")
                fi
            fi
        done <<< "$cursor_output"

        if [ ${#filtered_files[@]} -gt 0 ]; then
            log_info "Smart docs (cursor-agent): Selected ${#filtered_files[@]} relevant files"
            printf '%s\n' "${filtered_files[@]}"
            return 0
        fi
    fi

    # Try claude CLI as fallback
    if command -v claude >/dev/null 2>&1; then
        log_verbose "Trying claude CLI for smart docs filtering..."

        # Get list of doc files
        local doc_list
        doc_list=$(find "$docs_dir" -name "*.md" -type f 2>/dev/null | head -200)

        local selector_prompt="Given this Swift development task/error:
$prompt

Here are available documentation files:
$doc_list

List ONLY the file paths (from the list above) that are most relevant. Output one path per line, maximum 15 files. No explanations."

        local claude_output
        claude_output=$(echo "$selector_prompt" | claude --print --dangerously-skip-permissions 2>/dev/null || true)

        while IFS= read -r line; do
            local cleaned_path
            cleaned_path=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | grep -E '\.md$' || true)
            if [ -n "$cleaned_path" ] && [ -f "$cleaned_path" ]; then
                filtered_files+=("$cleaned_path")
            fi
        done <<< "$claude_output"

        if [ ${#filtered_files[@]} -gt 0 ]; then
            log_info "Smart docs (claude): Selected ${#filtered_files[@]} relevant files"
            printf '%s\n' "${filtered_files[@]}"
            return 0
        fi
    fi

    log_verbose "AI-based filtering unavailable"
    return 1
}

# Main smart docs filter - tries AI first, falls back to keywords
filter_swift_docs() {
    local prompt="$1"
    local docs_dir="$2"

    # Try AI-based filtering first
    if filter_swift_docs_via_ai "$prompt" "$docs_dir"; then
        return 0
    fi

    # Fall back to keyword-based filtering
    log_verbose "Falling back to keyword-based doc filtering..."

    local keywords=()
    while IFS= read -r kw; do
        [ -n "$kw" ] && keywords+=("$kw")
    done < <(extract_keywords_for_docs "$prompt")

    if [ ${#keywords[@]} -gt 0 ]; then
        if filter_docs_by_keywords "$docs_dir" "${keywords[@]}"; then
            log_info "Smart docs (keywords): Filtered docs by ${#keywords[@]} keywords"
            return 0
        fi
    fi

    log_verbose "Smart filtering returned no results"
    return 1
}

# Read specific MD files (used with smart docs filtering)
read_filtered_md_files() {
    local content=""

    while IFS= read -r md_file; do
        if [ -f "$md_file" ]; then
            local filename
            filename=$(basename "$md_file")
            content+="
--- FILE: $filename ---
$(cat "$md_file")
--- END FILE ---
"
        fi
    done

    echo "$content"
}

# Gather all context into a single string
gather_context() {
    local context=""
    local has_context=false

    # Check if there's any context to gather
    if [ -n "$SWIFT_DOCS_PATH" ] && [ "$SWIFT_DOCS_PATH" != "DISABLED" ] && [ -d "$SWIFT_DOCS_PATH" ]; then
        has_context=true
    fi

    if [ ${#CONTEXT_PATHS[@]} -gt 0 ]; then
        has_context=true
    fi

    if [ "$has_context" = true ]; then
        start_spinner "Gathering context"
    fi

    # Add Swift docs if available (with smart filtering by default)
    if [ -n "$SWIFT_DOCS_PATH" ] && [ "$SWIFT_DOCS_PATH" != "DISABLED" ] && [ -d "$SWIFT_DOCS_PATH" ]; then
        log_verbose "Adding Swift docs from: $SWIFT_DOCS_PATH"
        local swift_docs_content=""
        local input_content
        input_content=$(get_input_content)

        # Try smart filtering first (AI or keyword-based)
        if [ "$SMART_DOCS" = "true" ] && [ -n "$input_content" ]; then
            local filtered_files
            if filtered_files=$(filter_swift_docs "$input_content" "$SWIFT_DOCS_PATH"); then
                swift_docs_content=$(echo "$filtered_files" | read_filtered_md_files)
            fi
        fi

        # Fall back to reading all docs if smart filtering failed or disabled
        if [ -z "$swift_docs_content" ]; then
            if [ "$SMART_DOCS" = "true" ]; then
                log_verbose "Smart docs filtering returned no results, using all docs"
            fi
            swift_docs_content=$(read_md_files_from_dir "$SWIFT_DOCS_PATH")
        fi

        if [ -n "$swift_docs_content" ]; then
            context+="
=== SWIFT DOCUMENTATION ===
$swift_docs_content
=== END SWIFT DOCUMENTATION ===
"
        fi
    fi

    # Add context from provided paths
    if [ ${#CONTEXT_PATHS[@]} -gt 0 ]; then
        for ctx_path in "${CONTEXT_PATHS[@]}"; do
            if [ -f "$ctx_path" ]; then
                log_verbose "Adding context file: $ctx_path"
                context+="
--- CONTEXT FILE: $(basename "$ctx_path") ---
$(cat "$ctx_path")
--- END CONTEXT FILE ---
"
            elif [ -d "$ctx_path" ]; then
                log_verbose "Adding context directory: $ctx_path"
                local dir_content
                dir_content=$(read_md_files_from_dir "$ctx_path")
                if [ -n "$dir_content" ]; then
                    context+="
=== CONTEXT FROM: $ctx_path ===
$dir_content
=== END CONTEXT ===
"
                fi
            fi
        done
    fi

    if [ "$has_context" = true ]; then
        spinner_success "Context gathered"
    fi

    echo "$context"
}

# Get the main prompt/plan content
get_input_content() {
    # Use cached content if available (avoids temp file deletion issues)
    if [ -n "$PROMPT_CONTENT" ]; then
        echo "$PROMPT_CONTENT"
        return
    fi

    # Fallback to reading files (may fail if temp files were deleted)
    local content=""
    if [ -n "$PLAN_FILE" ] && [ -f "$PLAN_FILE" ]; then
        content=$(cat "$PLAN_FILE" 2>/dev/null || true)
    elif [ -n "$PROMPT_FILE" ] && [ -f "$PROMPT_FILE" ]; then
        content=$(cat "$PROMPT_FILE" 2>/dev/null || true)
    elif [ -n "$PROMPT_STRING" ]; then
        content="$PROMPT_STRING"
    fi

    echo "$content"
}

# ─────────────────────────────────────────────────────────────────────────────
# Cursor CLI Functions (with session support)
# ─────────────────────────────────────────────────────────────────────────────

# Build the initial prompt (first attempt - includes full context)
build_initial_prompt() {
    local input_content="$1"
    local context="$2"

    local prompt="You are a Swift/SwiftUI developer. Your task is to implement the following requirements.

IMPORTANT INSTRUCTIONS:
1. Write clean, production-ready Swift code
2. Follow Apple's Swift API Design Guidelines
3. Use SwiftUI for UI components where appropriate
4. Include proper error handling
5. The code must compile without errors
6. After writing code, the build will be verified automatically
7. If the build fails, you will receive error feedback and should try a DIFFERENT approach

TESTING & DEBUGGING REFERENCE:
For building, testing, and debugging iOS/macOS apps, reference this workflow guide:
/Users/emmanuel/Dev/Tools/Eocon-Foundation-V1/.Foundation/Docs/swiftDocs/Testing/XCODEBUILD_MCP_WORKFLOW.md

This guide covers:
- XcodeBuild MCP server tools for programmatic Xcode interaction
- Building for simulator, booting simulators, installing/launching apps
- UI automation: screenshots, accessibility hierarchy, tap simulation
- Debugging UI issues (button taps, gestures, navigation)

=== TASK/REQUIREMENTS ===
$input_content
=== END TASK ===
"

    if [ -n "$context" ]; then
        prompt+="

=== REFERENCE CONTEXT ===
Use the following documentation and context as reference:
$context
=== END CONTEXT ===
"
    fi

    # Inject memory context if available (learned patterns from previous sessions)
    if [ -n "$LETTA_MEMORY_CONTEXT" ]; then
        prompt+="
$LETTA_MEMORY_CONTEXT
"
    fi

    prompt+="

Please implement the requirements above. Write the code directly - do not explain, just write the implementation."

    echo "$prompt"
}

# Build follow-up prompt (subsequent attempts - includes original task + error feedback)
build_followup_prompt() {
    local error_feedback="$1"
    local attempt_num="$2"
    local original_task="$3"
    local context="$4"

    local prompt="You are a Swift/SwiftUI developer. A previous attempt to complete a task failed.

TESTING & DEBUGGING REFERENCE:
For building, testing, and debugging iOS/macOS apps, reference this workflow guide:
/Users/emmanuel/Dev/Tools/Eocon-Foundation-V1/.Foundation/Docs/swiftDocs/Testing/XCODEBUILD_MCP_WORKFLOW.md

This guide covers:
- XcodeBuild MCP server tools for programmatic Xcode interaction
- Building for simulator, booting simulators, installing/launching apps
- UI automation: screenshots, accessibility hierarchy, tap simulation
- Debugging UI issues (button taps, gestures, navigation)

=== ORIGINAL TASK ===
$original_task
=== END ORIGINAL TASK ===
"

    if [ -n "$context" ]; then
        prompt+="
=== REFERENCE CONTEXT ===
$context
=== END CONTEXT ===
"
    fi

    # Inject memory context if available (learned patterns from previous sessions)
    if [ -n "$LETTA_MEMORY_CONTEXT" ]; then
        prompt+="
$LETTA_MEMORY_CONTEXT
"
    fi

    prompt+="
=== BUILD ATTEMPT $((attempt_num - 1)) FAILED ===
The previous implementation failed with the following errors:

$error_feedback

=== INSTRUCTIONS FOR ATTEMPT $attempt_num ===
1. Analyze what went wrong in the previous approach
2. Try a DIFFERENT approach or fix the specific issues
3. Do NOT repeat the same mistakes
4. If the same approach keeps failing, consider an alternative implementation strategy
5. Write the corrected code directly - do not explain, just implement

Please fix the issues and provide the corrected implementation."

    echo "$prompt"
}

# Update session context file (tracks attempts for debugging)
update_session_context() {
    local attempt="$1"
    local status="$2"
    local details="${3:-}"

    {
        echo "## Attempt $attempt"
        echo "Status: $status"
        echo "Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
        if [ -n "$details" ]; then
            echo "Details:"
            echo '```'
            echo "$details" | head -50
            echo '```'
        fi
        echo ""
    } >> "$SESSION_FILE"
}

# Get the latest chat ID (currently only supported for Cursor)
get_latest_chat_id() {
    # Only supported for cursor-agent format
    if [ "$AI_PROVIDER" = "cursor" ] && [ "$AI_CMD" = "cursor-agent" ]; then
        # Try to get the latest chat ID with timeout to prevent hangs
        local chat_list
        local pid

        # Run cursor-agent ls in background with kill-based timeout
        # This is more reliable than timeout command which can't handle stopped processes
        if command -v timeout >/dev/null 2>&1 || command -v gtimeout >/dev/null 2>&1; then
            # Create temp file for output
            local tmpfile
            tmpfile=$(mktemp)

            # Run in background
            (cd "$PROJECT_ROOT" && cursor-agent ls 2>/dev/null | head -1 > "$tmpfile") &
            pid=$!

            # Wait max 2 seconds
            local count=0
            while [ $count -lt 20 ]; do
                if ! kill -0 "$pid" 2>/dev/null; then
                    # Process finished
                    chat_list=$(cat "$tmpfile" 2>/dev/null)
                    rm -f "$tmpfile"
                    break
                fi
                sleep 0.1
                count=$((count + 1))
            done

            # Kill if still running
            if kill -0 "$pid" 2>/dev/null; then
                kill -9 "$pid" 2>/dev/null
                wait "$pid" 2>/dev/null
                log_verbose "cursor-agent ls timed out after 2 seconds"
            fi
            rm -f "$tmpfile"
        else
            # No timeout available, skip to avoid potential hang
            log_verbose "timeout command not available, skipping chat ID capture"
            echo ""
            return
        fi

        if [ -n "$chat_list" ]; then
            # Extract chat ID (usually first field or UUID-like string)
            echo "$chat_list" | awk '{print $1}' | head -1
        fi
    fi
    # Return empty if not available or not supported for this provider
    echo ""
}

# Run AI CLI with session support
run_ai_cli() {
    local prompt="$1"
    local is_followup="${2:-false}"
    local output_file="${LOGS_DIR}/coder_attempt_${CURRENT_ATTEMPT}.log"

    log_attempt "Running ${AI_PROVIDER} AI CLI (session: $SESSION_ID)..."

    if [ "$DRY_RUN" = "true" ]; then
        log_info "[DRY RUN] Would run: $AI_CMD ..."
        if [ "$is_followup" = "true" ] && [ -n "$CURSOR_CHAT_ID" ]; then
            log_info "[DRY RUN] Would resume chat: $CURSOR_CHAT_ID"
        fi
        echo "[DRY RUN] AI CLI would be invoked here" > "$output_file"
        return 0
    fi

    local ai_exit_code=0
    local ai_cmd_full=""
    local provider_lower
    provider_lower=$(echo "$AI_PROVIDER" | tr '[:upper:]' '[:lower:]')

    # Write prompt to temp file to avoid shell escaping issues with special characters
    # This is critical because prompts may contain Swift code with $(), //, etc.
    # Using printf '%s' to avoid echo interpreting escape sequences
    local prompt_file="${LOGS_DIR}/prompt_attempt_${CURRENT_ATTEMPT}.txt"
    printf '%s' "$prompt" > "$prompt_file"

    # Build command based on provider (all use temp file/stdin for safety)
    case "$provider_lower" in
        cursor)
            # cursor-agent reads from stdin when piped
            local cursor_stream_flag=""
            if [ "$STREAM_OUTPUT" = "true" ] && [ "$AI_CMD" = "cursor-agent" ] && [ "$CURSOR_STREAM_SUPPORTED" = "true" ]; then
                cursor_stream_flag="--stream"
            fi

            if [ "$is_followup" = "true" ] && [ -n "$CURSOR_CHAT_ID" ] && [ "$AI_CMD" = "cursor-agent" ]; then
                # Resume existing session
                log_verbose "Resuming Cursor chat session: $CURSOR_CHAT_ID"
                ai_cmd_full="cat \"$prompt_file\" | $AI_CMD --resume \"$CURSOR_CHAT_ID\" --force --print --output-format text $cursor_stream_flag"
            else
                # New session (first attempt)
                ai_cmd_full="cat \"$prompt_file\" | $AI_CMD --force --print --output-format text $cursor_stream_flag"
                log_verbose "Starting new Cursor chat session"
            fi
            ;;

        claude)
            # Claude CLI - pipe from file to avoid escaping issues
            ai_cmd_full="cat \"$prompt_file\" | $AI_CMD --dangerously-skip-permissions -p -"
            log_verbose "Running Claude CLI (with --dangerously-skip-permissions)"
            ;;

        codex|openai)
            # OpenAI/Codex format using 'exec' subcommand for non-interactive mode
            # The 'exec' subcommand reads from stdin when prompt is '-'
            ai_cmd_full="cat \"$prompt_file\" | $AI_CMD exec --full-auto -"
            log_verbose "Running OpenAI/Codex CLI (exec mode with --full-auto)"
            ;;

        gemini|google)
            # Gemini format with yolo flag - pipe from file
            if [ "$AI_CMD" = "gemini" ]; then
                ai_cmd_full="cat \"$prompt_file\" | $AI_CMD generate --yolo"
            else
                ai_cmd_full="cat \"$prompt_file\" | $AI_CMD generate-text --yolo"
            fi
            log_verbose "Running Gemini CLI (with --yolo)"
            ;;

        aider)
            # Aider format - uses --message-file directly (already safe)
            ai_cmd_full="$AI_CMD --yes --message-file \"$prompt_file\""
            log_verbose "Running Aider CLI"
            ;;

        letta)
            # Letta Code - headless mode with -p flag
            # Uses stateful agents with persistent memory per directory
            local letta_flags=""

            # Initialize directory-specific agent (first run creates and pins agent)
            init_letta_directory_agent "$WORK_DIR" || true

            # Auto-approval in YOLO mode
            if [ "${YOLO_MODE:-false}" = "true" ]; then
                letta_flags="--yolo"
            fi

            # Streaming output format for long operations
            if [ "${STREAM_OUTPUT:-false}" = "true" ]; then
                letta_flags="$letta_flags --output-format stream-json"
            fi

            # Model selection if specified (via LETTA_MODEL env var)
            if [ -n "${LETTA_MODEL:-}" ]; then
                letta_flags="$letta_flags --model \"$LETTA_MODEL\""
            fi

            # Self-hosted instance support
            if [ -n "${LETTA_BASE_URL:-}" ]; then
                export LETTA_BASE_URL
            fi

            # Build command - run from WORK_DIR so Letta uses the directory-pinned agent
            # Pipe prompt file to letta with -p flag for headless execution
            ai_cmd_full="cat \"$prompt_file\" | $AI_CMD $letta_flags -p"
            log_verbose "Running Letta Code CLI with directory-specific agent"
            ;;

        copilot|github-copilot)
            # GitHub Copilot CLI - pipe from stdin to avoid argument length limits
            # Requires --allow-all-tools and --allow-all-paths for non-interactive mode
            local copilot_flags="--allow-all-tools --allow-all-paths --silent"
            if [ -n "${AI_MODEL:-}" ]; then
                copilot_flags="$copilot_flags --model \"$AI_MODEL\""
            fi
            # Pipe prompt from file to avoid shell escaping issues and argument limits
            ai_cmd_full="cat \"$prompt_file\" | $AI_CMD $copilot_flags"
            log_verbose "Running GitHub Copilot CLI (piped from stdin)"
            ;;

        *)
            log_error "Unknown AI provider: $AI_PROVIDER"
            return 1
            ;;
    esac

    # Log session info (for tracking purposes)
    if [ "$is_followup" = "true" ]; then
        log_verbose "Follow-up attempt in session: $SESSION_ID"
        if [ -n "$CURSOR_CHAT_ID" ]; then
            log_verbose "Using chat ID: $CURSOR_CHAT_ID"
        fi
    else
        log_verbose "New session: $SESSION_ID"
    fi

    # Run with streaming or spinner
    local spinner_msg="Generating code with ${AI_PROVIDER}"
    [ "$is_followup" = "true" ] && spinner_msg="Fixing code with ${AI_PROVIDER} (attempt $CURRENT_ATTEMPT)"

    if [ "$STREAM_OUTPUT" = "true" ]; then
        # Show status message but DON'T start spinner during streaming (prevents conflicts)
        echo -e "${YELLOW}[STREAMING]${NC} $spinner_msg" >&2
        echo -e "${CYAN}─── ${AI_PROVIDER} CLI Output ───${NC}" >&2
        echo "" >&2

        # Stream with unbuffering - run in WORK_DIR (where user invoked the command)
        if (cd "$WORK_DIR" && run_unbuffered "eval $ai_cmd_full" 2>&1) | unbuffered_tee "$output_file"; then
            ai_exit_code=0
            echo "" >&2
            echo -e "${GREEN}[DONE]${NC} Code generation completed ✓" >&2
        else
            ai_exit_code=$?
            echo "" >&2
            echo -e "${RED}[FAILED]${NC} Code generation failed (exit $ai_exit_code) ✗" >&2
        fi

        echo -e "${CYAN}─── End Output ───${NC}" >&2
        echo "" >&2
    else
        # Non-streaming: use spinner animation
        start_spinner "$spinner_msg"

        # Run in WORK_DIR (where user invoked the command) not PROJECT_ROOT
        if (cd "$WORK_DIR" && eval "$ai_cmd_full" > "$output_file" 2>&1); then
            ai_exit_code=0
            spinner_success "$spinner_msg"
        else
            ai_exit_code=$?
            spinner_error "$spinner_msg"
        fi
    fi

    # Check for authentication errors in the output
    if [ -f "$output_file" ]; then
        local ai_output
        ai_output=$(cat "$output_file")

        if check_auth_error "$ai_output"; then
            # Auth error detected, update session context
            update_session_context "$CURRENT_ATTEMPT" "auth_failed" "Authentication error with $AI_PROVIDER"
            log_error "Please authenticate with $AI_PROVIDER and try again"
            return 1
        fi
    fi

    # On first attempt with Cursor, try to capture the chat ID for future resume
    if [ "$SKIP_CHAT_ID_CAPTURE" = "false" ] && [ "$AI_PROVIDER" = "cursor" ] && [ "$is_followup" = "false" ] && [ -z "$CURSOR_CHAT_ID" ] && [ "$AI_CMD" = "cursor-agent" ] && [ $ai_exit_code -eq 0 ]; then
        log_verbose "Attempting to capture Cursor chat ID..."

        # Show spinner while capturing chat ID (can take a few seconds)
        start_spinner "Capturing chat session ID"
        local new_chat_id
        new_chat_id=$(get_latest_chat_id)
        stop_spinner

        if [ -n "$new_chat_id" ]; then
            CURSOR_CHAT_ID="$new_chat_id"
            # Store in session file for persistence
            echo "Cursor Chat ID: $CURSOR_CHAT_ID" >> "$SESSION_FILE"
            log_verbose "Captured Cursor chat ID: $CURSOR_CHAT_ID"
        else
            log_verbose "Could not capture chat ID (session resume disabled)"
        fi
    elif [ "$SKIP_CHAT_ID_CAPTURE" = "true" ]; then
        log_verbose "Chat ID capture skipped (--skip-chat-id)"
    fi

    # Update session context
    if [ $ai_exit_code -eq 0 ]; then
        update_session_context "$CURRENT_ATTEMPT" "completed" "Code generated successfully with $AI_PROVIDER"
    else
        update_session_context "$CURRENT_ATTEMPT" "failed" "${AI_PROVIDER} CLI exit code: $ai_exit_code"
    fi

    if [ $ai_exit_code -ne 0 ]; then
        log_error "${AI_PROVIDER} CLI failed with exit code: $ai_exit_code"
        return 1
    fi

    log_success "${AI_PROVIDER} CLI completed"
    return 0
}

# ─────────────────────────────────────────────────────────────────────────────
# Multi-Platform Build Orchestration
# ─────────────────────────────────────────────────────────────────────────────

# Run builds for multiple platforms using parallel execution
# Uses xargs for parallel builds when MCP_CALLER=true to avoid circular delegation
run_multi_platform_build() {
    local platforms=("${DETECTED_PLATFORMS[@]}")
    local num_platforms=${#platforms[@]}

    if [ $num_platforms -le 1 ]; then
        # Single platform - run normal build
        return 1  # Signal caller to use normal build path
    fi

    log_info "Multi-platform build: ${platforms[*]}"

    local parallelism="${MULTI_PLATFORM_PARALLELISM:-0}"
    if [ "$parallelism" -eq 0 ]; then
        parallelism=$num_platforms
    fi

    local results_dir="${LOGS_DIR}/platform_results"
    mkdir -p "$results_dir"

    local platform_args=()
    for plat in "${platforms[@]}"; do
        platform_args+=("$plat")
    done

    # Build common arguments for BuildLint
    local common_args=""
    [ -n "${XCODE_WORKSPACE:-}" ] && common_args+=" --workspace \"$XCODE_WORKSPACE\""
    [ -n "${XCODE_PROJECT:-}" ] && [ -z "${XCODE_WORKSPACE:-}" ] && common_args+=" --project \"$XCODE_PROJECT\""
    [ -n "$SCHEME" ] && common_args+=" --scheme \"$SCHEME\""
    [ -n "$BUILD_CONFIGURATION" ] && common_args+=" --configuration \"$BUILD_CONFIGURATION\""
    [ -n "$DERIVED_DATA_PATH" ] && common_args+=" --derived-data \"$DERIVED_DATA_PATH\""
    [ "$SKIP_LINT" = "true" ] && common_args+=" --skip-lint"
    [ "$VERBOSE" = "true" ] && common_args+=" --verbose"
    common_args+=" --json-output"

    local all_passed=true
    local failed_platforms=()
    local passed_platforms=()

    if [ "$MCP_CALLER" = "true" ]; then
        # Called by MCP server - use xargs for parallel builds to avoid circular delegation
        log_info "Running parallel builds via xargs (MCP_CALLER mode)"

        # Create temp script for xargs to execute
        local build_script="${results_dir}/run_platform_build.sh"
        cat > "$build_script" << SCRIPT_EOF
#!/bin/bash
platform="\$1"
plat_safe="\$(echo "\$platform" | tr ' ' '_')"
result_file="$results_dir/\${plat_safe}.json"
log_file="$results_dir/\${plat_safe}.log"
plat_logs_dir="$results_dir/\${plat_safe}"
mkdir -p "\$plat_logs_dir"

# Construct destination from platform name
case "\$platform" in
    "iOS Simulator")
        dest="platform=iOS Simulator,name=iPhone 16"
        ;;
    "macOS")
        dest="platform=macOS"
        ;;
    "watchOS Simulator")
        dest="platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)"
        ;;
    "tvOS Simulator")
        dest="platform=tvOS Simulator,name=Apple TV"
        ;;
    "visionOS Simulator")
        dest="platform=visionOS Simulator,name=Apple Vision Pro"
        ;;
    *)
        dest="platform=\$platform"
        ;;
esac

"$BUILD_LINT_SCRIPT" $common_args --destination "\$dest" --logs-dir "\$plat_logs_dir" > "\$log_file" 2>&1
exit_code=\$?

# Write result JSON
if [ \$exit_code -eq 0 ]; then
    echo '{"platform":"'\$platform'","status":"success","exit_code":0}' > "\$result_file"
else
    echo '{"platform":"'\$platform'","status":"failed","exit_code":'\$exit_code'}' > "\$result_file"
fi

exit \$exit_code
SCRIPT_EOF
        chmod +x "$build_script"

        # Run parallel builds with xargs
        local xargs_exit_code=0
        if [ "$MULTI_PLATFORM_FAIL_FAST" = "true" ]; then
            # Fail fast - stop on first error
            printf '%s\n' "${platform_args[@]}" | xargs -P "$parallelism" -I {} "$build_script" "{}" || xargs_exit_code=$?
        else
            # Continue on error - build all platforms
            printf '%s\n' "${platform_args[@]}" | xargs -P "$parallelism" -I {} sh -c '"$1" "$2" || true' _ "$build_script" "{}"
        fi

        # Collect results
        for plat in "${platforms[@]}"; do
            local result_file="${results_dir}/$(echo "$plat" | tr ' ' '_').json"
            if [ -f "$result_file" ]; then
                local status
                status=$(grep -o '"status":"[^"]*"' "$result_file" | cut -d'"' -f4)
                if [ "$status" = "success" ]; then
                    passed_platforms+=("$plat")
                else
                    failed_platforms+=("$plat")
                    all_passed=false
                fi
            else
                failed_platforms+=("$plat")
                all_passed=false
            fi
        done

    else
        # Standalone mode - run sequential builds (or delegate to MCP if available)
        log_info "Running sequential platform builds"

        for plat in "${platforms[@]}"; do
            log_info "Building for platform: $plat"

            # Show progress
            if type show_progress &>/dev/null && [ "${BUILDAGENT_FANCY_UI:-false}" = "true" ]; then
                local idx=0
                for i in "${!platforms[@]}"; do
                    [ "${platforms[$i]}" = "$plat" ] && idx=$i && break
                done
                show_progress $((idx + 1)) $num_platforms "Platform builds"
            fi

            local plat_log="${results_dir}/$(echo "$plat" | tr ' ' '_').log"
            local plat_result="${results_dir}/$(echo "$plat" | tr ' ' '_').json"
            local plat_logs_dir="${results_dir}/$(echo "$plat" | tr ' ' '_')"
            mkdir -p "$plat_logs_dir"

            # Construct destination
            local dest=""
            case "$plat" in
                "iOS Simulator")
                    dest="platform=iOS Simulator,name=iPhone 16"
                    ;;
                "macOS")
                    dest="platform=macOS"
                    ;;
                "watchOS Simulator")
                    dest="platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)"
                    ;;
                "tvOS Simulator")
                    dest="platform=tvOS Simulator,name=Apple TV"
                    ;;
                "visionOS Simulator")
                    dest="platform=visionOS Simulator,name=Apple Vision Pro"
                    ;;
                *)
                    dest="platform=$plat"
                    ;;
            esac

            local lint_args=("--logs-dir" "$plat_logs_dir" "--destination" "$dest" "--json-output")
            [ -n "${XCODE_WORKSPACE:-}" ] && lint_args+=("--workspace" "$XCODE_WORKSPACE")
            [ -n "${XCODE_PROJECT:-}" ] && [ -z "${XCODE_WORKSPACE:-}" ] && lint_args+=("--project" "$XCODE_PROJECT")
            [ -n "$SCHEME" ] && lint_args+=("--scheme" "$SCHEME")
            [ -n "$BUILD_CONFIGURATION" ] && lint_args+=("--configuration" "$BUILD_CONFIGURATION")
            [ -n "$DERIVED_DATA_PATH" ] && lint_args+=("--derived-data" "$DERIVED_DATA_PATH")
            [ "$SKIP_LINT" = "true" ] && lint_args+=("--skip-lint")
            [ "$VERBOSE" = "true" ] && lint_args+=("--verbose")

            if "$BUILD_LINT_SCRIPT" "${lint_args[@]}" > "$plat_log" 2>&1; then
                passed_platforms+=("$plat")
                echo '{"platform":"'"$plat"'","status":"success","exit_code":0}' > "$plat_result"
                log_success "Platform $plat: BUILD PASSED"
            else
                local exit_code=$?
                failed_platforms+=("$plat")
                all_passed=false
                echo '{"platform":"'"$plat"'","status":"failed","exit_code":'"$exit_code"'}' > "$plat_result"
                log_error "Platform $plat: BUILD FAILED (exit code: $exit_code)"

                if [ "$MULTI_PLATFORM_FAIL_FAST" = "true" ]; then
                    log_warning "Fail-fast enabled, stopping after first failure"
                    break
                fi
            fi
        done
    fi

    # Summary
    echo "" >&2
    log_section "Multi-Platform Build Summary"
    log_section "───────────────────────────────"

    if [ ${#passed_platforms[@]} -gt 0 ]; then
        log_success "Passed: ${passed_platforms[*]}"
    fi
    if [ ${#failed_platforms[@]} -gt 0 ]; then
        log_error "Failed: ${failed_platforms[*]}"
    fi

    # Output JSON summary if requested
    if [ "$JSON_OUTPUT" = "true" ]; then
        local json_results="["
        local first=true
        for plat in "${platforms[@]}"; do
            local result_file="${results_dir}/$(echo "$plat" | tr ' ' '_').json"
            if [ -f "$result_file" ]; then
                [ "$first" = "false" ] && json_results+=","
                json_results+=$(cat "$result_file")
                first=false
            fi
        done
        json_results+="]"
        echo "$json_results"
    fi

    if [ "$all_passed" = "true" ]; then
        return 0
    else
        return 10
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Build Verification Functions
# ─────────────────────────────────────────────────────────────────────────────

# Run BuildLint.sh and capture results
run_build_lint() {
    local lint_log="${LOGS_DIR}/buildlint_attempt_${CURRENT_ATTEMPT}.log"
    local lint_exit_code=0

    log_attempt "Running BuildLint.sh..."

    if [ "$DRY_RUN" = "true" ]; then
        log_info "[DRY RUN] Would run: BuildLint.sh"
        echo "[DRY RUN] BuildLint.sh would be invoked here" > "$lint_log"
        return 0
    fi

    # Check for multi-platform build (when multiple platforms detected and no specific platform requested)
    if [ ${#DETECTED_PLATFORMS[@]} -gt 1 ] && [ -z "$PLATFORM" ] && [ -z "$DESTINATION" ] && [ -z "$TARGET_ID" ]; then
        log_info "Multiple platforms detected, running multi-platform build..."
        if run_multi_platform_build; then
            # Pick a canonical BUILT_PRODUCTS_DIR from multi-platform results.
            # All BuildLint invocations share the same --logs-dir ($results_dir), so each
            # platform writes to the flat built_products_dir.txt in that directory.
            # For sequential builds the last successful platform wins (deterministic).
            local mp_results_dir="${LOGS_DIR}/platform_results"
            local mp_built_products_file="${mp_results_dir}/built_products_dir.txt"
            BUILT_PRODUCTS_DIR_CAPTURED=""

            if [ -f "$mp_built_products_file" ]; then
                BUILT_PRODUCTS_DIR_CAPTURED=$(cat "$mp_built_products_file")
                log_verbose "BUILT_PRODUCTS_DIR_CAPTURED (multi-platform): $BUILT_PRODUCTS_DIR_CAPTURED"
            else
                log_error "Multi-platform build succeeded but no built_products_dir.txt found in ${mp_results_dir}"
            fi
            return 0
        else
            return 10
        fi
    fi

    # Build BuildLint.sh arguments
    local lint_args=()
    lint_args+=("--logs-dir" "$LOGS_DIR")

    # Pass the Xcode project/workspace if we detected it
    if [ -n "${XCODE_WORKSPACE:-}" ]; then
        lint_args+=("--workspace" "$XCODE_WORKSPACE")
    elif [ -n "${XCODE_PROJECT:-}" ]; then
        lint_args+=("--project" "$XCODE_PROJECT")
    fi

    if [ -n "$TARGET_ID" ]; then
        lint_args+=("--target-id" "$TARGET_ID")
    fi

    if [ -n "$DESTINATION" ]; then
        lint_args+=("--destination" "$DESTINATION")
    fi

    if [ -n "$SCHEME" ]; then
        lint_args+=("--scheme" "$SCHEME")
    fi

    if [ -n "$BUILD_CONFIGURATION" ]; then
        lint_args+=("--configuration" "$BUILD_CONFIGURATION")
    fi

    if [ -n "$DERIVED_DATA_PATH" ]; then
        lint_args+=("--derived-data" "$DERIVED_DATA_PATH")
    fi

    if [ "$SKIP_LINT" = "true" ]; then
        lint_args+=("--skip-lint")
    fi

    if [ "$VERBOSE" = "true" ]; then
        lint_args+=("--verbose")
    fi

    # Debug: Show what we're passing to BuildLint
    if [ "$VERBOSE" = "true" ]; then
        log_verbose "BuildLint arguments: ${lint_args[*]}"
        log_verbose "XCODE_WORKSPACE=${XCODE_WORKSPACE:-<not set>}"
        log_verbose "XCODE_PROJECT=${XCODE_PROJECT:-<not set>}"
    fi

    # Run BuildLint.sh with spinner or streaming
    local build_spinner_msg="Building and verifying"

    if [ "$STREAM_OUTPUT" = "true" ]; then
        # Show status message but DON'T start spinner during streaming
        echo -e "${YELLOW}[STREAMING]${NC} $build_spinner_msg" >&2
        echo -e "${CYAN}─── BuildLint Output ───${NC}" >&2
        echo "" >&2

        # Stream output with unbuffering
        if run_unbuffered "\"$BUILD_LINT_SCRIPT\" ${lint_args[*]}" 2>&1 | unbuffered_tee "$lint_log"; then
            lint_exit_code=0
        else
            lint_exit_code=$?
        fi

        echo "" >&2
        echo -e "${CYAN}─── End BuildLint ───${NC}" >&2
        echo "" >&2
    else
        # Non-streaming: use spinner
        start_spinner "$build_spinner_msg"

        if "$BUILD_LINT_SCRIPT" "${lint_args[@]}" > "$lint_log" 2>&1; then
            lint_exit_code=0
        else
            lint_exit_code=$?
        fi

        # Don't show success/error here yet - we need to check for error.log first
        stop_spinner
    fi

    # Check for error.log (BuildLint writes directly to our LOGS_DIR now)
    if [ -f "${LOGS_DIR}/error.log" ]; then
        # Rename to include attempt number for tracking
        mv "${LOGS_DIR}/error.log" "${LOGS_DIR}/error_attempt_${CURRENT_ATTEMPT}.log"
        lint_exit_code=10
    fi

    if [ $lint_exit_code -eq 0 ]; then
        echo -e "${GREEN}[DONE]${NC} $build_spinner_msg ${GREEN}✓${NC}" >&2
        log_success "Build verification passed"
        # Read BUILT_PRODUCTS_DIR written by BuildLint.sh after successful build
        local built_products_dir_file="${LOGS_DIR}/built_products_dir.txt"
        if [ -f "$built_products_dir_file" ]; then
            BUILT_PRODUCTS_DIR_CAPTURED=$(cat "$built_products_dir_file")
            log_verbose "BUILT_PRODUCTS_DIR_CAPTURED: $BUILT_PRODUCTS_DIR_CAPTURED"
        fi
        return 0
    else
        echo -e "${RED}[FAILED]${NC} $build_spinner_msg ${RED}✗${NC}" >&2
        log_error "Build verification failed (exit code: $lint_exit_code)"
        return $lint_exit_code
    fi
}

# Get error content for feedback
get_error_feedback() {
    local error_file="${LOGS_DIR}/error_attempt_${CURRENT_ATTEMPT}.log"

    if [ -f "$error_file" ]; then
        cat "$error_file"
    else
        echo "Build failed but no detailed error log available."
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Status File Functions
# ─────────────────────────────────────────────────────────────────────────────

write_success_status() {
    local status_file="${STATUS_DIR}/success.txt"

    cat > "$status_file" << EOF
Build Agent Completed Successfully
===================================
Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
Attempts: $CURRENT_ATTEMPT
Scheme: ${SCHEME:-auto-detected}
Configuration: $BUILD_CONFIGURATION

Artifacts:
- Build log: ${LOGS_DIR}/build.log
- Coder logs: ${LOGS_DIR}/coder_attempt_*.log
EOF

    log_success "Status written to: $status_file"

    # Write build_output.txt with the .app path for downstream consumers (e.g. test runners)
    if [ -n "$BUILT_PRODUCTS_DIR_CAPTURED" ] && [ -n "$SCHEME" ]; then
        local app_path="${BUILT_PRODUCTS_DIR_CAPTURED}/${SCHEME}.app"
        echo "$app_path" > "${ARTIFACTS_RUN_DIR:-$STATUS_DIR}/build_output.txt"
        log_success "build_output.txt written: $app_path"
    else
        log_warning "build_output.txt not written: BUILT_PRODUCTS_DIR_CAPTURED or SCHEME is empty"
    fi

    # Store success to Letta memory
    store_build_result "success"

    # Prompt to persist frequently-used flags as session defaults
    if type session_should_offer_persist &>/dev/null && type session_set_default &>/dev/null && type session_save &>/dev/null; then
        local prompted_any=false

        # Check scheme
        if [ -n "${user_provided_scheme:-}" ]; then
            if [ "$(session_should_offer_persist "--scheme" "$user_provided_scheme")" = "true" ]; then
                echo "" >&2
                log_info "You've used --scheme $user_provided_scheme multiple times recently."
                read -p "Save --scheme $user_provided_scheme as default? (y/N) " -n 1 -r save
                echo "" >&2
                if [[ $save =~ ^[Yy]$ ]]; then
                    session_set_default "scheme" "$user_provided_scheme"
                    prompted_any=true
                    log_success "Saved scheme as default"
                fi
            fi
        fi

        # Check configuration
        if [ -n "${user_provided_configuration:-}" ]; then
            if [ "$(session_should_offer_persist "--configuration" "$user_provided_configuration")" = "true" ]; then
                echo "" >&2
                log_info "You've used --configuration $user_provided_configuration multiple times recently."
                read -p "Save --configuration $user_provided_configuration as default? (y/N) " -n 1 -r save
                echo "" >&2
                if [[ $save =~ ^[Yy]$ ]]; then
                    session_set_default "configuration" "$user_provided_configuration"
                    prompted_any=true
                    log_success "Saved configuration as default"
                fi
            fi
        fi

        # Check platform
        if [ -n "${user_provided_platform:-}" ]; then
            if [ "$(session_should_offer_persist "--platform" "$user_provided_platform")" = "true" ]; then
                echo "" >&2
                log_info "You've used --platform $user_provided_platform multiple times recently."
                read -p "Save --platform $user_provided_platform as default? (y/N) " -n 1 -r save
                echo "" >&2
                if [[ $save =~ ^[Yy]$ ]]; then
                    session_set_default "platform" "$user_provided_platform"
                    prompted_any=true
                    log_success "Saved platform as default"
                fi
            fi
        fi

        # Check AI provider
        if [ -n "${user_provided_ai_provider:-}" ]; then
            if [ "$(session_should_offer_persist "--ai-provider" "$user_provided_ai_provider")" = "true" ]; then
                echo "" >&2
                log_info "You've used --ai-provider $user_provided_ai_provider multiple times recently."
                read -p "Save --ai-provider $user_provided_ai_provider as default? (y/N) " -n 1 -r save
                echo "" >&2
                if [[ $save =~ ^[Yy]$ ]]; then
                    session_set_default "ai_provider" "$user_provided_ai_provider"
                    prompted_any=true
                    log_success "Saved AI provider as default"
                fi
            fi
        fi

        # Save session if any defaults were updated
        if [ "$prompted_any" = true ]; then
            session_save
            log_info "Session defaults saved to .foundation-session.json"
        fi
    fi
}

write_human_intervention() {
    local status_file="${STATUS_DIR}/human_intervention.md"
    local all_errors=""

    # Collect all error logs
    for error_log in "${LOGS_DIR}"/error_attempt_*.log; do
        if [ -f "$error_log" ]; then
            all_errors+="
### $(basename "$error_log")
\`\`\`
$(cat "$error_log")
\`\`\`
"
        fi
    done

    cat > "$status_file" << EOF
# Human Intervention Required

## Summary
Build Agent failed after $MAX_REPAIR_ATTEMPTS repair attempts.

## Timestamp
$(date -u +"%Y-%m-%dT%H:%M:%SZ")

## Configuration
- Scheme: ${SCHEME:-auto-detected}
- Configuration: $BUILD_CONFIGURATION
- Target: ${TARGET_ID:-${DESTINATION:-default simulator}}

## Input
$(get_input_content | head -50)
...

## Error History
$all_errors

## Recommendations
1. Review the error logs above
2. Check for missing dependencies or configuration issues
3. Manually fix the problematic code
4. Re-run the build agent after fixes

## Artifacts Location
\`${LOGS_DIR}\`

---
*Generated by BuildAgent - Phase 5*
EOF

    log_error "Human intervention required: $status_file"

    # Also emit to errors directory if available
    if [ -d "${PROJECT_ROOT}/.foundation/errors" ]; then
        cp "$status_file" "${PROJECT_ROOT}/.foundation/errors/human_intervention_$(date +%Y%m%d_%H%M%S).md"
    fi

    # Store failure to Letta memory
    store_build_result "failure" "$all_errors"
}

# ─────────────────────────────────────────────────────────────────────────────
# Error-Driven Repair Loop (when no plan provided but build fails)
# ─────────────────────────────────────────────────────────────────────────────

run_repair_loop_with_errors() {
    local initial_errors="$1"
    local context
    local error_feedback="$initial_errors"
    local is_followup="false"

    context=$(gather_context)

    # Retrieve memory context from Letta if available
    retrieve_memory_context

    log_info "Context length: ${#context} chars"
    log_info "Initial errors length: ${#initial_errors} chars"
    [ -n "$LETTA_MEMORY_CONTEXT" ] && log_info "Memory context: available"

    while [ $CURRENT_ATTEMPT -lt $MAX_REPAIR_ATTEMPTS ]; do
        CURRENT_ATTEMPT=$((CURRENT_ATTEMPT + 1))

        echo "" >&2
        log_section "────────────────────────────────────────"
        log_attempt "Starting repair cycle"
        log_section "────────────────────────────────────────"

        # Create AI prompt with build errors as input
        local prompt_content
        if [ "$is_followup" = "true" ]; then
            prompt_content="Previous fix attempt failed. Here are the remaining build errors:

$error_feedback

Please analyze and fix these errors."
        else
            prompt_content="The build failed with the following errors. Please fix them:

$error_feedback

Project context:
$context"
        fi

        # Acquire write lock before AI code generation
        if ! acquire_write_access; then
            log_error "Failed to acquire write lock"
            update_session_context "$CURRENT_ATTEMPT" "queue_timeout" "Write lock timeout"
            is_followup="true"
            continue
        fi

        # Generate code with AI
        if ! run_ai_cli "$prompt_content"; then
            release_write_access
            update_session_context "$CURRENT_ATTEMPT" "ai_error" "AI CLI failed"
            log_error "AI CLI call failed"
            # Note: run_ai_cli handles auth error detection internally
            # Continue to next attempt
            is_followup="true"
            continue
        fi

        release_write_access
        update_session_context "$CURRENT_ATTEMPT" "ai_success" "AI code generated"

        # Acquire build lock before verification
        if ! acquire_build_access; then
            log_error "Failed to acquire build lock"
            update_session_context "$CURRENT_ATTEMPT" "queue_timeout" "Build lock timeout"
            is_followup="true"
            continue
        fi

        # Verify build
        if run_build_lint; then
            release_build_access
            # Success!
            update_session_context "$CURRENT_ATTEMPT" "success" "Build passed"
            write_success_status
            return 0
        fi

        release_build_access

        # Build still failing - get new errors
        error_feedback=$(get_error_feedback)
        update_session_context "$CURRENT_ATTEMPT" "build_failed" "$error_feedback"

        log_warning "Build still failing, will retry..."
        is_followup="true"
    done

    # Exhausted all attempts
    log_error "Maximum repair attempts ($MAX_REPAIR_ATTEMPTS) reached"
    write_human_intervention
    return 10
}

# ─────────────────────────────────────────────────────────────────────────────
# Argent UI-Error Repair Loop (--repair-from-errors <file>)
# ─────────────────────────────────────────────────────────────────────────────

run_repair_loop_with_argent_errors() {
    local errors_file="$REPAIR_FROM_ERRORS_FILE"
    local context
    local error_feedback=""
    local is_followup="false"

    # Validate jq is available
    if ! command -v jq &>/dev/null; then
        log_error "jq is required for --repair-from-errors but was not found"
        return 11
    fi

    # Ensure an AI provider was successfully detected; detect_ai_provider() is called
    # via validate_inputs() when REPAIR_FROM_ERRORS_FILE is set, but guard here explicitly
    # so the function never silently enters the loop with an empty AI_CMD.
    if [ -z "$AI_CMD" ]; then
        if ! detect_ai_provider; then
            log_error "--repair-from-errors requires a configured AI provider; none available (exit 11)"
            return 11
        fi
    fi

    # Validate and parse the errors JSON file
    if ! jq empty "$errors_file" 2>/dev/null; then
        log_error "Invalid JSON in errors file: $errors_file"
        return 11
    fi

    local error_count
    error_count=$(jq '.errors | length' "$errors_file" 2>/dev/null || echo "0")
    if [ "$error_count" -eq 0 ]; then
        log_warning "No errors found in $errors_file — nothing to repair"
        return 0
    fi

    local source_name
    source_name=$(jq -r '.source // "unknown"' "$errors_file")
    local timestamp
    timestamp=$(jq -r '.timestamp // "unknown"' "$errors_file")

    log_info "Argent error repair: $error_count error(s) from $source_name (recorded $timestamp)"

    context=$(gather_context)
    retrieve_memory_context

    log_info "Context length: ${#context} chars"
    [ -n "$LETTA_MEMORY_CONTEXT" ] && log_info "Memory context: available"

    while [ $CURRENT_ATTEMPT -lt $MAX_REPAIR_ATTEMPTS ]; do
        CURRENT_ATTEMPT=$((CURRENT_ATTEMPT + 1))

        echo "" >&2
        log_section "────────────────────────────────────────"
        log_attempt "Starting argent UI repair cycle"
        log_section "────────────────────────────────────────"

        # Build the UI-specific prompt from the parsed errors
        local errors_block
        errors_block=$(jq -r '
          .errors[] |
          "--- Error in flow: \(.flow // "unknown") | Step: \(.step // "?") | Action: \(.action // "?") ---\n" +
          "Target element: \(.element // "?")\n" +
          "Error: \(.error // "?")\n" +
          "Screenshot path: \(.screenshot // "none")\n" +
          "Element tree snapshot:\n\(.elementTree // "(not available)")\n"
        ' "$errors_file" 2>/dev/null || echo "(could not parse errors)")

        local prompt_content
        if [ "$is_followup" = "false" ]; then
            prompt_content="A UI test recorded the following failures. Each failure indicates an element could not be found or an action could not be performed. Fix the SwiftUI/UIKit source so that each element is present and reachable.

For each missing element, the most common fix is to add \`.accessibilityIdentifier(\"<element>\")\` to the relevant view. For elements that exist but are not interactable, check the UI state (e.g. hidden, disabled, or covered by another view).

$errors_block

Project context:
$context"
        else
            prompt_content="The previous fix attempt did not resolve all UI test failures. Here is the updated build feedback:

$error_feedback

The original UI test errors were:

$errors_block

Please re-examine the relevant views and ensure every listed element has the correct .accessibilityIdentifier and is visible/enabled in the expected state."
        fi

        # Acquire write lock before AI code generation
        if ! acquire_write_access; then
            log_error "Failed to acquire write lock"
            update_session_context "$CURRENT_ATTEMPT" "queue_timeout" "Write lock timeout"
            is_followup="true"
            continue
        fi

        # Generate code with AI
        if ! run_ai_cli "$prompt_content"; then
            release_write_access
            update_session_context "$CURRENT_ATTEMPT" "ai_error" "AI CLI failed"
            log_error "AI CLI call failed"
            is_followup="true"
            continue
        fi

        release_write_access
        update_session_context "$CURRENT_ATTEMPT" "ai_success" "AI code generated"

        # Acquire build lock before verification
        if ! acquire_build_access; then
            log_error "Failed to acquire build lock"
            update_session_context "$CURRENT_ATTEMPT" "queue_timeout" "Build lock timeout"
            is_followup="true"
            continue
        fi

        # Verify build
        if run_build_lint; then
            release_build_access
            update_session_context "$CURRENT_ATTEMPT" "success" "Build passed"
            write_success_status
            return 0
        fi

        release_build_access

        # Build still failing — get new errors for next iteration
        error_feedback=$(get_error_feedback)
        update_session_context "$CURRENT_ATTEMPT" "build_failed" "$error_feedback"

        log_warning "Build still failing, will retry..."
        is_followup="true"
    done

    # Exhausted all attempts
    log_error "Maximum repair attempts ($MAX_REPAIR_ATTEMPTS) reached"
    write_human_intervention
    return 10
}

# ─────────────────────────────────────────────────────────────────────────────
# Auto-Detect Mode (no plan provided - lint/build first, AI repair if needed)
# ─────────────────────────────────────────────────────────────────────────────

run_lint_only() {
    log_section "Running initial lint/build check (no plan provided)"
    echo "" >&2

    CURRENT_ATTEMPT=0

    # Initialize session context file
    {
        echo "# Build Session: $SESSION_ID"
        echo "Started: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
        echo "Mode: Auto-detect (lint/build first, AI repair if needed)"
        echo "Max attempts: $MAX_REPAIR_ATTEMPTS"
        echo "AI Provider: $AI_PROVIDER"
        echo ""
    } > "$SESSION_FILE"

    # Acquire build lock for initial verification
    if ! acquire_build_access; then
        log_warning "Could not acquire build lock, waiting..."
    fi

    # Run initial build verification
    if run_build_lint; then
        release_build_access
        # Success! No errors to fix
        update_session_context "0" "success" "Build passed - no errors to fix"
        write_success_status
        log_success "Build passed! No errors detected."
        return 0
    fi

    release_build_access

    # Build failed - use errors as input for AI repair loop
    local error_feedback
    error_feedback=$(get_error_feedback)
    update_session_context "0" "build_failed" "$error_feedback"

    log_warning "Build errors detected - starting AI repair loop"
    log_info "Using build errors as AI input"
    echo "" >&2

    # Detect AI provider before repair loop (was skipped during validation in lint-only mode)
    if ! detect_ai_provider; then
        log_error "Cannot start repair loop: AI provider '$AI_PROVIDER' not available"
        write_human_intervention
        return 11
    fi

    # Transition to repair loop with errors as input
    # Set the error_feedback as initial context for the loop
    run_repair_loop_with_errors "$error_feedback"
    return $?
}

# ─────────────────────────────────────────────────────────────────────────────
# Main Execution Loop
# ─────────────────────────────────────────────────────────────────────────────

run_build_loop() {
    # Handle argent UI-error repair mode
    if [ -n "$REPAIR_FROM_ERRORS_FILE" ]; then
        run_repair_loop_with_argent_errors
        return $?
    fi

    # Handle lint-only mode
    if [ "$LINT_ONLY_MODE" = "true" ]; then
        run_lint_only
        return $?
    fi

    local input_content
    local context
    local error_feedback=""
    local is_followup="false"

    input_content=$(get_input_content)
    context=$(gather_context)

    # Retrieve memory context from Letta if available
    retrieve_memory_context

    log_info "Input length: ${#input_content} chars"
    log_info "Context length: ${#context} chars"
    [ -n "$LETTA_MEMORY_CONTEXT" ] && log_info "Memory context: available"
    log_info "Session ID: $SESSION_ID"

    # Initialize session context file
    {
        echo "# Build Session: $SESSION_ID"
        echo "Started: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
        echo "Max attempts: $MAX_REPAIR_ATTEMPTS"
        echo "AI Provider: $AI_PROVIDER"
        echo "AI CLI Command: $AI_CMD"
        if [ -n "$CURSOR_CHAT_ID" ]; then
            echo "Cursor Chat ID: $CURSOR_CHAT_ID"
        fi
        echo ""
    } > "$SESSION_FILE"

    while [ $CURRENT_ATTEMPT -lt $MAX_REPAIR_ATTEMPTS ]; do
        CURRENT_ATTEMPT=$((CURRENT_ATTEMPT + 1))

        echo "" >&2
        log_section "────────────────────────────────────────"
        log_attempt "Starting build cycle"
        log_section "────────────────────────────────────────"
        echo "" >&2

        # Build prompt based on whether this is first attempt or follow-up
        local prompt
        if [ "$is_followup" = "false" ]; then
            # First attempt: full context
            prompt=$(build_initial_prompt "$input_content" "$context")
        else
            # Follow-up: include original task + error feedback (no cursor session memory)
            prompt=$(build_followup_prompt "$error_feedback" "$CURRENT_ATTEMPT" "$input_content" "$context")
        fi

        # Acquire write lock before code generation (prevents concurrent modifications)
        if ! acquire_write_access; then
            log_error "Failed to acquire write lock - another agent may be stuck"
            error_feedback="Build coordination timeout. Another agent may be stuck."
            update_session_context "$CURRENT_ATTEMPT" "queue_timeout" "$error_feedback"
            is_followup="true"
            continue
        fi

        # Run AI CLI with session
        if ! run_ai_cli "$prompt" "$is_followup"; then
            release_write_access  # Release lock on failure
            log_error "${AI_PROVIDER} CLI failed"
            error_feedback="${AI_PROVIDER} CLI invocation failed. Please try again."
            update_session_context "$CURRENT_ATTEMPT" "cursor_failed" "$error_feedback"
            is_followup="true"
            continue
        fi

        # Release write lock, acquire build lock (allows other agents to queue up)
        release_write_access

        if ! acquire_build_access; then
            log_error "Failed to acquire build lock - another agent may be stuck"
            error_feedback="Build coordination timeout during build phase."
            update_session_context "$CURRENT_ATTEMPT" "queue_timeout" "$error_feedback"
            is_followup="true"
            continue
        fi

        # Run build verification
        local build_result=0
        if run_build_lint; then
            release_build_access  # Release lock after build
            # Success!
            update_session_context "$CURRENT_ATTEMPT" "success" "Build passed"
            write_success_status
            return 0
        fi

        release_build_access  # Release lock after build (even on failure)

        # Get error feedback for next attempt
        error_feedback=$(get_error_feedback)
        update_session_context "$CURRENT_ATTEMPT" "build_failed" "$error_feedback"

        # Mark as follow-up for next iteration
        is_followup="true"

        if [ $CURRENT_ATTEMPT -lt $MAX_REPAIR_ATTEMPTS ]; then
            log_warning "Build failed, continuing session with error feedback..."
        fi
    done

    # Max attempts reached
    log_error "Build failed after $MAX_REPAIR_ATTEMPTS attempts"
    write_human_intervention
    return 20
}

# ─────────────────────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────────────────────

main() {
    local read_stdin=false

    # Track which flags were explicitly provided by user
    local user_provided_scheme=""
    local user_provided_configuration=""
    local user_provided_platform=""
    local user_provided_ai_provider=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --plan)
                PLAN_FILE="${2:-}"
                shift 2
                ;;
            --prompt)
                PROMPT_FILE="${2:-}"
                shift 2
                ;;
            --prompt-string)
                PROMPT_STRING="${2:-}"
                shift 2
                ;;
            --stdin)
                read_stdin=true
                shift 1
                ;;
            --context)
                CONTEXT_PATHS+=("${2:-}")
                shift 2
                ;;
            --swift-docs)
                SWIFT_DOCS_PATH="${2:-}"
                shift 2
                ;;
            --no-swift-docs)
                SWIFT_DOCS_PATH="DISABLED"
                shift 1
                ;;
            --no-smart-docs)
                SMART_DOCS="false"
                shift 1
                ;;
            --ai-provider)
                AI_PROVIDER="${2:-}"
                user_provided_ai_provider="$AI_PROVIDER"
                shift 2
                ;;
            --ai-model)
                AI_MODEL="${2:-}"
                shift 2
                ;;
            --target-id)
                TARGET_ID="${2:-}"
                shift 2
                ;;
            --destination)
                DESTINATION="${2:-}"
                shift 2
                ;;
            --scheme)
                SCHEME="${2:-}"
                user_provided_scheme="$SCHEME"
                shift 2
                ;;
            --configuration)
                BUILD_CONFIGURATION="${2:-}"
                user_provided_configuration="$BUILD_CONFIGURATION"
                shift 2
                ;;
            --derived-data)
                DERIVED_DATA_PATH="${2:-}"
                shift 2
                ;;
            --skip-lint)
                SKIP_LINT="true"
                shift 1
                ;;
            --max-attempts)
                MAX_REPAIR_ATTEMPTS="${2:-3}"
                shift 2
                ;;
            --artifacts-dir)
                ARTIFACTS_DIR="${2:-}"
                shift 2
                ;;
            --stream)
                STREAM_OUTPUT="true"
                shift 1
                ;;
            --skip-chat-id)
                SKIP_CHAT_ID_CAPTURE="true"
                shift 1
                ;;
            --dry-run)
                DRY_RUN="true"
                shift 1
                ;;
            --verbose|-v)
                VERBOSE="true"
                shift 1
                ;;
            --yolo)
                YOLO_MODE="true"
                VERBOSE="true"
                SKIP_CHAT_ID_CAPTURE="true"
                STREAM_OUTPUT="true"
                # Increase max attempts to 5 for YOLO mode (unless already set)
                if [ "$MAX_REPAIR_ATTEMPTS" = "3" ]; then
                    MAX_REPAIR_ATTEMPTS="5"
                fi
                log_info "YOLO mode enabled: verbose + skip-chat-id + streaming + max-attempts=${MAX_REPAIR_ATTEMPTS}"
                shift 1
                ;;
            --quiet|-q)
                LOG_LEVEL="error"
                BUILDAGENT_FANCY_UI="false"
                VERBOSE="false"
                shift 1
                ;;
            --debug)
                LOG_LEVEL="debug"
                VERBOSE="true"
                shift 1
                ;;
            --no-fancy-ui)
                BUILDAGENT_FANCY_UI="false"
                shift 1
                ;;
            --fancy-ui)
                BUILDAGENT_FANCY_UI="true"
                shift 1
                ;;
            --no-defaults)
                LOAD_DEFAULTS="false"
                shift 1
                ;;
            --session-show)
                # Display current session defaults
                if type session_get_all_defaults &>/dev/null && type session_load &>/dev/null; then
                    session_load || true

                    if [ "$JSON_OUTPUT" = "true" ]; then
                        local defaults_json
                        defaults_json=$(session_get_all_defaults | jq '.' 2>/dev/null || echo "{}")
                        echo "{\"success\":true,\"output\":\"$defaults_json\",\"error\":null,\"duration\":0,\"metadata\":$defaults_json,\"exitCode\":0}"
                    else
                        # Use draw_box if available, otherwise plain output
                        if type draw_box &>/dev/null && type select_theme &>/dev/null; then
                            select_theme "${BUILDAGENT_THEME:-dark}"
                            local defaults_json
                            defaults_json=$(session_get_all_defaults | jq '.' 2>/dev/null || session_get_all_defaults)
                            local defaults_display
                            defaults_display=$(echo "$defaults_json" | jq -r 'to_entries | .[] | "\(.key): \(.value)"' 2>/dev/null || echo "No defaults set")

                            if [ -z "$defaults_display" ] || [ "$defaults_display" = "{}" ]; then
                                defaults_display="No session defaults set"
                            fi

                            draw_box "Defaults" "$defaults_display"
                        else
                            session_get_all_defaults | jq '.' 2>/dev/null || session_get_all_defaults
                        fi
                    fi
                else
                    if [ "$JSON_OUTPUT" = "true" ]; then
                        echo "{\"success\":false,\"output\":\"\",\"error\":\"Session management not available (jq required)\",\"duration\":0,\"metadata\":{},\"exitCode\":1}"
                    else
                        echo "Session management not available (jq required)" >&2
                    fi
                    exit 1
                fi
                exit 0
                ;;
            --session-clear)
                # Clear specific default
                local key_to_clear="${2:-}"
                if [ -z "$key_to_clear" ]; then
                    if [ "$JSON_OUTPUT" = "true" ]; then
                        echo "{\"success\":false,\"output\":\"\",\"error\":\"--session-clear requires a key name\",\"duration\":0,\"metadata\":{},\"exitCode\":11}"
                    else
                        echo -e "${RED}[ERROR]${NC} --session-clear requires a key name" >&2
                    fi
                    exit 11
                fi
                if type session_set_default &>/dev/null && type session_save &>/dev/null && type session_load &>/dev/null; then
                    session_load || true
                    session_set_default "$key_to_clear" ""
                    session_save
                    if [ "$JSON_OUTPUT" = "true" ]; then
                        echo "{\"success\":true,\"output\":\"Cleared session default: $key_to_clear\",\"error\":null,\"duration\":0,\"metadata\":{\"key\":\"$key_to_clear\"},\"exitCode\":0}"
                    else
                        echo -e "${GREEN}[SUCCESS]${NC} Cleared session default: $key_to_clear" >&2
                    fi
                else
                    if [ "$JSON_OUTPUT" = "true" ]; then
                        echo "{\"success\":false,\"output\":\"\",\"error\":\"Session management not available (jq required)\",\"duration\":0,\"metadata\":{},\"exitCode\":1}"
                    else
                        echo -e "${RED}[ERROR]${NC} Session management not available (jq required)" >&2
                    fi
                    exit 1
                fi
                shift  # consume the key argument
                exit 0
                ;;
            --session-clear-all)
                # Clear all session defaults
                if type session_clear &>/dev/null && type session_save &>/dev/null; then
                    session_clear
                    session_save
                    if [ "$JSON_OUTPUT" = "true" ]; then
                        echo "{\"success\":true,\"output\":\"All session defaults cleared\",\"error\":null,\"duration\":0,\"metadata\":{},\"exitCode\":0}"
                    else
                        echo -e "${GREEN}[SUCCESS]${NC} All session defaults cleared" >&2
                    fi
                else
                    if [ "$JSON_OUTPUT" = "true" ]; then
                        echo "{\"success\":false,\"output\":\"\",\"error\":\"Session management not available (jq required)\",\"duration\":0,\"metadata\":{},\"exitCode\":1}"
                    else
                        echo -e "${RED}[ERROR]${NC} Session management not available (jq required)" >&2
                    fi
                    exit 1
                fi
                exit 0
                ;;
            --platform)
                # Multi-platform support - build for specific platform
                PLATFORM="${2:-}"
                user_provided_platform="$PLATFORM"
                shift 2
                ;;
            --fail-fast)
                MULTI_PLATFORM_FAIL_FAST="true"
                shift 1
                ;;
            --continue-on-error)
                MULTI_PLATFORM_FAIL_FAST="false"
                shift 1
                ;;
            --json-output)
                JSON_OUTPUT="true"
                shift 1
                ;;
            --session-set)
                # Set a session default: --session-set key=value
                local kv="${2:-}"
                if [ -z "$kv" ]; then
                    echo -e "${RED}[ERROR]${NC} --session-set requires key=value" >&2
                    exit 11
                fi
                if type session_set_default &>/dev/null && type session_save &>/dev/null && type session_load &>/dev/null; then
                    session_load || true
                    local key="${kv%%=*}"
                    local value="${kv#*=}"
                    session_set_default "$key" "$value"
                    session_save
                    if [ "$JSON_OUTPUT" = "true" ]; then
                        echo "{\"success\":true,\"output\":\"Set session default: $key=$value\",\"error\":null,\"duration\":0,\"metadata\":{\"key\":\"$key\",\"value\":\"$value\"},\"exitCode\":0}"
                    else
                        echo -e "${GREEN}[SUCCESS]${NC} Set session default: $key=$value" >&2
                    fi
                else
                    if [ "$JSON_OUTPUT" = "true" ]; then
                        echo "{\"success\":false,\"output\":\"\",\"error\":\"Session management not available (jq required)\",\"duration\":0,\"metadata\":{},\"exitCode\":1}"
                    else
                        echo -e "${RED}[ERROR]${NC} Session management not available (jq required)" >&2
                    fi
                    exit 1
                fi
                shift 2
                exit 0
                ;;
            --session-get)
                # Get a session default: --session-get key
                local key="${2:-}"
                if [ -z "$key" ]; then
                    echo -e "${RED}[ERROR]${NC} --session-get requires a key name" >&2
                    exit 11
                fi
                if type session_get_default &>/dev/null && type session_load &>/dev/null; then
                    session_load || true
                    local value
                    value=$(session_get_default "$key")
                    if [ "$JSON_OUTPUT" = "true" ]; then
                        echo "{\"success\":true,\"output\":\"$value\",\"error\":null,\"duration\":0,\"metadata\":{\"key\":\"$key\",\"value\":\"$value\"},\"exitCode\":0}"
                    else
                        echo "$value"
                    fi
                else
                    if [ "$JSON_OUTPUT" = "true" ]; then
                        echo "{\"success\":false,\"output\":\"\",\"error\":\"Session management not available (jq required)\",\"duration\":0,\"metadata\":{},\"exitCode\":1}"
                    else
                        echo -e "${RED}[ERROR]${NC} Session management not available (jq required)" >&2
                    fi
                    exit 1
                fi
                shift 2
                exit 0
                ;;
            --repair-from-errors)
                if [ -z "${2:-}" ]; then
                    log_error "--repair-from-errors requires a file path argument"
                    exit 11
                fi
                if [ ! -f "$2" ]; then
                    log_error "--repair-from-errors: file not found: $2"
                    exit 11
                fi
                REPAIR_FROM_ERRORS_FILE="$2"
                shift 2
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 11
                ;;
        esac
    done

    # Load session defaults early (after parsing flags)
    if type session_load &>/dev/null; then
        session_load || true

        # Apply session defaults when flags are absent (if SESSION_DEFAULTS_ENABLED)
        if [ "${SESSION_DEFAULTS_ENABLED:-true}" = "true" ]; then
            # Apply saved defaults using ${VAR:-$(func)} pattern
            if [ -z "$user_provided_scheme" ]; then
                SCHEME=${SCHEME:-$(session_get_default "scheme" 2>/dev/null || echo "")}
            fi
            if [ -z "$user_provided_configuration" ]; then
                BUILD_CONFIGURATION=${BUILD_CONFIGURATION:-$(session_get_default "configuration" 2>/dev/null || echo "")}
                [ -z "$BUILD_CONFIGURATION" ] && BUILD_CONFIGURATION="${BUILD_CONFIGURATION:-Debug}"
            fi
            if [ -z "$user_provided_platform" ]; then
                PLATFORM=${PLATFORM:-$(session_get_default "platform" 2>/dev/null || echo "")}
            fi
            if [ -z "$user_provided_ai_provider" ]; then
                AI_PROVIDER=${AI_PROVIDER:-$(session_get_default "ai_provider" 2>/dev/null || echo "")}
                [ -z "$AI_PROVIDER" ] && AI_PROVIDER="${AI_PROVIDER:-copilot}"
            fi
        fi
    fi

    # Track flag usage for learning (if explicitly provided by user)
    if type session_track_flag &>/dev/null; then
        [ -n "$user_provided_scheme" ] && session_track_flag "--scheme" "$user_provided_scheme"
        [ -n "$user_provided_configuration" ] && session_track_flag "--configuration" "$user_provided_configuration"
        [ -n "$user_provided_platform" ] && session_track_flag "--platform" "$user_provided_platform"
        [ -n "$user_provided_ai_provider" ] && session_track_flag "--ai-provider" "$user_provided_ai_provider"
    fi

    # Read from stdin if requested
    if [ "$read_stdin" = true ]; then
        if [ -t 0 ]; then
            log_error "No input on stdin. Pipe content or use --prompt-string"
            exit 11
        fi
        PROMPT_STRING=$(cat)
    fi

    # CRITICAL: Cache prompt/plan content IMMEDIATELY after argument parsing
    # Traycer deletes temp files after 30 seconds, so read them NOW before any slow operations
    if [ -n "$PROMPT_FILE" ] && [ -f "$PROMPT_FILE" ] && [ -z "$PROMPT_CONTENT" ]; then
        PROMPT_CONTENT=$(cat "$PROMPT_FILE" 2>/dev/null || true)
        [ "${VERBOSE:-false}" = "true" ] && echo "[VERBOSE] Early-cached prompt content (${#PROMPT_CONTENT} chars)" >&2
    elif [ -n "$PLAN_FILE" ] && [ -f "$PLAN_FILE" ] && [ -z "$PROMPT_CONTENT" ]; then
        PROMPT_CONTENT=$(cat "$PLAN_FILE" 2>/dev/null || true)
        [ "${VERBOSE:-false}" = "true" ] && echo "[VERBOSE] Early-cached plan content (${#PROMPT_CONTENT} chars)" >&2
    fi

    # Initialize UI system
    init_ui

    echo "" >&2

    # Debug: Show UI status
    if [ "${VERBOSE:-false}" = "true" ]; then
        echo "[DEBUG] BUILDAGENT_FANCY_UI=${BUILDAGENT_FANCY_UI:-false}" >&2
        type get_icon &>/dev/null && echo "[DEBUG] get_icon: available" >&2 || echo "[DEBUG] get_icon: MISSING" >&2
        type get_color &>/dev/null && echo "[DEBUG] get_color: available" >&2 || echo "[DEBUG] get_color: MISSING" >&2
    fi

    # Show startup UI (logo, banner, tip) if fancy UI enabled
    if [ "${BUILDAGENT_FANCY_UI:-false}" = "true" ]; then
        show_startup_ui
    else
        log_section "=========================================="
        log_section "Phase 5: BuildAgent Starting"
        log_section "=========================================="
    fi
    echo "" >&2

    # Log if defaults were loaded
    if [ -f "${PHASE5_DIR}/defaults.conf" ] && [ "${LOAD_DEFAULTS:-true}" = "true" ]; then
        log_info "Loaded defaults from ${PHASE5_DIR}/defaults.conf"
    fi

    # Setup directories
    setup_directories

    # Initialize build queue coordination (prevents concurrent conflicts)
    init_build_queue

    # Validate inputs
    if ! validate_inputs; then
        exit 11
    fi

    # Detect supported platforms
    detect_project_platforms || true

    # Show configuration box (if fancy UI enabled)
    show_config_box

    log_info "Working Directory: $WORK_DIR"
    log_info "Project Root: $PROJECT_ROOT"
    if [ "$LINT_ONLY_MODE" = "true" ]; then
        log_info "Mode: Auto-detect (build first, AI repair if errors found)"
        log_info "AI Provider: $AI_PROVIDER (used if build fails)"
        log_info "Max Repair Attempts: $MAX_REPAIR_ATTEMPTS"
    else
        log_info "Max Repair Attempts: $MAX_REPAIR_ATTEMPTS"
        log_info "AI Provider: $AI_PROVIDER"
        if [ -n "$AI_MODEL" ]; then
            log_info "AI Model: $AI_MODEL"
        fi
    fi
    log_info "Artifacts: $ARTIFACTS_DIR"
    if [ "$YOLO_MODE" = "true" ]; then
        log_info "Mode: YOLO (automation mode active)"
    fi
    if [ -n "$SCHEME" ]; then
        log_info "Scheme: $SCHEME"
    fi
    if [ -n "$TARGET_ID" ]; then
        log_info "Target Device ID: $TARGET_ID"
    fi
    if [ -n "$DESTINATION" ]; then
        log_info "Destination: $DESTINATION"
    fi
    if [ -n "$BUILD_CONFIGURATION" ]; then
        log_info "Configuration: $BUILD_CONFIGURATION"
    fi
    if [ -n "$DERIVED_DATA_PATH" ]; then
        log_info "DerivedData Path: $DERIVED_DATA_PATH"
    fi
    echo "" >&2

    # Run the build loop
    local exit_code=0
    run_build_loop || exit_code=$?

    echo "" >&2
    log_section "=========================================="
    if [ $exit_code -eq 0 ]; then
        log_success "BuildAgent Complete!"
    elif [ $exit_code -eq 20 ]; then
        log_error "BuildAgent requires human intervention"
    else
        log_error "BuildAgent failed"
    fi
    log_section "=========================================="
    echo "" >&2
    log_info "Logs: $LOGS_DIR"
    log_info "Status: $STATUS_DIR"

    # List what was created
    if [ -d "$LOGS_DIR" ]; then
        log_verbose "Files in logs directory:"
        ls -la "$LOGS_DIR" >&2 2>/dev/null || true
    fi
    echo "" >&2

    # Output machine-friendly result
    if [ "$JSON_OUTPUT" = "true" ]; then
        # JSON output for MCP server
        local status_msg
        local error_msg="null"
        if [ $exit_code -eq 0 ]; then
            status_msg="Build completed successfully"
        elif [ $exit_code -eq 20 ]; then
            status_msg="Build requires human intervention"
            error_msg="Human intervention required after $CURRENT_ATTEMPT attempts"
        else
            status_msg="Build failed"
            error_msg="Build failed with exit code $exit_code"
        fi

        # Locate the most recent xcresult bundle for AI diagnostic consumers
        local xcresult_path=""
        local search_root="${DERIVED_DATA_PATH:-${WORK_DIR:-$PWD}}"
        xcresult_path=$(find "$search_root" -name "*.xcresult" -maxdepth 8 2>/dev/null | tail -1 || true)
        # Also check inside LOGS_DIR as a fallback
        if [ -z "$xcresult_path" ] && [ -d "${LOGS_DIR:-}" ]; then
            xcresult_path=$(find "$LOGS_DIR" -name "*.xcresult" -maxdepth 4 2>/dev/null | tail -1 || true)
        fi

        # Build extra_metadata with xcresultPath and logsPath
        local extra_meta="{}"
        if command -v jq &>/dev/null; then
            extra_meta=$(jq -n \
                --arg xr "$xcresult_path" \
                --arg lp "${LOGS_DIR:-}" \
                '{xcresultPath: (if $xr == "" then null else $xr end), logsPath: $lp}')
        fi

        # Build nextSteps hints for agent consumers
        local next_steps_json
        if [ $exit_code -eq 0 ]; then
            next_steps_json="$(jq -n \
                --arg ts "Run TestAgent.sh to verify: ${LOGS_DIR}" \
                --arg bv "Run BuildVerify.sh --skip-build to confirm" \
                '[$ts, $bv]' 2>/dev/null || echo '["Run TestAgent.sh to verify","Run BuildVerify.sh --skip-build"]')"
        elif [ $exit_code -eq 20 ]; then
            next_steps_json="$(jq -n \
                --arg er "Review error report in: ${LOGS_DIR}/error_attempt_${CURRENT_ATTEMPT}.log" \
                --arg re "Fix errors then re-run BuildAgent.sh" \
                '[$er, $re]' 2>/dev/null || echo '["Review error report in logs directory","Fix errors then re-run BuildAgent.sh"]')"
        else
            next_steps_json="$(jq -n \
                --arg lg "Check build log: ${LOGS_DIR}/buildlint_attempt_${CURRENT_ATTEMPT}.log" \
                --arg rv "Re-run with --verbose for detailed output" \
                '[$lg, $rv]' 2>/dev/null || echo '["Check build log in logs directory","Re-run with --verbose for detailed output"]')"
        fi

        output_json_result \
            "$([ $exit_code -eq 0 ] && echo true || echo false)" \
            "$status_msg" \
            "$error_msg" \
            "0" \
            "$extra_meta" \
            "$next_steps_json"
    else
        # Legacy output format
        if [ $exit_code -eq 0 ]; then
            printf 'BUILD_AGENT_STATUS=success\n'
        elif [ $exit_code -eq 20 ]; then
            printf 'BUILD_AGENT_STATUS=human_intervention\n'
        else
            printf 'BUILD_AGENT_STATUS=failed\n'
        fi
        printf 'BUILD_AGENT_LOGS_DIR=%q\n' "$LOGS_DIR"
        printf 'BUILD_AGENT_STATUS_DIR=%q\n' "$STATUS_DIR"
        printf 'BUILD_AGENT_ATTEMPTS=%d\n' "$CURRENT_ATTEMPT"
    fi

    exit $exit_code
}

# Run main
main "$@"
