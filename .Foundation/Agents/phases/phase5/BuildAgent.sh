#!/bin/bash

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

# When script is in PATH, use current working directory as project root
# Otherwise, calculate from script location
if [ -n "${BUILDAGENT_USE_CWD:-}" ] || [ "${PWD}" != "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" ]; then
    # Script is likely in PATH, use current working directory
    PROJECT_ROOT="${PROJECT_ROOT:-$PWD}"
else
    # Script is run from its own directory, calculate relative path
    PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="$PWD"  # Current working directory where user invoked the command

# Load helper libraries
HELPERS_LIB="${PROJECT_ROOT}/.foundation/lib/helpers.sh"
ERRORS_LIB="${PROJECT_ROOT}/.foundation/lib/errors.sh"
AI_PROVIDER_LIB="${PROJECT_ROOT}/.foundation/lib/ai_provider.sh"

if [ -f "$HELPERS_LIB" ]; then
    # shellcheck disable=SC1090
    source "$HELPERS_LIB"
fi

if [ -f "$ERRORS_LIB" ]; then
    # shellcheck disable=SC1090
    source "$ERRORS_LIB"
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

# Input configuration
PLAN_FILE=""
PROMPT_FILE=""
PROMPT_STRING=""
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

# Session configuration (maintains context between attempts)
SESSION_ID=""
SESSION_FILE=""
CURSOR_CHAT_ID=""  # Cursor CLI chat session ID for --resume
AI_PROVIDER="${AI_PROVIDER:-cursor}"  # AI CLI provider: cursor, claude, codex, gemini
AI_CMD=""          # Detected AI CLI command
AI_MODEL="${AI_MODEL:-}"  # Specific AI model (provider-dependent)

# Flags
VERBOSE="${VERBOSE:-false}"
DRY_RUN="${DRY_RUN:-false}"
SKIP_LINT="${SKIP_LINT:-false}"
STREAM_OUTPUT="${STREAM_OUTPUT:-false}"
SKIP_CHAT_ID_CAPTURE="${SKIP_CHAT_ID_CAPTURE:-false}"  # Skip cursor chat ID capture (can be slow/unreliable)
YOLO_MODE="${YOLO_MODE:-false}"  # Automation mode: enables verbose, skip-chat-id, stream output
LINT_ONLY_MODE="${LINT_ONLY_MODE:-false}"  # No AI input - just run lint and build

# Letta Memory integration (set by BuildVerify.sh orchestrator)
LETTA_MEMORY_AGENT="${LETTA_MEMORY_AGENT:-}"  # Memory agent name
LETTA_MEMORY_SCRIPT="${LETTA_MEMORY_SCRIPT:-}"  # Path to letta_memory.py
LETTA_MEMORY_CONTEXT=""  # Retrieved memory context (populated at runtime)

# Spinner state
SPINNER_PID=""

# ─────────────────────────────────────────────────────────────────────────────
# Logging Functions
# ─────────────────────────────────────────────────────────────────────────────

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" >&2
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" >&2
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_section() {
    echo -e "${CYAN}[BUILD-AGENT]${NC} $1" >&2
}

log_attempt() {
    echo -e "${MAGENTA}[ATTEMPT ${CURRENT_ATTEMPT}/${MAX_REPAIR_ATTEMPTS}]${NC} $1" >&2
}

log_verbose() {
    if [ "$VERBOSE" = "true" ]; then
        echo -e "${CYAN}[VERBOSE]${NC} $1" >&2
    fi
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
                    printf "\r${CYAN}[WORKING]${NC} %s ${YELLOW}%s${NC} ${BLUE}(%ds)${NC} " "$message" "$char" "$elapsed" >&2
                else
                    printf "\r${CYAN}[WORKING]${NC} %s ${YELLOW}%s${NC} " "$message" "$char" >&2
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
                    printf "\r${CYAN}[WORKING]${NC} %s ${YELLOW}%s${NC} ${BLUE}(%ds)${NC} " "$message" "$char" "$elapsed" >&2
                else
                    printf "\r${CYAN}[WORKING]${NC} %s ${YELLOW}%s${NC} " "$message" "$char" >&2
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

    if [ -n "$SPINNER_PID" ]; then
        kill $SPINNER_PID 2>/dev/null || true
        wait $SPINNER_PID 2>/dev/null || true
        SPINNER_PID=""
        # Clear the spinner line
        printf "\r\033[K" >&2

        # Show completion message if provided
        if [ -n "$completion_msg" ]; then
            echo -e "${GREEN}[DONE]${NC} $completion_msg" >&2
        fi
    fi
}

