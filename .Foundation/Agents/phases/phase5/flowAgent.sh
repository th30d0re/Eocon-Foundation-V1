#!/bin/bash

# Flow Agent
# Analyzes SwiftUI navigation structure and generates flow definitions
# Based on Foundation methodology and BuildAgent patterns
#
# Exit Codes:
#   0  - Success
#   10 - Analysis failed
#   11 - Misconfiguration
#   12 - AI provider error

set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"

# Source utility libraries
# shellcheck disable=SC1091
source "${LIB_DIR}/testUtils.sh"
# shellcheck disable=SC1091
source "${LIB_DIR}/testContextPaths.sh"

# Set log prefix for this agent
LOG_PREFIX="[FLOW]"

# Configuration variables
PROJECT_PATH=""
FEATURE_NAME=""
OUTPUT_PATH=""
OUTPUT_FORMAT="${OUTPUT_FORMAT:-json}"  # json or markdown
AI_PROVIDER="${AI_PROVIDER:-cursor}"
ARTIFACTS_DIR="${ARTIFACTS_DIR:-./Artifacts}"
VERBOSE="${VERBOSE:-false}"
DRY_RUN="${DRY_RUN:-false}"

# State variables
FLOWS_DETECTED=0
HAPPY_PATHS=0
SAD_PATHS=0
REGRESSION_PATHS=0

# ─────────────────────────────────────────────────────────────────────────────
# Usage
# ─────────────────────────────────────────────────────────────────────────────

show_usage() {
    cat << EOF
Flow Agent - Navigation Flow Analysis

DESCRIPTION:
    Analyzes SwiftUI navigation structure and generates flow definitions
    for UI testing. Identifies happy paths, sad paths, and regression scenarios.

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --project <path>        Xcode project/workspace (auto-detect if not provided)
    --feature <name>        Focus on specific feature/module
    --output <path>         Output file path (default: flows.json in artifacts)
    --format <type>         Output format: json (default) or markdown
    --ai-provider <name>    AI provider: cursor, claude, codex, gemini, aider, letta
    --artifacts-dir <path>  Output directory for artifacts
    --verbose               Enable verbose output
    --dry-run               Show what would be done without executing
    --help                  Show this help message

FLOW TYPES:
    happy       Normal user journeys with successful outcomes
    sad         Error conditions, validation failures, edge cases
    regression  Previously broken flows, critical business logic

FLOW JSON SCHEMA:
    {
      "flows": [
        {
          "name": "Flow Name",
          "type": "happy|sad|regression",
          "feature": "Feature Name",
          "steps": [
            {
              "action": "tap|input|verify|wait",
              "element": "accessibility-identifier",
              "input": "optional input value",
              "state": "expected state after action"
            }
          ]
        }
      ]
    }

EXAMPLES:
    # Analyze all navigation flows
    $0

    # Focus on authentication feature
    $0 --feature Authentication

    # Output to specific file
    $0 --output ./flows.json

    # Generate markdown format
    $0 --format markdown --output ./flows.md

EXIT CODES:
    0   Success
    10  Analysis failed
    11  Misconfiguration
    12  AI provider error

OUTPUT:
    - flows.json with structured flow definitions
    - Optional flows.md for human-readable format
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
            --feature)
                FEATURE_NAME="${2:-}"
                shift 2
                ;;
            --output)
                OUTPUT_PATH="${2:-}"
                shift 2
                ;;
            --format)
                OUTPUT_FORMAT="${2:-json}"
                shift 2
                ;;
            --ai-provider)
                AI_PROVIDER="${2:-cursor}"
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
    log_section "Flow Agent Starting"
    log_section "════════════════════════════════════════"
    echo "" >&2

    # Setup directories
    setup_logs_dir "$ARTIFACTS_DIR" || {
        log_error "Failed to setup directories"
        exit 11
    }

    # Set default output path
    if [ -z "$OUTPUT_PATH" ]; then
        if [ "$OUTPUT_FORMAT" = "markdown" ]; then
            OUTPUT_PATH="${ARTIFACTS_RUN_DIR}/flows.md"
        else
            OUTPUT_PATH="${ARTIFACTS_RUN_DIR}/flows.json"
        fi
    fi

    # Auto-detect Xcode project
    if [ -z "$PROJECT_PATH" ]; then
        detect_xcode_project || {
            log_warning "Could not auto-detect Xcode project"
        }
    fi

    log_info "Configuration:"
    log_info "  Project: ${XCODE_WORKSPACE:-${XCODE_PROJECT:-auto-detect}}"
    log_info "  Feature: ${FEATURE_NAME:-all}"
    log_info "  Output: $OUTPUT_PATH"
    log_info "  Format: $OUTPUT_FORMAT"
    log_info "  AI Provider: $AI_PROVIDER"
    echo "" >&2
}

