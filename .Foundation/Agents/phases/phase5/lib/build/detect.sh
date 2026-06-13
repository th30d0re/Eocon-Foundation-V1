#!/usr/bin/env bash
# lib/build/detect.sh — Project/scheme/platform detection, Swift docs, git, and input validation
[ -n "${_BUILD_DETECT_SH:-}" ] && return 0
_BUILD_DETECT_SH=1

setup_directories() {
    start_spinner "Setting up artifacts directory"

    local run_id
    run_id="$(date +%Y%m%d_%H%M%S)"
    local run_dir="${ARTIFACTS_DIR}/build_${run_id}"

    LOGS_DIR="${run_dir}/logs"
    STATUS_DIR="${run_dir}/status"
    ARTIFACTS_RUN_DIR="${run_dir}"

    if ! mkdir -p "$LOGS_DIR"; then
        spinner_error "Setting up artifacts directory"
        log_error "Failed to create logs directory: $LOGS_DIR"
        exit 11
    fi

    if ! mkdir -p "$STATUS_DIR"; then
        spinner_error "Setting up artifacts directory"
        log_error "Failed to create status directory: $STATUS_DIR"
        exit 11
    fi

    # Create session ID for maintaining context across attempts
    SESSION_ID="build_session_${run_id}"
    SESSION_FILE="${LOGS_DIR}/session_context.md"

    spinner_success "Setting up artifacts directory"

    log_verbose "Run directory: $run_dir"
    log_verbose "Logs directory: $LOGS_DIR"
    log_verbose "Status directory: $STATUS_DIR"
    log_verbose "Artifacts run directory: $ARTIFACTS_RUN_DIR"
    log_verbose "Session ID: $SESSION_ID"
    log_verbose "AI CLI Command: $AI_CMD"

    # Initialize pipeline stage tracker for orchestrator visualizer.
    echo '{"stages": {}}' > "${STATUS_DIR}/build_stages.json"
}

# Validate that a user-supplied identifier contains only safe characters.
# Prevents shell injection / predicate injection for scheme names, build
# configurations, and bundle IDs that are interpolated into commands.
validate_identifier() {
    local value="$1"
    local label="${2:-identifier}"
    if [ -z "$value" ]; then
        return 0
    fi
    if [[ ! "$value" =~ ^[a-zA-Z0-9._\ \-]+$ ]]; then
        log_error "$label contains invalid characters: '$value'"
        return 1
    fi
    return 0
}

