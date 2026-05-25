#!/usr/bin/env bash

# Test Utilities Library for Foundation Test Agents
# Provides shared functions for all test agents
# Sources: helpers.sh, ai_provider.sh, errors.sh

set -euo pipefail

# Verify bash is running
if [ -z "${BASH_VERSION:-}" ]; then
    echo "Error: This library requires bash" >&2
    return 1 2>/dev/null || exit 1
fi

# ─────────────────────────────────────────────────────────────────────────────
# Configuration and Path Detection
# ─────────────────────────────────────────────────────────────────────────────

# Detect script and project paths
TEST_UTILS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PHASE5_DIR="$(cd "${TEST_UTILS_DIR}/.." && pwd)"
FOUNDATION_LIB_DIR="$(cd "${TEST_UTILS_DIR}/../../.." && pwd)/lib"

# When script is in PATH, use current working directory as project root
if [ -n "${TESTAGENT_USE_CWD:-}" ] || [ "${PWD}" != "$PHASE5_DIR" ]; then
    PROJECT_ROOT="${PROJECT_ROOT:-$PWD}"
else
    PROJECT_ROOT="${PROJECT_ROOT:-$(cd "${TEST_UTILS_DIR}/../../../.." && pwd)}"
fi

WORK_DIR="$PWD"

# Load helper libraries
HELPERS_LIB="${FOUNDATION_LIB_DIR}/helpers.sh"
ERRORS_LIB="${FOUNDATION_LIB_DIR}/errors.sh"
AI_PROVIDER_LIB="${FOUNDATION_LIB_DIR}/ai_provider.sh"

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

# Colors (fallback if helpers not loaded)
RED="${RED:-\033[0;31m}"
GREEN="${GREEN:-\033[0;32m}"
YELLOW="${YELLOW:-\033[1;33m}"
BLUE="${BLUE:-\033[0;34m}"
CYAN="${CYAN:-\033[0;36m}"
MAGENTA="${MAGENTA:-\033[0;35m}"
NC="${NC:-\033[0m}"

# BuildLint script path
BUILD_LINT_SCRIPT="${PHASE5_DIR}/BuildLint.sh"

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
    local prefix="${LOG_PREFIX:-[TEST-UTILS]}"
    echo -e "${CYAN}${prefix}${NC} $1" >&2
}

