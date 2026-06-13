#!/usr/bin/env bash
# lib/build/run.sh — Build execution, lint, repair loops, and plans sequencing
[ -n "${_BUILD_RUN_SH:-}" ] && return 0
_BUILD_RUN_SH=1

run_multi_platform_build() {
    local platforms=("${DETECTED_PLATFORMS[@]}")
    local num_platforms=${#platforms[@]}

    if [ $num_platforms -le 1 ]; then
        return 1  # Signal caller to use normal build path
    fi

    log_info "Multi-platform build: ${platforms[*]}"

    local parallelism="${MULTI_PLATFORM_PARALLELISM:-0}"
    if [ "$parallelism" -eq 0 ]; then
        parallelism=$num_platforms
    fi
    log_info "Parallelism: $parallelism concurrent platform build(s)"

    local results_dir="${LOGS_DIR}/platform_results"
    mkdir -p "$results_dir"
    rm -f "${results_dir}"/*.json "${results_dir}"/*.log

    local platform_args=()
    for plat in "${platforms[@]}"; do
        platform_args+=("$plat")
    done

    # Build common arguments for BuildLint
    local common_args=""
    [ -n "${XCODE_WORKSPACE:-}" ] && common_args+=" --workspace \"$XCODE_WORKSPACE\""
    [ -n "${XCODE_PROJECT:-}" ] && [ -z "${XCODE_WORKSPACE:-}" ] && common_args+=" --project \"$XCODE_PROJECT\""
    [ -n "$SCHEME" ] && common_args+=" --scheme \"$SCHEME\""
    [ -n "$BUILD_CONFIGURATION" ] && common_args+=" --configuration \"$BUILD_CONFIGURATION\""
    [ -n "$DERIVED_DATA_PATH" ] && common_args+=" --derived-data \"$DERIVED_DATA_PATH\""
    [ "$SKIP_LINT" = "true" ] && common_args+=" --skip-lint"
    [ "$VERBOSE" = "true" ] && common_args+=" --verbose"
    common_args+=" --json-output"

    # Resolve platform.sh path before embedding in heredoc
    local platform_sh_path="${PHASE5_LIB_DIR:-${SCRIPT_DIR}/lib}/platform.sh"

    # Create temp script for xargs to execute
    local build_script="${results_dir}/run_platform_build.sh"
    cat > "$build_script" << SCRIPT_EOF
#!/bin/bash
platform="\$1"
plat_safe="\$(echo "\$platform" | tr ' ' '_')"
result_file="$results_dir/\${plat_safe}.json"
log_file="$results_dir/\${plat_safe}.log"
plat_logs_dir="$results_dir/\${plat_safe}"
mkdir -p "\$plat_logs_dir"

# Construct destination from platform name
PLATFORM_SH="$platform_sh_path"
[ -f "\$PLATFORM_SH" ] && source "\$PLATFORM_SH"

# Give construct_destination scheme-aware xcodebuild lookups.
export XCODE_PROJECT="${XCODE_PROJECT:-}"
export XCODE_WORKSPACE="${XCODE_WORKSPACE:-}"
export SCHEME="${SCHEME:-}"

dest=""
session_file="${PROJECT_ROOT:-}/.foundation-session.json"
if [ "\$platform" = "iOS Simulator" ] && [ -f "\$session_file" ] && command -v jq >/dev/null 2>&1; then
    saved_dest=\$(jq -r '.defaults.destination // empty' "\$session_file" 2>/dev/null || true)
    if [ -n "\$saved_dest" ]; then
        dest="\$saved_dest"
    fi
fi

if [ -z "\$dest" ] && type construct_destination &>/dev/null; then
    saved_sim=\$(jq -r '.defaults.simulator // empty' "\$session_file" 2>/dev/null || true)
    if [ "\$platform" = "iOS Simulator" ] && [ -n "\$saved_sim" ]; then
        dest=\$(construct_destination "\$platform" "\$saved_sim" "")
    else
        dest=\$(construct_destination "\$platform" "" "")
    fi
fi

if [ -z "\$dest" ]; then
    case "\$platform" in
        "iOS Simulator")
            dest="platform=iOS Simulator,name=iPhone 16"
            ;;
        "macOS")
            dest="platform=macOS"
            ;;
        "watchOS Simulator")
            dest="platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)"
            ;;
        "tvOS Simulator")
            dest="platform=tvOS Simulator,name=Apple TV"
            ;;
        "visionOS Simulator")
            dest="platform=visionOS Simulator,name=Apple Vision Pro"
            ;;
        *)
            dest="platform=\$platform"
            ;;
    esac
fi

"$BUILD_LINT_SCRIPT" $common_args --destination "\$dest" --logs-dir "\$plat_logs_dir" > "\$log_file" 2>&1
exit_code=\$?

if [ \$exit_code -eq 0 ]; then
    echo '{"platform":"'\$platform'","status":"success","exit_code":0}' > "\$result_file"
else
    echo '{"platform":"'\$platform'","status":"failed","exit_code":'\$exit_code'}' > "\$result_file"
fi

exit \$exit_code
SCRIPT_EOF
    chmod +x "$build_script"

    # Launch parallel builds via xargs
    local xargs_pid=""
    if [ "$MULTI_PLATFORM_FAIL_FAST" = "true" ]; then
        printf '%s\n' "${platform_args[@]}" | xargs -P "$parallelism" -I {} "$build_script" "{}" &
        xargs_pid=$!
    else
        printf '%s\n' "${platform_args[@]}" | xargs -P "$parallelism" -I {} sh -c '"$1" "$2" || true' _ "$build_script" "{}" &
        xargs_pid=$!
    fi

    # Live progress monitor with keyboard abort
    local spin_chars="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
    local spin_len=${#spin_chars}
    local spin_idx=0
    local user_aborted=false

    while kill -0 "$xargs_pid" 2>/dev/null; do
        local completed=0
        for plat in "${platforms[@]}"; do
            local result_file="${results_dir}/$(echo "$plat" | tr ' ' '_').json"
            [ -f "$result_file" ] && completed=$((completed + 1))
        done
        local running=$((num_platforms - completed))
        local spin_char="${spin_chars:spin_idx:1}"
        spin_idx=$(((spin_idx + 1) % spin_len))
        printf "\r\033[K\033[36m[%s]\033[0m Building %d platform(s): %d/%d complete (%d running)  (press 'q' to abort)" "$spin_char" "$num_platforms" "$completed" "$num_platforms" "$running" >&2

        # Check for keyboard abort
        local key=""
        if IFS= read -rs -t 1 -n 1 key < /dev/tty 2>/dev/null; then
            if [ "$key" = "q" ] || [ "$key" = "Q" ]; then
                user_aborted=true
                printf "\r\033[K\n" >&2
                log_warning "User aborted multi-platform build"
                break
            fi
        fi
    done

    if [ "$user_aborted" = "true" ]; then
        kill -TERM "$xargs_pid" 2>/dev/null || true
        sleep 0.5
        kill -KILL "$xargs_pid" 2>/dev/null || true
        wait "$xargs_pid" 2>/dev/null || true
        return 10
    fi

    # Wait for xargs to finish
    wait "$xargs_pid" 2>/dev/null || true
    printf "\r\033[K" >&2

    # Collect results
    local all_passed=true
    local failed_platforms=()
    local passed_platforms=()

    for plat in "${platforms[@]}"; do
        local result_file="${results_dir}/$(echo "$plat" | tr ' ' '_').json"
        if [ -f "$result_file" ]; then
            local status
            status=$(grep -o '"status":"[^"]*"' "$result_file" | cut -d'"' -f4)
            if [ "$status" = "success" ]; then
                passed_platforms+=("$plat")
            else
                failed_platforms+=("$plat")
                all_passed=false
            fi
        else
            failed_platforms+=("$plat")
            all_passed=false
        fi
    done
    # Summary
    echo "" >&2
    log_section "Multi-Platform Build Summary"
    log_section "───────────────────────────────"

    if [ ${#passed_platforms[@]} -gt 0 ]; then
        log_success "Passed: ${passed_platforms[*]}"
    fi
    if [ ${#failed_platforms[@]} -gt 0 ]; then
        log_error "Failed: ${failed_platforms[*]}"
    fi

    # Output JSON summary if requested
    if [ "$JSON_OUTPUT" = "true" ]; then
        local json_results="["
        local first=true
        for plat in "${platforms[@]}"; do
            local result_file="${results_dir}/$(echo "$plat" | tr ' ' '_').json"
            if [ -f "$result_file" ]; then
                [ "$first" = "false" ] && json_results+=","
                json_results+=$(cat "$result_file")
                first=false
            fi
        done
        json_results+="]"
        echo "$json_results"
    fi

    if [ "$all_passed" = "true" ]; then
        return 0
    else
        return 10
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Build Verification Functions
# ─────────────────────────────────────────────────────────────────────────────

# Background monitor for BuildLint progress.
# Watches the log file and prints stage transitions + heartbeats to stderr
# so the user knows what is happening during long builds.
monitor_buildlint_progress() {
    local log_file="$1"
    local start_time
    start_time=$(date +%s)
    local last_heartbeat_time=$start_time
    local last_stage=""
    local poll_interval=3

    while true; do
        sleep "$poll_interval"

        local elapsed
        elapsed=$(($(date +%s) - start_time))
        local current_stage=""

        if [ -f "$log_file" ]; then
            # Detect current stage from the last 30 lines of the log
            local tail_lines
            tail_lines=$(tail -n 30 "$log_file" 2>/dev/null || true)

            if echo "$tail_lines" | grep -q "BUILD SUCCEEDED"; then
                current_stage="Build succeeded"
            elif echo "$tail_lines" | grep -q "BUILD FAILED"; then
                current_stage="Build failed"
            elif echo "$tail_lines" | grep -q "Starting Xcode build"; then
                current_stage="Compiling with xcodebuild"
            elif echo "$tail_lines" | grep -q "Running SwiftLint"; then
                current_stage="Running SwiftLint"
            elif echo "$tail_lines" | grep -q "Cleaning Xcode build folder"; then
                current_stage="Cleaning build folder"
            elif echo "$tail_lines" | grep -q "Cleaning DerivedData"; then
                current_stage="Cleaning DerivedData"
            elif echo "$tail_lines" | grep -q "Cleaning Swift package"; then
                current_stage="Cleaning Swift package"
            elif echo "$tail_lines" | grep -q "Building Swift Package"; then
                current_stage="Building Swift package"
            fi
        fi

        # Print stage transition
        if [ -n "$current_stage" ] && [ "$current_stage" != "$last_stage" ]; then
            echo -e "${CYAN}[BUILD STAGE]${NC} ${current_stage} (${elapsed}s)" >&2
            last_stage="$current_stage"
            last_heartbeat_time=$(date +%s)
        fi

        # Heartbeat every 30 seconds if no stage change
        local since_heartbeat
        since_heartbeat=$(($(date +%s) - last_heartbeat_time))
        if [ "$since_heartbeat" -ge 30 ]; then
            if [ -n "$last_stage" ]; then
                echo -e "${CYAN}[BUILD STATUS]${NC} ${last_stage} — ${elapsed}s elapsed" >&2
            else
                echo -e "${CYAN}[BUILD STATUS]${NC} Build in progress — ${elapsed}s elapsed" >&2
            fi
            last_heartbeat_time=$(date +%s)
        fi
    done
}

# Run BuildLint.sh and capture results
run_build_lint() {
    local lint_log="${LOGS_DIR}/buildlint_attempt_${CURRENT_ATTEMPT}.log"
    local lint_exit_code=0
    local buildlint_start_time
    buildlint_start_time=$(date +%s)

    update_sidebar_stage "Building"
    write_build_stage "build" "running"

    log_attempt "Running BuildLint.sh..."

    if [ "$DRY_RUN" = "true" ]; then
        log_info "[DRY RUN] Would run: BuildLint.sh"
        echo "[DRY RUN] BuildLint.sh would be invoked here" > "$lint_log"
        return 0
    fi

    # Check for multi-platform build (when multiple platforms detected and no specific platform requested)
    if [ ${#DETECTED_PLATFORMS[@]} -gt 1 ] && [ -z "$PLATFORM" ] && [ -z "$DESTINATION" ] && [ -z "$TARGET_ID" ]; then
        log_info "Multiple platforms detected, running multi-platform build..."
        if run_multi_platform_build; then
            # Pick a canonical BUILT_PRODUCTS_DIR from multi-platform results.
            # Each platform's BuildLint writes built_products_dir.txt into its own
            # per-platform subdirectory (plat_logs_dir), e.g.:
            #   platform_results/iOS_Simulator/built_products_dir.txt
            # Priority: iOS Simulator > macOS > watchOS > tvOS > visionOS > any
            local mp_results_dir="${LOGS_DIR}/platform_results"
            BUILT_PRODUCTS_DIR_CAPTURED=""

            for plat in "iOS Simulator" "macOS" "watchOS Simulator" "tvOS Simulator" "visionOS Simulator"; do
                local plat_file="${mp_results_dir}/$(echo "$plat" | tr ' ' '_')/built_products_dir.txt"
                if [ -f "$plat_file" ]; then
                    BUILT_PRODUCTS_DIR_CAPTURED=$(cat "$plat_file")
                    log_verbose "BUILT_PRODUCTS_DIR_CAPTURED (multi-platform, canonical: $plat): $BUILT_PRODUCTS_DIR_CAPTURED"
                    break
                fi
            done

            if [ -z "$BUILT_PRODUCTS_DIR_CAPTURED" ]; then
                # Fallback: first available per-platform subdirectory
                for f in "${mp_results_dir}"/*/built_products_dir.txt; do
                    if [ -f "$f" ]; then
                        BUILT_PRODUCTS_DIR_CAPTURED=$(cat "$f")
                        log_verbose "BUILT_PRODUCTS_DIR_CAPTURED (multi-platform, fallback): $BUILT_PRODUCTS_DIR_CAPTURED"
                        break
                    fi
                done
            fi

            if [ -z "$BUILT_PRODUCTS_DIR_CAPTURED" ]; then
                log_error "Multi-platform build succeeded but no built_products_dir.txt found under ${mp_results_dir}/"
            fi
            return 0
        else
            return 10
        fi
    fi

    # Build BuildLint.sh arguments
    local lint_args=()
    lint_args+=("--logs-dir" "$LOGS_DIR")

    # Pass the Xcode project/workspace if we detected it
    if [ -n "${XCODE_WORKSPACE:-}" ]; then
        lint_args+=("--workspace" "$XCODE_WORKSPACE")
    elif [ -n "${XCODE_PROJECT:-}" ]; then
        lint_args+=("--project" "$XCODE_PROJECT")
    fi

    if [ -n "$TARGET_ID" ]; then
        lint_args+=("--target-id" "$TARGET_ID")
    fi

    if [ -n "$DESTINATION" ]; then
        lint_args+=("--destination" "$DESTINATION")
    fi

    if [ -n "$SCHEME" ]; then
        lint_args+=("--scheme" "$SCHEME")
    fi

    if [ -n "$BUILD_CONFIGURATION" ]; then
        lint_args+=("--configuration" "$BUILD_CONFIGURATION")
    fi

    if [ -n "$DERIVED_DATA_PATH" ]; then
        lint_args+=("--derived-data" "$DERIVED_DATA_PATH")
    fi

    if [ "$SKIP_LINT" = "true" ]; then
        lint_args+=("--skip-lint")
    fi

    if [ "$VERBOSE" = "true" ]; then
        lint_args+=("--verbose")
    fi

    # Debug: Show what we're passing to BuildLint
    if [ "$VERBOSE" = "true" ]; then
        log_verbose "BuildLint arguments: ${lint_args[*]}"
        log_verbose "XCODE_WORKSPACE=${XCODE_WORKSPACE:-<not set>}"
        log_verbose "XCODE_PROJECT=${XCODE_PROJECT:-<not set>}"
    fi

    # Run BuildLint.sh with spinner or streaming
    local build_spinner_msg="Building and verifying"

    if [ "$STREAM_OUTPUT" = "true" ]; then
        # Show status message but DON'T start spinner during streaming
        echo -e "${YELLOW}[STREAMING]${NC} $build_spinner_msg" >&2
        echo -e "${CYAN}─── BuildLint Output ───${NC}" >&2
        echo "" >&2

        # Start background progress monitor
        monitor_buildlint_progress "$lint_log" &
        local monitor_pid=$!

        # Stream output with unbuffering (quote each arg — destination strings contain commas)
        local buildlint_cmd
        buildlint_cmd=$(printf '%q ' "$BUILD_LINT_SCRIPT" "${lint_args[@]}")
        if run_unbuffered "$buildlint_cmd" 2>&1 | unbuffered_tee "$lint_log"; then
            lint_exit_code=0
        else
            lint_exit_code=$?
        fi

        # Kill progress monitor
        kill "$monitor_pid" 2>/dev/null
        wait "$monitor_pid" 2>/dev/null

        echo "" >&2
        echo -e "${CYAN}─── End BuildLint ───${NC}" >&2
        echo "" >&2
    else
        # Non-streaming: use spinner + background progress monitor
        start_spinner "$build_spinner_msg"
        monitor_buildlint_progress "$lint_log" &
        local monitor_pid=$!

        if "$BUILD_LINT_SCRIPT" "${lint_args[@]}" > "$lint_log" 2>&1; then
            lint_exit_code=0
        else
            lint_exit_code=$?
        fi

        # Kill progress monitor and spinner
        kill "$monitor_pid" 2>/dev/null
        wait "$monitor_pid" 2>/dev/null
        stop_spinner
    fi

    # Check for error.log (BuildLint writes directly to our LOGS_DIR now)
    if [ -f "${LOGS_DIR}/error.log" ]; then
        # Rename to include attempt number for tracking
        mv "${LOGS_DIR}/error.log" "${LOGS_DIR}/error_attempt_${CURRENT_ATTEMPT}.log"
        lint_exit_code=10
    fi

    local buildlint_elapsed=$(($(date +%s) - buildlint_start_time))
    if [ $lint_exit_code -eq 0 ]; then
        echo -e "${GREEN}[DONE]${NC} $build_spinner_msg ${GREEN}✓${NC} (${buildlint_elapsed}s)" >&2
        log_success "Build verification passed (${buildlint_elapsed}s)"
        # Read BUILT_PRODUCTS_DIR written by BuildLint.sh after successful build
        local built_products_dir_file="${LOGS_DIR}/built_products_dir.txt"
        if [ -f "$built_products_dir_file" ]; then
            BUILT_PRODUCTS_DIR_CAPTURED=$(cat "$built_products_dir_file")
            log_verbose "BUILT_PRODUCTS_DIR_CAPTURED: $BUILT_PRODUCTS_DIR_CAPTURED"
        fi
        return 0
    else
        echo -e "${RED}[FAILED]${NC} $build_spinner_msg ${RED}✗${NC} (${buildlint_elapsed}s)" >&2
        log_error "Build verification failed (exit code: $lint_exit_code) after ${buildlint_elapsed}s"
        return $lint_exit_code
    fi
}

# Get error content for feedback
get_error_feedback() {
    local error_file="${LOGS_DIR}/error_attempt_${CURRENT_ATTEMPT}.log"

    if [ -f "$error_file" ]; then
        cat "$error_file"
    else
        echo "Build failed but no detailed error log available."
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Status File Functions
# ─────────────────────────────────────────────────────────────────────────────

# Parse a markdown todo file into JSON array
# Supports:
#   - [ ] Unchecked item
#   - [x] Checked item
#   - [ ] Item with @file tag (track per-file)
#   - <!-- done --> marker

parse_todo_file() {
    local todo_file="$1"
    if [ -z "$todo_file" ] || [ ! -f "$todo_file" ]; then
        echo "[]"
        return 0
    fi

    local items=""
    local idx=0
    while IFS= read -r line; do
        # Match: - [ ] or - [x] at start of line
        if [[ "$line" =~ ^[[:space:]]*-[[:space:]]+\[([xX[:space:]])\][[:space:]]+(.+)$ ]]; then
            local check="${BASH_REMATCH[1]}"
            local text="${BASH_REMATCH[2]}"
            local status="pending"
            local file_tag=""

            if [[ "$check" == [xX] ]]; then
                status="done"
            fi

            # Extract @file tag
            if [[ "$text" =~ @([A-Za-z0-9_./-]+) ]]; then
                file_tag="${BASH_REMATCH[1]}"
            fi

            if [ -n "$items" ]; then
                items+=","
            fi
            items+="{\"id\":$idx,\"text\":\"$text\",\"status\":\"$status\",\"file\":\"$file_tag\"}"
            idx=$((idx + 1))
        fi
    done < "$todo_file"

    echo "[$items]"
}


run_repair_loop_with_errors() {
    local initial_errors="$1"
    local context
    local error_feedback="$initial_errors"
    local is_followup="false"

    context=$(gather_context)

    # Retrieve memory context from Letta if available
    retrieve_memory_context

    log_info "Context length: ${#context} chars"
    log_info "Initial errors length: ${#initial_errors} chars"
    [ -n "$LETTA_MEMORY_CONTEXT" ] && log_info "Memory context: available"

    update_sidebar_stage "Repairing"
    write_build_stage "repair" "running" 0 "$CURRENT_ATTEMPT"

    while [ $CURRENT_ATTEMPT -lt $MAX_REPAIR_ATTEMPTS ]; do
        CURRENT_ATTEMPT=$((CURRENT_ATTEMPT + 1))

        echo "" >&2
        log_section "────────────────────────────────────────"
        log_attempt "Starting repair cycle"
        log_section "────────────────────────────────────────"

        # Create AI prompt with build errors as input
        local prompt_content
        if [ "$is_followup" = "true" ]; then
            prompt_content="Previous fix attempt failed. Here are the remaining build errors:

$error_feedback

Please analyze and fix these errors."
        else
            prompt_content="The build failed with the following errors. Please fix them:

$error_feedback

Project context:
$context"
        fi

        # Acquire write lock before AI code generation
        if ! acquire_write_access; then
            log_error "Failed to acquire write lock"
            update_session_context "$CURRENT_ATTEMPT" "queue_timeout" "Write lock timeout"
            is_followup="true"
            continue
        fi

        # Generate code with AI
        AI_LAST_TIMEOUT="false"
        local attempt_start_time=$(date +%s)
        if ! run_ai_cli "$prompt_content"; then
            release_write_access
            local attempt_duration=$(($(date +%s) - attempt_start_time))

            # If the provider timed out, switch providers and retry
            if [ "$AI_LAST_TIMEOUT" = "true" ]; then
                log_warning "${AI_PROVIDER} timed out — switching providers and retrying"
                if command -v record_provider_result >/dev/null 2>&1; then
                    record_provider_result "$AI_PROVIDER" "$AI_LAST_TIMEOUT_TYPE" "$attempt_duration"
                fi
                if switch_ai_provider; then
                    TIMEOUT_RETRY_COUNT=$((TIMEOUT_RETRY_COUNT + 1))
                    if [ "$TIMEOUT_RETRY_COUNT" -gt "$MAX_TIMEOUT_RETRIES" ]; then
                        log_error "Max timeout retries ($MAX_TIMEOUT_RETRIES) reached — treating as failure"
                        update_session_context "$CURRENT_ATTEMPT" "provider_timeout" "All providers timed out after $MAX_TIMEOUT_RETRIES retries."
                        is_followup="true"
                        TIMEOUT_RETRY_COUNT=0
                        continue
                    fi
                    CURRENT_ATTEMPT=$((CURRENT_ATTEMPT - 1))
                    is_followup="false"
                    continue
                else
                    log_error "No alternative provider available after timeout"
                    update_session_context "$CURRENT_ATTEMPT" "provider_timeout" "${AI_PROVIDER} timed out and no alternative provider is available."
                    is_followup="true"
                    TIMEOUT_RETRY_COUNT=0
                    continue
                fi
            fi

            update_session_context "$CURRENT_ATTEMPT" "ai_error" "AI CLI failed"
            log_error "AI CLI call failed"
            is_followup="true"
            TIMEOUT_RETRY_COUNT=0
            continue
        fi

        release_write_access
        update_session_context "$CURRENT_ATTEMPT" "ai_success" "AI code generated"

        # Acquire build lock before verification
        if ! acquire_build_access; then
            log_error "Failed to acquire build lock"
            update_session_context "$CURRENT_ATTEMPT" "queue_timeout" "Build lock timeout"
            is_followup="true"
            continue
        fi

        # Verify build
        if run_build_lint; then
            release_build_access
            # Success!
            TIMEOUT_RETRY_COUNT=0
            update_session_context "$CURRENT_ATTEMPT" "success" "Build passed"
            write_success_status
            update_sidebar_stage "Complete"
            write_build_stage "complete" "completed"
            return 0
        fi

        release_build_access

        # Build still failing - get new errors
        error_feedback=$(get_error_feedback)
        update_session_context "$CURRENT_ATTEMPT" "build_failed" "$error_feedback"

        log_warning "Build still failing, will retry..."
        is_followup="true"
    done

    # Exhausted all attempts
    log_error "Maximum repair attempts ($MAX_REPAIR_ATTEMPTS) reached"
    write_human_intervention
    return 10
}

# ─────────────────────────────────────────────────────────────────────────────
# Argent UI-Error Repair Loop (--repair-from-errors <file>)
# ─────────────────────────────────────────────────────────────────────────────

run_repair_loop_with_argent_errors() {
    local errors_file="$REPAIR_FROM_ERRORS_FILE"
    local context
    local error_feedback=""
    local is_followup="false"

    # Validate jq is available
    if ! command -v jq &>/dev/null; then
        log_error "jq is required for --repair-from-errors but was not found"
        return 11
    fi

    # Ensure an AI provider was successfully detected; detect_ai_provider() is called
    # via validate_inputs() when REPAIR_FROM_ERRORS_FILE is set, but guard here explicitly
    # so the function never silently enters the loop with an empty AI_CMD.
    if [ -z "$AI_CMD" ]; then
        if ! detect_ai_provider; then
            log_error "--repair-from-errors requires a configured AI provider; none available (exit 11)"
            return 11
        fi
    fi

    # Validate and parse the errors JSON file
    if ! jq empty "$errors_file" 2>/dev/null; then
        log_error "Invalid JSON in errors file: $errors_file"
        return 11
    fi

    local error_count
    error_count=$(jq '.errors | length' "$errors_file" 2>/dev/null || echo "0")
    if [ "$error_count" -eq 0 ]; then
        log_warning "No errors found in $errors_file — nothing to repair"
        return 0
    fi

    local source_name
    source_name=$(jq -r '.source // "unknown"' "$errors_file")
    local timestamp
    timestamp=$(jq -r '.timestamp // "unknown"' "$errors_file")

    log_info "Argent error repair: $error_count error(s) from $source_name (recorded $timestamp)"

    context=$(gather_context)
    retrieve_memory_context

    log_info "Context length: ${#context} chars"
    [ -n "$LETTA_MEMORY_CONTEXT" ] && log_info "Memory context: available"

    while [ $CURRENT_ATTEMPT -lt $MAX_REPAIR_ATTEMPTS ]; do
        CURRENT_ATTEMPT=$((CURRENT_ATTEMPT + 1))

        echo "" >&2
        log_section "────────────────────────────────────────"
        log_attempt "Starting argent UI repair cycle"
        log_section "────────────────────────────────────────"

        # Build the UI-specific prompt from the parsed errors
        local errors_block
        errors_block=$(jq -r '
          .errors[] |
          "--- Error in flow: \(.flow // "unknown") | Step: \(.step // "?") | Action: \(.action // "?") ---\n" +
          "Target element: \(.element // "?")\n" +
          "Error: \(.error // "?")\n" +
          "Screenshot path: \(.screenshot // "none")\n" +
          "Element tree snapshot:\n\(.elementTree // "(not available)")\n"
        ' "$errors_file" 2>/dev/null || echo "(could not parse errors)")

        local prompt_content
        if [ "$is_followup" = "false" ]; then
            prompt_content="A UI test recorded the following failures. Each failure indicates an element could not be found or an action could not be performed. Fix the SwiftUI/UIKit source so that each element is present and reachable.

For each missing element, the most common fix is to add \`.accessibilityIdentifier(\"<element>\")\` to the relevant view. For elements that exist but are not interactable, check the UI state (e.g. hidden, disabled, or covered by another view).

$errors_block

Project context:
$context"
        else
            prompt_content="The previous fix attempt did not resolve all UI test failures. Here is the updated build feedback:

$error_feedback

The original UI test errors were:

$errors_block

Please re-examine the relevant views and ensure every listed element has the correct .accessibilityIdentifier and is visible/enabled in the expected state."
        fi

        # Acquire write lock before AI code generation
        if ! acquire_write_access; then
            log_error "Failed to acquire write lock"
            update_session_context "$CURRENT_ATTEMPT" "queue_timeout" "Write lock timeout"
            is_followup="true"
            continue
        fi

        # Generate code with AI
        AI_LAST_TIMEOUT="false"
        local attempt_start_time=$(date +%s)
        if ! run_ai_cli "$prompt_content"; then
            release_write_access
            local attempt_duration=$(($(date +%s) - attempt_start_time))

            # If the provider timed out, switch providers and retry
            if [ "$AI_LAST_TIMEOUT" = "true" ]; then
                log_warning "${AI_PROVIDER} timed out — switching providers and retrying"
                if command -v record_provider_result >/dev/null 2>&1; then
                    record_provider_result "$AI_PROVIDER" "$AI_LAST_TIMEOUT_TYPE" "$attempt_duration"
                fi
                if switch_ai_provider; then
                    TIMEOUT_RETRY_COUNT=$((TIMEOUT_RETRY_COUNT + 1))
                    if [ "$TIMEOUT_RETRY_COUNT" -gt "$MAX_TIMEOUT_RETRIES" ]; then
                        log_error "Max timeout retries ($MAX_TIMEOUT_RETRIES) reached — treating as failure"
                        update_session_context "$CURRENT_ATTEMPT" "provider_timeout" "All providers timed out after $MAX_TIMEOUT_RETRIES retries."
                        is_followup="true"
                        TIMEOUT_RETRY_COUNT=0
                        continue
                    fi
                    CURRENT_ATTEMPT=$((CURRENT_ATTEMPT - 1))
                    is_followup="false"
                    continue
                else
                    log_error "No alternative provider available after timeout"
                    update_session_context "$CURRENT_ATTEMPT" "provider_timeout" "${AI_PROVIDER} timed out and no alternative provider is available."
                    is_followup="true"
                    TIMEOUT_RETRY_COUNT=0
                    continue
                fi
            fi

            update_session_context "$CURRENT_ATTEMPT" "ai_error" "AI CLI failed"
            log_error "AI CLI call failed"
            is_followup="true"
            TIMEOUT_RETRY_COUNT=0
            continue
        fi

        release_write_access
        update_session_context "$CURRENT_ATTEMPT" "ai_success" "AI code generated"

        # Acquire build lock before verification
        if ! acquire_build_access; then
            log_error "Failed to acquire build lock"
            update_session_context "$CURRENT_ATTEMPT" "queue_timeout" "Build lock timeout"
            is_followup="true"
            continue
        fi

        # Verify build
        if run_build_lint; then
            release_build_access
            TIMEOUT_RETRY_COUNT=0
            update_session_context "$CURRENT_ATTEMPT" "success" "Build passed"
            # Record context outcome for VOI learning
            record_context_outcome "$had_context" "$CURRENT_ATTEMPT"
            write_success_status
            return 0
        fi

        release_build_access

        # Build still failing — get new errors for next iteration
        error_feedback=$(get_error_feedback)
        update_session_context "$CURRENT_ATTEMPT" "build_failed" "$error_feedback"

        log_warning "Build still failing, will retry..."
        is_followup="true"
    done

    # Exhausted all attempts
    log_error "Maximum repair attempts ($MAX_REPAIR_ATTEMPTS) reached"
    write_human_intervention
    return 10
}

# ─────────────────────────────────────────────────────────────────────────────
# Auto-Detect Mode (no plan provided - lint/build first, AI repair if needed)
# ─────────────────────────────────────────────────────────────────────────────

run_lint_only() {
    update_sidebar_stage "Linting"
    write_build_stage "build" "running"
    log_section "Running initial lint/build check (no plan provided)"
    echo "" >&2

    CURRENT_ATTEMPT=0
    TIMEOUT_RETRY_COUNT=0

    # Initialize session context file
    {
        echo "# Build Session: $SESSION_ID"
        echo "Started: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
        echo "Mode: Auto-detect (lint/build first, AI repair if needed)"
        echo "Max attempts: $MAX_REPAIR_ATTEMPTS"
        echo "AI Provider: $AI_PROVIDER"
        echo ""
    } > "$SESSION_FILE"

    # Acquire build lock for initial verification
    if ! acquire_build_access; then
        log_warning "Could not acquire build lock, waiting..."
    fi

    # Run initial build verification
    if run_build_lint; then
        release_build_access
        TIMEOUT_RETRY_COUNT=0
        # Success! No errors to fix
        update_session_context "0" "success" "Build passed - no errors to fix"
        write_success_status
        update_sidebar_stage "Complete"
        log_success "Build passed! No errors detected."
        return 0
    fi

    release_build_access

    # Build failed - use errors as input for AI repair loop
    local error_feedback
    error_feedback=$(get_error_feedback)
    update_session_context "0" "build_failed" "$error_feedback"

    log_warning "Build errors detected - starting AI repair loop"
    log_info "Using build errors as AI input"
    echo "" >&2

    # Detect AI provider before repair loop (was skipped during validation in lint-only mode)
    if ! detect_ai_provider; then
        log_error "Cannot start repair loop: AI provider '$AI_PROVIDER' not available"
        write_human_intervention
        return 11
    fi

    # Transition to repair loop with errors as input
    # Set the error_feedback as initial context for the loop
    run_repair_loop_with_errors "$error_feedback"
    return $?
}

# ─────────────────────────────────────────────────────────────────────────────
# Main Execution Loop
# ─────────────────────────────────────────────────────────────────────────────

# ─────────────────────────────────────────────────────────────────────────────
# Plan Discovery & Sequence Execution
# ─────────────────────────────────────────────────────────────────────────────

# Discover plan files in a directory.
# If sequence.md exists, parse it for the execution order.
# Otherwise, auto-discover all *.md files (sorted).

discover_plans_in_dir() {
    local dir="$1"

    # Check for sequence.md
    if [ -f "${dir}/sequence.md" ]; then
        log_info "Found sequence.md, using defined execution order"
        while IFS= read -r line || [ -n "$line" ]; do
            # Skip empty lines and markdown headers/comments
            [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue

            # Remove markdown list markers and trim whitespace
            local plan_path
            plan_path=$(echo "$line" | sed -E 's/^[[:space:]]*([-*]|[0-9]+\.[[:space:]])*[[:space:]]*//' | sed 's/[[:space:]]*$//')

            # Only keep lines that look like file paths ending in .md
            if [[ "$plan_path" == *.md ]]; then
                if [ -f "${dir}/${plan_path}" ]; then
                    echo "${dir}/${plan_path}"
                elif [ -f "$plan_path" ]; then
                    echo "$plan_path"
                else
                    log_warning "Plan file not found: $plan_path"
                fi
            fi
        done < "${dir}/sequence.md"
        return 0
    fi

    # Auto-discover all .md files up to 2 levels deep
    log_info "No sequence.md found, auto-discovering plans"
    find "$dir" -maxdepth 2 -name "*.md" -type f -print0 2>/dev/null | sort -z | while IFS= read -r -d '' file; do
        echo "$file"
    done
}

# Run a sequence of plans from PLAN_FILES array
run_plans_sequence() {
    local total_plans=${#PLAN_FILES[@]}
    local overall_exit=0
    local completed_plans=0

    log_section "=========================================="
    log_info "Plan Sequence: $total_plans plan(s) discovered"
    log_section "=========================================="
    for i in "${!PLAN_FILES[@]}"; do
        log_info "  [$((i + 1))] $(basename "${PLAN_FILES[$i]}")"
    done
    echo "" >&2

    for i in "${!PLAN_FILES[@]}"; do
        CURRENT_PLAN_INDEX=$i
        local plan_file="${PLAN_FILES[$i]}"
        local plan_num=$((i + 1))

        log_section "=========================================="
        log_info "Executing plan $plan_num/$total_plans: $(basename "$plan_file")"
        log_section "=========================================="
        echo "" >&2

        update_sidebar_stage "Plan $plan_num/$total_plans"

        # Set current plan state
        PLAN_FILE="$plan_file"
        PROMPT_CONTENT=""
        CURRENT_ATTEMPT=0
        TIMEOUT_RETRY_COUNT=0
        CURSOR_CHAT_ID=""

        # Cache plan content
        if [ -f "$PLAN_FILE" ]; then
            PROMPT_CONTENT=$(cat "$PLAN_FILE" 2>/dev/null || true)
            log_verbose "Cached plan content (${#PROMPT_CONTENT} chars)"
        fi

        # Run single plan build loop
        local plan_exit=0
        run_single_build_loop || plan_exit=$?

        if [ $plan_exit -ne 0 ]; then
            overall_exit=$plan_exit
            log_error "Plan $plan_num failed with exit code $plan_exit"
            break
        fi

        completed_plans=$((completed_plans + 1))
        log_success "Plan $plan_num completed successfully"
        echo "" >&2
    done

    log_section "=========================================="
    if [ $overall_exit -eq 0 ]; then
        log_success "All $total_plans plan(s) completed successfully"
    else
        log_error "Plan sequence stopped after $completed_plans/$total_plans plans"
    fi
    log_section "=========================================="

    return $overall_exit
}

# ─────────────────────────────────────────────────────────────────────────────
# Single Plan Build Loop (extracted for plan sequence reuse)
# ─────────────────────────────────────────────────────────────────────────────

run_single_build_loop() {
    local input_content
    local context=""
    local error_feedback=""
    local is_followup="false"
    local had_context="false"

    update_sidebar_stage "Planning"
    write_build_stage "context" "running"

    input_content=$(get_input_content)

    # Try cached context first (fast). Only gather fresh if needed after first failure.
    context=$(gather_context)
    if [ -n "$context" ]; then
        had_context="true"
    fi

    # Retrieve memory context from Letta if available
    retrieve_memory_context

    log_info "Input length: ${#input_content} chars"
    if [ -n "$context" ]; then
        log_info "Context length: ${#context} chars"
        if [ "${#context}" -gt "$MAX_CONTEXT_CHARS" ]; then
            log_warning "Context truncated from ${#context} to ${MAX_CONTEXT_CHARS} chars (set MAX_CONTEXT_CHARS env var to override)"
            context="${context:0:$MAX_CONTEXT_CHARS}"
            context+="
... [CONTEXT TRUNCATED — set MAX_CONTEXT_CHARS env var to increase limit] ..."
        fi
    else
        log_info "No cached context — will gather fresh if build fails on first attempt"
    fi
    [ -n "$LETTA_MEMORY_CONTEXT" ] && log_info "Memory context: available"
    log_info "Session ID: $SESSION_ID"

    # Initialize session context file
    {
        echo "# Build Session: $SESSION_ID"
        echo "Started: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
        echo "Max attempts: $MAX_REPAIR_ATTEMPTS"
        echo "AI Provider: $AI_PROVIDER"
        echo "AI CLI Command: $AI_CMD"
        if [ -n "$CURSOR_CHAT_ID" ]; then
            echo "Cursor Chat ID: $CURSOR_CHAT_ID"
        fi
        if [ ${#PLAN_FILES[@]} -gt 0 ]; then
            echo "Plan: $((CURRENT_PLAN_INDEX + 1))/${#PLAN_FILES[@]} — $(basename "${PLAN_FILES[$CURRENT_PLAN_INDEX]}")"
        fi
        echo ""
    } > "$SESSION_FILE"

    # Parse todo file if provided
    local todos_json="[]"
    if [ -n "$TODO_FILE" ]; then
        todos_json=$(parse_todo_file "$TODO_FILE")
        log_info "Loaded $(echo "$todos_json" | grep -o '"id"' | wc -l | tr -d ' ') todo(s) from $TODO_FILE"
    fi

    # Check saved state for this prompt (unless --force)
    local prompt_hash=""
    if [ "$FORCE_RUN" != "true" ] && [ -n "$input_content" ]; then
        prompt_hash=$(compute_prompt_hash "$input_content")
        if check_prompt_already_done "$input_content"; then
            log_info "This prompt was already completed in a previous session."
            log_info "Use --force to re-run anyway."
            update_session_context "0" "skipped" "Prompt already completed (hash: $prompt_hash)"
            write_success_status
            return 0
        fi
    fi

    # Build-first mode: run build before any AI generation
    if [ "$BUILD_FIRST_MODE" = "true" ]; then
        log_section "Build-first check"

        if acquire_build_access; then
            if run_build_lint; then
                release_build_access
                log_success "Build already passes"

                # If build passes and we have no prompt, we're done
                if [ -z "$input_content" ]; then
                    TIMEOUT_RETRY_COUNT=0
                    update_session_context "0" "success" "Build passed — no prompt to implement"
                    write_success_status
                    return 0
                fi

                # If build passes and prompt was previously completed, we're done
                if [ -n "$prompt_hash" ] && check_prompt_already_done "$input_content"; then
                    log_success "Prompt already implemented and build passes — nothing to do"
                    TIMEOUT_RETRY_COUNT=0
                    update_session_context "0" "success" "Build passed, prompt already completed"
                    write_success_status
                    return 0
                fi

                log_info "Build passes but prompt may need implementation — continuing to AI"
            else
                release_build_access
                log_warning "Build has errors — will use as initial feedback for AI repair"
                error_feedback=$(get_error_feedback)
                is_followup="true"
            fi
        else
            log_warning "Could not acquire build lock for build-first check — continuing anyway"
        fi
    fi

    while [ $CURRENT_ATTEMPT -lt $MAX_REPAIR_ATTEMPTS ]; do
        CURRENT_ATTEMPT=$((CURRENT_ATTEMPT + 1))

        echo "" >&2
        log_section "────────────────────────────────────────"
        log_attempt "Starting build cycle"
        log_section "────────────────────────────────────────"
        echo "" >&2

        # Lazy context gathering: if no cache and first attempt failed, gather now
        if [ -z "$context" ] && [ "$is_followup" = "true" ]; then
            log_info "Gathering context for repair..."
            context=$(gather_context)
            if [ -n "$context" ]; then
                log_info "Context length: ${#context} chars"
                if [ "${#context}" -gt "$MAX_CONTEXT_CHARS" ]; then
                    log_warning "Context truncated from ${#context} to ${MAX_CONTEXT_CHARS} chars (set MAX_CONTEXT_CHARS env var to override)"
                    context="${context:0:$MAX_CONTEXT_CHARS}"
                    context+="
... [CONTEXT TRUNCATED — set MAX_CONTEXT_CHARS env var to increase limit] ..."
                fi
            fi
        fi

        # Build prompt based on whether this is first attempt or follow-up
        local prompt
        local current_strategy=""
        local error_pattern=""
        if [ "$is_followup" = "false" ]; then
            # First attempt: use cached context if available, otherwise minimal prompt
            prompt=$(build_initial_prompt "$input_content" "$context")
        else
            # Follow-up: classify error pattern and select best repair strategy
            error_pattern=$(classify_error_pattern "$error_feedback")
            current_strategy=$(select_repair_strategy "$error_pattern")
            log_info "Error pattern: $error_pattern | Strategy: $current_strategy"
            prompt=$(build_followup_prompt_with_strategy "$error_feedback" "$CURRENT_ATTEMPT" "$input_content" "$context" "$current_strategy")
        fi

        # Acquire write lock before code generation (prevents concurrent modifications)
        if ! acquire_write_access; then
            log_error "Failed to acquire write lock - another agent may be stuck"
            error_feedback="Build coordination timeout. Another agent may be stuck."
            update_session_context "$CURRENT_ATTEMPT" "queue_timeout" "$error_feedback"
            is_followup="true"
            continue
        fi

        # Run AI CLI with session
        AI_LAST_TIMEOUT="false"
        local attempt_start_time=$(date +%s)
        if ! run_ai_cli "$prompt" "$is_followup"; then
            release_write_access  # Release lock on failure
            local attempt_duration=$(($(date +%s) - attempt_start_time))

            # If the provider timed out (zero bytes), switch providers and retry
            if [ "$AI_LAST_TIMEOUT" = "true" ]; then
                log_warning "${AI_PROVIDER} timed out — switching providers and retrying"
                if command -v record_provider_result >/dev/null 2>&1; then
                    record_provider_result "$AI_PROVIDER" "$AI_LAST_TIMEOUT_TYPE" "$attempt_duration"
                fi
                if switch_ai_provider; then
                    TIMEOUT_RETRY_COUNT=$((TIMEOUT_RETRY_COUNT + 1))
                    if [ "$TIMEOUT_RETRY_COUNT" -gt "$MAX_TIMEOUT_RETRIES" ]; then
                        log_error "Max timeout retries ($MAX_TIMEOUT_RETRIES) reached — treating as failure"
                        error_feedback="All providers timed out after $MAX_TIMEOUT_RETRIES retries."
                        update_session_context "$CURRENT_ATTEMPT" "provider_timeout" "$error_feedback"
                        is_followup="true"
                        TIMEOUT_RETRY_COUNT=0
                        continue
                    fi
                    # Retry same attempt number with new provider
                    CURRENT_ATTEMPT=$((CURRENT_ATTEMPT - 1))
                    is_followup="false"
                    continue
                else
                    log_error "No alternative provider available after timeout"
                    error_feedback="${AI_PROVIDER} timed out and no alternative provider is available."
                    update_session_context "$CURRENT_ATTEMPT" "provider_timeout" "$error_feedback"
                    is_followup="true"
                    TIMEOUT_RETRY_COUNT=0
                    continue
                fi
            fi

            log_error "${AI_PROVIDER} CLI failed"
            error_feedback="${AI_PROVIDER} CLI invocation failed. Please try again."
            update_session_context "$CURRENT_ATTEMPT" "cursor_failed" "$error_feedback"
            if command -v record_provider_result >/dev/null 2>&1; then
                record_provider_result "$AI_PROVIDER" "failure" "$attempt_duration"
            fi
            is_followup="true"
            TIMEOUT_RETRY_COUNT=0
            continue
        fi
        local ai_duration=$(($(date +%s) - attempt_start_time))

        # Release write lock, acquire build lock (allows other agents to queue up)
        release_write_access

        if ! acquire_build_access; then
            log_error "Failed to acquire build lock - another agent may be stuck"
            error_feedback="Build coordination timeout during build phase."
            update_session_context "$CURRENT_ATTEMPT" "queue_timeout" "$error_feedback"
            is_followup="true"
            continue
        fi

        # Run build verification
        local build_result=0
        local build_start_time=$(date +%s)
        if run_build_lint; then
            release_build_access  # Release lock after build
            TIMEOUT_RETRY_COUNT=0
            local build_duration=$(($(date +%s) - build_start_time))
            # Success! Record provider result with total duration (AI + build)
            if command -v record_provider_result >/dev/null 2>&1; then
                record_provider_result "$AI_PROVIDER" "success" "$((ai_duration + build_duration))"
            fi
            update_session_context "$CURRENT_ATTEMPT" "success" "Build passed"
            # Record repair strategy success
            if [ -n "$current_strategy" ] && [ -n "$error_pattern" ]; then
                record_repair_result "$error_pattern" "$current_strategy" "success"
                log_info "Repair strategy '$current_strategy' succeeded for pattern '$error_pattern'"
            fi
            # Persist completion state
            if [ -n "$input_content" ]; then
                local prompt_hash
                prompt_hash=$(compute_prompt_hash "$input_content")
                local todos_json="[]"
                if [ -n "$TODO_FILE" ] && [ -f "$TODO_FILE" ]; then
                    todos_json=$(parse_todo_file "$TODO_FILE")
                fi
                save_build_state "$prompt_hash" "completed" "$todos_json"
                log_info "Prompt completion saved to state (hash: $prompt_hash)"
            fi
            write_success_status
            return 0
        fi

        release_build_access  # Release lock after build (even on failure)
        local build_duration=$(($(date +%s) - build_start_time))

        # Record provider result (build failed but AI responded)
        if command -v record_provider_result >/dev/null 2>&1; then
            record_provider_result "$AI_PROVIDER" "failure" "$((ai_duration + build_duration))"
        fi

        # Record repair strategy failure
        if [ -n "$current_strategy" ] && [ -n "$error_pattern" ]; then
            record_repair_result "$error_pattern" "$current_strategy" "failure"
            log_info "Repair strategy '$current_strategy' failed for pattern '$error_pattern'"
        fi

        # Get error feedback for next attempt
        error_feedback=$(get_error_feedback)
        update_session_context "$CURRENT_ATTEMPT" "build_failed" "$error_feedback"

        # Mark as follow-up for next iteration
        is_followup="true"

        if [ $CURRENT_ATTEMPT -lt $MAX_REPAIR_ATTEMPTS ]; then
            log_warning "Build failed, continuing session with error feedback..."
        fi
    done

    # Max attempts reached — record context outcome before exiting
    record_context_outcome "${had_context:-false}" "$CURRENT_ATTEMPT"
    log_error "Build failed after $MAX_REPAIR_ATTEMPTS attempts"
    write_human_intervention
    return 20
}

run_build_loop() {
    # Handle plans directory mode
    if [ ${#PLAN_FILES[@]} -gt 0 ]; then
        run_plans_sequence
        return $?
    fi

    # Handle argent UI-error repair mode
    if [ -n "$REPAIR_FROM_ERRORS_FILE" ]; then
        run_repair_loop_with_argent_errors
        return $?
    fi

    # Handle lint-only mode
    if [ "$LINT_ONLY_MODE" = "true" ]; then
        run_lint_only
        return $?
    fi

    run_single_build_loop
    return $?
}

# ─────────────────────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────────────────────
