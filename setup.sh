#!/usr/bin/env bash

# Root setup script for Eocon Foundation V1
# Verifies the macOS + Apple Silicon environment, installs required tooling,
# initializes git submodules, builds the Swift app and Rust orchestrator,
# runs BATS tests, and ensures agent scripts are executable.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_NAME="Eocon Foundation V1"

DRY_RUN=false
NON_INTERACTIVE=false
VERBOSE=false
SKIP_BUILDS=false

# ─────────────────────────────────────────────────────────────────────────────
# Logging
# ─────────────────────────────────────────────────────────────────────────────

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ${NC} $*"; }
log_success() { echo -e "${GREEN}✓${NC} $*"; }
log_warn() { echo -e "${YELLOW}⚠${NC} $*"; }
log_error() { echo -e "${RED}✗${NC} $*"; }
log_step() { echo -e "${CYAN}▶${NC} $*"; }

# ─────────────────────────────────────────────────────────────────────────────
# CLI
# ─────────────────────────────────────────────────────────────────────────────

usage() {
    cat << EOF
Setup script for ${PROJECT_NAME}

Usage: $0 [OPTIONS]

OPTIONS:
    --dry-run           Show what would be done without making changes
    -y, --yes           Non-interactive mode; proceed with defaults
    --non-interactive   Same as --yes
    --skip-builds       Skip Swift and Rust builds (verify deps only)
    --verbose           Show detailed build output
    -h, --help          Show this help message

EOF
    exit 0
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            -y|--yes|--non-interactive)
                NON_INTERACTIVE=true
                shift
                ;;
            --skip-builds)
                SKIP_BUILDS=true
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
                log_error "Unknown option: $1"
                usage
                ;;
        esac
    done
}

is_interactive() {
    [[ "$NON_INTERACTIVE" == "false" && "$DRY_RUN" == "false" && "${CI:-false}" != "true" && -t 0 ]]
}

run_or_dry() {
    local description="$1"
    shift
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] $description"
        echo "    would run: $*"
        return 0
    fi
    if [[ "$VERBOSE" == "true" ]]; then
        log_info "Running: $*"
        "$@"
    else
        "$@" >/dev/null 2>&1
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Platform checks
# ─────────────────────────────────────────────────────────────────────────────

check_platform() {
    log_step "Checking platform..."

    local os arch
    os=$(uname -s)
    arch=$(uname -m)

    if [[ "$os" != "Darwin" ]]; then
        log_error "This setup script supports macOS only (found: $os)"
        exit 1
    fi

    if [[ "$arch" != "arm64" ]]; then
        log_warn "Apple Silicon (arm64) is recommended (found: $arch)"
        if is_interactive; then
            read -rp "Continue anyway? [y/N] " reply
            [[ "$reply" =~ ^[Yy]$ ]] || exit 1
        else
            log_error "Aborting: non-interactive mode requires Apple Silicon"
            exit 1
        fi
    fi

    log_success "Platform OK: macOS $arch"
}

# ─────────────────────────────────────────────────────────────────────────────
# Dependency checks / installs
# ─────────────────────────────────────────────────────────────────────────────

check_homebrew() {
    log_step "Checking Homebrew..."
    if command -v brew &>/dev/null; then
        log_success "Homebrew: $(brew --version | head -n1)"
        return 0
    fi

    log_warn "Homebrew not found"
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would install Homebrew"
        return 0
    fi

    log_info "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Ensure PATH for Apple Silicon and Intel Macs
    if [[ -f /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -f /usr/local/bin/brew ]]; then
        eval "$(/usr/local/bin/brew shellenv)"
    fi

    log_success "Homebrew installed"
}

ensure_brew_pkg() {
    local pkg="$1"
    local bin="${2:-$1}"

    if command -v "$bin" &>/dev/null; then
        log_success "$pkg: $(command -v "$bin")"
        return 0
    fi

    log_warn "$pkg not found"
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would brew install $pkg"
        return 0
    fi

    log_info "Installing $pkg..."
    brew install "$pkg"
    log_success "$pkg installed"
}

check_xcode_tools() {
    log_step "Checking Xcode Command Line Tools..."
    if xcode-select -p &>/dev/null; then
        log_success "Xcode Command Line Tools: $(xcode-select -p)"
        return 0
    fi

    log_warn "Xcode Command Line Tools not found"
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would run xcode-select --install"
        return 0
    fi

    log_info "Installing Xcode Command Line Tools..."
    xcode-select --install
    log_warn "Please complete the Xcode Command Line Tools installation, then re-run this script"
    exit 2
}

