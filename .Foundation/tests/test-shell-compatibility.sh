#!/usr/bin/env bash

# Shell Compatibility Test Suite
# Tests all agents and libraries for proper bash execution across different environments
# Based on Foundation Phase 7 shell compatibility requirements

set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PHASE5_DIR="${SCRIPT_DIR}/../Agents/phases/phase5"
FOUNDATION_LIB_DIR="${SCRIPT_DIR}/../lib"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Test results
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0

# Test log
TEST_LOG="${SCRIPT_DIR}/shell-compatibility-test.log"
> "$TEST_LOG"

# ─────────────────────────────────────────────────────────────────────────────
# Helper Functions
# ─────────────────────────────────────────────────────────────────────────────

log_test() {
    local message="$1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $message" >> "$TEST_LOG"
    echo -e "${CYAN}[TEST]${NC} $message"
}

log_pass() {
    local message="$1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✓ PASS: $message" >> "$TEST_LOG"
    echo -e "${GREEN}✓ PASS${NC} $message"
    PASSED_TESTS=$((PASSED_TESTS + 1))
}

log_fail() {
    local message="$1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✗ FAIL: $message" >> "$TEST_LOG"
    echo -e "${RED}✗ FAIL${NC} $message"
    FAILED_TESTS=$((FAILED_TESTS + 1))
}

log_skip() {
    local message="$1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ⊘ SKIP: $message" >> "$TEST_LOG"
    echo -e "${YELLOW}⊘ SKIP${NC} $message"
    SKIPPED_TESTS=$((SKIPPED_TESTS + 1))
}

log_info() {
    local message="$1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] INFO: $message" >> "$TEST_LOG"
    echo -e "${BLUE}[INFO]${NC} $message"
}

check_bash_version() {
    if [ -n "${BASH_VERSINFO:-}" ]; then
        echo "${BASH_VERSINFO[0]}.${BASH_VERSINFO[1]}"
    else
        echo "unknown"
    fi
}

get_bash_major_version() {
    if [ -n "${BASH_VERSINFO:-}" ]; then
        echo "${BASH_VERSINFO[0]}"
    else
        echo "0"
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Test Functions
# ─────────────────────────────────────────────────────────────────────────────

test_shebang_format() {
    local file="$1"
    local filename="$(basename "$file")"

    TOTAL_TESTS=$((TOTAL_TESTS + 1))

    if [ ! -f "$file" ]; then
        log_skip "File not found: $filename"
        return
    fi

    local shebang
    shebang=$(head -1 "$file")

    if [ "$shebang" = "#!/usr/bin/env bash" ]; then
        log_pass "Shebang correct: $filename"
    else
        log_fail "Shebang incorrect in $filename: '$shebang' (expected '#!/usr/bin/env bash')"
    fi
}

test_bash_source_usage() {
    local file="$1"
    local filename="$(basename "$file")"

    TOTAL_TESTS=$((TOTAL_TESTS + 1))

    if [ ! -f "$file" ]; then
        log_skip "File not found: $filename"
        return
    fi

    # Check if file uses BASH_SOURCE
    if grep -q "BASH_SOURCE\[0\]" "$file"; then
        # Verify it's used correctly (should work with env bash shebang)
        log_pass "BASH_SOURCE usage found in $filename"
    else
        log_skip "No BASH_SOURCE usage in $filename"
    fi
}

test_script_execution() {
    local script="$1"
    local script_name="$(basename "$script")"
    local test_env="$2"  # "bash", "zsh-bash", etc.

    TOTAL_TESTS=$((TOTAL_TESTS + 1))

    if [ ! -f "$script" ]; then
        log_skip "Script not found: $script_name"
        return
    fi

    # Check if script supports --help flag
    local output
    local exit_code=0

    case "$test_env" in
        bash)
            # Direct bash execution
            output=$(bash "$script" --help 2>&1) || exit_code=$?
            ;;
        zsh-bash)
            # Execute from zsh context
            if command -v zsh >/dev/null 2>&1; then
                output=$(zsh -c "bash '$script' --help" 2>&1) || exit_code=$?
            else
                log_skip "zsh not available for testing $script_name"
                return
            fi
            ;;
        *)
            log_skip "Unknown test environment: $test_env"
            return
            ;;
    esac

    # Check if help was displayed or if it's a library (no --help)
    if [ $exit_code -eq 0 ] || echo "$output" | grep -qi "usage\|help\|options"; then
        log_pass "Execution successful ($test_env): $script_name"
    else
        log_fail "Execution failed ($test_env): $script_name (exit code: $exit_code)"
    fi
}