log_verbose() {
    if [ "${VERBOSE:-false}" = "true" ]; then
        echo -e "${CYAN}[VERBOSE]${NC} $1" >&2
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Xcode Project Detection (reused from BuildAgent patterns)
# ─────────────────────────────────────────────────────────────────────────────

# Auto-detect Xcode project/workspace path
# Searches up to 5 levels deep, excludes dependency directories
# Returns: Sets XCODE_WORKSPACE or XCODE_PROJECT global variables
detect_xcode_project() {
    log_verbose "Searching for Xcode project/workspace..."

    # Common directories to exclude (dependencies, caches, etc.)
    local exclude_patterns=(
        "*/.*"
        "*/.build/*"
        "*/Pods/*"
        "*/Carthage/*"
        "*/checkouts/*"
        "*/DerivedData/*"
        "*/Build/*"
        "*/Docs/*"
        "*/docs/*"
        "*/Reference/*"
        "*/Ref/*"
        "*/Examples/*"
        "*/Samples/*"
    )

    # Build find exclude arguments
    local find_excludes=""
    for pattern in "${exclude_patterns[@]}"; do
        find_excludes="$find_excludes -not -path \"$pattern\""
    done

    # Function to find the best (shortest path) project/workspace
    find_best_xcode_path() {
        local search_dir="$1"
        local extension="$2"
        local max_depth="${3:-5}"

        eval "find \"$search_dir\" -maxdepth $max_depth -name \"*.$extension\" $find_excludes 2>/dev/null" | \
            awk '{ print length, $0 }' | \
            sort -n | \
            cut -d' ' -f2- | \
            head -1
    }

    # Look for workspace first (preferred)
    local workspace
    workspace=$(find_best_xcode_path "$WORK_DIR" "xcworkspace" 5)

    # Exclude project.xcworkspace (inside .xcodeproj)
    if [ -n "$workspace" ] && echo "$workspace" | grep -q "\.xcodeproj/"; then
        workspace=""
    fi

    if [ -z "$workspace" ] && [ "$WORK_DIR" != "$PROJECT_ROOT" ]; then
        workspace=$(find_best_xcode_path "$PROJECT_ROOT" "xcworkspace" 5)
        if [ -n "$workspace" ] && echo "$workspace" | grep -q "\.xcodeproj/"; then
            workspace=""
        fi
    fi

    local project=""
    if [ -z "$workspace" ]; then
        project=$(find_best_xcode_path "$WORK_DIR" "xcodeproj" 5)

        if [ -z "$project" ] && [ "$WORK_DIR" != "$PROJECT_ROOT" ]; then
            project=$(find_best_xcode_path "$PROJECT_ROOT" "xcodeproj" 5)
        fi
    fi

    if [ -n "$workspace" ]; then
        log_info "Found Xcode workspace: $workspace"
        XCODE_WORKSPACE="$workspace"
        XCODE_PROJECT=""
        return 0
    elif [ -n "$project" ]; then
        log_info "Found Xcode project: $project"
        XCODE_PROJECT="$project"
        XCODE_WORKSPACE=""
        return 0
    else
        log_verbose "No Xcode workspace or project found"
        return 1
    fi
}

# Auto-detect Xcode scheme
# Returns: Sets SCHEME global variable
detect_scheme() {
    if [ -n "${SCHEME:-}" ]; then
        log_verbose "Using provided scheme: $SCHEME"
        return 0
    fi

    log_verbose "Attempting to auto-detect Xcode scheme..."

    # Ensure we have project/workspace detected
    if [ -z "${XCODE_WORKSPACE:-}" ] && [ -z "${XCODE_PROJECT:-}" ]; then
        detect_xcode_project || true
    fi

    # Build xcodebuild argument
    local xcode_arg=""
    if [ -n "${XCODE_WORKSPACE:-}" ]; then
        xcode_arg="-workspace \"$XCODE_WORKSPACE\""
    elif [ -n "${XCODE_PROJECT:-}" ]; then
        xcode_arg="-project \"$XCODE_PROJECT\""
    else
        log_verbose "No Xcode workspace or project found"
        return 1
    fi

    # Get list of schemes
    local schemes_output
    schemes_output=$(eval "xcodebuild $xcode_arg -list 2>/dev/null" || true)

    # Extract first scheme from output
    SCHEME=$(echo "$schemes_output" | awk '/Schemes:/{found=1; next} found && /^[[:space:]]+[^[:space:]]/{print $1; exit}')

    if [ -n "$SCHEME" ]; then
        log_info "Auto-detected scheme: $SCHEME"
        return 0
    fi

    log_verbose "Could not auto-detect scheme"
    return 1
}

# ─────────────────────────────────────────────────────────────────────────────
# Context Gathering Functions
# ─────────────────────────────────────────────────────────────────────────────

# Read all MD files from a directory (up to 2 levels deep)
read_md_files_from_dir() {
    local dir="$1"
    local content=""

    if [ ! -d "$dir" ]; then
        return
    fi

    while IFS= read -r -d '' md_file; do
        local filename
        filename=$(basename "$md_file")
        content+="
--- FILE: $filename ---
$(cat "$md_file")
--- END FILE ---
"
    done < <(find "$dir" -maxdepth 2 -name "*.md" -type f -print0 2>/dev/null)

    echo "$content"
}

# Gather test context from specified paths
# Usage: gather_test_context "${CONTEXT_PATHS[@]}"
# Returns: Aggregated context string
gather_test_context() {
    local context=""
    local paths=("$@")

    if [ ${#paths[@]} -eq 0 ]; then
        return
    fi

    log_verbose "Gathering context from ${#paths[@]} paths..."

    for ctx_path in "${paths[@]}"; do
        if [ -f "$ctx_path" ]; then
            log_verbose "Adding context file: $ctx_path"
            context+="
--- CONTEXT FILE: $(basename "$ctx_path") ---
$(cat "$ctx_path")
--- END CONTEXT FILE ---
"
        elif [ -d "$ctx_path" ]; then
            log_verbose "Adding context directory: $ctx_path"
            local dir_content
            dir_content=$(read_md_files_from_dir "$ctx_path")
            if [ -n "$dir_content" ]; then
                context+="
=== CONTEXT FROM: $ctx_path ===
$dir_content
=== END CONTEXT ===
"
            fi
        else
            log_verbose "Context path not found: $ctx_path"
        fi
    done

    echo "$context"
}

# ─────────────────────────────────────────────────────────────────────────────
# BuildLint Integration
# ─────────────────────────────────────────────────────────────────────────────

# Run BuildLint.sh and capture results
# Usage: run_build_lint [--logs-dir <dir>] [--scheme <scheme>] [--skip-lint]
# Returns: Exit code from BuildLint.sh (0=success, 10=build fail, 11=config error)
run_build_lint() {
    local logs_dir="${LOGS_DIR:-./logs}"
    local lint_exit_code=0
    local lint_args=()

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --logs-dir)
                logs_dir="${2:-}"
                shift 2
                ;;
            --scheme)
                lint_args+=("--scheme" "${2:-}")
                shift 2
                ;;
            --skip-lint)
                lint_args+=("--skip-lint")
                shift 1
                ;;
            --workspace)
                lint_args+=("--workspace" "${2:-}")
                shift 2
                ;;
            --project)
                lint_args+=("--project" "${2:-}")
                shift 2
                ;;
            --configuration)
                lint_args+=("--configuration" "${2:-}")
                shift 2
                ;;
            --derived-data)
                lint_args+=("--derived-data" "${2:-}")
                shift 2
                ;;
            --verbose)
                lint_args+=("--verbose")
                shift 1
                ;;
            *)
                shift 1
                ;;
        esac
    done

    # Add logs directory
    lint_args+=("--logs-dir" "$logs_dir")

    # Add detected project/workspace if not explicitly provided
    local has_project=false
    for arg in "${lint_args[@]}"; do
        if [[ "$arg" == "--workspace" ]] || [[ "$arg" == "--project" ]]; then
            has_project=true
            break
        fi
    done

    if [ "$has_project" = false ]; then
        if [ -n "${XCODE_WORKSPACE:-}" ]; then
            lint_args+=("--workspace" "$XCODE_WORKSPACE")
        elif [ -n "${XCODE_PROJECT:-}" ]; then
            lint_args+=("--project" "$XCODE_PROJECT")
        fi
    fi

    # Check BuildLint.sh exists
    if [ ! -x "$BUILD_LINT_SCRIPT" ]; then
        log_error "BuildLint.sh not found or not executable: $BUILD_LINT_SCRIPT"
        return 11
    fi

    log_verbose "Running BuildLint: ${lint_args[*]}"

    local lint_log="${logs_dir}/buildlint.log"
    mkdir -p "$logs_dir"

    if "$BUILD_LINT_SCRIPT" "${lint_args[@]}" > "$lint_log" 2>&1; then
        lint_exit_code=0
    else
        lint_exit_code=$?
    fi

    # Check for error.log
    if [ -f "${logs_dir}/error.log" ]; then
        lint_exit_code=10
    fi

    if [ $lint_exit_code -eq 0 ]; then
        log_success "Build verification passed"
    else
        log_error "Build verification failed (exit code: $lint_exit_code)"
    fi

    return $lint_exit_code
}

