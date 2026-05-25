#!/usr/bin/env bash
# Library: swift_package.sh
# Purpose: Swift Package Manager support library for Foundation agents
# Dependencies: swift (Swift toolchain), jq (optional for JSON parsing)
#
# Functions:
#   is_swift_package()              - Check if current directory is a Swift package
#   swift_package_build()           - Build Swift package
#   swift_package_test()            - Run Swift package tests
#   swift_package_clean()           - Clean Swift package build
#   swift_package_resolve()         - Resolve dependencies
#   swift_package_update()          - Update dependencies
#   swift_package_describe()        - Get package description
#   parse_spm_output()              - Parse build/test output for errors/warnings
#
# Environment Variables:
#   PROJECT_ROOT                    - Root directory of the project
#   LOGS_DIR                        - Directory for log files
#   JSON_OUTPUT                     - Output JSON format (true/false)

set -euo pipefail

# Verify bash is running
if [ -z "${BASH_VERSION:-}" ]; then
    echo "Error: This library requires bash" >&2
    return 1 2>/dev/null || exit 1
fi

# Path resolution
SWIFT_PKG_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SWIFT_PKG_PHASE5_DIR="$(cd "${SWIFT_PKG_LIB_DIR}/.." && pwd)"
SWIFT_PKG_PROJECT_ROOT="${PROJECT_ROOT:-$(cd "${SWIFT_PKG_PHASE5_DIR}/../../../.." && pwd)}"

# Configuration
SWIFT_PKG_LOGS_DIR="${LOGS_DIR:-${SWIFT_PKG_PROJECT_ROOT}/.foundation-logs}"

# Check if jq is available
_spm_has_jq() {
    command -v jq &>/dev/null
}

# Check if current directory is a Swift package
# Returns: 0 if Package.swift exists, 1 otherwise
is_swift_package() {
    local dir="${1:-$SWIFT_PKG_PROJECT_ROOT}"
    [ -f "${dir}/Package.swift" ]
}

# Detect Package.swift location (searching upward)
# Arguments:
#   $1 - starting directory (optional)
# Returns: path to directory containing Package.swift
find_package_root() {
    local dir="${1:-$PWD}"

    while [ "$dir" != "/" ]; do
        if [ -f "${dir}/Package.swift" ]; then
            echo "$dir"
            return 0
        fi
        dir=$(dirname "$dir")
    done

    return 1
}