# ─────────────────────────────────────────────────────────────────────────────
# Navigation Analysis
# ─────────────────────────────────────────────────────────────────────────────

# Find navigation-related Swift files
find_navigation_files() {
    log_section "Finding navigation structures..."

    local nav_files=()

    # Find files with navigation patterns
    while IFS= read -r file; do
        if grep -qE "NavigationLink|NavigationStack|NavigationView|sheet|fullScreenCover|popover|tabItem" "$file" 2>/dev/null; then
            nav_files+=("$file")
        fi
    done < <(find_swift_source_files)

    # Also find files with state transitions
    while IFS= read -r file; do
        if ! printf '%s\n' "${nav_files[@]}" | grep -q "^$file$"; then
            if grep -qE "@State|@Published|@Binding|@StateObject|@ObservedObject" "$file" 2>/dev/null; then
                nav_files+=("$file")
            fi
        fi
    done < <(find_swift_source_files)

    if [ ${#nav_files[@]} -eq 0 ]; then
        log_warning "No navigation files found"
        return 1
    fi

    log_info "Found ${#nav_files[@]} files with navigation/state patterns"
    printf '%s\n' "${nav_files[@]}"
}

# Extract navigation structure from a file
extract_navigation_structure() {
    local file="$1"
    local structure=""

    log_verbose "Extracting navigation from: $file"

    local content
    content=$(cat "$file")

    # Extract NavigationLinks
    local nav_links
    nav_links=$(echo "$content" | grep -E "NavigationLink.*destination:" | head -10 || true)

    # Extract sheets
    local sheets
    sheets=$(echo "$content" | grep -E "\.sheet\(|\.fullScreenCover\(" | head -10 || true)

    # Extract button actions
    local buttons
    buttons=$(echo "$content" | grep -E "Button.*action:" | head -10 || true)

    # Extract state variables
    local states
    states=$(echo "$content" | grep -E "@State|@Published|@Binding" | head -10 || true)

    structure="File: $(basename "$file")

Navigation Links:
$nav_links

Sheets/Covers:
$sheets

Buttons:
$buttons

State Variables:
$states"

    echo "$structure"
}

# ─────────────────────────────────────────────────────────────────────────────
# Flow Generation
# ─────────────────────────────────────────────────────────────────────────────

# Build AI prompt for flow analysis
build_flow_prompt() {
    local navigation_info="$1"
    local context="$2"

    cat << EOF
You are a QA engineer analyzing a SwiftUI app for test automation.

NAVIGATION STRUCTURE:
$navigation_info

TASK:
Analyze the navigation structure and generate comprehensive test flows.
Identify user journeys through the app, categorizing them as:
- happy: Normal successful user journeys
- sad: Error conditions, validation failures, edge cases
- regression: Critical paths that must always work

For each flow, define step-by-step actions using:
- tap: Tap on an element (use accessibility identifier)
- input: Enter text in a field
- verify: Check that an element exists or has expected state
- wait: Wait for an element or condition

OUTPUT FORMAT (JSON):
{
  "flows": [
    {
      "name": "Descriptive flow name",
      "type": "happy|sad|regression",
      "feature": "Feature area",
      "description": "What this flow tests",
      "steps": [
        {
          "action": "tap|input|verify|wait",
          "element": "accessibility-identifier",
          "input": "value for input actions",
          "state": "expected state description"
        }
      ]
    }
  ]
}

REFERENCE DOCUMENTATION:
$context

REQUIREMENTS:
1. Generate at least 3 happy path flows
2. Generate at least 2 sad path flows
3. Generate at least 1 regression flow
4. Use descriptive kebab-case identifiers for elements
5. Each flow should have 3-10 steps
6. Include verification steps after key actions

OUTPUT ONLY VALID JSON. No explanations.
EOF
}

# Generate flows using AI
generate_flows() {
    log_section "Generating flow definitions..."

    # Collect navigation information from all files
    local nav_info=""
    local nav_files
    nav_files=$(find_navigation_files) || {
        log_error "No navigation structures found"
        return 10
    }

    while IFS= read -r file; do
        [ -z "$file" ] && continue
        local file_structure
        file_structure=$(extract_navigation_structure "$file")
        nav_info+="$file_structure

"
    done <<< "$nav_files"

    # Filter by feature if specified
    if [ -n "$FEATURE_NAME" ]; then
        log_info "Filtering for feature: $FEATURE_NAME"
        nav_info=$(echo "$nav_info" | grep -A 50 -i "$FEATURE_NAME" || echo "$nav_info")
    fi

    # Gather context
    local context
    context=$(gather_test_context "${NAVIGATION_CONTEXT_PATHS[@]}")

    # Build prompt
    local prompt
    prompt=$(build_flow_prompt "$nav_info" "$context")

    if [ "$DRY_RUN" = "true" ]; then
        log_info "[DRY RUN] Would generate flows to: $OUTPUT_PATH"
        log_verbose "Prompt length: ${#prompt} chars"
        return 0
    fi

    # Generate via AI
    local ai_output_file="${LOGS_DIR}/ai_flows.txt"

    if ! run_ai_cli "$prompt" --provider "$AI_PROVIDER" --output "$ai_output_file"; then
        log_error "AI flow generation failed"
        return 12
    fi

    # Extract JSON from response
    local flows_json
    flows_json=$(cat "$ai_output_file")

    # Clean up (remove markdown code blocks if present)
    flows_json=$(echo "$flows_json" | sed '/^```json$/d' | sed '/^```$/d')

    # Validate JSON
    if command -v jq >/dev/null 2>&1; then
        if ! echo "$flows_json" | jq empty 2>/dev/null; then
            log_error "Generated flows are not valid JSON"
            echo "$flows_json" > "${LOGS_DIR}/invalid_flows.txt"
            return 10
        fi

        # Count flows by type
        FLOWS_DETECTED=$(echo "$flows_json" | jq '.flows | length' 2>/dev/null || echo "0")
        HAPPY_PATHS=$(echo "$flows_json" | jq '[.flows[] | select(.type == "happy")] | length' 2>/dev/null || echo "0")
        SAD_PATHS=$(echo "$flows_json" | jq '[.flows[] | select(.type == "sad")] | length' 2>/dev/null || echo "0")
        REGRESSION_PATHS=$(echo "$flows_json" | jq '[.flows[] | select(.type == "regression")] | length' 2>/dev/null || echo "0")
    fi

    # Write output
    mkdir -p "$(dirname "$OUTPUT_PATH")"

    if [ "$OUTPUT_FORMAT" = "markdown" ]; then
        generate_markdown_flows "$flows_json" > "$OUTPUT_PATH"
    else
        echo "$flows_json" | jq '.' > "$OUTPUT_PATH" 2>/dev/null || echo "$flows_json" > "$OUTPUT_PATH"
    fi

    log_success "Flows generated: $OUTPUT_PATH"

    # Also save JSON for UI test agent
    if [ "$OUTPUT_FORMAT" = "markdown" ]; then
        echo "$flows_json" | jq '.' > "${ARTIFACTS_RUN_DIR}/flows.json" 2>/dev/null || echo "$flows_json" > "${ARTIFACTS_RUN_DIR}/flows.json"
    fi

    return 0
}

# Convert flows JSON to markdown
generate_markdown_flows() {
    local json="$1"

    echo "# Test Flows"
    echo ""
    echo "Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    echo ""

    if ! command -v jq >/dev/null 2>&1; then
        echo "## Raw JSON"
        echo '```json'
        echo "$json"
        echo '```'
        return
    fi

    # Group by type
    for flow_type in happy sad regression; do
        local type_flows
        type_flows=$(echo "$json" | jq -r ".flows[] | select(.type == \"$flow_type\")")

        if [ -n "$type_flows" ]; then
            echo "## ${flow_type^} Path Flows"
            echo ""

            echo "$json" | jq -r ".flows[] | select(.type == \"$flow_type\") | \"### \\(.name)\n\n**Feature:** \\(.feature // \"General\")\n\n**Description:** \\(.description // \"No description\")\n\n**Steps:**\n\"" 2>/dev/null

            # Output steps
            echo "$json" | jq -r ".flows[] | select(.type == \"$flow_type\") | .steps[] | \"1. **\\(.action)** \\(.element) \\(if .input then \"with '\" + .input + \"'\" else \"\" end) \\(if .state then \"→ \" + .state else \"\" end)\"" 2>/dev/null

            echo ""
        fi
    done
}

# ─────────────────────────────────────────────────────────────────────────────
# Report Generation
# ─────────────────────────────────────────────────────────────────────────────

generate_flow_report() {
    log_section "Generating flow analysis report..."

    local report_data="<div class='section'>
        <h2>Flow Analysis Results</h2>
        <table>
            <tr><th>Metric</th><th>Value</th></tr>
            <tr><td>Total Flows</td><td>${FLOWS_DETECTED}</td></tr>
            <tr><td>Happy Paths</td><td class='success'>${HAPPY_PATHS}</td></tr>
            <tr><td>Sad Paths</td><td class='warning'>${SAD_PATHS}</td></tr>
            <tr><td>Regression Paths</td><td>${REGRESSION_PATHS}</td></tr>
        </table>
    </div>

    <div class='section'>
        <h2>Output</h2>
        <p>Flow definitions saved to: <code>$OUTPUT_PATH</code></p>
    </div>"

    generate_report \
        --title "Flow Analysis Report" \
        --format html \
        --output "${ARTIFACTS_RUN_DIR}/flow_report.html" \
        --data "$report_data"

    # Generate JSON summary
    local json_data="{
        \"totalFlows\": $FLOWS_DETECTED,
        \"happyPaths\": $HAPPY_PATHS,
        \"sadPaths\": $SAD_PATHS,
        \"regressionPaths\": $REGRESSION_PATHS,
        \"outputPath\": \"$OUTPUT_PATH\"
    }"

    generate_report \
        --title "Flow Analysis" \
        --format json \
        --output "${ARTIFACTS_RUN_DIR}/flow_summary.json" \
        --data "$json_data"
}

# ─────────────────────────────────────────────────────────────────────────────
# Main Execution
# ─────────────────────────────────────────────────────────────────────────────

main() {
    parse_arguments "$@"
    initialize

    local exit_code=0

    # Generate flows
    if ! generate_flows; then
        exit_code=$?
    fi

    # Validate generated flows
    if [ -f "$OUTPUT_PATH" ] && [ "$OUTPUT_FORMAT" = "json" ]; then
        validate_flow_json "$OUTPUT_PATH" || {
            log_warning "Flow validation had issues"
        }
    fi

    # Generate report
    generate_flow_report

    # Final status
    echo "" >&2
    log_section "════════════════════════════════════════"
    if [ $exit_code -eq 0 ]; then
        log_success "Flow Agent Complete!"
        log_info "Flows detected: $FLOWS_DETECTED"
        log_info "  Happy paths: $HAPPY_PATHS"
        log_info "  Sad paths: $SAD_PATHS"
        log_info "  Regression: $REGRESSION_PATHS"
        write_success_log "Flow analysis completed" "Flows: $FLOWS_DETECTED (happy: $HAPPY_PATHS, sad: $SAD_PATHS, regression: $REGRESSION_PATHS)"
    else
        log_error "Flow Agent failed"
        write_error_log "Flow analysis failed"
    fi
    log_section "════════════════════════════════════════"
    echo "" >&2

    log_info "Output: $OUTPUT_PATH"
    log_info "Artifacts: ${ARTIFACTS_RUN_DIR}"

    exit $exit_code
}

main "$@"
