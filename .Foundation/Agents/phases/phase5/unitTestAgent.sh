#!/bin/bash

# Unit Test Agent
# Generates unit tests for Swift source files using AI
# Based on Foundation methodology and BuildAgent patterns
#
# Exit Codes:
#   0  - Success
#   10 - Build/test failed after max retries
#   11 - Misconfiguration
#   12 - AI provider error

set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"
TEMPLATES_DIR="${SCRIPT_DIR}/templates"

# Source utility libraries
# shellcheck disable=SC1091
source "${LIB_DIR}/testUtils.sh"
# shellcheck disable=SC1091
source "${LIB_DIR}/testContextPaths.sh"

# Set log prefix for this agent
LOG_PREFIX="[UNIT-TEST]"

# Configuration variables
PROJECT_PATH=""
SCHEME=""
FILES_PATTERN=""
FRAMEWORK="${FRAMEWORK:-xctest}"  # xctest or swift-testing
TARGET_COVERAGE="${TARGET_COVERAGE:-80}"
MAX_RETRIES="${MAX_RETRIES:-3}"
AI_PROVIDER="${AI_PROVIDER:-cursor}"
YOLO_MODE="${YOLO_MODE:-false}"
ARTIFACTS_DIR="${ARTIFACTS_DIR:-./Artifacts}"
VERBOSE="${VERBOSE:-false}"
DRY_RUN="${DRY_RUN:-false}"
STREAM_OUTPUT="${STREAM_OUTPUT:-false}"

# State variables
CURRENT_RETRY=0
TESTS_GENERATED=0
COVERAGE_ACHIEVED=0

# ─────────────────────────────────────────────────────────────────────────────
# Usage
# ─────────────────────────────────────────────────────────────────────────────

show_usage() {
    cat << EOF
Unit Test Agent - AI-Powered Unit Test Generation

DESCRIPTION:
    Generates unit tests for Swift source files using AI, with automatic
    build verification and retry loops.

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --project <path>        Xcode project/workspace (auto-detect if not provided)
    --scheme <name>         Target scheme (auto-detect if not provided)
    --files <pattern>       Specific files to test (glob pattern)
    --framework <name>      Testing framework: xctest (default) or swift-testing
    --target-coverage <n>   Target coverage percentage (default: 80)
    --max-retries <n>       Maximum retry attempts for build failures (default: 3)
    --ai-provider <name>    AI provider: cursor, claude, codex, gemini, aider, letta
    --yolo                  Auto-approve AI changes (unattended mode)
    --artifacts-dir <path>  Output directory for artifacts
    --verbose               Enable verbose output
    --dry-run               Show what would be done without executing
    --stream                Stream AI output in real-time
    --help                  Show this help message

EXAMPLES:
    # Basic usage with auto-detection
    $0

    # Specific project and scheme
    $0 --project MyApp.xcodeproj --scheme MyApp

    # Target specific files
    $0 --files "Sources/Models/*.swift"

    # Use Swift Testing framework
    $0 --framework swift-testing

    # Full automation mode
    $0 --yolo --ai-provider claude --max-retries 5

EXIT CODES:
    0   Success
    10  Build/test failed after max retries
    11  Misconfiguration
    12  AI provider error

OUTPUT:
    - Generated test files in test target directory
    - Coverage report in artifacts directory
    - Build and error logs
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
            --files)
                FILES_PATTERN="${2:-}"
                shift 2
                ;;
            --framework)
                FRAMEWORK="${2:-xctest}"
                shift 2
                ;;
            --target-coverage)
                TARGET_COVERAGE="${2:-80}"
                shift 2
                ;;
            --max-retries)
                MAX_RETRIES="${2:-3}"
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
            --stream)
                STREAM_OUTPUT="true"
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
    log_section "Unit Test Agent Starting"
    log_section "════════════════════════════════════════"
    echo "" >&2

    # Setup directories
    setup_logs_dir "$ARTIFACTS_DIR" || {
        log_error "Failed to setup directories"
        exit 11
    }

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

    # Detect test target directory
    TEST_TARGET_DIR=$(detect_test_target_dir)
    log_verbose "Test target directory: $TEST_TARGET_DIR"

    log_info "Configuration:"
    log_info "  Project: ${XCODE_WORKSPACE:-${XCODE_PROJECT:-auto-detect}}"
    log_info "  Scheme: ${SCHEME:-auto-detect}"
    log_info "  Framework: $FRAMEWORK"
    log_info "  Target Coverage: ${TARGET_COVERAGE}%"
    log_info "  Max Retries: $MAX_RETRIES"
    log_info "  AI Provider: $AI_PROVIDER"
    log_info "  Test Target: $TEST_TARGET_DIR"
    echo "" >&2
}

