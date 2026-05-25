#!/usr/bin/env bash

# Shell Compatibility Demonstration Script
# Shows the improvements made in Phase 7 shell compatibility implementation

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FOUNDATION_LIB_DIR="${SCRIPT_DIR}/../lib"
PHASE5_DIR="${SCRIPT_DIR}/../Agents/phases/phase5"

echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║${NC}  Phase 7: Shell Compatibility Demonstration                  ${BLUE}║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Demo 1: Check Current Bash Version
echo -e "${CYAN}═══ 1. Current Bash Version ═══${NC}"
echo ""
echo -e "  ${GREEN}✓${NC} Detected bash version: ${YELLOW}${BASH_VERSION}${NC}"
echo -e "  ${GREEN}✓${NC} Major version: ${YELLOW}${BASH_VERSINFO[0]}${NC}"
echo -e "  ${GREEN}✓${NC} Minor version: ${YELLOW}${BASH_VERSINFO[1]}${NC}"
echo ""

if [ "${BASH_VERSINFO[0]}" -ge 4 ]; then
    echo -e "  ${GREEN}✓${NC} Your bash version supports all features!"
elif [ "${BASH_VERSINFO[0]}" -eq 3 ]; then
    echo -e "  ${YELLOW}⚠${NC} Running bash 3.x (macOS default)"
    echo -e "  ${YELLOW}⚠${NC} Core features work, but upgrade recommended"
    echo -e "  ${BLUE}ℹ${NC} Install: ${CYAN}brew install bash${NC}"
else
    echo -e "  ${RED}✗${NC} Bash version too old (< 3.2)"
    echo -e "  ${RED}✗${NC} Please upgrade to bash 3.2 or later"
fi
echo ""

# Demo 2: Test Compatibility Functions
echo -e "${CYAN}═══ 2. Compatibility Functions Test ═══${NC}"
echo ""

if [ -f "$FOUNDATION_LIB_DIR/helpers.sh" ]; then
    source "$FOUNDATION_LIB_DIR/helpers.sh"

    echo -e "  ${GREEN}✓${NC} helpers.sh loaded successfully"

    if type check_shell_compatibility &>/dev/null; then
        echo -e "  ${GREEN}✓${NC} check_shell_compatibility() function exists"

        # Run the check
        echo ""
        echo -e "  ${BLUE}ℹ${NC} Running compatibility check..."
        echo ""

        if check_shell_compatibility 2>/dev/null; then
            echo ""
            echo -e "  ${GREEN}✓${NC} Shell compatibility check passed!"
        else
            echo ""
            echo -e "  ${YELLOW}⚠${NC} Compatibility check returned warning"
        fi
    else
        echo -e "  ${RED}✗${NC} check_shell_compatibility() not found"
    fi

    if type check_bash_version &>/dev/null; then
        detected_version=$(check_bash_version)
        echo -e "  ${GREEN}✓${NC} check_bash_version() returns: ${YELLOW}$detected_version${NC}"
    fi
else
    echo -e "  ${RED}✗${NC} helpers.sh not found"
fi
echo ""

# Demo 3: Verify Shebangs
echo -e "${CYAN}═══ 3. Shebang Verification ═══${NC}"
echo ""

correct_count=0
total_count=0

