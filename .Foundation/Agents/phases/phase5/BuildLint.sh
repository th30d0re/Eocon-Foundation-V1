#!/usr/bin/env bash

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

PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load helper libraries
HELPERS_LIB="${PROJECT_ROOT}/.Foundation/lib/helpers.sh"
ERRORS_LIB="${PROJECT_ROOT}/.Foundation/lib/errors.sh"

if [ -f "$HELPERS_LIB" ]; then
    # shellcheck disable=SC1090
    source "$HELPERS_LIB"

    # Check shell compatibility
    if type check_shell_compatibility &>/dev/null; then
        check_shell_compatibility || exit 11
    fi
fi

if [ -f "$ERRORS_LIB" ]; then
    # shellcheck disable=SC1090
    source "$ERRORS_LIB"
fi

# Load defaults configuration file (unless disabled)
LOAD_DEFAULTS="${LOAD_DEFAULTS:-true}"
PHASE5_DIR="${SCRIPT_DIR}"
DEFAULTS_CONF="${PHASE5_DIR}/defaults.conf"
if [ "$LOAD_DEFAULTS" = "true" ] && [ -f "$DEFAULTS_CONF" ]; then
    # shellcheck disable=SC1090,SC1091
    source "$DEFAULTS_CONF"
fi

# Load Phase 5 enhanced libraries
PHASE5_LIB_DIR="${SCRIPT_DIR}/lib"
if [ -f "${PHASE5_LIB_DIR}/xcodemake.sh" ]; then
    # shellcheck disable=SC1090
    source "${PHASE5_LIB_DIR}/xcodemake.sh"
fi
if [ -f "${PHASE5_LIB_DIR}/platform.sh" ]; then
    # shellcheck disable=SC1090
    source "${PHASE5_LIB_DIR}/platform.sh"
fi
if [ -f "${PHASE5_LIB_DIR}/session_store.sh" ]; then
    # shellcheck disable=SC1090
    source "${PHASE5_LIB_DIR}/session_store.sh"
fi
if [ -f "${PHASE5_LIB_DIR}/swift_package.sh" ]; then
    # shellcheck disable=SC1090
    source "${PHASE5_LIB_DIR}/swift_package.sh"
fi
if [ -f "${PHASE5_LIB_DIR}/log_capture.sh" ]; then
    # shellcheck disable=SC1090
    source "${PHASE5_LIB_DIR}/log_capture.sh"
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
AUTO_DETECTED_BUILD_PATH=""  # Auto-detected Build folder in script directory
XCODE_PROJECT=""
XCODE_WORKSPACE=""
SCHEME=""
TARGET_ID=""
DESTINATION=""
PLATFORM=""  # Platform name (e.g., "iOS Simulator", "macOS")
SIMULATOR=""  # Simulator name (e.g., "iPhone 16")
SKIP_LINT="${SKIP_LINT:-false}"
VERBOSE="${VERBOSE:-false}"
CLEAN="${CLEAN:-false}"
CLEAN_DERIVED_DATA="${CLEAN_DERIVED_DATA:-false}"
SKIP_MACRO_VALIDATION="${SKIP_MACRO_VALIDATION:-true}"  # Default to true
INCREMENTAL_BUILDS_ENABLED="${INCREMENTAL_BUILDS_ENABLED:-true}"
JSON_OUTPUT="${JSON_OUTPUT:-false}"  # Output results in JSON format
IS_SWIFT_PACKAGE="false"  # Set to true if building a Swift package
BUILT_PRODUCTS_DIR_CAPTURED=""  # Populated after a successful build via -showBuildSettings

# Load Phase 5 libraries for platform construction
PHASE5_LIB_DIR="${SCRIPT_DIR}/lib"
if [ -f "${PHASE5_LIB_DIR}/platform.sh" ]; then
    # shellcheck disable=SC1090
    source "${PHASE5_LIB_DIR}/platform.sh"
fi
if [ -f "${PHASE5_LIB_DIR}/xcodemake.sh" ]; then
    # shellcheck disable=SC1090
    source "${PHASE5_LIB_DIR}/xcodemake.sh"
