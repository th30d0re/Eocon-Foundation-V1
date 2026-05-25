#!/usr/bin/env bash
# Library: ui_components.sh
# Purpose: Visual UI components for terminal output
# Dependencies: ui_themes.sh (for colors and icons)
#
# Functions:
#   show_logo(size)                    - Display ASCII art logo
#   draw_box(title, content, width)    - Box with rounded corners
#   show_progress(current, total, label) - Progress bar
#   show_step(current, total, name)    - Step indicator
#   show_status_footer(provider, attempt, max, scheme) - Persistent footer
#   print_gradient(text)               - Gradient text effect
#   show_banner(title, subtitle)       - Banner with gradient title
#   start_enhanced_spinner(message)    - Spinner with phrase cycling
#   stop_enhanced_spinner(message)     - Stop spinner with message
#
# Spinner Styles:
#   braille, dots, arrows, bounce, pulse, moon, clock, box, star
#
# Environment Variables:
#   BUILDAGENT_SPINNER_STYLE  - Spinner style (default: braille)
#   BUILDAGENT_FANCY_UI       - Enable/disable fancy UI
#
# Usage:
#   source ui_themes.sh
#   source ui_components.sh
#   show_logo "medium"
#   draw_box "Configuration" "Scheme: MyApp\nPlatform: iOS" 50

set -euo pipefail

# Verify bash is running
if [ -z "${BASH_VERSION:-}" ]; then
    echo "Error: This library requires bash" >&2
    return 1 2>/dev/null || exit 1
fi

# Load ui_themes.sh if not already loaded
UI_COMPONENTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if ! declare -p THEME_COLORS &>/dev/null || [ "${#THEME_COLORS[@]}" -eq 0 ]; then
    if [ -f "${UI_COMPONENTS_LIB_DIR}/ui_themes.sh" ]; then
        # shellcheck disable=SC1091
        source "${UI_COMPONENTS_LIB_DIR}/ui_themes.sh"
    fi
fi

# ─────────────────────────────────────────────────────────────────────────────
# Spinner Configuration
# ─────────────────────────────────────────────────────────────────────────────

# Spinner styles
declare -A SPINNER_STYLES=(
    [braille]="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
    [dots]="⣾⣽⣻⢿⡿⣟⣯⣷"
    [arrows]="←↖↑↗→↘↓↙"
    [bounce]="⠁⠂⠄⡀⢀⠠⠐⠈"
    [pulse]="⣾⣽⣻⢿⡿⣟⣯⣷"
    [moon]="🌑🌒🌓🌔🌕🌖🌗🌘"
    [clock]="🕐🕑🕒🕓🕔🕕🕖🕗🕘🕙🕚🕛"
    [box]="◰◳◲◱"
    [star]="✶✸✹✺✹✸"
)

# Enhanced spinner state
_ENHANCED_SPINNER_PID=""
_ENHANCED_SPINNER_MESSAGE=""
_PHRASE_CYCLE_ENABLED="false"

# ─────────────────────────────────────────────────────────────────────────────
# Logo Definitions
# ─────────────────────────────────────────────────────────────────────────────

