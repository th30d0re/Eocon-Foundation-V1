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
# Live UI State (BuildVerify aesthetic upgrade)
# ─────────────────────────────────────────────────────────────────────────────

LIVE_UI_ACTIVE=false
LIVE_UI_STATE_FILE=""
LIVE_UI_DAEMON_PID=""
LIVE_UI_START_TS=""
LIVE_UI_HEIGHT=0

KEYREADER_ACTIVE=false
KEYREADER_PID=""
STTY_SAVED=""

DAEMON_FRAME=0

# ─────────────────────────────────────────────────────────────────────────────
# Split Pane Layout State (BuildVerify CLI UI Layout Review)
# ─────────────────────────────────────────────────────────────────────────────

SPLIT_LAYOUT_ACTIVE=false
INTERACTION_PANE_VISIBLE=true
INTERACTION_PANE_WIDTH=0      # computed at enable time
INTERACTION_BUFFER_FILE=""
INTERACTION_BUFFER_MAX_LINES=0 # computed at enable time
AGENT_STATE="idle"             # idle | thinking | acting
STATUS_BAR_ROW=0               # row N-1
PROMPT_ROW=0                   # row N

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
# BuildVerify Aesthetic Upgrade — Duration, Symbols, Dividers
# ─────────────────────────────────────────────────────────────────────────────

fmt_elapsed_compact() {
    local s=$1
    if   (( s < 60 ));   then printf "%ds" "$s"
    elif (( s < 3600 )); then printf "%dm %02ds" "$((s/60))" "$((s%60))"
    else                      printf "%dh %02dm %02ds" "$((s/3600))" "$(( (s%3600)/60 ))" "$((s%60))"
    fi
}

get_spinner_frame() {
    local idx=$(( $1 % 10 ))
    local frames=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
    if has_unicode && [ -t 2 ]; then
        printf "%s" "${frames[$idx]}"
    elif [ -t 2 ]; then
        printf "⋯"
    else
        printf "..."
    fi
}

