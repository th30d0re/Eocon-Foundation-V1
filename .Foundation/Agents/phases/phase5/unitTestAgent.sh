#!/usr/bin/env bash

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
source "${LIB_DIR}/session_store.sh"

# Set log prefix for this agent
LOG_PREFIX="[UNIT-TEST]"

# Configuration variables
PROJECT_PATH=""
SCHEME=""
FILES_PATTERN=""
UNIT_TEST_CONTEXT_PATHS=()
FRAMEWORK="${FRAMEWORK:-xctest}"  # xctest or swift-testing
TARGET_COVERAGE="${TARGET_COVERAGE:-80}"
MAX_RETRIES="${MAX_RETRIES:-3}"
AI_PROVIDER="${AI_PROVIDER:-cursor}"
YOLO_MODE="${YOLO_MODE:-false}"
ARTIFACTS_DIR="${ARTIFACTS_DIR:-./Artifacts}"
VERBOSE="${VERBOSE:-false}"
DRY_RUN="${DRY_RUN:-false}"
STREAM_OUTPUT="${STREAM_OUTPUT:-false}"

# Session integration
USE_SESSION="${USE_SESSION:-false}"
SESSION_SCHEME=""

# Test generation strategy:
#   priority   - happy → sad → regression → coverage (default)
#   coverage   - jump straight to target coverage
#   balanced   - mix all test types in one pass
TEST_STRATEGY="${TEST_STRATEGY:-priority}"

# Provider selection strategy:
#   round-robin        - rotate evenly across providers (default)
#   ucb1               - UCB1 bandit algorithm (learns best provider)
#   thompson           - Thompson sampling (robust, no tuning)
#   epsilon-greedy     - ε-greedy with exponential decay
#   explore-then-commit - random for k pulls, then commit to best
#   auto               - auto-select based on data richness
PROVIDER_STRATEGY="${PROVIDER_STRATEGY:-round-robin}"

# Happy-path-only mode: only generate happy path tests, skip sad/regression/coverage
HAPPY_ONLY="${HAPPY_ONLY:-false}"

# State variables
CURRENT_RETRY=0
TESTS_GENERATED=0
COVERAGE_ACHIEVED=0

# Test type tracking per wave
CURRENT_TEST_WAVE=""

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
    --test-strategy <mode>  Test generation strategy:
                            priority  - happy → sad → regression → coverage (default)
                            coverage  - jump straight to target coverage
                            balanced  - mix all test types in one pass
    --max-retries <n>       Maximum retry attempts for build failures (default: 3)
    --ai-provider <name>    AI provider: cursor, claude, codex, gemini, aider, letta
    --provider-strategy <s> Provider selection: round-robin, ucb1, thompson,
                            epsilon-greedy, explore-then-commit, auto (default: round-robin)
    --yolo                  Auto-approve AI changes (unattended mode)
    --artifacts-dir <path>  Output directory for artifacts
    --verbose               Enable verbose output
    --dry-run               Show what would be done without executing
    --stream                Stream AI output in real-time
    --session               Use session defaults for configuration
    --session-set <k=v>     Set session default (scheme, platform, simulator)
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
            --session)
                USE_SESSION="true"
                shift 1
                ;;
            --test-strategy)
                TEST_STRATEGY="${2:-priority}"
                shift 2
                ;;
            --provider-strategy)
                PROVIDER_STRATEGY="${2:-round-robin}"
                shift 2
                ;;
            --happy-only)
                HAPPY_ONLY="true"
                shift 1
                ;;
            --session-set)
                local kv="${2:-}"
                local key=$(echo "$kv" | cut -d'=' -f1)
                local value=$(echo "$kv" | cut -d'=' -f2-)
                session_set_default "$key" "$value"
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
    log_section "Unit Test Agent Starting"
    log_section "════════════════════════════════════════"
    echo "" >&2

    # Load session defaults if enabled
    if [ "$USE_SESSION" = "true" ]; then
        session_load || true
        SESSION_SCHEME=$(session_get_default "scheme")

        # Apply defaults if not explicitly set
        [ -z "$SCHEME" ] && [ -n "$SESSION_SCHEME" ] && SCHEME="$SESSION_SCHEME"
    fi

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

