#!/usr/bin/env bash
# lib/build/ui.sh — Spinner, unbuffered output, sidebar, and UI box functions for BuildAgent
[ -n "${_BUILD_UI_SH:-}" ] && return 0
_BUILD_UI_SH=1

# ─────────────────────────────────────────────────────────────────────────────
# Spinner/Progress Functions
# ─────────────────────────────────────────────────────────────────────────────

# Spinner characters (braille pattern for smooth animation)
SPINNER_CHARS="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"

# Alternative spinner styles
SPINNER_DOTS="⣾⣽⣻⢿⡿⣟⣯⣷"
SPINNER_ARROWS="←↖↑↗→↘↓↙"
SPINNER_BOUNCE="⠁⠂⠄⠂"

# Current spinner message (for reference)
SPINNER_MESSAGE=""

# Start spinner with message - format: [WORKING] Message ⠹
start_spinner() {
    local message="$1"
    SPINNER_MESSAGE="$message"

    # Use enhanced spinner when fancy UI is enabled
    if [ "${BUILDAGENT_FANCY_UI:-false}" = "true" ] && type start_enhanced_spinner &>/dev/null; then
        start_enhanced_spinner "$message"
        return
    fi

    # Don't start spinner if not a TTY (but allow it in stream mode)
    if [ ! -t 2 ]; then
        echo -e "${CYAN}[WORKING]${NC} $message ..." >&2
        return
    fi

    # Kill any existing spinner
    stop_spinner 2>/dev/null || true

    # In stream mode, use a newline approach so spinner doesn't interfere with streamed output
    if [ "$STREAM_OUTPUT" = "true" ]; then
        # Start spinner on a new line that will be updated in place
        echo "" >&2  # Ensure we're on a new line
        (
            local i=0
            local spin_len=${#SPINNER_CHARS}
            local elapsed=0
            while true; do
                local char="${SPINNER_CHARS:$i:1}"
                # Format: [WORKING] Message ⠹ (Xs) - use \r to overwrite same line
                if [ $elapsed -ge 5 ]; then
                    printf "\r\033[K${CYAN}[WORKING]${NC} %s ${YELLOW}%s${NC} ${BLUE}(%ds)${NC}" "$message" "$char" "$elapsed" >&2
                else
                    printf "\r\033[K${CYAN}[WORKING]${NC} %s ${YELLOW}%s${NC}" "$message" "$char" >&2
                fi
                i=$(( (i + 1) % spin_len ))
                sleep 0.1
                # Update elapsed time every 10 iterations (1 second)
                if [ $(( (i + 1) % 10 )) -eq 0 ]; then
                    elapsed=$((elapsed + 1))
                fi
            done
        ) &
        SPINNER_PID=$!
        disown $SPINNER_PID 2>/dev/null || true
    else
        # Normal mode - spinner overwrites same line
        (
            local i=0
            local spin_len=${#SPINNER_CHARS}
            local elapsed=0
            while true; do
                local char="${SPINNER_CHARS:$i:1}"
                # Format: [WORKING] Message ⠹ (Xs)
                if [ $elapsed -ge 5 ]; then
                    printf "\r\033[K${CYAN}[WORKING]${NC} %s ${YELLOW}%s${NC} ${BLUE}(%ds)${NC}" "$message" "$char" "$elapsed" >&2
                else
                    printf "\r\033[K${CYAN}[WORKING]${NC} %s ${YELLOW}%s${NC}" "$message" "$char" >&2
                fi
                i=$(( (i + 1) % spin_len ))
                sleep 0.1
                # Update elapsed time every 10 iterations (1 second)
                if [ $(( (i + 1) % 10 )) -eq 0 ]; then
                    elapsed=$((elapsed + 1))
                fi
            done
        ) &
        SPINNER_PID=$!
        disown $SPINNER_PID 2>/dev/null || true
    fi
}

# Stop spinner with optional completion message
stop_spinner() {
    local completion_msg="${1:-}"

    # Use enhanced spinner stop when fancy UI is enabled
    if [ "${BUILDAGENT_FANCY_UI:-false}" = "true" ] && type stop_enhanced_spinner &>/dev/null; then
        stop_enhanced_spinner
        if [ -n "$completion_msg" ]; then
            echo -e "$completion_msg" >&2
        fi
        return
    fi

    if [ -n "$SPINNER_PID" ]; then
        kill $SPINNER_PID 2>/dev/null || true
        wait $SPINNER_PID 2>/dev/null || true
        SPINNER_PID=""
        # Clear the spinner line
        printf "\r\033[K" >&2

        # Show completion message if provided
        if [ -n "$completion_msg" ]; then
            echo -e "$completion_msg" >&2
        fi
    fi
}

# Stop spinner with success message
spinner_success() {
    local message="${1:-$SPINNER_MESSAGE}"

    # Use enhanced spinner done when fancy UI is enabled
    if [ "${BUILDAGENT_FANCY_UI:-false}" = "true" ] && type spinner_done &>/dev/null; then
        spinner_done "$message"
        return
    fi

    stop_spinner
    echo -e "${GREEN}[DONE]${NC} $message ${GREEN}✓${NC}" >&2
}

# Stop spinner with error message
spinner_error() {
    local message="${1:-$SPINNER_MESSAGE}"

    # Use enhanced spinner fail when fancy UI is enabled
    if [ "${BUILDAGENT_FANCY_UI:-false}" = "true" ] && type spinner_fail &>/dev/null; then
        spinner_fail "$message"
        return
    fi

    stop_spinner
    echo -e "${RED}[FAILED]${NC} $message ${RED}✗${NC}" >&2
}

# Update spinner message (stops and restarts with new message)
update_spinner() {
    local message="$1"
    stop_spinner
    start_spinner "$message"
}

# Cleanup on exit (spinner + build queue locks + sidebar)
cleanup_all() {
    # Disable sidebar mode before exit
    if [ "${SIDEBAR_MODE_ACTIVE:-false}" = "true" ]; then
        disable_sidebar_mode 2>/dev/null || true
    fi
    # Stop both legacy and enhanced spinners
    stop_spinner 2>/dev/null || true
    if [ "${BUILDAGENT_FANCY_UI:-false}" = "true" ] && type stop_enhanced_spinner &>/dev/null; then
        stop_enhanced_spinner 2>/dev/null || true
    fi
    # Release any held build queue locks
    if [ "$BUILD_QUEUE_AVAILABLE" = "true" ]; then
        bq_cleanup 2>/dev/null || true
    fi
}
trap cleanup_all EXIT INT TERM

# ─────────────────────────────────────────────────────────────────────────────
# Sidebar Mode (persistent top status bar)
# ─────────────────────────────────────────────────────────────────────────────

SIDEBAR_DAEMON_PID=""
SIDEBAR_MODE_ACTIVE="false"
SIDEBAR_HEIGHT=2

# ─────────────────────────────────────────────────────────────────────────────
# Unbuffered Output Functions (for streaming mode)
# ─────────────────────────────────────────────────────────────────────────────

# Detect best available unbuffering method
detect_unbuffer_method() {
    if command -v stdbuf >/dev/null 2>&1; then
        echo "stdbuf"
    elif command -v unbuffer >/dev/null 2>&1; then
        echo "unbuffer"
    elif command -v script >/dev/null 2>&1; then
        echo "script"
    else
        echo "none"
    fi
}

# Run command with unbuffered output
run_unbuffered() {
    local cmd="$1"

    case "$UNBUFFER_METHOD" in
        stdbuf)
            # Line-buffered mode (best performance, most compatible)
            stdbuf -oL -eL bash -c "$cmd"
            ;;
        unbuffer)
            # expect's unbuffer (may not preserve exit codes well)
            unbuffer bash -c "$cmd"
            ;;
        script)
            # BSD/macOS script command (more portable but can be verbose)
            # -q flag suppresses start/done messages
            script -q /dev/null bash -c "$cmd"
            ;;
        none)
            # No unbuffering available - run normally (may be buffered)
            bash -c "$cmd"
            ;;
    esac
}