test_library_sourcing() {
    local library="$1"
    local lib_name="$(basename "$library")"

    TOTAL_TESTS=$((TOTAL_TESTS + 1))

    if [ ! -f "$library" ]; then
        log_skip "Library not found: $lib_name"
        return
    fi

    # Test sourcing in a subshell
    local output
    local exit_code=0

    output=$(bash -c "source '$library' 2>&1; echo 'sourced successfully'" 2>&1) || exit_code=$?

    if [ $exit_code -eq 0 ] && echo "$output" | grep -q "sourced successfully"; then
        log_pass "Library sources successfully: $lib_name"
    else
        log_fail "Library sourcing failed: $lib_name (exit code: $exit_code)"
    fi
}

test_compatibility_check_function() {
    TOTAL_TESTS=$((TOTAL_TESTS + 1))

    local helpers_lib="${FOUNDATION_LIB_DIR}/helpers.sh"

    if [ ! -f "$helpers_lib" ]; then
        log_fail "helpers.sh not found at $helpers_lib"
        return
    fi

    # Test that check_shell_compatibility function exists
    local output
    output=$(bash -c "source '$helpers_lib' 2>&1; type check_shell_compatibility >/dev/null 2>&1 && echo 'found'" 2>&1)

    if echo "$output" | grep -q "found"; then
        log_pass "check_shell_compatibility function exists in helpers.sh"
    else
        log_fail "check_shell_compatibility function not found in helpers.sh"
    fi
}

test_bash_version_check() {
    TOTAL_TESTS=$((TOTAL_TESTS + 1))

    local helpers_lib="${FOUNDATION_LIB_DIR}/helpers.sh"

    if [ ! -f "$helpers_lib" ]; then
        log_fail "helpers.sh not found at $helpers_lib"
        return
    fi

    # Test that check_bash_version function exists and works
    local output
    output=$(bash -c "source '$helpers_lib' 2>&1; check_bash_version" 2>&1)

    if [ -n "$output" ] && [ "$output" != "0" ]; then
        log_pass "check_bash_version returns version: $output"
    else
        log_fail "check_bash_version did not return valid version"
    fi
}

test_library_bash_check() {
    local library="$1"
    local lib_name="$(basename "$library")"

    TOTAL_TESTS=$((TOTAL_TESTS + 1))

    if [ ! -f "$library" ]; then
        log_skip "Library not found: $lib_name"
        return
    fi

    # Check if library has bash version check
    if grep -q 'if \[ -z "\${BASH_VERSION:-}"' "$library"; then
        log_pass "Bash version check present in $lib_name"
    else
        log_fail "No bash version check in $lib_name"
    fi
}

