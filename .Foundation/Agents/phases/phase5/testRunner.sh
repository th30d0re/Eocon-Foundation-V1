#!/usr/bin/env bash

# Test Runner Agent
# Executes tests and generates comprehensive reports with recordings
# Based on Foundation methodology and BuildAgent patterns
#
# Exit Codes:
#   0  - All tests passed
#   10 - Some tests failed
#   11 - Misconfiguration
#   12 - Execution error

set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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
source "${LIB_DIR}/simulator.sh"
source "${LIB_DIR}/simulator_prepare.sh"
source "${LIB_DIR}/log_capture.sh"
source "${LIB_DIR}/session_store.sh"

# Set log prefix for this agent
LOG_PREFIX="[RUNNER]"

# Configuration variables
PROJECT_PATH=""
SCHEME=""
TEST_PLAN=""
DESTINATIONS="${DESTINATIONS:-}"
PARALLEL="${PARALLEL:-false}"
MAX_CONCURRENT="${MAX_CONCURRENT:-2}"
RECORD="${RECORD:-false}"
SCREENSHOTS="${SCREENSHOTS:-false}"
SCREENSHOT_ON_FAIL="${SCREENSHOT_ON_FAIL:-true}"
VIDEO_QUALITY="${VIDEO_QUALITY:-medium}"
KEEP_RECORDINGS="${KEEP_RECORDINGS:-false}"
REPORT_FORMAT="${REPORT_FORMAT:-html}"  # html, json, markdown
REPORT_DIR=""
ARTIFACTS_DIR="${ARTIFACTS_DIR:-./Artifacts}"
VERBOSE="${VERBOSE:-false}"
DRY_RUN="${DRY_RUN:-false}"

# Simulator management variables
AUTO_BOOT="${AUTO_BOOT:-false}"
SIMULATOR_NAME=""
GPS_LOCATION=""
GPS_LAT=""
GPS_LON=""
APPEARANCE_MODE=""
CAPTURE_LOGS="${CAPTURE_LOGS:-false}"
LOG_SESSION=""

# AXe integration variables
USE_AXE="${USE_AXE:-false}"
DESCRIBE_UI_BEFORE_TESTS="${DESCRIBE_UI_BEFORE_TESTS:-false}"
UI_HIERARCHY_OUTPUT=""

# State variables
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0
TEST_DURATION=0
RECORDING_PID=""
SIMULATOR_UDID=""

# ─────────────────────────────────────────────────────────────────────────────
# Usage
# ─────────────────────────────────────────────────────────────────────────────