validate_inputs() {
    # IMMEDIATELY cache prompt/plan content before any slow operations
    # Traycer deletes temp files after 30 seconds, so read them NOW
    if [ -n "$PROMPT_FILE" ] && [ -f "$PROMPT_FILE" ] && [ -z "$PROMPT_CONTENT" ]; then
        PROMPT_CONTENT=$(cat "$PROMPT_FILE" 2>/dev/null || true)
        log_verbose "Cached prompt content (${#PROMPT_CONTENT} chars)"
    elif [ -n "$PLAN_FILE" ] && [ -f "$PLAN_FILE" ] && [ -z "$PROMPT_CONTENT" ]; then
        PROMPT_CONTENT=$(cat "$PLAN_FILE" 2>/dev/null || true)
        log_verbose "Cached plan content (${#PROMPT_CONTENT} chars)"
    elif [ -n "$PROMPT_STRING" ] && [ -z "$PROMPT_CONTENT" ]; then
        PROMPT_CONTENT="$PROMPT_STRING"
    fi

    start_spinner "Validating configuration"

    # Check if any input is provided - if not, run in lint-only mode
    # REPAIR_FROM_ERRORS_FILE and PLANS_DIR are AI-driven even though they carry no prompt text
    if [ -z "$PLAN_FILE" ] && [ -z "$PROMPT_FILE" ] && [ -z "$PROMPT_STRING" ] && [ -z "$PROMPT_CONTENT" ] && [ -z "$REPAIR_FROM_ERRORS_FILE" ] && [ -z "$PLANS_DIR" ]; then
        LINT_ONLY_MODE="true"
        log_info "No AI input provided - running in auto-detect mode (build first, AI repair if needed)"
    fi

    # Explicitly force AI-driven mode for --repair-from-errors
    if [ -n "$REPAIR_FROM_ERRORS_FILE" ]; then
        LINT_ONLY_MODE="false"
        log_verbose "Repair-from-errors mode: AI provider required"
    fi

    # Validate plans directory if provided
    if [ -n "$PLANS_DIR" ] && [ ! -d "$PLANS_DIR" ]; then
        spinner_error "Validating configuration"
        log_error "Plans directory not found: $PLANS_DIR"
        return 1
    fi

    # Validate plan file if provided (skip if already cached)
    if [ -n "$PLAN_FILE" ] && [ -z "$PROMPT_CONTENT" ] && [ ! -f "$PLAN_FILE" ]; then
        spinner_error "Validating configuration"
        log_error "Plan file not found: $PLAN_FILE"
        return 1
    fi

    # Validate prompt file if provided (skip if already cached)
    if [ -n "$PROMPT_FILE" ] && [ -z "$PROMPT_CONTENT" ] && [ ! -f "$PROMPT_FILE" ]; then
        spinner_error "Validating configuration"
        log_error "Prompt file not found: $PROMPT_FILE"
        return 1
    fi

    # Validate context paths
    if [ ${#CONTEXT_PATHS[@]} -gt 0 ]; then
        for ctx_path in "${CONTEXT_PATHS[@]}"; do
            if [ ! -e "$ctx_path" ]; then
                log_warning "Context path not found: $ctx_path"
            fi
        done
    fi

    # Auto-detect Swift docs if not disabled
    if [ -z "$SWIFT_DOCS_PATH" ] || [ "$SWIFT_DOCS_PATH" != "DISABLED" ]; then
        detect_swift_docs || true  # Non-fatal if not found
    fi

    # Auto-detect Xcode project/workspace (always run, even if scheme is provided)
    detect_xcode_project_path || true  # Non-fatal if not found

    # Auto-scope DerivedData per workspace/project when not explicitly set.
    # Mirrors XcodeBuildMCP's workspace-scoped DerivedData behaviour (v2.5.0) so
    # parallel multi-project builds don't clobber each other's output folders.
    if [ -z "$DERIVED_DATA_PATH" ]; then
        local _scope_input="${XCODE_WORKSPACE:-${XCODE_PROJECT:-}}"
        if [ -n "$_scope_input" ]; then
            local _scope_hash
            _scope_hash=$(printf '%s' "$_scope_input" | md5 2>/dev/null || printf '%s' "$_scope_input" | md5sum 2>/dev/null | cut -c1-8)
            _scope_hash="${_scope_hash:0:8}"
            DERIVED_DATA_PATH="${WORK_DIR}/.derived-data-${_scope_hash}"
            log_verbose "Auto-scoped DerivedData: $DERIVED_DATA_PATH"
        fi
    fi

    # Check/initialize git repository
    ensure_git_repo || true  # Non-fatal if initialization fails

    # Auto-detect scheme if not provided
    if [ -z "$SCHEME" ]; then
        if ! detect_scheme; then
            log_warning "Could not auto-detect scheme. Build may require --scheme parameter."
        fi
    fi

    # Validate user-supplied identifiers to block shell/predicate injection
    if ! validate_identifier "${SCHEME:-}" "Scheme"; then
        spinner_error "Validating configuration"
        return 1
    fi
    if ! validate_identifier "${BUILD_CONFIGURATION:-}" "Build configuration"; then
        spinner_error "Validating configuration"
        return 1
    fi

    # Check BuildLint.sh exists
    if [ ! -x "$BUILD_LINT_SCRIPT" ]; then
        spinner_error "Validating configuration"
        log_error "BuildLint.sh not found or not executable: $BUILD_LINT_SCRIPT"
        return 1
    fi

    # Detect and configure AI provider (skip in lint-only mode)
    if [ "$LINT_ONLY_MODE" = "false" ]; then
        if ! detect_ai_provider; then
            spinner_error "Validating configuration"
            log_error "AI provider detection failed; no provider available for the requested operation"
            return 11
        fi
    fi

    # Detect unbuffering method for streaming mode
    UNBUFFER_METHOD=$(detect_unbuffer_method)

    # Log streaming configuration if enabled
    if [ "$STREAM_OUTPUT" = "true" ]; then
        log_verbose "Streaming mode enabled"
        log_verbose "Unbuffering method: $UNBUFFER_METHOD"

        if [ "$UNBUFFER_METHOD" = "none" ]; then
            log_warning "No unbuffering tool available (stdbuf/unbuffer/script)"
            log_warning "Output may appear delayed or buffered"
        fi

        # Log provider streaming capability (only warn when streaming was explicitly requested)
        case "$AI_PROVIDER" in
            cursor)
                if [ "$AI_CMD" = "cursor-agent" ] && [ "$STREAM_OUTPUT" = "true" ]; then
                    if [ "$CURSOR_STREAM_SUPPORTED" = "true" ]; then
                        log_verbose "Using cursor-agent --stream-partial-output with stream-json"
                    else
                        log_warning "cursor-agent streaming not supported; falling back to standard output"
                    fi
                fi
                ;;
            letta)
                log_verbose "Using letta --output-format stream-json"
                ;;
            codex)
                log_verbose "Using codex with line-buffered output"
                ;;
            copilot|github-copilot)
                log_verbose "Using GitHub Copilot with line-buffered output"
                ;;
            *)
                log_verbose "Provider streaming via shell unbuffering (no native support)"
                ;;
        esac
    fi

    spinner_success "Validating configuration"
    return 0
}

