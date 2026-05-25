#!/usr/bin/env bash
# Library: ui_themes.sh
# Purpose: Terminal theme system with capability detection and color management
# Dependencies: tput (optional - graceful degradation if unavailable)
#
# Functions:
#   detect_terminal_capabilities()  - Check for true color, unicode, terminal width
#   select_theme(name)              - Load dark/light theme with RGB color codes
#   get_color(name)                 - Return themed color escape codes
#   get_icon(name)                  - Return themed icon (unicode or ASCII fallback)
#   is_fancy_ui_enabled()           - Check if fancy UI should be used
#
# Themes:
#   - foundation_dark (default): Dark background with vibrant accent colors
#   - foundation_light: Light background with adjusted accent colors
#
# Environment Variables:
#   BUILDAGENT_FANCY_UI      - Set to "true" to enable fancy UI (default: false)
#   BUILDAGENT_THEME         - Theme name: dark, light (default: dark)
#   NO_COLOR                 - If set, disables all colors (respects standard)
#   TERM                     - Terminal type for capability detection
#   COLORTERM                - Color terminal capability indicator
#
# Usage:
#   source ui_themes.sh
#   detect_terminal_capabilities
#   select_theme "dark"
#   echo -e "$(get_color 'success')Success!$(get_color 'reset')"

set -euo pipefail

# Verify bash is running
if [ -z "${BASH_VERSION:-}" ]; then
    echo "Error: This library requires bash" >&2
    return 1 2>/dev/null || exit 1
fi

# ─────────────────────────────────────────────────────────────────────────────
# Terminal Capability Detection
# ─────────────────────────────────────────────────────────────────────────────

# Internal state
_TERMINAL_TRUE_COLOR="false"
_TERMINAL_256_COLOR="false"
_TERMINAL_UNICODE="true"
_TERMINAL_WIDTH=80
_TERMINAL_HEIGHT=24
_TPUT_AVAILABLE="false"
_CAPABILITIES_DETECTED="false"

# Current theme colors (set by select_theme)
declare -A THEME_COLORS=()
declare -A THEME_ICONS=()

# Detect terminal capabilities
# Sets internal state for color support, unicode, and dimensions
detect_terminal_capabilities() {
    if [ "$_CAPABILITIES_DETECTED" = "true" ]; then
        return 0
    fi

    # Check for NO_COLOR environment variable (https://no-color.org/)
    if [ -n "${NO_COLOR:-}" ]; then
        _TERMINAL_TRUE_COLOR="false"
        _TERMINAL_256_COLOR="false"
        _CAPABILITIES_DETECTED="true"
        return 0
    fi

    # Check tput availability
    if command -v tput &>/dev/null; then
        _TPUT_AVAILABLE="true"
    fi

    # Detect true color support
    # COLORTERM=truecolor or COLORTERM=24bit indicates true color support
    if [ "${COLORTERM:-}" = "truecolor" ] || [ "${COLORTERM:-}" = "24bit" ]; then
        _TERMINAL_TRUE_COLOR="true"
        _TERMINAL_256_COLOR="true"
    # Some terminals set specific TERM values for true color
    elif [[ "${TERM:-}" == *"truecolor"* ]] || [[ "${TERM:-}" == *"24bit"* ]]; then
        _TERMINAL_TRUE_COLOR="true"
        _TERMINAL_256_COLOR="true"
    # Check for 256 color support
    elif [[ "${TERM:-}" == *"256color"* ]] || [ "${COLORTERM:-}" = "yes" ]; then
        _TERMINAL_256_COLOR="true"
    # Common terminals with true color support
    elif [[ "${TERM_PROGRAM:-}" == "iTerm.app" ]] || \
         [[ "${TERM_PROGRAM:-}" == "Apple_Terminal" ]] || \
         [[ "${TERM_PROGRAM:-}" == "Hyper" ]] || \
         [[ "${TERM_PROGRAM:-}" == "vscode" ]] || \
         [[ "${TERMINAL_EMULATOR:-}" == *"JetBrains"* ]]; then
        _TERMINAL_TRUE_COLOR="true"
        _TERMINAL_256_COLOR="true"
    fi

    # Detect unicode support from locale
    local lang="${LANG:-}"
    local lc_all="${LC_ALL:-}"
    if [[ "$lang" == *"UTF-8"* ]] || [[ "$lang" == *"utf-8"* ]] || \
       [[ "$lc_all" == *"UTF-8"* ]] || [[ "$lc_all" == *"utf-8"* ]]; then
        _TERMINAL_UNICODE="true"
    else
        _TERMINAL_UNICODE="false"
    fi

    # Get terminal dimensions
    if [ "$_TPUT_AVAILABLE" = "true" ]; then
        _TERMINAL_WIDTH=$(tput cols 2>/dev/null || echo "80")
        _TERMINAL_HEIGHT=$(tput lines 2>/dev/null || echo "24")
    elif [ -n "${COLUMNS:-}" ]; then
        _TERMINAL_WIDTH="$COLUMNS"
    fi

    _CAPABILITIES_DETECTED="true"
}

