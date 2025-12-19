#!/bin/bash

# Cleanup Plans Structure to Match Constitution
# Removes non-constitutional files and enforces naming standards

set -e

PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
PLANS_DIR="${1:-${PROJECT_ROOT}/Plans}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

echo ""
echo "🧹 Cleaning Plans Directory to Match Constitution"
echo "=================================================="
echo ""

if [ ! -d "$PLANS_DIR" ]; then
    echo "❌ Plans directory not found: $PLANS_DIR"
    exit 1
fi

total_removed=0
total_renamed=0

for plan_dir in "$PLANS_DIR"/plan*/; do
    [ -d "$plan_dir" ] || continue
    
    plan_num=$(basename "$plan_dir" | grep -o '[0-9]*$')
    log_info "Processing plan$plan_num..."
    
    # --- Fix main plan file naming ---
    # Constitution requires: plan${plan_num}.md
    if [ -f "$plan_dir/Plan${plan_num}.md" ] && [ ! -f "$plan_dir/plan${plan_num}.md" ]; then
        log_warning "  Renaming Plan${plan_num}.md → plan${plan_num}.md"
        mv "$plan_dir/Plan${plan_num}.md" "$plan_dir/plan${plan_num}.md"
        ((total_renamed++))
    fi
    
    # --- Ensure test file exists and is named correctly ---
    # Constitution requires: test${plan_num}.md
    if [ ! -f "$plan_dir/test${plan_num}.md" ]; then
        # Try to find and rename a test file
        test_file=$(find "$plan_dir" -maxdepth 1 -type f -name "*est*.md" -o -name "*Test*.md" | head -n 1)
        if [ -n "$test_file" ]; then
            log_warning "  Renaming $(basename "$test_file") → test${plan_num}.md"
            mv "$test_file" "$plan_dir/test${plan_num}.md"
            ((total_renamed++))
        fi
    fi
    
    # --- Remove non-constitutional files at plan root ---
    # Constitution allows ONLY: plan${plan_num}.md, test${plan_num}.md, decision_log.md, waves/
    log_info "  Removing extra files..."
    removed_count=0
    
    while IFS= read -r -d '' file; do
        basename_file=$(basename "$file")
        case "$basename_file" in
            plan${plan_num}.md|test${plan_num}.md|decision_log.md)
                # Keep these files (constitutional)
                ;;
            *)
                log_warning "    Removing: $basename_file"
                rm "$file"
                ((removed_count++))
                ((total_removed++))
                ;;
        esac
    done < <(find "$plan_dir" -maxdepth 1 -type f -name "*.md" -print0)
    
    if [ $removed_count -eq 0 ]; then
        log_success "  ✓ Plan root is clean"
    else
        log_warning "  Removed $removed_count extra files"
    fi
    
    # --- Clean wave directories ---
    if [ -d "$plan_dir/waves" ]; then
        for wave_dir in "$plan_dir/waves"/wave*/; do
            [ -d "$wave_dir" ] || continue
            
            wave_num=$(basename "$wave_dir" | grep -o '[0-9]*$')
            
            # Constitution allows ONLY: subplan${wave_num}.md, subtest${wave_num}.md, unit_tests.md
            wave_removed=0
            
            while IFS= read -r -d '' file; do
                basename_file=$(basename "$file")
                case "$basename_file" in
                    subplan${wave_num}.md|subtest${wave_num}.md|unit_tests.md)
                        # Keep these files (constitutional)
                        ;;
                    *)
                        log_warning "    Removing wave${wave_num}/$basename_file"
                        rm "$file"
                        ((wave_removed++))
                        ((total_removed++))
                        ;;
                esac
            done < <(find "$wave_dir" -maxdepth 1 -type f -name "*.md" -print0)
            
            if [ $wave_removed -gt 0 ]; then
                log_warning "  Cleaned wave${wave_num}: removed $wave_removed files"
            fi
        done
    fi
done

echo ""
echo "=================================================="
log_success "Cleanup Complete!"
echo ""
echo "Summary:"
echo "  - Files renamed: $total_renamed"
echo "  - Files removed: $total_removed"
echo ""

if [ $total_removed -gt 0 ] || [ $total_renamed -gt 0 ]; then
    log_info "Plans directory now matches Constitutional requirements"
else
    log_success "Plans directory was already Constitutional!"
fi

echo ""

