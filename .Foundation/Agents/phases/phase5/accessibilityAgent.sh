#!/usr/bin/env bash

# Accessibility Agent
# Analyzes and enhances SwiftUI views with accessibility modifiers
# Based on Foundation methodology and BuildAgent patterns
#
# Exit Codes:
#   0  - Success
#   10 - Build failed after max retries
#   11 - Misconfiguration
#   12 - AI provider error

set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"
FOUNDATION_LIB_DIR="$(cd "${SCRIPT_DIR}/../../../lib" && pwd)"

# Load Foundation helpers and check shell compatibility
HELPERS_LIB="${FOUNDATION_LIB_DIR}/helpers.sh"
if [ -f "$HELPERS_LIB" ]; then
    # shellcheck disable=SC1090
    source "$HELPERS_LIB"

    # Check shell compatibility
    if type check_shell_compatibility &>/dev/null; then
        check_shell_compatibility || exit 11
    fi
fi

# Source utility libraries
# shellcheck disable=SC1091
source "${LIB_DIR}/testUtils.sh"
# shellcheck disable=SC1091
source "${LIB_DIR}/testContextPaths.sh"
# shellcheck disable=SC1091
source "${LIB_DIR}/simulator_prepare.sh"

# Set log prefix for this agent
LOG_PREFIX="[ACCESSIBILITY]"

# Configuration variables
PROJECT_PATH=""
SCHEME=""
FILES_PATTERN=""
SCAN_ONLY="${SCAN_ONLY:-false}"
AUDIT_MODE="${AUDIT_MODE:-false}"
USE_DOCS="${USE_DOCS:-true}"
AI_PROVIDER="${AI_PROVIDER:-cursor}"
YOLO_MODE="${YOLO_MODE:-false}"
MAX_RETRIES="${MAX_RETRIES:-3}"
ARTIFACTS_DIR="${ARTIFACTS_DIR:-./Artifacts}"
VERBOSE="${VERBOSE:-false}"
DRY_RUN="${DRY_RUN:-false}"

# AXe live validation variables
USE_AXE="${USE_AXE:-false}"
VALIDATE_LIVE="${VALIDATE_LIVE:-false}"
AXE_AUDIT="${AXE_AUDIT:-false}"
CHECK_TOUCH_TARGETS="${CHECK_TOUCH_TARGETS:-false}"
SIMULATOR_NAME=""
APP_PATH=""
BUNDLE_ID=""
SIMULATOR_UDID=""

# State variables
VIEWS_SCANNED=0
VIEWS_MODIFIED=0
IDENTIFIERS_ADDED=0
MISSING_ACCESSIBILITY=()

# ─────────────────────────────────────────────────────────────────────────────
# Usage
# ─────────────────────────────────────────────────────────────────────────────

show_usage() {
    cat << EOF
Accessibility Agent - SwiftUI Accessibility Compliance

DESCRIPTION:
    Analyzes SwiftUI views and adds accessibility modifiers for
    VoiceOver support and UI testing capabilities.

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --project <path>        Xcode project/workspace (auto-detect if not provided)
    --scheme <name>         Target scheme (auto-detect if not provided)
    --files <pattern>       Specific SwiftUI views to process (glob pattern)
    --scan-only             Analyze without making modifications
    --audit                 Generate accessibility audit report
    --use-docs              Use Cursor @docs references (default: true)
    --no-docs               Disable documentation references
    --ai-provider <name>    AI provider: cursor, claude, codex, gemini, aider, letta
    --yolo                  Auto-approve AI changes (unattended mode)
    --max-retries <n>       Maximum retry attempts (default: 3)
    --artifacts-dir <path>  Output directory for artifacts
    --verbose               Enable verbose output
    --dry-run               Show what would be done without executing

  AXE INTEGRATION:
    --use-axe               Enable AXe UI automation
    --validate-live         Compare code accessibility vs running app
    --axe-audit             Generate audit from live hierarchy
    --check-touch-targets   Verify 44x44pt minimum sizes
    --simulator-name <name> Simulator to use
    --app-path <path>       Path to .app bundle
    --bundle-id <id>        App bundle identifier

    --help                  Show this help message

ACCESSIBILITY MODIFIERS ADDED:
    - accessibilityIdentifier   For UI testing element identification
    - accessibilityLabel        For VoiceOver announcements
    - accessibilityHint         For contextual help
    - accessibilityTraits       For element type hints (button, header, etc.)
    - accessibilityValue        For dynamic value announcements
    - accessibilityAction       For custom VoiceOver actions

EXAMPLES:
    # Scan and modify all SwiftUI views
    $0

    # Audit only (no modifications)
    $0 --scan-only --audit

    # Process specific files
    $0 --files "Views/*.swift"

    # Full automation
    $0 --yolo --ai-provider claude

EXIT CODES:
    0   Success
    10  Build failed after max retries
    11  Misconfiguration
    12  AI provider error

OUTPUT:
    - Modified view files with accessibility
    - Accessibility audit report
    - List of identifiers added
EOF
}