show_usage() {
    cat << EOF
Test Runner Agent - Test Execution and Reporting

DESCRIPTION:
    Executes unit and UI tests with optional screen recording,
    screenshots, and comprehensive reporting.

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --project <path>        Xcode project/workspace (auto-detect if not provided)
    --scheme <name>         Test scheme (auto-detect if not provided)
    --test-plan <path>      .xctestplan file to use
    --destinations <list>   Device/simulator destinations (comma-separated)
    --parallel              Enable parallel test execution
    --max-concurrent <n>    Max parallel test threads (default: 2)
    --record                Enable screen recording during tests
    --screenshots           Capture screenshots at key points
    --screenshot-on-fail    Only capture screenshots on failures (default: true)
    --video-quality <q>     Recording quality: low, medium, high (default: medium)
    --keep-recordings       Don't delete recordings after successful tests
    --report <format>       Report format: html, json, markdown (default: html)
    --report-dir <path>     Report output directory
    --artifacts-dir <path>  Artifacts output directory
    --verbose               Enable verbose output
    --dry-run               Show what would be done without executing

  SIMULATOR MANAGEMENT:
    --auto-boot             Auto-boot simulator if not running
    --simulator-name <name> Simulator to use (from session or flag)
    --set-location <lat,lon> Set GPS location before tests
    --appearance <mode>     Set dark/light mode
    --capture-logs          Enable structured log capture
    --use-axe               Enable AXe UI automation support
    --describe-ui           Capture UI hierarchy before tests

    --help                  Show this help message

EXAMPLES:
    # Basic test execution
    $0

    # With screen recording
    $0 --record --video-quality high

    # Parallel execution on multiple simulators
    $0 --parallel --destinations "iPhone 17 Pro Max,iPhone 17 Pro"

    # Using test plan
    $0 --test-plan Tests.xctestplan

    # With AXe UI automation and live UI description
    $0 --use-axe --describe-ui --simulator-name "iPhone 16"

EXIT CODES:
    0   All tests passed
    10  Some tests failed
    11  Misconfiguration
    12  Execution error

OUTPUT:
    TestReports/
    ├── index.html          Dashboard with summary
    ├── flows/              Individual flow reports
    ├── screenshots/        Test screenshots
    ├── recordings/         Screen recordings
    └── report.json         Machine-readable results
EOF
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
            --test-plan)
                TEST_PLAN="${2:-}"
                shift 2
                ;;
            --destinations)
                DESTINATIONS="${2:-}"
                shift 2
                ;;
            --parallel)
                PARALLEL="true"
                shift 1
                ;;
            --max-concurrent)
                MAX_CONCURRENT="${2:-2}"
                shift 2
                ;;
            --record)
                RECORD="true"
                shift 1
                ;;
            --screenshots)
                SCREENSHOTS="true"
                shift 1
                ;;
            --screenshot-on-fail)
                SCREENSHOT_ON_FAIL="true"
                shift 1
                ;;
            --video-quality)
                VIDEO_QUALITY="${2:-medium}"
                shift 2
                ;;
            --keep-recordings)
                KEEP_RECORDINGS="true"
                shift 1
                ;;
            --report)
                REPORT_FORMAT="${2:-html}"
                shift 2
                ;;
            --report-dir)
                REPORT_DIR="${2:-}"
                shift 2
                ;;
            --artifacts-dir)
                ARTIFACTS_DIR="${2:-./Artifacts}"
                shift 2
                ;;
            --verbose|-v)
                VERBOSE="true"
                shift 1
                ;;
            --dry-run)
                DRY_RUN="true"
                shift 1
                ;;
            --auto-boot)
                AUTO_BOOT="true"
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
            --capture-logs)
                CAPTURE_LOGS="true"
                shift 1
                ;;
            --use-axe)
                USE_AXE="true"
                shift 1
                ;;
            --describe-ui)
                DESCRIBE_UI_BEFORE_TESTS="true"
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
    log_section "════════════════════════════════════════"
    log_section "Test Runner Starting"
    log_section "════════════════════════════════════════"
    echo "" >&2

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
    mkdir -p "$REPORT_DIR/screenshots"
    mkdir -p "$REPORT_DIR/recordings"
    mkdir -p "$REPORT_DIR/flows"

    # Auto-detect Xcode project
    if [ -z "$PROJECT_PATH" ]; then
        detect_xcode_project || {
            log_warning "Could not auto-detect Xcode project"
        }
    else
        if [[ "$PROJECT_PATH" == *.xcworkspace ]]; then
            XCODE_WORKSPACE="$PROJECT_PATH"
        else
            XCODE_PROJECT="$PROJECT_PATH"
        fi
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
    log_info "  Test Plan: ${TEST_PLAN:-none}"
    log_info "  Destinations: ${DESTINATIONS:-default}"
    log_info "  Parallel: $PARALLEL"
    log_info "  Recording: $RECORD"
    log_info "  Screenshots: $SCREENSHOTS"
    log_info "  Report Dir: $REPORT_DIR"
    echo "" >&2
}

# ─────────────────────────────────────────────────────────────────────────────
# Simulator Management
# ─────────────────────────────────────────────────────────────────────────────

# Get booted simulator UDID
get_booted_simulator() {
    xcrun simctl list devices booted -j 2>/dev/null | \
        jq -r '.devices | to_entries | .[].value | .[] | select(.state == "Booted") | .udid' | \
        head -1
}

# Boot a simulator if needed
ensure_simulator_booted() {
    local destination="${1:-}"

    SIMULATOR_UDID=$(get_booted_simulator)

    if [ -z "$SIMULATOR_UDID" ]; then
        log_info "Booting simulator..."

        # Extract device name from destination
        local device_name
        device_name=$(echo "$destination" | grep -o "name=[^,]*" | cut -d= -f2)
        if [ -z "$device_name" ]; then
            device_name=$(detect_available_simulator)
            [ -z "$device_name" ] && device_name="iPhone 16"
        fi

        # Get UDID for device
        local udid
        udid=$(xcrun simctl list devices available -j | \
            jq -r ".devices | to_entries | .[].value | .[] | select(.name == \"$device_name\") | .udid" | \
            head -1)

        if [ -n "$udid" ]; then
            xcrun simctl boot "$udid" 2>/dev/null || true
            SIMULATOR_UDID="$udid"
            sleep 3  # Wait for boot
        fi
    fi

    log_verbose "Simulator UDID: ${SIMULATOR_UDID:-none}"
}