check_swift() {
    log_step "Checking Swift..."
    if command -v swift &>/dev/null; then
        log_success "Swift: $(swift --version | head -n1)"
        return 0
    fi

    log_error "Swift not found. Install Xcode or Xcode Command Line Tools."
    exit 1
}

check_xcodebuild() {
    log_step "Checking xcodebuild..."
    if command -v xcodebuild &>/dev/null; then
        log_success "xcodebuild: $(xcodebuild -version | head -n1)"
        return 0
    fi

    log_error "xcodebuild not found. Install Xcode."
    exit 1
}

check_swiftlint() {
    log_step "Checking SwiftLint..."
    ensure_brew_pkg swiftlint swiftlint
}

check_xcodemake() {
    log_step "Checking xcodemake..."
    if command -v xcodemake &>/dev/null; then
        log_success "xcodemake: $(xcodemake --version 2>&1 | head -n1)"
        return 0
    fi

    log_warn "xcodemake not found"
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would download xcodemake to /usr/local/bin"
        return 0
    fi

    log_info "Installing xcodemake..."
    local tmp
    tmp=$(mktemp)
    if curl -fsSL https://github.com/subdigital/xcodemake/releases/latest/download/xcodemake -o "$tmp"; then
        chmod +x "$tmp"
        sudo mv "$tmp" /usr/local/bin/xcodemake
        log_success "xcodemake installed"
    else
        log_error "Failed to download xcodemake"
        rm -f "$tmp"
        return 1
    fi
}

check_axe() {
    log_step "Checking AXe..."
    if command -v axe &>/dev/null; then
        log_success "AXe: $(axe --version 2>&1 | head -n1)"
        return 0
    fi

    log_warn "AXe not found"
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would tap cameroncooke/axe and brew install axe"
        return 0
    fi

    log_info "Installing AXe..."
    brew tap cameroncooke/axe
    brew install axe
    log_success "AXe installed"
}

check_jq() {
    log_step "Checking jq..."
    ensure_brew_pkg jq jq
}

check_node() {
    log_step "Checking Node.js..."
    if command -v node &>/dev/null; then
        log_success "Node.js: $(node --version)"
        [[ -n "$(command -v npm 2>/dev/null)" ]] && log_success "npm: $(npm --version)"
        return 0
    fi

    log_warn "Node.js not found"
    ensure_brew_pkg node node
}

# ─────────────────────────────────────────────────────────────────────────────
# Submodules
# ─────────────────────────────────────────────────────────────────────────────

setup_submodules() {
    log_step "Setting up git submodules..."

    if [[ ! -d "$SCRIPT_DIR/.git" ]]; then
        log_warn "Not a git repository; skipping submodule setup"
        return 0
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would run: git submodule update --init --recursive"
        return 0
    fi

    git -C "$SCRIPT_DIR" submodule update --init --recursive
    log_success "Git submodules initialized"
}

# ─────────────────────────────────────────────────────────────────────────────
# Builds
# ─────────────────────────────────────────────────────────────────────────────

build_swift_app() {
    log_step "Building Swift app..."

    local swift_dir="$SCRIPT_DIR/Foundation"
    if [[ ! -d "$swift_dir" ]]; then
        log_warn "Foundation/ Swift app directory not found; skipping Swift build"
        return 0
    fi

    if [[ ! -d "$swift_dir/Foundation.xcodeproj" ]]; then
        log_warn "Foundation.xcodeproj not found; skipping Swift build"
        return 0
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would build Foundation.xcodeproj (scheme Foundation, macOS)"
        return 0
    fi

    log_info "Building Foundation.xcodeproj for macOS..."
    local build_flags=(
        -project "$swift_dir/Foundation.xcodeproj"
        -scheme Foundation
        -sdk macosx
        -destination 'platform=macOS'
        -configuration Debug
        CODE_SIGNING_ALLOWED=NO
    )

    if [[ "$VERBOSE" == "true" ]]; then
        xcodebuild "${build_flags[@]}" build
    else
        xcodebuild "${build_flags[@]}" build >/tmp/foundation_build.log 2>&1 || {
            log_error "Swift app build failed; see /tmp/foundation_build.log"
            tail -n 50 /tmp/foundation_build.log
            return 1
        }
    fi

    log_success "Swift app built"
}