# Check if fancy UI should be enabled
# Returns: 0 if fancy UI should be used, 1 if not
is_fancy_ui_enabled() {
    local fancy_ui="${BUILDAGENT_FANCY_UI:-false}"

    # Explicitly disabled
    if [ "$fancy_ui" = "false" ] || [ "$fancy_ui" = "0" ]; then
        return 1
    fi

    # If explicitly enabled, bypass most checks (user knows what they want)
    local explicitly_enabled=false
    if [ "$fancy_ui" = "true" ] || [ "$fancy_ui" = "1" ]; then
        explicitly_enabled=true
    fi

    # Check for non-interactive terminal (stderr must be TTY since we output to >&2)
    # Skip this check if explicitly enabled
    if [ "$explicitly_enabled" = "false" ] && [ ! -t 2 ]; then
        return 1
    fi

    # Check for CI/CD environments
    # Skip this check if explicitly enabled
    if [ "$explicitly_enabled" = "false" ] && \
       ([ "${CI:-}" = "true" ] || \
        [ -n "${GITHUB_ACTIONS:-}" ] || \
        [ -n "${JENKINS_HOME:-}" ] || \
        [ -n "${GITLAB_CI:-}" ] || \
        [ -n "${CIRCLECI:-}" ] || \
        [ -n "${TRAVIS:-}" ] || \
        [ -n "${BUILDKITE:-}" ]); then
        return 1
    fi

    # Detect terminal capabilities if not done
    detect_terminal_capabilities

    # Disable fancy UI if terminal is too narrow
    # Skip this check if explicitly enabled (user can deal with it)
    if [ "$explicitly_enabled" = "false" ] && [ "$_TERMINAL_WIDTH" -lt 40 ]; then
        return 1
    fi

    # Disable if no unicode support and fancy UI requires it
    # Skip this check if explicitly enabled (will use ASCII fallbacks)
    if [ "$explicitly_enabled" = "false" ] && [ "$_TERMINAL_UNICODE" = "false" ]; then
        return 1
    fi

    return 0
}

# ─────────────────────────────────────────────────────────────────────────────
# Color Definitions
# ─────────────────────────────────────────────────────────────────────────────

# RGB to ANSI 256 color approximation
# Arguments: R G B (0-255 each)
# Outputs: ANSI 256 color code
_rgb_to_256() {
    local r=$1 g=$2 b=$3

    # Check for grayscale
    if [ "$r" -eq "$g" ] && [ "$g" -eq "$b" ]; then
        if [ "$r" -lt 8 ]; then
            echo "16"
        elif [ "$r" -gt 248 ]; then
            echo "231"
        else
            echo "$((((r - 8) / 247) * 24 + 232))"
        fi
        return
    fi

    # Convert to 6x6x6 color cube
    local r6=$((r * 6 / 256))
    local g6=$((g * 6 / 256))
    local b6=$((b * 6 / 256))
    echo "$((16 + 36 * r6 + 6 * g6 + b6))"
}