show_phase_divider() {
    local title="$1"
    local elapsed_label=""
    [ -n "${2:-}" ] && elapsed_label="  •  $(fmt_elapsed_compact "$2")"
    local label=" ${title}${elapsed_label} "
    local width; width=$(tput cols 2>/dev/null || echo 80)
    if [ -t 2 ] && has_unicode; then
        local fill_len=$(( width - ${#label} - 2 ))
        (( fill_len < 0 )) && fill_len=0
        local fill; fill=$(printf '%*s' "$fill_len" '' | tr ' ' '─')
        printf "\e[36m\e[2m──\e[0m\e[1m%s\e[0m\e[36m\e[2m%s\e[0m\n" "$label" "$fill" >&2
    else
        printf -- "--- %s ---\n" "$title" >&2
    fi
}

show_pipeline_header() {
    local session="$1" model="$2" dir="$3"
    local short_dir="${dir/#$HOME/\~}"
    local width; width=$(tput cols 2>/dev/null || echo 80)
    if [ -t 2 ] && has_unicode; then
        local header="BuildVerify  •  ${session}  •  ${model}  •  ${short_dir}"
        local rule; rule=$(printf '%*s' "$width" '' | tr ' ' '─')
        if [ "${LIVE_UI_ACTIVE:-false}" = "true" ]; then
            # Draw directly on fixed lines 1-2 so they survive scroll-region output
            printf "\e[1;1H\e[2K\e[1m%s\e[0m" "$header" >&2
            printf "\e[2;1H\e[2K\e[2m%s\e[0m" "$rule" >&2
        else
            printf "\e[1m%s\e[0m\n\e[2m%s\e[0m\n" "$header" "$rule" >&2
        fi
    else
        printf "BuildVerify %s %s %s\n" "$session" "$model" "$short_dir" >&2
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Live UI — Scroll region, daemon, state transport
# ─────────────────────────────────────────────────────────────────────────────

enable_live_ui() {
    [ "$LIVE_UI_ACTIVE" != "true" ] || return 0
    [ -t 2 ]                 || { LIVE_UI_ACTIVE=false; return 0; }
    [ -z "${CI:-}" ]         || { LIVE_UI_ACTIVE=false; return 0; }
    [ "${TERM:-}" != "dumb" ] || { LIVE_UI_ACTIVE=false; return 0; }
    local height; height=$(tput lines 2>/dev/null || echo 0)
    (( height >= 10 ))       || { LIVE_UI_ACTIVE=false; return 0; }

    LIVE_UI_HEIGHT=$height
    LIVE_UI_START_TS=$(date +%s)
    LIVE_UI_STATE_FILE=$(mktemp "/tmp/buildverify_live_XXXXXX")

    printf "op=\nstarted_at=%s\n" "$LIVE_UI_START_TS" > "$LIVE_UI_STATE_FILE"
    # Set scroll region to 3..N-1, clear fixed lines 1-2, park cursor at line 3
    printf "\e[3;%sr" "$((height - 1))" >&2
    printf "\e[1;1H\e[2K\e[2;1H\e[2K\e[3;1H" >&2

    LIVE_UI_ACTIVE=true
    start_live_daemon &
    LIVE_UI_DAEMON_PID=$!
}

enable_keyreader() {
    start_keyreader || true
}

disable_live_ui() {
    [ "$LIVE_UI_ACTIVE" = "true" ] || return 0
    LIVE_UI_ACTIVE=false
    stop_live_daemon
    stop_keyreader
    printf "\e[r\e[?25h" >&2
    printf "\e[%s;1H\e[2K\e[2;1H\e[2K\e[1;1H\e[2K" "$LIVE_UI_HEIGHT" >&2
    [ -n "$LIVE_UI_STATE_FILE" ] && rm -f "$LIVE_UI_STATE_FILE"
    LIVE_UI_STATE_FILE=""
}

update_live_op() {
    [ "$LIVE_UI_ACTIVE" = "true" ] || return 0
    [ -n "$LIVE_UI_STATE_FILE" ]   || return 0
    local tmp; tmp=$(mktemp "${LIVE_UI_STATE_FILE}.XXXXXX")
    printf "op=%s\nstarted_at=%s\n" "$1" "$LIVE_UI_START_TS" > "$tmp"
    mv "$tmp" "$LIVE_UI_STATE_FILE"
}

update_live_step() {
    [ "$LIVE_UI_ACTIVE" = "true" ] || return 0
    [ -n "${LIVE_UI_STATE_FILE:-}" ] || return 0
    local tmp; tmp=$(mktemp "${LIVE_UI_STATE_FILE}.XXXXXX")
    grep -v '^step=' "$LIVE_UI_STATE_FILE" 2>/dev/null > "$tmp" || true
    printf "step=%s\n" "$1" >> "$tmp"
    mv "$tmp" "$LIVE_UI_STATE_FILE"
}

start_keyreader() {
    [ -t 0 ] || { KEYREADER_ACTIVE=false; return 1; }
    STTY_SAVED=$(stty -g 2>/dev/null) || { KEYREADER_ACTIVE=false; return 1; }
    # Use cbreak-style input instead of raw mode so child process output keeps
    # normal newline handling (raw disables ONLCR and causes stair-stepped logs).
    stty -echo -icanon min 1 time 0 2>/dev/null || { KEYREADER_ACTIVE=false; return 1; }
    stty opost onlcr 2>/dev/null || true
    KEYREADER_ACTIVE=true
    local sf="$LIVE_UI_STATE_FILE"
    (
        while true; do
            local key
            key=$(dd if=/dev/stdin bs=1 count=1 2>/dev/null) || break
            case "$key" in
                s|S)
                    local tmp; tmp=$(mktemp "${sf}.XXXXXX")
                    grep -v '^cmd=' "$sf" 2>/dev/null > "$tmp" || true
                    printf "cmd=skip_phase\n" >> "$tmp"
                    mv "$tmp" "$sf"
                    kill -USR1 "$PPID" 2>/dev/null
                    ;;
                r|R)
                    local tmp; tmp=$(mktemp "${sf}.XXXXXX")
                    grep -v '^cmd=' "$sf" 2>/dev/null > "$tmp" || true
                    printf "cmd=skip_to_report\n" >> "$tmp"
                    mv "$tmp" "$sf"
                    kill -USR1 "$PPID" 2>/dev/null
                    ;;
                $'\t') # Tab
                    local tmp; tmp=$(mktemp "${sf}.XXXXXX")
                    grep -v '^cmd=' "$sf" 2>/dev/null > "$tmp" || true
                    printf "cmd=toggle_pane\n" >> "$tmp"
                    mv "$tmp" "$sf"
                    ;;
                '?')
                    local tmp; tmp=$(mktemp "${sf}.XXXXXX")
                    grep -v '^cmd=' "$sf" 2>/dev/null > "$tmp" || true
                    printf "cmd=help\n" >> "$tmp"
                    mv "$tmp" "$sf"
                    # No signal needed for help, daemon handles it
                    ;;
                '/')
                    local result
                    result=$(_bv_readline)
                    if [ $? -eq 0 ] && [ -n "$result" ]; then
                        local tmp; tmp=$(mktemp "${sf}.XXXXXX")
                        grep -v '^cmd=' "$sf" 2>/dev/null > "$tmp" || true
                        printf "cmd=/%s\n" "$result" >> "$tmp"
                        mv "$tmp" "$sf"
                        kill -USR1 "$PPID" 2>/dev/null
                    fi
                    ;;
                $'\x03') # Ctrl+C
                    kill -INT "$PPID" 2>/dev/null
                    ;;
            esac
        done
    ) &
    KEYREADER_PID=$!
}

stop_keyreader() {
    if [ -n "${KEYREADER_PID:-}" ]; then
        kill "$KEYREADER_PID" 2>/dev/null || true
        wait "$KEYREADER_PID" 2>/dev/null || true
    fi
    KEYREADER_PID=""
    KEYREADER_ACTIVE=false
    if [ -n "${STTY_SAVED:-}" ]; then
        stty "$STTY_SAVED" 2>/dev/null || true
    fi
    STTY_SAVED=""
}

start_live_daemon() {
    set +e   # prevent inherited set -euo pipefail from killing the daemon on non-zero returns
    local frame=0
    while [ "$LIVE_UI_ACTIVE" = "true" ]; do
        # Poll command file
        local cmd=""
        local command_mode=""
        if [ -f "${LIVE_UI_STATE_FILE:-}" ]; then
            command_mode=$(grep '^command_mode=' "$LIVE_UI_STATE_FILE" 2>/dev/null | cut -d= -f2-)
            [ "$command_mode" = "1" ] && { sleep 0.1; continue; }

            cmd=$(grep '^cmd=' "$LIVE_UI_STATE_FILE" 2>/dev/null | cut -d= -f2-)
            if [ -n "$cmd" ]; then
                # Clear cmd before acting to prevent re-delivery
                local tmp; tmp=$(mktemp "${LIVE_UI_STATE_FILE}.XXXXXX")
                grep -v '^cmd=' "$LIVE_UI_STATE_FILE" 2>/dev/null > "$tmp" || true
                mv "$tmp" "$LIVE_UI_STATE_FILE"
                case "$cmd" in
                    help)           draw_help_overlay ;;
                    toggle_pane)    toggle_interaction_pane ;;
                    skip_phase|skip_to_report) kill -USR1 "$PPID" 2>/dev/null ;;
                esac
            fi
        fi
        DAEMON_FRAME=$frame
        if [ "$SPLIT_LAYOUT_ACTIVE" = "true" ]; then
            draw_status_bar
            draw_interaction_pane
            draw_prompt_line
        else
            draw_bottom_bar
        fi
        frame=$(( frame + 1 ))
        sleep 1
    done
}

