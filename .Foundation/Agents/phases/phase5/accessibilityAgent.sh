#!/bin/bash

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

# Source utility libraries
# shellcheck disable=SC1091
source "${LIB_DIR}/testUtils.sh"
# shellcheck disable=SC1091
source "${LIB_DIR}/testContextPaths.sh"

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
    local json_data="{
        \"viewsScanned\": $VIEWS_SCANNED,
        \"viewsModified\": $VIEWS_MODIFIED,
        \"identifiersAdded\": $IDENTIFIERS_ADDED,
        \"issueCount\": ${#MISSING_ACCESSIBILITY[@]}
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

        # Enhance if not scan-only
        if [ "$SCAN_ONLY" = "false" ]; then
            if ! enhance_accessibility "$file"; then
                exit_code=10
                # Continue with other files
            fi
        fi
    done <<< "$view_files"

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