build_rust_orchestrator() {
    log_step "Building Rust orchestrator..."

    local orch_dir="$SCRIPT_DIR/.Foundation/Agents/phases/phase5/orchestrator"
    if [[ ! -d "$orch_dir" ]]; then
        log_warn "Orchestrator directory not found; skipping Rust build"
        return 0
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would run: cargo build --release in $orch_dir"
        return 0
    fi

    if ! command -v cargo &>/dev/null; then
        log_warn "Rust/Cargo not found; installing via rustup..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        source "$HOME/.cargo/env"
    fi

    log_info "Building orch (release)..."
    local cargo_flags=(--release)
    [[ "$VERBOSE" == "false" ]] && cargo_flags+=(--quiet)

    if (cd "$orch_dir" && cargo build "${cargo_flags[@]}"); then
        log_success "Rust orchestrator built"
    else
        log_error "Rust orchestrator build failed"
        return 1
    fi

    local install_dir="$HOME/.local/bin"
    mkdir -p "$install_dir"
    ln -sf "$orch_dir/target/release/orch" "$install_dir/orch"
    log_success "orch symlinked to $install_dir/orch"

    if [[ ":$PATH:" != *":$install_dir:"* ]]; then
        log_warn "$install_dir is not in PATH; add: export PATH=\"$install_dir:\$PATH\""
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Tests
# ─────────────────────────────────────────────────────────────────────────────

run_bats_tests() {
    log_step "Running BATS tests..."

    local bats_dir="$SCRIPT_DIR/.Foundation/Agents/phases/phase5/tests/bats"
    local bats_bin="$bats_dir/lib/bats-core/bin/bats"

    if [[ ! -d "$bats_dir" ]]; then
        log_warn "BATS test directory not found; skipping tests"
        return 0
    fi

    if [[ ! -x "$bats_bin" ]]; then
        log_warn "bats-core submodule not available; run submodule setup first"
        return 0
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would run: $bats_bin $bats_dir"
        return 0
    fi

    log_info "Running BATS tests in $bats_dir..."
    if "$bats_bin" "$bats_dir"; then
        log_success "BATS tests passed"
    else
        log_error "BATS tests failed"
        return 1
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Permissions
# ─────────────────────────────────────────────────────────────────────────────

set_executable_permissions() {
    log_step "Setting executable permissions..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would chmod +x all .sh files under .Foundation/Agents and .Foundation/lib"
        return 0
    fi

    local count=0
    while IFS= read -r -d '' script; do
        chmod +x "$script"
        ((count++))
    done < <(find "$SCRIPT_DIR/.Foundation/Agents" "$SCRIPT_DIR/.Foundation/lib" -type f -name '*.sh' -print0 2>/dev/null || true)

    log_success "Executable permissions set on $count scripts"
}

# ─────────────────────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────────────────────

main() {
    parse_args "$@"

    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "  ${PROJECT_NAME} Setup"
    echo "═══════════════════════════════════════════════════════════"
    echo ""

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "Running in DRY RUN mode — no changes will be made"
        echo ""
    fi

    check_platform
    check_homebrew
    check_xcode_tools
    check_xcodebuild
    check_swift
    check_swiftlint
    check_xcodemake
    check_axe
    check_jq
    check_node
    setup_submodules
    set_executable_permissions

    if [[ "$SKIP_BUILDS" == "false" ]]; then
        build_swift_app
        build_rust_orchestrator
        run_bats_tests
    else
        log_info "Skipping builds and tests as requested"
    fi

    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "  Setup Complete"
    echo "═══════════════════════════════════════════════════════════"
    echo ""

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "Dry run finished; re-run without --dry-run to apply changes"
    else
        log_success "${PROJECT_NAME} is ready"
        echo ""
        echo "Next steps:"
        echo "  1. Review the Constitution: open .Foundation/Foundation-constitution/Foundation-Constitution.pdf"
        echo "  2. Run BuildAgent: .Foundation/Agents/phases/phase5/BuildAgent.sh --help"
        echo "  3. Run the orchestrator: orch --help"
    fi
    echo ""
}

main "$@"
