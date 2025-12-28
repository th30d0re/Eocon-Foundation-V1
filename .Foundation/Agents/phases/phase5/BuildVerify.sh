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

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Configuration variables
PROJECT_PATH=""
SCHEME=""
PROMPT=""
PLAN_FILE=""
AI_PROVIDER="${AI_PROVIDER:-cursor}"
YOLO_MODE="false"
SKIP_TESTS="false"
SKIP_MEMORY="false"
VERBOSE="false"
DRY_RUN="false"
MAX_BUILD_ATTEMPTS="${MAX_BUILD_ATTEMPTS:-5}"
MAX_TEST_ATTEMPTS="${MAX_TEST_ATTEMPTS:-3}"
ARTIFACTS_DIR=""

# Session tracking
SESSION_ID=""
WORK_DIR="$(pwd)"
LETTA_ENABLED="false"
LETTA_AGENT=""
PIPELINE_START_TIME=""
BUILD_EXIT_CODE=0
TEST_EXIT_CODE=0

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
    echo -e "${CYAN}[BUILD-VERIFY]${NC} $1" >&2
}

log_verbose() {
    [ "$VERBOSE" = "true" ] && echo -e "${MAGENTA}[VERBOSE]${NC} $1" >&2
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
    --ai-provider <name>    AI provider: cursor, claude, codex, gemini, aider, letta
                            (default: cursor, or AI_PROVIDER env var)
    --yolo                  Enable YOLO mode (fully automated, no confirmations)

PIPELINE OPTIONS:
    --skip-tests            Skip test phase after successful build
    --skip-memory           Disable Letta memory integration
    --max-build-attempts <n> Maximum BuildAgent retry attempts (default: 5)
    --max-test-attempts <n>  Maximum TestAgent retry attempts (default: 3)

OUTPUT OPTIONS:
    --artifacts-dir <path>  Output directory for artifacts
    --verbose               Enable verbose logging
    --dry-run               Show what would be done without executing
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

    # Disable memory integration
    BuildVerify.sh --skip-memory --prompt "Quick fix"

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
            --yolo)
                YOLO_MODE="true"
                shift
                ;;
            --skip-tests)
                SKIP_TESTS="true"
                shift
                ;;
            --skip-memory)
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
        --memory "build_context,error_patterns,success_patterns,test_results,session_summary" 2>&1); then
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

# ─────────────────────────────────────────────────────────────────────────────
# Build Phase
# ─────────────────────────────────────────────────────────────────────────────

run_build_phase() {
    log_section "=========================================="
    log_section "Phase 1: Build"
    log_section "=========================================="
    echo "" >&2

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

    [ -n "$PROMPT" ] && build_args+=("--prompt" "$PROMPT")
    [ -n "$PLAN_FILE" ] && build_args+=("--plans-dir" "$(dirname "$PLAN_FILE")")
    [ -n "$PROJECT_PATH" ] && build_args+=("--project" "$PROJECT_PATH")
    [ -n "$SCHEME" ] && build_args+=("--scheme" "$SCHEME")
    [ -n "$ARTIFACTS_DIR" ] && build_args+=("--artifacts-dir" "$ARTIFACTS_DIR")
    [ "$YOLO_MODE" = "true" ] && build_args+=("--yolo")
    [ "$VERBOSE" = "true" ] && build_args+=("--verbose")
    [ "$DRY_RUN" = "true" ] && build_args+=("--dry-run")

    # Pass memory agent to BuildAgent
    if [ "$LETTA_ENABLED" = "true" ]; then
        export LETTA_MEMORY_AGENT="$LETTA_AGENT"
        export LETTA_MEMORY_SCRIPT="$LETTA_MEMORY"
    fi

    log_info "Running BuildAgent..."
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
        log_success "Build phase completed successfully"
    else
        log_error "Build phase failed (exit code: $BUILD_EXIT_CODE)"
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

    log_section "=========================================="
    log_section "Phase 2: Test"
    log_section "=========================================="
    echo "" >&2

    # Build command arguments
    local test_args=()
    test_args+=("--ai-provider" "$AI_PROVIDER")

    [ -n "$PROJECT_PATH" ] && test_args+=("--project" "$PROJECT_PATH")
    [ -n "$SCHEME" ] && test_args+=("--scheme" "$SCHEME")
    [ -n "$ARTIFACTS_DIR" ] && test_args+=("--artifacts-dir" "$ARTIFACTS_DIR")
    [ "$YOLO_MODE" = "true" ] && test_args+=("--yolo")
    [ "$VERBOSE" = "true" ] && test_args+=("--verbose")
    [ "$DRY_RUN" = "true" ] && test_args+=("--dry-run")

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
        log_success "Test phase completed successfully"
    else
        log_error "Test phase failed (exit code: $TEST_EXIT_CODE)"
    fi

    return $TEST_EXIT_CODE
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

    log_section "=========================================="
    log_section "BuildVerify Pipeline Starting"
    log_section "=========================================="
    echo "" >&2

    # Validate dependencies
    if ! validate_dependencies; then
        exit 11
    fi

    # Initialize Letta memory
    init_letta_memory

    # Show configuration
    log_info "Session: $SESSION_ID"
    log_info "Working Directory: $WORK_DIR"
    log_info "AI Provider: $AI_PROVIDER"
    [ -n "$PROMPT" ] && log_info "Prompt: ${PROMPT:0:50}..."
    [ -n "$PLAN_FILE" ] && log_info "Plan File: $PLAN_FILE"
    [ "$YOLO_MODE" = "true" ] && log_info "YOLO Mode: enabled"
    [ "$SKIP_TESTS" = "true" ] && log_info "Tests: skipped"
    [ "$LETTA_ENABLED" = "true" ] && log_info "Memory: enabled ($LETTA_AGENT)"
    echo "" >&2

    # Run build phase
    if ! run_build_phase; then
        store_session_summary
        log_section "=========================================="
        log_error "BuildVerify Pipeline Failed (Build)"
        log_section "=========================================="
        exit $BUILD_EXIT_CODE
    fi

    # Run test phase
    if ! run_test_phase; then
        store_session_summary
        log_section "=========================================="
        log_error "BuildVerify Pipeline Failed (Tests)"
        log_section "=========================================="
        exit 30
    fi

    # Store session summary
    store_session_summary

    # Final report
    log_section "=========================================="
    log_success "BuildVerify Pipeline Completed"
    log_section "=========================================="
    echo "" >&2

    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - PIPELINE_START_TIME))

    log_info "Session: $SESSION_ID"
    log_info "Duration: ${duration}s"
    log_info "Build: ${GREEN}PASSED${NC}"
    if [ "$SKIP_TESTS" = "true" ]; then
        log_info "Tests: SKIPPED"
    else
        log_info "Tests: ${GREEN}PASSED${NC}"
    fi

    # Export status for scripts
    echo ""
    echo "BUILD_VERIFY_STATUS=success"
    echo "BUILD_VERIFY_SESSION=$SESSION_ID"
    echo "BUILD_VERIFY_DURATION=$duration"
    [ "$LETTA_ENABLED" = "true" ] && echo "BUILD_VERIFY_MEMORY_AGENT=$LETTA_AGENT"

    exit 0
}

main "$@"