# ─────────────────────────────────────────────────────────────────────────────
# Screen Recording
# ─────────────────────────────────────────────────────────────────────────────

# Start screen recording
start_recording() {
    if [ "$RECORD" != "true" ]; then
        return 0
    fi

    log_info "Starting screen recording..."

    ensure_simulator_booted

    if [ -z "$SIMULATOR_UDID" ]; then
        log_warning "No simulator available for recording"
        return 1
    fi

    local video_file="$REPORT_DIR/recordings/test_run_$(date +%Y%m%d_%H%M%S).mp4"

    # Set codec based on quality
    local codec="h264"
    case "$VIDEO_QUALITY" in
        low)
            codec="h264"
            ;;
        medium)
            codec="h264"
            ;;
        high)
            codec="hevc"
            ;;
    esac

    if [ "$DRY_RUN" = "true" ]; then
        log_info "[DRY RUN] Would start recording: $video_file"
        return 0
    fi

    # Start recording in background
    xcrun simctl io "$SIMULATOR_UDID" recordVideo --codec="$codec" --force "$video_file" &
    RECORDING_PID=$!

    log_verbose "Recording started (PID: $RECORDING_PID)"
    echo "$video_file"
}

# Stop screen recording
stop_recording() {
    if [ -n "$RECORDING_PID" ]; then
        log_info "Stopping screen recording..."
        kill -INT "$RECORDING_PID" 2>/dev/null || true
        wait "$RECORDING_PID" 2>/dev/null || true
        RECORDING_PID=""
    fi
}

# Capture screenshot
capture_screenshot() {
    local name="$1"

    if [ "$SCREENSHOTS" != "true" ] && [ "$SCREENSHOT_ON_FAIL" != "true" ]; then
        return 0
    fi

    if [ -z "$SIMULATOR_UDID" ]; then
        ensure_simulator_booted
    fi

    if [ -z "$SIMULATOR_UDID" ]; then
        return 1
    fi

    local screenshot_file="$REPORT_DIR/screenshots/${name}_$(date +%Y%m%d_%H%M%S).png"

    if [ "$DRY_RUN" = "true" ]; then
        log_verbose "[DRY RUN] Would capture: $screenshot_file"
        return 0
    fi

    xcrun simctl io "$SIMULATOR_UDID" screenshot "$screenshot_file" 2>/dev/null && \
        log_verbose "Screenshot: $screenshot_file"
}

# ─────────────────────────────────────────────────────────────────────────────
# Test Execution
# ─────────────────────────────────────────────────────────────────────────────

# Build xcodebuild test command
build_test_command() {
    local cmd="xcodebuild test"

    # Add workspace/project
    if [ -n "${XCODE_WORKSPACE:-}" ]; then
        cmd="$cmd -workspace \"$XCODE_WORKSPACE\""
    elif [ -n "${XCODE_PROJECT:-}" ]; then
        cmd="$cmd -project \"$XCODE_PROJECT\""
    fi

    # Add scheme
    if [ -n "$SCHEME" ]; then
        cmd="$cmd -scheme \"$SCHEME\""
    fi

    # Add test plan
    if [ -n "$TEST_PLAN" ] && [ -f "$TEST_PLAN" ]; then
        cmd="$cmd -testPlan \"$(basename "$TEST_PLAN" .xctestplan)\""
    fi

    # Add destinations
    if [ -n "$DESTINATIONS" ]; then
        IFS=',' read -ra dest_list <<< "$DESTINATIONS"
        for dest in "${dest_list[@]}"; do
            cmd="$cmd -destination 'platform=iOS Simulator,name=$dest'"
        done
    else
        local sim_name
        sim_name=$(detect_available_simulator)
        [ -z "$sim_name" ] && sim_name="iPhone 16"
        cmd="$cmd -destination 'platform=iOS Simulator,name=$sim_name'"
    fi

    # Parallel execution
    if [ "$PARALLEL" = "true" ]; then
        cmd="$cmd -parallel-testing-enabled YES"
        cmd="$cmd -maximum-concurrent-test-simulator-destinations $MAX_CONCURRENT"
    fi

    # Enable code coverage
    cmd="$cmd -enableCodeCoverage YES"

    # Result bundle path
    cmd="$cmd -resultBundlePath \"$REPORT_DIR/TestResults.xcresult\""

    echo "$cmd"
}

