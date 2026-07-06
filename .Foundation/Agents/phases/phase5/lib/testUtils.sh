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
# Context Cache Functions
# ─────────────────────────────────────────────────────────────────────────────

# Directory for cached context (shared across agents)
CONTEXT_CACHE_DIR="${ARTIFACTS_DIR:-./Artifacts}/.context_cache"

# Compute a cache key from an array of paths plus an optional prompt/settings string
# Usage: compute_context_key "prompt_or_settings" "${paths[@]}"
compute_context_key() {
    local settings="$1"
    shift
    local paths=("$@")
    local key_input=""

    for p in "${paths[@]+"${paths[@]}"}"; do
        key_input+="${p}:"
    done
    key_input+="|${settings}"

    # Use md5 or shasum for hash
    if command -v md5 >/dev/null 2>&1; then
        echo "$key_input" | md5
    elif command -v md5sum >/dev/null 2>&1; then
        echo "$key_input" | md5sum | awk '{print $1}'
    else
        # Fallback: use key directly (less safe but functional)
        echo "$key_input" | tr -dc '[:alnum:]._-' | head -c 64
    fi
}

# Compute a stable hash of a prompt string for state tracking
# Usage: compute_prompt_hash "prompt text"
compute_prompt_hash() {
    local prompt="$1"
    if command -v md5 >/dev/null 2>&1; then
        echo "$prompt" | md5
    elif command -v md5sum >/dev/null 2>&1; then
        echo "$prompt" | md5sum | awk '{print $1}'
    else
        # Fallback: truncate and sanitize
        echo "$prompt" | tr -dc '[:alnum:]._-' | head -c 64
    fi
}

# Save gathered context to disk cache with manifest of source file mtimes
# Usage: save_context_cache <key> <context> "${paths[@]}"
save_context_cache() {
    local key="$1"
    local context="$2"
    shift 2
    local paths=("$@")

    mkdir -p "$CONTEXT_CACHE_DIR"

    echo "$context" > "${CONTEXT_CACHE_DIR}/context.txt"
    echo "$key" > "${CONTEXT_CACHE_DIR}/key.txt"

    # Write manifest: type|path|mtime|size
    local manifest="${CONTEXT_CACHE_DIR}/manifest.txt"
    > "$manifest"
    for p in "${paths[@]+"${paths[@]}"}"; do
        if [ -f "$p" ]; then
            local mtime size
            mtime=$(stat -f %m "$p" 2>/dev/null || stat -c %Y "$p" 2>/dev/null || echo "0")
            size=$(stat -f %z "$p" 2>/dev/null || stat -c %s "$p" 2>/dev/null || echo "0")
            echo "F|${p}|${mtime}|${size}" >> "$manifest"
        elif [ -d "$p" ]; then
            # For directories, track the newest mtime of any .md file up to 2 levels
            local latest_mtime
            latest_mtime=$(find "$p" -maxdepth 2 -name "*.md" -type f -exec stat -f %m {} + 2>/dev/null | sort -rn | head -1 || echo "0")
            echo "D|${p}|${latest_mtime}|0" >> "$manifest"
        fi
    done

    log_verbose "Context cached to ${CONTEXT_CACHE_DIR}"
}

# Load cached context if key and all mtimes match
# Usage: load_context_cache <key> "${paths[@]}"
# Returns: 0 + echoes context if valid, 1 if stale/missing
load_context_cache() {
    local key="$1"
    shift
    local paths=("$@")

    local context_file="${CONTEXT_CACHE_DIR}/context.txt"
    local key_file="${CONTEXT_CACHE_DIR}/key.txt"
    local manifest="${CONTEXT_CACHE_DIR}/manifest.txt"

    if [ ! -f "$context_file" ] || [ ! -f "$key_file" ] || [ ! -f "$manifest" ]; then
        return 1
    fi

    local cached_key
    cached_key=$(cat "$key_file" 2>/dev/null || echo "")
    if [ "$cached_key" != "$key" ]; then
        log_verbose "Context cache key mismatch, regathering..."
        return 1
    fi

    # Validate manifest entries
    while IFS='|' read -r type path mtime size; do
        if [ "$type" = "F" ]; then
            if [ ! -f "$path" ]; then
                log_verbose "Context cache stale: missing file $path"
                return 1
            fi
            local current_mtime current_size
            current_mtime=$(stat -f %m "$path" 2>/dev/null || stat -c %Y "$path" 2>/dev/null || echo "0")
            current_size=$(stat -f %z "$path" 2>/dev/null || stat -c %s "$path" 2>/dev/null || echo "0")
            if [ "$current_mtime" != "$mtime" ] || [ "$current_size" != "$size" ]; then
                log_verbose "Context cache stale: modified file $path"
                return 1
            fi
        elif [ "$type" = "D" ]; then
            if [ ! -d "$path" ]; then
                log_verbose "Context cache stale: missing directory $path"
                return 1
            fi
            local current_mtime
            current_mtime=$(find "$path" -maxdepth 2 -name "*.md" -type f -exec stat -f %m {} + 2>/dev/null | sort -rn | head -1 || echo "0")
            if [ "$current_mtime" != "$mtime" ]; then
                log_verbose "Context cache stale: modified directory $path"
                return 1
            fi
        fi
    done < "$manifest"

    log_info "Using cached context (${#paths[@]} source(s) unchanged)"
    cat "$context_file"
    return 0
}

