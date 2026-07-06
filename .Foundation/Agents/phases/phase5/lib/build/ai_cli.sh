#!/usr/bin/env bash
# lib/build/ai_cli.sh — AI CLI invocation (run_ai_cli) and cursor stream detection
[ -n "${_BUILD_AI_CLI_SH:-}" ] && return 0
_BUILD_AI_CLI_SH=1

detect_cursor_stream_support() {
    CURSOR_STREAM_SUPPORTED="true"
}

# Detect whether the AI agent is actively running a build.
# Used by the streaming watchdog so a long-running build (e.g. xcodebuild)
# is not mistaken for a stalled AI provider.
_foundation_ai_is_building() {
    local pid="${1:-}"
    local output_file="${2:-}"

    # Method 1: Recent output contains build indicators
    if [ -n "$output_file" ] && [ -f "$output_file" ]; then
        local recent_output
        recent_output=$(tail -c 4096 "$output_file" 2>/dev/null || true)
        if echo "$recent_output" | grep -qiE \
            "running xcodebuild|building target|build target|compileswift|compiling swift|compiling objective-c|linking|building for|build started|executing build|running build|swift build|swift package|cargo build|cmake --build|make -j|gradle build|npm run build|npm install|yarn install|pnpm install|bun install|pip install|bundle install|pod install|carthage build|ld:|clang:|gcc:|g\\+\\+:"; then
            return 0
        fi
    fi

    # Method 2: Known build tools are running anywhere on the system.
    # We do a system-wide check because run_unbuffered uses `script` which
    # creates a new PTY/session — the AI and its build children may NOT be
    # in the same process group as the parent subshell we track.
    local build_tools="xcodebuild|swift build|swiftc|npm|pnpm|yarn|bun|cargo|make|cmake|gradle|mvn|ld|clang|gcc|g\\+\\+|rustc|go build|tsc|esbuild|webpack|vite"
    if pgrep -qiE "$build_tools" 2>/dev/null; then
        return 0
    fi

    return 1
}

# Detect and configure AI CLI provider