# Stop spinner with success message
spinner_success() {
    local message="${1:-$SPINNER_MESSAGE}"
    stop_spinner
    echo -e "${GREEN}[DONE]${NC} $message ${GREEN}✓${NC}" >&2
}

# Stop spinner with error message
spinner_error() {
    local message="${1:-$SPINNER_MESSAGE}"
    stop_spinner
    echo -e "${RED}[FAILED]${NC} $message ${RED}✗${NC}" >&2
}

# Update spinner message (stops and restarts with new message)
update_spinner() {
    local message="$1"
    stop_spinner
    start_spinner "$message"
}

# Cleanup spinner on exit
cleanup_spinner() {
    stop_spinner
}
trap cleanup_spinner EXIT INT TERM

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
    
    Auto-detection searches these locations:
      • Docs/swiftDocs, docs/swiftDocs
      • Documentation/swiftDocs, documentation/swiftDocs
      • .foundation/docs/swiftDocs, .Foundation/docs/swiftDocs
      • And more...

AI PROVIDER OPTIONS:
    --ai-provider <name>    AI CLI provider to use (default: cursor)

                            Supported providers:
                              cursor  - Cursor AI (default)
                              claude  - Anthropic Claude
                              codex   - OpenAI Codex
                              gemini  - Google Gemini
                              aider   - Aider AI pair programming
                              letta   - Letta stateful agents (persistent memory)

                            Auto-installation:
                              If a provider is not installed, the script will
                              attempt to install it automatically!
                              - Letta: via npm (requires Node.js 18+)
                              - Others: via Cursor AI assistance

                            Auto-approval flags (for unattended operation):
                              cursor → --force
                              claude → --dangerously-skip-permissions
                              codex  → --full-auto
                              gemini → --yolo
                              aider  → --yes
                              letta  → --yolo

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
    --help                  Show this help message

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
      cursor: Already authenticated if Cursor IDE is logged in
      claude: export ANTHROPIC_API_KEY=sk-ant-...
      codex:  export OPENAI_API_KEY=sk-...
      gemini: export GOOGLE_API_KEY=...
      aider:  export OPENAI_API_KEY=... or ANTHROPIC_API_KEY=...
      letta:  export LETTA_API_KEY=letta-...
              Optional: export LETTA_BASE_URL=http://localhost:8283 (self-hosted)

ENVIRONMENT VARIABLES:
    PROJECT_ROOT            Override project root directory (default: $PWD)
    BUILDAGENT_USE_CWD      Force use of current working directory
    BUILD_CONFIGURATION     Default build configuration (default: Debug)
    MAX_REPAIR_ATTEMPTS     Default max repair attempts (default: 3)
    AI_PROVIDER             Default AI provider (default: cursor)

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
    log_verbose "Session ID: $SESSION_ID"
    log_verbose "AI CLI Command: $AI_CMD"
}

validate_inputs() {
    start_spinner "Validating configuration"

    # Check if any input is provided - if not, run in lint-only mode
    if [ -z "$PLAN_FILE" ] && [ -z "$PROMPT_FILE" ] && [ -z "$PROMPT_STRING" ]; then
        LINT_ONLY_MODE="true"
        log_info "No AI input provided - running in auto-detect mode (build first, AI repair if needed)"
    fi

    # Validate plan file if provided
    if [ -n "$PLAN_FILE" ] && [ ! -f "$PLAN_FILE" ]; then
        spinner_error "Validating configuration"
        log_error "Plan file not found: $PLAN_FILE"
        return 1
    fi

    # Validate prompt file if provided
    if [ -n "$PROMPT_FILE" ] && [ ! -f "$PROMPT_FILE" ]; then
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

    # Check/initialize git repository
    ensure_git_repo || true  # Non-fatal if initialization fails

    # Auto-detect scheme if not provided
    if [ -z "$SCHEME" ]; then
        if ! detect_scheme; then
            log_warning "Could not auto-detect scheme. Build may require --scheme parameter."
        fi
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
            return 1
        fi
    fi

    spinner_success "Validating configuration"
    return 0
}

