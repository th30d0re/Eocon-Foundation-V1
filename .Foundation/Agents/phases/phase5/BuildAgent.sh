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

PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

# Repair loop configuration
MAX_REPAIR_ATTEMPTS="${MAX_REPAIR_ATTEMPTS:-3}"
CURRENT_ATTEMPT=0

# Session configuration (maintains context between attempts)
SESSION_ID=""
SESSION_FILE=""
CURSOR_CHAT_ID=""  # Cursor CLI chat session ID for --resume
CURSOR_CMD=""      # Detected Cursor CLI command (cursor-agent or cursor)

# Flags
VERBOSE="${VERBOSE:-false}"
DRY_RUN="${DRY_RUN:-false}"
SKIP_LINT="${SKIP_LINT:-false}"
STREAM_OUTPUT="${STREAM_OUTPUT:-false}"
SKIP_CHAT_ID_CAPTURE="${SKIP_CHAT_ID_CAPTURE:-false}"  # Skip cursor chat ID capture (can be slow/unreliable)
YOLO_MODE="${YOLO_MODE:-false}"  # Automation mode: enables verbose, skip-chat-id, stream output

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
# Usage
# ─────────────────────────────────────────────────────────────────────────────

show_usage() {
    cat << EOF
Phase 5: BuildAgent - Code Generation & Build Verification

USAGE:
    $0 [OPTIONS]

INPUT OPTIONS (at least one required):
    --plan <file.md>        Path to plan markdown file
    --prompt <file.txt>     Path to prompt text file
    --prompt-string <str>   Prompt string directly (or use stdin)
    --stdin                 Read prompt from stdin

CONTEXT OPTIONS:
    --context <path>        MD file or directory with MD files (can be repeated)
    --swift-docs <path>     Path to Swift documentation (default: Docs/swiftDocs)
    --no-swift-docs         Skip Swift docs context

BUILD OPTIONS:
    --target-id <id>        Device/Simulator UDID (e.g., 00008150-001D5822210A401C)
    --destination <dest>    Full destination string (overrides --target-id)
                            Example: "platform=iOS Simulator,name=iPhone 16"
    --scheme <scheme>       Xcode scheme to build
    --configuration <cfg>   Build configuration (default: Debug)
    --skip-lint             Skip SwiftLint checks

EXECUTION OPTIONS:
    --max-attempts <n>      Max repair attempts (default: 3)
    --artifacts-dir <dir>   Artifacts output directory
    --stream                Stream Cursor CLI output in real-time
          --yolo                  Automation mode: max-attempts=10, verbose, skip-chat-id, streaming
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
    logs/coder.log              - Cursor CLI output
    status/success.txt          - On successful completion
    status/human_intervention.md - When human help needed

EXAMPLES:
    # Generate code from a plan file
    $0 --plan Plans/plan1/plan1.md --scheme MyApp

    # Use prompt string with context
    $0 --prompt-string "Add a login button" --context Guides/ --scheme MyApp

    # Read prompt from stdin
    echo "Fix the bug in AuthManager" | $0 --stdin --scheme MyApp

    # With physical device target
    $0 --plan plan.md --target-id 00008150-001D5822210A401C --scheme MyApp

    # With simulator destination
    $0 --prompt-string "Fix bug" --destination "platform=iOS Simulator,name=iPhone 16" --scheme MyApp

    # Build for specific device with Release configuration
    $0 --plan plan.md --target-id 00008150-001D5822210A401C --scheme MyApp --configuration Release

        # YOLO mode for long-running automation (10 retries, verbose, streaming, skip chat ID)
    $0 --plan plan.md --scheme MyApp --yolo


    # YOLO mode with custom retry count
    $0 --plan plan.md --scheme MyApp --max-attempts 20 --yolo
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
    log_verbose "Cursor CLI Command: $CURSOR_CMD"
}