# Execute tests
run_tests() {
    log_section "Executing tests..."

    # Prepare simulator if auto-boot is enabled
    if [ "$AUTO_BOOT" = "true" ] && [ -n "$SIMULATOR_NAME" ]; then
        log_info "Preparing simulator: $SIMULATOR_NAME"

        # Get simulator UUID
        SIMULATOR_UDID=$(get_simulator_by_name "$SIMULATOR_NAME") || {
            log_error "Failed to resolve simulator: $SIMULATOR_NAME"
            return 12
        }

        # Check if simulator is booted
        if [ "$(is_simulator_booted "$SIMULATOR_UDID")" != "true" ]; then
            log_info "Booting simulator: $SIMULATOR_NAME"
            boot_simulator "$SIMULATOR_NAME" true > /dev/null || {
                log_error "Failed to boot simulator"
                return 12
            }
        else
            log_info "Simulator already booted"
        fi

        # Configure simulator
        if [ -n "$GPS_LAT" ] && [ -n "$GPS_LON" ]; then
            log_info "Setting GPS location: $GPS_LAT, $GPS_LON"
            set_simulator_location "$SIMULATOR_UDID" "$GPS_LAT" "$GPS_LON" > /dev/null || {
                log_warning "Failed to set GPS location"
            }
        fi

        if [ -n "$APPEARANCE_MODE" ]; then
            log_info "Setting appearance: $APPEARANCE_MODE"
            set_simulator_appearance "$SIMULATOR_UDID" "$APPEARANCE_MODE" > /dev/null || {
                log_warning "Failed to set appearance"
            }
        fi
    fi

    # Start log capture if enabled
    if [ "$CAPTURE_LOGS" = "true" ] && command -v start_log_capture &>/dev/null; then
        log_info "Starting log capture..."
        LOG_SESSION=$(start_log_capture "iOS" "test" "${SCHEME:-TestRun}") || {
            log_warning "Failed to start log capture"
        }
        # Register cleanup trap
        trap 'stop_log_capture "$LOG_SESSION" 2>/dev/null || true' EXIT
    fi

    # Describe UI via AXe if enabled
    if [ "$USE_AXE" = "true" ] && [ "$DESCRIBE_UI_BEFORE_TESTS" = "true" ]; then
        if command -v is_axe_available &>/dev/null && is_axe_available; then
            log_info "Capturing UI hierarchy via AXe..."
            UI_HIERARCHY_OUTPUT="${ARTIFACTS_DIR}/ui_hierarchy_pre_test.json"
            JSON_OUTPUT=false axe_describe_ui "$SIMULATOR_UDID" > "$UI_HIERARCHY_OUTPUT" || {
                log_warning "Failed to capture UI hierarchy"
            }
        else
            log_warning "AXe not available, skipping UI description"
        fi
    fi

    local test_cmd
    test_cmd=$(build_test_command)

    log_verbose "Test command: $test_cmd"

    if [ "$DRY_RUN" = "true" ]; then
        log_info "[DRY RUN] Would execute: $test_cmd"
        return 0
    fi

    local test_log="$LOGS_DIR/test_execution.log"
    local start_time
    start_time=$(date +%s)

    # Start recording if enabled
    local recording_file=""
    if [ "$RECORD" = "true" ]; then
        recording_file=$(start_recording)
    fi

    # Execute tests
    local exit_code=0
    if eval "$test_cmd" > "$test_log" 2>&1; then
        exit_code=0
    else
        exit_code=$?
    fi

    local end_time
    end_time=$(date +%s)
    TEST_DURATION=$((end_time - start_time))

    # Stop recording
    stop_recording

    # Capture failure screenshot if tests failed
    if [ $exit_code -ne 0 ] && [ "$SCREENSHOT_ON_FAIL" = "true" ]; then
        capture_screenshot "test_failure"
    fi

    # Stop log capture
    if [ "$CAPTURE_LOGS" = "true" ] && [ -n "$LOG_SESSION" ]; then
        log_info "Stopping log capture..."
        stop_log_capture "$LOG_SESSION" 2>/dev/null || true
    fi

    log_verbose "Test execution completed in ${TEST_DURATION}s (exit code: $exit_code)"

    return $exit_code
}