# Large logo (80+ columns)
_LOGO_LARGE='
    ___________                    .___       __  .__
    \_   _____/___  __ __  ____   __| _/____ _/  |_|__| ____   ____
     |    __)/  _ \|  |  \/    \ / __ |\__  \\   __\  |/  _ \ /    \
     |     \(  <_> )  |  /   |  \ /_/ | / __ \|  | |  (  <_> )   |  \
     \___  / \____/|____/|___|  /\____ |(____  /__| |__|\____/|___|  /
         \/                   \/      \/     \/                    \/
'

# Medium logo (60+ columns)
_LOGO_MEDIUM='
  ___                  _       _   _
 | __|__ _  _ _ _  __| |__ _| |_(_)___ _ _
 | _/ _ \ || | '\'' \/ _` / _` |  _| / _ \ '\'' \
 |_|\___/\_,_|_||_\__,_\__,_|\__|_\___/_||_|
'

# Small logo (40+ columns)
_LOGO_SMALL='
 Foundation BuildAgent
'

# ─────────────────────────────────────────────────────────────────────────────
# Logo Functions
# ─────────────────────────────────────────────────────────────────────────────

# Display ASCII art logo based on terminal width
# Arguments:
#   $1 - size: large, medium, small, auto (default: auto)
show_logo() {
    local size="${1:-auto}"

    # Check if explicitly enabled, bypass is_fancy_ui_enabled() checks
    if [ "${BUILDAGENT_FANCY_UI:-false}" = "true" ]; then
        # Explicitly enabled, proceed
        :
    elif ! is_fancy_ui_enabled 2>/dev/null; then
        return 0
    fi

    local width
    width=$(get_terminal_width 2>/dev/null || echo "80")

    # Auto-select size based on terminal width
    if [ "$size" = "auto" ]; then
        if [ "$width" -ge 80 ]; then
            size="large"
        elif [ "$width" -ge 60 ]; then
            size="medium"
        else
            size="small"
        fi
    fi

    local primary
    local accent
    local reset
    primary=$(get_color "primary")
    accent=$(get_color "accent")
    reset=$(get_color "reset")

    case "$size" in
        large)
            echo -e "${primary}${_LOGO_LARGE}${reset}" >&2
            ;;
        medium)
            echo -e "${accent}${_LOGO_MEDIUM}${reset}" >&2
            ;;
        small|*)
            echo -e "${primary}${_LOGO_SMALL}${reset}" >&2
            ;;
    esac
}

# ─────────────────────────────────────────────────────────────────────────────
# Box Drawing Functions
# ─────────────────────────────────────────────────────────────────────────────