# ─────────────────────────────────────────────────────────────────────────────
# Initialization
# ─────────────────────────────────────────────────────────────────────────────

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --project)
                PROJECT_PATH="${2:-}"
                shift 2
                ;;
            --scheme)
                SCHEME="${2:-}"
                shift 2
                ;;
            --files)
                FILES_PATTERN="${2:-}"
                shift 2
                ;;
            --scan-only)
                SCAN_ONLY="true"
                shift 1
                ;;
            --audit)
                AUDIT_MODE="true"
                shift 1
                ;;
            --use-docs)
                USE_DOCS="true"
                shift 1
                ;;
            --no-docs)
                USE_DOCS="false"
                shift 1
                ;;
            --ai-provider)
                AI_PROVIDER="${2:-cursor}"
                shift 2
                ;;
            --yolo)
                YOLO_MODE="true"
                shift 1
                ;;
            --max-retries)
                MAX_RETRIES="${2:-3}"
                shift 2
                ;;
            --artifacts-dir)
                ARTIFACTS_DIR="${2:-./Artifacts}"
                shift 2
                ;;
            --verbose|-v)
                VERBOSE="true"
                shift 1
                ;;
            --dry-run)
                DRY_RUN="true"
                shift 1
                ;;
            --use-axe)
                USE_AXE="true"
                shift 1
                ;;
            --validate-live)
                VALIDATE_LIVE="true"
                USE_AXE="true"
                shift 1
                ;;
            --axe-audit)
                AXE_AUDIT="true"
                USE_AXE="true"
                shift 1
                ;;
            --simulator-name)
                SIMULATOR_NAME="${2:-}"
                shift 2
                ;;
            --app-path)
                APP_PATH="${2:-}"
                shift 2
                ;;
            --bundle-id)
                BUNDLE_ID="${2:-}"
                shift 2
                ;;
            --check-touch-targets)
                CHECK_TOUCH_TARGETS="true"
                shift 1
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 11
                ;;
        esac
    done
}

initialize() {
    log_section "════════════════════════════════════════"
    log_section "Accessibility Agent Starting"
    log_section "════════════════════════════════════════"
    echo "" >&2

    # Setup directories
    setup_logs_dir "$ARTIFACTS_DIR" || {
        log_error "Failed to setup directories"
        exit 11
    }

    # Auto-detect Xcode project
    if [ -z "$PROJECT_PATH" ]; then
        detect_xcode_project || {
            log_warning "Could not auto-detect Xcode project"
        }
    else
        if [[ "$PROJECT_PATH" == *.xcworkspace ]]; then
            XCODE_WORKSPACE="$PROJECT_PATH"
        else
            XCODE_PROJECT="$PROJECT_PATH"
        fi
    fi

    # Auto-detect scheme
    if [ -z "$SCHEME" ]; then
        detect_scheme || {
            log_warning "Could not auto-detect scheme"
        }
    fi

    log_info "Configuration:"
    log_info "  Project: ${XCODE_WORKSPACE:-${XCODE_PROJECT:-auto-detect}}"
    log_info "  Scheme: ${SCHEME:-auto-detect}"
    log_info "  Scan Only: $SCAN_ONLY"
    log_info "  Audit Mode: $AUDIT_MODE"
    log_info "  AI Provider: $AI_PROVIDER"
    echo "" >&2
}

# ─────────────────────────────────────────────────────────────────────────────
# SwiftUI View Analysis
# ─────────────────────────────────────────────────────────────────────────────