# ─────────────────────────────────────────────────────────────────────────────
# AI CLI Integration
# ─────────────────────────────────────────────────────────────────────────────

# Run AI CLI with context and streaming support
# Usage: run_ai_cli "<prompt>" [--provider <name>] [--model <model>] [--output <file>]
# Returns: Exit code (0=success, 1=failure)
run_ai_cli() {
    local prompt="$1"
    shift

    local ai_provider="${AI_PROVIDER:-cursor}"
    local ai_model=""
    local output_file=""
    local stream_output="${STREAM_OUTPUT:-false}"
    local yolo_mode="${YOLO_MODE:-false}"

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --provider)
                ai_provider="${2:-}"
                shift 2
                ;;
            --model)
                ai_model="${2:-}"
                shift 2
                ;;
            --output)
                output_file="${2:-}"
                shift 2
                ;;
            --stream)
                stream_output="true"
                shift 1
                ;;
            --yolo)
                yolo_mode="true"
                shift 1
                ;;
            *)
                shift 1
                ;;
        esac
    done

    ai_provider=$(echo "$ai_provider" | tr '[:upper:]' '[:lower:]')

    # Detect AI command
    local ai_cmd=""
    case "$ai_provider" in
        cursor)
            if command -v cursor-agent >/dev/null 2>&1; then
                ai_cmd="cursor-agent"
            elif command -v cursor >/dev/null 2>&1; then
                ai_cmd="cursor agent"
            else
                log_error "Cursor CLI not found"
                return 1
            fi
            ;;
        claude)
            if command -v claude >/dev/null 2>&1; then
                ai_cmd="claude"
            else
                log_error "Claude CLI not found"
                return 1
            fi
            ;;
        codex|openai)
            if command -v codex >/dev/null 2>&1; then
                ai_cmd="codex"
            elif command -v openai >/dev/null 2>&1; then
                ai_cmd="openai"
            else
                log_error "OpenAI/Codex CLI not found"
                return 1
            fi
            ;;
        gemini|google)
            if command -v gemini >/dev/null 2>&1; then
                ai_cmd="gemini"
            else
                log_error "Gemini CLI not found"
                return 1
            fi
            ;;
        aider)
            if command -v aider >/dev/null 2>&1; then
                ai_cmd="aider"
            else
                log_error "Aider CLI not found"
                return 1
            fi
            ;;
        letta)
            if command -v letta >/dev/null 2>&1; then
                ai_cmd="letta"
            else
                log_error "Letta CLI not found"
                return 1
            fi
            ;;
        *)
            log_error "Unknown AI provider: $ai_provider"
            return 1
            ;;
    esac

    # Write prompt to temp file for safety
    local prompt_file
    prompt_file=$(mktemp)
    printf '%s' "$prompt" > "$prompt_file"

    # Build command based on provider
    local ai_cmd_full=""
    case "$ai_provider" in
        cursor)
            ai_cmd_full="cat \"$prompt_file\" | $ai_cmd --force --print --output-format text"
            ;;
        claude)
            ai_cmd_full="cat \"$prompt_file\" | $ai_cmd --dangerously-skip-permissions -p -"
            ;;
        codex|openai)
            ai_cmd_full="cat \"$prompt_file\" | $ai_cmd complete --full-auto -"
            ;;
        gemini|google)
            ai_cmd_full="cat \"$prompt_file\" | $ai_cmd generate --yolo"
            ;;
        aider)
            ai_cmd_full="$ai_cmd --yes --message-file \"$prompt_file\""
            ;;
        letta)
            local letta_flags=""
            [ "$yolo_mode" = "true" ] && letta_flags="--yolo"
            ai_cmd_full="cat \"$prompt_file\" | $ai_cmd $letta_flags -p"
            ;;
    esac

    log_verbose "Running AI CLI: $ai_provider"

    local ai_exit_code=0
    if [ -n "$output_file" ]; then
        if (cd "$WORK_DIR" && eval "$ai_cmd_full" > "$output_file" 2>&1); then
            ai_exit_code=0
        else
            ai_exit_code=$?
        fi
    else
        if (cd "$WORK_DIR" && eval "$ai_cmd_full" 2>&1); then
            ai_exit_code=0
        else
            ai_exit_code=$?
        fi
    fi

    rm -f "$prompt_file"

    if [ $ai_exit_code -eq 0 ]; then
        log_success "AI CLI completed"
    else
        log_error "AI CLI failed (exit code: $ai_exit_code)"
    fi

    return $ai_exit_code
}