run_ai_cli() {
    local prompt="$1"
    local is_followup="${2:-false}"
    local output_file="${LOGS_DIR}/coder_attempt_${CURRENT_ATTEMPT}.log"

    update_sidebar_stage "Generating Code"
    write_build_stage "generate" "running"

    log_attempt "Running ${AI_PROVIDER} AI CLI (session: $SESSION_ID)..."

    if [ "$DRY_RUN" = "true" ]; then
        log_info "[DRY RUN] Would run: $AI_CMD ..."
        if [ "$is_followup" = "true" ] && [ -n "$CURSOR_CHAT_ID" ]; then
            log_info "[DRY RUN] Would resume chat: $CURSOR_CHAT_ID"
        fi
        echo "[DRY RUN] AI CLI would be invoked here" > "$output_file"
        return 0
    fi

    local ai_exit_code=0
    local ai_cmd_full=""
    local provider_lower
    provider_lower=$(echo "$AI_PROVIDER" | tr '[:upper:]' '[:lower:]')

    # Write prompt to temp file to avoid shell escaping issues with special characters
    # This is critical because prompts may contain Swift code with $(), //, etc.
    # Using printf '%s' to avoid echo interpreting escape sequences
    local prompt_file="${LOGS_DIR}/prompt_attempt_${CURRENT_ATTEMPT}.txt"
    printf '%s' "$prompt" > "$prompt_file"

    # Create empty MCP config for Kimi to avoid MCP_DOCKER connection errors
    local kimi_mcp_config=""

    # Build command based on provider (all use temp file/stdin for safety)
    case "$provider_lower" in
        cursor)
            # cursor-agent reads from stdin when piped
            local cursor_output_format="text"
            local cursor_stream_flag=""
            if [ "$STREAM_OUTPUT" = "true" ] && [ "$AI_CMD" = "cursor-agent" ] && [ "$CURSOR_STREAM_SUPPORTED" = "true" ]; then
                # cursor-agent uses --stream-partial-output (requires --output-format stream-json)
                cursor_output_format="stream-json"
                cursor_stream_flag="--stream-partial-output"
            fi

            if [ "$is_followup" = "true" ] && [ -n "$CURSOR_CHAT_ID" ] && [ "$AI_CMD" = "cursor-agent" ]; then
                # Resume existing session
                log_verbose "Resuming Cursor chat session: $CURSOR_CHAT_ID"
                if [ "$cursor_output_format" = "stream-json" ] && command -v jq &>/dev/null; then
                    ai_cmd_full="$AI_CMD --resume \"$CURSOR_CHAT_ID\" --force --print --output-format stream-json $cursor_stream_flag < \"$prompt_file\" 2>&1 | grep '^\\s*{' | jq -r 'select(.role==\"assistant\") | .content[]? | select(.type==\"text\") | .text'"
                else
                    ai_cmd_full="$AI_CMD --resume \"$CURSOR_CHAT_ID\" --force --print --output-format text $cursor_stream_flag < \"$prompt_file\""
                fi
            else
                # New session (first attempt)
                if [ "$cursor_output_format" = "stream-json" ] && command -v jq &>/dev/null; then
                    ai_cmd_full="$AI_CMD --force --print --output-format stream-json $cursor_stream_flag < \"$prompt_file\" 2>&1 | grep '^\\s*{' | jq -r 'select(.role==\"assistant\") | .content[]? | select(.type==\"text\") | .text'"
                else
                    ai_cmd_full="$AI_CMD --force --print --output-format text $cursor_stream_flag < \"$prompt_file\""
                fi
                log_verbose "Starting new Cursor chat session"
            fi
            ;;

        claude|anthropic)
            # Claude CLI - pipe from file to avoid escaping issues
            ai_cmd_full="cat \"$prompt_file\" | $AI_CMD --dangerously-skip-permissions -p -"
            log_verbose "Running Claude CLI (with --dangerously-skip-permissions)"
            ;;

        codex|openai)
            # OpenAI/Codex format using 'exec' subcommand for non-interactive mode
            # The 'exec' subcommand reads from stdin when prompt is '-'
            ai_cmd_full="cat \"$prompt_file\" | $AI_CMD exec --full-auto -"
            log_verbose "Running OpenAI/Codex CLI (exec mode with --full-auto)"
            ;;

        gemini|google)
            # Gemini format with yolo flag - pipe from file
            if [ "$AI_CMD" = "gemini" ]; then
                ai_cmd_full="cat \"$prompt_file\" | $AI_CMD generate --yolo"
            else
                ai_cmd_full="cat \"$prompt_file\" | $AI_CMD generate-text --yolo"
            fi
            log_verbose "Running Gemini CLI (with --yolo)"
            ;;

        aider)
            # Aider format - uses --message-file directly (already safe)
            ai_cmd_full="$AI_CMD --yes --message-file \"$prompt_file\""
            log_verbose "Running Aider CLI"
            ;;

        letta)
            # Letta Code - headless mode with -p flag
            # Uses stateful agents with persistent memory per directory
            local letta_flags=""

            # Initialize directory-specific agent (first run creates and pins agent)
            init_letta_directory_agent "$WORK_DIR" || true

            # Auto-approval in YOLO mode
            if [ "${YOLO_MODE:-false}" = "true" ]; then
                letta_flags="--yolo"
            fi

            # Streaming output format for long operations
            if [ "${STREAM_OUTPUT:-false}" = "true" ]; then
                letta_flags="$letta_flags --output-format stream-json"
            fi

            # Model selection if specified (via LETTA_MODEL env var)
            if [ -n "${LETTA_MODEL:-}" ]; then
                letta_flags="$letta_flags --model \"$LETTA_MODEL\""
            fi

            # Self-hosted instance support
            if [ -n "${LETTA_BASE_URL:-}" ]; then
                export LETTA_BASE_URL
            fi

            # Build command - run from WORK_DIR so Letta uses the directory-pinned agent
            # Pipe prompt file to letta with -p flag for headless execution
            ai_cmd_full="cat \"$prompt_file\" | $AI_CMD $letta_flags -p"
            log_verbose "Running Letta Code CLI with directory-specific agent"
            ;;

        copilot|github-copilot)
            # GitHub Copilot CLI - pipe from stdin to avoid argument length limits
            # Requires --allow-all-tools and --allow-all-paths for non-interactive mode
            local copilot_flags="--allow-all-tools --allow-all-paths --silent"
            if [ -n "${AI_MODEL:-}" ]; then
                copilot_flags="$copilot_flags --model \"$AI_MODEL\""
            fi
            # Pipe prompt from file to avoid shell escaping issues and argument limits
            ai_cmd_full="cat \"$prompt_file\" | $AI_CMD $copilot_flags"
            log_verbose "Running GitHub Copilot CLI (piped from stdin)"
            ;;

        kimi|kimi-code|moonshot)
            # Kimi Code CLI - use stream-json to avoid Rich markup parsing issues
            # with bracket characters in prompts (e.g., [/doc/path#id]).
            # Create a temporary empty MCP config to suppress MCP_DOCKER errors.
            kimi_mcp_config=$(mktemp /tmp/kimi_mcp_empty.XXXXXX)
            echo '{"mcpServers":{}}' > "$kimi_mcp_config"

            local kimi_flags="--yolo --print --output-format stream-json --mcp-config-file \"$kimi_mcp_config\""
            if [ -n "${AI_MODEL:-}" ]; then
                kimi_flags="$kimi_flags --model \"$AI_MODEL\""
            fi
            # Filter JSON stream to extract text responses; fall back to raw JSON if jq unavailable
            # Use stdin redirection (<) instead of pipe (cat |) because
            # `script` pseudo-terminal breaks piped stdin for kimi CLI.
            if command -v jq &>/dev/null; then
                ai_cmd_full="$AI_CMD $kimi_flags < \"$prompt_file\" 2>&1 | grep '^\\s*{' | jq -r 'select(.role==\"assistant\") | .content[]? | select(.type==\"text\") | .text'"
            else
                ai_cmd_full="$AI_CMD $kimi_flags < \"$prompt_file\""
            fi
            log_verbose "Running Kimi Code CLI (stream-json mode)"
            ;;

        *)
            log_error "Unknown AI provider: $AI_PROVIDER"
            return 1
            ;;
    esac

    # Log session info (for tracking purposes)
    if [ "$is_followup" = "true" ]; then
        log_verbose "Follow-up attempt in session: $SESSION_ID"
        if [ -n "$CURSOR_CHAT_ID" ]; then
            log_verbose "Using chat ID: $CURSOR_CHAT_ID"
        fi
    else
        log_verbose "New session: $SESSION_ID"
    fi

    # Run with streaming or spinner
    local spinner_msg="Generating code with ${AI_PROVIDER}"
    [ "$is_followup" = "true" ] && spinner_msg="Fixing code with ${AI_PROVIDER} (attempt $CURRENT_ATTEMPT)"

    if [ "$STREAM_OUTPUT" = "true" ]; then
        # Show status message but DON'T start spinner during streaming (prevents conflicts)
        echo -e "${YELLOW}[STREAMING]${NC} $spinner_msg" >&2
        echo -e "${CYAN}─── ${AI_PROVIDER} CLI Output ───${NC}" >&2
        echo "" >&2

        # Initialize stream timeline log
        STREAM_TIMELINE_FILE="${LOGS_DIR}/stream_timeline_attempt_${CURRENT_ATTEMPT}.log"
        write_stream_timeline "START" "provider=$AI_PROVIDER attempt=$CURRENT_ATTEMPT"

        local stream_start_time
        stream_start_time=$(date +%s)
        local heartbeat_pid=""
        local tail_pid=""

        # Run the AI command in a single background subshell writing directly to file.
        # Use run_unbuffered for line-buffered output so tail -f sees it immediately.
        (
            cd "$WORK_DIR" && run_unbuffered "eval $ai_cmd_full" > "$output_file" 2>&1
        ) &
        stream_cmd_pid=$!

        # Stream file contents in real-time via tail -f
        tail -n +1 -f "$output_file" 2>/dev/null &
        tail_pid=$!

        # Start background heartbeat + stalled watchdog if enabled
        if [ "$STREAM_HEARTBEAT_ENABLED" = "true" ]; then
            (
                local last_bytes=0
                local last_changed_time=$stream_start_time
                while kill -0 "$stream_cmd_pid" 2>/dev/null; do
                    sleep "$STREAM_HEARTBEAT_INTERVAL"
                    local elapsed=$(($(date +%s) - stream_start_time))
                    local bytes=0
                    [ -f "$output_file" ] && bytes=$(wc -c < "$output_file" 2>/dev/null || echo 0)

                    # Track when bytes last CHANGED (not just when they were non-zero)
                    if [ "$bytes" -gt "$last_bytes" ]; then
                        last_changed_time=$(date +%s)
                        last_bytes=$bytes
                    fi
                    local stalled=$(( $(date +%s) - last_changed_time ))

                    # Stalled watchdog: if no NEW output for too long, kill the provider
                    # This catches both "0 bytes forever" and "stopped producing after some bytes"
                    if [ "$stalled" -ge "$STREAM_ZERO_BYTES_TIMEOUT" ]; then
                        if _foundation_ai_is_building "$stream_cmd_pid" "$output_file"; then
                            echo -e "${CYAN}[STREAM STATUS]${NC} ${elapsed}s elapsed | ${bytes} bytes | ${AI_PROVIDER} is building — extending stall timeout" >&2
                            write_stream_timeline "BUILDING" "elapsed=${elapsed}s bytes=${bytes} reason=ai_building"
                            last_changed_time=$(date +%s)
                        else
                            echo -e "${RED}[STREAM STATUS]${NC} ${elapsed}s elapsed | ${bytes} bytes | ${AI_PROVIDER} STALLED — no new output for ${stalled}s" >&2
                            write_stream_timeline "TIMEOUT" "elapsed=${elapsed}s bytes=${bytes} stalled=${stalled}s reason=stalled"
                            kill -TERM "$stream_cmd_pid" 2>/dev/null
                            for child in $(pgrep -P "$stream_cmd_pid" 2>/dev/null || true); do
                                kill -TERM "$child" 2>/dev/null || true
                            done
                            break
                        fi
                    fi

                    # Total timeout watchdog
                    if [ "$elapsed" -ge "$STREAM_MAX_TOTAL_TIME" ]; then
                        if _foundation_ai_is_building "$stream_cmd_pid" "$output_file"; then
                            local extended_max=$((STREAM_MAX_TOTAL_TIME + STREAM_BUILD_GRACE_TIME))
                            echo -e "${CYAN}[STREAM STATUS]${NC} ${elapsed}s elapsed | ${bytes} bytes | ${AI_PROVIDER} still building — extending max time to ${extended_max}s" >&2
                            write_stream_timeline "BUILDING" "elapsed=${elapsed}s bytes=${bytes} reason=extending_max_time new_max=${extended_max}s"
                            STREAM_MAX_TOTAL_TIME=$extended_max
                        else
                            echo -e "${RED}[STREAM STATUS]${NC} ${elapsed}s elapsed | ${bytes} bytes | ${AI_PROVIDER} TIMEOUT — max total time reached" >&2
                            write_stream_timeline "TIMEOUT" "elapsed=${elapsed}s bytes=${bytes} reason=max_total_time"
                            kill -TERM "$stream_cmd_pid" 2>/dev/null
                            for child in $(pgrep -P "$stream_cmd_pid" 2>/dev/null || true); do
                                kill -TERM "$child" 2>/dev/null || true
                            done
                            break
                        fi
                    fi

                    local msg="${elapsed}s elapsed | ${bytes} bytes | ${AI_PROVIDER} still working..."
                    echo -e "${CYAN}[STREAM STATUS]${NC} $msg" >&2
                    write_stream_timeline "HEARTBEAT" "elapsed=${elapsed}s bytes=${bytes}"
                done
            ) &
            heartbeat_pid=$!
        fi

        # Wait for the stream command to finish
        local stream_exit=0
        if wait "$stream_cmd_pid"; then
            stream_exit=0
        else
            stream_exit=$?
        fi

        # Stop tail
        if [ -n "$tail_pid" ]; then
            kill "$tail_pid" 2>/dev/null || true
            wait "$tail_pid" 2>/dev/null || true
        fi

        # Stop heartbeat
        if [ -n "$heartbeat_pid" ]; then
            kill "$heartbeat_pid" 2>/dev/null || true
            wait "$heartbeat_pid" 2>/dev/null || true
        fi

        local total_elapsed=$(($(date +%s) - stream_start_time))
        local output_bytes=0
        [ -f "$output_file" ] && output_bytes=$(wc -c < "$output_file" 2>/dev/null || echo 0)

        # Detect timeout: killed by watchdog (SIGTERM/exit 143) OR zero bytes for too long
        # SIGTERM (143 = 128+15) means our watchdog killed it — always treat as timeout
        local was_killed_by_watchdog=false
        local timeout_type="timeout"  # "timeout" = zero bytes, "stall" = partial output then stopped
        if [ "$stream_exit" -eq 143 ]; then
            was_killed_by_watchdog=true
            if [ "$output_bytes" -gt 0 ]; then
                timeout_type="stall"
            fi
        elif [ $stream_exit -ne 0 ] && [ "$output_bytes" -eq 0 ] && [ "$total_elapsed" -ge "$STREAM_ZERO_BYTES_TIMEOUT" ]; then
            was_killed_by_watchdog=true
            timeout_type="timeout"
        elif [ $stream_exit -ne 0 ] && [ "$output_bytes" -gt 0 ] && [ "$total_elapsed" -ge "$STREAM_MAX_TOTAL_TIME" ]; then
            was_killed_by_watchdog=true
            timeout_type="stall"
        fi

        if [ "$was_killed_by_watchdog" = "true" ]; then
            AI_LAST_TIMEOUT="true"
            AI_LAST_TIMEOUT_TYPE="$timeout_type"
            ai_exit_code=124  # Standard timeout exit code
            write_stream_timeline "TIMEOUT" "elapsed=${total_elapsed}s exit=124 bytes=${output_bytes} type=${timeout_type}"
            echo "" >&2
            if [ "$timeout_type" = "stall" ]; then
                echo -e "${RED}[STALL]${NC} ${AI_PROVIDER} stalled after ${total_elapsed}s (${output_bytes} bytes partial output) — switching providers" >&2
            else
                echo -e "${RED}[TIMEOUT]${NC} ${AI_PROVIDER} timed out after ${total_elapsed}s (${output_bytes} bytes produced) — switching providers" >&2
            fi
        elif [ $stream_exit -eq 0 ]; then
            AI_LAST_TIMEOUT="false"
            ai_exit_code=0
            write_stream_timeline "COMPLETE" "elapsed=${total_elapsed}s exit=0"
            echo "" >&2
            echo -e "${GREEN}[DONE]${NC} Code generation completed ✓ (${total_elapsed}s)" >&2
        else
            AI_LAST_TIMEOUT="false"
            ai_exit_code=$stream_exit
            write_stream_timeline "FAILED" "elapsed=${total_elapsed}s exit=$stream_exit"
            echo "" >&2
            echo -e "${RED}[FAILED]${NC} Code generation failed (exit $stream_exit) after ${total_elapsed}s ✗" >&2
        fi

        echo -e "${CYAN}─── End Output ───${NC}" >&2
        echo "" >&2
    else
        # Non-streaming: use spinner animation with timeout
        start_spinner "$spinner_msg"

        # Run in background subshell so we can enforce a timeout
        (
            cd "$WORK_DIR" && eval "$ai_cmd_full" > "$output_file" 2>&1
        ) &
        local bg_pid=$!

        # Timeout watchdog — checks periodically and extends if the AI is building
        (
            local total_waited=0
            local check_interval=10
            while [ "$total_waited" -lt "$STREAM_MAX_TOTAL_TIME" ]; do
                sleep "$check_interval"
                total_waited=$((total_waited + check_interval))
                if [ -f "$output_file" ] && _foundation_ai_is_building "" "$output_file"; then
                    STREAM_MAX_TOTAL_TIME=$((STREAM_MAX_TOTAL_TIME + STREAM_BUILD_GRACE_TIME))
                    echo "[BUILD EXTENSION] AI is building — extending timeout to ${STREAM_MAX_TOTAL_TIME}s" >&2
                fi
                if ! kill -0 "$bg_pid" 2>/dev/null; then
                    break
                fi
            done
            if kill -0 "$bg_pid" 2>/dev/null; then
                kill -TERM "$bg_pid" 2>/dev/null
                for child in $(pgrep -P "$bg_pid" 2>/dev/null || true); do
                    kill -TERM "$child" 2>/dev/null || true
                done
            fi
        ) &

        if wait "$bg_pid"; then
            ai_exit_code=0
            spinner_success "$spinner_msg"
        else
            ai_exit_code=$?
            if [ "$ai_exit_code" -eq 143 ] || [ "$ai_exit_code" -eq 124 ]; then
                AI_LAST_TIMEOUT="true"
                AI_LAST_TIMEOUT_TYPE="timeout"
                log_warning "${AI_PROVIDER} timed out after ${STREAM_MAX_TOTAL_TIME}s (non-streaming mode)"
            fi
            spinner_error "$spinner_msg"
        fi
    fi

    # Check for authentication errors in the output
    if [ -f "$output_file" ]; then
        local ai_output
        ai_output=$(cat "$output_file")

        if check_auth_error "$ai_output"; then
            # Auth error detected, update session context
            update_session_context "$CURRENT_ATTEMPT" "auth_failed" "Authentication error with $AI_PROVIDER"
            # Clean up Kimi temp MCP config if created
            if [ -n "${kimi_mcp_config:-}" ] && [ -f "$kimi_mcp_config" ]; then
                rm -f "$kimi_mcp_config"
            fi
            log_error "Please authenticate with $AI_PROVIDER and try again"
            return 1
        fi
    fi

    # On first attempt with Cursor, try to capture the chat ID for future resume
    if [ "$SKIP_CHAT_ID_CAPTURE" = "false" ] && [ "$AI_PROVIDER" = "cursor" ] && [ "$is_followup" = "false" ] && [ -z "$CURSOR_CHAT_ID" ] && [ "$AI_CMD" = "cursor-agent" ] && [ $ai_exit_code -eq 0 ]; then
        log_verbose "Attempting to capture Cursor chat ID..."

        # Show spinner while capturing chat ID (can take a few seconds)
        start_spinner "Capturing chat session ID"
        local new_chat_id
        new_chat_id=$(get_latest_chat_id)
        stop_spinner

        if [ -n "$new_chat_id" ]; then
            CURSOR_CHAT_ID="$new_chat_id"
            # Store in session file for persistence
            echo "Cursor Chat ID: $CURSOR_CHAT_ID" >> "$SESSION_FILE"
            log_verbose "Captured Cursor chat ID: $CURSOR_CHAT_ID"
        else
            log_verbose "Could not capture chat ID (session resume disabled)"
        fi
    elif [ "$SKIP_CHAT_ID_CAPTURE" = "true" ]; then
        log_verbose "Chat ID capture skipped (--skip-chat-id)"
    fi

    # Update session context
    if [ $ai_exit_code -eq 0 ]; then
        update_session_context "$CURRENT_ATTEMPT" "completed" "Code generated successfully with $AI_PROVIDER"
    else
        update_session_context "$CURRENT_ATTEMPT" "failed" "${AI_PROVIDER} CLI exit code: $ai_exit_code"
    fi

    # Clean up Kimi temp MCP config if created (do this before early returns)
    if [ -n "${kimi_mcp_config:-}" ] && [ -f "$kimi_mcp_config" ]; then
        rm -f "$kimi_mcp_config"
    fi

    if [ $ai_exit_code -ne 0 ]; then
        log_error "${AI_PROVIDER} CLI failed with exit code: $ai_exit_code"
        return 1
    fi

    log_success "${AI_PROVIDER} CLI completed"
    return 0
}

# ─────────────────────────────────────────────────────────────────────────────
# Multi-Platform Build Orchestration
# ─────────────────────────────────────────────────────────────────────────────
# Run builds for multiple platforms using parallel execution.
# All builds run concurrently via xargs -P with a live progress monitor.