# ─────────────────────────────────────────────────────────────────────────────
# Auto-detection Functions
# ─────────────────────────────────────────────────────────────────────────────

# Ensure swiftDocs is cloned and up-to-date in Foundation directory
# Clones from https://github.com/th30d0re/swiftDocs.git if missing
# Checks for updates and pulls if available

ensure_swift_docs_repo() {
    local foundation_swift_docs="/Users/emmanuel/Dev/Tools/Eocon-Foundation-V1/.Foundation/Docs/swiftDocs"
    local swift_docs_repo="https://github.com/th30d0re/swiftDocs.git"
    
    # Check if git is available
    if ! command -v git >/dev/null 2>&1; then
        log_verbose "Git not available, skipping swiftDocs repo management"
        return 0
    fi
    
    # Create parent directory if needed
    local parent_dir="$(dirname "$foundation_swift_docs")"
    if [ ! -d "$parent_dir" ]; then
        log_verbose "Creating docs directory: $parent_dir"
        mkdir -p "$parent_dir" 2>/dev/null || true
    fi
    
    # Check if directory exists and is a git repo
    if [ -d "$foundation_swift_docs" ]; then
        if [ -d "$foundation_swift_docs/.git" ]; then
            # Check the remote URL
            local current_remote
            current_remote=$(cd "$foundation_swift_docs" 2>/dev/null && git remote get-url origin 2>/dev/null || echo "")
            
            if [ -n "$current_remote" ]; then
                # Check if it's the expected repo (handle both https and git URLs)
                if echo "$current_remote" | grep -q "th30d0re/swiftDocs"; then
                    log_verbose "Checking for swiftDocs updates..."
                    (
                        cd "$foundation_swift_docs" 2>/dev/null || exit 0
                        
                        # Fetch updates quietly
                        if git fetch origin --quiet 2>/dev/null; then
                            # Check if we're behind
                            local local_commit=$(git rev-parse HEAD 2>/dev/null)
                            local remote_commit=$(git rev-parse origin/main 2>/dev/null || git rev-parse origin/master 2>/dev/null)
                            
                            if [ -n "$local_commit" ] && [ -n "$remote_commit" ] && [ "$local_commit" != "$remote_commit" ]; then
                                log_info "Updating swiftDocs from repository..."
                                if git pull --quiet 2>/dev/null; then
                                    log_success "swiftDocs updated successfully"
                                else
                                    log_verbose "Could not update swiftDocs (continuing with current version)"
                                fi
                            else
                                log_verbose "swiftDocs is up to date"
                            fi
                        fi
                    )
                else
                    # Different repo - just use it as-is
                    log_verbose "swiftDocs exists from different repo: $current_remote (using as-is)"
                fi
            else
                log_verbose "swiftDocs directory is a git repo without origin (using as-is)"
            fi
        else
            # Directory exists but is not a git repo - check if it's empty
            if [ -z "$(ls -A "$foundation_swift_docs" 2>/dev/null)" ]; then
                log_info "Cloning swiftDocs repository..."
                if git clone --quiet "$swift_docs_repo" "$foundation_swift_docs" 2>/dev/null; then
                    log_success "swiftDocs cloned successfully"
                else
                    log_warning "Failed to clone swiftDocs repository"
                fi
            else
                log_verbose "swiftDocs directory exists but is not a git repo (using as-is)"
            fi
        fi
    else
        # Directory doesn't exist - clone it
        log_info "Cloning swiftDocs repository..."
        if git clone --quiet "$swift_docs_repo" "$foundation_swift_docs" 2>/dev/null; then
            log_success "swiftDocs cloned to: $foundation_swift_docs"
        else
            log_warning "Failed to clone swiftDocs repository"
        fi
    fi
    
    return 0
}

