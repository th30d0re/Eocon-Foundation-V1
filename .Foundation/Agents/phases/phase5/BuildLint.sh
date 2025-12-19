#!/bin/bash

# Phase 5: BuildAgent
# Compiles and builds the Swift project for a target device
# Based on: Foundation-Constitution.tex Phase 5 (Execution)
#
# Exit Codes:
#   0  - Success (build passed)
#   10 - Build failed
#   11 - Misconfiguration (missing scheme, project, etc.)

set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────────────────────────────────────

PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load helper libraries
HELPERS_LIB="${PROJECT_ROOT}/.foundation/lib/helpers.sh"
ERRORS_LIB="${PROJECT_ROOT}/.foundation/lib/errors.sh"

if [ -f "$HELPERS_LIB" ]; then
    # shellcheck disable=SC1090
    source "$HELPERS_LIB"
fi

if [ -f "$ERRORS_LIB" ]; then
    # shellcheck disable=SC1090
    source "$ERRORS_LIB"
fi

# Colors (fallback if helpers not loaded)
RED="${RED:-\033[0;31m}"
GREEN="${GREEN:-\033[0;32m}"
YELLOW="${YELLOW:-\033[1;33m}"
BLUE="${BLUE:-\033[0;34m}"
CYAN="${CYAN:-\033[0;36m}"
NC="${NC:-\033[0m}"

# Default artifact output directory
ARTIFACTS_DIR="${ARTIFACTS_DIR:-${PROJECT_ROOT}/Artifacts}"
LOGS_DIR=""  # Set dynamically based on run

# Build configuration
BUILD_CONFIGURATION="${BUILD_CONFIGURATION:-Debug}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-}"
XCODE_PROJECT=""
XCODE_WORKSPACE=""
SCHEME=""
TARGET_ID=""
DESTINATION=""
SKIP_LINT="${SKIP_LINT:-false}"
VERBOSE="${VERBOSE:-false}"
CLEAN="${CLEAN:-false}"
CLEAN_DERIVED_DATA="${CLEAN_DERIVED_DATA:-false}"

# ─────────────────────────────────────────────────────────────────────────────
# Logging Functions
# ─────────────────────────────────────────────────────────────────────────────

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" >&2
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" >&2
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_section() {
    echo -e "${CYAN}[BUILD]${NC} $1" >&2
}