# ─────────────────────────────────────────────────────────────────────────────
# Auto-detection Functions
# ─────────────────────────────────────────────────────────────────────────────

# Auto-detect Swift documentation path
# Searches up to 5 levels deep for swiftDocs directories, excludes dependency folders,
# and prioritizes the main project's docs (shortest path)
detect_swift_docs() {
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

    # Build xcodebuild argument
    local xcode_arg=""
    if [ -n "$workspace" ]; then
        xcode_arg="-workspace \"$workspace\""
        log_verbose "Using workspace: $workspace"
    elif [ -n "$project" ]; then
        xcode_arg="-project \"$project\""
        log_verbose "Using project: $project"
    else
        log_verbose "No Xcode workspace or project found"
        return 1
    fi

    # Get list of schemes
    local schemes_output
    schemes_output=$(eval "xcodebuild $xcode_arg -list 2>/dev/null" || true)

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

# Detect and configure AI CLI provider
detect_ai_provider() {
    local provider
    provider=$(echo "$AI_PROVIDER" | tr '[:upper:]' '[:lower:]')  # Convert to lowercase
    
    log_verbose "Detecting AI provider: $provider"
    
    case "$provider" in
        cursor)
            if command -v cursor-agent >/dev/null 2>&1; then
                AI_CMD="cursor-agent"
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

        *)
            log_error "Unknown AI provider: $provider"
            log_info "Supported providers: cursor, claude, codex, gemini, aider, letta"
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

    # Add Swift docs if available
    if [ -n "$SWIFT_DOCS_PATH" ] && [ "$SWIFT_DOCS_PATH" != "DISABLED" ] && [ -d "$SWIFT_DOCS_PATH" ]; then
        log_verbose "Adding Swift docs from: $SWIFT_DOCS_PATH"
        local swift_docs_content
        swift_docs_content=$(read_md_files_from_dir "$SWIFT_DOCS_PATH")
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
    local content=""

    if [ -n "$PLAN_FILE" ]; then
        content=$(cat "$PLAN_FILE")
    elif [ -n "$PROMPT_FILE" ]; then
        content=$(cat "$PROMPT_FILE")
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
        # Use timeout (2 seconds max - should be near instant)
        if command -v timeout >/dev/null 2>&1; then
            chat_list=$(cd "$PROJECT_ROOT" && timeout 2 cursor-agent ls 2>/dev/null | head -1)
        elif command -v gtimeout >/dev/null 2>&1; then
            # macOS with coreutils installed
            chat_list=$(cd "$PROJECT_ROOT" && gtimeout 2 cursor-agent ls 2>/dev/null | head -1)
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
            if [ "$is_followup" = "true" ] && [ -n "$CURSOR_CHAT_ID" ] && [ "$AI_CMD" = "cursor-agent" ]; then
                # Resume existing session
                log_verbose "Resuming Cursor chat session: $CURSOR_CHAT_ID"
                ai_cmd_full="cat \"$prompt_file\" | $AI_CMD --resume \"$CURSOR_CHAT_ID\" --force --print --output-format text"
            else
                # New session (first attempt)
                ai_cmd_full="cat \"$prompt_file\" | $AI_CMD --force --print --output-format text"
                log_verbose "Starting new Cursor chat session"
            fi
            ;;
        
        claude)
            # Claude CLI - pipe from file to avoid escaping issues
            ai_cmd_full="cat \"$prompt_file\" | $AI_CMD --dangerously-skip-permissions -p -"
            log_verbose "Running Claude CLI (with --dangerously-skip-permissions)"
            ;;
        
        codex|openai)
            # OpenAI/Codex format with full-auto flag - pipe from file
            ai_cmd_full="cat \"$prompt_file\" | $AI_CMD complete --full-auto -"
            log_verbose "Running OpenAI/Codex CLI (with --full-auto)"
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
        # Start spinner - it will run on its own line
        start_spinner "$spinner_msg"
        
        # Give spinner a moment to start, then move to new line for output
        sleep 0.2
        
        # Stream output in real-time (use tee to both display and save)
        echo "" >&2
        echo -e "${CYAN}─── ${AI_PROVIDER} CLI Output ───${NC}" >&2
        
        # Spinner continues on its line above while output streams below
        # Run in WORK_DIR (where user invoked the command) not PROJECT_ROOT
        if (cd "$WORK_DIR" && eval "$ai_cmd_full" 2>&1) | tee "$output_file"; then
            ai_exit_code=0
            stop_spinner
            spinner_success "$spinner_msg"
        else
            ai_exit_code=$?
            stop_spinner
            spinner_error "$spinner_msg"
        fi
        
        echo -e "${CYAN}─── End Output ───${NC}" >&2
        echo "" >&2
    else
        # Use spinner animation
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
        # Start spinner - it will run on its own line
        start_spinner "$build_spinner_msg"
        
        # Give spinner a moment to start, then move to new line for output
        sleep 0.2
        
        # Stream output
        echo "" >&2
        echo -e "${CYAN}─── BuildLint Output ───${NC}" >&2
        
        # Spinner continues on its line above while output streams below
        if "$BUILD_LINT_SCRIPT" "${lint_args[@]}" 2>&1 | tee "$lint_log"; then
            lint_exit_code=0
            # Don't show success/error here yet - we need to check for error.log first
            stop_spinner
        else
            lint_exit_code=$?
            stop_spinner
        fi
        
        echo -e "${CYAN}─── End BuildLint ───${NC}" >&2
        echo "" >&2
    else
        # Use spinner
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

    # Store success to Letta memory
    store_build_result "success"
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

        # Generate code with AI
        if ! run_ai_cli "$prompt_content"; then
            update_session_context "$CURRENT_ATTEMPT" "ai_error" "AI CLI failed"
            log_error "AI CLI call failed"
            # Note: run_ai_cli handles auth error detection internally
            # Continue to next attempt
            is_followup="true"
            continue
        fi

        update_session_context "$CURRENT_ATTEMPT" "ai_success" "AI code generated"

        # Verify build
        if run_build_lint; then
            # Success!
            update_session_context "$CURRENT_ATTEMPT" "success" "Build passed"
            write_success_status
            return 0
        fi

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

    # Run initial build verification
    if run_build_lint; then
        # Success! No errors to fix
        update_session_context "0" "success" "Build passed - no errors to fix"
        write_success_status
        log_success "Build passed! No errors detected."
        return 0
    fi

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

        # Run AI CLI with session
        if ! run_ai_cli "$prompt" "$is_followup"; then
            log_error "${AI_PROVIDER} CLI failed"
            error_feedback="${AI_PROVIDER} CLI invocation failed. Please try again."
            update_session_context "$CURRENT_ATTEMPT" "cursor_failed" "$error_feedback"
            is_followup="true"
            continue
        fi

        # Run build verification
        if run_build_lint; then
            # Success!
            update_session_context "$CURRENT_ATTEMPT" "success" "Build passed"
            write_success_status
            return 0
        fi

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
            --ai-provider)
                AI_PROVIDER="${2:-}"
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
                shift 2
                ;;
            --configuration)
                BUILD_CONFIGURATION="${2:-}"
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

    # Read from stdin if requested
    if [ "$read_stdin" = true ]; then
        if [ -t 0 ]; then
            log_error "No input on stdin. Pipe content or use --prompt-string"
            exit 11
        fi
        PROMPT_STRING=$(cat)
    fi

    echo "" >&2
    log_section "=========================================="
    log_section "Phase 5: BuildAgent Starting"
    log_section "=========================================="
    echo "" >&2

    # Setup directories
    setup_directories

    # Validate inputs
    if ! validate_inputs; then
        exit 11
    fi

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

    exit $exit_code
}

# Run main
main "$@"
