#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

BACKUP_DIR="${HOME}/.eocon-foundation-backup-$(date +%Y%m%d_%H%M%S)"
DRY_RUN=false

usage() {
    cat << EOF
Migration Script: v2.2 to v3.0

Usage: $0 [OPTIONS]

OPTIONS:
    --dry-run       Show what would be migrated without making changes
    --backup-dir    Specify custom backup directory (default: ~/.eocon-foundation-backup-TIMESTAMP)
    -h, --help      Show this help message

DESCRIPTION:
    Migrates Eocon Foundation Build System configuration from v2.2 to v3.0.
    
    This script will:
    1. Backup existing configuration
    2. Update session defaults format
    3. Migrate agent configurations
    4. Update environment variables
    5. Verify migration success

BACKUP:
    All existing files are backed up before migration.
    Rollback is supported via restore-backup.sh

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

backup_files() {
    log_info "Creating backup in: $BACKUP_DIR"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "  [DRY RUN] Would create directory: $BACKUP_DIR"
        return 0
    fi
    
    mkdir -p "$BACKUP_DIR"
    
    # Backup session defaults
    local session_file="${HOME}/.eocon-session-defaults.json"
    if [[ -f "$session_file" ]]; then
        cp "$session_file" "$BACKUP_DIR/"
        log_success "Backed up session defaults"
    fi
    
    # Backup defaults.conf
    local defaults_conf="${SCRIPT_DIR}/defaults.conf"
    if [[ -f "$defaults_conf" ]]; then
        cp "$defaults_conf" "$BACKUP_DIR/"
        log_success "Backed up defaults.conf"
    fi
    
    # Backup agent scripts
    for agent in BuildAgent BuildLint testRunner uiTestAgent accessibilityAgent flowAgent; do
        if [[ -f "${SCRIPT_DIR}/${agent}.sh" ]]; then
            cp "${SCRIPT_DIR}/${agent}.sh" "$BACKUP_DIR/"
        fi
    done
    log_success "Backed up agent scripts"
    
    # Create restore script
    cat > "$BACKUP_DIR/restore-backup.sh" << 'RESTORE_EOF'
#!/bin/bash
BACKUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "Restoring from backup: $BACKUP_DIR"
if [[ -f "$BACKUP_DIR/.eocon-session-defaults.json" ]]; then
    cp "$BACKUP_DIR/.eocon-session-defaults.json" "${HOME}/"
    echo "✓ Restored session defaults"
fi
echo "✓ Backup restored. Please restart your terminal."
RESTORE_EOF
    chmod +x "$BACKUP_DIR/restore-backup.sh"
    
    log_success "Backup complete. Restore script: $BACKUP_DIR/restore-backup.sh"
}

migrate_session_defaults() {
    log_info "Migrating session defaults..."
    
    local session_file="${HOME}/.eocon-session-defaults.json"
    
    if [[ ! -f "$session_file" ]]; then
        log_warn "No session defaults file found (this is OK for new installations)"
        return 0
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "  [DRY RUN] Would migrate: $session_file"
        return 0
    fi
    
    # Check if already v3.0 format
    if command -v jq &> /dev/null; then
        local version
        version=$(jq -r '.version // "2.2"' "$session_file")
        
        if [[ "$version" == "3.0" ]]; then
            log_success "Session defaults already in v3.0 format"
            return 0
        fi
        
        # Migrate to v3.0 format
        local temp_file
        temp_file=$(mktemp)
        
        jq '. + {version: "3.0", migrated: true, migration_date: now | strftime("%Y-%m-%d")}' \
            "$session_file" > "$temp_file"
        
        if [[ $? -eq 0 ]]; then
            mv "$temp_file" "$session_file"
            log_success "Migrated session defaults to v3.0"
        else
            log_error "Failed to migrate session defaults"
            rm -f "$temp_file"
            return 1
        fi
    else
        log_warn "jq not installed - skipping session defaults migration"
        log_warn "Install jq and re-run this script to complete migration"
    fi
    
    return 0
}

update_environment_variables() {
    log_info "Checking environment variables..."
    
    local shell_rc
    if [[ -n "${ZSH_VERSION:-}" ]]; then
        shell_rc="${HOME}/.zshrc"
    else
        shell_rc="${HOME}/.bashrc"
    fi
    
    log_info "Recommended environment variables for $shell_rc:"
    echo ""
    echo "  # Eocon Foundation Build System v3.0"
    echo "  export BUILDAGENT_FANCY_UI=true"
    echo "  export BUILDAGENT_THEME=dark  # or 'light'"
    echo "  export BUILDAGENT_SHOW_TIPS=true"
    echo ""
    
    if [[ "$DRY_RUN" == "false" ]]; then
        read -p "Add these to $shell_rc? [y/N] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            cat >> "$shell_rc" << 'ENV_EOF'

# Eocon Foundation Build System v3.0
export BUILDAGENT_FANCY_UI=true
export BUILDAGENT_THEME=dark
export BUILDAGENT_SHOW_TIPS=true
ENV_EOF
            log_success "Added environment variables to $shell_rc"
            log_info "Run: source $shell_rc"
        fi
    fi
}

check_dependencies() {
    log_info "Checking v3.0 dependencies..."
    
    local missing_deps=()
    
    if ! command -v xcodemake &> /dev/null; then
        missing_deps+=("xcodemake")
    fi
    
    if ! command -v axe &> /dev/null; then
        missing_deps+=("axe")
    fi
    
    if ! command -v jq &> /dev/null; then
        missing_deps+=("jq")
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_warn "Missing optional dependencies: ${missing_deps[*]}"
        log_info "Run setup.sh to install: ${SCRIPT_DIR}/setup.sh"
    else
        log_success "All dependencies installed"
    fi
}

verify_migration() {
    log_info "Verifying migration..."
    
    local issues=0
    
    # Check session defaults
    local session_file="${HOME}/.eocon-session-defaults.json"
    if [[ -f "$session_file" ]]; then
        if command -v jq &> /dev/null; then
            if jq empty "$session_file" 2>/dev/null; then
                log_success "Session defaults: Valid JSON"
            else
                log_error "Session defaults: Invalid JSON"
                ((issues++))
            fi
        fi
    fi
    
    # Check agent scripts exist
    for agent in BuildAgent testRunner uiTestAgent; do
        if [[ -f "${SCRIPT_DIR}/${agent}.sh" ]]; then
            log_success "Found: ${agent}.sh"
        else
            log_error "Missing: ${agent}.sh"
            ((issues++))
        fi
    done
    
    # Check library files
    for lib in session_store simulator log_capture axe_helpers; do
        if [[ -f "${SCRIPT_DIR}/lib/${lib}.sh" ]]; then
            log_success "Found: lib/${lib}.sh"
        else
            log_warn "Missing: lib/${lib}.sh (may be optional)"
        fi
    done
    
    echo ""
    if [[ $issues -eq 0 ]]; then
        log_success "Migration verification passed!"
        return 0
    else
        log_error "Migration verification found $issues issue(s)"
        return 1
    fi
}

show_whats_new() {
    cat << 'WHATSNEW'

╔════════════════════════════════════════════════════════════════╗
║                    What's New in v3.0                          ║
╚════════════════════════════════════════════════════════════════╝

✨ NEW FEATURES:

  • Incremental Builds
    Faster rebuild times with xcodemake integration
    
  • Enhanced UI Theming
    Beautiful terminal output with dark/light themes
    Enable with: export BUILDAGENT_FANCY_UI=true
    
  • Multi-Platform Support
    Build for iOS, macOS, tvOS, watchOS, visionOS
    
  • Session Management
    Save and reuse build configurations
    
  • Log Streaming
    Real-time log capture and analysis
    
  • UI Automation
    AXe integration for UI testing and accessibility
    
  • 71 MCP Tools
    Comprehensive XcodeBuildMCP integration

📚 DOCUMENTATION:

  • AGENT_REFERENCE.md - Complete agent flag reference
  • WORKFLOW_EXAMPLES.md - 10+ ready-to-use workflows
  • UI_CUSTOMIZATION.md - Theme and UI customization
  • TROUBLESHOOTING.md - Common issues and solutions

🔧 GETTING STARTED:

  1. Review: .Foundation/Docs/MIGRATION_V2_TO_V3.md
  2. Explore: .Foundation/Docs/WORKFLOW_EXAMPLES.md
  3. Customize: .Foundation/Docs/UI_CUSTOMIZATION.md

WHATSNEW
}

main() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --backup-dir)
                BACKUP_DIR="$2"
                shift 2
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
    echo "  Eocon Foundation v2.2 → v3.0 Migration"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "Running in DRY RUN mode"
        echo ""
    fi
    
    # Step 1: Backup
    backup_files
    echo ""
    
    # Step 2: Migrate session defaults
    migrate_session_defaults
    echo ""
    
    # Step 3: Check dependencies
    check_dependencies
    echo ""
    
    # Step 4: Update environment variables
    update_environment_variables
    echo ""
    
    # Step 5: Verify migration
    verify_migration
    echo ""
    
    # Show what's new
    show_whats_new
    
    echo ""
    log_success "Migration complete!"
    echo ""
    echo "Next steps:"
    echo "  1. Restart your terminal or run: source ~/.zshrc (or ~/.bashrc)"
    echo "  2. Review: ${SCRIPT_DIR}/../../../Docs/MIGRATION_V2_TO_V3.md"
    echo "  3. Try a workflow: ${SCRIPT_DIR}/../../../Docs/WORKFLOW_EXAMPLES.md"
    echo ""
    echo "If you encounter issues, restore from backup:"
    echo "  $BACKUP_DIR/restore-backup.sh"
    echo ""
}

main "$@"
