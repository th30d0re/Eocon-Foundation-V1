#!/usr/bin/env bash
# Test All Phase5 Agents
# Validates each agent with --help and basic smoke tests
# Exit codes: 0 = all passed, 1 = some failed

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASSED=0
FAILED=0
TOTAL=0

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║           Phase 5 Agent Test Suite                            ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo

# Array of agents to test
declare -a AGENTS=(
    "BuildAgent.sh"
    "BuildLint.sh"
    "BuildVerify.sh"
    "testAgent.sh"
    "unitTestAgent.sh"
    "accessibilityAgent.sh"
    "flowAgent.sh"
    "uiTestAgent.sh"
    "testRunner.sh"
)

# Test function
test_agent() {
    local agent=$1
    local agent_path="${SCRIPT_DIR}/${agent}"
    
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}Testing: ${agent}${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    TOTAL=$((TOTAL + 1))
    
    # Test 1: File exists and is executable
    if [[ ! -f "$agent_path" ]]; then
        echo -e "${RED}✗ FAIL: Agent not found${NC}"
        FAILED=$((FAILED + 1))
        return 1
    fi
    
    if [[ ! -x "$agent_path" ]]; then
        echo -e "${RED}✗ FAIL: Agent not executable${NC}"
        FAILED=$((FAILED + 1))
        return 1
    fi
    
    # Test 2: Help flag works
    echo -e "  Testing --help flag..."
    if "$agent_path" --help &>/dev/null; then
        echo -e "  ${GREEN}✓${NC} --help works"
    else
        # Some agents might not support --help, check for -h
        if "$agent_path" -h &>/dev/null; then
            echo -e "  ${GREEN}✓${NC} -h works"
        else
            echo -e "  ${YELLOW}⚠${NC}  No help flag (acceptable)"
        fi
    fi
    
    # Test 3: Check shebang
    local shebang=$(head -1 "$agent_path")
    if [[ "$shebang" =~ ^#!.*bash ]]; then
        echo -e "  ${GREEN}✓${NC} Valid bash shebang"
    else
        echo -e "  ${YELLOW}⚠${NC}  Unexpected shebang: $shebang"
    fi
    
    # Test 4: Check for set -euo pipefail (best practice)
    if grep -q "set -euo pipefail" "$agent_path"; then
        echo -e "  ${GREEN}✓${NC} Has strict error handling (set -euo pipefail)"
    elif grep -q "set -eo pipefail" "$agent_path"; then
        echo -e "  ${GREEN}✓${NC} Has error handling (set -eo pipefail)"
    else
        echo -e "  ${YELLOW}⚠${NC}  No strict error handling"
    fi
    
    # Test 5: Check for documentation
    local has_docs=false
    if grep -q "# Purpose\|# Description\|# Workflow" "$agent_path"; then
        echo -e "  ${GREEN}✓${NC} Has documentation"
        has_docs=true
    else
        echo -e "  ${YELLOW}⚠${NC}  Missing documentation"
    fi
    
    # Test 6: Check exit codes documented
    if grep -q "# Exit Codes:" "$agent_path"; then
        echo -e "  ${GREEN}✓${NC} Exit codes documented"
    else
        echo -e "  ${YELLOW}⚠${NC}  Exit codes not documented"
    fi
    
    # Test 7: Basic syntax check
    echo -e "  Testing bash syntax..."
    if bash -n "$agent_path" 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} Syntax valid"
    else
        echo -e "  ${RED}✗ FAIL: Syntax errors detected${NC}"
        FAILED=$((FAILED + 1))
        return 1
    fi
    
    # Agent-specific tests
    case "$agent" in
        "BuildAgent.sh")
            test_buildagent "$agent_path"
            ;;
        "BuildLint.sh")
            test_buildlint "$agent_path"
            ;;
        "BuildVerify.sh")
            test_buildverify "$agent_path"
            ;;
        "testAgent.sh")
            test_testagent "$agent_path"
            ;;
        *)
            # Generic test agents
            if grep -q "AI_PROVIDER" "$agent_path"; then
                echo -e "  ${GREEN}✓${NC} Supports AI providers"
            fi
            ;;
    esac
    
    echo -e "${GREEN}✓ PASS: ${agent}${NC}"
    PASSED=$((PASSED + 1))
    echo
}