# Build AI prompt for a specific test type (happy, sad, regression, coverage)
build_test_prompt_for_type() {
    local source_file="$1"
    local source_content="$2"
    local context="$3"
    local test_type="$4"  # happy, sad, regression, coverage

    local type_instructions=""
    local test_prefix=""
    case "$test_type" in
        happy)
            type_instructions="FOCUS: Happy path tests only.
- Test the NORMAL, SUCCESSFUL execution paths
- Use valid inputs and expected outputs
- Verify core functionality works as intended
- Do NOT test errors, edge cases, or invalid inputs in this wave"
            test_prefix="testHappy"
            ;;
        sad)
            type_instructions="FOCUS: Sad path and edge case tests only.
- Test ERROR conditions and exceptions (invalid inputs, nil values, out-of-bounds)
- Test BOUNDARY conditions (empty strings, zero values, max values)
- Test UNEXPECTED states and failure modes
- Verify proper error handling and graceful degradation"
            test_prefix="testSad"
            ;;
        regression)
            type_instructions="FOCUS: Regression tests only.
- Test KNOWN BUGS and previously fixed issues
- Test the EXACT scenarios that have failed in past builds
- Add tests that would have caught previous regressions
- Reference any error patterns from build history"
            test_prefix="testRegression"
            ;;
        coverage)
            type_instructions="FOCUS: Coverage gap filling.
- Target the SPECIFIC lines/branches not yet covered
- Test complex conditional branches (if/else, switch, guard)
- Test private/internal methods that lack coverage
- Aim to reach ${TARGET_COVERAGE}% line coverage"
            test_prefix="test"
            ;;
    esac

    local framework_instructions=""
    if [ "$FRAMEWORK" = "swift-testing" ]; then
        framework_instructions="Use the Swift Testing framework (@Test macro, #expect assertions)."
    else
        framework_instructions="Use XCTest framework (XCTestCase, XCTAssert assertions)."
    fi

    cat << EOF
You are a Swift developer writing focused unit tests.

TASK:
Generate $test_type path unit tests for the following Swift source file.

$type_instructions