stop_live_daemon() {
    [ -n "${LIVE_UI_DAEMON_PID:-}" ] || return 0
    kill "$LIVE_UI_DAEMON_PID" 2>/dev/null || true
    wait "$LIVE_UI_DAEMON_PID" 2>/dev/null || true
    LIVE_UI_DAEMON_PID=""
}

draw_phase_tracker() {
    [ "$LIVE_UI_ACTIVE" = "true" ] || return 0
    local phase_state="${1:-init:pending,build:pending,test:pending,complete:pending}"
    local line=""
    IFS=',' read -ra pairs <<< "$phase_state"
    for pair in "${pairs[@]}"; do
        local name="${pair%%:*}" state="${pair##*:}"
        case "$state" in
            done)    line+=" \e[32m✓\e[0m ${name^}" ;;
            active)  line+=" \e[33m◉\e[0m ${name^}" ;;
            failed)  line+=" \e[31m✗\e[0m ${name^}" ;;
            *)       line+=" \e[2m○\e[0m ${name^}" ;;
        esac
    done
    tput sc >&2
    printf "\e[2;1H\e[2K%b" "$line" >&2
    tput rc >&2
}

_bv_strip_ansi() {
    # Remove all ESC[...m sequences to measure visible string length
    printf '%s' "$1" | sed "s/$(printf '\x1b')\[[0-9;]*m//g"
}

