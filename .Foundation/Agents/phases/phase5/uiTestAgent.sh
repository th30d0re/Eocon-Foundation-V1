#!/usr/bin/env bash

# UI Test Agent
# Generates XCUITest files from flow definitions
# Based on Foundation methodology and BuildAgent patterns
#
# Exit Codes:
#   0  - Success
#   10 - Build failed after max retries
#   11 - Misconfiguration
#   12 - AI provider error

set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"
TEMPLATES_DIR="${SCRIPT_DIR}/templates"
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
# shellcheck disable=SC1091
source "${LIB_DIR}/testContextPaths.sh"
# shellcheck disable=SC1091
source "${LIB_DIR}/axe_helpers.sh"
# shellcheck disable=SC1091
source "${LIB_DIR}/simulator.sh"
# shellcheck disable=SC1091
source "${LIB_DIR}/simulator_prepare.sh"

# Set log prefix for this agent
LOG_PREFIX="[UI-TEST]"

# Configuration variables
FLOWS_PATH=""
FLOW_TYPE=""  # Filter: happy, sad, regression
GENERATE_TEST_PLAN="${GENERATE_TEST_PLAN:-false}"
DEVICES="${DEVICES:-}"
AI_PROVIDER="${AI_PROVIDER:-cursor}"
YOLO_MODE="${YOLO_MODE:-false}"
MAX_RETRIES="${MAX_RETRIES:-3}"
ARTIFACTS_DIR="${ARTIFACTS_DIR:-./Artifacts}"
VERBOSE="${VERBOSE:-false}"
DRY_RUN="${DRY_RUN:-false}"
GENERATE_PAGE_OBJECTS="${GENERATE_PAGE_OBJECTS:-true}"

# AXe UI automation variables
USE_AXE="${USE_AXE:-false}"
DESCRIBE_UI="${DESCRIBE_UI:-false}"
VALIDATE_IDENTIFIERS="${VALIDATE_IDENTIFIERS:-false}"
CAPTURE_BASELINE="${CAPTURE_BASELINE:-false}"
SIMULATOR_NAME=""
APP_PATH=""
BUNDLE_ID=""

# State variables
UI_TESTS_GENERATED=0
PAGE_OBJECTS_GENERATED=0
TEST_PLAN_CREATED=false

# ─────────────────────────────────────────────────────────────────────────────
# Usage
# ─────────────────────────────────────────────────────────────────────────────

show_usage() {
    cat << EOF
UI Test Agent - Generate XCUITest from Flow Definitions

DESCRIPTION:
    Generates XCUITest files from flow definitions (flows.json).
    Creates page objects for reusable view interactions.

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --flows <path>          Flow definitions JSON file (required)
    --type <type>           Filter by flow type: happy, sad, regression
    --generate-test-plan    Create .xctestplan file
    --devices <list>        Device configurations (comma-separated)
    --no-page-objects       Skip page object generation
    --ai-provider <name>    AI provider: cursor, claude, codex, gemini, aider, letta
    --yolo                  Auto-approve AI changes
    --max-retries <n>       Maximum retry attempts (default: 3)
    --artifacts-dir <path>  Output directory for artifacts
    --verbose               Enable verbose output
    --dry-run               Show what would be done without executing

  AXE UI AUTOMATION:
    --use-axe               Enable AXe UI automation
    --describe-ui           Dump view hierarchy before generation
    --validate-identifiers  Validate elements exist via AXe
    --capture-baseline      Screenshot for visual testing
    --simulator-name <name> Simulator to use
    --app-path <path>       Path to .app bundle
    --bundle-id <id>        App bundle identifier

    --help                  Show this help message

TEST GENERATION:
    Flow actions are mapped to XCUITest API calls:
    - tap     → app.buttons["identifier"].tap()
    - input   → app.textFields["identifier"].typeText("value")
    - verify  → XCTAssertTrue(app.staticTexts["identifier"].exists)
    - wait    → app.buttons["identifier"].waitForExistence(timeout: 5)

EXAMPLES:
    # Generate UI tests from flows
    $0 --flows flows.json

    # Only generate happy path tests
    $0 --flows flows.json --type happy

    # Generate with test plan
    $0 --flows flows.json --generate-test-plan

    # Full automation
    $0 --flows flows.json --yolo --ai-provider claude

EXIT CODES:
    0   Success
    10  Build failed after max retries
    11  Misconfiguration
    12  AI provider error

OUTPUT:
    - XCUITest files in UITests directory
    - Page object classes (if enabled)
    - Optional .xctestplan file
EOF
}

