#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

DRY_RUN=false
VERBOSE=false
NON_INTERACTIVE=false

usage() {
    cat << EOF
Setup Script for Eocon Foundation Build System

Usage: $0 [OPTIONS]

OPTIONS:
    --dry-run           Show what would be installed without installing
    --yes, -y           Non-interactive mode, proceed with default answers
    --non-interactive   Non-interactive mode (same as --yes)
    --verbose           Show detailed output
    -h, --help          Show this help message

DESCRIPTION:
    Automatically detects and installs all dependencies required for the
    Eocon Foundation Build System including XcodeBuildMCP integration.

DEPENDENCIES CHECKED:
    - Xcode and Command Line Tools
    - xcodemake (incremental build tool)
    - AXe (UI automation tool)
    - jq (JSON processor)
    - Node.js (for XcodeBuildMCP)

EOF
    exit 0
}

log_info() {
    echo -e "${BLUE}ℹ${NC} $*"
}

log_success() {
    echo -e "${GREEN}✓${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}⚠${NC} $*"
}

log_error() {
    echo -e "${RED}✗${NC} $*"
}

# Check if running in non-interactive mode
is_interactive() {
    # Return false if --yes/--non-interactive flag set
    if [[ "$NON_INTERACTIVE" == "true" ]]; then
        return 1
    fi

    # Return false if CI environment detected
    if [[ "${CI:-false}" == "true" ]]; then
        return 1
    fi

    # Return false if not a TTY
    if [[ ! -t 0 ]]; then
        return 1
    fi

    # Return false if in dry-run mode
    if [[ "$DRY_RUN" == "true" ]]; then
        return 1
    fi

    return 0
}

check_xcode() {
    log_info "Checking Xcode installation..."

    if ! command -v xcodebuild &> /dev/null; then
        log_error "Xcode is not installed"
        echo "  Please install Xcode from the App Store"
        return 1
    fi

    local xcode_version
    xcode_version=$(xcodebuild -version | head -n1)
    log_success "Found: $xcode_version"

    # Check for Command Line Tools
    if ! xcode-select -p &> /dev/null; then
        log_warn "Command Line Tools not found"
        echo "  Installing Command Line Tools..."
        if [[ "$DRY_RUN" == "false" ]]; then
            xcode-select --install
        else
            echo "  [DRY RUN] Would run: xcode-select --install"
        fi
        return 2
    fi

    log_success "Command Line Tools installed"
    return 0
}

check_homebrew() {
    log_info "Checking Homebrew..."

    if ! command -v brew &> /dev/null; then
        log_warn "Homebrew not found"
        echo "  Install from: https://brew.sh"
        echo "  Run: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        return 1
    fi

    local brew_version
    brew_version=$(brew --version | head -n1)
    log_success "Found: $brew_version"
    return 0
}

check_xcodemake() {
    log_info "Checking xcodemake..."

    if command -v xcodemake &> /dev/null; then
        local version
        version=$(xcodemake --version 2>&1 | head -n1 || echo "unknown")
        log_success "Found: xcodemake $version"
        return 0
    fi

    log_warn "xcodemake not found"
    return 1
}

install_xcodemake() {
    log_info "Installing xcodemake..."

    local install_dir="/usr/local/bin"
    local download_url="https://github.com/subdigital/xcodemake/releases/latest/download/xcodemake"

    if [[ "$DRY_RUN" == "true" ]]; then
        echo "  [DRY RUN] Would download from: $download_url"
        echo "  [DRY RUN] Would install to: $install_dir/xcodemake"
        return 0
    fi

    local temp_file
    temp_file=$(mktemp)

    if curl -fsSL "$download_url" -o "$temp_file"; then
        chmod +x "$temp_file"
        if sudo mv "$temp_file" "$install_dir/xcodemake"; then
            log_success "xcodemake installed successfully"
            return 0
        else
            log_error "Failed to install xcodemake to $install_dir"
            rm -f "$temp_file"
            return 1
        fi
    else
        log_error "Failed to download xcodemake"
        rm -f "$temp_file"
        return 1
    fi
}

check_axe() {
    log_info "Checking AXe..."

    if command -v axe &> /dev/null; then
        local version
        version=$(axe --version 2>&1 || echo "unknown")
        log_success "Found: AXe $version"
        return 0
    fi

    log_warn "AXe not found"
    return 1
}