_bv_show_config() {
    printf "\n  \e[2mFlags:\e[0m\n" >&2
    # Boolean flags
    local keys=("skip-memory" "skip-tests" "dry-run" "verbose" "yolo" "sidebar" "skip-argent" "no-context" "happy-only")
    local vars=("SKIP_MEMORY" "SKIP_TESTS" "DRY_RUN" "VERBOSE" "YOLO_MODE" "SIDEBAR_MODE" "SKIP_ARGENT" "NO_CONTEXT" "HAPPY_ONLY")
    
    local i
    for ((i=0; i<${#keys[@]}; i++)); do
        local key="${keys[$i]}"
        local var="${vars[$i]}"
        local val="${!var:-false}"
        local indicator; [ "$val" = "true" ] && indicator="\e[32m✓\e[0m" || indicator="\e[2m○\e[0m"
        printf "  %b  %-20s %s\n" "$indicator" "/$key" "$val" >&2
    done

    # Value flags
    local v_keys=("ai-provider" "ai-model" "scheme" "project" "simulator" "platform" "max-build" "max-test")
    local v_vars=("AI_PROVIDER" "AI_MODEL" "SCHEME" "PROJECT_PATH" "SIMULATOR_NAME" "PLATFORM" "MAX_BUILD_ATTEMPTS" "MAX_TEST_ATTEMPTS")
    
    for ((i=0; i<${#v_keys[@]}; i++)); do
        local key="${v_keys[$i]}"
        local var="${v_vars[$i]}"
        local val="${!var:-}"
        [ -n "$val" ] && printf "  \e[36m▸\e[0m  %-20s %s\n" "/$key" "$val" >&2
    done
    printf "\n  Type \e[1m/help\e[0m for all commands. \e[1m/run\e[0m to start.\n\n" >&2
}

draw_help_overlay_text() {
    [ "$LIVE_UI_ACTIVE" = "true" ] || return 0
    local msg="$1"
    local width; width=$(tput cols 2>/dev/null || echo 80)
    local truncated="${msg:0:$((width - 1))}"
    tput sc >&2
    printf "\e[%s;1H\e[2K\e[7m%s\e[0m" "$LIVE_UI_HEIGHT" "$truncated" >&2
    tput rc >&2
}

dispatch_command() {
    local input="$1" mode="$2"
    input="${input#/}"  # strip leading / if present
    local cmd="${input%% *}"
    local arg=""
    [[ "$input" == *" "* ]] && arg="${input#* }"

    case "$cmd" in
        # Boolean flag toggles
        skip-memory)   [ "$SKIP_MEMORY"   = "true" ] && SKIP_MEMORY=false   || SKIP_MEMORY=true   ;;
        skip-tests)    [ "$SKIP_TESTS"    = "true" ] && SKIP_TESTS=false    || SKIP_TESTS=true    ;;
        dry-run)       [ "$DRY_RUN"       = "true" ] && DRY_RUN=false       || DRY_RUN=true       ;;
        verbose)       [ "$VERBOSE"       = "true" ] && VERBOSE=false       || VERBOSE=true       ;;
        yolo)          [ "$YOLO_MODE"     = "true" ] && YOLO_MODE=false     || YOLO_MODE=true     ;;
        sidebar)       [ "$SIDEBAR_MODE"  = "true" ] && SIDEBAR_MODE=false  || SIDEBAR_MODE=true  ;;
        skip-argent)   [ "$SKIP_ARGENT"   = "true" ] && SKIP_ARGENT=false   || SKIP_ARGENT=true   ;;
        no-context)    [ "$NO_CONTEXT"    = "true" ] && NO_CONTEXT=false    || NO_CONTEXT=true    ;;
        happy-only)    [ "$HAPPY_ONLY"    = "true" ] && HAPPY_ONLY=false    || HAPPY_ONLY=true    ;;
        # Value flags
        ai-provider)   [ -n "$arg" ] && AI_PROVIDER="$arg" || printf "  AI_PROVIDER=%s\n" "$AI_PROVIDER" >&2 ;;
        ai-model)      [ -n "$arg" ] && AI_MODEL="$arg"    || printf "  AI_MODEL=%s\n"    "$AI_MODEL"    >&2 ;;
        scheme)        [ -n "$arg" ] && SCHEME="$arg"       || printf "  SCHEME=%s\n"      "$SCHEME"      >&2 ;;
        project)       [ -n "$arg" ] && PROJECT_PATH="$arg" || printf "  PROJECT_PATH=%s\n" "$PROJECT_PATH" >&2 ;;
        simulator)     [ -n "$arg" ] && SIMULATOR_NAME="$arg" ;;
        platform)      [ -n "$arg" ] && PLATFORM="$arg" ;;
        max-build)     [ -n "$arg" ] && MAX_BUILD_ATTEMPTS="$arg" ;;
        max-test)      [ -n "$arg" ] && MAX_TEST_ATTEMPTS="$arg" ;;
        prompt)        [ -n "$arg" ] && PROMPT="$arg" ;;
        plan)          [ -n "$arg" ] && PLAN_FILE="$arg" ;;
        artifacts)     [ -n "$arg" ] && ARTIFACTS_DIR="$arg" ;;
        # Pre-run only
        run)
            [ "$mode" = "pre-run" ] && return 99
            printf "  /run is only available before the pipeline starts.\n" >&2
            ;;
        quit)
            [ "$mode" = "pre-run" ] && return 98
            printf "  Use /abort to stop the running pipeline.\n" >&2
            ;;
        # Mid-run only
        skip)
            [ "$mode" = "pre-run" ] && { printf "  /skip is only available during a running phase.\n" >&2; return 0; }
            SKIP_PHASE_FLAG=true
            if kill -0 "${CURRENT_PHASE_PID:-0}" 2>/dev/null; then
                kill -TERM "$CURRENT_PHASE_PID"
            fi
            ;;
        report)
            [ "$mode" = "pre-run" ] && { printf "  /report is only available during a running phase.\n" >&2; return 0; }
            SKIP_TO_REPORT_FLAG=true
            if kill -0 "${CURRENT_PHASE_PID:-0}" 2>/dev/null; then
                kill -TERM "$CURRENT_PHASE_PID"
            fi
            ;;
        abort)
            [ "$mode" = "pre-run" ] && { printf "  Use /quit to exit before starting.\n" >&2; return 0; }
            ABORT_FLAG=true
            if kill -0 "${CURRENT_PHASE_PID:-0}" 2>/dev/null; then
                kill -TERM "$CURRENT_PHASE_PID"
            fi
            ;;
        # Both modes
        status)
            local status_line="Phase: ${CURRENT_PHASE:-init}  Step: $(grep '^step=' "${LIVE_UI_STATE_FILE:-/dev/null}" 2>/dev/null | cut -d= -f2-)  Elapsed: $(fmt_elapsed_compact "$(( $(date +%s) - ${LIVE_UI_START_TS:-$(date +%s)} ))")"
            if [ "$mode" = "mid-run" ] && [ "$LIVE_UI_ACTIVE" = "true" ]; then
                draw_help_overlay_text "$status_line"
            else
                printf "  %s\n" "$status_line" >&2
            fi
            ;;
        flags)
            if [ "$mode" = "mid-run" ] && [ "$LIVE_UI_ACTIVE" = "true" ]; then
                local flags_line="skip-memory:${SKIP_MEMORY:-false}  skip-tests:${SKIP_TESTS:-false}  dry-run:${DRY_RUN:-false}  provider:${AI_PROVIDER:-cursor}"
                draw_help_overlay_text "$flags_line"
            else
                _bv_show_config
            fi
            ;;
        help)
            if [ "$mode" = "mid-run" ]; then
                draw_help_overlay_text "/skip · /report · /abort · /status · /flags · /help"
            else
                printf "  Commands: /run /quit /skip-memory /skip-tests /dry-run /verbose /yolo /sidebar\n" >&2
                printf "            /ai-provider <n> /ai-model <n> /scheme <n> /project <p>\n" >&2
                printf "            /status /flags /help\n" >&2
            fi
            ;;
        '')
            ;;  # empty input, ignore
        *)
            printf "  Unknown command: /%s. Type /help.\n" "$cmd" >&2
            ;;
    esac
    return 0
}

_bv_readline() {
    [ "$LIVE_UI_ACTIVE" = "true" ] || return 1
    # Signal daemon to pause
    local tmp; tmp=$(mktemp "${LIVE_UI_STATE_FILE}.XXXXXX")
    grep -v '^command_mode=' "$LIVE_UI_STATE_FILE" 2>/dev/null > "$tmp" || true
    printf "command_mode=1\n" >> "$tmp"
    mv "$tmp" "$LIVE_UI_STATE_FILE"

    local buf=""
    _render() {
        local width; width=$(tput cols 2>/dev/null || echo 80)
        local display="/ ${buf}▋"
        tput sc >&2
        printf "\e[%s;1H\e[2K\e[1m%s\e[0m" "$LIVE_UI_HEIGHT" "$display" >&2
        tput rc >&2
    }
    _render

    local char rc=0
    while true; do
        char=$(dd if=/dev/stdin bs=1 count=1 2>/dev/null) || break
        case "$char" in
            $'\n'|$'\r') break ;;
            $'\x7f'|$'\x08') [ ${#buf} -gt 0 ] && buf="${buf%?}"; _render ;;
            $'\x1b') buf=""; rc=1; break ;;
            *) buf+="$char"; _render ;;
        esac
    done

    # Clear command_mode
    local tmp2; tmp2=$(mktemp "${LIVE_UI_STATE_FILE}.XXXXXX")
    grep -v '^command_mode=' "$LIVE_UI_STATE_FILE" 2>/dev/null > "$tmp2" || true
    mv "$tmp2" "$LIVE_UI_STATE_FILE"

    printf '%s' "$buf"
    return $rc
}

