#!/usr/bin/env bash
# Test all Foundation Phase 0-4 agents.
# Exit codes: 0 = all passed, 1 = one or more checks failed.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASSED=0
FAILED=0
TOTAL=0

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

AGENTS="
phase0/ConstitutionAgent.sh
phase1/PlannerAgent.sh
phase2/QuestionAgent.sh
phase3/OptimizationAgent.sh
phase4/StagesAgent.sh
"

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║           Phase 0-4 Agent Test Suite                          ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo

check_agent_help() {
    local agent_rel="$1"
    local agent_path="${SCRIPT_DIR}/${agent_rel}"
    local output

    TOTAL=$((TOTAL + 1))
    echo -e "${YELLOW}Testing --help: ${agent_rel}${NC}"

    if [ ! -x "$agent_path" ]; then
        echo -e "${RED}✗ FAIL: not executable or missing: ${agent_rel}${NC}"
        FAILED=$((FAILED + 1))
        return
    fi

    if ! output="$("$agent_path" --help 2>&1)"; then
        echo -e "${RED}✗ FAIL: --help exited non-zero${NC}"
        FAILED=$((FAILED + 1))
        return
    fi

    for flag in --project-dir --ai-provider --model --yolo --dry-run --verbose --help --version; do
        if ! printf '%s\n' "$output" | grep -q -- "$flag"; then
            echo -e "${RED}✗ FAIL: help missing ${flag}${NC}"
            FAILED=$((FAILED + 1))
            return
        fi
    done

    echo -e "${GREEN}✓ PASS: ${agent_rel} help${NC}"
    PASSED=$((PASSED + 1))
}

for agent in $AGENTS; do
    check_agent_help "$agent"
done

echo
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}shellcheck: phase0-4/*.sh shared/*.sh${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
TOTAL=$((TOTAL + 1))
if ! command -v shellcheck >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠ shellcheck not installed — skipping${NC}"
    PASSED=$((PASSED + 1))
else
    SC_FILES=""
    for file in "$SCRIPT_DIR"/phase[0-4]/*.sh "$SCRIPT_DIR"/shared/*.sh; do
        [ -f "$file" ] || continue
        SC_FILES="${SC_FILES}
${file}"
    done

    SC_ERRORS=0
    printf '%s\n' "$SC_FILES" | while IFS= read -r file; do
        [ -n "$file" ] || continue
        if shellcheck -S warning -e SC1090,SC1091,SC2154,SC2034 "$file"; then
            echo -e "  ${GREEN}✓${NC} ${file#$SCRIPT_DIR/}"
        else
            echo -e "  ${RED}✗${NC} ${file#$SCRIPT_DIR/}"
            exit 2
        fi
    done || SC_ERRORS=1

    if [ "$SC_ERRORS" -eq 0 ]; then
        echo -e "${GREEN}✓ PASS: shellcheck${NC}"
        PASSED=$((PASSED + 1))
    else
        echo -e "${RED}✗ FAIL: shellcheck warnings/errors${NC}"
        FAILED=$((FAILED + 1))
    fi
fi

echo
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}bats: tests/bats/*.bats${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
TOTAL=$((TOTAL + 1))
BATS_BIN="${SCRIPT_DIR}/phase5/tests/bats/lib/bats-core/bin/bats"
BATS_DIR="${SCRIPT_DIR}/tests/bats"
if [ ! -x "$BATS_BIN" ]; then
    echo -e "${RED}✗ FAIL: bats-core not found at ${BATS_BIN}${NC}"
    FAILED=$((FAILED + 1))
elif ! ls "$BATS_DIR"/*.bats >/dev/null 2>&1; then
    echo -e "${RED}✗ FAIL: no bats files found in ${BATS_DIR}${NC}"
    FAILED=$((FAILED + 1))
else
    if "$BATS_BIN" "$BATS_DIR"/*.bats; then
        echo -e "${GREEN}✓ PASS: bats${NC}"
        PASSED=$((PASSED + 1))
    else
        echo -e "${RED}✗ FAIL: bats${NC}"
        FAILED=$((FAILED + 1))
    fi
fi

echo
echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                    Test Summary                               ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo "Total Checks: $TOTAL"
echo -e "${GREEN}Passed: $PASSED${NC}"
if [ "$FAILED" -gt 0 ]; then
    echo -e "${RED}Failed: $FAILED${NC}"
    exit 1
fi
echo "Failed: 0"
echo -e "${GREEN}All tests passed!${NC}"