install_axe() {
    log_info "Installing AXe..."

    if ! command -v brew &> /dev/null; then
        log_error "Homebrew required to install AXe"
        return 1
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        echo "  [DRY RUN] Would run: brew tap cameroncooke/axe"
        echo "  [DRY RUN] Would run: brew install axe"
        return 0
    fi

    if brew tap cameroncooke/axe && brew install axe; then
        log_success "AXe installed successfully"
        return 0
    else
        log_error "Failed to install AXe"
        return 1
    fi
}

check_jq() {
    log_info "Checking jq..."

    if command -v jq &> /dev/null; then
        local version
        version=$(jq --version 2>&1)
        log_success "Found: $version"
        return 0
    fi

    log_warn "jq not found"
    return 1
}

install_jq() {
    log_info "Installing jq..."

    if ! command -v brew &> /dev/null; then
        log_error "Homebrew required to install jq"
        return 1
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        echo "  [DRY RUN] Would run: brew install jq"
        return 0
    fi

    if brew install jq; then
        log_success "jq installed successfully"
        return 0
    else
        log_error "Failed to install jq"
        return 1
    fi
}

check_node() {
    log_info "Checking Node.js..."

    if command -v node &> /dev/null; then
        local version
        version=$(node --version)
        log_success "Found: Node.js $version"

        if command -v npm &> /dev/null; then
            local npm_version
            npm_version=$(npm --version)
            log_success "Found: npm $npm_version"
        fi
        return 0
    fi

    log_warn "Node.js not found"
    return 1
}

install_node() {
    log_info "Installing Node.js..."

    if ! command -v brew &> /dev/null; then
        log_error "Homebrew required to install Node.js"
        return 1
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        echo "  [DRY RUN] Would run: brew install node"
        return 0
    fi

    if brew install node; then
        log_success "Node.js installed successfully"
        return 0
    else
        log_error "Failed to install Node.js"
        return 1
    fi
}

install_agents() {
    log_info "Installing Foundation agents to PATH (/usr/local/bin)..."

    local agents=(
        BuildAgent.sh
        BuildLint.sh
        BuildVerify.sh
        testAgent.sh
        testRunner.sh
        unitTestAgent.sh
        accessibilityAgent.sh
        flowAgent.sh
        uiTestAgent.sh
        argentRuntimeAgent.sh
    )

    local install_dir="/usr/local/bin"
    local installed=0
    local skipped=0
    local failed=0

    for agent in "${agents[@]}"; do
        local src="${SCRIPT_DIR}/${agent}"
        local dst="${install_dir}/${agent}"

        if [[ ! -f "$src" ]]; then
            log_warn "  $agent: source not found, skipping"
            ((skipped++))
            continue
        fi

        if [[ "$DRY_RUN" == "true" ]]; then
            echo "  [DRY RUN] Would symlink: $dst -> $src"
            continue
        fi

        # Remove stale symlink or file if it points elsewhere
        if [[ -L "$dst" ]]; then
            local current_target
            current_target=$(readlink "$dst")
            if [[ "$current_target" == "$src" ]]; then
                log_success "  $agent: already linked"
                ((skipped++))
                continue
            fi
            sudo rm -f "$dst"
        fi

        if sudo ln -sf "$src" "$dst"; then
            log_success "  $agent: linked"
            ((installed++))
        else
            log_error "  $agent: failed to link (check sudo permissions)"
            ((failed++))
        fi
    done

    echo ""
    if [[ "$DRY_RUN" == "false" ]]; then
        echo "  Agents: $installed installed, $skipped already up-to-date, $failed failed"
    fi

    [[ $failed -eq 0 ]] && return 0 || return 1
}

