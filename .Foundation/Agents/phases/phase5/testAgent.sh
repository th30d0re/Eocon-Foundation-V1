#!/usr/bin/env bash

# Test Agent - Main Orchestrator
# Orchestrates the complete test automation pipeline
# Based on Foundation methodology and BuildAgent patterns
#
# Pipeline Stages:
#   1. Unit Test Generation
#   2. Accessibility Compliance
#   3. Flow Analysis
#   4. UI Test Generation
#   5. Test Execution
#   5a. Maestro UI Flow Verification
#   5b. Argent Runtime Verification (fallback)
#   6. Report Generation
#
# Exit Codes:
#   0  - Success
#   10 - Stage failure
#   11 - Misconfiguration
#   20 - Human intervention required

set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────────────────────────────────────

# Resolve symlinks to get actual script directory (supports running via symlink)
SOURCE="${BASH_SOURCE[0]}"
while [ -L "$SOURCE" ]; do
    SCRIPT_DIR="$(cd "$(dirname "$SOURCE")" && pwd)"
    SOURCE="$(readlink "$SOURCE")"
    [[ $SOURCE != /* ]] && SOURCE="$SCRIPT_DIR/$SOURCE"
done
SCRIPT_DIR="$(cd "$(dirname "$SOURCE")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"
FOUNDATION_LIB_DIR="$(cd "${SCRIPT_DIR}/../../../lib" && pwd)"

# Load Foundation helpers and check shell compatibility
HELPERS_LIB="${FOUNDATION_LIB_DIR}/helpers.sh"
if [ -f "$HELPERS_LIB" ]; then
    # shellcheck disable=SC1090
    source "$HELPERS_LIB"

    # Check shell compatibility
    if type check_shell_compatibility &>/dev/null; then
        check_shell_compatibility || exit 11
    fi
fi

# Source utility libraries
# shellcheck disable=SC1091
source "${LIB_DIR}/testUtils.sh"

# Set log prefix for this agent
LOG_PREFIX="[TEST-AGENT]"

# Agent scripts
UNIT_TEST_AGENT="${SCRIPT_DIR}/unitTestAgent.sh"
ACCESSIBILITY_AGENT="${SCRIPT_DIR}/accessibilityAgent.sh"
FLOW_AGENT="${SCRIPT_DIR}/flowAgent.sh"
UI_TEST_AGENT="${SCRIPT_DIR}/uiTestAgent.sh"
TEST_RUNNER="${SCRIPT_DIR}/testRunner.sh"
ARGENT_RUNTIME_AGENT="${SCRIPT_DIR}/argentRuntimeAgent.sh"
BUILD_AGENT="${SCRIPT_DIR}/BuildAgent.sh"

# Configuration variables
PROJECT_PATH=""
SCHEME=""
STAGE=""  # Run specific stage only
RESUME_FROM=""  # Resume from specific stage
AI_PROVIDER="${AI_PROVIDER:-cursor}"
YOLO_MODE="${YOLO_MODE:-false}"
RECORD="${RECORD:-false}"
REPORT_DIR=""
ARTIFACTS_DIR="${ARTIFACTS_DIR:-./Artifacts}"
VERBOSE="${VERBOSE:-false}"
DRY_RUN="${DRY_RUN:-false}"

# Simulator preparation
PREPARE_SIMULATOR="${PREPARE_SIMULATOR:-false}"
SIMULATOR_NAME=""
GPS_LOCATION=""
GPS_LAT=""
GPS_LON=""
APPEARANCE_MODE=""
CAPTURE_PIPELINE_LOGS="${CAPTURE_PIPELINE_LOGS:-false}"
PIPELINE_LOG_SESSION=""

# Skip flags
SKIP_UNIT="${SKIP_UNIT:-false}"
SKIP_ACCESSIBILITY="${SKIP_ACCESSIBILITY:-false}"
SKIP_UI="${SKIP_UI:-false}"
SKIP_FLOW="${SKIP_FLOW:-false}"
SKIP_RUN="${SKIP_RUN:-false}"
SKIP_ARGENT="${SKIP_ARGENT:-false}"
SKIP_MAESTRO="${SKIP_MAESTRO:-false}"
DISCOVER_FLOWS="${DISCOVER_FLOWS:-false}"
LEARN_FLOWS="${LEARN_FLOWS:-false}"

# Argent repair configuration
MAX_ARGENT_REPAIR_ATTEMPTS="${MAX_ARGENT_REPAIR_ATTEMPTS:-3}"

# Stress test / robustness simulation
STRESS_TEST="${STRESS_TEST:-false}"
STRESS_LEVEL="${STRESS_LEVEL:-1}"  # 1=light, 2=moderate, 3=severe

# Happy-path-only mode (skip sad/regression/coverage waves)
HAPPY_ONLY="${HAPPY_ONLY:-false}"

# Unified scope control (orchestrator → TestAgent → sub-agents)
SCOPE_COVERAGE=""       # Target coverage percentage (e.g., 80)
SCOPE_STRATEGY=""       # Test strategy: priority, coverage, balanced, happy-only
SCOPE_FILES=""          # File scope pattern (e.g., "Sources/Models/*.swift")

# Letta Memory integration (set by BuildVerify.sh orchestrator)
LETTA_MEMORY_AGENT="${LETTA_MEMORY_AGENT:-}"
LETTA_MEMORY_SCRIPT="${LETTA_MEMORY_SCRIPT:-}"
LETTA_BUILD_CONTEXT=""  # Retrieved build context from memory

# State tracking
STAGES_FILE=""
CURRENT_STAGE=""
PIPELINE_START_TIME=""

# Stage results (bash 3.2-compatible associative-array emulation)
_stage_result() { local v="STAGE_RESULT_${1}"; echo "${!v:-pending}"; }
_set_stage_result() { printf -v "STAGE_RESULT_${1}" "%s" "${2}"; }
_stage_duration() { local v="STAGE_DURATION_${1}"; echo "${!v:-0}"; }
_set_stage_duration() { printf -v "STAGE_DURATION_${1}" "%s" "${2}"; }
_stage_coverage() { local v="STAGE_COVERAGE_${1}"; echo "${!v:-0}"; }
_set_stage_coverage() { printf -v "STAGE_COVERAGE_${1}" "%s" "${2}"; }

PIPELINE_STATE_FILE=""

# ─────────────────────────────────────────────────────────────────────────────
# Pipeline State Persistence (cross-run progress tracking)
# ─────────────────────────────────────────────────────────────────────────────

# Load pipeline state from previous runs
load_pipeline_state() {
    if [ -z "$PIPELINE_STATE_FILE" ] || [ ! -f "$PIPELINE_STATE_FILE" ]; then
        return 0
    fi
    if command -v jq >/dev/null 2>&1; then
        for stage in unit accessibility flow discover ui run maestro argent; do
            local cov
            cov=$(jq -r ".stages.\"$stage\".coverage // 0" "$PIPELINE_STATE_FILE" 2>/dev/null || echo "0")
            _set_stage_coverage "$stage" "$cov"
        done
    fi
}

# Save pipeline state for future runs
save_pipeline_state() {
    if [ -z "$PIPELINE_STATE_FILE" ]; then
        return 0
    fi
    mkdir -p "$(dirname "$PIPELINE_STATE_FILE")"
    if command -v jq >/dev/null 2>&1; then
        local json="{\"updated_at\":\"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\",\"stages\":{"
        local first=true
        for stage in unit accessibility flow discover ui run maestro argent; do
            if [ "$first" = true ]; then first=false; else json+=","; fi
            local cov="$(_stage_coverage "$stage")"
            local status="$(_stage_result "$stage")"
            json+="\"$stage\":{\"coverage\":$cov,\"last_status\":\"$status\"}"
        done
        json+="}}"
        echo "$json" | jq '.' > "$PIPELINE_STATE_FILE"
    fi
}

# Pre-stage prompt: short 3-second window to skip BEFORE stage starts.
# Returns 0 if should skip, 1 if should continue.
prompt_skip_stage() {
    local stage="$1"
    # Skip prompt in non-tty, CI, or when YOLO mode
    if [ ! -t 0 ] || [ "${SKIP_STAGE_PROMPT:-false}" = "true" ] || [ "$YOLO_MODE" = "true" ]; then
        return 1
    fi
    local current_cov="$(_stage_coverage "$stage")"
    echo "" >&2
    log_info "Stage: $stage (previous coverage: ${current_cov}%)"
    log_info "Press 's' NOW to skip, or press 's' at any time during the stage to abort"

    local response
    if IFS= read -rs -t 2 -n 1 response < /dev/tty 2>/dev/null; then
        if [ "$response" = "s" ] || [ "$response" = "S" ]; then
            log_warning "Skipping stage: $stage"
            return 0
        fi
    fi
    return 1
}

# Recursively kill a process tree starting from pid.  Uses pgrep -P (macOS).
kill_stage_tree() {
    local pid="$1"
    local signal="${2:-TERM}"
    local children
    children=$(pgrep -P "$pid" 2>/dev/null || true)
    for child in $children; do
        kill_stage_tree "$child" "$signal"
    done
    kill -"$signal" "$pid" 2>/dev/null || true
}

# Run a stage function with live keyboard skip.
# The stage runs in a background process group; we poll /dev/tty in the
# foreground.  If the user presses 's' (or 'S'), we kill the entire stage
# process tree and treat it as skipped.
# Usage: run_stage_with_skip <stage_name> <stage_function_name>
run_stage_with_skip() {
    local stage="$1"
    local stage_func="$2"

    # Skip prompt in non-tty, CI, automation mode
    if [ ! -t 0 ] || [ "${SKIP_STAGE_PROMPT:-false}" = "true" ] || [ "$YOLO_MODE" = "true" ]; then
        "$stage_func"
        return $?
    fi

    local current_cov="$(_stage_coverage "$stage")"
    echo "" >&2
    log_info "Stage: $stage (previous coverage: ${current_cov}%)"
    echo -e "\033[2m  → Press 's' at any time to skip this stage\033[0m" >&2

    # Run the stage in a subshell with job control so it gets its own PGID.
    # We can then kill the whole process group.
    (
        set -m
        "$stage_func" &
        local stage_pid=$!

        # Keyboard poller — runs in the subshell foreground
        local key=""
        while kill -0 "$stage_pid" 2>/dev/null; do
            if IFS= read -rs -t 1 -n 1 key < /dev/tty 2>/dev/null; then
                if [ "$key" = "s" ] || [ "$key" = "S" ]; then
                    echo "" >&2
                    log_warning "Aborting stage: $stage (user pressed 's')"
                    # Kill process group first, then recursively clean up stragglers
                    kill -TERM -- -"$stage_pid" 2>/dev/null || true
                    sleep 0.3
                    kill_stage_tree "$stage_pid" TERM
                    sleep 0.3
                    kill -KILL -- -"$stage_pid" 2>/dev/null || true
                    kill_stage_tree "$stage_pid" KILL
                    exit 77   # Special exit code meaning "user skipped"
                fi
            fi
        done

        wait "$stage_pid"
        exit $?
    ) &
    local wrapper_pid=$!
    wait "$wrapper_pid"
    local wrapper_exit=$?

    if [ "$wrapper_exit" -eq 77 ]; then
        update_stage_status "$stage" "skipped" 0 "user skipped mid-run"
        return 0   # Skipped is not a pipeline failure
    fi

    return "$wrapper_exit"
}

# ─────────────────────────────────────────────────────────────────────────────
# Usage
# ─────────────────────────────────────────────────────────────────────────────

show_usage() {
    cat << EOF
Test Agent - Complete Test Automation Pipeline

DESCRIPTION:
    Orchestrates the complete test automation pipeline including unit test
    generation, accessibility compliance, flow analysis, UI test generation,
    and test execution with comprehensive reporting.

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --project <path>        Xcode project/workspace (auto-detect if not provided)
    --scheme <name>         Target scheme (auto-detect if not provided)
    --stage <name>          Run specific stage only:
                            unit, accessibility, flow, ui, run, maestro, argent
    --resume-from <stage>   Resume pipeline from specific stage
    --ai-provider <name>    AI provider for all agents
    --yolo                  Auto-approve for all agents
    --skip-stage            Auto-skip all stage prompts (same as SKIP_STAGE_PROMPT=true)
    --record                Enable recording in test runner
    --report-dir <path>     Final report directory
    --artifacts-dir <path>  Artifacts output directory
    --skip-unit             Skip unit test generation
    --skip-accessibility    Skip accessibility agent
    --skip-flow             Skip flow analysis
    --skip-ui               Skip UI test generation
    --skip-run              Skip test execution
    --skip-maestro          Skip Maestro UI flow verification
    --skip-argent           Skip Argent runtime verification
    --coverage <n>          Target coverage percentage for unit tests
    --strategy <mode>       Test strategy: priority, coverage, balanced, happy-only
    --files <pattern>       Scope to specific files (glob or comma-separated)
    --happy-only            Only run happy-path tests across all stages
    --verbose               Enable verbose output
    --dry-run               Show what would be done without executing

  SIMULATOR PREPARATION:
    --prepare-simulator     Boot and configure simulator before pipeline
    --simulator-name <name> Simulator to use
    --set-location <lat,lon> Set GPS location
    --appearance <mode>     Set dark/light mode
    --capture-pipeline-logs Unified log session for entire pipeline

    --help                  Show this help message

PIPELINE STAGES:
    1. Unit Test Generation     Generate unit tests for source files
    2. Accessibility Compliance Add accessibility modifiers to views
    3. Flow Analysis            Analyze navigation and generate flows
    4. UI Test Generation       Generate XCUITest from flows
    5. Test Execution           Run tests with optional recording
    5b. Argent Runtime Verification  Boot simulator, install/launch app, run flows via Argent
    6. Report Generation        Create comprehensive HTML report

EXAMPLES:
    # Run complete pipeline
    $0

    # Run with specific AI provider
    $0 --ai-provider claude --yolo

    # Run only flow analysis
    $0 --stage flow

    # Resume from UI test generation
    $0 --resume-from ui

    # Skip certain stages
    $0 --skip-unit --skip-accessibility

    # Full automation with recording
    $0 --yolo --record --ai-provider claude

EXIT CODES:
    0   Pipeline completed successfully
    10  Stage failure (see logs)
    11  Misconfiguration
    20  Human intervention required

OUTPUT:
    Artifacts/<run_id>/
    ├── unit_test/          Unit test generation artifacts
    ├── accessibility/      Accessibility audit artifacts
    ├── flow/               Flow analysis artifacts
    ├── ui_test/            UI test generation artifacts
    ├── TestReports/        Test execution reports
    ├── argent/             Argent runtime verification artifacts
    │   ├── screens/        Per-step screenshots
    │   ├── errors.json     Verification errors (on failure)
    │   └── summary.json    Argent verification summary
    └── pipeline_report.html Final pipeline summary
EOF
}

# ─────────────────────────────────────────────────────────────────────────────
# Letta Memory Functions
# ─────────────────────────────────────────────────────────────────────────────

# Check if Letta memory is available
letta_memory_available() {
    [ -n "$LETTA_MEMORY_AGENT" ] && [ -n "$LETTA_MEMORY_SCRIPT" ] && [ -f "$LETTA_MEMORY_SCRIPT" ]
}

# Retrieve build context from memory
retrieve_build_context() {
    if ! letta_memory_available; then
        return 0
    fi

    log_info "Retrieving build context from Letta memory..."

    local context
    context=$(python3 "$LETTA_MEMORY_SCRIPT" retrieve \
        --agent "$LETTA_MEMORY_AGENT" \
        --block "build_context" 2>/dev/null || echo "")

    if [ -n "$context" ]; then
        LETTA_BUILD_CONTEXT="$context"
        log_info "Retrieved build context from previous build phase"
        log_verbose "Build context: ${context:0:200}..."
    fi
}

# Store test results to memory
store_test_results() {
    local tests_run="${1:-0}"
    local tests_passed="${2:-0}"
    local tests_failed="${3:-0}"
    local coverage="${4:-0}"

    if ! letta_memory_available; then
        return 0
    fi

    log_verbose "Storing test results to Letta memory..."

    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    local data
    data=$(cat << EOF
{
    "tests_run": $tests_run,
    "tests_passed": $tests_passed,
    "tests_failed": $tests_failed,
    "coverage": $coverage,
    "scheme": "${SCHEME:-unknown}",
    "timestamp": "$timestamp",
    "stages": {
        "unit": "$(_stage_result "unit")",
        "accessibility": "$(_stage_result "accessibility")",
        "flow": "$(_stage_result "flow")",
        "discover": "$(_stage_result "discover")",
        "ui": "$(_stage_result "ui")",
        "run": "$(_stage_result "run")",
        "maestro": "$(_stage_result "maestro")",
        "argent": "$(_stage_result "argent")"
    }
}
EOF
)

    python3 "$LETTA_MEMORY_SCRIPT" store \
        --agent "$LETTA_MEMORY_AGENT" \
        --block "test_results" \
        --data "$data" >/dev/null 2>&1 || true

    # Also remember for implicit learning
    python3 "$LETTA_MEMORY_SCRIPT" remember \
        --agent "$LETTA_MEMORY_AGENT" \
        --content "Test run completed: $tests_run tests, $tests_passed passed, $tests_failed failed" >/dev/null 2>&1 || true
}

# ─────────────────────────────────────────────────────────────────────────────
# Initialization
# ─────────────────────────────────────────────────────────────────────────────

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --project)
                PROJECT_PATH="${2:-}"
                # Translate to XCODE_PROJECT/XCODE_WORKSPACE so build_common_args forwards it.
                if [ -n "$PROJECT_PATH" ]; then
                    if echo "$PROJECT_PATH" | grep -q '\.xcworkspace$'; then
                        XCODE_WORKSPACE="$PROJECT_PATH"
                        XCODE_PROJECT=""
                    elif echo "$PROJECT_PATH" | grep -q '\.xcodeproj$'; then
                        XCODE_PROJECT="$PROJECT_PATH"
                        XCODE_WORKSPACE=""
                    else
                        # Fallback: treat as project path and let sub-agents handle it
                        XCODE_PROJECT="$PROJECT_PATH"
                    fi
                fi
                shift 2
                ;;
            --scheme)
                SCHEME="${2:-}"
                shift 2
                ;;
            --stage)
                STAGE="${2:-}"
                shift 2
                ;;
            --resume-from)
                RESUME_FROM="${2:-}"
                shift 2
                ;;
            --ai-provider)
                AI_PROVIDER="${2:-cursor}"
                shift 2
                ;;
            --yolo)
                YOLO_MODE="true"
                shift 1
                ;;
            --skip-stage)
                SKIP_STAGE_PROMPT="true"
                shift 1
                ;;
            --record)
                RECORD="true"
                shift 1
                ;;
            --report-dir)
                REPORT_DIR="${2:-}"
                shift 2
                ;;
            --artifacts-dir)
                ARTIFACTS_DIR="${2:-./Artifacts}"
                shift 2
                ;;
            --skip-unit)
                SKIP_UNIT="true"
                shift 1
                ;;
            --skip-accessibility)
                SKIP_ACCESSIBILITY="true"
                shift 1
                ;;
            --skip-flow)
                SKIP_FLOW="true"
                shift 1
                ;;
            --skip-ui)
                SKIP_UI="true"
                shift 1
                ;;
            --skip-run)
                SKIP_RUN="true"
                shift 1
                ;;
            --skip-argent)
                SKIP_ARGENT="true"
                shift 1
                ;;
            --skip-maestro)
                SKIP_MAESTRO="true"
                shift 1
                ;;
            --discover)
                DISCOVER_FLOWS="true"
                shift 1
                ;;
            --learn)
                LEARN_FLOWS="true"
                shift 1
                ;;
            --verbose|-v)
                VERBOSE="true"
                shift 1
                ;;
            --dry-run)
                DRY_RUN="true"
                shift 1
                ;;
            --prepare-simulator)
                PREPARE_SIMULATOR="true"
                shift 1
                ;;
            --simulator-name)
                SIMULATOR_NAME="${2:-}"
                shift 2
                ;;
            --set-location)
                GPS_LOCATION="${2:-}"
                GPS_LAT=$(echo "$GPS_LOCATION" | cut -d',' -f1)
                GPS_LON=$(echo "$GPS_LOCATION" | cut -d',' -f2)
                shift 2
                ;;
            --appearance)
                APPEARANCE_MODE="${2:-}"
                shift 2
                ;;
            --capture-pipeline-logs)
                CAPTURE_PIPELINE_LOGS="true"
                shift 1
                ;;
            --stress-test)
                STRESS_TEST="true"
                STRESS_LEVEL="${2:-1}"
                shift 2
                ;;
            --happy-only)
                HAPPY_ONLY="true"
                shift 1
                ;;
            --coverage)
                SCOPE_COVERAGE="${2:-}"
                shift 2
                ;;
            --strategy)
                SCOPE_STRATEGY="${2:-}"
                shift 2
                ;;
            --files)
                SCOPE_FILES="${2:-}"
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
}

# Load build scope from the most recent BuildAgent artifact.
# If --files was not explicitly set, use .build_scope.json as default.
load_build_scope() {
    if [ -n "$SCOPE_FILES" ]; then
        return
    fi
    local latest_build=""
    for dir in "$ARTIFACTS_DIR"/build_*; do
        [ -d "$dir" ] || continue
        if [ -z "$latest_build" ] || [ "$dir" -nt "$latest_build" ]; then
            latest_build="$dir"
        fi
    done
    if [ -z "$latest_build" ]; then
        return
    fi
    local scope_file="$latest_build/.build_scope.json"
    if [ -f "$scope_file" ] && command -v jq >/dev/null 2>&1; then
        local files
        files=$(jq -r '.modified_files | join(",")' "$scope_file" 2>/dev/null || echo "")
        if [ -n "$files" ]; then
            # Filter out garbage files (logs, artifacts, system files).
            local filtered=""
            local IFS=','
            for f in $files; do
                case "$f" in
                    Artifacts/*|.git/*|node_modules/*|Pods/*|.build/*|DerivedData/*)
                        continue ;;
                    *.DS_Store*|*.log|*.tmp|*.bak)
                        continue ;;
                esac
                if [ -n "$filtered" ]; then
                    filtered="$filtered,$f"
                else
                    filtered="$f"
                fi
            done
            if [ -n "$filtered" ]; then
                SCOPE_FILES="$filtered"
                log_info "Loaded build scope from $scope_file: $filtered"
            fi
        fi
    fi
}

initialize() {
    log_section "════════════════════════════════════════════════════════"
    log_section "Test Agent - Complete Test Automation Pipeline"
    log_section "════════════════════════════════════════════════════════"
    echo "" >&2

    PIPELINE_START_TIME=$(date +%s)

    # Auto-load file scope from last BuildAgent run.
    load_build_scope

    # Setup directories
    setup_logs_dir "$ARTIFACTS_DIR" || {
        log_error "Failed to setup directories"
        exit 11
    }

    # Set report directory
    if [ -z "$REPORT_DIR" ]; then
        REPORT_DIR="${ARTIFACTS_RUN_DIR}/TestReports"
    fi
    mkdir -p "$REPORT_DIR"

    # Stage tracking file
    STAGES_FILE="${ARTIFACTS_RUN_DIR}/stages.json"
    echo '{"stages": {}}' > "$STAGES_FILE"

    # Pipeline state file (persists across runs)
    PIPELINE_STATE_FILE="${ARTIFACTS_DIR}/.pipeline_state.json"

    # Verify agent scripts exist
    for script in "$UNIT_TEST_AGENT" "$ACCESSIBILITY_AGENT" "$FLOW_AGENT" "$UI_TEST_AGENT" "$TEST_RUNNER"; do
        if [ ! -x "$script" ]; then
            log_error "Agent script not found or not executable: $script"
            exit 11
        fi
    done

    # Auto-detect Xcode project
    if [ -z "$PROJECT_PATH" ]; then
        detect_xcode_project || {
            log_warning "Could not auto-detect Xcode project"
        }
    fi

    # Auto-detect scheme
    if [ -z "$SCHEME" ]; then
        detect_scheme || {
            log_warning "Could not auto-detect scheme"
        }
    fi

    log_info "Configuration:"
    log_info "  Project: ${XCODE_WORKSPACE:-${XCODE_PROJECT:-auto-detect}}"
    log_info "  Scheme: ${SCHEME:-auto-detect}"
    log_info "  AI Provider: $AI_PROVIDER"
    log_info "  YOLO Mode: $YOLO_MODE"
    log_info "  Recording: $RECORD"
    log_info "  Artifacts: $ARTIFACTS_RUN_DIR"
    echo "" >&2
}

# ─────────────────────────────────────────────────────────────────────────────
# Stage Management
# ─────────────────────────────────────────────────────────────────────────────

# Update stage status
update_stage_status() {
    local stage="$1"
    local status="$2"
    local duration="${3:-0}"
    local details="${4:-}"
    local coverage="${5:-0}"

    _set_stage_result "$stage" "$status"
    _set_stage_duration "$stage" "$duration"
    if [ "$coverage" -gt 0 ]; then
        _set_stage_coverage "$stage" "$coverage"
    fi

    if command -v jq >/dev/null 2>&1; then
        local tmp_file
        tmp_file=$(mktemp)
        jq ".stages.\"$stage\" = {\"status\": \"$status\", \"duration\": $duration, \"details\": \"$details\", \"coverage\": $coverage}" "$STAGES_FILE" > "$tmp_file"
        mv "$tmp_file" "$STAGES_FILE"
    fi

    case "$status" in
        completed)
            if [ "$coverage" -gt 0 ]; then
                log_success "Stage $stage completed (${duration}s, coverage: ${coverage}%)"
            else
                log_success "Stage $stage completed (${duration}s)"
            fi
            ;;
        failed)
            log_error "Stage $stage failed (${duration}s)"
            ;;
        skipped)
            log_warning "Stage $stage skipped"
            ;;
    esac
}

# ─────────────────────────────────────────────────────────────────────────────
# Rare Event Simulation / Stress Testing
# ─────────────────────────────────────────────────────────────────────────────

# Apply stress perturbations to the pipeline
apply_stress_test() {
    local stage="$1"
    if [ "$STRESS_TEST" != "true" ]; then
        return 0
    fi

    log_warning "STRESS TEST mode (level: $STRESS_LEVEL) — applying perturbations to $stage"

    # Perturbation 1: Random provider switch
    if [ "$STRESS_LEVEL" -ge 1 ] && [ "$((RANDOM % 3))" -eq 0 ]; then
        local providers=()
        while IFS= read -r p; do [ -n "$p" ] && providers+=("$p"); done <<< "$(discover_available_providers)"
        if [ ${#providers[@]} -gt 1 ]; then
            local random_provider="${providers[$((RANDOM % ${#providers[@]}))]}"
            log_info "[STRESS] Random provider switch: $AI_PROVIDER → $random_provider"
            AI_PROVIDER="$random_provider"
        fi
    fi

    # Perturbation 2: Artificial delay
    if [ "$STRESS_LEVEL" -ge 2 ] && [ "$((RANDOM % 2))" -eq 0 ]; then
        local delay=$((RANDOM % 5 + 1))
        log_info "[STRESS] Artificial delay: ${delay}s"
        sleep "$delay"
    fi

    # Perturbation 3: Simulate provider failure (skip stage)
    if [ "$STRESS_LEVEL" -ge 3 ] && [ "$((RANDOM % 5))" -eq 0 ]; then
        log_error "[STRESS] Simulated provider failure for stage: $stage"
        return 1
    fi

    # Perturbation 4: Reduce context size
    if [ "$STRESS_LEVEL" -ge 2 ] && [ "$((RANDOM % 3))" -eq 0 ]; then
        local reduced_context=$((MAX_CONTEXT_CHARS / 2))
        log_info "[STRESS] Reduced context cap: $MAX_CONTEXT_CHARS → $reduced_context"
        MAX_CONTEXT_CHARS="$reduced_context"
    fi

    return 0
}

# Check if stage should run
should_run_stage() {
    local stage="$1"

    # If specific stage requested, only run that one
    if [ -n "$STAGE" ]; then
        [ "$STAGE" = "$stage" ] && return 0 || return 1
    fi

    # Check resume-from
    if [ -n "$RESUME_FROM" ]; then
        local stages=("unit" "accessibility" "flow" "discover" "ui" "run" "maestro" "argent" "report")
        local found_resume=false
        for s in "${stages[@]}"; do
            if [ "$s" = "$RESUME_FROM" ]; then
                found_resume=true
            fi
            if [ "$found_resume" = true ] && [ "$s" = "$stage" ]; then
                return 0
            fi
        done
        return 1
    fi

    # Check skip flags
    case "$stage" in
        unit) [ "$SKIP_UNIT" = "true" ] && return 1 ;;
        accessibility) [ "$SKIP_ACCESSIBILITY" = "true" ] && return 1 ;;
        flow) [ "$SKIP_FLOW" = "true" ] && return 1 ;;
        discover)
            # Auto-run discover on first build if .maestro/ is empty
            if [ "$DISCOVER_FLOWS" = "true" ]; then
                return 0
            fi
            local _maestro_dir=""
            if [ -n "$PROJECT_PATH" ] && [ "$PROJECT_PATH" != "." ] && [ -d "$PROJECT_PATH" ]; then
                _maestro_dir="${PROJECT_PATH}/.maestro"
            else
                _maestro_dir="${ARTIFACTS_RUN_DIR:-./Artifacts}/.maestro"
            fi
            if [ ! -d "$_maestro_dir" ] || [ -z "$(ls -A "$_maestro_dir" 2>/dev/null)" ]; then
                log_info "Auto-discovering Maestro flows (first build detected)"
                return 0
            fi
            return 1
            ;;
        ui) [ "$SKIP_UI" = "true" ] && return 1 ;;
        run) [ "$SKIP_RUN" = "true" ] && return 1 ;;
        maestro)
            [ "$SKIP_MAESTRO" = "true" ] && return 1
            if [ -z "$SIMULATOR_NAME" ]; then
                log_warning "No simulator specified (--simulator-name) — skipping Maestro UI flows"
                return 1
            fi
            ;;
        argent)
            [ "$SKIP_ARGENT" = "true" ] && return 1
            if [ -z "$SIMULATOR_NAME" ]; then
                log_warning "No simulator specified (--simulator-name) — skipping Argent runtime verification"
                return 1
            fi
            ;;
    esac

    return 0
}

# Prepare simulator for test pipeline
prepare_simulator_for_pipeline() {
    if [ "$PREPARE_SIMULATOR" != "true" ]; then
        return 0
    fi

    if [ -z "$SIMULATOR_NAME" ]; then
        log_warning "No simulator specified, skipping preparation"
        return 0
    fi

    log_section "Preparing simulator: $SIMULATOR_NAME"

    # Source simulator library
    source "${LIB_DIR}/simulator.sh"

    # Get simulator UUID
    local simulator_udid
    simulator_udid=$(get_simulator_by_name "$SIMULATOR_NAME") || {
        log_error "Failed to resolve simulator: $SIMULATOR_NAME"
        return 1
    }

    # Boot if not running
    if [ "$(is_simulator_booted "$simulator_udid")" != "true" ]; then
        log_info "Booting simulator..."
        boot_simulator "$SIMULATOR_NAME" true > /dev/null || {
            log_error "Failed to boot simulator"
            return 1
        }
    else
        log_info "Simulator already booted"
    fi

    # Configure GPS location
    if [ -n "$GPS_LAT" ] && [ -n "$GPS_LON" ]; then
        log_info "Setting GPS location: $GPS_LAT, $GPS_LON"
        set_simulator_location "$simulator_udid" "$GPS_LAT" "$GPS_LON" > /dev/null || {
            log_warning "Failed to set GPS location"
        }
    fi

    # Configure appearance
    if [ -n "$APPEARANCE_MODE" ]; then
        log_info "Setting appearance: $APPEARANCE_MODE"
        set_simulator_appearance "$simulator_udid" "$APPEARANCE_MODE" > /dev/null || {
            log_warning "Failed to set appearance"
        }
    fi

    log_success "Simulator prepared successfully"
    return 0
}

# Start pipeline-wide log capture
start_pipeline_log_capture() {
    if [ "$CAPTURE_PIPELINE_LOGS" != "true" ]; then
        return 0
    fi

    source "${LIB_DIR}/log_capture.sh"

    log_info "Starting pipeline log capture..."
    PIPELINE_LOG_SESSION=$(start_log_capture "Pipeline" "test" "${SCHEME:-TestPipeline}") || {
        log_warning "Failed to start pipeline log capture"
        return 1
    }

    # Register cleanup trap
    trap 'stop_log_capture "$PIPELINE_LOG_SESSION" 2>/dev/null || true' EXIT

    log_info "Pipeline logs: $(get_log_path "$PIPELINE_LOG_SESSION")"
    return 0
}

# Build common arguments for agents
# Common args supported by all agents
build_common_args() {
    local args=""
    if [ -n "${XCODE_WORKSPACE:-}" ]; then
        args="$args --project \"$XCODE_WORKSPACE\""
    elif [ -n "${XCODE_PROJECT:-}" ]; then
        args="$args --project \"$XCODE_PROJECT\""
    fi
    args="$args --artifacts-dir \"${ARTIFACTS_RUN_DIR}\""
    [ "$VERBOSE" = "true" ] && args="$args --verbose"
    [ "$DRY_RUN" = "true" ] && args="$args --dry-run"
    echo "$args"
}

# Args for unit test agent (supports coverage, strategy, files, happy-only)
build_unit_test_args() {
    local args=$(build_common_args)
    [ -n "$SCHEME" ] && args="$args --scheme \"$SCHEME\""
    args="$args --ai-provider \"$AI_PROVIDER\""
    [ "$YOLO_MODE" = "true" ] && args="$args --yolo"
    [ "$HAPPY_ONLY" = "true" ] && args="$args --happy-only"
    [ -n "$SCOPE_COVERAGE" ] && args="$args --target-coverage \"$SCOPE_COVERAGE\""
    [ -n "$SCOPE_STRATEGY" ] && args="$args --test-strategy \"$SCOPE_STRATEGY\""
    [ -n "$SCOPE_FILES" ] && args="$args --files \"$SCOPE_FILES\""
    [ -n "$SIMULATOR_NAME" ] && args="$args --simulator-name \"$SIMULATOR_NAME\""
    echo "$args"
}

# Args for accessibility agent (supports files)
build_accessibility_args() {
    local args=$(build_common_args)
    [ -n "$SCHEME" ] && args="$args --scheme \"$SCHEME\""
    args="$args --ai-provider \"$AI_PROVIDER\""
    [ "$YOLO_MODE" = "true" ] && args="$args --yolo"
    [ -n "$SCOPE_FILES" ] && args="$args --files \"$SCOPE_FILES\""
    [ -n "$SIMULATOR_NAME" ] && args="$args --simulator-name \"$SIMULATOR_NAME\""
    echo "$args"
}

# Args for flow agent (no --scheme, no --happy-only, no --project)
build_flow_args() {
    local args=""
    args="$args --ai-provider \"$AI_PROVIDER\""
    args="$args --artifacts-dir \"${ARTIFACTS_RUN_DIR}\""
    [ "$VERBOSE" = "true" ] && args="$args --verbose"
    [ "$DRY_RUN" = "true" ] && args="$args --dry-run"
    echo "$args"
}

# Args for UI test agent (uses flows, supports yolo)
build_ui_test_args() {
    # uiTestAgent.sh does NOT support --project or --scheme.
    local args=""
    args="$args --ai-provider \"$AI_PROVIDER\""
    args="$args --artifacts-dir \"${ARTIFACTS_RUN_DIR}\""
    [ "$YOLO_MODE" = "true" ] && args="$args --yolo"
    [ "$HAPPY_ONLY" = "true" ] && args="$args --type happy"
    [ -n "$SIMULATOR_NAME" ] && args="$args --simulator-name \"$SIMULATOR_NAME\""
    [ "$VERBOSE" = "true" ] && args="$args --verbose"
    [ "$DRY_RUN" = "true" ] && args="$args --dry-run"
    echo "$args"
}

# Args for test runner (no ai-provider, no happy-only, no files, no yolo)
build_test_runner_args() {
    local args=$(build_common_args)
    [ -n "$SCHEME" ] && args="$args --scheme \"$SCHEME\""
    [ -n "$SIMULATOR_NAME" ] && args="$args --simulator-name \"$SIMULATOR_NAME\""
    echo "$args"
}

# ─────────────────────────────────────────────────────────────────────────────
# Pipeline Stages
# ─────────────────────────────────────────────────────────────────────────────

# Stage 1: Unit Test Generation
run_stage_unit() {
    if ! should_run_stage "unit"; then
        update_stage_status "unit" "skipped"
        return 0
    fi

    if prompt_skip_stage "unit"; then
        update_stage_status "unit" "skipped" 0 "user skipped"
        return 0
    fi

    CURRENT_STAGE="unit"
    log_section "────────────────────────────────────────"
    log_section "Stage 1/6: Unit Test Generation"
    log_section "────────────────────────────────────────"
    echo "" >&2

    if ! apply_stress_test "unit"; then
        update_stage_status "unit" "failed" 0 "stress test simulation"
        return 10
    fi

    local start_time
    start_time=$(date +%s)
    local args
    args=$(build_unit_test_args)

    if [ "$DRY_RUN" = "true" ]; then
        log_info "[DRY RUN] Would run: $UNIT_TEST_AGENT $args"
        update_stage_status "unit" "completed" 0 "dry-run"
        return 0
    fi

    local exit_code=0
    if eval "$UNIT_TEST_AGENT $args" 2>&1 | tee "${LOGS_DIR}/unit_test.log"; then
        exit_code=0
    else
        exit_code=$?
    fi

    local duration=$(($(date +%s) - start_time))

    if [ $exit_code -eq 0 ]; then
        # Extract coverage from unit test results if available
        local coverage=0
        local results_json="${ARTIFACTS_RUN_DIR}/unit_test_results.json"
        if [ -f "$results_json" ] && command -v jq >/dev/null 2>&1; then
            coverage=$(jq '.coverageAchieved // 0' "$results_json" 2>/dev/null || echo "0")
        fi
        update_stage_status "unit" "completed" $duration "" "$coverage"
        return 0
    else
        update_stage_status "unit" "failed" $duration "exit code: $exit_code"
        return 10
    fi
}

# Stage 2: Accessibility Compliance
run_stage_accessibility() {
    if ! should_run_stage "accessibility"; then
        update_stage_status "accessibility" "skipped"
        return 0
    fi

    if prompt_skip_stage "accessibility"; then
        update_stage_status "accessibility" "skipped" 0 "user skipped"
        return 0
    fi

    CURRENT_STAGE="accessibility"
    log_section "────────────────────────────────────────"
    log_section "Stage 2/6: Accessibility Compliance"
    log_section "────────────────────────────────────────"
    echo "" >&2

    if ! apply_stress_test "accessibility"; then
        update_stage_status "accessibility" "failed" 0 "stress test simulation"
        return 10
    fi

    local start_time
    start_time=$(date +%s)
    local args
    args=$(build_accessibility_args)

    if [ "$DRY_RUN" = "true" ]; then
        log_info "[DRY RUN] Would run: $ACCESSIBILITY_AGENT $args"
        update_stage_status "accessibility" "completed" 0 "dry-run"
        return 0
    fi

    local exit_code=0
    if eval "$ACCESSIBILITY_AGENT $args" 2>&1 | tee "${LOGS_DIR}/accessibility.log"; then
        exit_code=0
    else
        exit_code=$?
    fi

    local duration=$(($(date +%s) - start_time))

    if [ $exit_code -eq 0 ]; then
        update_stage_status "accessibility" "completed" $duration
        return 0
    else
        update_stage_status "accessibility" "failed" $duration "exit code: $exit_code"
        return 10
    fi
}

# Stage 3: Flow Analysis
run_stage_flow() {
    if ! should_run_stage "flow"; then
        update_stage_status "flow" "skipped"
        return 0
    fi

    if prompt_skip_stage "flow"; then
        update_stage_status "flow" "skipped" 0 "user skipped"
        return 0
    fi

    CURRENT_STAGE="flow"
    log_section "────────────────────────────────────────"
    log_section "Stage 3/6: Flow Analysis"
    log_section "────────────────────────────────────────"
    echo "" >&2

    if ! apply_stress_test "flow"; then
        update_stage_status "flow" "failed" 0 "stress test simulation"
        return 10
    fi

    local start_time
    start_time=$(date +%s)
    local args
    args=$(build_flow_args)
    args="$args --output \"${ARTIFACTS_RUN_DIR}/flows.json\""

    if [ "$DRY_RUN" = "true" ]; then
        log_info "[DRY RUN] Would run: $FLOW_AGENT $args"
        update_stage_status "flow" "completed" 0 "dry-run"
        return 0
    fi

    local exit_code=0
    if eval "$FLOW_AGENT $args" 2>&1 | tee "${LOGS_DIR}/flow.log"; then
        exit_code=0
    else
        exit_code=$?
    fi

    local duration=$(($(date +%s) - start_time))

    if [ $exit_code -eq 0 ]; then
        update_stage_status "flow" "completed" $duration
        return 0
    else
        update_stage_status "flow" "failed" $duration "exit code: $exit_code"
        return 10
    fi
}

# Stage 3b: Discover Maestro Flows from Code
run_stage_discover() {
    if ! should_run_stage "discover"; then
        update_stage_status "discover" "skipped"
        return 0
    fi

    if prompt_skip_stage "discover"; then
        update_stage_status "discover" "skipped" 0 "user skipped"
        return 0
    fi

    CURRENT_STAGE="discover"
    log_section "────────────────────────────────────────"
    log_section "Stage 3b/8: Discover Maestro Flows"
    log_section "────────────────────────────────────────"
    echo "" >&2

    if ! apply_stress_test "discover"; then
        update_stage_status "discover" "failed" 0 "stress test simulation"
        return 10
    fi

    local start_time
    start_time=$(date +%s)

    local maestro_dir=""
    if [ -n "$PROJECT_PATH" ] && [ "$PROJECT_PATH" != "." ] && [ -d "$PROJECT_PATH" ]; then
        maestro_dir="${PROJECT_PATH}/.maestro"
    else
        maestro_dir="${ARTIFACTS_RUN_DIR}/.maestro"
    fi
    local analyzer="${SCRIPT_DIR}/lib/testgen/swift_ui_analyzer.py"
    local change_analyzer="${SCRIPT_DIR}/lib/testgen/code_change_analyzer.py"
    local generator="${SCRIPT_DIR}/lib/testgen/maestro_flow_generator.py"
    local learner="${SCRIPT_DIR}/lib/testgen/flow_learner.py"
    local structure_json="${ARTIFACTS_RUN_DIR}/app_structure.json"
    local changes_json="${ARTIFACTS_RUN_DIR}/changes_analysis.json"

    # Auto-discover on first build if .maestro/ doesn't exist
    if [ "$DISCOVER_FLOWS" != "true" ] && [ -d "$maestro_dir" ] && [ -n "$(ls -A "$maestro_dir" 2>/dev/null)" ]; then
        log_info "Maestro flows already exist — skipping discovery (use --discover to force)"
        update_stage_status "discover" "skipped" 0 "flows already exist"
        return 0
    fi

    if [ ! -f "$analyzer" ]; then
        log_warning "Swift analyzer not found — skipping flow discovery"
        update_stage_status "discover" "skipped" 0 "analyzer not found"
        return 0
    fi

    if [ "$DRY_RUN" = "true" ]; then
        log_info "[DRY RUN] Would discover flows from Swift code"
        update_stage_status "discover" "completed" 0 "dry-run"
        return 0
    fi

    mkdir -p "$maestro_dir"

    # Step 1: Analyze Swift code
    log_info "Analyzing SwiftUI code structure..."
    local analyze_exit=0
    python3 "$analyzer" \
        --project-dir "$PROJECT_PATH" \
        --output "$structure_json" 2>&1 | tee "${LOGS_DIR}/discover_analyze.log" || analyze_exit=$?

    if [ $analyze_exit -ne 0 ]; then
        log_warning "Swift analysis failed — Maestro flows not generated"
        update_stage_status "discover" "failed" $(($(date +%s) - start_time)) "analyzer failed"
        return 0  # Don't fail pipeline for discovery issues
    fi

    # Step 1b: Analyze git changes for targeted regression
    if [ -f "$change_analyzer" ] && [ -d "${PROJECT_PATH}/.git" ]; then
        log_info "Analyzing git changes for targeted regression..."
        local change_exit=0
        python3 "$change_analyzer" \
            --project-root "$PROJECT_PATH" \
            --output "$changes_json" 2>&1 | tee "${LOGS_DIR}/discover_changes.log" || change_exit=$?
        if [ $change_exit -eq 0 ] && [ -f "$changes_json" ]; then
            log_info "Change analysis complete — will generate targeted regression flows"
        else
            log_warning "Change analysis failed — falling back to generic regression"
            changes_json=""
        fi
    fi

    # Step 2: Generate Maestro flows
    log_info "Generating Maestro test flows..."
    local gen_exit=0
    local gen_args=(
        --app-structure "$structure_json"
        --output-dir "$maestro_dir"
        --bundle-id "${BUNDLE_ID:-tech.eocon.AmmoScan}"
        --categories "smoke,regression"
    )
    [ -n "$changes_json" ] && [ -f "$changes_json" ] && gen_args+=(--changes-file "$changes_json")
    python3 "$generator" "${gen_args[@]}" 2>&1 | tee "${LOGS_DIR}/discover_generate.log" || gen_exit=$?

    local duration=$(($(date +%s) - start_time))

    if [ $gen_exit -ne 0 ]; then
        log_warning "Flow generation had issues — continuing"
        update_stage_status "discover" "failed" $duration "generator failed"
        return 0  # Don't fail pipeline
    fi

    # Step 3: Learn reliable assertions (if --learn or first build)
    if [ "$LEARN_FLOWS" = "true" ] || [ ! -f "${maestro_dir}/learned_assertions.json" ]; then
        # Ensure maestro is in PATH
        if [ -d "$HOME/.maestro/bin" ]; then
            export PATH="$PATH:$HOME/.maestro/bin"
        fi
        if [ -f "$learner" ] && (command -v maestro >/dev/null 2>&1 || [ -x "$HOME/.maestro/bin/maestro" ]); then
            log_info "Learning reliable assertions from smoke test run..."
            local learn_exit=0
            python3 "$learner" \
                --run-and-learn \
                --project-dir "$PROJECT_PATH" \
                --bundle-id "${BUNDLE_ID:-tech.eocon.AmmoScan}" 2>&1 | tee "${LOGS_DIR}/discover_learn.log" || learn_exit=$?
            if [ $learn_exit -eq 0 ]; then
                log_success "Flow learning complete — smoke tests regenerated with proven assertions"
                # Re-generate regression flows with learned knowledge
                if [ -f "$generator" ] && [ -f "$structure_json" ]; then
                    log_info "Re-generating regression flows with learned assertions..."
                    local regen_args=(
                        --app-structure "$structure_json"
                        --output-dir "$maestro_dir"
                        --bundle-id "${BUNDLE_ID:-tech.eocon.AmmoScan}"
                        --categories "regression"
                    )
                    [ -n "$changes_json" ] && [ -f "$changes_json" ] && regen_args+=(--changes-file "$changes_json")
                    python3 "$generator" "${regen_args[@]}" 2>&1 | tee "${LOGS_DIR}/discover_regression_regen.log" || true
                fi
            else
                log_warning "Flow learning had issues — using statically generated flows"
            fi
        else
            log_info "Maestro CLI not available — skipping flow learning"
        fi
    fi

    log_success "Maestro flows discovered and generated"
    update_stage_status "discover" "completed" $duration
    return 0
}

# Stage 4: UI Test Generation
run_stage_ui() {
    if ! should_run_stage "ui"; then
        update_stage_status "ui" "skipped"
        return 0
    fi

    if prompt_skip_stage "ui"; then
        update_stage_status "ui" "skipped" 0 "user skipped"
        return 0
    fi

    CURRENT_STAGE="ui"
    log_section "────────────────────────────────────────"
    log_section "Stage 4/6: UI Test Generation"
    log_section "────────────────────────────────────────"
    echo "" >&2

    if ! apply_stress_test "ui"; then
        update_stage_status "ui" "failed" 0 "stress test simulation"
        return 10
    fi

    # Check if flows file exists
    local flows_file="${ARTIFACTS_RUN_DIR}/flows.json"
    if [ ! -f "$flows_file" ]; then
        log_warning "No flows.json found - skipping UI test generation"
        update_stage_status "ui" "skipped" 0 "no flows file"
        return 0
    fi

    local start_time
    start_time=$(date +%s)
    local args
    args=$(build_ui_test_args)
    args="$args --flows \"$flows_file\""


    if [ "$DRY_RUN" = "true" ]; then
        log_info "[DRY RUN] Would run: $UI_TEST_AGENT $args"
        update_stage_status "ui" "completed" 0 "dry-run"
        return 0
    fi

    local exit_code=0
    if eval "$UI_TEST_AGENT $args" 2>&1 | tee "${LOGS_DIR}/ui_test.log"; then
        exit_code=0
    else
        exit_code=$?
    fi

    local duration=$(($(date +%s) - start_time))

    if [ $exit_code -eq 0 ]; then
        update_stage_status "ui" "completed" $duration
        return 0
    else
        update_stage_status "ui" "failed" $duration "exit code: $exit_code"
        return 10
    fi
}

# Stage 5: Test Execution
run_stage_run() {
    if ! should_run_stage "run"; then
        update_stage_status "run" "skipped"
        return 0
    fi

    if prompt_skip_stage "run"; then
        update_stage_status "run" "skipped" 0 "user skipped"
        return 0
    fi

    CURRENT_STAGE="run"
    log_section "────────────────────────────────────────"
    log_section "Stage 5/6: Test Execution"
    log_section "────────────────────────────────────────"
    echo "" >&2

    if ! apply_stress_test "run"; then
        update_stage_status "run" "failed" 0 "stress test simulation"
        return 10
    fi

    local start_time
    start_time=$(date +%s)
    local args
    args=$(build_test_runner_args)
    args="$args --report-dir \"$REPORT_DIR\""

    [ "$RECORD" = "true" ] && args="$args --record"

    if [ "$DRY_RUN" = "true" ]; then
        log_info "[DRY RUN] Would run: $TEST_RUNNER $args"
        update_stage_status "run" "completed" 0 "dry-run"
        return 0
    fi

    local exit_code=0
    if eval "$TEST_RUNNER $args" 2>&1 | tee "${LOGS_DIR}/test_run.log"; then
        exit_code=0
    else
        exit_code=$?
    fi

    local duration=$(($(date +%s) - start_time))

    if [ $exit_code -eq 0 ]; then
        update_stage_status "run" "completed" $duration
        return 0
    else
        update_stage_status "run" "failed" $duration "exit code: $exit_code"
        # Don't fail pipeline for test failures - continue to report
        return 0
    fi
}

# Stage 5a: Maestro UI Flow Verification
run_stage_maestro() {
    if ! should_run_stage "maestro"; then
        update_stage_status "maestro" "skipped"
        return 0
    fi

    if prompt_skip_stage "maestro"; then
        update_stage_status "maestro" "skipped" 0 "user skipped"
        return 0
    fi

    CURRENT_STAGE="maestro"
    log_section "────────────────────────────────────────"
    log_section "Stage 5a/7: Maestro UI Flow Verification"
    log_section "────────────────────────────────────────"
    echo "" >&2

    if ! apply_stress_test "maestro"; then
        update_stage_status "maestro" "failed" 0 "stress test simulation"
        return 10
    fi

    local start_time
    start_time=$(date +%s)

    # Check Maestro is installed
    if ! command -v maestro >/dev/null 2>&1; then
        if [ -d "$HOME/.maestro/bin" ]; then
            export PATH="$PATH:$HOME/.maestro/bin"
        else
            log_warning "Maestro not installed — skipping Maestro UI flows"
            update_stage_status "maestro" "skipped" 0 "maestro not installed"
            return 0
        fi
    fi

    # Find Maestro workspace
    local maestro_dir="${PROJECT_PATH}/.maestro"
    if [ ! -d "$maestro_dir" ]; then
        log_warning "No .maestro/ directory found in project — skipping Maestro UI flows"
        update_stage_status "maestro" "skipped" 0 "no .maestro directory"
        return 0
    fi

    local maestro_artifacts="${ARTIFACTS_RUN_DIR}/maestro"
    mkdir -p "$maestro_artifacts"

    # Clean previous screenshots to avoid stale artifacts
    rm -rf "${maestro_artifacts}/screenshots"

    if [ "$DRY_RUN" = "true" ]; then
        log_info "[DRY RUN] Would run: maestro test ${maestro_dir}/"
        update_stage_status "maestro" "completed" 0 "dry-run"
        return 0
    fi

    # Suppress Maestro analytics notifications
    export MAESTRO_CLI_ANALYSIS_NOTIFICATION_DISABLED=true

    local maestro_exit=0
    set +e
    maestro test "$maestro_dir/" \
        --debug-output "$maestro_artifacts" \
        --test-output-dir "$maestro_artifacts" \
        --flatten-debug-output \
        2>&1 | tee "${LOGS_DIR}/maestro.log"
    maestro_exit=${PIPESTATUS[0]}
    set -e

    local duration=$(($(date +%s) - start_time))

    # Parse flow results from commands JSON files
    local total_flows=0
    local passed_flows=0
    local failed_flows=0
    local flow_summaries="[]"

    for cmd_json in "${maestro_artifacts}"/commands-*.json; do
        [ -f "$cmd_json" ] || continue
        total_flows=$((total_flows + 1))
        local flow_name
        flow_name=$(basename "$cmd_json" .json | sed 's/commands-(//' | sed 's/)//')

        # Check if any step failed
        local failed_steps
        failed_steps=$(jq '[.[] | select(.metadata.status != "COMPLETED")] | length' "$cmd_json" 2>/dev/null || echo "0")
        local total_steps
        total_steps=$(jq 'length' "$cmd_json" 2>/dev/null || echo "0")

        local flow_status="passed"
        local flow_duration=0
        if [ "$failed_steps" -gt 0 ]; then
            flow_status="failed"
            failed_flows=$((failed_flows + 1))
        else
            passed_flows=$((passed_flows + 1))
        fi

        # Calculate total duration from all steps
        flow_duration=$(jq '[.[] | .metadata.duration // 0] | add' "$cmd_json" 2>/dev/null || echo "0")

        # Build flow summary entry
        local flow_entry
        flow_entry=$(jq -n \
            --arg name "$flow_name" \
            --arg status "$flow_status" \
            --argjson duration "$flow_duration" \
            --argjson total_steps "$total_steps" \
            --argjson failed_steps "$failed_steps" \
            '{name: $name, status: $status, duration_ms: $duration, total_steps: $total_steps, failed_steps: $failed_steps}')
        flow_summaries=$(echo "$flow_summaries" | jq --argjson entry "$flow_entry" '. + [$entry]' 2>/dev/null || echo "$flow_summaries")
    done

    # Collect screenshots
    local screenshots="[]"
    for screenshot in "${maestro_artifacts}"/screenshots/*.png; do
        [ -f "$screenshot" ] || continue
        screenshots=$(echo "$screenshots" | jq --arg path "$screenshot" '. + [$path]' 2>/dev/null || echo "$screenshots")
    done

    # Write Maestro summary JSON for report consumption
    local summary_json="${maestro_artifacts}/summary.json"
    jq -n \
        --arg status "$([ $maestro_exit -eq 0 ] && echo "passed" || echo "failed")" \
        --argjson total_flows "$total_flows" \
        --argjson passed_flows "$passed_flows" \
        --argjson failed_flows "$failed_flows" \
        --argjson flows "$flow_summaries" \
        --argjson screenshots "$screenshots" \
        '{status: $status, total_flows: $total_flows, passed_flows: $passed_flows, failed_flows: $failed_flows, flows: $flows, screenshots: $screenshots}' > "$summary_json" 2>/dev/null || true

    if [ $maestro_exit -eq 0 ]; then
        log_success "Maestro UI flows passed ($passed_flows/$total_flows)"
        update_stage_status "maestro" "completed" $duration
        return 0
    else
        log_error "Maestro UI flows failed ($failed_flows/$total_flows)"
        update_stage_status "maestro" "failed" $duration "exit code: $maestro_exit"
        return 10
    fi
}

# Stage 5b: Argent Runtime Verification (Deep Diagnostics Fallback)
run_stage_argent() {
    if ! should_run_stage "argent"; then
        update_stage_status "argent" "skipped"
        return 0
    fi

    if prompt_skip_stage "argent"; then
        update_stage_status "argent" "skipped" 0 "user skipped"
        return 0
    fi

    CURRENT_STAGE="argent"
    log_section "────────────────────────────────────────"
    log_section "Stage 5b/7: Argent Runtime Verification"
    log_section "────────────────────────────────────────"
    echo "" >&2

    if ! apply_stress_test "argent"; then
        update_stage_status "argent" "failed" 0 "stress test simulation"
        return 10
    fi

    local start_time
    start_time=$(date +%s)

    # Build argent args
    local argent_args=(--simulator "$SIMULATOR_NAME" --artifacts-dir "$ARTIFACTS_RUN_DIR")
    [ -f "${ARTIFACTS_RUN_DIR}/flows.json" ] && argent_args+=(--flows "${ARTIFACTS_RUN_DIR}/flows.json")
    [ "$VERBOSE" = "true" ] && argent_args+=(--verbose)
    [ "$DRY_RUN" = "true" ] && argent_args+=(--dry-run)

    if [ "$DRY_RUN" = "true" ]; then
        log_info "[DRY RUN] Would run: $ARGENT_RUNTIME_AGENT ${argent_args[*]}"
        update_stage_status "argent" "completed" 0 "dry-run"
        return 0
    fi

    local argent_exit=0
    set +e
    "$ARGENT_RUNTIME_AGENT" "${argent_args[@]}" 2>&1 | tee "${LOGS_DIR}/argent.log"
    argent_exit=${PIPESTATUS[0]}
    set -e

    local duration=$(($(date +%s) - start_time))

    case $argent_exit in
        0)
            update_stage_status "argent" "completed" $duration
            return 0
            ;;
        11)
            log_warning "Argent misconfiguration — skipping"
            update_stage_status "argent" "skipped" $duration "misconfiguration"
            return 0
            ;;
        10)
            # Enter self-healing repair cycle
            local errors_file="${ARTIFACTS_RUN_DIR}/argent/errors.json"
            local attempt=0

            while [ $attempt -lt "$MAX_ARGENT_REPAIR_ATTEMPTS" ]; do
                attempt=$((attempt + 1))
                log_info "Argent verification failed — invoking BuildAgent for repair (attempt ${attempt}/${MAX_ARGENT_REPAIR_ATTEMPTS})"

                # Build repair args
                local repair_args=(--repair-from-errors "$errors_file" --ai-provider "$AI_PROVIDER" --artifacts-dir "$ARTIFACTS_RUN_DIR")
                [ "$YOLO_MODE" = "true" ] && repair_args+=(--yolo)
                [ "$VERBOSE" = "true" ] && repair_args+=(--verbose)

                local ba_exit=0
                set +e
                "$BUILD_AGENT" "${repair_args[@]}" 2>&1 | tee "${LOGS_DIR}/argent_repair_${attempt}.log"
                ba_exit=${PIPESTATUS[0]}
                set -e

                if [ $ba_exit -ne 0 ]; then
                    log_warning "BuildAgent repair attempt $attempt failed (exit $ba_exit)"
                    continue
                fi

                # BuildAgent's setup_directories() always creates a nested
                # build_<timestamp> directory under the --artifacts-dir it receives,
                # and writes build_output.txt there.  Pick the most-recently written
                # file so we always follow the latest repair rebuild.
                local build_output_file
                build_output_file=$(ls -t "${ARTIFACTS_RUN_DIR}"/build_*/build_output.txt 2>/dev/null | head -1 || true)
                local new_app_path=""
                [ -f "$build_output_file" ] && new_app_path=$(cat "$build_output_file")
                if [ -z "$new_app_path" ]; then
                    log_warning "build_output.txt not found under ${ARTIFACTS_RUN_DIR}/build_*/ — retry will rely on Argent auto-detection"
                fi

                # Re-run argentRuntimeAgent with updated .app path
                local retry_args=(--simulator "$SIMULATOR_NAME" --artifacts-dir "$ARTIFACTS_RUN_DIR")
                [ -n "$new_app_path" ] && retry_args+=(--app-path "$new_app_path")
                [ -f "${ARTIFACTS_RUN_DIR}/flows.json" ] && retry_args+=(--flows "${ARTIFACTS_RUN_DIR}/flows.json")
                [ "$VERBOSE" = "true" ] && retry_args+=(--verbose)

                local retry_exit=0
                set +e
                "$ARGENT_RUNTIME_AGENT" "${retry_args[@]}" 2>&1 | tee "${LOGS_DIR}/argent_retry_${attempt}.log"
                retry_exit=${PIPESTATUS[0]}
                set -e

                if [ $retry_exit -eq 0 ]; then
                    log_success "Argent repair succeeded on attempt $attempt"
                    duration=$(($(date +%s) - start_time))
                    update_stage_status "argent" "completed" $duration
                    return 0
                fi

                if [ $retry_exit -eq 11 ]; then
                    log_warning "Argent misconfiguration after repair (exit 11) — skipping remaining attempts"
                    duration=$(($(date +%s) - start_time))
                    update_stage_status "argent" "skipped" $duration "misconfiguration after repair"
                    return 0
                fi

                if [ $retry_exit -ne 10 ]; then
                    log_error "Argent returned non-repairable exit code $retry_exit — aborting repair loop"
                    duration=$(($(date +%s) - start_time))
                    update_stage_status "argent" "failed" $duration "non-repairable exit: $retry_exit"
                    return 10
                fi

                log_warning "Argent still failing (exit 10) after repair attempt $attempt — retrying"
            done

            log_error "Argent repair exhausted after ${MAX_ARGENT_REPAIR_ATTEMPTS} attempts — continuing to report"
            duration=$(($(date +%s) - start_time))
            update_stage_status "argent" "failed" $duration "repair exhausted"
            return 10
            ;;
        *)
            update_stage_status "argent" "failed" $duration "exit code: $argent_exit"
            return 10
            ;;
    esac
}