# BuildAgent-specific tests
test_buildagent() {
    local agent_path=$1
    
    # Check for multi-provider support
    if grep -q "cursor\|claude\|codex\|gemini\|aider\|letta" "$agent_path"; then
        echo -e "  ${GREEN}✓${NC} Multi-provider support detected"
    fi
    
    # Check for auto-detection
    if grep -q "detect.*project\|find.*xcodeproj\|find.*xcworkspace" "$agent_path"; then
        echo -e "  ${GREEN}✓${NC} Auto-detection implemented"
    fi
    
    # Check for YOLO mode
    if grep -q "YOLO\|yolo" "$agent_path"; then
        echo -e "  ${GREEN}✓${NC} YOLO mode available"
    fi
}

# BuildLint-specific tests
test_buildlint() {
    local agent_path=$1
    
    # Check for SwiftLint integration
    if grep -q "swiftlint" "$agent_path"; then
        echo -e "  ${GREEN}✓${NC} SwiftLint integration"
    fi
    
    # Check for xcodebuild
    if grep -q "xcodebuild" "$agent_path"; then
        echo -e "  ${GREEN}✓${NC} Xcode build integration"
    fi
}

# BuildVerify-specific tests
test_buildverify() {
    local agent_path=$1
    
    # Check for Letta memory integration
    if grep -q "letta\|LETTA" "$agent_path"; then
        echo -e "  ${GREEN}✓${NC} Letta memory integration"
    fi
    
    # Check for BuildAgent integration
    if grep -q "BuildAgent" "$agent_path"; then
        echo -e "  ${GREEN}✓${NC} BuildAgent integration"
    fi
    
    # Check for TestAgent integration
    if grep -q "testAgent\|TestAgent" "$agent_path"; then
        echo -e "  ${GREEN}✓${NC} TestAgent integration"
    fi
}

# TestAgent-specific tests
test_testagent() {
    local agent_path=$1
    
    # Check for stage management
    if grep -q "stage\|Stage" "$agent_path"; then
        echo -e "  ${GREEN}✓${NC} Stage management"
    fi
    
    # Check for sub-agent integration
    if grep -q "unitTestAgent\|accessibilityAgent\|flowAgent\|uiTestAgent" "$agent_path"; then
        echo -e "  ${GREEN}✓${NC} Sub-agent orchestration"
    fi
}

# Run tests for all agents
for agent in "${AGENTS[@]}"; do
    test_agent "$agent"
done

# Summary
echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                    Test Summary                                ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo -e "Total Agents: ${TOTAL}"
echo -e "${GREEN}Passed: ${PASSED}${NC}"
if [[ $FAILED -gt 0 ]]; then
    echo -e "${RED}Failed: ${FAILED}${NC}"
else
    echo -e "Failed: ${FAILED}"
fi
echo

# Additional checks
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}Additional Checks${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Check for lib directory
if [[ -d "${SCRIPT_DIR}/lib" ]]; then
    echo -e "${GREEN}✓${NC} lib/ directory exists"
    lib_count=$(find "${SCRIPT_DIR}/lib" -name "*.sh" -type f | wc -l | tr -d ' ')
    echo -e "  Found ${lib_count} library files"
else
    echo -e "${YELLOW}⚠${NC}  lib/ directory not found"
fi

# Check for templates directory
if [[ -d "${SCRIPT_DIR}/templates" ]]; then
    echo -e "${GREEN}✓${NC} templates/ directory exists"
    tmpl_count=$(find "${SCRIPT_DIR}/templates" -type f | wc -l | tr -d ' ')
    echo -e "  Found ${tmpl_count} template files"
else
    echo -e "${YELLOW}⚠${NC}  templates/ directory not found"
fi

# Check for README
if [[ -f "${SCRIPT_DIR}/README.md" ]]; then
    echo -e "${GREEN}✓${NC} README.md exists"
else
    echo -e "${YELLOW}⚠${NC}  README.md not found"
fi

echo

# Exit with appropriate code
if [[ $FAILED -gt 0 ]]; then
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
else
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
fi