draw_bottom_bar() {
    [ "$LIVE_UI_ACTIVE" = "true" ] || return 0
    local op="" step="" started_at="$LIVE_UI_START_TS" frame="${DAEMON_FRAME:-0}"
    if [ -f "${LIVE_UI_STATE_FILE:-}" ]; then
        op=$(grep '^op=' "$LIVE_UI_STATE_FILE" 2>/dev/null | cut -d= -f2-)
        step=$(grep '^step=' "$LIVE_UI_STATE_FILE" 2>/dev/null | cut -d= -f2-)
        local sa; sa=$(grep '^started_at=' "$LIVE_UI_STATE_FILE" 2>/dev/null | cut -d= -f2-)
        [ -n "$sa" ] && started_at=$sa
    fi

    local now; now=$(date +%s)
    local elapsed=$(( now - ${started_at:-now} ))
    local spinner; spinner=$(get_spinner_frame "$frame")
    local elapsed_str; elapsed_str=$(fmt_elapsed_compact "$elapsed")
    local width; width=$(tput cols 2>/dev/null || echo 80)

    # Left zone: shortcut badges (Terminal.Gui Shortcut pattern)
    local b_s b_r b_h
    if has_unicode && [ -t 2 ]; then
        b_s="$(printf '\e[7m s \e[0m')"
        b_r="$(printf '\e[7m r \e[0m')"
        b_h="$(printf '\e[7m ? \e[0m')"
        local left_zone="${b_s} Skip · ${b_r} Report · ${b_h} Help"
    else
        local left_zone=""
    fi

    # Right zone: spinner · phase step · elapsed
    local right_zone="${spinner} ${op}"
    [ -n "$step" ] && right_zone+=" · ${step}"
    right_zone+=" · ${elapsed_str}"

    # Width-aware padding (strip ANSI before measuring)
    local left_v right_v
    left_v=$(_bv_strip_ansi "$left_zone")
    right_v=$(_bv_strip_ansi "$right_zone")
    local pad=$(( width - ${#left_v} - ${#right_v} ))
    (( pad < 1 )) && pad=1

    tput sc >&2
    printf "\e[%s;1H\e[2K\e[2m%s\e[0m%*s\e[2m%s\e[0m" \
        "$LIVE_UI_HEIGHT" "$left_zone" "$pad" "" "$right_zone" >&2
    tput rc >&2
}

draw_help_overlay() {
    [ "$LIVE_UI_ACTIVE" = "true" ] || return 0
    local width; width=$(tput cols 2>/dev/null || echo 80)
    local msg=" s  Skip Phase  ·  r  Skip to Report  ·  ?  Help  ·  Ctrl+C  Abort"
    local truncated="${msg:0:$((width - 1))}"
    printf "\e[s\e[%s;1H\e[2K\e[7m%s\e[0m\e[u" "$LIVE_UI_HEIGHT" "$truncated" >&2
}

show_pipeline_summary() {
    local status="$1" session="$2" elapsed="$3" memory="${4:-}"
    local title
    [ "$status" = "passed" ] && title="Pipeline Complete" || title="Pipeline Failed"
    show_phase_divider "$title" "$elapsed"
    shift 4
    if [ -t 2 ] && [ -z "${NO_COLOR:-}" ]; then
        for row in "$@"; do
            local name="${row%%:*}" rest="${row#*:}"
            local pstatus="${rest%%:*}" detail="${rest##*:}"
            case "$pstatus" in
                passed)  printf "\e[32m✓\e[0m  %-12s %s\n" "$name" "$pstatus" >&2 ;;
                failed)  printf "\e[31m✗\e[0m  %-12s %-10s %s\n" "$name" "$pstatus" "$detail" >&2 ;;
                skipped) printf "\e[2m─  %-12s %s\e[0m\n" "$name" "$pstatus" >&2 ;;
            esac
        done
    else
        for row in "$@"; do
            local name="${row%%:*}" rest="${row#*:}"
            local pstatus="${rest%%:*}" detail="${rest##*:}"
            case "$pstatus" in
                passed)  printf "+  %-12s %s\n" "$name" "$pstatus" >&2 ;;
                failed)  printf "x  %-12s %-10s %s\n" "$name" "$pstatus" "$detail" >&2 ;;
                skipped) printf -- "-  %-12s %s\n" "$name" "$pstatus" >&2 ;;
            esac
        done
    fi
    printf "   %-12s %s\n" "Session" "$session" >&2
    [ -n "$memory" ] && printf "   %-12s %s\n" "Memory" "$memory" >&2
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

    if [ "$LIVE_UI_ACTIVE" = "true" ]; then
        update_live_op "${1:-Working}"
        return 0
    fi

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


# ─────────────────────────────────────────────────────────────────────────────
# Sidebar Mode (persistent top status bar)
# ─────────────────────────────────────────────────────────────────────────────
# These functions implement a persistent header that stays fixed at the top
# of the terminal while all other output scrolls below. Uses ANSI scroll regions.
#
# Expected globals (define in calling script):
#   SIDEBAR_MODE         - "true" to enable sidebar
#   SIDEBAR_MODE_ACTIVE  - set by enable_sidebar_mode()
#   SIDEBAR_DAEMON_PID   - set by start_sidebar_daemon()
#   SIDEBAR_STAGE        - current stage string displayed in header
#   PLAN_FILES           - array of plan files (optional)
#   CURRENT_PLAN_INDEX   - index into PLAN_FILES (optional)
#   PLAN_FILE            - single plan file path (optional)
#   CURRENT_ATTEMPT      - current attempt counter
#   MAX_REPAIR_ATTEMPTS  - max attempts
#   AI_PROVIDER          - AI provider name
#   JSON_OUTPUT          - "true" disables sidebar
# ─────────────────────────────────────────────────────────────────────────────