# Auto-detect Swift documentation path
# Searches up to 5 levels deep for swiftDocs directories, excludes dependency folders,
# and prioritizes the main project's docs (shortest path)
detect_swift_docs() {
    # First, ensure Foundation swiftDocs repo is available and updated
    ensure_swift_docs_repo
    
    if [ -n "$SWIFT_DOCS_PATH" ] && [ -d "$SWIFT_DOCS_PATH" ]; then
        log_verbose "Using provided Swift docs path: $SWIFT_DOCS_PATH"
        return 0
    fi

    log_verbose "Searching for Swift documentation..."

    local docs_path=""
    local search_dirs=("$WORK_DIR")

    # Also search PROJECT_ROOT if different from WORK_DIR
    if [ "$WORK_DIR" != "$PROJECT_ROOT" ]; then
        search_dirs+=("$PROJECT_ROOT")
    fi

    # Search each directory for swiftDocs
    for search_dir in "${search_dirs[@]}"; do
        if [ -n "$docs_path" ]; then
            break
        fi

        # Find directories named "swiftDocs" or "SwiftDocs", excluding dependency folders
        # Sort by path length (shortest first = main project)
        local found_paths
        found_paths=$(find "$search_dir" -maxdepth 5 -type d \( -name "swiftDocs" -o -name "SwiftDocs" \) \
            -not -path "*/.build/*" \
            -not -path "*/Pods/*" \
            -not -path "*/Carthage/*" \
            -not -path "*/checkouts/*" \
            -not -path "*/DerivedData/*" \
            -not -path "*/Build/*" \
            -not -path "*/Ref/*" \
            -not -path "*/Reference/*" \
            -not -path "*/.planning/*" \
            2>/dev/null | \
            awk '{ print length, $0 }' | \
            sort -n | \
            cut -d' ' -f2-) || true

        # Check each found path for .md files, use first valid one
        while IFS= read -r path; do
            if [ -n "$path" ] && [ -d "$path" ]; then
                # Check if at least one .md file exists (use -print -quit to avoid pipefail issues)
                local first_md
                first_md=$(find "$path" -maxdepth 2 -name "*.md" -type f -print -quit 2>/dev/null) || true
                if [ -n "$first_md" ]; then
                    docs_path="$path"
                    break
                fi
            fi
        done <<< "$found_paths"
    done

    # Also check .Foundation directories explicitly (hidden dirs might be missed by main search)
    if [ -z "$docs_path" ]; then
        local foundation_paths=(
            "/Users/emmanuel/Dev/Tools/Eocon-Foundation-V1/.Foundation/Docs/swiftDocs"
            "${WORK_DIR}/.Foundation/Docs/swiftDocs"
            "${WORK_DIR}/.Foundation/.Foundation/Docs/swiftDocs"
            "${WORK_DIR}/.foundation/docs/swiftDocs"
            "${PROJECT_ROOT}/.Foundation/Docs/swiftDocs"
            "${PROJECT_ROOT}/.Foundation/.Foundation/Docs/swiftDocs"
            "${PROJECT_ROOT}/.foundation/docs/swiftDocs"
        )
        for fpath in "${foundation_paths[@]}"; do
            if [ -d "$fpath" ]; then
                local first_md
                first_md=$(find "$fpath" -maxdepth 2 -name "*.md" -type f -print -quit 2>/dev/null) || true
                if [ -n "$first_md" ]; then
                    docs_path="$fpath"
                    break
                fi
            fi
        done
    fi

    if [ -n "$docs_path" ]; then
        SWIFT_DOCS_PATH="$docs_path"
        log_info "Auto-detected Swift docs: $SWIFT_DOCS_PATH"
        return 0
    fi

    log_verbose "No Swift documentation found, continuing without docs context"
    SWIFT_DOCS_PATH=""
    return 1
}