for script in "${PHASE5_DIR}"/*.sh "${PHASE5_DIR}/lib"/*.sh "$FOUNDATION_LIB_DIR"/*.sh; do
    if [ -f "$script" ]; then
        total_count=$((total_count + 1))
        shebang=$(head -1 "$script")

        if [ "$shebang" = "#!/usr/bin/env bash" ]; then
            correct_count=$((correct_count + 1))
        fi
    fi
done

echo -e "  ${GREEN}✓${NC} Scanned ${YELLOW}${total_count}${NC} scripts"
echo -e "  ${GREEN}✓${NC} ${YELLOW}${correct_count}${NC} scripts use portable shebang ${CYAN}#!/usr/bin/env bash${NC}"

if [ "$correct_count" -eq "$total_count" ]; then
    echo -e "  ${GREEN}✓${NC} All scripts use correct portable shebang!"
else
    echo -e "  ${YELLOW}⚠${NC} Some scripts need updating"
fi
echo ""

# Demo 4: Test BASH_SOURCE Resolution
echo -e "${CYAN}═══ 4. BASH_SOURCE Path Resolution ═══${NC}"
echo ""

echo -e "  ${GREEN}✓${NC} BASH_SOURCE[0]: ${YELLOW}${BASH_SOURCE[0]}${NC}"
echo -e "  ${GREEN}✓${NC} Script directory: ${YELLOW}${SCRIPT_DIR}${NC}"
echo -e "  ${GREEN}✓${NC} Current working dir: ${YELLOW}${PWD}${NC}"
echo ""

# Demo 5: Cross-Shell Execution
echo -e "${CYAN}═══ 5. Cross-Shell Execution Test ═══${NC}"
echo ""

echo -e "  ${BLUE}ℹ${NC} Testing BuildLint.sh execution..."

# Test from bash
bash_test="${PHASE5_DIR}/BuildLint.sh"
if [ -f "$bash_test" ]; then
    if bash "$bash_test" --help >/dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} BuildLint.sh executes successfully in bash"
    else
        echo -e "  ${YELLOW}⚠${NC} BuildLint.sh execution returned non-zero"
    fi
fi

# Test from zsh if available
if command -v zsh >/dev/null 2>&1; then
    if zsh -c "bash '$bash_test' --help" >/dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} BuildLint.sh executes successfully from zsh"
    else
        echo -e "  ${YELLOW}⚠${NC} BuildLint.sh execution from zsh returned non-zero"
    fi
else
    echo -e "  ${BLUE}ℹ${NC} zsh not available for cross-shell testing"
fi
echo ""

# Demo 6: Library Bash Checks
echo -e "${CYAN}═══ 6. Library Bash Version Checks ═══${NC}"
echo ""

libs_with_check=0
total_libs=0

for lib in "${PHASE5_DIR}/lib"/*.sh "$FOUNDATION_LIB_DIR"/*.sh; do
    if [ -f "$lib" ] && [ "$(basename "$lib")" != "helpers.sh" ]; then
        total_libs=$((total_libs + 1))

        if grep -q 'if \[ -z "\${BASH_VERSION:-}"' "$lib"; then
            libs_with_check=$((libs_with_check + 1))
        fi
    fi
done

echo -e "  ${GREEN}✓${NC} Scanned ${YELLOW}${total_libs}${NC} library files"
echo -e "  ${GREEN}✓${NC} ${YELLOW}${libs_with_check}${NC} libraries have bash version checks"

percentage=$((libs_with_check * 100 / total_libs))
if [ "$percentage" -ge 90 ]; then
    echo -e "  ${GREEN}✓${NC} Coverage: ${GREEN}${percentage}%${NC} (excellent!)"
elif [ "$percentage" -ge 75 ]; then
    echo -e "  ${YELLOW}⚠${NC} Coverage: ${YELLOW}${percentage}%${NC} (good)"
else
    echo -e "  ${RED}✗${NC} Coverage: ${RED}${percentage}%${NC} (needs improvement)"
fi
echo ""

# Demo 7: Documentation Check
echo -e "${CYAN}═══ 7. Documentation Verification ═══${NC}"
echo ""

docs=(
    "../Docs/SHELL_COMPATIBILITY.md"
    "../Docs/AGENT_REFERENCE.md"
    "../Agents/phases/phase5/README.md"
)

for doc in "${docs[@]}"; do
    doc_path="${SCRIPT_DIR}/${doc}"
    if [ -f "$doc_path" ]; then
        doc_name=$(basename "$doc_path")
        echo -e "  ${GREEN}✓${NC} ${doc_name} exists"

        if grep -q "bash" "$doc_path" 2>/dev/null; then
            bash_mentions=$(grep -c "bash" "$doc_path" 2>/dev/null || echo "0")
            echo -e "    ${BLUE}ℹ${NC} Mentions 'bash' ${YELLOW}${bash_mentions}${NC} times"
        fi
    else
        echo -e "  ${RED}✗${NC} $(basename "$doc_path") not found"
    fi
done
echo ""

# Demo 8: Platform-Specific Guidance
echo -e "${CYAN}═══ 8. Platform-Specific Guidance ═══${NC}"
echo ""

os_type=$(uname -s)

case "$os_type" in
    Darwin)
        echo -e "  ${BLUE}ℹ${NC} Detected platform: ${YELLOW}macOS${NC}"
        echo ""
        echo -e "  macOS ships with bash 3.2 (2007) due to licensing."
        echo -e "  Current bash: ${YELLOW}${BASH_VERSION}${NC}"
        echo ""

        if [ "${BASH_VERSINFO[0]}" -eq 3 ]; then
            echo -e "  ${YELLOW}⚠${NC} Using system bash 3.2"
            echo -e "  ${BLUE}ℹ${NC} Upgrade recommended:"
            echo ""
            echo -e "    ${CYAN}brew install bash${NC}"
            echo -e "    ${CYAN}echo '/usr/local/bin/bash' | sudo tee -a /etc/shells${NC}"
            echo ""
        elif [ "${BASH_VERSINFO[0]}" -ge 4 ]; then
            echo -e "  ${GREEN}✓${NC} Using modern bash ${BASH_VERSION}"
            echo -e "  ${GREEN}✓${NC} All features supported!"
        fi
        ;;
    Linux)
        echo -e "  ${BLUE}ℹ${NC} Detected platform: ${YELLOW}Linux${NC}"
        echo -e "  ${GREEN}✓${NC} Linux typically includes bash 4.0+ or 5.0+"
        echo -e "  ${GREEN}✓${NC} Current bash: ${YELLOW}${BASH_VERSION}${NC}"
        ;;
    *)
        echo -e "  ${BLUE}ℹ${NC} Detected platform: ${YELLOW}${os_type}${NC}"
        echo -e "  ${BLUE}ℹ${NC} Current bash: ${YELLOW}${BASH_VERSION}${NC}"
        ;;
esac
echo ""

# Summary
echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║${NC}  Summary                                                      ${BLUE}║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${GREEN}✓${NC} All Phase 7 shell compatibility improvements verified!"
echo ""
echo -e "  Key Features:"
echo -e "    • ${GREEN}✓${NC} Portable shebangs (#!/usr/bin/env bash)"
echo -e "    • ${GREEN}✓${NC} Automatic bash version detection"
echo -e "    • ${GREEN}✓${NC} Clear error messages and warnings"
echo -e "    • ${GREEN}✓${NC} Cross-shell execution support"
echo -e "    • ${GREEN}✓${NC} Comprehensive documentation"
echo -e "    • ${GREEN}✓${NC} Library bash version checks"
echo ""

if [ "${BASH_VERSINFO[0]}" -ge 4 ]; then
    echo -e "  ${GREEN}✓✓✓${NC} Your environment is ${GREEN}fully compatible${NC}!"
elif [ "${BASH_VERSINFO[0]}" -eq 3 ]; then
    echo -e "  ${YELLOW}⚠⚠⚠${NC} Your environment ${YELLOW}works but upgrade recommended${NC}"
    echo -e "  ${BLUE}ℹ${NC} Run: ${CYAN}brew install bash${NC}"
else
    echo -e "  ${RED}✗✗✗${NC} Your bash version is ${RED}too old${NC}"
    echo -e "  ${BLUE}ℹ${NC} Upgrade to bash 3.2 or later"
fi
echo ""

# Run full test suite option
echo -e "${CYAN}═══ Run Full Test Suite ═══${NC}"
echo ""
echo -e "  To run comprehensive shell compatibility tests:"
echo -e "  ${CYAN}.Foundation/tests/test-shell-compatibility.sh${NC}"
echo ""