# ─────────────────────────────────────────────────────────────────────────────
# Report Generation
# ─────────────────────────────────────────────────────────────────────────────

# Generate HTML report
# Usage: generate_report --title "<title>" --format <html|json|markdown> --output <file> [--data <json>]
generate_report() {
    local title=""
    local format="html"
    local output_file=""
    local data=""
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --title)
                title="${2:-}"
                shift 2
                ;;
            --format)
                format="${2:-html}"
                shift 2
                ;;
            --output)
                output_file="${2:-}"
                shift 2
                ;;
            --data)
                data="${2:-}"
                shift 2
                ;;
            *)
                shift 1
                ;;
        esac
    done

    if [ -z "$output_file" ]; then
        log_error "Output file required for report generation"
        return 1
    fi

    mkdir -p "$(dirname "$output_file")"

    case "$format" in
        html)
            cat > "$output_file" << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>${title}</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; margin: 40px; background: #f5f5f7; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 40px; border-radius: 12px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1 { color: #1d1d1f; border-bottom: 2px solid #0066cc; padding-bottom: 10px; }
        .meta { color: #86868b; font-size: 14px; margin-bottom: 20px; }
        .section { margin: 20px 0; padding: 20px; background: #f5f5f7; border-radius: 8px; }
        .success { color: #34c759; }
        .failure { color: #ff3b30; }
        .warning { color: #ff9500; }
        pre { background: #1d1d1f; color: #f5f5f7; padding: 15px; border-radius: 8px; overflow-x: auto; }
        table { width: 100%; border-collapse: collapse; margin: 10px 0; }
        th, td { padding: 12px; text-align: left; border-bottom: 1px solid #d2d2d7; }
        th { background: #f5f5f7; font-weight: 600; }
    </style>
</head>
<body>
    <div class="container">
        <h1>${title}</h1>
        <div class="meta">Generated: ${timestamp}</div>
        <div class="content">
            ${data}
        </div>
    </div>
</body>
</html>
EOF
            ;;
        json)
            cat > "$output_file" << EOF
{
    "title": "${title}",
    "timestamp": "${timestamp}",
    "data": ${data:-{}}
}
EOF
            ;;
        markdown)
            cat > "$output_file" << EOF
# ${title}

**Generated:** ${timestamp}

${data}
EOF
            ;;
    esac

    log_success "Report generated: $output_file"
    return 0
}

# ─────────────────────────────────────────────────────────────────────────────
# Log Directory Setup
# ─────────────────────────────────────────────────────────────────────────────

# Setup timestamped logs directory
# Usage: setup_logs_dir [base_dir]
# Returns: Sets LOGS_DIR global variable
setup_logs_dir() {
    local base_dir="${1:-${ARTIFACTS_DIR:-./Artifacts}}"
    local run_id
    run_id="$(date +%Y%m%d_%H%M%S)"

    LOGS_DIR="${base_dir}/test_${run_id}/logs"
    STATUS_DIR="${base_dir}/test_${run_id}/status"
    ARTIFACTS_RUN_DIR="${base_dir}/test_${run_id}"

    if ! mkdir -p "$LOGS_DIR"; then
        log_error "Failed to create logs directory: $LOGS_DIR"
        return 1
    fi

    if ! mkdir -p "$STATUS_DIR"; then
        log_error "Failed to create status directory: $STATUS_DIR"
        return 1
    fi

    log_verbose "Logs directory: $LOGS_DIR"
    log_verbose "Status directory: $STATUS_DIR"

    return 0
}

# ─────────────────────────────────────────────────────────────────────────────
# Error and Success Logging
# ─────────────────────────────────────────────────────────────────────────────

# Write standardized error log
# Usage: write_error_log "<message>" [additional_context]
write_error_log() {
    local message="$1"
    local context="${2:-}"
    local error_file="${LOGS_DIR:-./logs}/error.log"

    mkdir -p "$(dirname "$error_file")"

    {
        echo "═══════════════════════════════════════════════════════"
        echo "ERROR LOG"
        echo "═══════════════════════════════════════════════════════"
        echo "Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
        echo "Message: $message"
        if [ -n "$context" ]; then
            echo ""
            echo "Context:"
            echo "$context"
        fi
        echo ""
        echo "Configuration:"
        echo "  Project Root: ${PROJECT_ROOT:-unknown}"
        echo "  Work Dir: ${WORK_DIR:-unknown}"
        echo "  Scheme: ${SCHEME:-auto-detect}"
        echo "  AI Provider: ${AI_PROVIDER:-cursor}"
        echo "═══════════════════════════════════════════════════════"
    } >> "$error_file"

    log_error "Error logged to: $error_file"
}

# Write standardized success log
# Usage: write_success_log "<message>" [metrics]
write_success_log() {
    local message="$1"
    local metrics="${2:-}"
    local success_file="${STATUS_DIR:-./status}/success.txt"

    mkdir -p "$(dirname "$success_file")"

    {
        echo "═══════════════════════════════════════════════════════"
        echo "SUCCESS"
        echo "═══════════════════════════════════════════════════════"
        echo "Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
        echo "Message: $message"
        if [ -n "$metrics" ]; then
            echo ""
            echo "Metrics:"
            echo "$metrics"
        fi
        echo "═══════════════════════════════════════════════════════"
    } > "$success_file"

    log_success "Success logged to: $success_file"
}

# ─────────────────────────────────────────────────────────────────────────────
# Flow JSON Validation
# ─────────────────────────────────────────────────────────────────────────────

# Validate flow JSON structure
# Usage: validate_flow_json "<json_file>"
# Returns: 0 if valid, 1 if invalid
validate_flow_json() {
    local json_file="$1"

    if [ ! -f "$json_file" ]; then
        log_error "Flow JSON file not found: $json_file"
        return 1
    fi

    # Check if jq is available
    if ! command -v jq >/dev/null 2>&1; then
        log_warning "jq not installed, skipping JSON validation"
        return 0
    fi

    # Validate JSON syntax
    if ! jq empty "$json_file" 2>/dev/null; then
        log_error "Invalid JSON syntax in: $json_file"
        return 1
    fi

    # Validate required fields
    local flows_count
    flows_count=$(jq '.flows | length' "$json_file" 2>/dev/null || echo "0")

    if [ "$flows_count" -eq 0 ]; then
        log_warning "No flows found in JSON file"
        return 0
    fi

    # Validate each flow has required fields
    local invalid_flows
    invalid_flows=$(jq '[.flows[] | select(.name == null or .type == null or .steps == null)] | length' "$json_file" 2>/dev/null || echo "0")

    if [ "$invalid_flows" -gt 0 ]; then
        log_error "Found $invalid_flows flows missing required fields (name, type, steps)"
        return 1
    fi

    # Validate flow types
    local invalid_types
    invalid_types=$(jq '[.flows[] | select(.type != "happy" and .type != "sad" and .type != "regression")] | length' "$json_file" 2>/dev/null || echo "0")

    if [ "$invalid_types" -gt 0 ]; then
        log_warning "Found $invalid_types flows with non-standard types (expected: happy, sad, regression)"
    fi

    log_success "Flow JSON validated: $flows_count flows"
    return 0
}

# ─────────────────────────────────────────────────────────────────────────────
# Swift File Analysis
# ─────────────────────────────────────────────────────────────────────────────

# Find Swift source files (excluding tests, dependencies)
# Usage: find_swift_source_files [directory]
# Returns: List of Swift files
find_swift_source_files() {
    local search_dir="${1:-$WORK_DIR}"

    find "$search_dir" -name "*.swift" -type f \
        -not -path "*/.build/*" \
        -not -path "*/Pods/*" \
        -not -path "*/Carthage/*" \
        -not -path "*/checkouts/*" \
        -not -path "*/DerivedData/*" \
        -not -path "*Tests/*" \
        -not -path "*Test/*" \
        -not -name "*Tests.swift" \
        -not -name "*Test.swift" \
        2>/dev/null | sort
}

# Find Swift test files
# Usage: find_swift_test_files [directory]
# Returns: List of test Swift files
find_swift_test_files() {
    local search_dir="${1:-$WORK_DIR}"

    find "$search_dir" -name "*Tests.swift" -o -name "*Test.swift" -type f \
        -not -path "*/.build/*" \
        -not -path "*/Pods/*" \
        -not -path "*/Carthage/*" \
        2>/dev/null | sort
}

# Find SwiftUI view files
# Usage: find_swiftui_views [directory]
# Returns: List of files containing SwiftUI View protocol
find_swiftui_views() {
    local search_dir="${1:-$WORK_DIR}"

    grep -l ": View" "$search_dir"/*.swift 2>/dev/null | sort || \
    find "$search_dir" -name "*.swift" -type f -exec grep -l ": View" {} \; 2>/dev/null | sort
}

# ─────────────────────────────────────────────────────────────────────────────
# Test Target Detection
# ─────────────────────────────────────────────────────────────────────────────

# Detect test target directory
# Usage: detect_test_target_dir [project_dir]
# Returns: Path to test target directory
detect_test_target_dir() {
    local project_dir="${1:-$WORK_DIR}"

    # Common test directory patterns
    local test_dirs=(
        "${project_dir}Tests"
        "${project_dir}/Tests"
        "${project_dir}/*Tests"
        "${project_dir}/*/Tests"
    )

    for pattern in "${test_dirs[@]}"; do
        local found_dir
        found_dir=$(find "$project_dir" -maxdepth 2 -type d -name "*Tests" 2>/dev/null | head -1)
        if [ -n "$found_dir" ]; then
            echo "$found_dir"
            return 0
        fi
    done

    # Fallback: create Tests directory
    echo "${project_dir}/Tests"
    return 1
}

# Detect UI test target directory
# Usage: detect_ui_test_target_dir [project_dir]
# Returns: Path to UI test target directory
detect_ui_test_target_dir() {
    local project_dir="${1:-$WORK_DIR}"

    local found_dir
    found_dir=$(find "$project_dir" -maxdepth 2 -type d -name "*UITests" 2>/dev/null | head -1)

    if [ -n "$found_dir" ]; then
        echo "$found_dir"
        return 0
    fi

    # Fallback
    echo "${project_dir}/UITests"
    return 1
}

# ─────────────────────────────────────────────────────────────────────────────
# Export Functions
# ─────────────────────────────────────────────────────────────────────────────

export -f log_info
export -f log_success
export -f log_warning
export -f log_error
export -f log_section
export -f log_verbose
export -f detect_xcode_project
export -f detect_scheme
export -f gather_test_context
export -f run_build_lint
export -f run_ai_cli
export -f generate_report
export -f setup_logs_dir
export -f write_error_log
export -f write_success_log
export -f validate_flow_json
export -f find_swift_source_files
export -f find_swift_test_files
export -f find_swiftui_views
export -f detect_test_target_dir
export -f detect_ui_test_target_dir