# Find SwiftUI view files
find_view_files() {
    log_section "Finding SwiftUI views..."

    local view_files=()

    if [ -n "$FILES_PATTERN" ]; then
        # Use provided pattern
        while IFS= read -r file; do
            view_files+=("$file")
        done < <(find . -name "$FILES_PATTERN" -type f 2>/dev/null)
    else
        # Find files containing View protocol
        while IFS= read -r file; do
            if grep -q ": View" "$file" 2>/dev/null; then
                view_files+=("$file")
            fi
        done < <(find_swift_source_files)
    fi

    if [ ${#view_files[@]} -eq 0 ]; then
        log_warning "No SwiftUI view files found"
        return 1
    fi

    log_info "Found ${#view_files[@]} SwiftUI view files"
    printf '%s\n' "${view_files[@]}"
}

# Analyze a view file for accessibility compliance
analyze_view_accessibility() {
    local file="$1"
    local issues=()

    log_verbose "Analyzing: $file"

    local content
    content=$(cat "$file")

    # Check for missing accessibility modifiers
    local has_identifier=false
    local has_label=false
    local has_hint=false
    local has_traits=false

    # Check for accessibilityIdentifier
    if echo "$content" | grep -q "accessibilityIdentifier"; then
        has_identifier=true
    fi

    # Check for accessibilityLabel
    if echo "$content" | grep -q "accessibilityLabel"; then
        has_label=true
    fi

    # Check for accessibilityHint
    if echo "$content" | grep -q "accessibilityHint"; then
        has_hint=true
    fi

    # Check for accessibilityTraits (SwiftUI) or accessibilityAddTraits
    if echo "$content" | grep -qE "accessibilityTraits|accessibilityAddTraits"; then
        has_traits=true
    fi

    # Check for interactive elements without accessibility
    local interactive_count=0
    interactive_count=$(echo "$content" | grep -cE "Button|NavigationLink|onTapGesture|Toggle|Slider|Picker" || true)

    local with_accessibility=0
    with_accessibility=$(echo "$content" | grep -cE "accessibilityIdentifier|accessibilityLabel" || true)

    # Build analysis report
    local analysis="File: $file
Interactive Elements: $interactive_count
With Accessibility: $with_accessibility
Has Identifier: $has_identifier
Has Label: $has_label
Has Hint: $has_hint
Has Traits: $has_traits"

    # Track missing accessibility
    if [ "$has_identifier" = false ]; then
        issues+=("Missing accessibilityIdentifier")
    fi
    if [ "$has_label" = false ] && [ $interactive_count -gt 0 ]; then
        issues+=("Missing accessibilityLabel for interactive elements")
    fi

    if [ ${#issues[@]} -gt 0 ]; then
        MISSING_ACCESSIBILITY+=("$file: ${issues[*]}")
    fi

    VIEWS_SCANNED=$((VIEWS_SCANNED + 1))

    echo "$analysis"
}

# Validate accessibility against live UI
validate_live_accessibility() {
    local file="$1"

    if [ "$VALIDATE_LIVE" != "true" ] || [ "$USE_AXE" != "true" ]; then
        return 0
    fi

    if ! command -v is_axe_available &>/dev/null || ! is_axe_available; then
        log_warning "AXe not available, skipping live validation"
        return 0
    fi

    # Prepare simulator if needed
    if [ -z "$SIMULATOR_UDID" ]; then
        log_info "Preparing simulator for live validation..."
        SIMULATOR_UDID=$(prepare_simulator_for_testing "$SIMULATOR_NAME" "$APP_PATH" "$BUNDLE_ID") || {
            log_error "Failed to prepare simulator"
            return 1
        }
    fi

    # Get live UI hierarchy
    local ui_hierarchy
    ui_hierarchy=$(JSON_OUTPUT=false axe_describe_ui "$SIMULATOR_UDID") || {
        log_error "Failed to get UI hierarchy"
        return 1
    }

    # Extract identifiers from code
    local code_identifiers
    code_identifiers=$(grep -oE 'accessibilityIdentifier\("[^"]+"\)' "$file" | sed 's/accessibilityIdentifier("\(.*\)")/\1/g' | sort -u)

    # Compare with live UI
    local missing_count=0
    local found_count=0
    while IFS= read -r identifier; do
        if [ -z "$identifier" ]; then
            continue
        fi

        if echo "$ui_hierarchy" | jq -e --arg id "$identifier" '.. | objects | select(.identifier == $id)' >/dev/null 2>&1; then
            found_count=$((found_count + 1))
        else
            log_warning "Identifier in code but not in live UI: $identifier"
            missing_count=$((missing_count + 1))
        fi
    done <<< "$code_identifiers"

    log_info "Live validation: $found_count found, $missing_count missing"
    return 0
}

# Run AXe-based accessibility audit
run_axe_audit() {
    if [ "$AXE_AUDIT" != "true" ] || [ "$USE_AXE" != "true" ]; then
        return 0
    fi

    if ! command -v is_axe_available &>/dev/null || ! is_axe_available; then
        log_warning "AXe not available, skipping audit"
        return 0
    fi

    log_section "Running AXe Accessibility Audit"

    # Prepare simulator if needed
    if [ -z "$SIMULATOR_UDID" ]; then
        log_info "Preparing simulator for audit..."
        SIMULATOR_UDID=$(prepare_simulator_for_testing "$SIMULATOR_NAME" "$APP_PATH" "$BUNDLE_ID") || {
            log_error "Failed to prepare simulator"
            return 1
        }
    fi

    # Get live UI hierarchy
    local ui_hierarchy
    ui_hierarchy=$(JSON_OUTPUT=false axe_describe_ui "$SIMULATOR_UDID") || {
        log_error "Failed to get UI hierarchy for audit"
        return 1
    }

    # Save audit hierarchy
    local audit_file="${ARTIFACTS_DIR}/axe_audit_hierarchy.json"
    echo "$ui_hierarchy" > "$audit_file"
    log_info "UI hierarchy saved: $audit_file"

    # Check touch targets if requested
    if [ "$CHECK_TOUCH_TARGETS" = "true" ]; then
        log_info "Checking touch target sizes (minimum 44x44pt)..."
        local violations=0

        # Parse UI hierarchy for elements with frames smaller than 44x44
        if command -v jq >/dev/null 2>&1; then
            violations=$(echo "$ui_hierarchy" | jq -r '
                .. | objects | select(.frame?) |
                select((.frame.width < 44) or (.frame.height < 44)) |
                .identifier // .label // "unknown"
            ' 2>/dev/null | wc -l | tr -d ' ')

            if [ "$violations" -gt 0 ]; then
                log_warning "Found $violations elements with touch targets smaller than 44x44pt"
                echo "$ui_hierarchy" | jq -r '
                    .. | objects | select(.frame?) |
                    select((.frame.width < 44) or (.frame.height < 44)) |
                    "  - \(.identifier // .label // "unknown"): \(.frame.width)x\(.frame.height)pt"
                ' 2>/dev/null | head -10
            else
                log_success "All interactive elements meet 44x44pt minimum"
            fi
        fi
    fi

    log_success "AXe audit complete"
    return 0
}

# ─────────────────────────────────────────────────────────────────────────────
# Accessibility Enhancement
# ─────────────────────────────────────────────────────────────────────────────

# Build AI prompt for accessibility enhancement
build_accessibility_prompt() {
    local file="$1"
    local content="$2"
    local context="$3"

    cat << EOF
You are a SwiftUI accessibility expert. Your task is to add comprehensive
accessibility modifiers to the following SwiftUI view.

SOURCE FILE: $(basename "$file")
\`\`\`swift
$content
\`\`\`

REQUIREMENTS:
1. Add accessibilityIdentifier to ALL interactive elements (Button, NavigationLink, TextField, etc.)
   - Use descriptive, kebab-case identifiers: "login-button", "username-field"
   - Make identifiers unique within the view

2. Add accessibilityLabel to elements that need VoiceOver descriptions
   - Describe what the element does, not how it looks
   - Be concise but descriptive

3. Add accessibilityHint for elements that need additional context
   - Explain what happens when activated

4. Add accessibilityTraits where appropriate:
   - .isButton for clickable elements
   - .isHeader for section headers
   - .isLink for navigation links
   - .isImage for decorative images
   - .isSelected for selected states

5. Use accessibilityValue for dynamic content (sliders, progress, etc.)

6. Group related elements with accessibilityElement(children: .combine) when appropriate

REFERENCE DOCUMENTATION:
$context

OUTPUT:
Generate the complete modified Swift file with accessibility modifiers added.
Preserve all existing functionality. Only add accessibility modifiers.
Start with import statements and end with the closing brace.
EOF
}

# Enhance accessibility for a view file
enhance_accessibility() {
    local file="$1"
    local retry_count=0

    log_section "Enhancing accessibility: $(basename "$file")"

    # Read file content
    local content
    content=$(cat "$file")

    # Backup original file
    local backup_file="${file}.backup"
    cp "$file" "$backup_file"

    # Gather accessibility context
    local context=""
    if [ "$USE_DOCS" = "true" ]; then
        context=$(gather_test_context "${ACCESSIBILITY_CONTEXT_PATHS[@]}")
    fi

    # Build prompt
    local prompt
    prompt=$(build_accessibility_prompt "$file" "$content" "$context")

    if [ "$DRY_RUN" = "true" ]; then
        log_info "[DRY RUN] Would enhance: $file"
        return 0
    fi

    if [ "$SCAN_ONLY" = "true" ]; then
        log_info "[SCAN ONLY] Would enhance: $file"
        return 0
    fi

    # Retry loop
    while [ $retry_count -lt $MAX_RETRIES ]; do
        retry_count=$((retry_count + 1))
        log_info "Attempt $retry_count/$MAX_RETRIES"

        # Generate enhanced file via AI
        local ai_output_file="${LOGS_DIR}/ai_accessibility_$(basename "$file" .swift)_${retry_count}.txt"

        if ! run_ai_cli "$prompt" --provider "$AI_PROVIDER" --output "$ai_output_file"; then
            log_error "AI generation failed"
            if [ $retry_count -lt $MAX_RETRIES ]; then
                log_warning "Retrying..."
                continue
            fi
            # Restore backup
            mv "$backup_file" "$file"
            return 12
        fi

        # Extract Swift code from AI response
        local enhanced_code
        enhanced_code=$(cat "$ai_output_file")

        # Clean up code (remove markdown code blocks if present)
        enhanced_code=$(echo "$enhanced_code" | sed '/^```swift$/d' | sed '/^```$/d')

        # Write enhanced file
        echo "$enhanced_code" > "$file"

        # Count identifiers added
        local old_count new_count
        old_count=$(echo "$content" | grep -c "accessibilityIdentifier" || true)
        new_count=$(echo "$enhanced_code" | grep -c "accessibilityIdentifier" || true)
        local added=$((new_count - old_count))
        if [ $added -gt 0 ]; then
            IDENTIFIERS_ADDED=$((IDENTIFIERS_ADDED + added))
        fi

        # Verify build
        log_info "Verifying build..."
        if run_build_lint --logs-dir "$LOGS_DIR" --scheme "$SCHEME"; then
            log_success "Build verification passed"
            VIEWS_MODIFIED=$((VIEWS_MODIFIED + 1))
            rm -f "$backup_file"
            return 0
        else
            log_warning "Build failed, extracting errors..."

            # Get error feedback
            local error_log="${LOGS_DIR}/error.log"
            if [ -f "$error_log" ]; then
                local errors
                errors=$(cat "$error_log")

                # Update prompt with error feedback
                prompt="The previous accessibility enhancement had build errors:

$errors

Please fix the following enhanced file:
\`\`\`swift
$enhanced_code
\`\`\`

Original file for reference:
\`\`\`swift
$content
\`\`\`

Generate the corrected file with accessibility modifiers."

                rm -f "$error_log"
            fi
        fi
    done

    # Restore backup on failure
    log_error "Failed to enhance accessibility after $MAX_RETRIES attempts"
    mv "$backup_file" "$file"
    write_error_log "Failed to enhance accessibility for: $file"
    return 10
}

# ─────────────────────────────────────────────────────────────────────────────
# Audit Report
# ─────────────────────────────────────────────────────────────────────────────

generate_audit_report() {
    log_section "Generating accessibility audit..."

    local missing_list=""
    for item in "${MISSING_ACCESSIBILITY[@]}"; do
        missing_list+="<li>$item</li>\n"
    done

    # Add AXe audit section if available
    local axe_section=""
    if [ -f "${ARTIFACTS_DIR}/axe_audit_hierarchy.json" ]; then
        axe_section="
    <div class='section'>
        <h2>AXe Live Audit</h2>
        <p>UI hierarchy captured from running app:</p>
        <ul>
            <li><a href='axe_audit_hierarchy.json'>UI Hierarchy JSON</a></li>
        </ul>
    </div>"
    fi

    local report_data="<div class='section'>
        <h2>Accessibility Audit Results</h2>
        <table>
            <tr><th>Metric</th><th>Value</th></tr>
            <tr><td>Views Scanned</td><td>${VIEWS_SCANNED}</td></tr>
            <tr><td>Views Modified</td><td>${VIEWS_MODIFIED}</td></tr>
            <tr><td>Identifiers Added</td><td>${IDENTIFIERS_ADDED}</td></tr>
            <tr><td>Views with Issues</td><td>${#MISSING_ACCESSIBILITY[@]}</td></tr>
        </table>
    </div>

    <div class='section'>
        <h2>Missing Accessibility</h2>
        <ul>
            $(echo -e "$missing_list")
        </ul>
    </div>

    $axe_section

    <div class='section'>
        <h2>Recommendations</h2>
        <ul>
            <li>Add accessibilityIdentifier to all interactive elements for UI testing</li>
            <li>Provide accessibilityLabel for elements that VoiceOver cannot describe</li>
            <li>Use accessibilityHint to explain what happens when an element is activated</li>
            <li>Apply appropriate accessibilityTraits to convey element roles</li>
        </ul>
    </div>"

    generate_report \
        --title "Accessibility Audit Report" \
        --format html \
        --output "${ARTIFACTS_RUN_DIR}/accessibility_audit.html" \
        --data "$report_data"

    # Generate JSON report
    local axe_audit_data="false"
    if [ -f "${ARTIFACTS_DIR}/axe_audit_hierarchy.json" ]; then
        axe_audit_data="true"
    fi

    local json_data="{
        \"viewsScanned\": $VIEWS_SCANNED,
        \"viewsModified\": $VIEWS_MODIFIED,
        \"identifiersAdded\": $IDENTIFIERS_ADDED,
        \"issueCount\": ${#MISSING_ACCESSIBILITY[@]},
        \"axeAuditPerformed\": $axe_audit_data
    }"

    generate_report \
        --title "Accessibility Audit" \
        --format json \
        --output "${ARTIFACTS_RUN_DIR}/accessibility_audit.json" \
        --data "$json_data"

    log_success "Audit report generated: ${ARTIFACTS_RUN_DIR}/accessibility_audit.html"
}

# ─────────────────────────────────────────────────────────────────────────────
# Main Execution
# ─────────────────────────────────────────────────────────────────────────────

main() {
    parse_arguments "$@"
    initialize

    # Find view files
    local view_files
    view_files=$(find_view_files) || {
        log_warning "No SwiftUI view files found"
        if [ "$AUDIT_MODE" = "true" ]; then
            generate_audit_report
        fi
        exit 0
    }

    local exit_code=0

    # Analyze and optionally enhance each view
    while IFS= read -r file; do
        [ -z "$file" ] && continue

        # Analyze accessibility
        analyze_view_accessibility "$file"

        # Validate against live UI if enabled
        if [ "$USE_AXE" = "true" ]; then
            validate_live_accessibility "$file"
        fi

        # Enhance if not scan-only
        if [ "$SCAN_ONLY" = "false" ]; then
            if ! enhance_accessibility "$file"; then
                exit_code=10
                # Continue with other files
            fi
        fi
    done <<< "$view_files"

    # Run AXe audit if requested
    if [ "$AXE_AUDIT" = "true" ]; then
        run_axe_audit
    fi

    # Generate audit report if requested
    if [ "$AUDIT_MODE" = "true" ] || [ "$SCAN_ONLY" = "true" ]; then
        generate_audit_report
    fi

    # Final status
    echo "" >&2
    log_section "════════════════════════════════════════"
    if [ $exit_code -eq 0 ]; then
        log_success "Accessibility Agent Complete!"
        log_info "Views scanned: $VIEWS_SCANNED"
        log_info "Views modified: $VIEWS_MODIFIED"
        log_info "Identifiers added: $IDENTIFIERS_ADDED"
        write_success_log "Accessibility enhanced successfully" "Views: $VIEWS_MODIFIED, Identifiers: $IDENTIFIERS_ADDED"
    else
        log_error "Accessibility Agent completed with errors"
        write_error_log "Accessibility enhancement had failures"
    fi
    log_section "════════════════════════════════════════"
    echo "" >&2

    log_info "Artifacts: ${ARTIFACTS_RUN_DIR}"

    exit $exit_code
}

main "$@"