# Enable sidebar mode: draws a persistent header at the top of the terminal
# using ANSI scroll regions. Lines 1-2 are reserved for the header;
# all other output scrolls below.
enable_sidebar_mode()  { enable_live_ui "$@"; }

# Disable sidebar mode: restores normal scrolling
disable_sidebar_mode() { disable_live_ui "$@"; }

# Draw the sidebar header on lines 1-2
draw_sidebar_header() {
    if [ "${SIDEBAR_MODE_ACTIVE:-false}" != "true" ]; then
        return 0
    fi

    local width
    width=$(get_terminal_width 2>/dev/null || echo 80)
    local height
    height=$(get_terminal_height 2>/dev/null || echo 24)

    # Get colors from theme system
    local primary muted accent reset
    if type get_color &>/dev/null; then
        primary=$(get_color "primary")
        muted=$(get_color "muted")
        accent=$(get_color "accent")
        reset=$(get_color "reset")
    else
        primary="${CYAN:-\e[36m}"
        muted="${BLUE:-\e[34m}"
        accent="${GREEN:-\e[32m}"
        reset="${NC:-\e[0m}"
    fi

    # Build info strings
    local stage="${SIDEBAR_STAGE:-Ready}"
    local plan_info=""
    local plan_count=0
    if declare -p PLAN_FILES 2>/dev/null | grep -q 'declare -a'; then
        plan_count=${#PLAN_FILES[@]}
    fi
    if [ "$plan_count" -gt 0 ] && [ "${CURRENT_PLAN_INDEX:-0}" -lt "$plan_count" ]; then
        plan_info="Plan $((CURRENT_PLAN_INDEX + 1))/${plan_count}: $(basename "${PLAN_FILES[$CURRENT_PLAN_INDEX]}")"
    elif [ -n "${PLAN_FILE:-}" ]; then
        plan_info="$(basename "$PLAN_FILE")"
    fi

    local attempt_info="Attempt ${CURRENT_ATTEMPT:-0}/${MAX_REPAIR_ATTEMPTS:-3}"
    local provider="${AI_PROVIDER:-copilot}"

    # ── Line 1: Title bar ─────────────────────────────────────────────────────
    local title=" ${SIDEBAR_TITLE:-BuildAgent} "
    local title_len=${#title}
    local fill_len=$((width - title_len))
    if [ "$fill_len" -lt 0 ]; then fill_len=0; fi
    printf "\e[1;1H\e[2K%s%s%s%*s%s\n" "$accent" "$title" "$reset" "$fill_len" "" "$reset" >&2

    # ── Line 2: Status row ────────────────────────────────────────────────────
    local left=" ${stage} "
    local mid=" ${plan_info:-${attempt_info}} "
    local right=" ${provider} "

    # Truncate if too wide for terminal
    local content_width=$((width - 2))
    local total_len=$(( ${#left} + ${#mid} + ${#right} ))
    if [ "$total_len" -gt "$content_width" ]; then
        mid=" ${attempt_info} "
        total_len=$(( ${#left} + ${#mid} + ${#right} ))
        if [ "$total_len" -gt "$content_width" ]; then
            mid=""
        fi
    fi

    local line2=""
    if [ -n "$mid" ]; then
        line2="${left}│${mid}│${right}"
    else
        line2="${left}│${right}"
    fi
    local line2_len=${#line2}
    local pad2=$((width - line2_len))
    if [ "$pad2" -lt 0 ]; then pad2=0; fi

    printf "\e[2;1H\e[2K%s%s%s%*s%s\n" "$primary" "$line2" "$reset" "$pad2" "" "$reset" >&2

    # Return cursor to scroll region
    printf "\e[3;1H" >&2
}

# Update sidebar stage and immediately redraw
update_sidebar_stage() {
    local phase="${1:-}" state="${2:-active}"
    update_live_op "$phase"
    draw_phase_tracker "init:done,${phase,,}:${state},test:pending,complete:pending"
}

# Background daemon that periodically refreshes the sidebar header
start_sidebar_daemon() { : ; }

stop_sidebar_daemon()  { stop_live_daemon "$@"; }

# ─────────────────────────────────────────────────────────────────────────────
# Split Pane Layout (BuildVerify CLI UI Layout Review)
# ─────────────────────────────────────────────────────────────────────────────

enable_split_layout() {
    [ "$SPLIT_LAYOUT_ACTIVE" != "true" ] || return 0
    [ -t 2 ] || { SPLIT_LAYOUT_ACTIVE=false; return 0; }
    [ -z "${CI:-}" ] || { SPLIT_LAYOUT_ACTIVE=false; return 0; }
    [ "${TERM:-}" != "dumb" ] || { SPLIT_LAYOUT_ACTIVE=false; return 0; }

    local height width
    height=$(tput lines 2>/dev/null || echo 0)
    width=$(tput cols 2>/dev/null || echo 80)
    (( height >= 12 )) || { SPLIT_LAYOUT_ACTIVE=false; return 0; }
    (( width >= 60 )) || { SPLIT_LAYOUT_ACTIVE=false; return 0; }

    # Pre-compute all split layout state BEFORE forking the daemon
    STATUS_BAR_ROW=$((height - 1))
    PROMPT_ROW=$height
    INTERACTION_PANE_VISIBLE=true
    INTERACTION_PANE_WIDTH=$((width / 2))
    [ "$INTERACTION_PANE_WIDTH" -lt 30 ] && INTERACTION_PANE_WIDTH=30
    [ "$INTERACTION_PANE_WIDTH" -gt 60 ] && INTERACTION_PANE_WIDTH=60

    INTERACTION_BUFFER_FILE=$(mktemp "/tmp/buildverify_interact_XXXXXX")
    INTERACTION_BUFFER_MAX_LINES=$((height - 4))  # rows 3 to height-2

    # Export so the daemon (forked by enable_live_ui) inherits these values
    export SPLIT_LAYOUT_ACTIVE=true
    export STATUS_BAR_ROW PROMPT_ROW INTERACTION_PANE_VISIBLE INTERACTION_PANE_WIDTH
    export INTERACTION_BUFFER_FILE INTERACTION_BUFFER_MAX_LINES

    # Enable base live UI (forks daemon — daemon will see exported vars)
    enable_live_ui
    [ "$LIVE_UI_ACTIVE" = "true" ] || {
        SPLIT_LAYOUT_ACTIVE=false
        unset SPLIT_LAYOUT_ACTIVE
        return 0
    }

    # Override LIVE_UI_HEIGHT in parent only (disable_live_ui cleanup uses this)
    LIVE_UI_HEIGHT=$STATUS_BAR_ROW

    # Recalculate scroll region to end at N-2 instead of N-1
    printf "\e[3;%sr" "$((height - 2))" >&2

    # Seed initial content and draw
    printf "[AGENT] BuildVerify ready.\n" > "$INTERACTION_BUFFER_FILE"

    # Initial draw of all split layout elements
    draw_interaction_pane
    draw_status_bar
    draw_prompt_line
}

disable_split_layout() {
    [ "$SPLIT_LAYOUT_ACTIVE" = "true" ] || { disable_live_ui; return 0; }
    SPLIT_LAYOUT_ACTIVE=false

    # Clear interaction pane area (rows 3 to STATUS_BAR_ROW-1)
    local i
    for ((i=3; i<STATUS_BAR_ROW; i++)); do
        printf "\e[%s;1H\e[2K" "$i" >&2
    done

    # Clean up buffer
    [ -n "$INTERACTION_BUFFER_FILE" ] && rm -f "$INTERACTION_BUFFER_FILE"
    INTERACTION_BUFFER_FILE=""

    disable_live_ui

    # disable_live_ui clears rows 1, 2, and LIVE_UI_HEIGHT (STATUS_BAR_ROW)
    # and leaves cursor at row 1. Clear the prompt row and move to bottom
    # so the shell prompt appears cleanly without the '%' artifact.
    local height; height=$(tput lines 2>/dev/null || echo 24)
    printf "\e[%s;1H\e[2K\n" "$height" >&2
}

draw_interaction_pane() {
    [ "$SPLIT_LAYOUT_ACTIVE" = "true" ] || return 0
    [ "$INTERACTION_PANE_VISIBLE" = "true" ] || return 0
    [ -f "$INTERACTION_BUFFER_FILE" ] || return 0

    local width height
    width=$(tput cols 2>/dev/null || echo 80)
    height=$(tput lines 2>/dev/null || echo 24)

    # Recalculate pane width on each draw to handle resize
    INTERACTION_PANE_WIDTH=$((width / 2))
    [ "$INTERACTION_PANE_WIDTH" -lt 30 ] && INTERACTION_PANE_WIDTH=30
    [ "$INTERACTION_PANE_WIDTH" -gt 60 ] && INTERACTION_PANE_WIDTH=60

    local max_lines=$((height - 4))  # rows 3 to height-2
    local border_char="│"
    has_unicode || border_char="|"

    # Read last N lines from buffer
    local lines=()
    if [ -f "$INTERACTION_BUFFER_FILE" ]; then
        mapfile -t lines < <(tail -n "$max_lines" "$INTERACTION_BUFFER_FILE" 2>/dev/null)
    fi

    # Save cursor
    tput sc >&2

    local i row
    row=3
    for ((i=0; i<max_lines; i++)); do
        local line="${lines[$i]:-}"
        local display_width=$((INTERACTION_PANE_WIDTH - 1))

        # Strip ANSI for length calculation, then pad
        local visible_line
        visible_line=$(_bv_strip_ansi "$line")
        local line_len=${#visible_line}
        local pad=$((display_width - line_len))
        ((pad < 0)) && pad=0

        # Position cursor, draw line + border
        printf "\e[%s;1H\e[2K" "$row" >&2
        if [ -n "$line" ]; then
            printf "%s%*s%s" "$line" "$pad" "" "$border_char" >&2
        else
            printf "%*s%s" "$display_width" "" "$border_char" >&2
        fi

        ((row++))
    done

    # Restore cursor
    tput rc >&2
}

interaction_log() {
    local voice="${1:-neutral}"
    local text="$2"

    # If split layout is not active, just print to stderr
    if [ "$SPLIT_LAYOUT_ACTIVE" != "true" ]; then
        printf "%s\n" "$text" >&2
        return 0
    fi

    local prefix=""
    local formatted=""
    case "$voice" in
        user)
            prefix="> "
            formatted=$(apply_block_color "user" "${prefix}${text}")
            ;;
        agent)
            prefix="[AGENT] "
            formatted=$(apply_block_color "agent" "${prefix}${text}")
            ;;
        shell)
            prefix="  "
            formatted=$(apply_block_color "shell" "${prefix}${text}")
            ;;
        error)
            prefix="✕ "
            formatted=$(apply_block_color "error" "${prefix}${text}")
            ;;
        warning)
            prefix="⚠ "
            formatted=$(apply_block_color "warning" "${prefix}${text}")
            ;;
        *)
            formatted="$text"
            ;;
    esac

    # Append to buffer
    printf "%s\n" "$formatted" >> "$INTERACTION_BUFFER_FILE"

    # Keep buffer from growing unbounded (keep last 500 lines)
    local buf_lines
    buf_lines=$(wc -l < "$INTERACTION_BUFFER_FILE" 2>/dev/null || echo 0)
    if [ "$buf_lines" -gt 500 ]; then
        local tmp; tmp=$(mktemp "${INTERACTION_BUFFER_FILE}.XXXXXX")
        tail -n 400 "$INTERACTION_BUFFER_FILE" > "$tmp"
        mv "$tmp" "$INTERACTION_BUFFER_FILE"
    fi

    # Redraw immediately
    draw_interaction_pane
}

draw_status_bar() {
    [ "$LIVE_UI_ACTIVE" = "true" ] || return 0

    # If split layout not active, fall back to draw_bottom_bar
    if [ "$SPLIT_LAYOUT_ACTIVE" != "true" ]; then
        draw_bottom_bar
        return 0
    fi

    local op="" step="" started_at="$LIVE_UI_START_TS" frame="${DAEMON_FRAME:-0}"
    local agent_st="$AGENT_STATE"
    if [ -f "${LIVE_UI_STATE_FILE:-}" ]; then
        op=$(grep '^op=' "$LIVE_UI_STATE_FILE" 2>/dev/null | cut -d= -f2-)
        step=$(grep '^step=' "$LIVE_UI_STATE_FILE" 2>/dev/null | cut -d= -f2-)
        local sa; sa=$(grep '^started_at=' "$LIVE_UI_STATE_FILE" 2>/dev/null | cut -d= -f2-)
        [ -n "$sa" ] && started_at=$sa
        local ast; ast=$(grep '^agent_state=' "$LIVE_UI_STATE_FILE" 2>/dev/null | cut -d= -f2-)
        [ -n "$ast" ] && agent_st="$ast"
    fi

    local now; now=$(date +%s)
    local elapsed=$(( now - ${started_at:-now} ))
    local spinner; spinner=$(get_spinner_frame "$frame")
    local elapsed_str; elapsed_str=$(fmt_elapsed_compact "$elapsed")
    local width; width=$(tput cols 2>/dev/null || echo 80)

    # Agent indicator symbol
    local agent_sym="○"
    case "$agent_st" in
        thinking) agent_sym="◐" ;;
        acting)   agent_sym="●" ;;
    esac
    has_unicode || agent_sym="*"

    # Foundation (left, muted)
    local foundation="Foundation Build Verify"

    # State UI (dynamic)
    local state_ui="${op:-idle}"
    [ -n "$step" ] && state_ui+=" · ${step}"

    # Problem count (placeholder — integrated from build state)
    local problems="0 errors"

    # Agent indicator
    local agent_ind="${agent_sym} agent ${agent_st}"

    # Spinner + elapsed (paired)
    local time_pair="${spinner} ${elapsed_str}"

    # Assemble right zone
    local right_zone="${state_ui} │ ${problems} │ ${agent_ind} │ ${time_pair}"

    # Measure and pad
    local left_len=${#foundation}
    local right_len=${#right_zone}
    local pad=$(( width - left_len - right_len - 2 ))
    (( pad < 1 )) && pad=1

    # Draw on status bar row
    tput sc >&2
    printf "\e[%s;1H\e[2K\e[2m%s\e[0m %*s %s" \
        "$STATUS_BAR_ROW" "$foundation" "$pad" "" "$right_zone" >&2
    tput rc >&2
}

draw_prompt_line() {
    [ "$SPLIT_LAYOUT_ACTIVE" = "true" ] || return 0
    tput sc >&2
    printf "\e[%s;1H\e[2K\e[1m> \e[0m_" "$PROMPT_ROW" >&2
    tput rc >&2
}

toggle_interaction_pane() {
    [ "$SPLIT_LAYOUT_ACTIVE" = "true" ] || return 0
    if [ "$INTERACTION_PANE_VISIBLE" = "true" ]; then
        INTERACTION_PANE_VISIBLE=false
        # Clear left pane area so build output can use full width
        local i
        tput sc >&2
        for ((i=3; i<STATUS_BAR_ROW; i++)); do
            printf "\e[%s;1H\e[2K" "$i" >&2
        done
        tput rc >&2
    else
        INTERACTION_PANE_VISIBLE=true
        draw_interaction_pane
    fi
}

set_agent_indicator() {
    local state="$1"
    case "$state" in
        idle|thinking|acting) ;;
        *) state="idle" ;;
    esac
    AGENT_STATE="$state"
    # Write to state file so daemon can read it (daemon is a forked subshell)
    if [ -n "${LIVE_UI_STATE_FILE:-}" ] && [ -f "$LIVE_UI_STATE_FILE" ]; then
        local tmp; tmp=$(mktemp "${LIVE_UI_STATE_FILE}.XXXXXX")
        grep -v '^agent_state=' "$LIVE_UI_STATE_FILE" 2>/dev/null > "$tmp" || true
        printf "agent_state=%s\n" "$state" >> "$tmp"
        mv "$tmp" "$LIVE_UI_STATE_FILE"
    fi
    if [ "$SPLIT_LAYOUT_ACTIVE" = "true" ]; then
        draw_status_bar
    fi
}

update_agent_indicator() {
    set_agent_indicator "$1"
}