# ─────────────────────────────────────────────────────────────────────────────
# Simulator Detection
# ─────────────────────────────────────────────────────────────────────────────

# Detect the best available iPhone simulator for a given scheme.
# Queries xcodebuild -showdestinations and returns the first non-placeholder
# iPhone simulator name. Falls back to generic destination.
# Usage: detect_available_simulator [scheme] [project] [workspace]
detect_available_simulator() {
    local scheme="${1:-}"
    local project="${2:-}"
    local workspace="${3:-}"

    local cmd_args=("xcodebuild")
    if [ -n "$workspace" ]; then
        cmd_args+=("-workspace" "$workspace")
    elif [ -n "$project" ]; then
        cmd_args+=("-project" "$project")
    fi

    if [ -n "$scheme" ]; then
        cmd_args+=("-scheme" "$scheme")
    fi

    if [ ${#cmd_args[@]} -gt 1 ]; then
        local destinations
        destinations=$("${cmd_args[@]}" -showdestinations 2>/dev/null | grep "platform:iOS Simulator" | grep "name:iPhone" | grep -v "placeholder")
        # Prefer Pro Max, then Pro, then any iPhone
        local available_sim
        available_sim=$(echo "$destinations" | grep "Pro Max" | head -1 | sed -n 's/.*name:\([^,}]*\).*/\1/p' | xargs)
        if [ -z "$available_sim" ]; then
            available_sim=$(echo "$destinations" | grep "Pro" | head -1 | sed -n 's/.*name:\([^,}]*\).*/\1/p' | xargs)
        fi
        if [ -z "$available_sim" ]; then
            available_sim=$(echo "$destinations" | head -1 | sed -n 's/.*name:\([^,}]*\).*/\1/p' | xargs)
        fi
        if [ -n "$available_sim" ]; then
            echo "$available_sim"
            return 0
        fi
    fi

    # Fallback: use xcrun simctl — prefer Pro Max, then Pro, then standard
    local simctl_json
    simctl_json=$(xcrun simctl list devices available -j 2>/dev/null)
    # 1. Try Pro Max first (latest)
    local fallback_sim
    fallback_sim=$(echo "$simctl_json" | jq -r '.devices | to_entries[] | .value[] | select(.name | test("^iPhone [0-9]+ Pro Max$")) | .name' | sort -V | tail -1)
    # 2. Try Pro
    if [ -z "$fallback_sim" ]; then
        fallback_sim=$(echo "$simctl_json" | jq -r '.devices | to_entries[] | .value[] | select(.name | test("^iPhone [0-9]+ Pro$")) | .name' | sort -V | tail -1)
    fi
    # 3. Try standard iPhone
    if [ -z "$fallback_sim" ]; then
        fallback_sim=$(echo "$simctl_json" | jq -r '.devices | to_entries[] | .value[] | select(.name | test("^iPhone [0-9]+$")) | .name' | sort -V | tail -1)
    fi
    # 4. Try Plus / Air / SE / any iPhone
    if [ -z "$fallback_sim" ]; then
        fallback_sim=$(echo "$simctl_json" | jq -r '.devices | to_entries[] | .value[] | select(.name | test("^iPhone")) | .name' | sort -V | tail -1)
    fi
    if [ -n "$fallback_sim" ]; then
        echo "$fallback_sim"
        return 0
    fi

    echo ""
    return 1
}

# Context Gathering Functions
# ─────────────────────────────────────────────────────────────────────────────

# Offer user a chance to skip context gathering before it starts
# Usage: prompt_skip_context <description>
# Returns: 0 if user chose to skip, 1 otherwise
prompt_skip_context() {
    local description="${1:-context gathering}"

    # Only prompt if running interactively
    if [ ! -t 0 ]; then
        return 1
    fi

    # Respect env flag to disable prompt (for CI/automation)
    if [ "${SKIP_CONTEXT_PROMPT:-false}" = "true" ]; then
        return 1
    fi

    local timeout_secs=3
    local spin_chars="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
    local spin_len=${#spin_chars}
    echo "" >&2
    log_info "$description starting..."

    (
        local elapsed=0
        local spin_idx=0
        while [ $elapsed -lt $timeout_secs ]; do
            local spin_char="${spin_chars:spin_idx:1}"
            local remaining=$((timeout_secs - elapsed))
            printf "\r\033[K\033[36m[%s]\033[0m Press \033[1m's'\033[0m to skip %s (%ds left)" "$spin_char" "$description" "$remaining" >&2
            spin_idx=$(((spin_idx + 1) % spin_len))
            sleep 0.15
            local _tmp=$((elapsed * 100 + 15))
            if [ "$_tmp" -ge $(((elapsed + 1) * 100)) ]; then
                elapsed=$((elapsed + 1))
            fi
        done
        printf "\r\033[K" >&2
    ) &
    local spinner_pid=$!

    local key=""
    if IFS= read -rs -t $timeout_secs -n 1 key 2>/dev/null; then
        kill "$spinner_pid" 2>/dev/null
        wait "$spinner_pid" 2>/dev/null
        printf "\r\033[K" >&2
        if [ "$key" = "s" ] || [ "$key" = "S" ]; then
            echo "" >&2
            log_info "Skipping $description"
            echo "" >&2
            return 0
        fi
    fi

    kill "$spinner_pid" 2>/dev/null
    wait "$spinner_pid" 2>/dev/null
    printf "\r\033[K" >&2
    echo "" >&2
    return 1
}

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
# Usage: gather_test_context [--cache-key <key>] "${CONTEXT_PATHS[@]}"
# Returns: Aggregated context string
# If --cache-key is provided, checks disk cache first and saves after gathering.
gather_test_context() {
    local cache_key=""
    local paths=()

    # Parse optional --cache-key
    while [ $# -gt 0 ]; do
        case "$1" in
            --cache-key)
                cache_key="$2"
                shift 2
                ;;
            *)
                paths+=("$1")
                shift
                ;;
        esac
    done

    if [ ${#paths[@]} -eq 0 ]; then
        return
    fi

    # Offer user chance to skip
    if prompt_skip_context "Context gathering"; then
        return
    fi

    # Try cache first
    if [ -n "$cache_key" ]; then
        if load_context_cache "$cache_key" "${paths[@]}"; then
            return 0
        fi
    fi

    log_verbose "Gathering context from ${#paths[@]} paths..."

    local context=""
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

    # Save to cache
    if [ -n "$cache_key" ]; then
        save_context_cache "$cache_key" "$context" "${paths[@]}"
    fi

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
        claude|anthropic)
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
        kimi|kimi-code|moonshot)
            if command -v kimi >/dev/null 2>&1; then
                ai_cmd="kimi"
            else
                log_error "Kimi CLI not found"
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
        claude|anthropic)
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
        kimi|kimi-code|moonshot)
            # Use stream-json to avoid Rich markup parsing issues with brackets in prompts
            local kimi_mcp_config
            kimi_mcp_config=$(mktemp /tmp/kimi_mcp_empty.XXXXXX)
            echo '{"mcpServers":{}}' > "$kimi_mcp_config"
            local kimi_flags="--yolo --print --output-format stream-json --mcp-config-file \"$kimi_mcp_config\""
            if [ -n "${ai_model:-}" ]; then
                kimi_flags="$kimi_flags --model \"$ai_model\""
            fi
            if command -v jq &>/dev/null; then
                ai_cmd_full="cat \"$prompt_file\" | $ai_cmd $kimi_flags 2>&1 | grep '^\\s*{' | jq -r 'select(.role==\"assistant\") | .content[]? | select(.type==\"text\") | .text'"
            else
                ai_cmd_full="cat \"$prompt_file\" | $ai_cmd $kimi_flags"
            fi
            # Schedule cleanup of temp MCP config after eval
            ai_cmd_full="$ai_cmd_full; rm -f \"$kimi_mcp_config\""
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

# Extract Swift code from AI markdown output
# Tries ```swift fences first, then plain ``` fences, then falls back to raw minus fences.
# Returns empty string and exit 1 if no Swift syntax markers are detected (prose-only).
# Usage: extract_swift_code "<raw_ai_output>"
extract_swift_code() {
    local raw="$1"
    local extracted=""

    # 1. Try ```swift blocks (case-insensitive, optional trailing whitespace)
    extracted=$(echo "$raw" | awk 'tolower($0) ~ /^```swift\s*$/{flag=1;next}/^```\s*$/{flag=0;next}flag')

    # 2. If empty, try plain ``` blocks (first pair only)
    if [ -z "$extracted" ]; then
        extracted=$(echo "$raw" | awk '/^```\s*$/{if(!started){started=1;flag=1;next}else{flag=0;next}}flag')
    fi

    # 3. If still empty, fall back to raw with fence lines removed
    if [ -z "$extracted" ]; then
        extracted=$(echo "$raw" | sed -E '/^```(swift)?\s*$/d')
    fi

    # 4. Validate: must contain actual Swift syntax markers
    # Look for at least one of: import, class, struct, enum, func, extension, protocol, @Test, @MainActor
    if ! echo "$extracted" | grep -qiE '^[[:space:]]*(import|class|struct|enum|func|extension|protocol|@)' ; then
        echo ""
        return 1
    fi

    # 5. Validate: must NOT be truncated (look for placeholder patterns)
    if echo "$extracted" | grep -qE '^[[:space:]]*//+[[:space:]]*\.\.\.|//+[[:space:]]*full (test )?suite|//+[[:space:]]*remaining|//+[[:space:]]*continued|//+[[:space:]]*truncated' ; then
        echo ""
        return 1
    fi

    # 6. Validate: first non-empty line should start with import, @, class, struct, enum, or extension
    local first_line
    first_line=$(echo "$extracted" | sed '/^[[:space:]]*$/d' | head -n 1)
    if ! echo "$first_line" | grep -qiE '^[[:space:]]*(import|@|class|struct|enum|extension)' ; then
        echo ""
        return 1
    fi

    echo "$extracted"
    return 0
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
    "data": $(if [ -n "${data:-}" ]; then echo "$data"; else echo "{}"; fi)
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

    # If the base directory already looks like a timestamped run directory
    # (e.g., Artifacts/test_20260605_121738 or Artifacts/build_20260605_121738),
    # reuse it directly instead of creating a nested directory.
    if echo "$base_dir" | grep -qE '/(test_|build_)[0-9]{8}_[0-9]{6}$'; then
        LOGS_DIR="${base_dir}/logs"
        STATUS_DIR="${base_dir}/status"
        ARTIFACTS_RUN_DIR="$base_dir"
        if ! mkdir -p "$LOGS_DIR"; then
            log_error "Failed to create logs directory: $LOGS_DIR"
            return 1
        fi
        if ! mkdir -p "$STATUS_DIR"; then
            log_error "Failed to create status directory: $STATUS_DIR"
            return 1
        fi
        log_verbose "Reusing run directory: $ARTIFACTS_RUN_DIR"
        log_verbose "Logs directory: $LOGS_DIR"
        log_verbose "Status directory: $STATUS_DIR"
        return 0
    fi

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
        -not -path "*/Docs/*" \
        -not -path "*/docs/*" \
        -not -path "*/Artifacts/*" \
        -not -path "*Tests/*" \
        -not -path "*Test/*" \
        -not -name "*Tests.swift" \
        -not -name "*Test.swift" \
        2>/dev/null | sort -u
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
# ─────────────────────────────────────────────────────────────────────────────
# Build Agent State Persistence (prompt completion tracking)
# ─────────────────────────────────────────────────────────────────────────────

# State file location: Artifacts/.build_state/completed_prompts.jsonl
_BUILD_STATE_DIR="${ARTIFACTS_DIR:-./Artifacts}/.build_state"
_COMPLETED_PROMPTS_FILE="$_BUILD_STATE_DIR/completed_prompts.jsonl"

# Compute a stable hash for a prompt string
compute_prompt_hash() {
    local input="$1"
    if [ -z "$input" ]; then
        echo ""
        return 0
    fi
    # Normalize: trim leading/trailing whitespace, collapse whitespace
    local normalized
    normalized=$(echo "$input" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | tr -s '[:space:]')
    printf '%s' "$normalized" | md5 2>/dev/null || printf '%s' "$normalized" | md5sum 2>/dev/null | awk '{print $1}' || echo ""
}

# Check if a prompt was already completed successfully
check_prompt_already_done() {
    local input="$1"
    if [ -z "$input" ]; then
        return 1  # Not done (no prompt)
    fi
    if [ ! -f "$_COMPLETED_PROMPTS_FILE" ]; then
        return 1  # Not done (no state file)
    fi

    local hash
    hash=$(compute_prompt_hash "$input")
    if [ -z "$hash" ]; then
        return 1
    fi

    # Check if hash exists in state file
    grep -q "\"hash\":\"$hash\"" "$_COMPLETED_PROMPTS_FILE" 2>/dev/null
}

# Mark a prompt as completed
save_prompt_completion() {
    local input="$1"
    local plan_ref="${2:-}"
    local metadata="${3:-{}}"

    if [ -z "$input" ]; then
        return 0  # Nothing to save
    fi

    local hash
    hash=$(compute_prompt_hash "$input")
    if [ -z "$hash" ]; then
        return 1
    fi

    mkdir -p "$_BUILD_STATE_DIR"

    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Append a JSON line (JSONL format)
    printf '{"hash":"%s","completed_at":"%s","plan_ref":"%s","metadata":%s}\n' \
        "$hash" "$timestamp" "$plan_ref" "$metadata" >> "$_COMPLETED_PROMPTS_FILE"
}

# ─────────────────────────────────────────────────────────────────────────────
# Provider Selection via Multi-Armed Bandit Algorithms
# Based on: Kochenderfer et al., "Algorithms for Decision Making", Ch.15
# ─────────────────────────────────────────────────────────────────────────────

_PROVIDER_SCOREBOARD="${ARTIFACTS_DIR:-./Artifacts}/.provider_scoreboard.json"

# Beta prior parameters (uniform prior = Beta(1,1))
_PROVIDER_BETA_PRIOR_ALPHA=1
_PROVIDER_BETA_PRIOR_BETA=1

# Initialize scoreboard with all available providers.
# If file exists, ensure all discovered providers have proper schema defaults.
_init_provider_scoreboard() {
    local scoreboard="${_PROVIDER_SCOREBOARD}"
    local providers=()
    while IFS= read -r p; do
        [ -n "$p" ] && providers+=("$p")
    done <<< "$(discover_available_providers)"
    if [ ${#providers[@]} -eq 0 ]; then
        return 1
    fi

    if [ ! -f "$scoreboard" ]; then
        local entries=""
        for p in "${providers[@]}"; do
            [ -n "$entries" ] && entries+=","
            entries+="\"$p\":{\"successes\":0,\"failures\":0,\"timeouts\":0,\"stalls\":0,\"total_time\":0,\"last_used\":\"\",\"alpha\":${_PROVIDER_BETA_PRIOR_ALPHA},\"beta\":${_PROVIDER_BETA_PRIOR_BETA}}"
        done
        mkdir -p "$(dirname "$scoreboard")"
        echo "{$entries}" > "$scoreboard"
        return 0
    fi

    # File exists — ensure all providers have alpha/beta and count fields
    local tmp_file
    tmp_file=$(mktemp)
    cp "$scoreboard" "$tmp_file"
    for p in "${providers[@]}"; do
        local tmp2
        tmp2=$(mktemp)
        jq --arg p "$p" \
           --argjson a "${_PROVIDER_BETA_PRIOR_ALPHA}" \
           --argjson b "${_PROVIDER_BETA_PRIOR_BETA}" \
           '.[$p].successes     //= 0 |
            .[$p].failures      //= 0 |
            .[$p].timeouts      //= 0 |
            .[$p].stalls        //= 0 |
            .[$p].total_time    //= 0 |
            .[$p].alpha         //= $a |
            .[$p].beta          //= $b' \
           "$tmp_file" > "$tmp2" 2>/dev/null || cp "$tmp_file" "$tmp2"
        mv "$tmp2" "$tmp_file"
    done
    mv "$tmp_file" "$scoreboard"
}

# Record result for a provider.
# Results map to reward values per the textbook's binary bandit framework,
# extended with partial rewards for timeout/stall (provider works but is slow).
#   success  -> r=1.0  (full reward)
#   stall    -> r=0.5  (partial — provider responded but was very slow)
#   timeout  -> r=0.25 (partial — provider failed to respond in time)
#   failure  -> r=0.0  (full penalty — provider responded with bad output)
# The Beta posterior is updated: Beta(α + r, β + (1-r))
record_provider_result() {
    local provider="$1"
    local result="$2"   # "success" | "failure" | "timeout" | "stall"
    local duration="${3:-0}"
    local scoreboard="${_PROVIDER_SCOREBOARD}"

    if [ ! -f "$scoreboard" ]; then
        _init_provider_scoreboard || return 1
    fi

    local tmp_file
    tmp_file=$(mktemp)

    case "$result" in
        success)
            jq --arg p "$provider" --argjson d "$duration" \
               '.[$p].successes += 1 | .[$p].total_time += $d | .[$p].last_used = now | .[$p].alpha += 1.0 | .[$p].beta += 0.0' \
               "$scoreboard" > "$tmp_file" 2>/dev/null || cat "$scoreboard" > "$tmp_file"
            ;;
        stall)
            jq --arg p "$provider" --argjson d "$duration" \
               '.[$p].stalls += 1 | .[$p].total_time += $d | .[$p].last_used = now | .[$p].alpha += 0.5 | .[$p].beta += 0.5' \
               "$scoreboard" > "$tmp_file" 2>/dev/null || cat "$scoreboard" > "$tmp_file"
            ;;
        timeout)
            jq --arg p "$provider" --argjson d "$duration" \
               '.[$p].timeouts += 1 | .[$p].total_time += $d | .[$p].last_used = now | .[$p].alpha += 0.25 | .[$p].beta += 0.75' \
               "$scoreboard" > "$tmp_file" 2>/dev/null || cat "$scoreboard" > "$tmp_file"
            ;;
        failure)
            jq --arg p "$provider" --argjson d "$duration" \
               '.[$p].failures += 1 | .[$p].total_time += $d | .[$p].last_used = now | .[$p].alpha += 0.0 | .[$p].beta += 1.0' \
               "$scoreboard" > "$tmp_file" 2>/dev/null || cat "$scoreboard" > "$tmp_file"
            ;;
        *)
            cat "$scoreboard" > "$tmp_file"
            ;;
    esac

    mv "$tmp_file" "$scoreboard"
}

