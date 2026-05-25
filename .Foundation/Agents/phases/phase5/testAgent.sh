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

# Letta Memory integration (set by BuildVerify.sh orchestrator)
LETTA_MEMORY_AGENT="${LETTA_MEMORY_AGENT:-}"
LETTA_MEMORY_SCRIPT="${LETTA_MEMORY_SCRIPT:-}"
LETTA_BUILD_CONTEXT=""  # Retrieved build context from memory

# State tracking
STAGES_FILE=""
CURRENT_STAGE=""
PIPELINE_START_TIME=""

# Stage results
declare -A STAGE_RESULTS
declare -A STAGE_DURATIONS

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
                            unit, accessibility, flow, ui, run
    --resume-from <stage>   Resume pipeline from specific stage
    --ai-provider <name>    AI provider for all agents
    --yolo                  Auto-approve for all agents
    --record                Enable recording in test runner
    --report-dir <path>     Final report directory
    --artifacts-dir <path>  Artifacts output directory
    --skip-unit             Skip unit test generation
    --skip-accessibility    Skip accessibility agent
    --skip-flow             Skip flow analysis
    --skip-ui               Skip UI test generation
    --skip-run              Skip test execution
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
        "unit": "${STAGE_RESULTS[unit]:-skipped}",
        "accessibility": "${STAGE_RESULTS[accessibility]:-skipped}",
        "flow": "${STAGE_RESULTS[flow]:-skipped}",
        "ui": "${STAGE_RESULTS[ui]:-skipped}",
        "run": "${STAGE_RESULTS[run]:-skipped}"
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

initialize() {
    log_section "════════════════════════════════════════════════════════"
    log_section "Test Agent - Complete Test Automation Pipeline"
    log_section "════════════════════════════════════════════════════════"
    echo "" >&2

    PIPELINE_START_TIME=$(date +%s)

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

    STAGE_RESULTS[$stage]="$status"
    STAGE_DURATIONS[$stage]="$duration"

    if command -v jq >/dev/null 2>&1; then
        local tmp_file
        tmp_file=$(mktemp)
        jq ".stages.\"$stage\" = {\"status\": \"$status\", \"duration\": $duration, \"details\": \"$details\"}" "$STAGES_FILE" > "$tmp_file"
        mv "$tmp_file" "$STAGES_FILE"
    fi

    case "$status" in
        completed)
            log_success "Stage $stage completed (${duration}s)"
            ;;
        failed)
            log_error "Stage $stage failed (${duration}s)"
            ;;
        skipped)
            log_warning "Stage $stage skipped"
            ;;
    esac
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
        local stages=("unit" "accessibility" "flow" "ui" "run" "report")
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
        ui) [ "$SKIP_UI" = "true" ] && return 1 ;;
        run) [ "$SKIP_RUN" = "true" ] && return 1 ;;
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
build_agent_args() {
    local args=""

    if [ -n "${XCODE_WORKSPACE:-}" ]; then
        args="$args --project \"$XCODE_WORKSPACE\""
    elif [ -n "${XCODE_PROJECT:-}" ]; then
        args="$args --project \"$XCODE_PROJECT\""
    fi

    if [ -n "$SCHEME" ]; then
        args="$args --scheme \"$SCHEME\""
    fi

    args="$args --ai-provider \"$AI_PROVIDER\""
    args="$args --artifacts-dir \"${ARTIFACTS_RUN_DIR}\""

    [ "$YOLO_MODE" = "true" ] && args="$args --yolo"
    [ "$VERBOSE" = "true" ] && args="$args --verbose"
    [ "$DRY_RUN" = "true" ] && args="$args --dry-run"

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

    CURRENT_STAGE="unit"
    log_section "────────────────────────────────────────"
    log_section "Stage 1/6: Unit Test Generation"
    log_section "────────────────────────────────────────"
    echo "" >&2

    local start_time
    start_time=$(date +%s)
    local args
    args=$(build_agent_args)

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
        update_stage_status "unit" "completed" $duration
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

    CURRENT_STAGE="accessibility"
    log_section "────────────────────────────────────────"
    log_section "Stage 2/6: Accessibility Compliance"
    log_section "────────────────────────────────────────"
    echo "" >&2

    local start_time
    start_time=$(date +%s)
    local args
    args=$(build_agent_args)

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

    CURRENT_STAGE="flow"
    log_section "────────────────────────────────────────"
    log_section "Stage 3/6: Flow Analysis"
    log_section "────────────────────────────────────────"
    echo "" >&2

    local start_time
    start_time=$(date +%s)
    local args
    args=$(build_agent_args)
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

# Stage 4: UI Test Generation
run_stage_ui() {
    if ! should_run_stage "ui"; then
        update_stage_status "ui" "skipped"
        return 0
    fi

    CURRENT_STAGE="ui"
    log_section "────────────────────────────────────────"
    log_section "Stage 4/6: UI Test Generation"
    log_section "────────────────────────────────────────"
    echo "" >&2

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
    args=$(build_agent_args)
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

    CURRENT_STAGE="run"
    log_section "────────────────────────────────────────"
    log_section "Stage 5/6: Test Execution"
    log_section "────────────────────────────────────────"
    echo "" >&2

    local start_time
    start_time=$(date +%s)
    local args
    args=$(build_agent_args)
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
    for stage in unit accessibility flow ui run; do
        local status="${STAGE_RESULTS[$stage]:-pending}"
        local duration="${STAGE_DURATIONS[$stage]:-0}"
        local status_class="warning"
        case "$status" in
            completed) status_class="success" ;;
            failed) status_class="failure" ;;
            skipped) status_class="warning" ;;
        esac
        stage_rows+="<tr><td>${stage^}</td><td class='$status_class'>${status^}</td><td>${duration}s</td></tr>"
    done

    # Count successes/failures
    local completed=0
    local failed=0
    local skipped=0
    for status in "${STAGE_RESULTS[@]}"; do
        case "$status" in
            completed) completed=$((completed + 1)) ;;
            failed) failed=$((failed + 1)) ;;
            skipped) skipped=$((skipped + 1)) ;;
        esac
    done

    local report_data="<div class='section'>
        <h2>Pipeline Summary</h2>
        <table>
            <tr><th>Metric</th><th>Value</th></tr>
            <tr><td>Total Stages</td><td>6</td></tr>
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
        \"totalStages\": 6,
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

    local exit_code=0

    # Run pipeline stages
    run_stage_unit || exit_code=10
    run_stage_accessibility || exit_code=10
    run_stage_flow || exit_code=10
    run_stage_ui || exit_code=10
    run_stage_run || exit_code=10
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
    for stage in unit accessibility flow ui run report; do
        local status="${STAGE_RESULTS[$stage]:-pending}"
        local duration="${STAGE_DURATIONS[$stage]:-0}"
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

    # Stop pipeline log capture
    if [ "$CAPTURE_PIPELINE_LOGS" = "true" ] && [ -n "$PIPELINE_LOG_SESSION" ]; then
        log_info "Stopping pipeline log capture..."
        stop_log_capture "$PIPELINE_LOG_SESSION" 2>/dev/null || true
    fi

    exit $exit_code
}

main "$@"