# Symlink agents to ~/.local/bin with clean names (no sudo, matches BuildAgent/testAgent pattern)
install_agents_local() {
    log_info "Installing Foundation agents to PATH (~/.local/bin)..."

    local install_dir="${HOME}/.local/bin"
    mkdir -p "$install_dir"

    # name_on_path:source_script
    local agents=(
        BuildAgent:BuildAgent.sh
        BuildLint:BuildLint.sh
        BuildVerify:BuildVerify.sh
        testAgent:testAgent.sh
        argentRuntimeAgent:argentRuntimeAgent.sh
    )

    local installed=0
    local skipped=0
    local failed=0

    for entry in "${agents[@]}"; do
        local name="${entry%%:*}"
        local script="${entry##*:}"
        local src="${SCRIPT_DIR}/${script}"
        local dst="${install_dir}/${name}"

        if [[ ! -f "$src" ]]; then
            log_warn "  $name: source not found ($script), skipping"
            ((skipped++))
            continue
        fi

        if [[ "$DRY_RUN" == "true" ]]; then
            echo "  [DRY RUN] Would symlink: $dst -> $src"
            continue
        fi

        if [[ -L "$dst" ]] && [[ "$(readlink "$dst")" == "$src" ]]; then
            log_success "  $name: already linked"
            ((skipped++))
            continue
        fi

        if ln -sf "$src" "$dst"; then
            log_success "  $name: linked"
            ((installed++))
        else
            log_error "  $name: failed to link"
            ((failed++))
        fi
    done

    echo ""
    if [[ "$DRY_RUN" == "false" ]]; then
        echo "  Local agents: $installed installed, $skipped already up-to-date, $failed failed"
    fi

    [[ $failed -eq 0 ]] && return 0 || return 1
}

check_agents_on_path() {
    log_info "Checking agents on PATH..."

    local agents=(BuildAgent testAgent argentRuntimeAgent BuildAgent.sh BuildLint.sh testAgent.sh argentRuntimeAgent.sh)
    local all_found=true

    for agent in "${agents[@]}"; do
        if command -v "$agent" &>/dev/null; then
            log_success "  $agent: $(command -v "$agent")"
        else
            log_warn "  $agent: not on PATH"
            all_found=false
        fi
    done

    $all_found && return 0 || return 1
}

check_xcodebuildmcp() {
    log_info "Checking XcodeBuildMCP..."

    local xcodemcp_path="${SCRIPT_DIR}/../../../../../XcodeBuildMCP"

    if [[ -d "$xcodemcp_path" ]]; then
        log_success "Found XcodeBuildMCP at: $xcodemcp_path"

        if [[ -f "$xcodemcp_path/package.json" ]]; then
            if [[ -d "$xcodemcp_path/node_modules" ]]; then
                log_success "Dependencies installed"
                return 0
            else
                log_warn "Dependencies not installed"
                return 1
            fi
        fi
    else
        log_warn "XcodeBuildMCP not found at expected location"
    fi

    return 1
}

install_xcodebuildmcp() {
    log_info "Installing XcodeBuildMCP dependencies..."

    local xcodemcp_path="${SCRIPT_DIR}/../../../../../XcodeBuildMCP"

    if [[ ! -d "$xcodemcp_path" ]]; then
        log_error "XcodeBuildMCP directory not found"
        echo "  Clone from: https://github.com/yourusername/XcodeBuildMCP"
        return 1
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        echo "  [DRY RUN] Would run: npm install in $xcodemcp_path"
        return 0
    fi

    if (cd "$xcodemcp_path" && npm install); then
        log_success "XcodeBuildMCP dependencies installed"
        return 0
    else
        log_error "Failed to install XcodeBuildMCP dependencies"
        return 1
    fi
}

run_smoke_tests() {
    log_info "Running smoke tests..."

    local tests_passed=0
    local tests_failed=0

    # Test 1: xcodebuild
    if command -v xcodebuild &> /dev/null; then
        ((tests_passed++))
        log_success "xcodebuild: OK"
    else
        ((tests_failed++))
        log_error "xcodebuild: FAILED"
    fi

    # Test 2: xcodemake
    if command -v xcodemake &> /dev/null; then
        ((tests_passed++))
        log_success "xcodemake: OK"
    else
        ((tests_failed++))
        log_warn "xcodemake: NOT FOUND (optional)"
    fi

    # Test 3: AXe
    if command -v axe &> /dev/null; then
        ((tests_passed++))
        log_success "axe: OK"
    else
        ((tests_failed++))
        log_warn "axe: NOT FOUND (optional for UI testing)"
    fi

    # Test 4: jq
    if command -v jq &> /dev/null; then
        ((tests_passed++))
        log_success "jq: OK"
    else
        ((tests_failed++))
        log_error "jq: FAILED"
    fi

    # Test 5: Session store
    if [[ -f "${SCRIPT_DIR}/lib/session_store.sh" ]]; then
        ((tests_passed++))
        log_success "session_store.sh: OK"
    else
        ((tests_failed++))
        log_error "session_store.sh: NOT FOUND"
    fi

    # Test 6: Core agents on PATH
    local path_agents=(BuildAgent testAgent argentRuntimeAgent)
    for agent in "${path_agents[@]}"; do
        if command -v "$agent" &>/dev/null; then
            ((tests_passed++))
            log_success "$agent on PATH: OK"
        else
            ((tests_failed++))
            log_warn "$agent: not on PATH (run setup.sh to install)"
        fi
    done

    echo ""
    echo "Smoke tests: $tests_passed passed, $tests_failed issues"

    return 0
}