# Generate color escape sequence
# Arguments: R G B (0-255 each), type (fg or bg)
# Outputs: ANSI escape sequence
_make_color() {
    local r=$1 g=$2 b=$3
    local type="${4:-fg}"

    if [ "$_TERMINAL_TRUE_COLOR" = "true" ]; then
        if [ "$type" = "fg" ]; then
            printf '\033[38;2;%d;%d;%dm' "$r" "$g" "$b"
        else
            printf '\033[48;2;%d;%d;%dm' "$r" "$g" "$b"
        fi
    elif [ "$_TERMINAL_256_COLOR" = "true" ]; then
        local color256
        color256=$(_rgb_to_256 "$r" "$g" "$b")
        if [ "$type" = "fg" ]; then
            printf '\033[38;5;%dm' "$color256"
        else
            printf '\033[48;5;%dm' "$color256"
        fi
    else
        # Basic ANSI fallback
        printf ''
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Theme Definitions
# ─────────────────────────────────────────────────────────────────────────────

# Foundation Dark Theme
# Inspired by modern terminal themes with a focus on readability
_init_theme_dark() {
    # Reset
    THEME_COLORS[reset]='\033[0m'
    THEME_COLORS[bold]='\033[1m'
    THEME_COLORS[dim]='\033[2m'
    THEME_COLORS[italic]='\033[3m'
    THEME_COLORS[underline]='\033[4m'

    # Primary colors - Foundation Dark palette
    THEME_COLORS[primary]=$(_make_color 137 180 250)      # Blue (#89B4FA)
    THEME_COLORS[secondary]=$(_make_color 180 190 254)    # Lavender (#B4BEFE)
    THEME_COLORS[accent]=$(_make_color 203 166 247)       # Mauve (#CBA6F7)

    # Status colors
    THEME_COLORS[success]=$(_make_color 166 227 161)      # Green (#A6E3A1)
    THEME_COLORS[warning]=$(_make_color 249 226 175)      # Yellow (#F9E2AF)
    THEME_COLORS[error]=$(_make_color 243 139 168)        # Red (#F38BA8)
    THEME_COLORS[info]=$(_make_color 137 180 250)         # Blue (#89B4FA)

    # UI element colors
    THEME_COLORS[muted]=$(_make_color 147 153 178)        # Overlay1 (#939AB7)
    THEME_COLORS[subtle]=$(_make_color 108 112 134)       # Overlay0 (#6C7086)
    THEME_COLORS[border]=$(_make_color 88 91 112)         # Surface1 (#585B70)

    # Special colors
    THEME_COLORS[ai]=$(_make_color 203 166 247)           # Mauve for AI (#CBA6F7)
    THEME_COLORS[build]=$(_make_color 137 180 250)        # Blue for build (#89B4FA)
    THEME_COLORS[test]=$(_make_color 148 226 213)         # Teal for test (#94E2D5)
    THEME_COLORS[section]=$(_make_color 180 190 254)      # Lavender for sections (#B4BEFE)

    # Gradient colors (for gradient text effects)
    THEME_COLORS[gradient_start]=$(_make_color 137 180 250)  # Blue
    THEME_COLORS[gradient_mid]=$(_make_color 203 166 247)    # Mauve
    THEME_COLORS[gradient_end]=$(_make_color 243 139 168)    # Pink

    # Basic ANSI fallbacks (always available)
    THEME_COLORS[red]='\033[0;31m'
    THEME_COLORS[green]='\033[0;32m'
    THEME_COLORS[yellow]='\033[1;33m'
    THEME_COLORS[blue]='\033[0;34m'
    THEME_COLORS[magenta]='\033[0;35m'
    THEME_COLORS[cyan]='\033[0;36m'
    THEME_COLORS[white]='\033[0;37m'
}

# Foundation Light Theme
# Adjusted colors for light backgrounds
_init_theme_light() {
    # Reset and text styles (same as dark)
    THEME_COLORS[reset]='\033[0m'
    THEME_COLORS[bold]='\033[1m'
    THEME_COLORS[dim]='\033[2m'
    THEME_COLORS[italic]='\033[3m'
    THEME_COLORS[underline]='\033[4m'

    # Primary colors - Foundation Light palette (Latte)
    THEME_COLORS[primary]=$(_make_color 30 102 245)       # Blue (#1E66F5)
    THEME_COLORS[secondary]=$(_make_color 114 135 253)    # Lavender (#7287FD)
    THEME_COLORS[accent]=$(_make_color 136 57 239)        # Mauve (#8839EF)

    # Status colors
    THEME_COLORS[success]=$(_make_color 64 160 43)        # Green (#40A02B)
    THEME_COLORS[warning]=$(_make_color 223 142 29)       # Yellow (#DF8E1D)
    THEME_COLORS[error]=$(_make_color 210 15 57)          # Red (#D20F39)
    THEME_COLORS[info]=$(_make_color 30 102 245)          # Blue (#1E66F5)

    # UI element colors
    THEME_COLORS[muted]=$(_make_color 108 111 133)        # Overlay1 (#6C6F85)
    THEME_COLORS[subtle]=$(_make_color 124 127 147)       # Overlay0 (#7C7F93)
    THEME_COLORS[border]=$(_make_color 172 176 190)       # Surface1 (#ACB0BE)

    # Special colors
    THEME_COLORS[ai]=$(_make_color 136 57 239)            # Mauve for AI (#8839EF)
    THEME_COLORS[build]=$(_make_color 30 102 245)         # Blue for build (#1E66F5)
    THEME_COLORS[test]=$(_make_color 23 146 153)          # Teal for test (#179299)
    THEME_COLORS[section]=$(_make_color 114 135 253)      # Lavender for sections (#7287FD)

    # Gradient colors
    THEME_COLORS[gradient_start]=$(_make_color 30 102 245)   # Blue
    THEME_COLORS[gradient_mid]=$(_make_color 136 57 239)     # Mauve
    THEME_COLORS[gradient_end]=$(_make_color 210 15 57)      # Pink

    # Basic ANSI fallbacks
    THEME_COLORS[red]='\033[0;31m'
    THEME_COLORS[green]='\033[0;32m'
    THEME_COLORS[yellow]='\033[1;33m'
    THEME_COLORS[blue]='\033[0;34m'
    THEME_COLORS[magenta]='\033[0;35m'
    THEME_COLORS[cyan]='\033[0;36m'
    THEME_COLORS[white]='\033[0;37m'
}

# Initialize icons based on unicode support
_init_icons() {
    if [ "$_TERMINAL_UNICODE" = "true" ]; then
        # Unicode icons
        THEME_ICONS[info]="ℹ"
        THEME_ICONS[success]="✓"
        THEME_ICONS[warning]="⚠"
        THEME_ICONS[error]="✗"
        THEME_ICONS[section]="▶"
        THEME_ICONS[build]="🔨"
        THEME_ICONS[ai]="🤖"
        THEME_ICONS[test]="🧪"
        THEME_ICONS[debug]="🐛"
        THEME_ICONS[tip]="💡"
        THEME_ICONS[arrow_right]="→"
        THEME_ICONS[arrow_down]="↓"
        THEME_ICONS[check]="✓"
        THEME_ICONS[cross]="✗"
        THEME_ICONS[star]="★"
        THEME_ICONS[rocket]="🚀"
        THEME_ICONS[gear]="⚙"
        THEME_ICONS[clock]="⏱"
        THEME_ICONS[folder]="📁"
        THEME_ICONS[file]="📄"
        THEME_ICONS[package]="📦"

        # Box drawing characters (rounded corners)
        THEME_ICONS[box_tl]="╭"
        THEME_ICONS[box_tr]="╮"
        THEME_ICONS[box_bl]="╰"
        THEME_ICONS[box_br]="╯"
        THEME_ICONS[box_h]="─"
        THEME_ICONS[box_v]="│"
        THEME_ICONS[box_vr]="├"
        THEME_ICONS[box_vl]="┤"
        THEME_ICONS[box_hd]="┬"
        THEME_ICONS[box_hu]="┴"

        # Progress bar characters
        THEME_ICONS[progress_full]="█"
        THEME_ICONS[progress_empty]="░"
        THEME_ICONS[progress_half]="▒"
    else
        # ASCII fallbacks
        THEME_ICONS[info]="[i]"
        THEME_ICONS[success]="[+]"
        THEME_ICONS[warning]="[!]"
        THEME_ICONS[error]="[x]"
        THEME_ICONS[section]=">"
        THEME_ICONS[build]="[B]"
        THEME_ICONS[ai]="[AI]"
        THEME_ICONS[test]="[T]"
        THEME_ICONS[debug]="[D]"
        THEME_ICONS[tip]="*"
        THEME_ICONS[arrow_right]="->"
        THEME_ICONS[arrow_down]="v"
        THEME_ICONS[check]="[v]"
        THEME_ICONS[cross]="[x]"
        THEME_ICONS[star]="*"
        THEME_ICONS[rocket]=">"
        THEME_ICONS[gear]="@"
        THEME_ICONS[clock]="@"
        THEME_ICONS[folder]="[/]"
        THEME_ICONS[file]="[-]"
        THEME_ICONS[package]="[#]"

        # ASCII box drawing
        THEME_ICONS[box_tl]="+"
        THEME_ICONS[box_tr]="+"
        THEME_ICONS[box_bl]="+"
        THEME_ICONS[box_br]="+"
        THEME_ICONS[box_h]="-"
        THEME_ICONS[box_v]="|"
        THEME_ICONS[box_vr]="+"
        THEME_ICONS[box_vl]="+"
        THEME_ICONS[box_hd]="+"
        THEME_ICONS[box_hu]="+"

        # ASCII progress bar
        THEME_ICONS[progress_full]="#"
        THEME_ICONS[progress_empty]="-"
        THEME_ICONS[progress_half]="="
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Public Functions
# ─────────────────────────────────────────────────────────────────────────────

# Select and initialize a theme
# Arguments:
#   $1 - theme name: dark, light (default: dark)
select_theme() {
    local theme_name="${1:-dark}"

    # Detect capabilities first
    detect_terminal_capabilities

    case "$theme_name" in
        light)
            _init_theme_light
            ;;
        dark|*)
            _init_theme_dark
            ;;
    esac

    # Initialize icons based on unicode support
    _init_icons
}