fi

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
                            Auto-detects: {script_dir}/Build if exists
    --artifacts-dir <dir>   Artifacts output directory (default: Artifacts/)
    --logs-dir <dir>        Use specific logs directory (skips auto-creation)
    --skip-lint             Skip SwiftLint on uncommitted changes
    --clean                 Clean build folder before building
    --clean-derived-data    Also remove DerivedData folder (use with --clean)
    --verbose               Enable verbose output
    --platform <name>       Platform to build for (e.g., "iOS Simulator", "macOS")
    --simulator <name>      Simulator name (e.g., "iPhone 16")
    --json-output           Output results in JSON format for MCP integration
    --skip-macro-validation Skip Swift macro validation (default: enabled)
    --no-incremental        Disable incremental builds, force full xcodebuild
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

    # Output JSON error if requested
    if [ "$JSON_OUTPUT" = "true" ]; then
        local platform_name="${PLATFORM:-iOS Simulator}"
        local escaped_error
        escaped_error=$(echo "$error_message" | sed 's/"/\\"/g' | tr '\n' ' ')
        cat << JSONEOF
{
  "status": "failed",
  "platform": "$platform_name",
  "scheme": "${SCHEME:-}",
  "configuration": "$BUILD_CONFIGURATION",
  "destination": "${DESTINATION:-}",
  "error": "$escaped_error",
  "error_file": "$error_file",
  "logs_dir": "$LOGS_DIR",
  "exit_code": $exit_code,
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
JSONEOF
    fi

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

# ─────────────────────────────────────────────────────────────────────────────
# Auto-Installation Functions
# ─────────────────────────────────────────────────────────────────────────────

# Install Homebrew if not present (macOS/Linux)
install_homebrew() {
    if command -v brew >/dev/null 2>&1; then
        log_verbose "Homebrew already installed"
        return 0
    fi

    log_section "Installing Homebrew..."

    # Check if we're on macOS or Linux
    local os_type
    os_type=$(uname -s)

    if [ "$os_type" = "Darwin" ] || [ "$os_type" = "Linux" ]; then
        # Official Homebrew installation script
        # Using NONINTERACTIVE to avoid prompts in automation
        if NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" 2>&1; then
            log_success "Homebrew installed successfully"

            # Add Homebrew to PATH for this session (needed on Linux and Apple Silicon)
            if [ "$os_type" = "Linux" ]; then
                eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)" 2>/dev/null || true
            elif [ -f "/opt/homebrew/bin/brew" ]; then
                # Apple Silicon Mac
                eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null || true
            fi

            return 0
        else
            log_error "Failed to install Homebrew"
            log_info "Please install manually: https://brew.sh"
            return 1
        fi
    else
        log_warning "Homebrew installation not supported on $os_type"
        return 1
    fi
}

# Install SwiftLint via Homebrew
install_swiftlint() {
    if command -v swiftlint >/dev/null 2>&1; then
        log_verbose "SwiftLint already installed: $(swiftlint version 2>/dev/null || echo 'unknown version')"
        return 0
    fi

    log_section "Installing SwiftLint..."

    # Ensure Homebrew is installed first
    if ! command -v brew >/dev/null 2>&1; then
        log_info "Homebrew not found, installing first..."
        if ! install_homebrew; then
            log_error "Cannot install SwiftLint without Homebrew"
            return 1
        fi
    fi

    # Install SwiftLint via Homebrew
    if brew install swiftlint 2>&1; then
        log_success "SwiftLint installed successfully"

        # Verify installation
        if command -v swiftlint >/dev/null 2>&1; then
            log_info "SwiftLint version: $(swiftlint version 2>/dev/null || echo 'installed')"
            return 0
        else
            log_warning "SwiftLint installed but not in PATH"
            # Try to find it
            local brew_prefix
            brew_prefix=$(brew --prefix 2>/dev/null || echo "/usr/local")
            if [ -x "${brew_prefix}/bin/swiftlint" ]; then
                export PATH="${brew_prefix}/bin:$PATH"
                log_info "Added ${brew_prefix}/bin to PATH"
                return 0
            fi
            return 1
        fi
    else
        log_error "Failed to install SwiftLint"
        return 1
    fi
}