# Auto-detect Xcode project/workspace path (separate from scheme detection)
# Searches up to 5 levels deep, excludes dependency directories, and prioritizes
# the "main" project (shortest path, not in build/dependency folders)
detect_xcode_project_path() {
    log_verbose "Searching for Xcode project/workspace..."

    # Common directories to exclude (dependencies, caches, etc.)
    local exclude_patterns=(
        "*/.*"                    # Hidden directories
        "*/.build/*"              # Swift Package Manager build
        "*/Pods/*"                # CocoaPods
        "*/Carthage/*"            # Carthage
        "*/checkouts/*"           # SPM checkouts
        "*/DerivedData/*"         # Xcode derived data
        "*/Build/*"               # Build folders
        "*/Docs/*"                # Documentation
        "*/docs/*"                # Documentation (lowercase)
        "*/Reference/*"           # Reference projects
        "*/Ref/*"                 # Reference projects (short)
        "*/Examples/*"            # Example projects
        "*/Samples/*"             # Sample projects
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

        # Find all matching paths, sort by path length (shortest first)
        eval "find \"$search_dir\" -maxdepth $max_depth -name \"*.$extension\" $find_excludes 2>/dev/null" | \
            awk '{ print length, $0 }' | \
            sort -n | \
            cut -d' ' -f2- | \
            head -1
    }

    # Look for workspace first (preferred) - search in WORK_DIR first, then PROJECT_ROOT
    local workspace
    workspace=$(find_best_xcode_path "$WORK_DIR" "xcworkspace" 5)

    # Exclude project.xcworkspace (inside .xcodeproj) - we want standalone workspaces
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
        # Fall back to project - search in WORK_DIR first, then PROJECT_ROOT
        project=$(find_best_xcode_path "$WORK_DIR" "xcodeproj" 5)

        if [ -z "$project" ] && [ "$WORK_DIR" != "$PROJECT_ROOT" ]; then
            project=$(find_best_xcode_path "$PROJECT_ROOT" "xcodeproj" 5)
        fi
    fi

    if [ -n "$workspace" ]; then
        log_info "Found Xcode workspace: $workspace"
        XCODE_WORKSPACE="$workspace"
        return 0
    elif [ -n "$project" ]; then
        log_info "Found Xcode project: $project"
        XCODE_PROJECT="$project"
        return 0
    else
        log_verbose "No Xcode workspace or project found in $WORK_DIR"
        if [ "$WORK_DIR" != "$PROJECT_ROOT" ]; then
            log_verbose "Also checked: $PROJECT_ROOT"
        fi
        return 1
    fi
}