# ─────────────────────────────────────────────────────────────────────────────
# Source Analysis
# ─────────────────────────────────────────────────────────────────────────────

# Find source files to generate tests for
find_source_files() {
    log_section "Finding source files..."

    local source_files=()

    if [ -n "$FILES_PATTERN" ]; then
        # Use provided pattern
        while IFS= read -r file; do
            source_files+=("$file")
        done < <(find . -name "$FILES_PATTERN" -type f 2>/dev/null)
    else
        # Find all Swift source files
        while IFS= read -r file; do
            source_files+=("$file")
        done < <(find_swift_source_files)
    fi

    if [ ${#source_files[@]} -eq 0 ]; then
        log_warning "No source files found"
        return 1
    fi

    log_info "Found ${#source_files[@]} source files"
    echo "${source_files[@]}"
}

# Analyze source file for testable components
analyze_source_file() {
    local file="$1"
    local analysis=""

    log_verbose "Analyzing: $file"

    # Read file content
    local content
    content=$(cat "$file")

    # Extract class/struct names
    local types
    types=$(echo "$content" | grep -E "^(class|struct|enum|actor)\s+\w+" | sed 's/[:{].*$//' || true)

    # Extract function signatures
    local functions
    functions=$(echo "$content" | grep -E "^\s*func\s+\w+" | head -20 || true)

    analysis="File: $file
Types: $types
Functions: $functions"

    echo "$analysis"
}

# ─────────────────────────────────────────────────────────────────────────────
# Test Generation
# ─────────────────────────────────────────────────────────────────────────────

# Build AI prompt for test generation
build_test_prompt() {
    local source_file="$1"
    local source_content="$2"
    local context="$3"

    local framework_instructions=""
    if [ "$FRAMEWORK" = "swift-testing" ]; then
        framework_instructions="Use the Swift Testing framework (@Test macro, #expect assertions).
Import Testing framework at the top of the file.
Use @Suite for grouping related tests.
Example:
import Testing

@Suite struct MyTests {
    @Test func testExample() {
        #expect(result == expected)
    }
}"
    else
        framework_instructions="Use XCTest framework (XCTestCase, XCTAssert assertions).
Import XCTest at the top of the file.
Subclass XCTestCase for test classes.
Example:
import XCTest
@testable import ModuleName

class MyTests: XCTestCase {
    func testExample() throws {
        XCTAssertEqual(result, expected)
    }
}"
    fi

    cat << EOF
You are a Swift developer writing comprehensive unit tests.

TASK:
Generate unit tests for the following Swift source file.

SOURCE FILE: $(basename "$source_file")
\`\`\`swift
$source_content
\`\`\`

TESTING FRAMEWORK:
$framework_instructions

REQUIREMENTS:
1. Test all public functions and methods
2. Include edge cases and error conditions
3. Use descriptive test names: test_functionName_condition_expectedResult
4. Include setup and teardown if needed
5. Mock dependencies where appropriate
6. Target ${TARGET_COVERAGE}% code coverage
7. Follow Apple's testing best practices

REFERENCE DOCUMENTATION:
$context

OUTPUT:
Generate ONLY the test file content. No explanations.
Start with the import statements and end with the closing brace.
EOF
}

# Generate tests for a source file
generate_tests_for_file() {
    local source_file="$1"
    local retry_count=0
    local test_file=""

    log_section "Generating tests for: $(basename "$source_file")"

    # Read source content
    local source_content
    source_content=$(cat "$source_file")

    # Gather context from test documentation
    local context
    context=$(gather_test_context "${UNIT_TEST_CONTEXT_PATHS[@]}")

    # Build prompt
    local prompt
    prompt=$(build_test_prompt "$source_file" "$source_content" "$context")

    # Determine test file path
    local base_name
    base_name=$(basename "$source_file" .swift)
    test_file="${TEST_TARGET_DIR}/${base_name}Tests.swift"

    if [ "$DRY_RUN" = "true" ]; then
        log_info "[DRY RUN] Would generate: $test_file"
        log_verbose "Prompt length: ${#prompt} chars"
        return 0
    fi

    # Retry loop
    while [ $retry_count -lt $MAX_RETRIES ]; do
        retry_count=$((retry_count + 1))
        log_info "Attempt $retry_count/$MAX_RETRIES"

        # Generate tests via AI
        local ai_output_file="${LOGS_DIR}/ai_output_${base_name}_${retry_count}.txt"

        if ! run_ai_cli "$prompt" --provider "$AI_PROVIDER" --output "$ai_output_file"; then
            log_error "AI generation failed"
            if [ $retry_count -lt $MAX_RETRIES ]; then
                log_warning "Retrying..."
                continue
            fi
            return 12
        fi

        # Extract Swift code from AI response
        local generated_code
        generated_code=$(cat "$ai_output_file")

        # Clean up code (remove markdown code blocks if present)
        generated_code=$(echo "$generated_code" | sed '/^```swift$/d' | sed '/^```$/d')

        # Write test file
        mkdir -p "$(dirname "$test_file")"
        echo "$generated_code" > "$test_file"
        log_success "Generated: $test_file"

        # Verify build
        log_info "Verifying build..."
        if run_build_lint --logs-dir "$LOGS_DIR" --scheme "$SCHEME"; then
            log_success "Build verification passed"
            TESTS_GENERATED=$((TESTS_GENERATED + 1))
            return 0
        else
            log_warning "Build failed, extracting errors..."

            # Get error feedback
            local error_log="${LOGS_DIR}/error.log"
            if [ -f "$error_log" ]; then
                local errors
                errors=$(cat "$error_log")

                # Update prompt with error feedback
                prompt="The previous test generation had build errors:

$errors

Please fix the following test file:
\`\`\`swift
$generated_code
\`\`\`

Original source file:
\`\`\`swift
$source_content
\`\`\`

Generate the corrected test file."

                # Clean up error log for next attempt
                rm -f "$error_log"
            fi
        fi
    done

    log_error "Failed to generate valid tests after $MAX_RETRIES attempts"
    write_error_log "Failed to generate tests for: $source_file"
    return 10
}

# ─────────────────────────────────────────────────────────────────────────────
# Test Execution
# ─────────────────────────────────────────────────────────────────────────────

run_tests() {
    log_section "Running tests..."

    if [ "$DRY_RUN" = "true" ]; then
        log_info "[DRY RUN] Would run: xcodebuild test"
        return 0
    fi

    local xcode_arg=""
    if [ -n "${XCODE_WORKSPACE:-}" ]; then
        xcode_arg="-workspace \"$XCODE_WORKSPACE\""
    elif [ -n "${XCODE_PROJECT:-}" ]; then
        xcode_arg="-project \"$XCODE_PROJECT\""
    fi

    local test_cmd="xcodebuild test $xcode_arg"
    [ -n "$SCHEME" ] && test_cmd="$test_cmd -scheme \"$SCHEME\""
    test_cmd="$test_cmd -destination 'platform=iOS Simulator,name=iPhone 15' -enableCodeCoverage YES"

    local test_log="${LOGS_DIR}/test_results.log"

    log_verbose "Running: $test_cmd"

    if eval "$test_cmd" > "$test_log" 2>&1; then
        log_success "Tests passed"
        return 0
    else
        log_error "Tests failed"
        cat "$test_log" >&2
        return 10
    fi
}

# Extract coverage from test results
extract_coverage() {
    log_section "Extracting coverage..."

    # Look for coverage in xcresult bundle
    local xcresult
    xcresult=$(find . -name "*.xcresult" -type d 2>/dev/null | head -1)

    if [ -n "$xcresult" ]; then
        log_verbose "Found xcresult: $xcresult"

        # Use xcrun to extract coverage
        if command -v xcrun >/dev/null 2>&1; then
            local coverage_json="${LOGS_DIR}/coverage.json"
            if xcrun xccov view --report --json "$xcresult" > "$coverage_json" 2>/dev/null; then
                # Extract overall coverage percentage
                if command -v jq >/dev/null 2>&1; then
                    COVERAGE_ACHIEVED=$(jq '.lineCoverage * 100 | floor' "$coverage_json" 2>/dev/null || echo "0")
                    log_info "Code coverage: ${COVERAGE_ACHIEVED}%"
                fi
            fi
        fi
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Report Generation
# ─────────────────────────────────────────────────────────────────────────────

generate_unit_test_report() {
    log_section "Generating report..."

    local report_data="<div class='section'>
        <h2>Unit Test Generation Results</h2>
        <table>
            <tr><th>Metric</th><th>Value</th></tr>
            <tr><td>Tests Generated</td><td>${TESTS_GENERATED}</td></tr>
            <tr><td>Coverage Achieved</td><td>${COVERAGE_ACHIEVED}%</td></tr>
            <tr><td>Target Coverage</td><td>${TARGET_COVERAGE}%</td></tr>
            <tr><td>Framework</td><td>${FRAMEWORK}</td></tr>
            <tr><td>AI Provider</td><td>${AI_PROVIDER}</td></tr>
        </table>
    </div>"

    generate_report \
        --title "Unit Test Agent Report" \
        --format html \
        --output "${ARTIFACTS_RUN_DIR}/unit_test_report.html" \
        --data "$report_data"

    # Also generate JSON report
    local json_data="{
        \"testsGenerated\": $TESTS_GENERATED,
        \"coverageAchieved\": $COVERAGE_ACHIEVED,
        \"targetCoverage\": $TARGET_COVERAGE,
        \"framework\": \"$FRAMEWORK\",
        \"aiProvider\": \"$AI_PROVIDER\"
    }"

    generate_report \
        --title "Unit Test Results" \
        --format json \
        --output "${ARTIFACTS_RUN_DIR}/unit_test_results.json" \
        --data "$json_data"
}

# ─────────────────────────────────────────────────────────────────────────────
# Main Execution
# ─────────────────────────────────────────────────────────────────────────────

main() {
    parse_arguments "$@"
    initialize

    # Find source files
    local source_files
    source_files=$(find_source_files) || {
        log_error "No source files found"
        exit 11
    }

    # Generate tests for each file
    local exit_code=0
    for file in $source_files; do
        if ! generate_tests_for_file "$file"; then
            exit_code=10
            # Continue with other files even if one fails
        fi
    done

    # Run tests if any were generated
    if [ $TESTS_GENERATED -gt 0 ]; then
        if ! run_tests; then
            exit_code=10
        fi
        extract_coverage
    fi

    # Generate report
    generate_unit_test_report

    # Final status
    echo "" >&2
    log_section "════════════════════════════════════════"
    if [ $exit_code -eq 0 ]; then
        log_success "Unit Test Agent Complete!"
        log_info "Tests generated: $TESTS_GENERATED"
        log_info "Coverage: ${COVERAGE_ACHIEVED}%"
        write_success_log "Unit tests generated successfully" "Tests: $TESTS_GENERATED, Coverage: ${COVERAGE_ACHIEVED}%"
    else
        log_error "Unit Test Agent failed"
        write_error_log "Unit test generation failed"
    fi
    log_section "════════════════════════════════════════"
    echo "" >&2

    log_info "Artifacts: ${ARTIFACTS_RUN_DIR}"

    exit $exit_code
}

main "$@"