# Get color escape sequence by name
# Arguments:
#   $1 - color name (primary, success, error, etc.)
# Outputs: Escape sequence to stdout
get_color() {
    local name="$1"

    # Return empty if colors not initialized or fancy UI disabled
    if [ ${#THEME_COLORS[@]} -eq 0 ]; then
        select_theme "${BUILDAGENT_THEME:-dark}"
    fi

    if ! is_fancy_ui_enabled && [ "$name" != "reset" ]; then
        # Return basic ANSI colors for non-fancy mode
        case "$name" in
            success|green) echo -e '\033[0;32m' ;;
            error|red) echo -e '\033[0;31m' ;;
            warning|yellow) echo -e '\033[1;33m' ;;
            info|blue|primary) echo -e '\033[0;34m' ;;
            section|cyan) echo -e '\033[0;36m' ;;
            ai|magenta) echo -e '\033[0;35m' ;;
            reset) echo -e '\033[0m' ;;
            *) echo "" ;;
        esac
        return
    fi

    echo -e "${THEME_COLORS[$name]:-}"
}

# Get icon by name
# Arguments:
#   $1 - icon name
# Outputs: Icon character to stdout
get_icon() {
    local name="$1"

    if [ ${#THEME_ICONS[@]} -eq 0 ]; then
        _init_icons
    fi

    echo "${THEME_ICONS[$name]:-}"
}

# Get terminal width
get_terminal_width() {
    detect_terminal_capabilities
    echo "$_TERMINAL_WIDTH"
}

# Get terminal height
get_terminal_height() {
    detect_terminal_capabilities
    echo "$_TERMINAL_HEIGHT"
}

# Check if true color is supported
has_true_color() {
    detect_terminal_capabilities
    [ "$_TERMINAL_TRUE_COLOR" = "true" ]
}

# Check if unicode is supported
has_unicode() {
    detect_terminal_capabilities
    [ "$_TERMINAL_UNICODE" = "true" ]
}

# Auto-initialize with default theme on source
if [ "${BUILDAGENT_THEME:-}" != "" ]; then
    select_theme "$BUILDAGENT_THEME"
fi