# ─────────────────────────────────────────────────────────────────────────────
# Initialization
# ─────────────────────────────────────────────────────────────────────────────

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --flows)
                FLOWS_PATH="${2:-}"
                shift 2
                ;;
            --type)
                FLOW_TYPE="${2:-}"
                shift 2
                ;;
            --generate-test-plan)
                GENERATE_TEST_PLAN="true"
                shift 1
                ;;
            --devices)
                DEVICES="${2:-}"
                shift 2
                ;;
            --no-page-objects)
                GENERATE_PAGE_OBJECTS="false"
                shift 1
                ;;
            --ai-provider)
                AI_PROVIDER="${2:-cursor}"
                shift 2
                ;;
            --yolo)
                YOLO_MODE="true"
                shift 1
                ;;
            --max-retries)
                MAX_RETRIES="${2:-3}"
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
            --use-axe)
                USE_AXE="true"
                shift 1
                ;;
            --describe-ui)
                DESCRIBE_UI="true"
                shift 1
                ;;
            --validate-identifiers)
                VALIDATE_IDENTIFIERS="true"
                shift 1
                ;;
            --capture-baseline)
                CAPTURE_BASELINE="true"
                shift 1
                ;;
            --simulator-name)
                SIMULATOR_NAME="${2:-}"
                shift 2
                ;;
            --app-path)
                APP_PATH="${2:-}"
                shift 2
                ;;
            --bundle-id)
                BUNDLE_ID="${2:-}"
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

initialize() {
    log_section "════════════════════════════════════════"
    log_section "UI Test Agent Starting"
    log_section "════════════════════════════════════════"
    echo "" >&2

    # Validate flows file
    if [ -z "$FLOWS_PATH" ]; then
        log_error "Flows file required. Use --flows <path>"
        exit 11
    fi

    if [ ! -f "$FLOWS_PATH" ]; then
        log_error "Flows file not found: $FLOWS_PATH"
        exit 11
    fi

    # Validate flow JSON
    if ! validate_flow_json "$FLOWS_PATH"; then
        log_error "Invalid flows file"
        exit 11
    fi

    # Setup directories
    setup_logs_dir "$ARTIFACTS_DIR" || {
        log_error "Failed to setup directories"
        exit 11
    }

    # Auto-detect Xcode project
    detect_xcode_project || {
        log_warning "Could not auto-detect Xcode project"
    }

    # Detect UI test target directory
    UI_TEST_TARGET_DIR=$(detect_ui_test_target_dir)
    log_verbose "UI test target directory: $UI_TEST_TARGET_DIR"

    log_info "Configuration:"
    log_info "  Flows: $FLOWS_PATH"
    log_info "  Filter Type: ${FLOW_TYPE:-all}"
    log_info "  UI Test Dir: $UI_TEST_TARGET_DIR"
    log_info "  Generate Page Objects: $GENERATE_PAGE_OBJECTS"
    log_info "  Generate Test Plan: $GENERATE_TEST_PLAN"
    log_info "  AI Provider: $AI_PROVIDER"
    echo "" >&2
}

# ─────────────────────────────────────────────────────────────────────────────
# Flow Processing
# ─────────────────────────────────────────────────────────────────────────────

# Get flows from JSON file (optionally filtered by type)
get_flows() {
    local flows_file="$1"
    local filter_type="${2:-}"

    if ! command -v jq >/dev/null 2>&1; then
        log_error "jq required for flow processing"
        exit 11
    fi

    if [ -n "$filter_type" ]; then
        jq -r ".flows[] | select(.type == \"$filter_type\")" "$flows_file"
    else
        jq -r '.flows[]' "$flows_file"
    fi
}