validate_inputs() {
    start_spinner "Validating configuration"

    # Check that at least one input is provided
    if [ -z "$PLAN_FILE" ] && [ -z "$PROMPT_FILE" ] && [ -z "$PROMPT_STRING" ]; then
        spinner_error "Validating configuration"
        log_error "No input provided. Use --plan, --prompt, --prompt-string, or --stdin"
        return 1
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

    # Check BuildLint.sh exists
    if [ ! -x "$BUILD_LINT_SCRIPT" ]; then
        spinner_error "Validating configuration"
        log_error "BuildLint.sh not found or not executable: $BUILD_LINT_SCRIPT"
        return 1
    fi

    # Check Cursor CLI is available (try both formats)
    if command -v cursor-agent >/dev/null 2>&1; then
        CURSOR_CMD="cursor-agent"
        log_verbose "Using cursor-agent command"
    elif command -v cursor >/dev/null 2>&1; then
        CURSOR_CMD="cursor agent"
        log_verbose "Using cursor agent command"
    else
        spinner_error "Validating configuration"
        log_error "Cursor CLI not found. Install from https://cursor.sh"
        return 1
    fi

    spinner_success "Validating configuration"
    return 0
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
    if [ -d "$SWIFT_DOCS_PATH" ] || [ ${#CONTEXT_PATHS[@]} -gt 0 ]; then
        has_context=true
        start_spinner "Gathering context"
    fi

    # Add Swift docs if available
    if [ -d "$SWIFT_DOCS_PATH" ]; then
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

# Get the latest Cursor chat ID from cursor-agent ls
get_latest_chat_id() {
    if [ "$CURSOR_CMD" = "cursor-agent" ]; then
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
            # cursor-agent ls is unreliable, session resume not critical
            log_verbose "timeout command not available, skipping chat ID capture"
            echo ""
            return
        fi
        
        if [ -n "$chat_list" ]; then
            # Extract chat ID (usually first field or UUID-like string)
            echo "$chat_list" | awk '{print $1}' | head -1
        fi
    fi
    # Return empty if not available or using cursor agent format
    echo ""
}

# Run Cursor CLI with session support
run_cursor_cli() {
    local prompt="$1"
    local is_followup="${2:-false}"
    local output_file="${LOGS_DIR}/coder_attempt_${CURRENT_ATTEMPT}.log"

    log_attempt "Running Cursor CLI (session: $SESSION_ID)..."

    if [ "$DRY_RUN" = "true" ]; then
        log_info "[DRY RUN] Would run: $CURSOR_CMD --force --print ..."
        if [ "$is_followup" = "true" ] && [ -n "$CURSOR_CHAT_ID" ]; then
            log_info "[DRY RUN] Would resume chat: $CURSOR_CHAT_ID"
        fi
        echo "[DRY RUN] Cursor CLI would be invoked here" > "$output_file"
        return 0
    fi

    # Save prompt for debugging
    echo "$prompt" > "${LOGS_DIR}/prompt_attempt_${CURRENT_ATTEMPT}.txt"

    local cursor_exit_code=0
    local cursor_cmd_full=""

    # Build command based on whether this is a follow-up with session resume
    if [ "$is_followup" = "true" ] && [ -n "$CURSOR_CHAT_ID" ] && [ "$CURSOR_CMD" = "cursor-agent" ]; then
        # Resume existing session
        log_verbose "Resuming Cursor chat session: $CURSOR_CHAT_ID"
        cursor_cmd_full="$CURSOR_CMD --resume \"$CURSOR_CHAT_ID\" --force --print --output-format text \"$prompt\""
    else
        # New session (first attempt)
        if [ "$CURSOR_CMD" = "cursor-agent" ]; then
            cursor_cmd_full="$CURSOR_CMD --force --print --output-format text \"$prompt\""
        else
            # cursor agent format (space-separated) - try to add --force if supported
            cursor_cmd_full="$CURSOR_CMD --force --print --output-format text \"$prompt\""
        fi
        log_verbose "Starting new Cursor chat session"
    fi

    # Log session info (for tracking purposes)
    if [ "$is_followup" = "true" ]; then
        log_verbose "Follow-up attempt in session: $SESSION_ID"
        if [ -n "$CURSOR_CHAT_ID" ]; then
            log_verbose "Using Cursor chat ID: $CURSOR_CHAT_ID"
        fi
    else
        log_verbose "New session: $SESSION_ID"
    fi

    # Run with streaming or spinner
    local spinner_msg="Generating code"
    [ "$is_followup" = "true" ] && spinner_msg="Fixing code (attempt $CURRENT_ATTEMPT)"

    if [ "$STREAM_OUTPUT" = "true" ]; then
        # Start spinner - it will run on its own line
        start_spinner "$spinner_msg"
        
        # Give spinner a moment to start, then move to new line for output
        sleep 0.2
        
        # Stream output in real-time (use tee to both display and save)
        # Print newline to move past spinner line, then stream output
        echo "" >&2
        echo -e "${CYAN}─── Cursor CLI Output ───${NC}" >&2
        
        # Spinner continues on its line above while output streams below
        if (cd "$PROJECT_ROOT" && eval "$cursor_cmd_full" 2>&1) | tee "$output_file"; then
            cursor_exit_code=0
            # Stop spinner and show success
            stop_spinner
            spinner_success "$spinner_msg"
        else
            cursor_exit_code=$?
            # Stop spinner and show error
            stop_spinner
            spinner_error "$spinner_msg"
        fi
        
        echo -e "${CYAN}─── End Output ───${NC}" >&2
        echo "" >&2
    else
        # Use spinner animation
        start_spinner "$spinner_msg"

        if (cd "$PROJECT_ROOT" && eval "$cursor_cmd_full" > "$output_file" 2>&1); then
            cursor_exit_code=0
            spinner_success "$spinner_msg"
        else
            cursor_exit_code=$?
            spinner_error "$spinner_msg"
        fi
    fi

    # On first attempt, try to capture the chat ID for future resume
    # Note: This is optional and can be skipped with --skip-chat-id
    if [ "$SKIP_CHAT_ID_CAPTURE" = "false" ] && [ "$is_followup" = "false" ] && [ -z "$CURSOR_CHAT_ID" ] && [ "$CURSOR_CMD" = "cursor-agent" ] && [ $cursor_exit_code -eq 0 ]; then
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
    if [ $cursor_exit_code -eq 0 ]; then
        update_session_context "$CURRENT_ATTEMPT" "completed" "Code generated successfully"
    else
        update_session_context "$CURRENT_ATTEMPT" "failed" "Cursor CLI exit code: $cursor_exit_code"
    fi

    if [ $cursor_exit_code -ne 0 ]; then
        log_error "Cursor CLI failed with exit code: $cursor_exit_code"
        return 1
    fi

    log_success "Cursor CLI completed"
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

    if [ "$SKIP_LINT" = "true" ]; then
        lint_args+=("--skip-lint")
    fi

    if [ "$VERBOSE" = "true" ]; then
        lint_args+=("--verbose")
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
}

# ─────────────────────────────────────────────────────────────────────────────
# Main Execution Loop
# ─────────────────────────────────────────────────────────────────────────────

run_build_loop() {
    local input_content
    local context
    local error_feedback=""
    local is_followup="false"

    input_content=$(get_input_content)
    context=$(gather_context)

    log_info "Input length: ${#input_content} chars"
    log_info "Context length: ${#context} chars"
    log_info "Session ID: $SESSION_ID"

    # Initialize session context file
    {
        echo "# Build Session: $SESSION_ID"
        echo "Started: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
        echo "Max attempts: $MAX_REPAIR_ATTEMPTS"
        echo "Cursor CLI Command: $CURSOR_CMD"
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

        # Run Cursor CLI with session
        if ! run_cursor_cli "$prompt" "$is_followup"; then
            log_error "Cursor CLI failed"
            error_feedback="Cursor CLI invocation failed. Please try again."
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
                SWIFT_DOCS_PATH=""
                shift 1
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
                # Increase max attempts to 10 for YOLO mode (unless already set)
                if [ "$MAX_REPAIR_ATTEMPTS" = "3" ]; then
                    MAX_REPAIR_ATTEMPTS="10"
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

    log_info "Project Root: $PROJECT_ROOT"
    log_info "Max Repair Attempts: $MAX_REPAIR_ATTEMPTS"
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