# ─────────────────────────────────────────────────────────────────────────────
# Result Parsing
# ─────────────────────────────────────────────────────────────────────────────

# Parse test results from xcresult bundle
parse_test_results() {
    log_section "Parsing test results..."

    local xcresult="$REPORT_DIR/TestResults.xcresult"

    if [ ! -d "$xcresult" ]; then
        log_warning "No xcresult bundle found"
        return 1
    fi

    # Extract test summary using xcrun
    if command -v xcrun >/dev/null 2>&1; then
        local summary_json="$LOGS_DIR/test_summary.json"

        # Get test plan run summaries
        if xcrun xcresulttool get --format json --path "$xcresult" > "$summary_json" 2>/dev/null; then
            if command -v jq >/dev/null 2>&1; then
                # Parse test counts
                TOTAL_TESTS=$(jq '.metrics.testsCount.value // 0' "$summary_json" 2>/dev/null || echo "0")
                PASSED_TESTS=$(jq '.metrics.testsPassedCount.value // 0' "$summary_json" 2>/dev/null || echo "0")
                FAILED_TESTS=$(jq '.metrics.testsFailedCount.value // 0' "$summary_json" 2>/dev/null || echo "0")
                SKIPPED_TESTS=$(jq '.metrics.testsSkippedCount.value // 0' "$summary_json" 2>/dev/null || echo "0")
            fi
        fi
    fi

    log_info "Test Results:"
    log_info "  Total: $TOTAL_TESTS"
    log_info "  Passed: $PASSED_TESTS"
    log_info "  Failed: $FAILED_TESTS"
    log_info "  Skipped: $SKIPPED_TESTS"
    log_info "  Duration: ${TEST_DURATION}s"
}