# Ensure git repository exists (initialize if needed)
ensure_git_repo() {
    # Check if we're in a git repository
    if git rev-parse --git-dir >/dev/null 2>&1; then
        log_verbose "Git repository found"
        return 0
    fi

    log_warning "No git repository found in $WORK_DIR"
    log_info "Git repository is recommended for SwiftLint to work properly"

    # Check if git is available
    if ! command -v git >/dev/null 2>&1; then
        log_warning "Git is not installed - skipping initialization"
        return 1
    fi

    # Ask user if they want to initialize (or auto-initialize in YOLO mode)
    if [ "$YOLO_MODE" = "true" ] || [ "$DRY_RUN" = "true" ]; then
        log_info "Auto-initializing git repository..."

        if [ "$DRY_RUN" = "true" ]; then
            log_info "[DRY RUN] Would run: git init && git add . && git commit -m 'Initial commit'"
            return 0
        fi

        # Initialize git repo
        if git init >/dev/null 2>&1; then
            log_success "✓ Initialized empty git repository"

            # Add all files and make initial commit
            if git add . >/dev/null 2>&1 && git commit -m "Initial commit by BuildAgent" >/dev/null 2>&1; then
                log_success "✓ Created initial commit"
                log_info "Git repository ready for SwiftLint"
                return 0
            else
                log_warning "Git initialized but initial commit failed"
                return 1
            fi
        else
            log_error "Failed to initialize git repository"
            return 1
        fi
    else
        log_info "Run 'git init' to initialize a repository for better linting"
        return 1
    fi
}