# ─────────────────────────────────────────────────────────────────────────────
# UCB1 Provider Selection (Algorithm 15.7)
# Uses Beta posterior parameters as pseudocounts for N(a), as suggested
# in the textbook: "we can adapt it to the Bayesian context by having N(a)
# be the sum of the beta distribution parameters associated with a."
# ─────────────────────────────────────────────────────────────────────────────
select_provider_ucb1() {
    local explore_factor="${1:-0.5}"
    local scoreboard="${_PROVIDER_SCOREBOARD}"

    if [ ! -f "$scoreboard" ]; then
        _init_provider_scoreboard || return 1
    fi

    local best_provider=""
    local best_score=-1

    while IFS= read -r line; do
        local provider="${line%%$'\t'*}"
        local stats="${line#*$'\t'}"
        local alpha=$(echo "$stats" | jq '.alpha // 1')
        local beta=$(echo "$stats" | jq '.beta // 1')
        local pulls=$(awk "BEGIN {print $alpha + $beta - ${_PROVIDER_BETA_PRIOR_ALPHA} - ${_PROVIDER_BETA_PRIOR_BETA}}")

        if [ "$(awk "BEGIN {print ($pulls < 1) ? 1 : 0}")" -eq 1 ]; then
            # Unexplored or minimally explored — prioritize discovery
            echo "$provider"
            return 0
        fi

        local mean_reward
        mean_reward=$(awk "BEGIN {print ($alpha - ${_PROVIDER_BETA_PRIOR_ALPHA}) / $pulls}")

        # Total pseudocounts across all providers
        local total_pulls
        total_pulls=$(jq '[.[] | (.alpha + .beta)] | add' "$scoreboard")
        if [ -z "$total_pulls" ] || [ "$total_pulls" = "0" ] || [ "$total_pulls" = "null" ]; then
            total_pulls=2
        fi

        local na
        na=$(awk "BEGIN {print $alpha + $beta - ${_PROVIDER_BETA_PRIOR_ALPHA} - ${_PROVIDER_BETA_PRIOR_BETA}}")
        if [ "$(awk "BEGIN {print ($na < 1) ? 1 : 0}")" -eq 1 ]; then
            na=1
        fi

        local ucb
        ucb=$(awk -v mean="$mean_reward" -v total="$total_pulls" -v na="$na" -v c="$explore_factor" \
              'BEGIN {print mean + c * sqrt(log(total) / na)}')

        if [ "$best_score" = "-1" ] || [ "$(awk -v a="$ucb" -v b="$best_score" 'BEGIN {print (a > b) ? 1 : 0}')" -eq 1 ]; then
            best_score="$ucb"
            best_provider="$provider"
        fi
    done <<< "$(jq -r 'to_entries[] | "\(.key)\t\(.value)"' "$scoreboard" 2>/dev/null)"

    if [ -n "$best_provider" ]; then
        echo "$best_provider"
    else
        discover_available_providers | head -1
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Thompson Sampling (Posterior Sampling) Provider Selection (Algorithm 15.8)
# "Simple to implement and does not require careful parameter tuning."
# Sample from each provider's Beta posterior, pick the one with max sample.
# More robust than UCB1 for small sample sizes.
# ─────────────────────────────────────────────────────────────────────────────
select_provider_thompson() {
    local scoreboard="${_PROVIDER_SCOREBOARD}"

    if [ ! -f "$scoreboard" ]; then
        _init_provider_scoreboard || return 1
    fi

    local best_provider=""
    local best_sample=-1

    while IFS= read -r line; do
        local provider="${line%%$'\t'*}"
        local stats="${line#*$'\t'}"
        local alpha=$(echo "$stats" | jq '.alpha // 1')
        local beta=$(echo "$stats" | jq '.beta // 1')

        # Sample from Beta(α, β) using the Gamma ratio method.
        # On macOS / POSIX: use python3 for reliable Beta sampling.
        local sample
        if command -v python3 >/dev/null 2>&1; then
            sample=$(python3 -c "import random; random.seed(); print(random.betavariate($alpha, $beta))")
        else
            # Fallback: use mean (degrades to greedy, but functional)
            sample=$(awk "BEGIN {print $alpha / ($alpha + $beta)}")
        fi

        if [ "$best_sample" = "-1" ] || [ "$(awk -v a="$sample" -v b="$best_sample" 'BEGIN {print (a > b) ? 1 : 0}')" -eq 1 ]; then
            best_sample="$sample"
            best_provider="$provider"
        fi
    done <<< "$(jq -r 'to_entries[] | "\(.key)\t\(.value)"' "$scoreboard" 2>/dev/null)"

    if [ -n "$best_provider" ]; then
        echo "$best_provider"
    else
        discover_available_providers | head -1
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Epsilon-Greedy with Exponential Decay (Algorithm 15.3 + eq 15.2)
# ε ← α·ε  after each pull.  Starts with more exploration, decays over time.
# The textbook: "maintains a constant amount of exploration, despite there
# being far more uncertainty earlier... One common adjustment is to decay ε."
# ─────────────────────────────────────────────────────────────────────────────
select_provider_epsilon_greedy() {
    local epsilon="${1:-0.3}"
    local decay="${2:-0.95}"
    local scoreboard="${_PROVIDER_SCOREBOARD}"

    if [ ! -f "$scoreboard" ]; then
        _init_provider_scoreboard || return 1
    fi

    # Compute current ε based on total pulls so far
    local total_pulls
    total_pulls=$(jq '[.[] | (.successes + .failures + .timeouts + .stalls)] | add' "$scoreboard")
    if [ -z "$total_pulls" ] || [ "$total_pulls" = "0" ] || [ "$total_pulls" = "null" ]; then
        total_pulls=0
    fi

    # Apply decay: ε_current = ε · α^total_pulls
    local current_epsilon
    current_epsilon=$(awk -v e="$epsilon" -v d="$decay" -v n="$total_pulls" \
                      'BEGIN {print e * (d ^ n)}')

    # Decide: explore or exploit?
    local roll
    roll=$(awk 'BEGIN {srand(); print rand()}')

    if [ "$(awk -v r="$roll" -v e="$current_epsilon" 'BEGIN {print (r < e) ? 1 : 0}')" -eq 1 ]; then
        # Explore: pick uniformly at random from available providers
        local providers=()
        while IFS= read -r p; do
            [ -n "$p" ] && providers+=("$p")
        done <<< "$(jq -r 'keys[]' "$scoreboard" 2>/dev/null)"
        if [ ${#providers[@]} -gt 0 ]; then
            local idx
            idx=$(awk -v n="${#providers[@]}" 'BEGIN {srand(); print int(rand() * n)}')
            echo "${providers[$idx]}"
            return 0
        fi
    fi

    # Exploit: pick provider with highest mean reward (posterior mean)
    local best_provider=""
    local best_mean=-1

    while IFS= read -r line; do
        local provider="${line%%$'\t'*}"
        local stats="${line#*$'\t'}"
        local alpha=$(echo "$stats" | jq '.alpha // 1')
        local beta=$(echo "$stats" | jq '.beta // 1')
        local mean
        mean=$(awk "BEGIN {print $alpha / ($alpha + $beta)}")

        if [ "$best_mean" = "-1" ] || [ "$(awk -v a="$mean" -v b="$best_mean" 'BEGIN {print (a > b) ? 1 : 0}')" -eq 1 ]; then
            best_mean="$mean"
            best_provider="$provider"
        fi
    done <<< "$(jq -r 'to_entries[] | "\(.key)\t\(.value)"' "$scoreboard" 2>/dev/null)"

    if [ -n "$best_provider" ]; then
        echo "$best_provider"
    else
        discover_available_providers | head -1
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Explore-Then-Commit (Algorithm 15.4)
# Uniform random for first k pulls per provider, then commit to best.
# Ideal for cold-start when no data exists.
# ─────────────────────────────────────────────────────────────────────────────
select_provider_explore_then_commit() {
    local k="${1:-2}"
    local scoreboard="${_PROVIDER_SCOREBOARD}"

    if [ ! -f "$scoreboard" ]; then
        _init_provider_scoreboard || return 1
    fi

    # Check if any provider is still in exploration phase (< k pulls)
    local explore_candidates=()
    while IFS= read -r line; do
        local provider="${line%%$'\t'*}"
        local stats="${line#*$'\t'}"
        local pulls=$(echo "$stats" | jq '(.successes + .failures + .timeouts + .stalls) // 0')
        if [ "$pulls" -lt "$k" ]; then
            explore_candidates+=("$provider")
        fi
    done <<< "$(jq -r 'to_entries[] | "\(.key)\t\(.value)"' "$scoreboard" 2>/dev/null)"

    if [ ${#explore_candidates[@]} -gt 0 ]; then
        # Randomly pick from candidates still needing exploration
        local idx
        idx=$(awk -v n="${#explore_candidates[@]}" 'BEGIN {srand(); print int(rand() * n)}')
        echo "${explore_candidates[$idx]}"
        return 0
    fi

    # Commit: pick provider with highest posterior mean
    local best_provider=""
    local best_mean=-1

    while IFS= read -r line; do
        local provider="${line%%$'\t'*}"
        local stats="${line#*$'\t'}"
        local alpha=$(echo "$stats" | jq '.alpha // 1')
        local beta=$(echo "$stats" | jq '.beta // 1')
        local mean
        mean=$(awk "BEGIN {print $alpha / ($alpha + $beta)}")

        if [ "$best_mean" = "-1" ] || [ "$(awk -v a="$mean" -v b="$best_mean" 'BEGIN {print (a > b) ? 1 : 0}')" -eq 1 ]; then
            best_mean="$mean"
            best_provider="$provider"
        fi
    done <<< "$(jq -r 'to_entries[] | "\(.key)\t\(.value)"' "$scoreboard" 2>/dev/null)"

    if [ -n "$best_provider" ]; then
        echo "$best_provider"
    else
        discover_available_providers | head -1
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Auto-select provider strategy based on data richness.
# Cold-start (< k pulls total)    -> explore-then-commit
# Sparse data (< 10 pulls total)  -> thompson sampling (robust, no tuning)
# Rich data (≥ 10 pulls total)    -> ucb1 with small c (exploits knowledge)
# ─────────────────────────────────────────────────────────────────────────────
select_provider_auto() {
    local scoreboard="${_PROVIDER_SCOREBOARD}"

    if [ ! -f "$scoreboard" ]; then
        _init_provider_scoreboard || return 1
    fi

    local total_pulls
    total_pulls=$(jq '[.[] | (.successes + .failures + .timeouts + .stalls)] | add' "$scoreboard")
    if [ -z "$total_pulls" ] || [ "$total_pulls" = "0" ] || [ "$total_pulls" = "null" ]; then
        total_pulls=0
    fi

    if [ "$total_pulls" -lt 4 ]; then
        select_provider_explore_then_commit 2
    elif [ "$total_pulls" -lt 12 ]; then
        select_provider_thompson
    else
        select_provider_ucb1 0.5
    fi
}

# Get provider stats summary (for logging)
get_provider_stats() {
    local scoreboard="${_PROVIDER_SCOREBOARD}"
    if [ ! -f "$scoreboard" ]; then
        echo "No provider stats available"
        return 0
    fi
    jq -r 'to_entries | map("\(.key): succ=\(.value.successes) fail=\(.value.failures) to=\(.value.timeouts) stall=\(.value.stalls) | post=Beta(\(.value.alpha * 100 | floor | . / 100),\(.value.beta * 100 | floor | . / 100)) | avg_time=\(if .value.total_time > 0 then (.value.total_time / (.value.successes + .value.failures + .value.timeouts + .value.stalls) | floor) else 0 end)s") | .[]' "$scoreboard" 2>/dev/null || echo "Stats unavailable"
}

export -f find_swift_test_files
export -f find_swiftui_views
export -f detect_test_target_dir
export -f compute_prompt_hash
export -f check_prompt_already_done
export -f save_prompt_completion
export -f detect_ui_test_target_dir
export -f record_provider_result
export -f select_provider_ucb1
export -f select_provider_thompson
export -f select_provider_epsilon_greedy
export -f select_provider_explore_then_commit
export -f select_provider_auto
export -f get_provider_stats
