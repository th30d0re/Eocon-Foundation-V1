#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_NAME="orch"
INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/bin}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

DRY_RUN=false
VERBOSE=false

usage() {
    cat << EOF
Setup Script for Foundation Orchestrator ($PROJECT_NAME)

Usage: $0 [OPTIONS]

OPTIONS:
    --dry-run           Show what would be done without making changes
    --install-dir DIR   Install directory (default: ~/.local/bin)
    --verbose           Show detailed cargo build output
    -h, --help          Show this help message

DESCRIPTION:
    Builds the Foundation Orchestrator from source and installs it to
    your PATH. Also checks for AI provider CLI tools.

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

log_step() {
    echo -e "${CYAN}▶${NC} $*"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --install-dir)
            INSTALL_DIR="$2"
            shift 2
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

# ── Checks ──────────────────────────────────────────────────────────

log_step "Checking prerequisites..."

if ! command -v cargo &> /dev/null; then
    log_error "Rust/Cargo is not installed"
    echo "  Install from: https://rustup.rs"
    echo "  Run: curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
    exit 1
fi

RUST_VERSION=$(rustc --version)
log_success "Found: $RUST_VERSION"

if [[ "$DRY_RUN" == "false" ]]; then
    mkdir -p "$INSTALL_DIR"
fi

# ── Build ───────────────────────────────────────────────────────────

log_step "Building $PROJECT_NAME..."

cd "$SCRIPT_DIR"

if [[ "$DRY_RUN" == "true" ]]; then
    echo "  [DRY RUN] Would run: cargo build --release"
else
    BUILD_FLAGS="--release"
    if [[ "$VERBOSE" == "false" ]]; then
        BUILD_FLAGS="$BUILD_FLAGS --quiet"
    fi
    cargo build $BUILD_FLAGS
fi

BINARY_PATH="$SCRIPT_DIR/target/release/$PROJECT_NAME"

if [[ "$DRY_RUN" == "false" && ! -f "$BINARY_PATH" ]]; then
    log_error "Build failed: $BINARY_PATH not found"
    exit 1
fi

log_success "Build complete"

# ── Install ─────────────────────────────────────────────────────────

log_step "Installing to $INSTALL_DIR..."

TARGET_LINK="$INSTALL_DIR/$PROJECT_NAME"

if [[ "$DRY_RUN" == "true" ]]; then
    echo "  [DRY RUN] Would symlink: $BINARY_PATH -> $TARGET_LINK"
else
    # Remove existing symlink or file
    if [[ -L "$TARGET_LINK" || -f "$TARGET_LINK" ]]; then
        rm "$TARGET_LINK"
    fi
    ln -sf "$BINARY_PATH" "$TARGET_LINK"
    log_success "Installed: $TARGET_LINK"
fi

# ── Check AI Provider CLIs ────────────────────────────────────────

log_step "Checking AI provider CLI tools..."

CLI_TOOLS=(
    "claude:anthropic"
    "kimi:moonshot"
    "ollama:ollama"
    "gemini:google"
    "codex:openai/codex"
    "cursor:cursor"
)

FOUND=0
MISSING=0

find_tool() {
    local name="$1"
    if command -v "$name" &> /dev/null; then
        echo "$name"
        return 0
    fi
    # Check common install locations
    local paths=(
        "$HOME/.local/bin/$name"
        "$HOME/.bun/bin/$name"
        "$HOME/.cargo/bin/$name"
        "/opt/homebrew/bin/$name"
        "/usr/local/bin/$name"
    )
    for p in "${paths[@]}"; do
        if [[ -x "$p" ]]; then
            echo "$p"
            return 0
        fi
    done
    return 1
}

for entry in "${CLI_TOOLS[@]}"; do
    tool="${entry%%:*}"
    provider="${entry#*:}"

    if path=$(find_tool "$tool"); then
        log_success "Found: $tool ($provider) at $path"
        ((FOUND++))
    else
        log_warn "Missing: $tool ($provider)"
        ((MISSING++))
    fi
done

# ── Summary ─────────────────────────────────────────────────────────

echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}  Foundation Orchestrator Setup Complete${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
echo ""

if [[ "$DRY_RUN" == "true" ]]; then
    echo "  Mode: ${YELLOW}dry-run${NC} (no changes made)"
else
    echo "  Binary: $TARGET_LINK"
    echo "  Version: $("$BINARY_PATH" --version 2>/dev/null || echo "unknown")"
fi

echo ""
echo "  CLI tools found:    $FOUND"
echo "  CLI tools missing:  $MISSING"
echo ""

if [[ $MISSING -gt 0 ]]; then
    echo -e "  ${YELLOW}Tip:${NC} Install missing CLIs to chat with those providers:"
    echo "    • claude   → https://docs.anthropic.com/en/docs/agents-and-tools/claude-code/overview"
    echo "    • kimi     → https://github.com/MoonshotAI/kimi-cli"
    echo "    • ollama   → https://ollama.com"
    echo "    • gemini   → npm install -g @google/gemini-cli"
    echo "    • codex    → npm install -g @openai/codex"
    echo "    • cursor   → https://cursor.com"
    echo ""
fi

# Check PATH
if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
    log_warn "$INSTALL_DIR is not in your PATH"
    echo "  Add this to your shell profile (~/.zshrc or ~/.bash_profile):"
    echo "    export PATH=\"$INSTALL_DIR:\$PATH\""
    echo ""
fi

echo "  Run '$PROJECT_NAME --help' to get started"
echo ""
