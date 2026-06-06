#!/usr/bin/env bash

# BuildVerify - Build and Test Orchestrator with Shared Memory
# Orchestrates BuildAgent followed by TestAgent with Letta memory integration
# Based on Foundation methodology
#
# Workflow:
#   1. Initialize Letta memory (graceful fallback if unavailable)
#   2. Run BuildAgent.sh with memory-enhanced prompts
#   3. On build success, run testAgent.sh with shared context
#   4. Store session summary to memory
#   5. Generate combined pipeline report
#
# Exit Codes:
#   0  - Success (build and tests passed)
#   10 - Build failed after max retries
#   11 - Misconfiguration
#   20 - Human intervention required
#   30 - Tests failed (build succeeded)

set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────────────────────────────────────

# Resolve symlinks to get actual script directory
SOURCE="${BASH_SOURCE[0]}"
while [ -L "$SOURCE" ]; do
    SCRIPT_DIR="$(cd "$(dirname "$SOURCE")" && pwd)"
    SOURCE="$(readlink "$SOURCE")"
    [[ $SOURCE != /* ]] && SOURCE="$SCRIPT_DIR/$SOURCE"
done
SCRIPT_DIR="$(cd "$(dirname "$SOURCE")" && pwd)"

# Agent scripts
BUILD_AGENT="${SCRIPT_DIR}/BuildAgent.sh"
TEST_AGENT="${SCRIPT_DIR}/testAgent.sh"
LETTA_MEMORY="${SCRIPT_DIR}/lib/letta_memory.py"

# Library directory
LIB_DIR="${SCRIPT_DIR}/lib"
FOUNDATION_LIB_DIR="$(cd "${SCRIPT_DIR}/../../../lib" && pwd)"

# Load Foundation helpers
HELPERS_LIB="${FOUNDATION_LIB_DIR}/helpers.sh"
if [ -f "$HELPERS_LIB" ]; then
    # shellcheck disable=SC1090
    source "$HELPERS_LIB"

    # Check shell compatibility
    if type check_shell_compatibility &>/dev/null; then
        check_shell_compatibility || exit 11
    fi
fi

# Colors for output (fallback if helpers not loaded)
RED="${RED:-\033[0;31m}"
GREEN="${GREEN:-\033[0;32m}"
YELLOW="${YELLOW:-\033[1;33m}"
BLUE="${BLUE:-\033[0;34m}"
CYAN="${CYAN:-\033[0;36m}"
MAGENTA="${MAGENTA:-\033[0;35m}"
NC="${NC:-\033[0m}" # No Color

# Source session library
source "${LIB_DIR}/session_store.sh"

# Source UI libraries for sidebar support
if [ -f "${LIB_DIR}/ui_themes.sh" ]; then
    source "${LIB_DIR}/ui_themes.sh"
fi
if [ -f "${LIB_DIR}/ui_components.sh" ]; then
    source "${LIB_DIR}/ui_components.sh"
fi

# Configuration variables
PROJECT_PATH=""
SCHEME=""
PROMPT=""
PLAN_FILE=""
AI_PROVIDER="${AI_PROVIDER:-cursor}"
AI_MODEL="${AI_MODEL:-}"
YOLO_MODE="false"
SKIP_TESTS="false"
SKIP_MEMORY="false"
VERBOSE="false"
DRY_RUN="false"
SIMULATOR_NAME=""
SKIP_ARGENT="false"
NO_CONTEXT="false"
PLATFORM=""
DESTINATION=""
STAGE=""
MAX_BUILD_ATTEMPTS="${MAX_BUILD_ATTEMPTS:-5}"
MAX_TEST_ATTEMPTS="${MAX_TEST_ATTEMPTS:-3}"
ARTIFACTS_DIR=""
SIDEBAR_MODE="${SIDEBAR_MODE:-false}"

# Interactive and control flags
INTERACTIVE_MODE=false
ABORT_FLAG=false
SKIP_PHASE_FLAG=false
SKIP_TO_REPORT_FLAG=false
CURRENT_PHASE_PID=""
MAX_CONTEXT_CHARS="${MAX_CONTEXT_CHARS:-400000}"

# When no prompt is provided, run in happy-path-only mode
# (build + lint, skip AI generation, focus on basic tests)
HAPPY_ONLY="false"

# Session integration
USE_SESSION="${USE_SESSION:-false}"
SESSION_SCHEME=""
SESSION_PLATFORM=""
SESSION_SIMULATOR=""

# Session tracking
SESSION_ID=""
WORK_DIR="$(pwd)"
LETTA_ENABLED="false"
LETTA_AGENT=""
PIPELINE_START_TIME=""
BUILD_EXIT_CODE=0
TEST_EXIT_CODE=0
PLANS_DIR=""

# ─────────────────────────────────────────────────────────────────────────────
# Policy Gradient Hyperparameter Learning
# ─────────────────────────────────────────────────────────────────────────────

HYPERPARAM_REGISTRY="${ARTIFACTS_DIR:-./Artifacts}/.hyperparams.json"

# Initialize hyperparameter registry with defaults
init_hyperparams() {
    local registry="$HYPERPARAM_REGISTRY"
    if [ -f "$registry" ]; then
        return 0
    fi
    # Guard against mkdir failing (e.g., path exists as a file on macOS)
    if ! mkdir -p "$(dirname "$registry")" 2>/dev/null; then
        log_verbose "Could not create hyperparam registry directory"
        return 0
    fi
    if ! cat > "$registry" 2>/dev/null << 'EOF'
{
  "max_build_attempts": {"value": 5, "reward_sum": 0, "count": 0, "gradient": 0},
  "max_test_attempts": {"value": 3, "reward_sum": 0, "count": 0, "gradient": 0},
  "context_chars": {"value": 400000, "reward_sum": 0, "count": 0, "gradient": 0},
  "learning_rate": 0.1
}
EOF
    then
        log_verbose "Could not write hyperparam registry"
        return 0
    fi
}

# Record outcome for current hyperparameters
record_hyperparam_outcome() {
    local build_attempts="$1"
    local test_attempts="$2"
    local build_success="$3"
    local test_success="$4"
    local duration="$5"
    local registry="$HYPERPARAM_REGISTRY"

    if [ ! -f "$registry" ] || ! command -v jq >/dev/null 2>&1; then
        return 0
    fi

    # Reward function: higher is better
    # success = +100, each attempt = -10, duration penalty = -1 per minute
    local reward=0
    if [ "$build_success" = "true" ]; then
        reward=$((reward + 100))
    else
        reward=$((reward - 50))
    fi
    if [ "$test_success" = "true" ]; then
        reward=$((reward + 100))
    fi
    reward=$((reward - build_attempts * 10 - test_attempts * 10 - duration / 60))

    local tmp_file
    tmp_file=$(mktemp)
    jq --argjson r "$reward" \
       '.max_build_attempts.reward_sum += $r | .max_build_attempts.count += 1 | .max_test_attempts.reward_sum += $r | .max_test_attempts.count += 1 | .context_chars.reward_sum += $r | .context_chars.count += 1' \
       "$registry" > "$tmp_file" 2>/dev/null || cat "$registry" > "$tmp_file"
    mv "$tmp_file" "$registry"
}

# Apply policy gradient update to hyperparameters
update_hyperparams() {
    local registry="$HYPERPARAM_REGISTRY"
    if [ ! -f "$registry" ] || ! command -v jq >/dev/null 2>&1; then
        return 0
    fi

    local lr
    lr=$(jq '.learning_rate // 0.1' "$registry")

    local tmp_file
    tmp_file=$(mktemp)

    # Simple gradient ascent: if reward is positive, increase parameter slightly
    # if reward is negative, decrease parameter slightly
    jq --argjson lr "$lr" '
      .max_build_attempts.avg_reward = (.max_build_attempts.reward_sum / (.max_build_attempts.count | max(1))) |
      .max_build_attempts.gradient = (.max_build_attempts.avg_reward * $lr) |
      .max_build_attempts.value = ([(.max_build_attempts.value + .max_build_attempts.gradient) | floor, 10] | max) |
      .max_test_attempts.avg_reward = (.max_test_attempts.reward_sum / (.max_test_attempts.count | max(1))) |
      .max_test_attempts.gradient = (.max_test_attempts.avg_reward * $lr) |
      .max_test_attempts.value = ([(.max_test_attempts.value + .max_test_attempts.gradient) | floor, 1] | max) |
      .context_chars.avg_reward = (.context_chars.reward_sum / (.context_chars.count | max(1))) |
      .context_chars.gradient = (.context_chars.avg_reward * $lr * 10000) |
      .context_chars.value = ([(.context_chars.value + .context_chars.gradient) | floor, 50000] | max)
    ' "$registry" > "$tmp_file" 2>/dev/null || cat "$registry" > "$tmp_file"
    mv "$tmp_file" "$registry"
}

# Get recommended hyperparameters
get_recommended_hyperparams() {
    local registry="$HYPERPARAM_REGISTRY"
    if [ ! -f "$registry" ] || ! command -v jq >/dev/null 2>&1; then
        echo "max_build_attempts=5 max_test_attempts=3 context_chars=400000"
        return 0
    fi
    local build_attempts test_attempts ctx_chars
    build_attempts=$(jq '.max_build_attempts.value // 5' "$registry" 2>/dev/null) || build_attempts=5
    test_attempts=$(jq '.max_test_attempts.value // 3' "$registry" 2>/dev/null) || test_attempts=3
    ctx_chars=$(jq '.context_chars.value // 400000' "$registry" 2>/dev/null) || ctx_chars=400000
    echo "max_build_attempts=$build_attempts max_test_attempts=$test_attempts context_chars=$ctx_chars"
}

# Apply recommended hyperparameters to environment
apply_hyperparams() {
    local rec
    rec=$(get_recommended_hyperparams)
    local build_attempts="" test_attempts="" ctx_chars=""

    # Use sed instead of grep|cut to avoid pipefail + set -e surprises
    build_attempts=$(echo "$rec" | sed -n 's/.*max_build_attempts=\([0-9]*\).*/\1/p') || true
    test_attempts=$(echo "$rec" | sed -n 's/.*max_test_attempts=\([0-9]*\).*/\1/p') || true
    ctx_chars=$(echo "$rec" | sed -n 's/.*context_chars=\([0-9]*\).*/\1/p') || true

    if [ -n "$build_attempts" ]; then
        MAX_BUILD_ATTEMPTS="$build_attempts"
        log_info "Hyperparam: MAX_BUILD_ATTEMPTS=$MAX_BUILD_ATTEMPTS"
    fi
    if [ -n "$test_attempts" ]; then
        MAX_TEST_ATTEMPTS="$test_attempts"
        log_info "Hyperparam: MAX_TEST_ATTEMPTS=$MAX_TEST_ATTEMPTS"
    fi
    if [ -n "$ctx_chars" ]; then
        MAX_CONTEXT_CHARS="$ctx_chars"
        log_info "Hyperparam: MAX_CONTEXT_CHARS=$MAX_CONTEXT_CHARS"
    fi
    return 0
}

# Sidebar / Live UI state (used by ui_components.sh)
SIDEBAR_DAEMON_PID=""
SIDEBAR_MODE_ACTIVE="false"
SIDEBAR_STAGE="Initializing"
SIDEBAR_TITLE="BuildVerify"

# Interactive bottom bar state
CURRENT_PHASE_PID=""
SKIP_PHASE_FLAG=false
SKIP_TO_REPORT_FLAG=false

# Cleanup on exit (live UI + memory)
cleanup_buildverify() {
    if [ "${SIDEBAR_MODE_ACTIVE:-false}" = "true" ]; then
        disable_sidebar_mode 2>/dev/null || true
    fi
    disable_split_layout 2>/dev/null || true
}
trap cleanup_buildverify EXIT INT TERM

_handle_sigwinch() {
    LIVE_UI_HEIGHT=$(tput lines 2>/dev/null || echo 24)
    if [ "${LIVE_UI_ACTIVE:-false}" = "true" ]; then
        printf "\e[3;%sr" "$((LIVE_UI_HEIGHT - 1))" >&2
        draw_phase_tracker
        draw_bottom_bar
    fi
}
trap '_handle_sigwinch' SIGWINCH

_handle_sigusr1() {
    local cmd=""
    [ -f "${LIVE_UI_STATE_FILE:-}" ] && \
        cmd=$(grep '^cmd=' "$LIVE_UI_STATE_FILE" 2>/dev/null | cut -d= -f2-)
    case "$cmd" in
        skip_phase)
            SKIP_PHASE_FLAG=true
            if kill -0 "${CURRENT_PHASE_PID:-0}" 2>/dev/null; then
                kill -TERM "$CURRENT_PHASE_PID"
                # Fallback: if child ignores SIGTERM, force after 3s
                ( sleep 3; kill -0 "${CURRENT_PHASE_PID:-0}" 2>/dev/null && kill -9 "$CURRENT_PHASE_PID" ) &
            fi
            ;;
        skip_to_report)
            SKIP_TO_REPORT_FLAG=true
            kill -0 "${CURRENT_PHASE_PID:-0}" 2>/dev/null && kill -TERM "$CURRENT_PHASE_PID"
            ;;
        /*)
            dispatch_command "${cmd:1}" "mid-run"
            ;;
    esac
}
trap '_handle_sigusr1' USR1

# ─────────────────────────────────────────────────────────────────────────────
# Logging Functions (symbol-prefixed, ASCII fallback)
# ─────────────────────────────────────────────────────────────────────────────

_bv_sym() {
    # $1=unicode_sym $2=ascii_sym $3=color_code $4=message
    local nl="\n"
    # If live UI is active, the terminal might be in raw mode (no automatic CR on LF)
    [ "${LIVE_UI_ACTIVE:-false}" = "true" ] && nl="\r\n"

    if [ -t 2 ] && has_unicode && [ -z "${NO_COLOR:-}" ]; then
        printf "\e[%sm%s\e[0m %s%b" "$3" "$1" "$4" "$nl" >&2
    elif [ -t 2 ] && [ -z "${NO_COLOR:-}" ]; then
        printf "%s %s%b" "$2" "$4" "$nl" >&2
    else
        printf "%s %s\n" "$2" "$4" >&2
    fi
}
log_info()    { _bv_sym "▸" ">" "34" "$1"; }
log_success() { _bv_sym "✓" "+" "32" "$1"; }
log_warning() { _bv_sym "⚠" "!" "33" "$1"; }
log_error()   { _bv_sym "✗" "x" "31" "$1"; }
log_section() { _bv_sym "─" "-" "36;2" "$1"; }
log_verbose() {
    [ "${VERBOSE:-false}" = "true" ] && _bv_sym "◆" "*" "35;2" "$1"
    return 0
}

# ─────────────────────────────────────────────────────────────────────────────
# Help
# ─────────────────────────────────────────────────────────────────────────────

show_help() {
    cat << 'EOF'
BuildVerify - Build and Test Orchestrator with Shared Memory

DESCRIPTION:
    Orchestrates the complete build-and-test pipeline with Letta memory
    integration. Runs BuildAgent first, then TestAgent on success, sharing
    context between stages via persistent memory.

USAGE:
    BuildVerify.sh [OPTIONS]

INPUT OPTIONS:
    --prompt <string>       Direct prompt for build task
    --plan <file.md>        Plan file for build task

PROJECT OPTIONS:
    --project <path>        Xcode project/workspace path (auto-detected)
    --scheme <name>         Target scheme (auto-detected)

AI OPTIONS:
    --ai-provider <name>    AI provider: cursor, claude, codex, gemini, aider, letta, kimi
                            (default: cursor, or AI_PROVIDER env var)
    --ai-model <model>      Specific AI model (provider-dependent)
                            Example: --ai-model kimi-k2-0711-preview
    --yolo                  Enable YOLO mode (fully automated, no confirmations)

PIPELINE OPTIONS:
    --skip-tests            Skip test phase after successful build
    --happy-only            Focus on happy path only (no sad/regression/coverage waves)
                            Auto-enabled when no prompt/plan is provided
    --no-context            Skip Swift docs context gathering (faster, no 60s RAG wait)
    --no-letta              Completely bypass Letta memory (alias: --skip-memory)
    --skip-memory           Disable Letta memory integration
    --max-build-attempts <n> Maximum BuildAgent retry attempts (default: 5)
    --max-test-attempts <n>  Maximum TestAgent retry attempts (default: 3)

SIMULATOR / ARGENT OPTIONS:
    --simulator-name <name> Simulator name to forward to testAgent for Argent
                            runtime verification (e.g., "iPhone 16 Pro")
    --skip-argent           Skip the Argent runtime verification stage (Stage 5b)
    --platform <name>       Platform to build for (forwarded to BuildAgent)
    --destination <dest>    Full xcodebuild destination string (forwarded to BuildAgent)
    --stage <name>          Run only a specific test stage (forwarded to testAgent)

OUTPUT OPTIONS:
    --artifacts-dir <path>  Output directory for artifacts
    --verbose               Enable verbose logging
    --dry-run               Show what would be done without executing
    --sidebar               Enable persistent sidebar status bar (interactive terminals only)
    --interactive, -i       Enable interactive configuration shell and mid-run command bar

SESSION OPTIONS:
    --session               Use session defaults for configuration
    --session-set <k=v>     Set session default (scheme, platform, simulator)

    --help                  Show this help message

MEMORY INTEGRATION:
    When Letta is configured (LETTA_API_KEY set), BuildVerify:
    - Creates a project-specific agent with shared memory blocks
    - Retrieves learned error patterns before build
    - Stores successful patterns after build
    - Shares build context with test agent
    - Stores test results for future reference

ENVIRONMENT VARIABLES:
    LETTA_API_KEY           API key for Letta (enables memory integration)
    LETTA_BASE_URL          Optional: Self-hosted Letta server URL
    LETTA_MODEL             Optional: AI model for memory agent
    AI_PROVIDER             Default AI provider
    MAX_BUILD_ATTEMPTS      Default max build attempts
    MAX_TEST_ATTEMPTS       Default max test attempts

EXAMPLES:
    # Basic build and test
    BuildVerify.sh --prompt "Add login feature"

    # With specific AI provider and YOLO mode
    BuildVerify.sh --ai-provider claude --yolo --prompt "Fix authentication bug"

    # Build only, skip tests
    BuildVerify.sh --skip-tests --prompt "Refactor database layer"

    # With plan file
    BuildVerify.sh --plan Plans/feature-login.md

    # With plans directory (executes sequentially)
    BuildVerify.sh --plans-dir Plans/

    # Disable memory / Letta (two equivalent flags)
    BuildVerify.sh --no-letta --prompt "Quick fix"
    BuildVerify.sh --skip-memory --prompt "Quick fix"

    # Full pipeline with Argent runtime verification
    BuildVerify.sh --simulator-name "iPhone 16 Pro" --prompt "Add login feature"

    # Skip Argent stage
    BuildVerify.sh --skip-argent --prompt "Quick fix"

EXIT CODES:
    0  - Success (build and tests passed)
    10 - Build failed after max retries
    11 - Misconfiguration
    20 - Human intervention required
    30 - Tests failed (build succeeded)
EOF
}

# ─────────────────────────────────────────────────────────────────────────────
# Argument Parsing
# ─────────────────────────────────────────────────────────────────────────────

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --prompt)
                PROMPT="$2"
                shift 2
                ;;
            --plan)
                PLAN_FILE="$2"
                shift 2
                ;;
            --plans-dir)
                PLANS_DIR="$2"
                shift 2
                ;;
            --project)
                PROJECT_PATH="$2"
                shift 2
                ;;
            --scheme)
                SCHEME="$2"
                shift 2
                ;;
            --ai-provider)
                AI_PROVIDER="$2"
                shift 2
                ;;
            --ai-model)
                AI_MODEL="$2"
                shift 2
                ;;
            --yolo)
                YOLO_MODE="true"
                shift
                ;;
            --skip-tests)
                SKIP_TESTS="true"
                shift
                ;;
            --skip-memory|--no-letta)
                SKIP_MEMORY="true"
                shift
                ;;
            --max-build-attempts)
                MAX_BUILD_ATTEMPTS="$2"
                shift 2
                ;;
            --max-test-attempts)
                MAX_TEST_ATTEMPTS="$2"
                shift 2
                ;;
            --artifacts-dir)
                ARTIFACTS_DIR="$2"
                shift 2
                ;;
            --verbose)
                VERBOSE="true"
                shift
                ;;
            --dry-run)
                DRY_RUN="true"
                shift
                ;;
            --sidebar)
                SIDEBAR_MODE="true"
                shift
                ;;
            --simulator-name)
                SIMULATOR_NAME="$2"
                shift 2
                ;;
            --skip-argent)
                SKIP_ARGENT="true"
                shift
                ;;
            --no-context)
                NO_CONTEXT="true"
                shift
                ;;
            --platform)
                PLATFORM="$2"
                shift 2
                ;;
            --destination)
                DESTINATION="$2"
                shift 2
                ;;
            --stage)
                STAGE="$2"
                shift 2
                ;;
            --session)
                USE_SESSION="true"
                shift
                ;;
            --session-set)
                local kv="${2:-}"
                local key=$(echo "$kv" | cut -d'=' -f1)
                local value=$(echo "$kv" | cut -d'=' -f2-)
                session_set_default "$key" "$value"
                shift 2
                ;;
            --happy-only)
                HAPPY_ONLY="true"
                shift
                ;;
            --interactive|-i)
                INTERACTIVE_MODE=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 11
                ;;
        esac
    done

    # Auto-detect happy-only mode when no prompt/plan is provided
    if [ -z "$PROMPT" ] && [ -z "$PLAN_FILE" ] && [ -z "$PLANS_DIR" ]; then
        HAPPY_ONLY="true"
        log_info "No prompt/plan provided — running in happy-path-only mode (build + basic tests)"
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Validation
# ─────────────────────────────────────────────────────────────────────────────

validate_dependencies() {
    # Check BuildAgent exists
    if [ ! -x "$BUILD_AGENT" ]; then
        log_error "BuildAgent.sh not found or not executable: $BUILD_AGENT"
        return 1
    fi

    # Check TestAgent exists
    if [ ! -x "$TEST_AGENT" ]; then
        log_error "testAgent.sh not found or not executable: $TEST_AGENT"
        return 1
    fi

    # Check letta_memory.py exists (not required, but log if missing)
    if [ ! -f "$LETTA_MEMORY" ]; then
        log_warning "letta_memory.py not found: $LETTA_MEMORY"
        log_info "Memory integration will be disabled"
        SKIP_MEMORY="true"
    fi

    return 0
}

validate_input() {
    # Validate plan file exists if specified
    if [ -n "$PLAN_FILE" ] && [ ! -f "$PLAN_FILE" ]; then
        log_error "Plan file not found: $PLAN_FILE"
        return 1
    fi

    # Validate plans directory exists if specified
    if [ -n "$PLANS_DIR" ] && [ ! -d "$PLANS_DIR" ]; then
        log_error "Plans directory not found: $PLANS_DIR"
        return 1
    fi

    return 0
}

# ─────────────────────────────────────────────────────────────────────────────
# Letta Memory Functions
# ─────────────────────────────────────────────────────────────────────────────

init_letta_memory() {
    if [ "$SKIP_MEMORY" = "true" ]; then
        log_verbose "Memory integration disabled by --skip-memory"
        return 0
    fi

    # Check Python availability
    if ! command -v python3 >/dev/null 2>&1; then
        log_warning "Python3 not available - memory integration disabled"
        LETTA_ENABLED="false"
        return 0
    fi

    # Check environment
    local check_result
    check_result=$(python3 "$LETTA_MEMORY" check-env 2>/dev/null || echo "ERROR")

    if [ "$check_result" != "OK" ]; then
        case "$check_result" in
            MISSING_PACKAGE)
                log_warning "agentic-learning package not installed"
                log_info "Install with: pip install agentic-learning"
                ;;
            MISSING_API_KEY)
                log_warning "LETTA_API_KEY not set"
                log_info "Get your API key from: https://app.letta.com/api-keys"
                ;;
            PYTHON_VERSION_ERROR*)
                log_warning "Python 3.10+ required for memory integration"
                ;;
            *)
                log_warning "Letta environment check failed: $check_result"
                ;;
        esac
        LETTA_ENABLED="false"
        return 0
    fi

    # Generate project-specific agent name
    local project_name
    project_name=$(basename "$WORK_DIR")
    local project_hash
    project_hash=$(echo "$WORK_DIR" | md5 2>/dev/null | cut -c1-8 || echo "$RANDOM")
    LETTA_AGENT="foundation_${project_name}_${project_hash}"

    log_info "Initializing Letta memory agent: $LETTA_AGENT"

    # Initialize agent with memory blocks
    local init_result
    if init_result=$(python3 "$LETTA_MEMORY" init \
        --agent "$LETTA_AGENT" \
        --memory "build_context,error_patterns,success_patterns,test_results,session_summary" </dev/null 2>&1); then
        LETTA_ENABLED="true"
        log_success "Letta memory initialized"
        log_verbose "Agent: $LETTA_AGENT"
    else
        log_warning "Failed to initialize Letta memory: $init_result"
        LETTA_ENABLED="false"
    fi

    return 0
}

store_memory() {
    local block="$1"
    local data="$2"

    [ "$LETTA_ENABLED" != "true" ] && return 0

    log_verbose "Storing to memory block: $block"
    python3 "$LETTA_MEMORY" store \
        --agent "$LETTA_AGENT" \
        --block "$block" \
        --data "$data" >/dev/null 2>&1 || true
}

retrieve_memory() {
    local block="$1"

    [ "$LETTA_ENABLED" != "true" ] && echo "" && return 0

    python3 "$LETTA_MEMORY" retrieve \
        --agent "$LETTA_AGENT" \
        --block "$block" 2>/dev/null || echo ""
}

search_memory() {
    local query="$1"

    [ "$LETTA_ENABLED" != "true" ] && echo "" && return 0

    python3 "$LETTA_MEMORY" search \
        --agent "$LETTA_AGENT" \
        --query "$query" 2>/dev/null || echo ""
}

# Poll for interactive keys while a background phase runs.
# Reads from stdin with a 1-second timeout so the loop is responsive
# but doesn't spin. Handles s (skip phase), r (skip to report), ? (help).
_wait_with_key_poll() {
    local pid="$1"
    # If live UI is active, the background keyreader handles stdin.
    # We just wait for the process to exit.
    if [ "${LIVE_UI_ACTIVE:-false}" = "true" ]; then
        wait "$pid" 2>/dev/null || return $?
        return 0
    fi

    # Legacy polling for non-live-UI mode
    while kill -0 "$pid" 2>/dev/null; do
        local key=""
        if IFS= read -rs -t 1 -n 1 key 2>/dev/null; then
            case "$key" in
                s|S)
                    SKIP_PHASE_FLAG=true
                    kill -TERM "$pid" 2>/dev/null
                    ( sleep 3; kill -0 "$pid" 2>/dev/null && kill -9 "$pid" ) &
                    break
                    ;;
                r|R)
                    SKIP_TO_REPORT_FLAG=true
                    kill -TERM "$pid" 2>/dev/null
                    break
                    ;;
                '?')
                    if [ -n "${LIVE_UI_STATE_FILE:-}" ]; then
                        local tmp; tmp=$(mktemp "${LIVE_UI_STATE_FILE}.XXXXXX")
                        grep -v '^cmd=' "$LIVE_UI_STATE_FILE" 2>/dev/null > "$tmp" || true
                        printf "cmd=help\n" >> "$tmp"
                        mv "$tmp" "$LIVE_UI_STATE_FILE"
                    fi
                    ;;
            esac
        fi
    done
    wait "$pid" 2>/dev/null
}

# ─────────────────────────────────────────────────────────────────────────────
# Build Phase
# ─────────────────────────────────────────────────────────────────────────────

run_build_phase() {
    update_sidebar_stage "Building"

    show_phase_divider "Phase 1: Build"
    update_live_op "Running BuildAgent"
    draw_phase_tracker "init:done,build:active,test:pending,complete:pending"

    # Store build context
    if [ "$LETTA_ENABLED" = "true" ]; then
        local build_context
        build_context=$(cat << EOF
{
    "session_id": "$SESSION_ID",
    "project_dir": "$WORK_DIR",
    "scheme": "${SCHEME:-auto}",
    "prompt": "${PROMPT:-}",
    "plan_file": "${PLAN_FILE:-}",
    "ai_provider": "$AI_PROVIDER",
    "started_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "max_attempts": $MAX_BUILD_ATTEMPTS
}
EOF
)
        store_memory "build_context" "$build_context"
    fi

    # Build command arguments
    local build_args=()
    build_args+=("--ai-provider" "$AI_PROVIDER")
    build_args+=("--max-attempts" "$MAX_BUILD_ATTEMPTS")

    [ -n "$AI_MODEL" ] && build_args+=("--ai-model" "$AI_MODEL")
    [ -n "$PROMPT" ] && build_args+=("--prompt-string" "$PROMPT")
    [ -n "$PLAN_FILE" ] && build_args+=("--plan" "$PLAN_FILE")
    [ -n "$PLANS_DIR" ] && build_args+=("--plans-dir" "$PLANS_DIR")
    [ -n "$PROJECT_PATH" ] && build_args+=("--project" "$PROJECT_PATH")
    [ -n "$SCHEME" ] && build_args+=("--scheme" "$SCHEME")
    [ -n "$ARTIFACTS_DIR" ] && build_args+=("--artifacts-dir" "$ARTIFACTS_DIR")
    [ -n "$PLATFORM" ] && build_args+=("--platform" "$PLATFORM")
    [ -n "$DESTINATION" ] && build_args+=("--destination" "$DESTINATION")
    [ "$YOLO_MODE" = "true" ] && build_args+=("--yolo")
    [ "$VERBOSE" = "true" ] && build_args+=("--verbose")
    [ "$DRY_RUN" = "true" ] && build_args+=("--dry-run")
    [ "$NO_CONTEXT" = "true" ] && build_args+=("--no-swift-docs")
    # Suppress BuildAgent's fancy terminal UI so it does not clear/overwrite BuildVerify's output
    build_args+=("--no-fancy-ui")

    # Forward iOS-only build flag
    if [ -n "${AUTO_MULTI_PLATFORM:-}" ]; then
        export AUTO_MULTI_PLATFORM
    fi

    # Pass memory agent to BuildAgent
    if [ "$LETTA_ENABLED" = "true" ]; then
        export LETTA_MEMORY_AGENT="$LETTA_AGENT"
        export LETTA_MEMORY_SCRIPT="$LETTA_MEMORY"
    fi

    log_info "Running BuildAgent..."
    update_live_op "Running BuildAgent"
    log_verbose "Args: ${build_args[*]}"

    if [ "$DRY_RUN" = "true" ]; then
        log_info "[DRY RUN] Would execute: $BUILD_AGENT ${build_args[*]}"
        BUILD_EXIT_CODE=0
        return 0
    fi

    # Run BuildAgent
    set +e
    "$BUILD_AGENT" "${build_args[@]}"
    BUILD_EXIT_CODE=$?
    set -e

    # Store result
    if [ "$LETTA_ENABLED" = "true" ]; then
        if [ $BUILD_EXIT_CODE -eq 0 ]; then
            store_memory "success_patterns" "{\"phase\": \"build\", \"success\": true, \"prompt\": \"${PROMPT:-}\", \"timestamp\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"}"
        else
            store_memory "error_patterns" "{\"phase\": \"build\", \"exit_code\": $BUILD_EXIT_CODE, \"prompt\": \"${PROMPT:-}\", \"timestamp\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"}"
        fi
    fi

    if [ $BUILD_EXIT_CODE -eq 0 ]; then
        BUILD_ATTEMPTS_USED=1
        log_success "Build phase completed successfully"
        draw_phase_tracker "init:done,build:done,test:pending,complete:pending"
    else
        BUILD_ATTEMPTS_USED=$MAX_BUILD_ATTEMPTS
        log_error "Build phase failed (exit code: $BUILD_EXIT_CODE)"
        draw_phase_tracker "init:done,build:failed,test:pending,complete:pending"
    fi

    return $BUILD_EXIT_CODE
}

# ─────────────────────────────────────────────────────────────────────────────
# Test Phase
# ─────────────────────────────────────────────────────────────────────────────

run_test_phase() {
    if [ "$SKIP_TESTS" = "true" ]; then
        log_info "Skipping test phase (--skip-tests)"
        return 0
    fi

    update_sidebar_stage "Testing"

    show_phase_divider "Phase 2: Test"
    update_live_op "Running testAgent"
    draw_phase_tracker "init:done,build:done,test:active,complete:pending"

    # Build command arguments
    local test_args=()
    test_args+=("--ai-provider" "$AI_PROVIDER")

    [ -n "$PROJECT_PATH" ] && test_args+=("--project" "$PROJECT_PATH")
    [ -n "$SCHEME" ] && test_args+=("--scheme" "$SCHEME")
    [ -n "$ARTIFACTS_DIR" ] && test_args+=("--artifacts-dir" "$ARTIFACTS_DIR")
    [ -n "$STAGE" ] && test_args+=("--stage" "$STAGE")
    [ "$YOLO_MODE" = "true" ] && test_args+=("--yolo")
    [ "$VERBOSE" = "true" ] && test_args+=("--verbose")
    [ "$DRY_RUN" = "true" ] && test_args+=("--dry-run")
    [ -n "$SIMULATOR_NAME" ] && test_args+=("--simulator-name" "$SIMULATOR_NAME")
    [ "$SKIP_ARGENT" = "true" ] && test_args+=("--skip-argent")
    [ "$HAPPY_ONLY" = "true" ] && test_args+=("--happy-only")

    # If only argent stage is requested, skip all other test stages
    if [ "$STAGE" = "argent" ]; then
        test_args+=("--skip-unit" "--skip-accessibility" "--skip-flow" "--skip-ui" "--skip-run")
    fi

    # Pass memory agent to TestAgent
    if [ "$LETTA_ENABLED" = "true" ]; then
        export LETTA_MEMORY_AGENT="$LETTA_AGENT"
        export LETTA_MEMORY_SCRIPT="$LETTA_MEMORY"
    fi

    log_info "Running TestAgent..."
    log_verbose "Args: ${test_args[*]}"

    if [ "$DRY_RUN" = "true" ]; then
        log_info "[DRY RUN] Would execute: $TEST_AGENT ${test_args[*]}"
        TEST_EXIT_CODE=0
        return 0
    fi

    # Run TestAgent
    set +e
    "$TEST_AGENT" "${test_args[@]}"
    TEST_EXIT_CODE=$?
    set -e

    # Store result
    if [ "$LETTA_ENABLED" = "true" ]; then
        store_memory "test_results" "{\"exit_code\": $TEST_EXIT_CODE, \"timestamp\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"}"
    fi

    if [ $TEST_EXIT_CODE -eq 0 ]; then
        TEST_ATTEMPTS_USED=1
        log_success "Test phase completed successfully"
        draw_phase_tracker "init:done,build:done,test:done,complete:active"
    else
        TEST_ATTEMPTS_USED=$MAX_TEST_ATTEMPTS
        log_error "Test phase failed (exit code: $TEST_EXIT_CODE)"
        draw_phase_tracker "init:done,build:done,test:failed,complete:pending"
    fi

    return $TEST_EXIT_CODE
}

run_interactive_shell() {
    [ -t 0 ] || return 0  # degrade on non-TTY
    local live_ui_was_active=false
    # Temporarily reset scroll region so read -e has a clean full-screen terminal.
    if [ "${LIVE_UI_ACTIVE:-false}" = "true" ]; then
        live_ui_was_active=true
        stop_live_daemon
        if [ -n "${LIVE_UI_STATE_FILE:-}" ]; then
            local tmp
            tmp=$(mktemp "${LIVE_UI_STATE_FILE}.XXXXXX")
            grep -v '^command_mode=' "$LIVE_UI_STATE_FILE" 2>/dev/null > "$tmp" || true
            printf "command_mode=1\n" >> "$tmp"
            mv "$tmp" "$LIVE_UI_STATE_FILE"
        fi
        printf "\e[r\e[?25h" >&2
        printf "\e[%s;1H\e[2K" "$LIVE_UI_HEIGHT" >&2
    fi
    _bv_show_config

    # Optional tab completion (Bash 4+)
    if [ "${BASH_VERSINFO[0]:-3}" -ge 4 ]; then
        _bv_complete() {
            local commands="/run /quit /skip-memory /skip-tests /dry-run /verbose /yolo /sidebar /skip-argent /no-context /happy-only /ai-provider /ai-model /scheme /project /simulator /platform /max-build /max-test /prompt /plan /artifacts /status /flags /help"
            COMPREPLY=( $(compgen -W "$commands" -- "${COMP_WORDS[COMP_CWORD]}") )
        }
        complete -F _bv_complete buildverify 2>/dev/null || true
    fi

    local input
    local interactive_rc=0
    while true; do
        read -e -p $'\e[36mbuildverify\e[0m \e[2m>\e[0m ' input || break
        [[ -z "$input" ]] && continue
        [[ "$input" != /* ]] && { printf "  Commands start with /. Type /help.\n" >&2; continue; }
        dispatch_command "$input" "pre-run"
        local rc=$?
        [ $rc -eq 99 ] && break
        [ $rc -eq 98 ] && { interactive_rc=1; break; }
        _bv_show_config
    done

    complete -r buildverify 2>/dev/null || true
    # Restore scroll region for live UI.
    if [ "$live_ui_was_active" = "true" ]; then
        if [ -n "${LIVE_UI_STATE_FILE:-}" ]; then
            local tmp
            tmp=$(mktemp "${LIVE_UI_STATE_FILE}.XXXXXX")
            grep -v '^command_mode=' "$LIVE_UI_STATE_FILE" 2>/dev/null > "$tmp" || true
            mv "$tmp" "$LIVE_UI_STATE_FILE"
        fi
        printf "\e[r\e[?25h" >&2
        printf "\e[1;1H\e[2K\e[2;1H\e[2K\e[3;1H\e[J" >&2
        printf "\e[3;%sr\e[3;1H" "$((LIVE_UI_HEIGHT - 1))" >&2
        if [ "$interactive_rc" -eq 0 ] && [ "${LIVE_UI_ACTIVE:-false}" = "true" ]; then
            start_live_daemon &
            LIVE_UI_DAEMON_PID=$!
        fi
    fi
    return "$interactive_rc"
}

# ─────────────────────────────────────────────────────────────────────────────
# Session Summary
# ─────────────────────────────────────────────────────────────────────────────

store_session_summary() {
    [ "$LETTA_ENABLED" != "true" ] && return 0

    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - PIPELINE_START_TIME))

    local summary
    summary=$(cat << EOF
{
    "session_id": "$SESSION_ID",
    "completed_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "duration_seconds": $duration,
    "build_exit_code": $BUILD_EXIT_CODE,
    "test_exit_code": $TEST_EXIT_CODE,
    "tests_skipped": $( [ "$SKIP_TESTS" = "true" ] && echo "true" || echo "false" ),
    "ai_provider": "$AI_PROVIDER",
    "yolo_mode": $( [ "$YOLO_MODE" = "true" ] && echo "true" || echo "false" )
}
EOF
)

    store_memory "session_summary" "$summary"
    log_verbose "Session summary stored to memory"
}

# ─────────────────────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────────────────────

main() {
    parse_args "$@"

    # Generate session ID
    SESSION_ID="verify_$(date +%Y%m%d_%H%M%S)"
    PIPELINE_START_TIME=$(date +%s)

    # Enable sidebar / live UI before starting pipeline (if requested)
    if [ "$SIDEBAR_MODE" = "true" ]; then
        enable_sidebar_mode
    fi

    enable_split_layout
    show_pipeline_header "$SESSION_ID" "${AI_PROVIDER:-cursor}" "$PWD"
    update_sidebar_stage "Initializing"

    # Validate dependencies
    if ! validate_dependencies; then
        exit 11
    fi

    # Validate input
    if ! validate_input; then
        exit 11
    fi

    # Initialize Letta memory
    init_letta_memory

    # Load session defaults if enabled
    if [ "$USE_SESSION" = "true" ]; then
        session_load || true
        SESSION_SCHEME=$(session_get_default "scheme")
        SESSION_PLATFORM=$(session_get_default "platform")
        SESSION_SIMULATOR=$(session_get_default "simulator")

        # Apply defaults if not explicitly set
        [ -z "$SCHEME" ] && [ -n "$SESSION_SCHEME" ] && SCHEME="$SESSION_SCHEME"
        # Additional session defaults can be applied here
    fi

    # Initialize and apply learned hyperparameters
    log_verbose "Entering init_hyperparams..."
    init_hyperparams
    log_verbose "Entering apply_hyperparams..."
    apply_hyperparams
    log_verbose "Hyperparams done, showing config..."

    # Pre-run interactive shell
    if [ "$INTERACTIVE_MODE" = "true" ]; then
        run_interactive_shell || exit 0
    fi
    enable_keyreader   # start stdin raw mode only after all init and pre-run REPL complete

    # Set initial agent state
    set_agent_indicator "idle"

    # Show configuration
    log_info "Session: $SESSION_ID"
    log_info "Working Directory: $WORK_DIR"
    log_info "AI Provider: $AI_PROVIDER"
    [ -n "$PROMPT" ] && log_info "Prompt: ${PROMPT:0:50}..."
    [ -n "$PLAN_FILE" ] && log_info "Plan File: $PLAN_FILE"
    [ "$YOLO_MODE" = "true" ] && log_info "YOLO Mode: enabled"
    [ "$SKIP_TESTS" = "true" ] && log_info "Tests: skipped"
    [ "$LETTA_ENABLED" = "true" ] && log_info "Memory: enabled ($LETTA_AGENT)"
    [ "$USE_SESSION" = "true" ] && log_info "Session Defaults: enabled"
    echo "" >&2

    # Run build phase (backgrounded for interactive skip)
    update_live_step "1/2"
    set_agent_indicator "idle"
    run_build_phase &
    CURRENT_PHASE_PID=$!
    BUILD_EXIT=0
    _wait_with_key_poll "$CURRENT_PHASE_PID" || BUILD_EXIT=$?
    CURRENT_PHASE_PID=""
    if [ "$ABORT_FLAG" = "true" ]; then
        log_warning "Pipeline aborted by user"
        BUILD_VERIFY_STATUS="aborted"
        store_session_summary
        disable_split_layout
        local _dur=$(( $(date +%s) - PIPELINE_START_TIME ))
        show_pipeline_summary "aborted" "$SESSION_ID" "$_dur" "${LETTA_AGENT:-}" "Build:aborted:" "Tests:skipped:"
        exit 0
    fi
    if [ "$SKIP_PHASE_FLAG" = "true" ]; then
        SKIP_PHASE_FLAG=false
        log_warning "Build phase skipped by user"
        set_agent_indicator "idle"
        draw_phase_tracker "init:done,build:skipped,test:pending,complete:pending"
    elif [ "$SKIP_TO_REPORT_FLAG" = "true" ]; then
        :
    elif [ "$BUILD_EXIT" -ne 0 ]; then
        store_session_summary
        set_agent_indicator "thinking"
        disable_split_layout
        local _fail_dur=$(( $(date +%s) - PIPELINE_START_TIME ))
        show_pipeline_summary \
            "failed" \
            "$SESSION_ID" \
            "$_fail_dur" \
            "${LETTA_AGENT:-}" \
            "Build:failed:exit $BUILD_EXIT_CODE" \
            "Tests:skipped:"
        exit $BUILD_EXIT_CODE
    fi
    update_live_step "2/2"

    # Run test phase (backgrounded for interactive skip)
    if [ "$SKIP_TO_REPORT_FLAG" = "true" ]; then
        log_info "Skipping to report (user requested)"
    else
        update_live_step "1/2"
        set_agent_indicator "idle"
        run_test_phase &
        CURRENT_PHASE_PID=$!
        TEST_EXIT=0
        _wait_with_key_poll "$CURRENT_PHASE_PID" || TEST_EXIT=$?
        CURRENT_PHASE_PID=""
        if [ "$ABORT_FLAG" = "true" ]; then
            log_warning "Pipeline aborted by user"
            BUILD_VERIFY_STATUS="aborted"
            store_session_summary
            disable_split_layout
            local _dur=$(( $(date +%s) - PIPELINE_START_TIME ))
            show_pipeline_summary "aborted" "$SESSION_ID" "$_dur" "${LETTA_AGENT:-}" "Build:passed:" "Tests:aborted:"
            exit 0
        fi
        if [ "$SKIP_PHASE_FLAG" = "true" ]; then
            SKIP_PHASE_FLAG=false
            log_warning "Test phase skipped by user"
            set_agent_indicator "idle"
            draw_phase_tracker "init:done,build:done,test:skipped,complete:pending"
        elif [ "$SKIP_TO_REPORT_FLAG" = "true" ]; then
            :
        elif [ "$TEST_EXIT" -ne 0 ]; then
            store_session_summary
            disable_split_layout
            local _fail_dur=$(( $(date +%s) - PIPELINE_START_TIME ))
            show_pipeline_summary \
                "failed" \
                "$SESSION_ID" \
                "$_fail_dur" \
                "${LETTA_AGENT:-}" \
                "Build:passed:" \
                "Tests:failed:exit $TEST_EXIT_CODE"
            exit 30
        fi
        update_live_step "2/2"
    fi

    # Store session summary
    store_session_summary
    update_sidebar_stage "Complete"

    # Record hyperparameter outcome and update policy
    local pipeline_duration=$(($(date +%s) - PIPELINE_START_TIME))
    local build_attempts_used=${BUILD_ATTEMPTS_USED:-0}
    local test_attempts_used=${TEST_ATTEMPTS_USED:-0}
    record_hyperparam_outcome "$build_attempts_used" "$test_attempts_used" "true" "true" "$pipeline_duration"
    update_hyperparams
    log_info "Hyperparameters updated for next run"

    # Save session defaults if used
    if [ "$USE_SESSION" = "true" ]; then
        session_save || true
    fi

    # Final summary panel
    set_agent_indicator "idle"
    disable_split_layout
    local _bv_status="passed"
    local _test_status="passed"
    [ "$SKIP_TESTS" = "true" ] && _test_status="skipped"
    # Reflect interactive skip state in summary
    if [ "$SKIP_TO_REPORT_FLAG" = "true" ] || [ "$SKIP_PHASE_FLAG" = "true" ]; then
        _bv_status="skipped"
        _test_status="skipped"
    fi
    show_pipeline_summary \
        "$_bv_status" \
        "$SESSION_ID" \
        "$pipeline_duration" \
        "${LETTA_AGENT:-}" \
        "Build:${_bv_status}:" \
        "Tests:${_test_status}:"

    # Export status for scripts
    echo ""
    echo "BUILD_VERIFY_STATUS=success"
    echo "BUILD_VERIFY_SESSION=$SESSION_ID"
    echo "BUILD_VERIFY_DURATION=$pipeline_duration"
    [ "$LETTA_ENABLED" = "true" ] && echo "BUILD_VERIFY_MEMORY_AGENT=$LETTA_AGENT"

    exit 0
}

main "$@"