# Extract coverage information
extract_coverage() {
    log_section "Extracting coverage..."

    local xcresult="$REPORT_DIR/TestResults.xcresult"

    if [ ! -d "$xcresult" ]; then
        return 1
    fi

    local coverage_json="$REPORT_DIR/coverage.json"

    if xcrun xccov view --report --json "$xcresult" > "$coverage_json" 2>/dev/null; then
        if command -v jq >/dev/null 2>&1; then
            local coverage
            coverage=$(jq '.lineCoverage * 100 | floor' "$coverage_json" 2>/dev/null || echo "0")
            log_info "Code Coverage: ${coverage}%"
        fi
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Report Generation
# ─────────────────────────────────────────────────────────────────────────────

generate_test_report() {
    log_section "Generating test reports..."

    # Calculate pass rate
    local pass_rate=0
    if [ "$TOTAL_TESTS" -gt 0 ]; then
        pass_rate=$(( (PASSED_TESTS * 100) / TOTAL_TESTS ))
    fi

    # Determine status class
    local status_class="success"
    if [ "$FAILED_TESTS" -gt 0 ]; then
        status_class="failure"
    fi

    # Generate HTML report
    local report_data="<div class='section'>
        <h2>Test Execution Summary</h2>
        <table>
            <tr><th>Metric</th><th>Value</th></tr>
            <tr><td>Total Tests</td><td>${TOTAL_TESTS}</td></tr>
            <tr><td>Passed</td><td class='success'>${PASSED_TESTS}</td></tr>
            <tr><td>Failed</td><td class='${status_class}'>${FAILED_TESTS}</td></tr>
            <tr><td>Skipped</td><td class='warning'>${SKIPPED_TESTS}</td></tr>
            <tr><td>Pass Rate</td><td>${pass_rate}%</td></tr>
            <tr><td>Duration</td><td>${TEST_DURATION}s</td></tr>
        </table>
    </div>

    <div class='section'>
        <h2>Configuration</h2>
        <table>
            <tr><th>Setting</th><th>Value</th></tr>
            <tr><td>Scheme</td><td>${SCHEME:-auto-detect}</td></tr>
            <tr><td>Destinations</td><td>${DESTINATIONS:-default}</td></tr>
            <tr><td>Parallel</td><td>${PARALLEL}</td></tr>
            <tr><td>Recording</td><td>${RECORD}</td></tr>
            <tr><td>AXe Enabled</td><td>${USE_AXE}</td></tr>
        </table>
    </div>

    <div class='section'>
        <h2>Artifacts</h2>
        <ul>
            <li><a href='TestResults.xcresult'>Test Results Bundle</a></li>
            $([ -f "$REPORT_DIR/coverage.json" ] && echo "<li><a href='coverage.json'>Coverage Report</a></li>")
            $([ -n "$UI_HIERARCHY_OUTPUT" ] && [ -f "$UI_HIERARCHY_OUTPUT" ] && echo "<li><a href='$(basename "$UI_HIERARCHY_OUTPUT")'>UI Hierarchy (Pre-Test)</a></li>")
            $([ -d "$REPORT_DIR/screenshots" ] && ls "$REPORT_DIR/screenshots"/*.png 2>/dev/null | head -5 | while read f; do echo "<li><a href='screenshots/$(basename "$f")'>$(basename "$f")</a></li>"; done)
            $([ -d "$REPORT_DIR/recordings" ] && ls "$REPORT_DIR/recordings"/*.mp4 2>/dev/null | head -3 | while read f; do echo "<li><a href='recordings/$(basename "$f")'>$(basename "$f")</a></li>"; done)
        </ul>
    </div>"

    generate_report \
        --title "Test Execution Report" \
        --format html \
        --output "$REPORT_DIR/index.html" \
        --data "$report_data"

    # Generate JSON report
    local json_data="{
        \"totalTests\": $TOTAL_TESTS,
        \"passedTests\": $PASSED_TESTS,
        \"failedTests\": $FAILED_TESTS,
        \"skippedTests\": $SKIPPED_TESTS,
        \"passRate\": $pass_rate,
        \"duration\": $TEST_DURATION,
        \"scheme\": \"${SCHEME:-auto-detect}\",
        \"parallel\": $PARALLEL,
        \"recording\": $RECORD
    }"

    generate_report \
        --title "Test Results" \
        --format json \
        --output "$REPORT_DIR/report.json" \
        --data "$json_data"

    log_success "Reports generated: $REPORT_DIR"
}

# Clean up recordings on success (if not keeping)
cleanup_recordings() {
    if [ "$KEEP_RECORDINGS" = "true" ]; then
        return 0
    fi

    if [ "$FAILED_TESTS" -eq 0 ]; then
        log_verbose "Cleaning up recordings (all tests passed)"
        rm -f "$REPORT_DIR/recordings"/*.mp4 2>/dev/null || true
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Cleanup
# ─────────────────────────────────────────────────────────────────────────────

cleanup() {
    stop_recording
}

trap cleanup EXIT INT TERM

# ─────────────────────────────────────────────────────────────────────────────
# Main Execution
# ─────────────────────────────────────────────────────────────────────────────

main() {
    parse_arguments "$@"
    initialize

    local exit_code=0

    # Execute tests
    if ! run_tests; then
        exit_code=10
    fi

    # Parse results
    parse_test_results

    # Extract coverage
    extract_coverage

    # Generate reports
    generate_test_report

    # Cleanup
    cleanup_recordings

    # Final status
    echo "" >&2
    log_section "════════════════════════════════════════"
    if [ $exit_code -eq 0 ] && [ "$FAILED_TESTS" -eq 0 ]; then
        log_success "Test Runner Complete - All tests passed!"
        write_success_log "All tests passed" "Total: $TOTAL_TESTS, Passed: $PASSED_TESTS, Duration: ${TEST_DURATION}s"
    else
        log_error "Test Runner Complete - Some tests failed"
        write_error_log "Tests failed" "Total: $TOTAL_TESTS, Failed: $FAILED_TESTS"
        exit_code=10
    fi
    log_section "════════════════════════════════════════"
    echo "" >&2

    log_info "Total: $TOTAL_TESTS | Passed: $PASSED_TESTS | Failed: $FAILED_TESTS"
    log_info "Duration: ${TEST_DURATION}s"
    log_info "Reports: $REPORT_DIR"

    exit $exit_code
}

main "$@"