# Unbuffer tee specifically (tee adds its own buffering layer)
unbuffered_tee() {
    local output_file="$1"

    case "$UNBUFFER_METHOD" in
        stdbuf)
            stdbuf -oL -eL tee "$output_file"
            ;;
        script)
            # script with tee (less ideal but works)
            script -q /dev/null tee "$output_file"
            ;;
        *)
            # Fallback: use regular tee (may be buffered)
            tee "$output_file"
            ;;
    esac
}

init_ui() {
    # Skip UI initialization if disabled or not available
    if [ "${BUILDAGENT_FANCY_UI:-false}" != "true" ]; then
        return 0
    fi

    # Detect terminal capabilities
    if type detect_terminal_capabilities &>/dev/null; then
        detect_terminal_capabilities
    fi

    # Select theme
    if type select_theme &>/dev/null; then
        select_theme "${BUILDAGENT_THEME:-dark}"
    fi

    # Enable phrase cycling for spinner
    if type enable_phrase_cycling &>/dev/null && [ "${BUILDAGENT_WITTY_PHRASES:-true}" = "true" ]; then
        enable_phrase_cycling
    fi
}

# Show startup UI (logo, banner, tip)
show_startup_ui() {
    if [ "${BUILDAGENT_FANCY_UI:-false}" != "true" ]; then
        return 0
    fi

    # Show logo
    if type show_logo &>/dev/null; then
        show_logo "auto"
    fi

    # Show banner
    if type show_banner &>/dev/null; then
        show_banner "Foundation BuildAgent" "AI-Powered Build Verification"
    fi

    # Show random tip
    if type get_random_tip_formatted &>/dev/null && [ "${BUILDAGENT_SHOW_TIPS:-true}" = "true" ]; then
        local tip
        tip=$(get_random_tip_formatted)
        echo "" >&2
        echo "$tip" >&2
        echo "" >&2
    fi
}

# Show configuration box
show_config_box() {
    if [ "${BUILDAGENT_FANCY_UI:-false}" != "true" ]; then
        return 0
    fi

    if ! type draw_box &>/dev/null; then
        return 0
    fi

    local config_content=""
    config_content+="Scheme: ${SCHEME:-auto-detect}\n"
    config_content+="Configuration: ${BUILD_CONFIGURATION:-Debug}\n"
    config_content+="AI Provider: ${AI_PROVIDER:-copilot}\n"
    config_content+="Max Attempts: ${MAX_REPAIR_ATTEMPTS:-3}"

    if [ -n "$DESTINATION" ]; then
        config_content+="\nDestination: $DESTINATION"
    fi

    if [ ${#DETECTED_PLATFORMS[@]} -gt 1 ]; then
        config_content+="\nPlatforms: ${DETECTED_PLATFORMS[*]}"
    fi

    draw_box "Configuration" "$config_content"
}

# ─────────────────────────────────────────────────────────────────────────────
# AI Provider Detection & Configuration
# ─────────────────────────────────────────────────────────────────────────────

# Attempt to install missing AI provider using Cursor CLI