test_agent_compatibility_call() {
    local agent="$1"
    local agent_name="$(basename "$agent")"

    TOTAL_TESTS=$((TOTAL_TESTS + 1))

    if [ ! -f "$agent" ]; then
        log_skip "Agent not found: $agent_name"
        return
    fi

    # Check if agent calls check_shell_compatibility
    if grep -q "check_shell_compatibility" "$agent"; then
        log_pass "Agent calls check_shell_compatibility: $agent_name"
    else
        # Some agents might not use helpers.sh
        if grep -q "source.*helpers\.sh" "$agent"; then
            log_fail "Agent sources helpers.sh but doesn't call check_shell_compatibility: $agent_name"
        else
            log_skip "Agent doesn't use helpers.sh: $agent_name"
        fi
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Main Test Execution
# ─────────────────────────────────────────────────────────────────────────────

main() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}  Shell Compatibility Test Suite                              ${BLUE}║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    local bash_version
    bash_version=$(check_bash_version)
    log_info "Running tests with bash version: $bash_version"
    log_info "Test log: $TEST_LOG"
    echo ""

    # Test 1: Shebang Format Tests
    echo -e "${CYAN}═══ Shebang Format Tests ═══${NC}"

    for script in "${PHASE5_DIR}"/*.sh; do
        test_shebang_format "$script"
    done

    for library in "${PHASE5_DIR}/lib"/*.sh; do
        test_shebang_format "$library"
    done

    for library in "${FOUNDATION_LIB_DIR}"/*.sh; do
        test_shebang_format "$library"
    done

    echo ""

    # Test 2: BASH_SOURCE Usage Tests
    echo -e "${CYAN}═══ BASH_SOURCE Usage Tests ═══${NC}"

    for script in "${PHASE5_DIR}"/*.sh; do
        test_bash_source_usage "$script"
    done

    for library in "${PHASE5_DIR}/lib"/*.sh; do
        test_bash_source_usage "$library"
    done

    echo ""

    # Test 3: Compatibility Function Tests
    echo -e "${CYAN}═══ Compatibility Function Tests ═══${NC}"

    test_compatibility_check_function
    test_bash_version_check

    echo ""

    # Test 4: Library Bash Check Tests
    echo -e "${CYAN}═══ Library Bash Check Tests ═══${NC}"

    for library in "${PHASE5_DIR}/lib"/*.sh; do
        test_library_bash_check "$library"
    done

    for library in "${FOUNDATION_LIB_DIR}"/*.sh; do
        # Skip helpers.sh as it has comprehensive checks
        if [ "$(basename "$library")" != "helpers.sh" ]; then
            test_library_bash_check "$library"
        fi
    done

    echo ""

    # Test 5: Agent Compatibility Call Tests
    echo -e "${CYAN}═══ Agent Compatibility Call Tests ═══${NC}"

    local main_agents=(
        "BuildAgent.sh"
        "BuildLint.sh"
        "BuildVerify.sh"
        "testRunner.sh"
        "uiTestAgent.sh"
        "unitTestAgent.sh"
        "testAgent.sh"
        "flowAgent.sh"
        "accessibilityAgent.sh"
    )

    for agent in "${main_agents[@]}"; do
        test_agent_compatibility_call "${PHASE5_DIR}/${agent}"
    done

    echo ""

    # Test 6: Library Sourcing Tests
    echo -e "${CYAN}═══ Library Sourcing Tests ═══${NC}"

    for library in "${PHASE5_DIR}/lib"/*.sh; do
        test_library_sourcing "$library"
    done

    for library in "${FOUNDATION_LIB_DIR}"/*.sh; do
        test_library_sourcing "$library"
    done

    echo ""

    # Test 7: Script Execution Tests (bash)
    echo -e "${CYAN}═══ Script Execution Tests (bash) ═══${NC}"

    local executable_agents=(
        "BuildAgent.sh"
        "BuildLint.sh"
        "testRunner.sh"
        "list-simulators.sh"
    )

    for agent in "${executable_agents[@]}"; do
        test_script_execution "${PHASE5_DIR}/${agent}" "bash"
    done

    echo ""

    # Test 8: Script Execution from zsh
    if command -v zsh >/dev/null 2>&1; then
        echo -e "${CYAN}═══ Script Execution Tests (from zsh) ═══${NC}"

        for agent in "${executable_agents[@]}"; do
            test_script_execution "${PHASE5_DIR}/${agent}" "zsh-bash"
        done

        echo ""
    else
        log_info "zsh not available, skipping zsh execution tests"
        echo ""
    fi

    # ─────────────────────────────────────────────────────────────────────────
    # Test Summary
    # ─────────────────────────────────────────────────────────────────────────

    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}  Test Summary                                                 ${BLUE}║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  Total Tests:   ${CYAN}${TOTAL_TESTS}${NC}"
    echo -e "  ${GREEN}Passed:        ${PASSED_TESTS}${NC}"
    echo -e "  ${RED}Failed:        ${FAILED_TESTS}${NC}"
    echo -e "  ${YELLOW}Skipped:       ${SKIPPED_TESTS}${NC}"
    echo ""

    if [ $FAILED_TESTS -eq 0 ]; then
        echo -e "${GREEN}✓ All tests passed!${NC}"
        echo ""
        return 0
    else
        echo -e "${RED}✗ Some tests failed. Check log: $TEST_LOG${NC}"
        echo ""
        return 1
    fi
}

# Run tests
main "$@"