# Get flow count
get_flow_count() {
    local flows_file="$1"
    local filter_type="${2:-}"

    if ! command -v jq >/dev/null 2>&1; then
        echo "0"
        return
    fi

    if [ -n "$filter_type" ]; then
        jq "[.flows[] | select(.type == \"$filter_type\")] | length" "$flows_file"
    else
        jq '.flows | length' "$flows_file"
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# UI Test Generation
# ─────────────────────────────────────────────────────────────────────────────

# Build AI prompt for UI test generation
build_ui_test_prompt() {
    local flow_json="$1"
    local context="$2"
    local ui_hierarchy_json="${3:-}"

    local ui_section=""
    if [ -n "$ui_hierarchy_json" ]; then
        ui_section="
LIVE_UI_HIERARCHY:
\`\`\`json
$ui_hierarchy_json
\`\`\`

Use the live UI hierarchy to:
1. Verify element identifiers exist in the actual UI
2. Use accurate frame coordinates for element targeting
3. Validate accessibility labels match the running app
4. Generate tests that target real UI elements
"
    fi

    cat << EOF
You are a Swift developer writing XCUITest UI tests.

FLOW DEFINITION:
\`\`\`json
$flow_json
\`\`\`
$ui_section
TASK:
Generate an XCUITest file that implements this flow.

ACTION MAPPING:
- "tap" → app.buttons["identifier"].tap() (or appropriate element type)
- "input" → app.textFields["identifier"].tap(); app.textFields["identifier"].typeText("value")
- "verify" → XCTAssertTrue(app.staticTexts["identifier"].exists) (or waitForExistence)
- "wait" → _ = app.buttons["identifier"].waitForExistence(timeout: 5)

REQUIREMENTS:
1. Import XCTest
2. Create a class extending XCTestCase
3. Setup app launch in setUpWithError()
4. Use descriptive test method names
5. Add waitForExistence for elements that may not be immediately available
6. Handle both success and failure scenarios
7. Use appropriate element types (buttons, textFields, staticTexts, etc.)

TEMPLATE:
\`\`\`swift
import XCTest

class FeatureUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    func testUI_flowName_expectedBehavior() throws {
        // Test implementation
    }
}
\`\`\`

REFERENCE DOCUMENTATION:
$context

OUTPUT:
Generate ONLY the Swift test file. No explanations.
EOF
}

# Prepare simulator with AXe if enabled
prepare_axe_environment() {
    if [ "$USE_AXE" != "true" ]; then
        return 0
    fi

    log_section "Preparing AXe environment"

    # Check AXe availability
    if ! is_axe_available; then
        log_warning "AXe not installed. Install with: brew tap cameroncooke/axe && brew install axe"
        log_warning "Falling back to XCUITest generation without live validation"
        return 1
    fi

    # Validate required parameters
    if [ -z "$SIMULATOR_NAME" ] || [ -z "$APP_PATH" ] || [ -z "$BUNDLE_ID" ]; then
        log_error "AXe requires --simulator-name, --app-path, and --bundle-id"
        return 1
    fi

    # Prepare simulator
    log_info "Preparing simulator: $SIMULATOR_NAME"
    SIMULATOR_UDID=$(prepare_simulator_for_testing "$SIMULATOR_NAME" "$APP_PATH" "$BUNDLE_ID") || {
        log_error "Failed to prepare simulator"
        return 1
    }

    # Wait for app to launch
    sleep 2

    # Always get UI hierarchy when using AXe
    log_info "Capturing UI hierarchy..."
    local ui_hierarchy="${ARTIFACTS_DIR}/ui_hierarchy.json"
    mkdir -p "$(dirname "$ui_hierarchy")"

    JSON_OUTPUT=false axe_describe_ui "$SIMULATOR_UDID" > "$ui_hierarchy" || {
        log_error "Failed to capture UI hierarchy - cannot generate accurate tests"
        return 1
    }
    log_success "UI hierarchy saved: $ui_hierarchy"

    # Capture baseline screenshot if requested
    if [ "$CAPTURE_BASELINE" = "true" ]; then
        log_info "Capturing baseline screenshot..."
        local screenshot="${ARTIFACTS_DIR}/baseline_screenshot.png"
        mkdir -p "$(dirname "$screenshot")"

        JSON_OUTPUT=false axe_screenshot "$SIMULATOR_UDID" "$screenshot" || {
            log_warning "Failed to capture screenshot"
        }
    fi

    return 0
}

# Validate element identifiers using AXe
validate_element_identifiers() {
    local test_file="$1"

    if [ "$USE_AXE" != "true" ]; then
        return 0
    fi

    if ! is_axe_available; then
        return 0
    fi

    log_info "Validating element identifiers via AXe..."

    # Extract accessibility identifiers from test file
    local identifiers
    identifiers=$(grep -oE '\["[^"]+"\]' "$test_file" | sed 's/\["\(.*\)"\]/\1/g' | sort -u)

    local invalid_count=0
    local valid_count=0
    while IFS= read -r identifier; do
        if [ -z "$identifier" ]; then
            continue
        fi

        # Check if element exists
        if ! JSON_OUTPUT=false axe_element_exists "$SIMULATOR_UDID" "$identifier" 2>/dev/null; then
            log_warning "Element identifier not found in UI: $identifier"
            invalid_count=$((invalid_count + 1))
        else
            valid_count=$((valid_count + 1))
        fi
    done <<< "$identifiers"

    log_info "Validation results: $valid_count valid, $invalid_count invalid"
    if [ $invalid_count -gt 0 ]; then
        log_warning "Found $invalid_count invalid identifiers. Consider updating test or app accessibility labels."
    else
        log_success "All identifiers validated successfully"
    fi

    return 0
}

# Generate UI test for a flow
generate_ui_test_for_flow() {
    local flow_json="$1"
    local retry_count=0

    # Extract flow name and feature
    local flow_name
    local feature_name
    flow_name=$(echo "$flow_json" | jq -r '.name' | tr ' ' '_' | tr -cd '[:alnum:]_')
    feature_name=$(echo "$flow_json" | jq -r '.feature // "General"' | tr ' ' '_' | tr -cd '[:alnum:]_')

    log_section "Generating UI test: ${feature_name}_${flow_name}"

    # Gather context
    local context
    context=$(gather_test_context "${UI_TEST_CONTEXT_PATHS[@]}")

    # Load UI hierarchy if available
    local ui_hierarchy_json=""
    if [ -f "${ARTIFACTS_DIR}/ui_hierarchy.json" ]; then
        ui_hierarchy_json=$(cat "${ARTIFACTS_DIR}/ui_hierarchy.json")
    fi

    # Build prompt
    local prompt
    prompt=$(build_ui_test_prompt "$flow_json" "$context" "$ui_hierarchy_json")

    # Determine test file path
    local test_file="${UI_TEST_TARGET_DIR}/${feature_name}UITests.swift"

    if [ "$DRY_RUN" = "true" ]; then
        log_info "[DRY RUN] Would generate: $test_file"
        return 0
    fi

    # Retry loop
    while [ $retry_count -lt $MAX_RETRIES ]; do
        retry_count=$((retry_count + 1))
        log_info "Attempt $retry_count/$MAX_RETRIES"

        # Generate via AI
        local ai_output_file="${LOGS_DIR}/ai_uitest_${feature_name}_${retry_count}.txt"

        if ! run_ai_cli "$prompt" --provider "$AI_PROVIDER" --output "$ai_output_file"; then
            log_error "AI generation failed"
            if [ $retry_count -lt $MAX_RETRIES ]; then
                continue
            fi
            return 12
        fi

        # Extract Swift code
        local generated_code
        generated_code=$(cat "$ai_output_file")
        generated_code=$(echo "$generated_code" | sed '/^```swift$/d' | sed '/^```$/d')

        # Write test file
        mkdir -p "$(dirname "$test_file")"
        echo "$generated_code" > "$test_file"
        log_success "Generated: $test_file"

        # Verify build
        log_info "Verifying build..."
        if run_build_lint --logs-dir "$LOGS_DIR"; then
            log_success "Build verification passed"
            UI_TESTS_GENERATED=$((UI_TESTS_GENERATED + 1))
            return 0
        else
            log_warning "Build failed, extracting errors..."

            local error_log="${LOGS_DIR}/error.log"
            if [ -f "$error_log" ]; then
                local errors
                errors=$(cat "$error_log")

                prompt="The UI test had build errors:

$errors

Fix the following test:
\`\`\`swift
$generated_code
\`\`\`

Original flow:
\`\`\`json
$flow_json
\`\`\`

Generate the corrected test file."

                rm -f "$error_log"
            fi
        fi
    done

    log_error "Failed to generate UI test after $MAX_RETRIES attempts"
    return 10
}

# ─────────────────────────────────────────────────────────────────────────────
# Page Object Generation
# ─────────────────────────────────────────────────────────────────────────────

# Build prompt for page object generation
build_page_object_prompt() {
    local flow_json="$1"

    cat << EOF
You are a Swift developer creating Page Object classes for XCUITest.

FLOW DEFINITIONS:
\`\`\`json
$flow_json
\`\`\`

TASK:
Create Page Object classes that encapsulate view interactions.
Each page object represents a screen/view in the app.

TEMPLATE:
\`\`\`swift
import XCTest

class ScreenNamePage {
    let app: XCUIApplication

    init(app: XCUIApplication) {
        self.app = app
    }

    // MARK: - Elements

    var elementName: XCUIElement {
        app.buttons["accessibility-identifier"]
    }

    // MARK: - Actions

    func tapElement() {
        elementName.tap()
    }

    // MARK: - Verifications

    func verifyElementExists() -> Bool {
        elementName.waitForExistence(timeout: 5)
    }
}
\`\`\`

REQUIREMENTS:
1. Extract unique screens/views from the flows
2. Create computed properties for each element
3. Create action methods for common interactions
4. Create verification methods for assertions
5. Use waitForExistence for reliability
6. Use appropriate XCUIElement types

OUTPUT:
Generate the Swift page object file(s). No explanations.
EOF
}

# Generate page objects from flows
generate_page_objects() {
    if [ "$GENERATE_PAGE_OBJECTS" = "false" ]; then
        log_verbose "Page object generation disabled"
        return 0
    fi

    log_section "Generating page objects..."

    # Read all flows
    local all_flows
    all_flows=$(cat "$FLOWS_PATH")

    # Build prompt
    local prompt
    prompt=$(build_page_object_prompt "$all_flows")

    if [ "$DRY_RUN" = "true" ]; then
        log_info "[DRY RUN] Would generate page objects"
        return 0
    fi

    local ai_output_file="${LOGS_DIR}/ai_page_objects.txt"

    if ! run_ai_cli "$prompt" --provider "$AI_PROVIDER" --output "$ai_output_file"; then
        log_warning "Page object generation failed"
        return 0  # Non-fatal
    fi

    # Write page objects
    local page_objects_dir="${UI_TEST_TARGET_DIR}/PageObjects"
    mkdir -p "$page_objects_dir"

    local generated_code
    generated_code=$(cat "$ai_output_file")
    generated_code=$(echo "$generated_code" | sed '/^```swift$/d' | sed '/^```$/d')

    echo "$generated_code" > "${page_objects_dir}/Pages.swift"
    log_success "Generated: ${page_objects_dir}/Pages.swift"

    PAGE_OBJECTS_GENERATED=1
    return 0
}

# ─────────────────────────────────────────────────────────────────────────────
# Test Plan Generation
# ─────────────────────────────────────────────────────────────────────────────

generate_test_plan() {
    if [ "$GENERATE_TEST_PLAN" = "false" ]; then
        return 0
    fi

    log_section "Generating test plan..."

    local test_plan_path="${UI_TEST_TARGET_DIR}/UITests.xctestplan"

    # Parse devices
    local configurations="[]"
    if [ -n "$DEVICES" ]; then
        IFS=',' read -ra device_list <<< "$DEVICES"
        configurations="["
        local first=true
        for device in "${device_list[@]}"; do
            if [ "$first" = true ]; then
                first=false
            else
                configurations+=","
            fi
            configurations+="{\"name\": \"$device\"}"
        done
        configurations+="]"
    fi

    if [ "$DRY_RUN" = "true" ]; then
        log_info "[DRY RUN] Would generate test plan: $test_plan_path"
        return 0
    fi

    # Generate test plan JSON
    cat > "$test_plan_path" << EOF
{
  "configurations" : [
    {
      "id" : "$(uuidgen 2>/dev/null || echo "default-config")",
      "name" : "Test Scheme Action",
      "options" : {

      }
    }
  ],
  "defaultOptions" : {
    "targetForVariableExpansion" : {
      "containerPath" : "container:",
      "identifier" : "UITests",
      "name" : "UITests"
    }
  },
  "testTargets" : [
    {
      "target" : {
        "containerPath" : "container:",
        "identifier" : "UITests",
        "name" : "UITests"
      }
    }
  ],
  "version" : 1
}
EOF

    log_success "Generated test plan: $test_plan_path"
    TEST_PLAN_CREATED=true
    return 0
}

# ─────────────────────────────────────────────────────────────────────────────
# Report Generation
# ─────────────────────────────────────────────────────────────────────────────

generate_ui_test_report() {
    log_section "Generating UI test report..."

    local report_data="<div class='section'>
        <h2>UI Test Generation Results</h2>
        <table>
            <tr><th>Metric</th><th>Value</th></tr>
            <tr><td>UI Tests Generated</td><td>${UI_TESTS_GENERATED}</td></tr>
            <tr><td>Page Objects Generated</td><td>${PAGE_OBJECTS_GENERATED}</td></tr>
            <tr><td>Test Plan Created</td><td>${TEST_PLAN_CREATED}</td></tr>
            <tr><td>Flow Filter</td><td>${FLOW_TYPE:-all}</td></tr>
        </table>
    </div>

    <div class='section'>
        <h2>Generated Files</h2>
        <ul>
            <li>UI Tests: ${UI_TEST_TARGET_DIR}/</li>
            $([ "$PAGE_OBJECTS_GENERATED" -gt 0 ] && echo "<li>Page Objects: ${UI_TEST_TARGET_DIR}/PageObjects/</li>")
            $([ "$TEST_PLAN_CREATED" = true ] && echo "<li>Test Plan: ${UI_TEST_TARGET_DIR}/UITests.xctestplan</li>")
        </ul>
    </div>"

    generate_report \
        --title "UI Test Agent Report" \
        --format html \
        --output "${ARTIFACTS_RUN_DIR}/ui_test_report.html" \
        --data "$report_data"

    # JSON report
    local json_data="{
        \"uiTestsGenerated\": $UI_TESTS_GENERATED,
        \"pageObjectsGenerated\": $PAGE_OBJECTS_GENERATED,
        \"testPlanCreated\": $TEST_PLAN_CREATED,
        \"flowFilter\": \"${FLOW_TYPE:-all}\"
    }"

    generate_report \
        --title "UI Test Results" \
        --format json \
        --output "${ARTIFACTS_RUN_DIR}/ui_test_results.json" \
        --data "$json_data"
}

# ─────────────────────────────────────────────────────────────────────────────
# Main Execution
# ─────────────────────────────────────────────────────────────────────────────

main() {
    parse_arguments "$@"
    initialize

    # Prepare AXe environment if enabled
    if [ "$USE_AXE" = "true" ]; then
        prepare_axe_environment || {
            log_warning "AXe environment preparation failed, continuing without AXe"
            USE_AXE="false"
        }
    fi

    local exit_code=0

    # Get flow count
    local flow_count
    flow_count=$(get_flow_count "$FLOWS_PATH" "$FLOW_TYPE")
    log_info "Processing $flow_count flows"

    if [ "$flow_count" -eq 0 ]; then
        log_warning "No flows to process"
        exit 0
    fi

    # Generate UI tests for each flow
    while IFS= read -r flow_json; do
        [ -z "$flow_json" ] && continue

        if ! generate_ui_test_for_flow "$flow_json"; then
            exit_code=10
            # Continue with other flows
        fi
    done < <(if [ -n "$FLOW_TYPE" ]; then
        jq -c ".flows[] | select(.type == \"$FLOW_TYPE\")" "$FLOWS_PATH"
    else
        jq -c '.flows[]' "$FLOWS_PATH"
    fi)

    # Generate page objects
    generate_page_objects

    # Generate test plan
    generate_test_plan

    # Generate report
    generate_ui_test_report

    # Final status
    echo "" >&2
    log_section "════════════════════════════════════════"
    if [ $exit_code -eq 0 ]; then
        log_success "UI Test Agent Complete!"
        log_info "UI tests generated: $UI_TESTS_GENERATED"
        log_info "Page objects: $PAGE_OBJECTS_GENERATED"
        log_info "Test plan: $TEST_PLAN_CREATED"
        write_success_log "UI tests generated successfully" "Tests: $UI_TESTS_GENERATED"
    else
        log_error "UI Test Agent completed with errors"
        write_error_log "UI test generation had failures"
    fi
    log_section "════════════════════════════════════════"
    echo "" >&2

    log_info "Output: $UI_TEST_TARGET_DIR"
    log_info "Artifacts: ${ARTIFACTS_RUN_DIR}"

    exit $exit_code
}

main "$@"