log_verbose() {
    if [ "$VERBOSE" = "true" ]; then
        echo -e "${CYAN}[VERBOSE]${NC} $1" >&2
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Usage
# ─────────────────────────────────────────────────────────────────────────────

show_usage() {
    cat << EOF
Phase 5: BuildAgent - Swift/Xcode Build CLI

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --target-id <id>        Device/Simulator UDID (e.g., 00008150-001D5822210A401C)
    --destination <dest>    Full destination string (overrides --target-id)
    --scheme <scheme>       Xcode scheme to build
    --project <path>        Path to .xcodeproj
    --workspace <path>      Path to .xcworkspace (overrides --project)
    --configuration <cfg>   Build configuration (default: Debug)
    --derived-data <path>   Custom DerivedData path
    --artifacts-dir <dir>   Artifacts output directory (default: Artifacts/)
    --logs-dir <dir>        Use specific logs directory (skips auto-creation)
    --skip-lint             Skip SwiftLint on uncommitted changes
    --clean                 Clean build folder before building
    --clean-derived-data    Also remove DerivedData folder (use with --clean)
    --verbose               Enable verbose output
    --help                  Show this help message

EXIT CODES:
    0   Success
    10  Build failed
    11  Misconfiguration

OUTPUTS:
    logs/build.log   - Build log with analytics (on success)
    logs/error.log   - Error details (on failure)

EXAMPLES:
    # Build for a specific device
    $0 --target-id 00008150-001D5822210A401C --scheme MyApp

    # Build for iOS Simulator
    $0 --destination "platform=iOS Simulator,name=iPhone 15"

    # Build with workspace
    $0 --workspace MyApp.xcworkspace --scheme MyApp

    # Clean build folder before building
    $0 --clean --scheme MyApp

    # Clean build folder and DerivedData
    $0 --clean --clean-derived-data --scheme MyApp

EOF
}

# ─────────────────────────────────────────────────────────────────────────────
# Utility Functions
# ─────────────────────────────────────────────────────────────────────────────

# Setup logs directory for this run
setup_logs_dir() {
    # If LOGS_DIR is already set (via --logs-dir), use it
    if [ -n "$LOGS_DIR" ]; then
        log_verbose "Using provided logs directory: $LOGS_DIR"
        mkdir -p "$LOGS_DIR" || {
            log_error "Failed to create logs directory: $LOGS_DIR"
            exit 11
        }
        return 0
    fi

    # Create new timestamped directory
    local run_id
    run_id="$(date +%Y%m%d_%H%M%S)"
    LOGS_DIR="${ARTIFACTS_DIR}/build_${run_id}/logs"
    mkdir -p "$LOGS_DIR" || {
        log_error "Failed to create logs directory: $LOGS_DIR"
        exit 11
    }
    log_verbose "Logs directory: $LOGS_DIR"
}

# Write error log and exit
write_error_log() {
    local error_message="$1"
    local error_details="${2:-}"
    local failing_command="${3:-}"
    local exit_code="${4:-10}"

    local error_file="${LOGS_DIR}/error.log"

    cat > "$error_file" << EOF
================================================================================
BUILD AGENT ERROR LOG
================================================================================
Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
Exit Code: $exit_code
Error: $error_message
================================================================================

CONFIGURATION:
  Scheme: ${SCHEME:-<not set>}
  Configuration: ${BUILD_CONFIGURATION}
  Destination: ${DESTINATION:-<not set>}
  Project: ${XCODE_PROJECT:-<not set>}
  Workspace: ${XCODE_WORKSPACE:-<not set>}

EOF

    if [ -n "$failing_command" ]; then
        cat >> "$error_file" << EOF
FAILING COMMAND:
  $failing_command

EOF
    fi

    if [ -n "$error_details" ]; then
        cat >> "$error_file" << EOF
ERROR DETAILS:
$error_details
================================================================================
EOF
    fi

    log_error "Error log written to: $error_file"
    echo "$error_file"
}

# Write build success log with analytics
write_build_log() {
    local build_output="$1"
    local duration_seconds="$2"
    local warnings_count="$3"

    local build_file="${LOGS_DIR}/build.log"

    cat > "$build_file" << EOF
================================================================================
BUILD AGENT SUCCESS LOG
================================================================================
Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
Status: SUCCESS
================================================================================

CONFIGURATION:
  Scheme: ${SCHEME}
  Configuration: ${BUILD_CONFIGURATION}
  Destination: ${DESTINATION}
  Project: ${XCODE_PROJECT:-<workspace used>}
  Workspace: ${XCODE_WORKSPACE:-<project used>}

ANALYTICS:
  Build Duration: ${duration_seconds}s
  Warnings Count: ${warnings_count}
  Derived Data: ${DERIVED_DATA_PATH:-<default>}

EOF

    if [ -n "$build_output" ]; then
        cat >> "$build_file" << EOF
BUILD OUTPUT:
--------------------------------------------------------------------------------
$build_output
--------------------------------------------------------------------------------
EOF
    fi

    echo "================================================================================" >> "$build_file"

    log_success "Build log written to: $build_file"
    echo "$build_file"
}

# ─────────────────────────────────────────────────────────────────────────────
# Git & Lint Functions
# ─────────────────────────────────────────────────────────────────────────────

# Check if we're in a git repository
is_git_repo() {
    git -C "$PROJECT_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1
}

# Get list of uncommitted Swift files
get_uncommitted_swift_files() {
    if ! is_git_repo; then
        return 0
    fi

    # Get both staged and unstaged changes for .swift files
    local files
    files=$(git -C "$PROJECT_ROOT" diff --name-only --diff-filter=ACMR HEAD 2>/dev/null | grep '\.swift$' || true)

    # Also include untracked Swift files
    local untracked
    untracked=$(git -C "$PROJECT_ROOT" ls-files --others --exclude-standard 2>/dev/null | grep '\.swift$' || true)

    echo -e "${files}\n${untracked}" | grep -v '^$' | sort -u
}

# Run SwiftLint on uncommitted files
run_swiftlint() {
    if [ "$SKIP_LINT" = "true" ]; then
        log_info "Skipping lint (--skip-lint specified)"
        return 0
    fi

    if ! is_git_repo; then
        log_info "Not a git repository, skipping lint"
        return 0
    fi

    # Check if SwiftLint is installed
    if ! command -v swiftlint >/dev/null 2>&1; then
        log_warning "SwiftLint not installed, skipping lint checks"
        log_info "Install with: brew install swiftlint"
        return 0
    fi

    local swift_files
    swift_files=$(get_uncommitted_swift_files)

    if [ -z "$swift_files" ]; then
        log_info "No uncommitted Swift files to lint"
        return 0
    fi

    local file_count
    file_count=$(echo "$swift_files" | wc -l | tr -d ' ')
    log_section "Running SwiftLint on $file_count uncommitted file(s)..."

    local lint_output
    local lint_exit_code=0
    local temp_lint_log="${LOGS_DIR}/swiftlint_output.txt"

    # Run SwiftLint on each file
    while IFS= read -r file; do
        [ -z "$file" ] && continue
        local full_path="${PROJECT_ROOT}/${file}"
        if [ -f "$full_path" ]; then
            log_verbose "Linting: $file"
            swiftlint lint --path "$full_path" --quiet 2>&1 >> "$temp_lint_log" || lint_exit_code=$?
        fi
    done <<< "$swift_files"

    if [ -f "$temp_lint_log" ]; then
        lint_output=$(cat "$temp_lint_log")
    fi

    # Check for errors (not warnings)
    local error_count=0
    if [ -f "$temp_lint_log" ]; then
        error_count=$(grep -c ": error:" "$temp_lint_log" 2>/dev/null || echo "0")
    fi

    if [ "$error_count" -gt 0 ]; then
        log_error "SwiftLint found $error_count error(s)"
        write_error_log "SwiftLint errors found" "$lint_output" "swiftlint lint" 10
        return 10
    fi

    local warning_count=0
    if [ -f "$temp_lint_log" ]; then
        warning_count=$(grep -c ": warning:" "$temp_lint_log" 2>/dev/null || echo "0")
    fi

    if [ "$warning_count" -gt 0 ]; then
        log_warning "SwiftLint found $warning_count warning(s) (non-blocking)"
    else
        log_success "SwiftLint passed with no issues"
    fi

    return 0
}

# ─────────────────────────────────────────────────────────────────────────────
# Xcode Discovery Functions
# ─────────────────────────────────────────────────────────────────────────────

# Auto-detect Xcode project or workspace
detect_xcode_project() {
    # If already set, use those
    if [ -n "$XCODE_WORKSPACE" ] && [ -f "$XCODE_WORKSPACE" ]; then
        return 0
    fi
    if [ -n "$XCODE_PROJECT" ] && [ -d "$XCODE_PROJECT" ]; then
        return 0
    fi

    # Look for workspace first (preferred)
    local workspace
    workspace=$(find "$PROJECT_ROOT" -maxdepth 2 -name "*.xcworkspace" -not -path "*/.*" | head -1)
    if [ -n "$workspace" ] && [ -d "$workspace" ]; then
        XCODE_WORKSPACE="$workspace"
        log_info "Auto-detected workspace: $XCODE_WORKSPACE"
        return 0
    fi

    # Fall back to project
    local project
    project=$(find "$PROJECT_ROOT" -maxdepth 2 -name "*.xcodeproj" -not -path "*/.*" | head -1)
    if [ -n "$project" ] && [ -d "$project" ]; then
        XCODE_PROJECT="$project"
        log_info "Auto-detected project: $XCODE_PROJECT"
        return 0
    fi

    return 1
}

# Auto-detect scheme
detect_scheme() {
    if [ -n "$SCHEME" ]; then
        return 0
    fi

    local schemes_output
    local xcode_arg=""

    if [ -n "$XCODE_WORKSPACE" ]; then
        xcode_arg="-workspace $XCODE_WORKSPACE"
    elif [ -n "$XCODE_PROJECT" ]; then
        xcode_arg="-project $XCODE_PROJECT"
    else
        return 1
    fi

    # Get list of schemes
    schemes_output=$(xcodebuild $xcode_arg -list 2>/dev/null || true)

    # Extract first scheme
    SCHEME=$(echo "$schemes_output" | awk '/Schemes:/{found=1; next} found && /^[[:space:]]+[^[:space:]]/{print $1; exit}')

    if [ -n "$SCHEME" ]; then
        log_info "Auto-detected scheme: $SCHEME"
        return 0
    fi

    return 1
}

# Build destination string from target ID
build_destination() {
    if [ -n "$DESTINATION" ]; then
        return 0
    fi

    if [ -n "$TARGET_ID" ]; then
        DESTINATION="id=${TARGET_ID}"
        log_info "Using device destination: $DESTINATION"
        return 0
    fi

    # Default to iOS Simulator
    DESTINATION="platform=iOS Simulator,name=iPhone 16"
    log_info "Using default simulator destination: $DESTINATION"
    return 0
}

# ─────────────────────────────────────────────────────────────────────────────
# Build Function
# ─────────────────────────────────────────────────────────────────────────────

run_xcode_build() {
    log_section "Starting Xcode build..."

    # Construct xcodebuild command
    local xcode_cmd="xcodebuild"

    if [ -n "$XCODE_WORKSPACE" ]; then
        xcode_cmd+=" -workspace \"$XCODE_WORKSPACE\""
    elif [ -n "$XCODE_PROJECT" ]; then
        xcode_cmd+=" -project \"$XCODE_PROJECT\""
    fi

    xcode_cmd+=" -scheme \"$SCHEME\""
    xcode_cmd+=" -configuration \"$BUILD_CONFIGURATION\""
    xcode_cmd+=" -destination \"$DESTINATION\""

    if [ -n "$DERIVED_DATA_PATH" ]; then
        xcode_cmd+=" -derivedDataPath \"$DERIVED_DATA_PATH\""
    fi

    xcode_cmd+=" build"

    log_info "Build command: $xcode_cmd"

    # Run build and capture output
    local build_output_file="${LOGS_DIR}/xcodebuild_raw.log"
    local start_time
    local end_time
    local duration
    local build_exit_code=0

    start_time=$(date +%s)

    # Execute build
    if [ "$VERBOSE" = "true" ]; then
        eval "$xcode_cmd" 2>&1 | tee "$build_output_file" || build_exit_code=$?
    else
        eval "$xcode_cmd" > "$build_output_file" 2>&1 || build_exit_code=$?
    fi

    end_time=$(date +%s)
    duration=$((end_time - start_time))

    local build_output
    build_output=$(cat "$build_output_file")

    # Count warnings
    local warnings_count=0
    warnings_count=$(grep -c "warning:" "$build_output_file" 2>/dev/null || echo "0")

    if [ "$build_exit_code" -ne 0 ]; then
        log_error "Build failed with exit code: $build_exit_code"
        write_error_log "Xcode build failed" "$build_output" "$xcode_cmd" 10
        return 10
    fi

    # Check for build success in output
    if ! grep -q "BUILD SUCCEEDED" "$build_output_file" 2>/dev/null; then
        # Some builds don't explicitly say BUILD SUCCEEDED but still pass
        if grep -q "BUILD FAILED" "$build_output_file" 2>/dev/null; then
            log_error "Build failed (BUILD FAILED found in output)"
            write_error_log "Xcode build failed" "$build_output" "$xcode_cmd" 10
            return 10
        fi
    fi

    log_success "Build succeeded in ${duration}s with ${warnings_count} warning(s)"
    write_build_log "$build_output" "$duration" "$warnings_count"

    return 0
}

# ─────────────────────────────────────────────────────────────────────────────
# Clean Function
# ─────────────────────────────────────────────────────────────────────────────

run_xcode_clean() {
    log_section "Cleaning Xcode build folder..."

    # Construct xcodebuild clean command
    local xcode_cmd="xcodebuild"

    if [ -n "$XCODE_WORKSPACE" ]; then
        xcode_cmd+=" -workspace \"$XCODE_WORKSPACE\""
    elif [ -n "$XCODE_PROJECT" ]; then
        xcode_cmd+=" -project \"$XCODE_PROJECT\""
    fi

    xcode_cmd+=" -scheme \"$SCHEME\""
    xcode_cmd+=" -configuration \"$BUILD_CONFIGURATION\""

    if [ -n "$DERIVED_DATA_PATH" ]; then
        xcode_cmd+=" -derivedDataPath \"$DERIVED_DATA_PATH\""
    fi

    xcode_cmd+=" clean"

    log_info "Clean command: $xcode_cmd"

    # Run clean and capture output
    local clean_output_file="${LOGS_DIR}/xcodebuild_clean.log"
    local clean_exit_code=0

    # Execute clean
    if [ "$VERBOSE" = "true" ]; then
        eval "$xcode_cmd" 2>&1 | tee "$clean_output_file" || clean_exit_code=$?
    else
        eval "$xcode_cmd" > "$clean_output_file" 2>&1 || clean_exit_code=$?
    fi

    if [ "$clean_exit_code" -ne 0 ]; then
        log_error "Clean failed with exit code: $clean_exit_code"
        write_error_log "Xcode clean failed" "$(cat "$clean_output_file" 2>/dev/null || echo '')" "$xcode_cmd" 10
        return 10
    fi

    log_success "Build folder cleaned successfully"

    # Optionally clean DerivedData
    if [ "$CLEAN_DERIVED_DATA" = "true" ]; then
        log_section "Cleaning DerivedData folder..."

        local derived_data_to_clean=""
        if [ -n "$DERIVED_DATA_PATH" ]; then
            derived_data_to_clean="$DERIVED_DATA_PATH"
        else
            # Use default DerivedData location
            derived_data_to_clean="${HOME}/Library/Developer/Xcode/DerivedData"
        fi

        if [ -d "$derived_data_to_clean" ]; then
            # Find and remove project-specific DerivedData
            local project_name
            if [ -n "$XCODE_WORKSPACE" ]; then
                project_name=$(basename "$XCODE_WORKSPACE" .xcworkspace)
            elif [ -n "$XCODE_PROJECT" ]; then
                project_name=$(basename "$XCODE_PROJECT" .xcodeproj)
            else
                project_name=""
            fi

            if [ -n "$project_name" ]; then
                # Remove project-specific DerivedData (format: ProjectName-XXXXX)
                local project_derived_data
                project_derived_data=$(find "$derived_data_to_clean" -maxdepth 1 -type d -name "${project_name}-*" 2>/dev/null | head -1)
                if [ -n "$project_derived_data" ] && [ -d "$project_derived_data" ]; then
                    log_info "Removing project DerivedData: $project_derived_data"
                    rm -rf "$project_derived_data" || {
                        log_warning "Failed to remove: $project_derived_data"
                    }
                    log_success "Project DerivedData cleaned"
                else
                    log_info "No project-specific DerivedData found for: $project_name"
                fi
            else
                log_warning "Could not determine project name for DerivedData cleanup"
            fi
        else
            log_info "DerivedData directory not found: $derived_data_to_clean"
        fi
    fi

    return 0
}

# ─────────────────────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────────────────────

main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --target-id)
                TARGET_ID="${2:-}"
                shift 2
                ;;
            --destination)
                DESTINATION="${2:-}"
                shift 2
                ;;
            --scheme)
                SCHEME="${2:-}"
                shift 2
                ;;
            --project)
                XCODE_PROJECT="${2:-}"
                shift 2
                ;;
            --workspace)
                XCODE_WORKSPACE="${2:-}"
                shift 2
                ;;
            --configuration)
                BUILD_CONFIGURATION="${2:-}"
                shift 2
                ;;
            --derived-data)
                DERIVED_DATA_PATH="${2:-}"
                shift 2
                ;;
            --artifacts-dir)
                ARTIFACTS_DIR="${2:-}"
                shift 2
                ;;
            --logs-dir)
                LOGS_DIR="${2:-}"
                shift 2
                ;;
            --skip-lint)
                SKIP_LINT="true"
                shift 1
                ;;
            --clean)
                CLEAN="true"
                shift 1
                ;;
            --clean-derived-data)
                CLEAN_DERIVED_DATA="true"
                shift 1
                ;;
            --verbose|-v)
                VERBOSE="true"
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

    echo "" >&2
    log_section "=========================================="
    log_section "Phase 5: BuildLint Starting"
    log_section "=========================================="
    echo "" >&2

    # Setup logs directory
    setup_logs_dir

    # Validate Xcode project/workspace
    if ! detect_xcode_project; then
        log_error "No Xcode project or workspace found"
        write_error_log "Misconfiguration: No Xcode project or workspace found" \
            "Searched in: $PROJECT_ROOT" "" 11
        exit 11
    fi

    # Validate scheme
    if ! detect_scheme; then
        log_error "No scheme specified and auto-detection failed"
        write_error_log "Misconfiguration: No scheme available" \
            "Use --scheme to specify a scheme" "" 11
        exit 11
    fi

    # Build destination
    build_destination

    log_info "Project Root: $PROJECT_ROOT"
    log_info "Scheme: $SCHEME"
    log_info "Configuration: $BUILD_CONFIGURATION"
    log_info "Destination: $DESTINATION"
    echo "" >&2

    # Clean build folder if requested
    if [ "$CLEAN" = "true" ]; then
        if ! run_xcode_clean; then
            log_error "Clean failed"
            exit 10
        fi
        echo "" >&2
    fi

    # Run lints on uncommitted changes (if in git repo)
    if ! run_swiftlint; then
        log_error "Lint check failed"
        exit 10
    fi

    echo "" >&2

    # Run Xcode build
    if ! run_xcode_build; then
        log_error "Build failed"
        exit 10
    fi

    echo "" >&2
    log_section "=========================================="
    log_success "BuildAgent Complete!"
    log_section "=========================================="
    echo "" >&2
    log_info "Artifacts: $LOGS_DIR"
    echo "" >&2

    # Output machine-friendly result
    printf 'BUILD_STATUS=success\n'
    printf 'BUILD_LOGS_DIR=%q\n' "$LOGS_DIR"

    exit 0
}

# Run main
main "$@"