# Auto-detect Xcode scheme by looking for .xcodeproj or .xcworkspace
detect_scheme() {
    if [ -n "$SCHEME" ]; then
        log_verbose "Using provided scheme: $SCHEME"
        return 0
    fi

    log_verbose "Attempting to auto-detect Xcode scheme..."

    # Use already-detected project/workspace if available
    local workspace="$XCODE_WORKSPACE"
    local project="$XCODE_PROJECT"

    # If not already detected, run detect_xcode_project_path first
    if [ -z "$workspace" ] && [ -z "$project" ]; then
        detect_xcode_project_path || true
        workspace="$XCODE_WORKSPACE"
        project="$XCODE_PROJECT"
    fi

    # Build xcodebuild argument array (no eval — avoids CWE-78 shell injection)
    local xcode_cmd_args=("xcodebuild")
    if [ -n "$workspace" ]; then
        xcode_cmd_args+=("-workspace" "$workspace")
        log_verbose "Using workspace: $workspace"
    elif [ -n "$project" ]; then
        xcode_cmd_args+=("-project" "$project")
        log_verbose "Using project: $project"
    else
        log_verbose "No Xcode workspace or project found"
        return 1
    fi

    # Get list of schemes
    local schemes_output
    schemes_output=$("${xcode_cmd_args[@]}" -list 2>/dev/null || true)

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
# Multi-Platform Detection
# ─────────────────────────────────────────────────────────────────────────────

# Detected platforms (array)
DETECTED_PLATFORMS=()

# Detect all platforms supported by the project
# Parses project.pbxproj for SUPPORTED_PLATFORMS and SDKROOT
detect_project_platforms() {
    if [ "$AUTO_MULTI_PLATFORM" != "true" ]; then
        log_verbose "Multi-platform detection disabled"
        return 0
    fi

    log_verbose "Detecting supported platforms..."

    local project_file=""

    # Find the project.pbxproj file
    if [ -n "$XCODE_WORKSPACE" ]; then
        # For workspaces, look for the main project inside
        local proj_in_workspace
        proj_in_workspace=$(find "$(dirname "$XCODE_WORKSPACE")" -maxdepth 2 -name "*.xcodeproj" -not -path "*/.build/*" 2>/dev/null | head -1)
        if [ -n "$proj_in_workspace" ]; then
            project_file="${proj_in_workspace}/project.pbxproj"
        fi
    elif [ -n "$XCODE_PROJECT" ]; then
        project_file="${XCODE_PROJECT}/project.pbxproj"
    fi

    if [ ! -f "$project_file" ]; then
        log_verbose "Could not find project.pbxproj for platform detection"
        DETECTED_PLATFORMS=("iOS Simulator")  # Default fallback
        return 0
    fi

    # Parse SUPPORTED_PLATFORMS from pbxproj
    local supported_platforms
    supported_platforms=$(grep -E "SUPPORTED_PLATFORMS\s*=" "$project_file" 2>/dev/null | head -1 | sed 's/.*=\s*"\?\([^";]*\)"\?.*/\1/' || echo "")

    if [ -n "$supported_platforms" ]; then
        log_verbose "Found SUPPORTED_PLATFORMS: $supported_platforms"

        # Parse the platform list
        local platforms_list
        platforms_list=$(echo "$supported_platforms" | tr ',' '\n' | tr ' ' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | grep -v '^$')

        while IFS= read -r plat; do
            case "$plat" in
                iphoneos)
                    # iOS Device (we'll use simulator for builds typically)
                    DETECTED_PLATFORMS+=("iOS Simulator")
                    ;;
                iphonesimulator)
                    DETECTED_PLATFORMS+=("iOS Simulator")
                    ;;
                macosx)
                    DETECTED_PLATFORMS+=("macOS")
                    ;;
                watchos)
                    DETECTED_PLATFORMS+=("watchOS Simulator")
                    ;;
                watchsimulator)
                    DETECTED_PLATFORMS+=("watchOS Simulator")
                    ;;
                appletvos)
                    DETECTED_PLATFORMS+=("tvOS Simulator")
                    ;;
                appletvsimulator)
                    DETECTED_PLATFORMS+=("tvOS Simulator")
                    ;;
                xros)
                    DETECTED_PLATFORMS+=("visionOS Simulator")
                    ;;
                xrsimulator)
                    DETECTED_PLATFORMS+=("visionOS Simulator")
                    ;;
            esac
        done <<< "$platforms_list"
    else
        # Try parsing SDKROOT as fallback
        local sdkroot
        sdkroot=$(grep -E "SDKROOT\s*=" "$project_file" 2>/dev/null | head -1 | sed 's/.*=\s*"\?\([^";]*\)"\?.*/\1/' || echo "")

        if [ -n "$sdkroot" ]; then
            case "$sdkroot" in
                iphoneos*)
                    DETECTED_PLATFORMS+=("iOS Simulator")
                    ;;
                macosx*)
                    DETECTED_PLATFORMS+=("macOS")
                    ;;
                watchos*)
                    DETECTED_PLATFORMS+=("watchOS Simulator")
                    ;;
                appletvos*)
                    DETECTED_PLATFORMS+=("tvOS Simulator")
                    ;;
                xros*)
                    DETECTED_PLATFORMS+=("visionOS Simulator")
                    ;;
            esac
        fi
    fi

    # Remove duplicates
    if [ ${#DETECTED_PLATFORMS[@]} -gt 0 ]; then
        local unique_platforms=()
        local -A seen=()
        for p in "${DETECTED_PLATFORMS[@]}"; do
            if [ -z "${seen[$p]:-}" ]; then
                unique_platforms+=("$p")
                seen[$p]=1
            fi
        done
        DETECTED_PLATFORMS=("${unique_platforms[@]}")
    else
        # Default to iOS Simulator if nothing detected
        DETECTED_PLATFORMS=("iOS Simulator")
    fi

    # Filter to only iOS and macOS platforms (default behavior)
    local filtered_platforms=()
    for p in "${DETECTED_PLATFORMS[@]}"; do
        case "$p" in
            "iOS Simulator"|"macOS")
                filtered_platforms+=("$p")
                ;;
            *)
                log_verbose "Skipping platform: $p (only iOS and macOS enabled by default)"
                ;;
        esac
    done
    
    # Update DETECTED_PLATFORMS with filtered list
    if [ ${#filtered_platforms[@]} -gt 0 ]; then
        DETECTED_PLATFORMS=("${filtered_platforms[@]}")
    else
        # Fallback to iOS Simulator if filtering removed all platforms
        DETECTED_PLATFORMS=("iOS Simulator")
    fi

    log_info "Detected platforms: ${DETECTED_PLATFORMS[*]}"
    return 0
}

# ─────────────────────────────────────────────────────────────────────────────
# UI Initialization
# ─────────────────────────────────────────────────────────────────────────────