verify_installation() {
    log_info "Verifying installation..."

    local all_ok=true

    check_xcode || all_ok=false
    check_homebrew || all_ok=false
    check_xcodemake || all_ok=false
    check_axe || all_ok=false
    check_jq || all_ok=false
    check_node || all_ok=false
    check_xcodebuildmcp || all_ok=false

    echo ""
    run_smoke_tests

    echo ""
    if [[ "$all_ok" == "true" ]]; then
        log_success "All dependencies verified!"
        return 0
    else
        log_warn "Some dependencies missing or not installed"
        echo ""
        echo "Run without --dry-run to install missing dependencies"
        return 1
    fi
}

generate_report() {
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "  Installation Report"
    echo "═══════════════════════════════════════════════════════════"
    echo ""

    verify_installation

    echo ""
    echo "Next Steps:"
    echo "  1. Review the GETTING_STARTED guide"
    echo "  2. Set up your first project with session defaults"
    echo "  3. Try a sample workflow from WORKFLOW_EXAMPLES.md"
    echo ""
}

main() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --yes|-y|--non-interactive)
                NON_INTERACTIVE=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            -h|--help)
                usage
                ;;
            *)
                echo "Unknown option: $1"
                usage
                ;;
        esac
    done

    echo "═══════════════════════════════════════════════════════════"
    echo "  Eocon Foundation Build System Setup"
    echo "═══════════════════════════════════════════════════════════"
    echo ""

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "Running in DRY RUN mode - no changes will be made"
        echo ""
    fi

    if [[ "$NON_INTERACTIVE" == "true" ]] || [[ "${CI:-false}" == "true" ]] || [[ ! -t 0 ]]; then
        NON_INTERACTIVE=true
        log_info "Running in NON-INTERACTIVE mode - using default answers"
        echo ""
    fi

    # Check required dependencies
    check_xcode || true
    check_homebrew || true

    # Check and install optional dependencies
    if ! check_xcodemake; then
        if is_interactive; then
            read -p "Install xcodemake for incremental builds? [Y/n] " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
                install_xcodemake || true
            fi
        else
            log_info "Auto-installing xcodemake (non-interactive mode)"
            install_xcodemake || true
        fi
    fi

    if ! check_axe; then
        if is_interactive; then
            read -p "Install AXe for UI automation? [Y/n] " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
                install_axe || true
            fi
        else
            log_info "Auto-installing AXe (non-interactive mode)"
            install_axe || true
        fi
    fi

    if ! check_jq; then
        if is_interactive; then
            read -p "Install jq for JSON processing? [Y/n] " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
                install_jq || true
            fi
        else
            log_info "Auto-installing jq (non-interactive mode)"
            install_jq || true
        fi
    fi

    if ! check_node; then
        if is_interactive; then
            read -p "Install Node.js for XcodeBuildMCP? [Y/n] " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
                install_node || true
            fi
        else
            log_info "Auto-installing Node.js (non-interactive mode)"
            install_node || true
        fi
    fi

    if ! check_xcodebuildmcp; then
        if check_node; then
            if is_interactive; then
                read -p "Install XcodeBuildMCP dependencies? [Y/n] " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
                    install_xcodebuildmcp || true
                fi
            else
                log_info "Auto-installing XcodeBuildMCP dependencies (non-interactive mode)"
                install_xcodebuildmcp || true
            fi
        fi
    fi

    # Install agents to PATH
    echo ""
    install_agents_local || true
    if ! check_agents_on_path; then
        if is_interactive; then
            read -p "Symlink all agents to /usr/local/bin (requires sudo)? [Y/n] " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
                install_agents || true
            fi
        else
            log_info "Auto-installing agents to PATH (non-interactive mode)"
            install_agents || true
        fi
    fi

    generate_report
}

main "$@"