# Stage 6: Report Generation
run_stage_report() {
    CURRENT_STAGE="report"
    log_section "────────────────────────────────────────"
    log_section "Stage 6/6: Report Generation"
    log_section "────────────────────────────────────────"
    echo "" >&2

    local start_time
    start_time=$(date +%s)

    # Calculate pipeline duration
    local pipeline_duration=$(($(date +%s) - PIPELINE_START_TIME))

    # Build stage summary
    local stage_rows=""
    for stage in unit accessibility flow discover ui run maestro argent; do
        local status="$(_stage_result "$stage")"
        local duration="$(_stage_duration "$stage")"
        local status_class="warning"
        case "$status" in
            completed) status_class="success" ;;
            failed) status_class="failure" ;;
            skipped) status_class="warning" ;;
        esac
        local _stage_cap="$(echo "$stage" | awk '{print toupper(substr($0,1,1)) substr($0,2)}')"
        local _status_cap="$(echo "$status" | awk '{print toupper(substr($0,1,1)) substr($0,2)}')"
        stage_rows+="<tr><td>${_stage_cap}</td><td class='$status_class'>${_status_cap}</td><td>${duration}s</td></tr>"
    done

    # Count successes/failures
    local completed=0
    local failed=0
    local skipped=0
    for _st in unit accessibility flow discover ui run maestro argent; do
        local _status="$(_stage_result "$_st")"
        case "$_status" in
            completed) completed=$((completed + 1)) ;;
            failed) failed=$((failed + 1)) ;;
            skipped) skipped=$((skipped + 1)) ;;
        esac
    done

    # Build Maestro summary section from maestro/summary.json if present
    local maestro_section=""
    local maestro_summary_file="${ARTIFACTS_RUN_DIR}/maestro/summary.json"
    if [ -f "$maestro_summary_file" ] && command -v jq >/dev/null 2>&1; then
        local maestro_status maestro_flow_rows maestro_screenshots
        maestro_status=$(jq -r '.status // "unknown"' "$maestro_summary_file" 2>/dev/null || echo "unknown")
        maestro_flow_rows=""
        while IFS= read -r flow_row; do
            maestro_flow_rows+="$flow_row"
        done < <(jq -r '
            .flows[]? |
            "<tr><td>" + (.name // "unnamed") + "</td>" +
            "<td>" + (.status // "unknown") + "</td>" +
            "<td>" + ((.total_steps // 0) | tostring) + "/" + ((.failed_steps // 0) | tostring) + "</td>" +
            "<td>" + ((.duration_ms // 0) | tostring) + "ms</td></tr>"
        ' "$maestro_summary_file" 2>/dev/null || true)
        maestro_screenshots=""
        while IFS= read -r img_path; do
            [ -f "$img_path" ] && maestro_screenshots+="<img src='${img_path}' style='max-width:200px;margin:4px;' alt='screenshot'/>"
        done < <(find "${ARTIFACTS_RUN_DIR}/maestro/screenshots" -name "*.png" 2>/dev/null | sort || true)
        maestro_section="
    <div class='section'>
        <h2>Maestro UI Flow Verification</h2>
        <p>Status: <strong>${maestro_status}</strong></p>
        $([ -n "$maestro_flow_rows" ] && echo "
        <table>
            <tr><th>Flow</th><th>Status</th><th>Steps (Total/Failed)</th><th>Duration</th></tr>
            ${maestro_flow_rows}
        </table>")
        $([ -n "$maestro_screenshots" ] && echo "<div>${maestro_screenshots}</div>")
    </div>"
    fi

    # Build Argent summary section from argent/summary.json if present
    local argent_section=""
    local argent_summary_file="${ARTIFACTS_RUN_DIR}/argent/summary.json"
    if [ -f "$argent_summary_file" ] && command -v jq >/dev/null 2>&1; then
        local argent_status argent_flow_rows argent_screenshots
        argent_status=$(jq -r '.status // "unknown"' "$argent_summary_file" 2>/dev/null || echo "unknown")
        argent_flow_rows=""
        while IFS= read -r flow_row; do
            argent_flow_rows+="$flow_row"
        done < <(jq -r '
            .flows[]? |
            "<tr><td>" + (.name // "unnamed") + "</td>" +
            "<td>" + (.status // "unknown") + "</td>" +
            "<td>" + ((.stepsPassed // 0) | tostring) + "/" + ((.stepsTotal // 0) | tostring) + "</td>" +
            "<td>" + (.error // "") + "</td></tr>"
        ' "$argent_summary_file" 2>/dev/null || true)
        argent_screenshots=""
        while IFS= read -r img_path; do
            [ -f "$img_path" ] && argent_screenshots+="<img src='${img_path}' style='max-width:200px;margin:4px;' alt='screenshot'/>"
        done < <(find "${ARTIFACTS_RUN_DIR}/argent/screens" -name "*.png" 2>/dev/null | sort || true)
        argent_section="
    <div class='section'>
        <h2>Argent Runtime Verification</h2>
        <p>Status: <strong>${argent_status}</strong></p>
        $([ -n "$argent_flow_rows" ] && echo "
        <table>
            <tr><th>Flow</th><th>Status</th><th>Steps</th><th>Error</th></tr>
            ${argent_flow_rows}
        </table>")
        $([ -n "$argent_screenshots" ] && echo "<div>${argent_screenshots}</div>")
    </div>"
    fi

    local report_data="<div class='section'>
        <h2>Pipeline Summary</h2>
        <table>
            <tr><th>Metric</th><th>Value</th></tr>
            <tr><td>Total Stages</td><td>8</td></tr>
            <tr><td>Completed</td><td class='success'>${completed}</td></tr>
            <tr><td>Failed</td><td class='failure'>${failed}</td></tr>
            <tr><td>Skipped</td><td class='warning'>${skipped}</td></tr>
            <tr><td>Total Duration</td><td>${pipeline_duration}s</td></tr>
        </table>
    </div>

    <div class='section'>
        <h2>Stage Details</h2>
        <table>
            <tr><th>Stage</th><th>Status</th><th>Duration</th></tr>
            $stage_rows
        </table>
    </div>
    ${maestro_section}
    ${argent_section}
    <div class='section'>
        <h2>Configuration</h2>
        <table>
            <tr><th>Setting</th><th>Value</th></tr>
            <tr><td>Project</td><td>${XCODE_WORKSPACE:-${XCODE_PROJECT:-auto-detect}}</td></tr>
            <tr><td>Scheme</td><td>${SCHEME:-auto-detect}</td></tr>
            <tr><td>AI Provider</td><td>${AI_PROVIDER}</td></tr>
            <tr><td>YOLO Mode</td><td>${YOLO_MODE}</td></tr>
        </table>
    </div>

    <div class='section'>
        <h2>Artifacts</h2>
        <ul>
            <li><a href='flows.json'>Flow Definitions</a></li>
            <li><a href='TestReports/'>Test Reports</a></li>
            <li><a href='maestro/'>Maestro UI Flow Artifacts</a></li>
            <li><a href='argent/'>Argent Verification Artifacts</a></li>
            <li><a href='stages.json'>Stage Tracking</a></li>
        </ul>
    </div>"

    generate_report \
        --title "Test Pipeline Report" \
        --format html \
        --output "${ARTIFACTS_RUN_DIR}/pipeline_report.html" \
        --data "$report_data"

    # JSON summary
    local json_data="{
        \"totalStages\": 8,
        \"completedStages\": $completed,
        \"failedStages\": $failed,
        \"skippedStages\": $skipped,
        \"totalDuration\": $pipeline_duration,
        \"aiProvider\": \"$AI_PROVIDER\",
        \"yoloMode\": $YOLO_MODE
    }"

    generate_report \
        --title "Pipeline Summary" \
        --format json \
        --output "${ARTIFACTS_RUN_DIR}/pipeline_summary.json" \
        --data "$json_data"

    # ── Rich Argent HTML Report (with screenshots & code analysis) ─────────────
    local rich_report_generator="${SCRIPT_DIR}/lib/testgen/report_generator.py"
    if [ -f "$rich_report_generator" ]; then
        log_info "Generating rich HTML report with screenshots..."
        local combined_exec="${ARTIFACTS_RUN_DIR}/argent/executions_combined.json"
        local analysis_json="${ARTIFACTS_RUN_DIR}/.argent/analysis.json"
        local rich_report="${ARTIFACTS_RUN_DIR}/test_report.html"

        # Build combined execution JSON from individual flow executions
        if [ -d "${ARTIFACTS_RUN_DIR}/argent" ]; then
            local valid_flows="[]"
            for f in "${ARTIFACTS_RUN_DIR}/argent/execution_"*.json; do
                [ -f "$f" ] || continue
                # Handle both wrapped flow objects (with .steps) and raw NDJSON
                if jq -e '.steps' "$f" >/dev/null 2>&1; then
                    # Already wrapped flow object
                    valid_flows=$(echo "$valid_flows" | jq --argjson flow "$(cat "$f")" '. + [$flow]' 2>/dev/null || echo "$valid_flows")
                elif jq -s -e '.[0].kind' "$f" >/dev/null 2>&1; then
                    # Raw NDJSON from flow-execute — wrap it
                    local flow_name
                    flow_name=$(basename "$f" .json | sed 's/execution_//')
                    local wrapped
                    wrapped=$(jq -s --arg name "$flow_name" --arg status "unknown" \
                        '{name: $name, status: $status, steps: .}' "$f" 2>/dev/null)
                    [ -n "$wrapped" ] && valid_flows=$(echo "$valid_flows" | jq --argjson flow "$wrapped" '. + [$flow]' 2>/dev/null || echo "$valid_flows")
                fi
            done
            echo "{\"flows\": $valid_flows}" > "$combined_exec"

            if python3 "$rich_report_generator" \
                --execution-json "$combined_exec" \
                ${analysis_json:+--analysis-json "$analysis_json"} \
                --screenshots-dir "${ARTIFACTS_RUN_DIR}/argent/screens" \
                --project-name "${SCHEME:-AmmoScan}" \
                --bundle-id "${BUNDLE_ID:-}" \
                --simulator "${SIMULATOR_NAME:-}" \
                --output "$rich_report" 2>&1; then
                log_success "Rich HTML report: $rich_report"
            else
                log_warning "Rich report generation failed"
            fi
            rm -f "$combined_exec"
        fi
    fi

    local duration=$(($(date +%s) - start_time))
    update_stage_status "report" "completed" $duration

    log_success "Pipeline report generated: ${ARTIFACTS_RUN_DIR}/pipeline_report.html"
}

# ─────────────────────────────────────────────────────────────────────────────
# Main Execution
# ─────────────────────────────────────────────────────────────────────────────

main() {
    parse_arguments "$@"
    initialize

    # Prepare simulator if requested
    if ! prepare_simulator_for_pipeline; then
        log_error "Simulator preparation failed"
        exit 11
    fi

    # Start pipeline log capture
    start_pipeline_log_capture

    # Retrieve build context from Letta memory if available
    retrieve_build_context

    # Load previous pipeline state (coverage, etc.)
    load_pipeline_state

    local exit_code=0

    # Run pipeline stages with live keyboard skip support
    run_stage_with_skip "unit" run_stage_unit || exit_code=10
    run_stage_with_skip "accessibility" run_stage_accessibility || exit_code=10
    run_stage_with_skip "flow" run_stage_flow || exit_code=10
    run_stage_with_skip "discover" run_stage_discover || exit_code=10
    run_stage_with_skip "ui" run_stage_ui || exit_code=10
    run_stage_with_skip "run" run_stage_run || exit_code=10
    run_stage_with_skip "maestro" run_stage_maestro || exit_code=10
    run_stage_with_skip "argent" run_stage_argent || exit_code=10
    run_stage_report

    # Calculate final duration
    local pipeline_duration=$(($(date +%s) - PIPELINE_START_TIME))

    # Store test results to Letta memory
    # TODO: Extract actual test counts from test results when available
    local tests_passed=0
    local tests_failed=0
    if [ $exit_code -eq 0 ]; then
        tests_passed=1  # Placeholder - pipeline succeeded
    else
        tests_failed=1  # Placeholder - pipeline had failures
    fi
    store_test_results 1 "$tests_passed" "$tests_failed" 0

    # Final status
    echo "" >&2
    log_section "════════════════════════════════════════════════════════"
    if [ $exit_code -eq 0 ]; then
        log_success "Test Pipeline Complete!"
    else
        log_error "Test Pipeline completed with failures"
    fi
    log_section "════════════════════════════════════════════════════════"
    echo "" >&2

    # Print summary
    log_info "Stage Summary:"
    for stage in unit accessibility flow discover ui run maestro argent report; do
        local status="$(_stage_result "$stage")"
        local duration="$(_stage_duration "$stage")"
        case "$status" in
            completed) echo -e "  ${GREEN}✓${NC} ${stage}: ${duration}s" >&2 ;;
            failed) echo -e "  ${RED}✗${NC} ${stage}: ${duration}s" >&2 ;;
            skipped) echo -e "  ${YELLOW}○${NC} ${stage}: skipped" >&2 ;;
            *) echo -e "  ${CYAN}?${NC} ${stage}: pending" >&2 ;;
        esac
    done
    echo "" >&2

    log_info "Total Duration: ${pipeline_duration}s"
    log_info "Artifacts: ${ARTIFACTS_RUN_DIR}"
    log_info "Report: ${ARTIFACTS_RUN_DIR}/pipeline_report.html"

    # Save pipeline state for next run
    save_pipeline_state

    # Stop pipeline log capture
    if [ "$CAPTURE_PIPELINE_LOGS" = "true" ] && [ -n "$PIPELINE_LOG_SESSION" ]; then
        log_info "Stopping pipeline log capture..."
        stop_log_capture "$PIPELINE_LOG_SESSION" 2>/dev/null || true
    fi

    exit $exit_code
}

main "$@"