# Ensure SwiftLint is available (install if needed)
ensure_swiftlint() {
    if command -v swiftlint >/dev/null 2>&1; then
        return 0
    fi

    log_info "SwiftLint not found, attempting auto-installation..."

    if install_swiftlint; then
        return 0
    else
        log_warning "Could not auto-install SwiftLint, lint checks will be skipped"
        return 1
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Lint Functions
# ─────────────────────────────────────────────────────────────────────────────

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

    # Auto-install SwiftLint if not present
    if ! ensure_swiftlint; then
        log_warning "SwiftLint not available, skipping lint checks"
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

    # Check for Swift Package first (Package.swift)
    if [ -f "${PROJECT_ROOT}/Package.swift" ]; then
        IS_SWIFT_PACKAGE="true"
        log_info "Auto-detected Swift Package: ${PROJECT_ROOT}/Package.swift"
        return 0
    fi

    # Look for workspace (preferred for Xcode projects)
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

# Auto-detect Build folder in script directory
detect_build_folder() {
    # Only auto-detect if DERIVED_DATA_PATH is not already set
    if [ -n "$DERIVED_DATA_PATH" ]; then
        log_verbose "Using provided derived data path: $DERIVED_DATA_PATH"
        return 0
    fi

    # Check for Build folder in script directory
    local build_dir="${SCRIPT_DIR}/Build"

    if [ -d "$build_dir" ]; then
        AUTO_DETECTED_BUILD_PATH="$build_dir"
        DERIVED_DATA_PATH="$build_dir"
        log_info "Auto-detected Build folder: $build_dir"
        return 0
    fi

    log_verbose "No Build folder found in script directory, using default"
    return 1
}

# Auto-detect scheme
detect_scheme() {
    if [ -n "$SCHEME" ]; then
        return 0
    fi

    local schemes_output
    local xcode_cmd_args=("xcodebuild")

    if [ -n "$XCODE_WORKSPACE" ]; then
        xcode_cmd_args+=("-workspace" "$XCODE_WORKSPACE")
    elif [ -n "$XCODE_PROJECT" ]; then
        xcode_cmd_args+=("-project" "$XCODE_PROJECT")
    else
        return 1
    fi

    # Get list of schemes (array-based — avoids CWE-78 shell injection)
    schemes_output=$("${xcode_cmd_args[@]}" -list 2>/dev/null || true)

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
    # Priority 0: Explicit PLATFORM flag (uses platform.sh)
    if [ -n "$PLATFORM" ] && type construct_destination &>/dev/null; then
        local platform_dest
        platform_dest=$(construct_destination "$PLATFORM" "${SIMULATOR:-}" "")
        if [ -n "$platform_dest" ] && [ $? -eq 0 ]; then
            DESTINATION="$platform_dest"
            log_info "Using platform destination: $DESTINATION"
            return 0
        else
            log_warning "Failed to construct destination for platform: $PLATFORM"
        fi
    fi

    # Priority 1: Explicit TARGET_ID
    if [ -n "$TARGET_ID" ]; then
        DESTINATION="id=${TARGET_ID}"
        log_info "Using device destination: $DESTINATION"
        return 0
    fi

    # Priority 2: Pre-set DESTINATION
    if [ -n "$DESTINATION" ]; then
        # Sanitize destination - remove invalid OS:latest parameter
        if echo "$DESTINATION" | grep -q "OS:latest"; then
            log_warning "Removing invalid 'OS:latest' from destination"
            DESTINATION=$(echo "$DESTINATION" | sed 's/,\s*OS:latest//g' | sed 's/OS:latest,\s*//g')
        fi

        # Use platform.sh validation if available
        if type validate_destination &>/dev/null; then
            local validation_result=0
            validate_destination "$DESTINATION" || validation_result=$?
            if [ "$validation_result" -eq 2 ]; then
                log_warning "Destination device/simulator not found, falling back to auto-detection"
                DESTINATION=""
            elif [ "$validation_result" -eq 1 ]; then
                log_warning "Invalid destination format, falling back to auto-detection"
                DESTINATION=""
            fi
        else
            # Legacy validation: If destination specifies a specific device name, verify it exists
            if echo "$DESTINATION" | grep -q "name=iPhone 16"; then
                local sim_exists
                sim_exists=$(xcrun simctl list devices available 2>/dev/null | grep -c "iPhone 16" || true)
                if [ "$sim_exists" -eq 0 ]; then
                    log_warning "iPhone 16 simulator not found, falling back to auto-detection"
                    DESTINATION=""
                fi
            fi
        fi
        if [ -n "$DESTINATION" ]; then
            return 0
        fi
    fi

    # Priority 3: Use platform.sh construct_destination if available
    if type construct_destination &>/dev/null; then
        local platform_dest
        platform_dest=$(construct_destination "iOS Simulator" "" "")
        if [ -n "$platform_dest" ] && [ "$?" -eq 0 ]; then
            DESTINATION="$platform_dest"
            log_info "Using platform.sh auto-detected destination: $DESTINATION"

            # Validate the constructed destination
            if type validate_destination &>/dev/null; then
                local validation_result=0
                validate_destination "$DESTINATION" || validation_result=$?
                if [ "$validation_result" -ne 0 ]; then
                    log_warning "Constructed destination validation failed, trying generic fallback"
                    if type get_generic_destination &>/dev/null; then
                        platform_dest=$(get_generic_destination "iOS Simulator")
                        if [ -n "$platform_dest" ]; then
                            DESTINATION="$platform_dest"
                            log_info "Using generic destination fallback: $DESTINATION"
                            return 0
                        fi
                    fi
                    DESTINATION=""
                else
                    return 0
                fi
            else
                return 0
            fi
        fi
    fi

    # Priority 4: Auto-detect iOS Simulator from xcodebuild's available destinations
    local dest_cmd_args=("xcodebuild")
    if [ -n "$XCODE_WORKSPACE" ]; then
        dest_cmd_args+=("-workspace" "$XCODE_WORKSPACE")
    elif [ -n "$XCODE_PROJECT" ]; then
        dest_cmd_args+=("-project" "$XCODE_PROJECT")
    fi

    if [ "${#dest_cmd_args[@]}" -gt 1 ]; then
        # Get first available iPhone simulator from xcodebuild (array — avoids CWE-78)
        local available_sim
        available_sim=$("${dest_cmd_args[@]}" -scheme "${SCHEME:-Foundation}" -showdestinations 2>/dev/null | grep "platform:iOS Simulator" | grep "name:iPhone" | grep -v "placeholder" | head -1 | sed -n 's/.*name:\([^,}]*\).*/\1/p' | xargs)
        if [ -n "$available_sim" ]; then
            DESTINATION="platform=iOS Simulator,name=$available_sim"
            log_info "Using default simulator destination: $DESTINATION"
            return 0
        fi
    fi

    # Fallback to generic destination (use platform.sh if available)
    if type get_generic_destination &>/dev/null; then
        DESTINATION=$(get_generic_destination "iOS Simulator")
    else
        DESTINATION="platform=iOS Simulator,name=Any iOS Simulator Device"
    fi
    log_info "Using default simulator destination: $DESTINATION"
    return 0
}

# ─────────────────────────────────────────────────────────────────────────────
# Build Function
# ─────────────────────────────────────────────────────────────────────────────

run_xcode_build() {
    log_section "Starting Xcode build..."

    # Construct xcodebuild command as an array (no eval — avoids CWE-78 shell injection)
    local xcode_cmd_array=("xcodebuild")

    if [ -n "$XCODE_WORKSPACE" ]; then
        xcode_cmd_array+=("-workspace" "$XCODE_WORKSPACE")
    elif [ -n "$XCODE_PROJECT" ]; then
        xcode_cmd_array+=("-project" "$XCODE_PROJECT")
    fi

    xcode_cmd_array+=("-scheme" "$SCHEME")
    xcode_cmd_array+=("-configuration" "$BUILD_CONFIGURATION")
    xcode_cmd_array+=("-destination" "$DESTINATION")

    if [ -n "$DERIVED_DATA_PATH" ]; then
        xcode_cmd_array+=("-derivedDataPath" "$DERIVED_DATA_PATH")
    fi

    # Add skipMacroValidation flag if enabled
    if [ "${SKIP_MACRO_VALIDATION}" = "true" ]; then
        xcode_cmd_array+=("-skipMacroValidation")
        log_verbose "Skipping Swift macro validation"
    fi

    xcode_cmd_array+=("build")

    # Human-readable command string for logging only
    local xcode_cmd="${xcode_cmd_array[*]}"

    # Run build and capture output
    local build_output_file="${LOGS_DIR}/xcodebuild_raw.log"
    local build_filtered_file="${LOGS_DIR}/xcodebuild_filtered.log"
    local start_time
    local end_time
    local duration
    local build_exit_code=0
    local used_incremental="false"

    start_time=$(date +%s)

    # Determine make target based on xcodebuild action (build/test/clean)
    # For run_xcode_build, we're always building, so target is "build"
    local make_target="build"

    # Try incremental build first if available
    if [ "${INCREMENTAL_BUILDS_ENABLED}" = "true" ] && type is_makefile_available &>/dev/null; then
        if is_makefile_available; then
            # Check if Makefile needs regeneration
            if type should_regenerate &>/dev/null && should_regenerate; then
                log_info "Regenerating Makefile (project config changed)"
                if type generate_makefile &>/dev/null; then
                    generate_makefile "$xcode_cmd" || true
                fi
            fi

            # Try incremental build with appropriate target
            if type execute_incremental_build &>/dev/null; then
                log_info "⚡ Using incremental build (Makefile found)"
                local make_exit_code=0
                execute_incremental_build "$make_target" "" > "$build_output_file" 2>&1 || make_exit_code=$?

                if [ "$make_exit_code" -eq 0 ]; then
                    used_incremental="true"
                    build_exit_code=0
                else
                    log_warning "Incremental build failed, falling back to full xcodebuild"
                    # Fall through to full build
                fi
            fi
        fi
    fi

    # Run full xcodebuild if incremental build was not used or failed
    if [ "$used_incremental" != "true" ]; then
        log_info "Build command: $xcode_cmd"

        # Execute build (array — avoids CWE-78 shell injection)
        "${xcode_cmd_array[@]}" > "$build_output_file" 2>&1 || build_exit_code=$?

        # If full build succeeded after incremental failure, regenerate Makefile for next time
        if [ "$build_exit_code" -eq 0 ] && [ "${INCREMENTAL_BUILDS_ENABLED}" = "true" ]; then
            if type generate_makefile &>/dev/null && type is_xcodemake_available &>/dev/null && is_xcodemake_available; then
                log_verbose "Regenerating Makefile after successful full build"
                generate_makefile "$xcode_cmd" 2>/dev/null || true
            fi
        fi
    fi

    # Filter out noisy Xcode warnings for display (doesn't affect exit code)
    # DVTDeviceOperation/DVTBuildVersion: device discovery noise
    # IDELogStore: internal Xcode logging
    grep -v -E "(DVTDeviceOperation|DVTBuildVersion|IDELogStore)" "$build_output_file" > "$build_filtered_file" 2>/dev/null || true

    # Show filtered output in verbose mode
    if [ "$VERBOSE" = "true" ]; then
        cat "$build_filtered_file"
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

    if [ "$used_incremental" = "true" ]; then
        log_success "✓ Build succeeded in ${duration}s (vs ~28s full build)"
    else
        log_success "Build succeeded in ${duration}s with ${warnings_count} warning(s)"
    fi
    write_build_log "$build_output" "$duration" "$warnings_count"

    # Capture BUILT_PRODUCTS_DIR via -showBuildSettings (fast metadata-only call, no recompile)
    if [ -n "$LOGS_DIR" ]; then
        local settings_cmd_array=("xcodebuild")
        if [ -n "$XCODE_WORKSPACE" ]; then
            settings_cmd_array+=("-workspace" "$XCODE_WORKSPACE")
        elif [ -n "$XCODE_PROJECT" ]; then
            settings_cmd_array+=("-project" "$XCODE_PROJECT")
        fi
        settings_cmd_array+=("-scheme" "$SCHEME")
        settings_cmd_array+=("-configuration" "$BUILD_CONFIGURATION")
        if [ -n "$DESTINATION" ]; then
            settings_cmd_array+=("-destination" "$DESTINATION")
        fi
        if [ -n "$DERIVED_DATA_PATH" ]; then
            settings_cmd_array+=("-derivedDataPath" "$DERIVED_DATA_PATH")
        fi
        settings_cmd_array+=("-showBuildSettings")

        local built_products_dir
        built_products_dir=$("${settings_cmd_array[@]}" 2>/dev/null | grep "^\s*BUILT_PRODUCTS_DIR" | awk '{print $3}' || true)
        if [ -n "$built_products_dir" ]; then
            BUILT_PRODUCTS_DIR_CAPTURED="$built_products_dir"
            echo "$built_products_dir" > "${LOGS_DIR}/built_products_dir.txt"
            log_verbose "BUILT_PRODUCTS_DIR captured: $built_products_dir"
        else
            log_warning "Could not capture BUILT_PRODUCTS_DIR from -showBuildSettings"
        fi
    fi

    return 0
}

# ─────────────────────────────────────────────────────────────────────────────
# Clean Function
# ─────────────────────────────────────────────────────────────────────────────

run_xcode_clean() {
    log_section "Cleaning Xcode build folder..."

    # Construct xcodebuild clean command as an array (no eval — avoids CWE-78 shell injection)
    local xcode_cmd_array=("xcodebuild")

    if [ -n "$XCODE_WORKSPACE" ]; then
        xcode_cmd_array+=("-workspace" "$XCODE_WORKSPACE")
    elif [ -n "$XCODE_PROJECT" ]; then
        xcode_cmd_array+=("-project" "$XCODE_PROJECT")
    fi

    xcode_cmd_array+=("-scheme" "$SCHEME")
    xcode_cmd_array+=("-configuration" "$BUILD_CONFIGURATION")

    if [ -n "$DERIVED_DATA_PATH" ]; then
        xcode_cmd_array+=("-derivedDataPath" "$DERIVED_DATA_PATH")
    fi

    xcode_cmd_array+=("clean")

    # Human-readable command string for logging only
    local xcode_cmd="${xcode_cmd_array[*]}"

    log_info "Clean command: $xcode_cmd"

    # Run clean and capture output
    local clean_output_file="${LOGS_DIR}/xcodebuild_clean.log"
    local clean_exit_code=0

    # Execute clean (array — avoids CWE-78 shell injection)
    if [ "$VERBOSE" = "true" ]; then
        "${xcode_cmd_array[@]}" 2>&1 | tee "$clean_output_file" || clean_exit_code=$?
    else
        "${xcode_cmd_array[@]}" > "$clean_output_file" 2>&1 || clean_exit_code=$?
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

# ─────────────────────────────────────────────────────────────────────────────
# JSON Output Helper
# ─────────────────────────────────────────────────────────────────────────────

output_json_error() {
    local error_msg="$1"
    local exit_code="${2:-1}"

    if [ "$JSON_OUTPUT" = "true" ]; then
        output_json_result "false" "" "$error_msg" "0" "{\"exitCode\":$exit_code}"
    fi
}

output_json_result() {
    local success="$1"
    local output="$2"
    local error="${3:-null}"
    local duration="${4:-0}"
    local extra_metadata="${5:-{}}"

    if [ "$JSON_OUTPUT" != "true" ]; then
        return 0
    fi

    # Escape special characters for JSON
    output=$(echo "$output" | jq -Rs '.' 2>/dev/null | sed 's/^"//;s/"$//' || echo "$output")

    if [ "$error" != "null" ]; then
        error=$(echo "$error" | jq -Rs '.' 2>/dev/null | sed 's/^"//;s/"$//' || echo "$error")
    fi

    # Build metadata object
    local metadata
    if command -v jq &>/dev/null; then
        metadata=$(jq -n \
            --arg logs_dir "${LOGS_DIR:-}" \
            --arg scheme "${SCHEME:-}" \
            --arg platform "${PLATFORM:-}" \
            --arg configuration "${BUILD_CONFIGURATION:-}" \
            --arg destination "${DESTINATION:-}" \
            --argjson extra "$extra_metadata" \
            '{
                logsDir: $logs_dir,
                scheme: $scheme,
                platform: $platform,
                configuration: $configuration,
                destination: $destination
            } + $extra')
    else
        metadata="{\"logsDir\":\"${LOGS_DIR:-}\",\"scheme\":\"${SCHEME:-}\",\"platform\":\"${PLATFORM:-}\"}"
    fi

    # Output JSON result
    if command -v jq &>/dev/null; then
        jq -n \
            --argjson success "$success" \
            --arg output "$output" \
            --arg error "$error" \
            --argjson duration "$duration" \
            --argjson metadata "$metadata" \
            '{
                success: $success,
                output: $output,
                error: (if $error == "null" then null else $error end),
                duration: $duration,
                metadata: $metadata,
                exitCode: (if $success then 0 else 1 end)
            }'
    else
        # Fallback without jq
        local error_json
        if [ "$error" = "null" ]; then
            error_json="null"
        else
            error_json="\"$error\""
        fi

        cat <<EOF
{
  "success": $success,
  "output": "$output",
  "error": $error_json,
  "duration": $duration,
  "metadata": $metadata,
  "exitCode": $((success ? 0 : 1))
}
EOF
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────────────────────

main() {
    local START_TIME
    START_TIME=$(date +%s)

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
            --skip-macro-validation)
                SKIP_MACRO_VALIDATION="true"
                shift 1
                ;;
            --no-incremental)
                INCREMENTAL_BUILDS_ENABLED="false"
                shift 1
                ;;
            --platform)
                PLATFORM="${2:-}"
                shift 2
                ;;
            --simulator)
                SIMULATOR="${2:-}"
                shift 2
                ;;
            --json-output)
                JSON_OUTPUT="true"
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

    # Load session data and apply defaults if available
    if type session_load &>/dev/null; then
        session_load

        # Apply session defaults for empty flags
        if [ -z "$SCHEME" ] && type session_get_default &>/dev/null; then
            local saved_scheme
            saved_scheme=$(session_get_default "scheme")
            if [ -n "$saved_scheme" ]; then
                SCHEME="$saved_scheme"
                log_verbose "Loaded scheme from session: $SCHEME"
            fi
        fi

        if [ -z "$BUILD_CONFIGURATION" ] && type session_get_default &>/dev/null; then
            local saved_config
            saved_config=$(session_get_default "configuration")
            if [ -n "$saved_config" ]; then
                BUILD_CONFIGURATION="$saved_config"
                log_verbose "Loaded configuration from session: $BUILD_CONFIGURATION"
            fi
        fi

        if [ -z "$TARGET_ID" ] && [ -z "$DESTINATION" ] && type session_get_default &>/dev/null; then
            local saved_simulator
            saved_simulator=$(session_get_default "simulator")
            if [ -n "$saved_simulator" ]; then
                log_verbose "Loaded simulator from session: $saved_simulator"
            fi
        fi
    fi

    # Setup logs directory
    setup_logs_dir

    # Auto-detect Build folder in script directory (if not already set)
    detect_build_folder || true  # Non-fatal

    # Validate Xcode project/workspace
    if ! detect_xcode_project; then
        log_error "No Xcode project or workspace found"
        write_error_log "Misconfiguration: No Xcode project or workspace found" \
            "Searched in: $PROJECT_ROOT" "" 11
        exit 11
    fi

    # Handle Swift Package build separately
    if [ "$IS_SWIFT_PACKAGE" = "true" ]; then
        log_info "Building Swift Package..."
        log_info "Project Root: $PROJECT_ROOT"
        log_info "Configuration: $BUILD_CONFIGURATION"
        echo "" >&2

        # Clean if requested
        if [ "$CLEAN" = "true" ]; then
            log_info "Cleaning Swift package..."
            if type swift_package_clean &>/dev/null; then
                swift_package_clean "true" || true
            else
                swift package clean 2>&1 || true
            fi
            echo "" >&2
        fi

        # Run swift build
        local spm_exit_code=0
        local spm_config="debug"
        [ "$BUILD_CONFIGURATION" = "Release" ] && spm_config="release"

        if type swift_package_build &>/dev/null; then
            swift_package_build "$spm_config" || spm_exit_code=$?
        else
            swift build --configuration "$spm_config" 2>&1 | tee "${LOGS_DIR}/spm_build.log" || spm_exit_code=$?
        fi

        if [ $spm_exit_code -ne 0 ]; then
            log_error "Swift package build failed"
            write_error_log "Swift package build failed" \
                "Check ${LOGS_DIR}/spm_build.log for details" "" 10
            output_json_error "Swift package build failed" 10
            exit 10
        fi

        log_success "Swift package build succeeded"
    else
        # Standard Xcode project build

        # Validate scheme
        if ! detect_scheme; then
            log_error "No scheme specified and auto-detection failed"
            write_error_log "Misconfiguration: No scheme available" \
                "Use --scheme to specify a scheme" "" 11
            output_json_error "No scheme specified and auto-detection failed" 11
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
                output_json_error "Clean failed" 10
                exit 10
            fi
            echo "" >&2
        fi

        # Run lints on uncommitted changes (if in git repo)
        if ! run_swiftlint; then
            log_error "Lint check failed"
            output_json_error "Lint check failed" 10
            exit 10
        fi

        echo "" >&2

        # Run Xcode build
        if ! run_xcode_build; then
            log_error "Build failed"
            exit 10
        fi
    fi

    echo "" >&2
    log_section "=========================================="
    log_success "BuildAgent Complete!"
    log_section "=========================================="
    echo "" >&2
    log_info "Artifacts: $LOGS_DIR"
    echo "" >&2

    # Track successful build flags in session
    if type session_track_flag &>/dev/null; then
        [ -n "$SCHEME" ] && session_track_flag "scheme" "$SCHEME"
        [ -n "$BUILD_CONFIGURATION" ] && session_track_flag "configuration" "$BUILD_CONFIGURATION"
        [ -n "$DESTINATION" ] && session_track_flag "destination" "$DESTINATION"

        # Save session data
        if type session_save &>/dev/null; then
            session_save
        fi
    fi

    # Output machine-friendly result
    # Output results
    local END_TIME
    END_TIME=$(date +%s)
    local DURATION=$((END_TIME - START_TIME))
    local DURATION_MS=$((DURATION * 1000))

    if [ "$JSON_OUTPUT" = "true" ]; then
        local platform_name="${PLATFORM:-iOS Simulator}"
        local extra_metadata="{}"
        if command -v jq &>/dev/null; then
            extra_metadata=$(jq -n \
                --arg timestamp "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
                '{
                    timestamp: $timestamp
                }')
        fi

        output_json_result \
            "true" \
            "Build completed for ${SCHEME:-} on $platform_name" \
            "null" \
            "$DURATION_MS" \
            "$extra_metadata"
    else
        printf 'BUILD_STATUS=success\n'
        printf 'BUILD_LOGS_DIR=%q\n' "$LOGS_DIR"
    fi

    exit 0
}

# Run main
main "$@"