# Build Swift package
# Arguments:
#   $1 - configuration (debug/release, default: debug)
#   $2+ - additional swift build arguments
# Returns: 0 on success, non-zero on failure
swift_package_build() {
    local configuration="${1:-debug}"
    shift 2>/dev/null || true
    local extra_args=("$@")

    local log_file="${SWIFT_PKG_LOGS_DIR}/spm_build.log"
    mkdir -p "$(dirname "$log_file")"

    echo "[SPM] Building Swift package (${configuration})..." >&2

    local build_cmd=(swift build --configuration "$configuration")

    # Add extra arguments if provided
    if [ ${#extra_args[@]} -gt 0 ]; then
        build_cmd+=("${extra_args[@]}")
    fi

    # Run build and capture output
    local exit_code=0
    "${build_cmd[@]}" 2>&1 | tee "$log_file" || exit_code=$?

    if [ $exit_code -eq 0 ]; then
        echo "[SPM] Build succeeded" >&2
    else
        echo "[SPM] Build failed with exit code $exit_code" >&2
    fi

    # Parse output if JSON requested
    if [ "${JSON_OUTPUT:-false}" = "true" ]; then
        parse_spm_output "$log_file" "$exit_code"
    fi

    return $exit_code
}

# Run Swift package tests
# Arguments:
#   $1 - filter pattern (optional)
#   $2 - parallel (true/false, default: true)
#   $3+ - additional swift test arguments
# Returns: 0 on success, non-zero on failure
swift_package_test() {
    local filter="${1:-}"
    local parallel="${2:-true}"
    shift 2 2>/dev/null || true
    local extra_args=("$@")

    local log_file="${SWIFT_PKG_LOGS_DIR}/spm_test.log"
    mkdir -p "$(dirname "$log_file")"

    echo "[SPM] Running Swift package tests..." >&2

    local test_cmd=(swift test)

    if [ -n "$filter" ]; then
        test_cmd+=(--filter "$filter")
    fi

    if [ "$parallel" = "true" ]; then
        test_cmd+=(--parallel)
    fi

    # Add extra arguments if provided
    if [ ${#extra_args[@]} -gt 0 ]; then
        test_cmd+=("${extra_args[@]}")
    fi

    # Run tests and capture output
    local exit_code=0
    "${test_cmd[@]}" 2>&1 | tee "$log_file" || exit_code=$?

    if [ $exit_code -eq 0 ]; then
        echo "[SPM] Tests passed" >&2
    else
        echo "[SPM] Tests failed with exit code $exit_code" >&2
    fi

    # Parse output if JSON requested
    if [ "${JSON_OUTPUT:-false}" = "true" ]; then
        parse_spm_test_output "$log_file" "$exit_code"
    fi

    return $exit_code
}

# Clean Swift package build
# Arguments:
#   $1 - also remove .build directory (true/false, default: false)
# Returns: 0 on success
swift_package_clean() {
    local remove_build_dir="${1:-false}"

    echo "[SPM] Cleaning Swift package build..." >&2

    swift package clean 2>&1

    if [ "$remove_build_dir" = "true" ] && [ -d ".build" ]; then
        echo "[SPM] Removing .build directory..." >&2
        rm -rf .build
    fi

    echo "[SPM] Clean completed" >&2
    return 0
}

# Resolve Swift package dependencies
# Returns: 0 on success
swift_package_resolve() {
    local log_file="${SWIFT_PKG_LOGS_DIR}/spm_resolve.log"
    mkdir -p "$(dirname "$log_file")"

    echo "[SPM] Resolving dependencies..." >&2

    local exit_code=0
    swift package resolve 2>&1 | tee "$log_file" || exit_code=$?

    if [ $exit_code -eq 0 ]; then
        echo "[SPM] Dependencies resolved" >&2
    else
        echo "[SPM] Failed to resolve dependencies" >&2
    fi

    return $exit_code
}

# Update Swift package dependencies
# Returns: 0 on success
swift_package_update() {
    local log_file="${SWIFT_PKG_LOGS_DIR}/spm_update.log"
    mkdir -p "$(dirname "$log_file")"

    echo "[SPM] Updating dependencies..." >&2

    local exit_code=0
    swift package update 2>&1 | tee "$log_file" || exit_code=$?

    if [ $exit_code -eq 0 ]; then
        echo "[SPM] Dependencies updated" >&2
    else
        echo "[SPM] Failed to update dependencies" >&2
    fi

    return $exit_code
}

# Get Swift package description
# Returns: JSON package description
swift_package_describe() {
    local format="${1:-json}"

    if [ "$format" = "json" ]; then
        swift package describe --type json 2>/dev/null
    else
        swift package describe 2>/dev/null
    fi
}

# Get Swift package products
# Returns: list of products
swift_package_products() {
    if _spm_has_jq; then
        swift_package_describe json | jq -r '.products[].name' 2>/dev/null
    else
        swift_package_describe text | grep -A 100 "Products:" | grep -E "^\s+\w+" | awk '{print $1}'
    fi
}

# Get Swift package targets
# Returns: list of targets
swift_package_targets() {
    if _spm_has_jq; then
        swift_package_describe json | jq -r '.targets[].name' 2>/dev/null
    else
        swift_package_describe text | grep -A 100 "Targets:" | grep -E "^\s+\w+" | awk '{print $1}'
    fi
}

# Get Swift package dependencies
# Returns: list of dependencies
swift_package_dependencies() {
    if _spm_has_jq; then
        swift_package_describe json | jq -r '.dependencies[].identity // .dependencies[].url' 2>/dev/null
    else
        swift package show-dependencies 2>/dev/null
    fi
}

# Parse SPM build output for errors and warnings
# Arguments:
#   $1 - log file path
#   $2 - exit code from build
# Returns: JSON object with parsed results
parse_spm_output() {
    local log_file="$1"
    local exit_code="${2:-0}"

    if ! _spm_has_jq; then
        echo "{\"success\": $([ "$exit_code" -eq 0 ] && echo true || echo false)}"
        return
    fi

    # Extract errors and warnings
    local errors=$(grep -E "^.*error:" "$log_file" 2>/dev/null | jq -R -s -c 'split("\n") | map(select(length > 0))' || echo "[]")
    local warnings=$(grep -E "^.*warning:" "$log_file" 2>/dev/null | jq -R -s -c 'split("\n") | map(select(length > 0))' || echo "[]")

    local error_count=$(echo "$errors" | jq 'length')
    local warning_count=$(echo "$warnings" | jq 'length')

    jq -n \
        --argjson success "$([ "$exit_code" -eq 0 ] && echo true || echo false)" \
        --argjson errors "$errors" \
        --argjson warnings "$warnings" \
        --argjson errorCount "$error_count" \
        --argjson warningCount "$warning_count" \
        '{
            success: $success,
            errors: $errors,
            warnings: $warnings,
            summary: {
                errorCount: $errorCount,
                warningCount: $warningCount
            }
        }'
}

# Parse SPM test output
# Arguments:
#   $1 - log file path
#   $2 - exit code from tests
# Returns: JSON object with test results
parse_spm_test_output() {
    local log_file="$1"
    local exit_code="${2:-0}"

    if ! _spm_has_jq; then
        echo "{\"success\": $([ "$exit_code" -eq 0 ] && echo true || echo false)}"
        return
    fi

    # Extract test counts from output
    # Format: "Test Suite 'All tests' passed at ... Executed X tests, with Y failures ... in Z seconds"
    local test_summary=$(grep -E "Executed [0-9]+ tests?" "$log_file" 2>/dev/null | tail -1 || echo "")

    local tests_run=0
    local tests_failed=0
    local tests_skipped=0

    if [ -n "$test_summary" ]; then
        tests_run=$(echo "$test_summary" | grep -oE "Executed [0-9]+" | grep -oE "[0-9]+" || echo 0)
        tests_failed=$(echo "$test_summary" | grep -oE "with [0-9]+ failures?" | grep -oE "[0-9]+" || echo 0)
    fi

    local tests_passed=$((tests_run - tests_failed))

    # Extract failed test names
    local failed_tests=$(grep -E "^.*failed" "$log_file" 2>/dev/null | jq -R -s -c 'split("\n") | map(select(length > 0))' || echo "[]")

    jq -n \
        --argjson success "$([ "$exit_code" -eq 0 ] && echo true || echo false)" \
        --argjson testsRun "$tests_run" \
        --argjson testsPassed "$tests_passed" \
        --argjson testsFailed "$tests_failed" \
        --argjson testsSkipped "$tests_skipped" \
        --argjson failedTests "$failed_tests" \
        '{
            success: $success,
            testsRun: $testsRun,
            testsPassed: $testsPassed,
            testsFailed: $testsFailed,
            testsSkipped: $testsSkipped,
            failedTests: $failedTests
        }'
}

# Run swift build with specific target
# Arguments:
#   $1 - target name
#   $2 - configuration (debug/release)
# Returns: 0 on success
swift_package_build_target() {
    local target="$1"
    local configuration="${2:-debug}"

    echo "[SPM] Building target: $target ($configuration)..." >&2
    swift build --target "$target" --configuration "$configuration" 2>&1
}

# Run swift build with specific product
# Arguments:
#   $1 - product name
#   $2 - configuration (debug/release)
# Returns: 0 on success
swift_package_build_product() {
    local product="$1"
    local configuration="${2:-debug}"

    echo "[SPM] Building product: $product ($configuration)..." >&2
    swift build --product "$product" --configuration "$configuration" 2>&1
}

# Get the built executable path for a product
# Arguments:
#   $1 - product name
#   $2 - configuration (debug/release)
# Returns: path to executable
swift_package_product_path() {
    local product="$1"
    local configuration="${2:-debug}"

    swift build --show-bin-path --configuration "$configuration" 2>/dev/null | tr -d '\n'
    echo "/${product}"
}