# Draw a box with rounded corners
# Arguments:
#   $1 - title (optional, can be empty)
#   $2 - content (newline-separated lines)
#   $3 - width (optional, default: auto based on content)
#   $4 - border_color (optional, default: border)
draw_box() {
    local title="${1:-}"
    local content="${2:-}"
    local width="${3:-0}"
    local border_color_name="${4:-border}"

    local border_color
    local title_color
    local content_color
    local reset

    # Check if explicitly enabled or auto-detected as enabled
    if [ "${BUILDAGENT_FANCY_UI:-false}" = "true" ] || is_fancy_ui_enabled 2>/dev/null; then
        border_color=$(get_color "$border_color_name")
        title_color=$(get_color "primary")
        content_color=$(get_color "muted")
        reset=$(get_color "reset")
    else
        border_color=""
        title_color=""
        content_color=""
        reset=""
    fi

    # Get box drawing characters
    local tl tr bl br h v
    tl=$(get_icon "box_tl" 2>/dev/null || echo "+")
    tr=$(get_icon "box_tr" 2>/dev/null || echo "+")
    bl=$(get_icon "box_bl" 2>/dev/null || echo "+")
    br=$(get_icon "box_br" 2>/dev/null || echo "+")
    h=$(get_icon "box_h" 2>/dev/null || echo "-")
    v=$(get_icon "box_v" 2>/dev/null || echo "|")

    # Calculate width if not specified
    if [ "$width" -eq 0 ]; then
        # Find the longest line
        local max_len=0
        while IFS= read -r line; do
            local stripped
            stripped=$(echo "$line" | sed 's/\x1b\[[0-9;]*m//g')
            local len=${#stripped}
            if [ "$len" -gt "$max_len" ]; then
                max_len=$len
            fi
        done <<< "$content"

        # Account for title if longer
        local title_len=${#title}
        if [ "$title_len" -gt "$max_len" ]; then
            max_len=$title_len
        fi

        width=$((max_len + 4))  # Add padding

        # Limit to terminal width
        local term_width
        term_width=$(get_terminal_width 2>/dev/null || echo "80")
        if [ "$width" -gt "$((term_width - 4))" ]; then
            width=$((term_width - 4))
        fi
    fi

    local inner_width=$((width - 2))

    # Draw top border
    local top_border=""
    for ((i=0; i<inner_width; i++)); do
        top_border+="$h"
    done

    if [ -n "$title" ]; then
        # Center the title in the top border
        local title_display=" $title "
        local title_len=${#title_display}
        local left_padding=$(( (inner_width - title_len) / 2 ))
        local right_padding=$((inner_width - title_len - left_padding))

        local left_border=""
        for ((i=0; i<left_padding; i++)); do
            left_border+="$h"
        done

        local right_border=""
        for ((i=0; i<right_padding; i++)); do
            right_border+="$h"
        done

        echo -e "${border_color}${tl}${left_border}${title_color}${title_display}${border_color}${right_border}${tr}${reset}" >&2
    else
        echo -e "${border_color}${tl}${top_border}${tr}${reset}" >&2
    fi

    # Draw content lines
    while IFS= read -r line; do
        # Strip ANSI codes to calculate padding
        local stripped
        stripped=$(echo "$line" | sed 's/\x1b\[[0-9;]*m//g')
        local line_len=${#stripped}
        local padding=$((inner_width - line_len - 2))

        if [ "$padding" -lt 0 ]; then
            padding=0
            # Truncate line if too long
            line="${line:0:$((inner_width - 2))}"
        fi

        local spaces=""
        for ((i=0; i<padding; i++)); do
            spaces+=" "
        done

        echo -e "${border_color}${v}${reset} ${content_color}${line}${spaces}${reset} ${border_color}${v}${reset}" >&2
    done <<< "$content"

    # Draw bottom border
    local bottom_border=""
    for ((i=0; i<inner_width; i++)); do
        bottom_border+="$h"
    done
    echo -e "${border_color}${bl}${bottom_border}${br}${reset}" >&2
}

# ─────────────────────────────────────────────────────────────────────────────
# Progress Bar Functions
# ─────────────────────────────────────────────────────────────────────────────

# Show a progress bar
# Arguments:
#   $1 - current value
#   $2 - total value
#   $3 - label (optional)
#   $4 - width (optional, default: 40)
show_progress() {
    local current="${1:-0}"
    local total="${2:-100}"
    local label="${3:-Progress}"
    local width="${4:-40}"

    if [ "$total" -eq 0 ]; then
        total=1
    fi

    local percentage=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))

    local full_char
    local empty_char
    full_char=$(get_icon "progress_full" 2>/dev/null || echo "#")
    empty_char=$(get_icon "progress_empty" 2>/dev/null || echo "-")

    local success_color
    local muted_color
    local reset

    # Check if explicitly enabled or auto-detected as enabled
    if [ "${BUILDAGENT_FANCY_UI:-false}" = "true" ] || is_fancy_ui_enabled 2>/dev/null; then
        success_color=$(get_color "success")
        muted_color=$(get_color "muted")
        reset=$(get_color "reset")
    else
        success_color=""
        muted_color=""
        reset=""
    fi

    # Build the bar
    local bar=""
    for ((i=0; i<filled; i++)); do
        bar+="$full_char"
    done
    for ((i=0; i<empty; i++)); do
        bar+="$empty_char"
    done

    printf "\r${success_color}%s${reset} [${success_color}%s${muted_color}%s${reset}] ${success_color}%3d%%${reset}" \
        "$label" "${bar:0:$filled}" "${bar:$filled}" "$percentage" >&2
}

# ─────────────────────────────────────────────────────────────────────────────
# Step Indicator Functions
# ─────────────────────────────────────────────────────────────────────────────

# Show step indicator
# Arguments:
#   $1 - current step
#   $2 - total steps
#   $3 - step name
show_step() {
    local current="${1:-1}"
    local total="${2:-1}"
    local name="${3:-Step}"

    local primary
    local muted
    local reset

    # Check if explicitly enabled or auto-detected as enabled
    if [ "${BUILDAGENT_FANCY_UI:-false}" = "true" ] || is_fancy_ui_enabled 2>/dev/null; then
        primary=$(get_color "primary")
        muted=$(get_color "muted")
        reset=$(get_color "reset")
    else
        primary=""
        muted=""
        reset=""
    fi

    echo -e "${muted}[${primary}${current}/${total}${muted}]${reset} ${name}" >&2
}

# ─────────────────────────────────────────────────────────────────────────────
# Status Footer Functions
# ─────────────────────────────────────────────────────────────────────────────

# Show persistent status footer at bottom of screen
# Arguments:
#   $1 - ai_provider
#   $2 - current attempt
#   $3 - max attempts
#   $4 - scheme name
show_status_footer() {
    local ai_provider="${1:-unknown}"
    local attempt="${2:-1}"
    local max_attempts="${3:-3}"
    local scheme="${4:-}"

    # Check if explicitly enabled, bypass is_fancy_ui_enabled() checks
    if [ "${BUILDAGENT_FANCY_UI:-false}" != "true" ] && ! is_fancy_ui_enabled 2>/dev/null; then
        return 0
    fi

    local primary
    local muted
    local accent
    local reset
    primary=$(get_color "primary")
    muted=$(get_color "muted")
    accent=$(get_color "accent")
    reset=$(get_color "reset")

    local width
    width=$(get_terminal_width 2>/dev/null || echo "80")

    # Build footer content
    local footer_left=" AI: ${accent}${ai_provider}${reset}"
    local footer_mid="Attempt: ${primary}${attempt}/${max_attempts}${reset}"
    local footer_right=""
    if [ -n "$scheme" ]; then
        footer_right="Scheme: ${accent}${scheme}${reset} "
    fi

    # Calculate spacing
    local left_len=$((${#ai_provider} + 5))
    local mid_len=$((${#attempt} + ${#max_attempts} + 10))
    local right_len=$((${#scheme} + 9))
    local total_len=$((left_len + mid_len + right_len))
    local spaces=$((width - total_len - 4))

    if [ "$spaces" -lt 0 ]; then
        spaces=2
    fi

    local spacing=""
    for ((i=0; i<spaces/2; i++)); do
        spacing+=" "
    done

    # Save cursor, move to last line, print footer, restore cursor
    printf "\033[s\033[%d;1H${muted}%s${spacing}%s${spacing}%s${reset}\033[u" \
        "$(get_terminal_height 2>/dev/null || echo 24)" \
        "$footer_left" "$footer_mid" "$footer_right" >&2
}

# ─────────────────────────────────────────────────────────────────────────────
# Gradient Text Functions
# ─────────────────────────────────────────────────────────────────────────────

# Print text with gradient effect (blue -> purple -> pink)
# Arguments:
#   $1 - text to print
print_gradient() {
    local text="$1"

    # Check if explicitly enabled or auto-detected as enabled
    if [ "${BUILDAGENT_FANCY_UI:-false}" != "true" ] && ! is_fancy_ui_enabled 2>/dev/null || ! has_true_color 2>/dev/null; then
        local primary
        primary=$(get_color "primary")
        local reset
        reset=$(get_color "reset")
        echo -e "${primary}${text}${reset}"
        return
    fi

    local len=${#text}
    local result=""

    # Gradient from blue (137,180,250) -> mauve (203,166,247) -> pink (243,139,168)
    for ((i=0; i<len; i++)); do
        local char="${text:$i:1}"
        local progress=$((i * 100 / len))

        local r g b
        if [ "$progress" -lt 50 ]; then
            # Blue to Mauve
            local p=$((progress * 2))
            r=$((137 + (203 - 137) * p / 100))
            g=$((180 + (166 - 180) * p / 100))
            b=$((250 + (247 - 250) * p / 100))
        else
            # Mauve to Pink
            local p=$(((progress - 50) * 2))
            r=$((203 + (243 - 203) * p / 100))
            g=$((166 + (139 - 166) * p / 100))
            b=$((247 + (168 - 247) * p / 100))
        fi

        result+="\033[38;2;${r};${g};${b}m${char}"
    done

    local reset
    reset=$(get_color "reset")
    echo -e "${result}${reset}"
}

# ─────────────────────────────────────────────────────────────────────────────
# Banner Functions
# ─────────────────────────────────────────────────────────────────────────────

# Show a banner with gradient title
# Arguments:
#   $1 - title
#   $2 - subtitle (optional)
show_banner() {
    local title="$1"
    local subtitle="${2:-}"

    # Check if explicitly enabled, bypass is_fancy_ui_enabled() checks
    if [ "${BUILDAGENT_FANCY_UI:-false}" != "true" ] && ! is_fancy_ui_enabled 2>/dev/null; then
        echo "=== $title ===" >&2
        if [ -n "$subtitle" ]; then
            echo "$subtitle" >&2
        fi
        return 0
    fi

    local width
    width=$(get_terminal_width 2>/dev/null || echo "80")

    # Draw separator line
    local h
    h=$(get_icon "box_h" 2>/dev/null || echo "-")
    local border_color
    border_color=$(get_color "border")
    local reset
    reset=$(get_color "reset")

    local separator=""
    for ((i=0; i<width-2; i++)); do
        separator+="$h"
    done

    echo "" >&2
    echo -e "${border_color}${separator}${reset}" >&2
    echo "" >&2

    # Print gradient title (centered)
    local title_len=${#title}
    local left_pad=$(( (width - title_len) / 2 ))
    local padding=""
    for ((i=0; i<left_pad; i++)); do
        padding+=" "
    done

    echo -n "$padding" >&2
    print_gradient "$title" >&2

    # Print subtitle if provided
    if [ -n "$subtitle" ]; then
        local muted
        muted=$(get_color "muted")
        local subtitle_len=${#subtitle}
        local sub_pad=$(( (width - subtitle_len) / 2 ))
        local sub_padding=""
        for ((i=0; i<sub_pad; i++)); do
            sub_padding+=" "
        done
        echo -e "${sub_padding}${muted}${subtitle}${reset}" >&2
    fi

    echo "" >&2
    echo -e "${border_color}${separator}${reset}" >&2
    echo "" >&2
}

# ─────────────────────────────────────────────────────────────────────────────
# Enhanced Spinner Functions
# ─────────────────────────────────────────────────────────────────────────────

# Start enhanced spinner with witty phrases
# Arguments:
#   $1 - initial message
start_enhanced_spinner() {
    local message="$1"
    _ENHANCED_SPINNER_MESSAGE="$message"

    # Don't start spinner if not a TTY
    if [ ! -t 2 ]; then
        local info_color
        info_color=$(get_color "info" 2>/dev/null || echo "")
        local reset
        reset=$(get_color "reset" 2>/dev/null || echo "")
        echo -e "${info_color}[WORKING]${reset} $message ..." >&2
        return
    fi

    # Kill any existing spinner
    stop_enhanced_spinner 2>/dev/null || true

    # Get spinner style
    local style="${BUILDAGENT_SPINNER_STYLE:-braille}"
    local spinner_chars="${SPINNER_STYLES[$style]:-${SPINNER_STYLES[braille]}}"

    # Guard against empty spinner frames
    if [ -z "$spinner_chars" ]; then
        spinner_chars="${SPINNER_STYLES[braille]}"
    fi

    local spin_len=${#spinner_chars}

    # Guard against zero length to prevent divide-by-zero
    if [ "$spin_len" -eq 0 ]; then
        spinner_chars="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
        spin_len=${#spinner_chars}
    fi

    # Load witty phrases if available
    local use_phrases="false"
    if [ "$_PHRASE_CYCLE_ENABLED" = "true" ] && type get_random_phrase &>/dev/null; then
        use_phrases="true"
    fi

    local primary
    local muted
    local reset
    primary=$(get_color "primary" 2>/dev/null || echo "")
    muted=$(get_color "muted" 2>/dev/null || echo "")
    reset=$(get_color "reset" 2>/dev/null || echo "")

    (
        local i=0
        local elapsed=0
        local phrase_interval=50  # Update phrase every 5 seconds (50 * 0.1s)
        local phrase_counter=0
        local current_phrase="$message"

        while true; do
            local char="${spinner_chars:$i:1}"

            # Update phrase periodically
            if [ "$use_phrases" = "true" ]; then
                if [ $((phrase_counter % phrase_interval)) -eq 0 ] && [ "$phrase_counter" -gt 0 ]; then
                    current_phrase=$(get_random_phrase 2>/dev/null || echo "$message")
                fi
                phrase_counter=$((phrase_counter + 1))
            fi

            # Format: [WORKING] Message  (Xs)
            # Clear line first to prevent clipping when message changes length
            if [ "$elapsed" -ge 5 ]; then
                printf "\r\033[K${primary}[WORKING]${reset} %s ${muted}%s${reset} ${primary}(%ds)${reset}" \
                    "$current_phrase" "$char" "$elapsed" >&2
            else
                printf "\r\033[K${primary}[WORKING]${reset} %s ${muted}%s${reset}" \
                    "$current_phrase" "$char" >&2
            fi

            i=$(( (i + 1) % spin_len ))
            sleep 0.1

            # Update elapsed time every 10 iterations
            if [ $((phrase_counter % 10)) -eq 0 ]; then
                elapsed=$((elapsed + 1))
            fi
        done
    ) &
    _ENHANCED_SPINNER_PID=$!
    disown $_ENHANCED_SPINNER_PID 2>/dev/null || true
}

# Stop enhanced spinner with optional completion message
# Arguments:
#   $1 - completion message (optional)
stop_enhanced_spinner() {
    local completion_msg="${1:-}"

    if [ -n "$_ENHANCED_SPINNER_PID" ]; then
        kill $_ENHANCED_SPINNER_PID 2>/dev/null || true
        wait $_ENHANCED_SPINNER_PID 2>/dev/null || true
        _ENHANCED_SPINNER_PID=""

        # Clear the spinner line
        printf "\r\033[K" >&2

        # Show completion message if provided
        if [ -n "$completion_msg" ]; then
            local success
            success=$(get_color "success" 2>/dev/null || echo "")
            local reset
            reset=$(get_color "reset" 2>/dev/null || echo "")
            local check
            check=$(get_icon "check" 2>/dev/null || echo "[v]")
            echo -e "${success}[DONE]${reset} $completion_msg ${success}${check}${reset}" >&2
        fi
    fi
}

# Stop spinner with success message
spinner_done() {
    local message="${1:-$_ENHANCED_SPINNER_MESSAGE}"
    stop_enhanced_spinner
    local success
    success=$(get_color "success" 2>/dev/null || echo "")
    local reset
    reset=$(get_color "reset" 2>/dev/null || echo "")
    local check
    check=$(get_icon "check" 2>/dev/null || echo "[v]")
    echo -e "${success}[DONE]${reset} $message ${success}${check}${reset}" >&2
}

# Stop spinner with error message
spinner_fail() {
    local message="${1:-$_ENHANCED_SPINNER_MESSAGE}"
    stop_enhanced_spinner
    local error
    error=$(get_color "error" 2>/dev/null || echo "")
    local reset
    reset=$(get_color "reset" 2>/dev/null || echo "")
    local cross
    cross=$(get_icon "cross" 2>/dev/null || echo "[x]")
    echo -e "${error}[FAILED]${reset} $message ${error}${cross}${reset}" >&2
}

# Enable phrase cycling for spinner
enable_phrase_cycling() {
    _PHRASE_CYCLE_ENABLED="true"
}

# Disable phrase cycling for spinner
disable_phrase_cycling() {
    _PHRASE_CYCLE_ENABLED="false"
}