SOURCE FILE: $(basename "$source_file")
\`\`\`swift
$source_content
\`\`\`

TESTING FRAMEWORK:
$framework_instructions

REQUIREMENTS:
1. $type_instructions
2. Use descriptive test names: ${test_prefix}_functionName_condition_expectedResult
3. Include setup and teardown if needed
4. Mock dependencies where appropriate
5. Follow Apple's testing best practices

REFERENCE DOCUMENTATION:
$context

OUTPUT:
Generate ONLY the test file content. No explanations.
Start with the import statements and end with the closing brace.
EOF
}

# ─────────────────────────────────────────────────────────────────────────────
# Wave-based prioritized test generation
# ─────────────────────────────────────────────────────────────────────────────

# Run test generation in waves: happy → sad → regression → coverage
# Stops early if target coverage is reached
run_prioritized_generation() {
    local context="$1"
    local source_files="$2"
    local waves=("happy" "sad" "regression" "coverage")
    local wave_descriptions=("Happy path" "Sad path" "Regression" "Coverage expansion")

    # In happy-only mode, only run the happy path wave
    if [ "$HAPPY_ONLY" = "true" ]; then
        waves=("happy")
        wave_descriptions=("Happy path")
        log_info "Happy-only mode: skipping sad/regression/coverage waves"
    fi

    for i in "${!waves[@]}"; do
        local wave="${waves[$i]}"
        local desc="${wave_descriptions[$i]}"
        CURRENT_TEST_WAVE="$wave"

        log_section "════════════════════════════════════════"
        log_section "Test Wave $((i+1))/${#waves[@]}: $desc"
        log_section "════════════════════════════════════════"

        # Check if we've already hit coverage target
        if [ "$COVERAGE_ACHIEVED" -ge "$TARGET_COVERAGE" ] 2>/dev/null; then
            log_success "Target coverage (${TARGET_COVERAGE}%) already reached — skipping remaining waves"
            break
        fi

        # Generate tests for this wave
        if ! generate_tests_for_wave "$context" "$source_files" "$wave"; then
            log_warning "Wave $wave had issues, continuing..."
        fi

        # Build and fix after each wave to get coverage feedback
        if [ $TESTS_GENERATED -gt 0 ] || [ -n "$(find "${TEST_TARGET_DIR}" -name "*Tests.swift" 2>/dev/null)" ]; then
            log_info "Building after $desc wave..."
            if build_and_fix_tests "$context"; then
                # Run tests to check coverage
                if run_tests; then
                    extract_coverage
                    log_info "Coverage after $desc wave: ${COVERAGE_ACHIEVED}%"
                fi
            fi
        fi
    done

    CURRENT_TEST_WAVE=""
}

# Generate tests for a specific wave type
generate_tests_for_wave() {
    local context="$1"
    local source_files="$2"
    local wave="$3"

    # Override the prompt builder temporarily
    local original_prompt_builder=""
    # We can't easily override a function in bash, so we'll modify generate_test_file_only
    # to accept a test_type parameter. For now, use a global variable.
    TEST_GENERATION_WAVE="$wave"

    # Use the same parallel generation but with wave-specific prompts
    generate_tests_parallel "$context" "$source_files"

    TEST_GENERATION_WAVE=""
}

# ─────────────────────────────────────────────────────────────────────────────
# Multi-Provider Parallel Generation
# ─────────────────────────────────────────────────────────────────────────────

# Discover which AI providers are available on this system
discover_available_providers() {
    local providers=()
    if command -v kimi >/dev/null 2>&1; then providers+=("kimi"); fi
    if command -v cursor-agent >/dev/null 2>&1 || command -v cursor >/dev/null 2>&1; then providers+=("cursor"); fi
    if command -v codex >/dev/null 2>&1 || command -v openai >/dev/null 2>&1; then providers+=("codex"); fi
    if command -v gemini >/dev/null 2>&1; then providers+=("gemini"); fi
    # Claude temporarily removed from rotation (user paused account).
    if command -v aider >/dev/null 2>&1; then providers+=("aider"); fi
    if [ ${#providers[@]} -gt 0 ]; then
        printf '%s\n' "${providers[@]}"
    fi
}

# Maximum concurrent jobs per provider (to avoid rate limits)
get_provider_max_slots() {
    case "$1" in
        kimi) echo 2 ;;
        cursor) echo 3 ;;
        codex) echo 3 ;;
        gemini) echo 3 ;;
        # Claude temporarily removed from rotation (user paused account).
        aider) echo 2 ;;
        *) echo 2 ;;
    esac
}

# Get the next provider in round-robin order
get_next_provider() {
    local current="$1"
    local all_providers=()
    while IFS= read -r p; do
        [ -n "$p" ] && all_providers+=("$p")
    done <<< "$(discover_available_providers)"
    if [ ${#all_providers[@]} -le 1 ]; then
        echo "$current"
        return
    fi
    local idx=-1
    for i in "${!all_providers[@]}"; do
        if [ "${all_providers[$i]}" = "$current" ]; then idx=$i; break; fi
    done
    if [ $idx -ge 0 ]; then
        echo "${all_providers[$(((idx + 1) % ${#all_providers[@]}))]}"
    else
        echo "${all_providers[0]}"
    fi
}

# Generate tests for multiple files in parallel, distributing across providers.
# When STREAM_OUTPUT=true, shows real-time progress with per-job status.
generate_tests_parallel() {
    local context="$1"
    local source_files="$2"
    local providers=()
    while IFS= read -r p; do [ -n "$p" ] && providers+=("$p"); done <<< "$(discover_available_providers)"
    if [ ${#providers[@]} -eq 0 ]; then
        log_error "No AI providers found. Install at least one: cursor, codex, gemini, kimi, aider"
        return 12
    fi

    # Categorize files
    local files_needing_tests=()
    local assigned_providers=()
    local skipped_count=0
    local provider_idx=0
    while IFS= read -r file; do
        [ -z "$file" ] && continue
        local base_name=$(basename "$file" .swift)
        local test_file="${TEST_TARGET_DIR}/${base_name}Tests.swift"
        if [ -f "$test_file" ]; then
            skipped_count=$((skipped_count + 1))
            continue
        fi
        files_needing_tests+=("$file")
        assigned_providers+=("${providers[$provider_idx]}")
        provider_idx=$(((provider_idx + 1) % ${#providers[@]}))
    done <<< "$source_files"

    local total_files=${#files_needing_tests[@]}
    log_info "Found ${#providers[@]} provider(s), $skipped_count file(s) already have tests, $total_files need generation"

    if [ $total_files -eq 0 ]; then
        log_info "No new test files needed"
        return 0
    fi

    if [ $total_files -eq 1 ]; then
        log_info "Generating 1 test file (provider: ${assigned_providers[0]})"
    else
        log_info "Generating $total_files test file(s) in parallel across ${#providers[@]} provider(s)"
    fi

    local jobs_dir="${LOGS_DIR}/parallel_jobs"
    mkdir -p "$jobs_dir"
    rm -f "${jobs_dir}"/*
    local active_jobs_dir="${jobs_dir}/active"
    mkdir -p "$active_jobs_dir"
    local spawned=0

    for i in "${!files_needing_tests[@]}"; do
        local file="${files_needing_tests[$i]}"
        local provider="${assigned_providers[$i]}"
        local max_slots=$(get_provider_max_slots "$provider")
        while true; do
            local active_count=0
            for job_file in "${active_jobs_dir}"/*."${provider}"; do
                [ -f "$job_file" ] || continue
                local job_pid=$(basename "$job_file" ".${provider}")
                if kill -0 "$job_pid" 2>/dev/null; then
                    active_count=$((active_count + 1))
                else
                    rm -f "$job_file"
                fi
            done
            if [ "$active_count" -lt "$max_slots" ]; then break; fi
            sleep 0.5
        done
        local base_name=$(basename "$file" .swift)
        local job_log="${jobs_dir}/log_${base_name}_${provider}.txt"
        local success_marker="${jobs_dir}/success_${base_name}"
        local running_marker="${jobs_dir}/running_${base_name}_${provider}"
        (
            touch "$running_marker"
            local _exit=0
            if [ "$STREAM_OUTPUT" = "true" ]; then
                # Stream to both stderr and log file so user sees real-time progress
                generate_test_file_only "$file" "$context" "$provider" 2> >(tee -a "$job_log" >&2) || _exit=$?
            else
                generate_test_file_only "$file" "$context" "$provider" > "$job_log" 2>&1 || _exit=$?
            fi
            rm -f "$running_marker"
            if [ "$_exit" -eq 0 ]; then
                touch "$success_marker"
            fi
            echo "$_exit" > "${jobs_dir}/exit_${base_name}"
            echo "$file" > "${jobs_dir}/file_${base_name}"
        ) &
        local job_pid=$!
        echo "$job_pid" > "${active_jobs_dir}/${job_pid}.${provider}"
        spawned=$((spawned + 1))
    done

    # Live progress monitor with keyboard abort (press 'q' or 's' to skip generation)
    local user_aborted=false
    if [ "$STREAM_OUTPUT" = "true" ] && [ $spawned -gt 1 ]; then
        local completed=0
        while [ $completed -lt $spawned ]; do
            completed=$(ls "${jobs_dir}"/exit_* 2>/dev/null | wc -l | tr -d ' ')
            local running=$(ls "${jobs_dir}"/running_* 2>/dev/null | wc -l | tr -d ' ')
            printf "\r\033[K[INFO] Progress: %d/%d complete, %d running  (press 'q' to abort)" "$completed" "$spawned" "$running" >&2
            if [ $completed -lt $spawned ]; then
                # Check for keyboard abort every 1 second
                local key=""
                if IFS= read -rs -t 1 -n 1 key < /dev/tty 2>/dev/null; then
                    if [ "$key" = "q" ] || [ "$key" = "Q" ] || [ "$key" = "s" ] || [ "$key" = "S" ]; then
                        user_aborted=true
                        printf "\r\033[K\n" >&2
                        log_warning "User aborted test generation"
                        break
                    fi
                fi
            fi
        done
        if [ "$user_aborted" = "false" ]; then
            echo "" >&2
        fi
    else
        log_info "Waiting for $spawned job(s) to complete... (press 'q' to abort)"
        # Poll for completion while checking for keyboard abort
        local all_done=false
        while [ "$all_done" = "false" ]; do
            all_done=true
            for job_file in "${active_jobs_dir}"/*; do
                [ -f "$job_file" ] || continue
                local job_pid=$(basename "$job_file" | sed 's/\.[^.]*$//')
                if kill -0 "$job_pid" 2>/dev/null; then
                    all_done=false
                    break
                fi
            done
            if [ "$all_done" = "false" ]; then
                local key=""
                if IFS= read -rs -t 1 -n 1 key < /dev/tty 2>/dev/null; then
                    if [ "$key" = "q" ] || [ "$key" = "Q" ] || [ "$key" = "s" ] || [ "$key" = "S" ]; then
                        user_aborted=true
                        log_warning "User aborted test generation"
                        break
                    fi
                fi
            fi
        done
    fi

    # Kill any remaining jobs if user aborted
    if [ "$user_aborted" = "true" ]; then
        for job_file in "${active_jobs_dir}"/*; do
            [ -f "$job_file" ] || continue
            local job_pid=$(basename "$job_file" | sed 's/\.[^.]*$//')
            kill -TERM "$job_pid" 2>/dev/null || true
        done
        sleep 0.5
        for job_file in "${active_jobs_dir}"/*; do
            [ -f "$job_file" ] || continue
            local job_pid=$(basename "$job_file" | sed 's/\.[^.]*$//')
            kill -KILL "$job_pid" 2>/dev/null || true
        done
        return 0  # Graceful skip, not an error
    fi

    for job_file in "${active_jobs_dir}"/*; do
        [ -f "$job_file" ] || continue
        local job_pid=$(basename "$job_file" | sed 's/\.[^.]*$//')
        wait "$job_pid" 2>/dev/null || true
    done

    local success_count=0
    for marker in "${jobs_dir}"/success_*; do
        [ -f "$marker" ] || continue
        success_count=$((success_count + 1))
    done
    local failed_count=$((spawned - success_count))
    TESTS_GENERATED=$((TESTS_GENERATED + success_count))
    log_info "Generation complete: $success_count succeeded, $failed_count failed"
    if [ $failed_count -gt 0 ]; then
        log_warning "Failed generations:"
        for exit_file in "${jobs_dir}"/exit_*; do
            [ -f "$exit_file" ] || continue
            local job_exit=$(cat "$exit_file")
            if [ "$job_exit" -ne 0 ]; then
                local failed_base=$(basename "$exit_file" | sed 's/exit_//')
                local failed_file="${jobs_dir}/file_${failed_base}"
                if [ -f "$failed_file" ]; then
                    log_warning "  - $(basename "$(cat "$failed_file")") (exit: $job_exit)"
                fi
            fi
        done
        return 10
    fi
    return 0
}

# Generate tests for a source file (batch mode — no build verification)
# Usage: generate_test_file_only <source_file> <context> [provider] [prompt_override]
generate_test_file_only() {
    local source_file="$1"
    local context="${2:-}"
    local provider="${3:-${AI_PROVIDER:-cursor}}"
    local prompt_override="${4:-}"
    local retry_count=0
    local test_file=""

    log_section "Generating tests for: $(basename "$source_file") (provider: $provider)"

    # Read source content
    local source_content
    source_content=$(cat "$source_file")

    # Build prompt
    local prompt
    if [ -n "$prompt_override" ]; then
        prompt="$prompt_override"
    elif [ -n "${TEST_GENERATION_WAVE:-}" ]; then
        prompt=$(build_test_prompt_for_type "$source_file" "$source_content" "$context" "$TEST_GENERATION_WAVE")
    else
        prompt=$(build_test_prompt "$source_file" "$source_content" "$context")
    fi

    # Determine test file path
    local base_name
    base_name=$(basename "$source_file" .swift)
    test_file="${TEST_TARGET_DIR}/${base_name}Tests.swift"

    # Skip if test file already exists
    if [ -f "$test_file" ]; then
        log_info "Test file already exists, skipping: $(basename "$test_file")"
        return 0
    fi

    if [ "$DRY_RUN" = "true" ]; then
        log_info "[DRY RUN] Would generate: $test_file"
        log_verbose "Prompt length: ${#prompt} chars"
        return 0
    fi

    # Retry loop — rotate provider on each retry to distribute load
    local providers_pool=("$provider")
    while [ $retry_count -lt $MAX_RETRIES ]; do
        retry_count=$((retry_count + 1))
        local current_provider="${providers_pool[$((retry_count - 1))]:-$provider}"
        log_info "Attempt $retry_count/$MAX_RETRIES (provider: $current_provider)"

        # Generate tests via AI
        local ai_output_file="${LOGS_DIR}/ai_output_${base_name}_${current_provider}_${retry_count}.txt"
        local wave_start_time
        wave_start_time=$(date +%s)

        if ! run_ai_cli "$prompt" --provider "$current_provider" --output "$ai_output_file"; then
            log_error "AI generation failed (provider: $current_provider)"
            local wave_duration=$(($(date +%s) - wave_start_time))
            record_provider_result "$current_provider" "failure" "$wave_duration"
            if [ $retry_count -lt $MAX_RETRIES ]; then
                local next_provider
                case "$PROVIDER_STRATEGY" in
                        ucb1)
                            next_provider=$(select_provider_ucb1 0.5)
                            log_info "UCB1 selected: $next_provider"
                            ;;
                        thompson)
                            next_provider=$(select_provider_thompson)
                            log_info "Thompson selected: $next_provider"
                            ;;
                        epsilon-greedy)
                            next_provider=$(select_provider_epsilon_greedy 0.3 0.95)
                            log_info "Epsilon-greedy selected: $next_provider"
                            ;;
                        explore-then-commit)
                            next_provider=$(select_provider_explore_then_commit 2)
                            log_info "Explore-then-commit selected: $next_provider"
                            ;;
                        auto)
                            next_provider=$(select_provider_auto)
                            log_info "Auto selected: $next_provider"
                            ;;
                        *)
                            next_provider=$(get_next_provider "$current_provider")
                            ;;
                    esac
                if [ -n "$next_provider" ] && [ "$next_provider" != "$current_provider" ]; then
                    log_info "Switching to $next_provider for next attempt"
                    providers_pool+=("$next_provider")
                fi
                log_warning "Retrying..."
                sleep 2
                continue
            fi
            return 12
        fi

        # Extract Swift code from AI response
        local generated_code
        generated_code=$(cat "$ai_output_file")
        local wave_duration=$(($(date +%s) - wave_start_time))

        # Extract Swift code from markdown, detecting prose-only or truncated output
        local extracted_code
        local code_valid=false
        if extracted_code=$(extract_swift_code "$generated_code"); then
            generated_code="$extracted_code"
            code_valid=true
            record_provider_result "$current_provider" "success" "$wave_duration"
        else
            log_warning "AI output contained no valid Swift code (prose/truncated). Retrying..."
            record_provider_result "$current_provider" "failure" "$wave_duration"
            if [ $retry_count -lt $MAX_RETRIES ]; then
                local next_provider
                case "$PROVIDER_STRATEGY" in
                        ucb1)
                            next_provider=$(select_provider_ucb1 0.5)
                            log_info "UCB1 selected: $next_provider"
                            ;;
                        thompson)
                            next_provider=$(select_provider_thompson)
                            log_info "Thompson selected: $next_provider"
                            ;;
                        epsilon-greedy)
                            next_provider=$(select_provider_epsilon_greedy 0.3 0.95)
                            log_info "Epsilon-greedy selected: $next_provider"
                            ;;
                        explore-then-commit)
                            next_provider=$(select_provider_explore_then_commit 2)
                            log_info "Explore-then-commit selected: $next_provider"
                            ;;
                        auto)
                            next_provider=$(select_provider_auto)
                            log_info "Auto selected: $next_provider"
                            ;;
                        *)
                            next_provider=$(get_next_provider "$current_provider")
                            ;;
                    esac
                if [ -n "$next_provider" ] && [ "$next_provider" != "$current_provider" ]; then
                    log_info "Switching to $next_provider for next attempt"
                    providers_pool+=("$next_provider")
                fi
                prompt="Generate a valid Swift test file for $(basename "$source_file"). The previous response contained explanations or truncated code instead of the complete file.

SOURCE FILE:
\`\`\`swift
$source_content
\`\`\`

Output ONLY the full raw Swift code starting with import statements. No markdown, no prose, no placeholders like // ..."
                sleep 2
                continue
            fi
            generated_code=$(echo "$generated_code" | sed -E '/^\`\`\`(swift)?\s*$/d')
        fi

        # Only write if code is valid OR no previous good version exists
        if [ "$code_valid" = "true" ] || [ ! -f "$test_file" ]; then
            mkdir -p "$(dirname "$test_file")"
            echo "$generated_code" > "$test_file"
            log_success "Generated: $test_file"
            return 0
        else
            log_warning "Skipping write for $test_file — existing file preserved (new output was invalid)."
        fi
    done

    log_error "Failed to generate valid tests after $MAX_RETRIES attempts"
    write_error_log "Failed to generate tests for: $source_file"
    return 10
}

# Fix a test file using build error feedback
# Usage: fix_test_file <test_file> <errors> [context]
fix_test_file() {
    local test_file="$1"
    local errors="$2"
    local context="${3:-}"
    local retry_count=0

    local base_name=$(basename "$test_file" "Tests.swift")
    local source_file=""
    while IFS= read -r sf; do
        [ -z "$sf" ] && continue
        if [ "$(basename "$sf" .swift)" = "$base_name" ]; then
            source_file="$sf"
            break
        fi
    done <<< "$SOURCE_FILES_CACHE"

    if [ ! -f "$source_file" ]; then
        log_error "Could not find source file for $test_file"
        return 1
    fi

    local source_content=$(cat "$source_file")
    local current_test_content=$(cat "$test_file")

    log_info "Fixing: $(basename "$test_file")"

    while [ $retry_count -lt $MAX_RETRIES ]; do
        retry_count=$((retry_count + 1))
        log_info "Fix attempt $retry_count/$MAX_RETRIES for $(basename "$test_file")"

        local prompt="The following test file has build errors:

BUILD ERRORS:
$errors

CURRENT TEST FILE ($(basename "$test_file")):
\`\`\`swift
$current_test_content
\`\`\`

ORIGINAL SOURCE FILE ($(basename "$source_file")):
\`\`\`swift
$source_content
\`\`\`

Please fix the test file to resolve all build errors.

REFERENCE DOCUMENTATION:
$context

CRITICAL: Output ONLY the corrected raw Swift code. Do NOT include markdown tables, summaries, explanations, bullet points, or any prose. Start with import statements."

        local ai_output_file="${LOGS_DIR}/ai_fix_${base_name}_${retry_count}.txt"

        if ! run_ai_cli "$prompt" --provider "$AI_PROVIDER" --output "$ai_output_file"; then
            log_error "AI fix generation failed for $(basename "$test_file")"
            if [ $retry_count -lt $MAX_RETRIES ]; then
                continue
            fi
            return 12
        fi

        local generated_code=$(cat "$ai_output_file")
        local extracted_code
        if extracted_code=$(extract_swift_code "$generated_code"); then
            generated_code="$extracted_code"
        else
            log_warning "AI fix output contained no valid Swift code. Retrying..."
            if [ $retry_count -lt $MAX_RETRIES ]; then
                continue
            fi
            generated_code=$(echo "$generated_code" | sed -E '/^\`\`\`(swift)?\s*$/d')
        fi

        echo "$generated_code" > "$test_file"
        log_success "Updated: $test_file"
        return 0
    done

    log_error "Failed to fix $(basename "$test_file") after $MAX_RETRIES attempts"
    return 10
}

# Parse build error.log and return list of broken test file paths
find_broken_test_files_from_errors() {
    local error_log="$1"
    if [ ! -f "$error_log" ]; then
        return 0
    fi
    grep -oE "${TEST_TARGET_DIR}/[^[:space:]]+Tests\.swift" "$error_log" 2>/dev/null | sort -u
}

# Batch build verification and fix loop
# Usage: build_and_fix_tests [context]
build_and_fix_tests() {
    local context="${1:-}"
    local fix_round=0

    while [ $fix_round -lt $MAX_RETRIES ]; do
        fix_round=$((fix_round + 1))
        log_section "Build verification (round $fix_round/$MAX_RETRIES)"

        if [ "$DRY_RUN" = "true" ]; then
            log_info "[DRY RUN] Would run build"
            return 0
        fi

        rm -f "${LOGS_DIR}/error.log"

        if run_build_lint --logs-dir "$LOGS_DIR" --scheme "$SCHEME"; then
            log_success "Build verification passed — all tests compile"
            return 0
        fi

        log_warning "Build failed, analyzing errors..."

        local error_log="${LOGS_DIR}/error.log"
        if [ ! -f "$error_log" ]; then
            log_error "Build failed but no error.log found"
            return 10
        fi

        local broken_files
        broken_files=$(find_broken_test_files_from_errors "$error_log")

        if [ -z "$broken_files" ]; then
            log_error "Build failed but no test file errors detected (may be source or project issues)"
            cat "$error_log" >&2
            return 10
        fi

        local errors
        errors=$(cat "$error_log")

        local fix_count=0
        while IFS= read -r test_file; do
            [ -z "$test_file" ] && continue
            if [ -f "$test_file" ]; then
                if fix_test_file "$test_file" "$errors" "$context"; then
                    fix_count=$((fix_count + 1))
                fi
            fi
        done <<< "$broken_files"

        log_info "Fixed $fix_count test file(s), rebuilding..."
    done

    log_error "Build still failing after $MAX_RETRIES fix rounds"
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

    # Detect available simulator dynamically
    local sim_name
    sim_name=$(detect_available_simulator "$SCHEME" "${XCODE_PROJECT:-}" "${XCODE_WORKSPACE:-}")
    if [ -z "$sim_name" ]; then
        sim_name="iPhone 16"
        log_warning "Could not detect available simulator, falling back to $sim_name"
    fi
    log_info "Using simulator: $sim_name"

    local test_cmd="xcodebuild test $xcode_arg"
    [ -n "$SCHEME" ] && test_cmd="$test_cmd -scheme \"$SCHEME\""
    test_cmd="$test_cmd -destination 'platform=iOS Simulator,name=$sim_name' -enableCodeCoverage YES"

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

# Global cache of source files for fix_test_file to use
SOURCE_FILES_CACHE=""

main() {
    parse_arguments "$@"
    initialize

    # Find source files
    SOURCE_FILES_CACHE=$(find_source_files) || {
        log_error "No source files found"
        exit 11
    }

    local exit_code=0

    # ═══════════════════════════════════════════════════════════════════════════
    # PHASE 1: Generate test files
    # ═══════════════════════════════════════════════════════════════════════════
    log_section "PHASE 1: Generating test files (strategy: $TEST_STRATEGY)"

    # Gather context once, cache across runs
    local test_context
    local cache_key
    cache_key=$(compute_context_key "unit-test-agent" "${UNIT_TEST_CONTEXT_PATHS[@]+"${UNIT_TEST_CONTEXT_PATHS[@]}"}")
    test_context=$(gather_test_context --cache-key "$cache_key" "${UNIT_TEST_CONTEXT_PATHS[@]+"${UNIT_TEST_CONTEXT_PATHS[@]}"}")

    # Force priority strategy in happy-only mode (so we only run happy wave)
    if [ "$HAPPY_ONLY" = "true" ]; then
        TEST_STRATEGY="priority"
    fi

    if [ "$TEST_STRATEGY" = "priority" ]; then
        # Wave-based: happy → sad → regression → coverage
        run_prioritized_generation "$test_context" "$SOURCE_FILES_CACHE"
    else
        # Standard parallel generation across providers
        if ! generate_tests_parallel "$test_context" "$SOURCE_FILES_CACHE"; then
            exit_code=10
        fi
    fi

    # ═══════════════════════════════════════════════════════════════════════════
    # PHASE 2: Build once, fix broken tests, repeat
    # ═══════════════════════════════════════════════════════════════════════════
    if [ $TESTS_GENERATED -gt 0 ] || [ -n "$(find "${TEST_TARGET_DIR}" -name "*Tests.swift" 2>/dev/null)" ]; then
        log_section "PHASE 2: Build verification and fix loop"
        if ! build_and_fix_tests "$test_context"; then
            exit_code=10
        fi
    else
        log_info "No test files to build"
    fi

    # ═══════════════════════════════════════════════════════════════════════════
    # PHASE 3: Run tests and extract coverage
    # ═══════════════════════════════════════════════════════════════════════════
    if [ $TESTS_GENERATED -gt 0 ]; then
        if ! run_tests; then
            exit_code=10
        fi
        extract_coverage
    fi

    # Generate report
    generate_unit_test_report

    # Save session defaults if used
    if [ "$USE_SESSION" = "true" ]; then
        session_save || true
    fi

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
