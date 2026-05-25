#!/usr/bin/env bash
# Library: axe_helpers.sh
# Purpose: AXe UI automation helper library for iOS simulator interactions
# Dependencies: axe (optional - graceful degradation), jq (optional)
#
# AXe is a command-line tool for UI automation on iOS simulators.
# Install: brew tap cameroncooke/axe && brew install axe
#
# Functions:
#   get_axe_path()                     - Resolve AXe binary (env -> bundled -> PATH)
#   is_axe_available()                 - Check if AXe is installed
#   get_axe_version()                  - Get AXe version string
#   is_axe_at_least_version(ver)       - Version comparison
#   axe_describe_ui(uuid)              - Get full view hierarchy JSON
#   axe_tap(uuid, x, y)                - Tap at coordinates
#   axe_tap_element(uuid, id)          - Tap by accessibility ID
#   axe_tap_label(uuid, label)         - Tap by accessibility label
#   axe_swipe(uuid, direction)         - Swipe up/down/left/right
#   axe_type_text(uuid, text)          - Type into active field
#   axe_long_press(uuid, x, y, duration) - Long press gesture
#   axe_hardware_button(uuid, btn)     - home/lock/volumeUp/volumeDown
#   axe_screenshot(uuid, path)         - Capture screenshot via AXe
#   axe_execute(uuid, cmd, args)       - Generic AXe command executor
#
# Environment Variables:
#   XCODEBUILDMCP_AXE_PATH             - Override AXe binary path (highest priority)
#   AXE_PATH                           - Alternative env var for AXe path
#   JSON_OUTPUT                        - Set to "true" for JSON output mode
#   AXE_PRE_DELAY                      - Delay before interaction (ms, default: 0)
#   AXE_POST_DELAY                     - Delay after interaction (ms, default: 0)
#
# Exit Codes:
#   0  - Success
#   1  - General error
#   30 - AXe not installed
#   31 - AXe command failed
#   32 - Element not found
#   33 - Invalid coordinates
#   34 - Invalid direction

set -euo pipefail

# Verify bash is running
if [ -z "${BASH_VERSION:-}" ]; then
    echo "Error: This library requires bash" >&2
    return 1 2>/dev/null || exit 1
fi

# Path resolution
AXE_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AXE_PHASE5_DIR="$(cd "${AXE_LIB_DIR}/.." && pwd)"
AXE_PROJECT_ROOT="${PROJECT_ROOT:-$(cd "${AXE_PHASE5_DIR}/../../../.." && pwd)}"

# Configuration
JSON_OUTPUT="${JSON_OUTPUT:-false}"
AXE_PRE_DELAY="${AXE_PRE_DELAY:-0}"
AXE_POST_DELAY="${AXE_POST_DELAY:-0}"

# Internal state
_AXE_PATH=""
_AXE_AVAILABLE=""
_JQ_AVAILABLE=""

# ─────────────────────────────────────────────────────────────────────────────
# Internal Helpers
# ─────────────────────────────────────────────────────────────────────────────

# Check if jq is available
_axe_check_jq() {
    if [ -z "$_JQ_AVAILABLE" ]; then
        if command -v jq &>/dev/null; then
            _JQ_AVAILABLE="true"
        else
            _JQ_AVAILABLE="false"
        fi
    fi
    [ "$_JQ_AVAILABLE" = "true" ]
}

# Output JSON response
_axe_json_response() {
    local success="$1"
    local message="$2"
    local data="${3:-null}"

    if [ "$JSON_OUTPUT" = "true" ]; then
        if _axe_check_jq; then
            jq -n \
                --argjson success "$success" \
                --arg message "$message" \
                --argjson data "$data" \
                '{success: $success, message: $message, data: $data}'
        else
            echo "{\"success\": $success, \"message\": \"$message\", \"data\": $data}"
        fi
    else
        if [ "$success" = "true" ]; then
            echo "$message"
        else
            echo "Error: $message" >&2
        fi
    fi
}

# Output error response
_axe_error_response() {
    local code="$1"
    local message="$2"
    _axe_json_response "false" "$message" "null"
    return "$code"
}

# Check if file is executable
_is_executable() {
    local path="$1"
    [ -f "$path" ] && [ -x "$path" ]
}

# ─────────────────────────────────────────────────────────────────────────────
# AXe Binary Resolution
# ─────────────────────────────────────────────────────────────────────────────

# Resolve AXe binary path
# Priority: XCODEBUILDMCP_AXE_PATH -> AXE_PATH -> bundled -> PATH
# Outputs: Path to axe binary or empty string
get_axe_path() {
    # Return cached path if available
    if [ -n "$_AXE_PATH" ]; then
        echo "$_AXE_PATH"
        return 0
    fi

    # 1. Check environment variables
    if [ -n "${XCODEBUILDMCP_AXE_PATH:-}" ] && _is_executable "$XCODEBUILDMCP_AXE_PATH"; then
        _AXE_PATH="$XCODEBUILDMCP_AXE_PATH"
        echo "$_AXE_PATH"
        return 0
    fi

    if [ -n "${AXE_PATH:-}" ] && _is_executable "$AXE_PATH"; then
        _AXE_PATH="$AXE_PATH"
        echo "$_AXE_PATH"
        return 0
    fi

    # 2. Check bundled location (relative to XcodeBuildMCP package)
    local bundled_paths=(
        "${AXE_PROJECT_ROOT}/bundled/axe"
        "${AXE_PHASE5_DIR}/bundled/axe"
        "./bundled/axe"
    )

    for bundled_path in "${bundled_paths[@]}"; do
        if _is_executable "$bundled_path"; then
            _AXE_PATH="$bundled_path"
            echo "$_AXE_PATH"
            return 0
        fi
    done

    # 3. Check PATH
    local path_binary
    path_binary=$(command -v axe 2>/dev/null || echo "")
    if [ -n "$path_binary" ] && _is_executable "$path_binary"; then
        _AXE_PATH="$path_binary"
        echo "$_AXE_PATH"
        return 0
    fi

    # Not found
    echo ""
    return 0
}

# Check if AXe is available
# Returns: 0 if available, 30 if not
is_axe_available() {
    if [ -n "$_AXE_AVAILABLE" ]; then
        if [ "$_AXE_AVAILABLE" = "true" ]; then
            return 0
        else
            return 30
        fi
    fi

    local axe_path
    axe_path=$(get_axe_path)

    if [ -n "$axe_path" ]; then
        _AXE_AVAILABLE="true"
        return 0
    else
        _AXE_AVAILABLE="false"
        return 30
    fi
}

# Get AXe version
# Outputs: Version string (e.g., "1.1.0")
get_axe_version() {
    local axe_path
    axe_path=$(get_axe_path)

    if [ -z "$axe_path" ]; then
        echo ""
        return 30
    fi

    local version_output
    version_output=$("$axe_path" --version 2>/dev/null) || {
        echo ""
        return 31
    }

    # Extract semver pattern
    local version
    version=$(echo "$version_output" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    echo "$version"
}

# Compare semver versions
# Returns: 0 if version >= required, 1 otherwise
_compare_semver() {
    local current="$1"
    local required="$2"

    # Split into arrays
    IFS='.' read -ra current_parts <<< "$current"
    IFS='.' read -ra required_parts <<< "$required"

    local max_len=${#current_parts[@]}
    [ ${#required_parts[@]} -gt $max_len ] && max_len=${#required_parts[@]}

    for ((i = 0; i < max_len; i++)); do
        local cur=${current_parts[i]:-0}
        local req=${required_parts[i]:-0}

        if [ "$cur" -gt "$req" ]; then
            return 0
        elif [ "$cur" -lt "$req" ]; then
            return 1
        fi
    done

    return 0
}

# Check if AXe version is at least the required version
# Arguments:
#   $1 - required version (e.g., "1.0.0")
# Returns: 0 if version is sufficient, 1 otherwise
is_axe_at_least_version() {
    local required="$1"

    local current
    current=$(get_axe_version)

    if [ -z "$current" ]; then
        return 1
    fi

    _compare_semver "$current" "$required"
}

# Get installation instructions
get_axe_install_instructions() {
    echo "AXe tool not found. UI automation features are not available."
    echo ""
    echo "To install AXe:"
    echo "  brew tap cameroncooke/axe"
    echo "  brew install axe"
    echo ""
    echo "Or set XCODEBUILDMCP_AXE_PATH or AXE_PATH environment variable."
}

# ─────────────────────────────────────────────────────────────────────────────
# UI Description
# ─────────────────────────────────────────────────────────────────────────────

# Get full UI hierarchy from simulator
# Arguments:
#   $1 - simulator UUID
# Outputs: JSON view hierarchy
axe_describe_ui() {
    local uuid="$1"

    if ! is_axe_available; then
        _axe_error_response 30 "AXe not installed. $(get_axe_install_instructions)"
        return 30
    fi

    local axe_path
    axe_path=$(get_axe_path)

    local output
    output=$("$axe_path" describe-ui --udid "$uuid" 2>&1) || {
        _axe_error_response 31 "Failed to describe UI: $output"
        return 31
    }

    if [ "$JSON_OUTPUT" = "true" ]; then
        _axe_json_response "true" "UI hierarchy retrieved" "$output"
    else
        echo "$output"
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# UI Interactions
# ─────────────────────────────────────────────────────────────────────────────

# Tap at specific coordinates
# Arguments:
#   $1 - simulator UUID
#   $2 - x coordinate
#   $3 - y coordinate
axe_tap() {
    local uuid="$1"
    local x="$2"
    local y="$3"

    # Validate coordinates
    if ! [[ "$x" =~ ^[0-9]+(\.[0-9]+)?$ ]] || ! [[ "$y" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        _axe_error_response 33 "Invalid coordinates: x=$x, y=$y"
        return 33
    fi

    if ! is_axe_available; then
        _axe_error_response 30 "AXe not installed"
        return 30
    fi

    local axe_path
    axe_path=$(get_axe_path)

    local cmd_args=("$axe_path" "tap" "--udid" "$uuid" "--x" "$x" "--y" "$y")

    # Add pre/post delay if set
    [ "$AXE_PRE_DELAY" -gt 0 ] && cmd_args+=("--pre-delay" "$AXE_PRE_DELAY")
    [ "$AXE_POST_DELAY" -gt 0 ] && cmd_args+=("--post-delay" "$AXE_POST_DELAY")

    local output
    output=$("${cmd_args[@]}" 2>&1) || {
        _axe_error_response 31 "Tap failed: $output"
        return 31
    }

    _axe_json_response "true" "Tapped at ($x, $y)" "{\"x\": $x, \"y\": $y}"
}

# Tap element by accessibility identifier
# Arguments:
#   $1 - simulator UUID
#   $2 - accessibility identifier
axe_tap_element() {
    local uuid="$1"
    local identifier="$2"

    if ! is_axe_available; then
        _axe_error_response 30 "AXe not installed"
        return 30
    fi

    local axe_path
    axe_path=$(get_axe_path)

    local cmd_args=("$axe_path" "tap" "--udid" "$uuid" "--id" "$identifier")

    [ "$AXE_PRE_DELAY" -gt 0 ] && cmd_args+=("--pre-delay" "$AXE_PRE_DELAY")
    [ "$AXE_POST_DELAY" -gt 0 ] && cmd_args+=("--post-delay" "$AXE_POST_DELAY")

    local output
    output=$("${cmd_args[@]}" 2>&1) || {
        _axe_error_response 32 "Element not found or tap failed: $identifier"
        return 32
    }

    _axe_json_response "true" "Tapped element: $identifier" "\"$identifier\""
}

# Tap element by accessibility label
# Arguments:
#   $1 - simulator UUID
#   $2 - accessibility label
axe_tap_label() {
    local uuid="$1"
    local label="$2"

    if ! is_axe_available; then
        _axe_error_response 30 "AXe not installed"
        return 30
    fi

    local axe_path
    axe_path=$(get_axe_path)

    local cmd_args=("$axe_path" "tap" "--udid" "$uuid" "--label" "$label")

    [ "$AXE_PRE_DELAY" -gt 0 ] && cmd_args+=("--pre-delay" "$AXE_PRE_DELAY")
    [ "$AXE_POST_DELAY" -gt 0 ] && cmd_args+=("--post-delay" "$AXE_POST_DELAY")

    local output
    output=$("${cmd_args[@]}" 2>&1) || {
        _axe_error_response 32 "Element not found or tap failed: $label"
        return 32
    }

    _axe_json_response "true" "Tapped element with label: $label" "\"$label\""
}

# Swipe in a direction
# Arguments:
#   $1 - simulator UUID
#   $2 - direction (up, down, left, right)
axe_swipe() {
    local uuid="$1"
    local direction="$2"

    # Validate direction
    case "$direction" in
        up|down|left|right)
            ;;
        *)
            _axe_error_response 34 "Invalid direction: $direction (use up, down, left, right)"
            return 34
            ;;
    esac

    if ! is_axe_available; then
        _axe_error_response 30 "AXe not installed"
        return 30
    fi

    local axe_path
    axe_path=$(get_axe_path)

    local cmd_args=("$axe_path" "swipe" "--udid" "$uuid" "--direction" "$direction")

    [ "$AXE_PRE_DELAY" -gt 0 ] && cmd_args+=("--pre-delay" "$AXE_PRE_DELAY")
    [ "$AXE_POST_DELAY" -gt 0 ] && cmd_args+=("--post-delay" "$AXE_POST_DELAY")

    local output
    output=$("${cmd_args[@]}" 2>&1) || {
        _axe_error_response 31 "Swipe failed: $output"
        return 31
    }

    _axe_json_response "true" "Swiped $direction" "\"$direction\""
}

# Type text into the active field
# Arguments:
#   $1 - simulator UUID
#   $2 - text to type
axe_type_text() {
    local uuid="$1"
    local text="$2"

    if ! is_axe_available; then
        _axe_error_response 30 "AXe not installed"
        return 30
    fi

    local axe_path
    axe_path=$(get_axe_path)

    local cmd_args=("$axe_path" "type" "--udid" "$uuid" "--text" "$text")

    [ "$AXE_PRE_DELAY" -gt 0 ] && cmd_args+=("--pre-delay" "$AXE_PRE_DELAY")
    [ "$AXE_POST_DELAY" -gt 0 ] && cmd_args+=("--post-delay" "$AXE_POST_DELAY")

    local output
    output=$("${cmd_args[@]}" 2>&1) || {
        _axe_error_response 31 "Type text failed: $output"
        return 31
    }

    _axe_json_response "true" "Typed text" "\"${text:0:20}...\""
}

# Long press at coordinates
# Arguments:
#   $1 - simulator UUID
#   $2 - x coordinate
#   $3 - y coordinate
#   $4 - duration in seconds (optional, default: 1.0)
axe_long_press() {
    local uuid="$1"
    local x="$2"
    local y="$3"
    local duration="${4:-1.0}"

    # Validate coordinates
    if ! [[ "$x" =~ ^[0-9]+(\.[0-9]+)?$ ]] || ! [[ "$y" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        _axe_error_response 33 "Invalid coordinates: x=$x, y=$y"
        return 33
    fi

    if ! is_axe_available; then
        _axe_error_response 30 "AXe not installed"
        return 30
    fi

    local axe_path
    axe_path=$(get_axe_path)

    local cmd_args=("$axe_path" "long-press" "--udid" "$uuid" "--x" "$x" "--y" "$y" "--duration" "$duration")

    [ "$AXE_PRE_DELAY" -gt 0 ] && cmd_args+=("--pre-delay" "$AXE_PRE_DELAY")
    [ "$AXE_POST_DELAY" -gt 0 ] && cmd_args+=("--post-delay" "$AXE_POST_DELAY")

    local output
    output=$("${cmd_args[@]}" 2>&1) || {
        _axe_error_response 31 "Long press failed: $output"
        return 31
    }

    _axe_json_response "true" "Long pressed at ($x, $y) for ${duration}s" "{\"x\": $x, \"y\": $y, \"duration\": $duration}"
}

# ─────────────────────────────────────────────────────────────────────────────
# Hardware Simulation
# ─────────────────────────────────────────────────────────────────────────────

# Simulate hardware button press
# Arguments:
#   $1 - simulator UUID
#   $2 - button (home, lock, volumeUp, volumeDown, siri)
axe_hardware_button() {
    local uuid="$1"
    local button="$2"

    # Validate button
    case "$button" in
        home|lock|volumeUp|volumeDown|siri)
            ;;
        *)
            _axe_error_response 1 "Invalid button: $button (use home, lock, volumeUp, volumeDown, siri)"
            return 1
            ;;
    esac

    if ! is_axe_available; then
        _axe_error_response 30 "AXe not installed"
        return 30
    fi

    local axe_path
    axe_path=$(get_axe_path)

    local output
    output=$("$axe_path" button --udid "$uuid" --button "$button" 2>&1) || {
        _axe_error_response 31 "Button press failed: $output"
        return 31
    }

    _axe_json_response "true" "Pressed $button button" "\"$button\""
}

# ─────────────────────────────────────────────────────────────────────────────
# Screenshot
# ─────────────────────────────────────────────────────────────────────────────

# Capture screenshot via AXe
# Arguments:
#   $1 - simulator UUID
#   $2 - output path
axe_screenshot() {
    local uuid="$1"
    local output_path="$2"

    if ! is_axe_available; then
        _axe_error_response 30 "AXe not installed"
        return 30
    fi

    local axe_path
    axe_path=$(get_axe_path)

    local output
    output=$("$axe_path" screenshot --udid "$uuid" --path "$output_path" 2>&1) || {
        _axe_error_response 31 "Screenshot failed: $output"
        return 31
    }

    _axe_json_response "true" "Screenshot saved to $output_path" "\"$output_path\""
}

# ─────────────────────────────────────────────────────────────────────────────
# Key Press
# ─────────────────────────────────────────────────────────────────────────────

# Simulate key press
# Arguments:
#   $1 - simulator UUID
#   $2 - key (e.g., "return", "delete", "escape", etc.)
axe_key_press() {
    local uuid="$1"
    local key="$2"

    if ! is_axe_available; then
        _axe_error_response 30 "AXe not installed"
        return 30
    fi

    local axe_path
    axe_path=$(get_axe_path)

    local output
    output=$("$axe_path" key --udid "$uuid" --key "$key" 2>&1) || {
        _axe_error_response 31 "Key press failed: $output"
        return 31
    }

    _axe_json_response "true" "Pressed key: $key" "\"$key\""
}

# Simulate key sequence
# Arguments:
#   $1 - simulator UUID
#   $2 - key sequence (space-separated)
axe_key_sequence() {
    local uuid="$1"
    local sequence="$2"

    if ! is_axe_available; then
        _axe_error_response 30 "AXe not installed"
        return 30
    fi

    local axe_path
    axe_path=$(get_axe_path)

    # Parse sequence and send each key
    local key
    for key in $sequence; do
        local output
        output=$("$axe_path" key --udid "$uuid" --key "$key" 2>&1) || {
            _axe_error_response 31 "Key sequence failed at: $key"
            return 31
        }
    done

    _axe_json_response "true" "Key sequence completed" "\"$sequence\""
}

# ─────────────────────────────────────────────────────────────────────────────
# Touch Gestures
# ─────────────────────────────────────────────────────────────────────────────

# Perform touch gesture with multiple points
# Arguments:
#   $1 - simulator UUID
#   $2 - JSON array of touch points: [{"x": 100, "y": 200, "duration": 0.1}, ...]
axe_touch_gesture() {
    local uuid="$1"
    local points_json="$2"

    if ! is_axe_available; then
        _axe_error_response 30 "AXe not installed"
        return 30
    fi

    local axe_path
    axe_path=$(get_axe_path)

    local output
    output=$("$axe_path" gesture --udid "$uuid" --points "$points_json" 2>&1) || {
        _axe_error_response 31 "Touch gesture failed: $output"
        return 31
    }

    _axe_json_response "true" "Touch gesture completed" "$points_json"
}

# ─────────────────────────────────────────────────────────────────────────────
# Generic Executor
# ─────────────────────────────────────────────────────────────────────────────

# Execute arbitrary AXe command
# Arguments:
#   $1 - simulator UUID
#   $2 - AXe command
#   $3 - additional arguments (space-separated)
# Outputs: Command output
axe_execute() {
    local uuid="$1"
    local cmd="$2"
    local args="${3:-}"

    if ! is_axe_available; then
        _axe_error_response 30 "AXe not installed"
        return 30
    fi

    local axe_path
    axe_path=$(get_axe_path)

    local cmd_args=("$axe_path" "$cmd" "--udid" "$uuid")

    # Add additional arguments
    if [ -n "$args" ]; then
        # shellcheck disable=SC2086
        cmd_args+=($args)
    fi

    local output
    output=$("${cmd_args[@]}" 2>&1) || {
        _axe_error_response 31 "AXe command failed: $output"
        return 31
    }

    if [ "$JSON_OUTPUT" = "true" ]; then
        # Try to parse as JSON, fallback to string
        if echo "$output" | jq empty 2>/dev/null; then
            _axe_json_response "true" "Command executed" "$output"
        else
            _axe_json_response "true" "Command executed" "\"$output\""
        fi
    else
        echo "$output"
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# UI Element Helpers
# ─────────────────────────────────────────────────────────────────────────────

# Find element in UI hierarchy by identifier
# Arguments:
#   $1 - simulator UUID
#   $2 - accessibility identifier
# Outputs: Element JSON if found
axe_find_element() {
    local uuid="$1"
    local identifier="$2"

    local hierarchy
    hierarchy=$(axe_describe_ui "$uuid") || return $?

    if _axe_check_jq; then
        local element
        element=$(echo "$hierarchy" | jq --arg id "$identifier" \
            '.. | objects | select(.identifier == $id) | .')

        if [ -n "$element" ] && [ "$element" != "null" ]; then
            echo "$element"
            return 0
        fi
    fi

    _axe_error_response 32 "Element not found: $identifier"
    return 32
}

# Find element by label
# Arguments:
#   $1 - simulator UUID
#   $2 - accessibility label
# Outputs: Element JSON if found
axe_find_by_label() {
    local uuid="$1"
    local label="$2"

    local hierarchy
    hierarchy=$(axe_describe_ui "$uuid") || return $?

    if _axe_check_jq; then
        local element
        element=$(echo "$hierarchy" | jq --arg label "$label" \
            '.. | objects | select(.label == $label) | .')

        if [ -n "$element" ] && [ "$element" != "null" ]; then
            echo "$element"
            return 0
        fi
    fi

    _axe_error_response 32 "Element not found with label: $label"
    return 32
}

# Check if element exists
# Arguments:
#   $1 - simulator UUID
#   $2 - accessibility identifier
# Returns: 0 if exists, 32 if not
axe_element_exists() {
    local uuid="$1"
    local identifier="$2"

    axe_find_element "$uuid" "$identifier" >/dev/null 2>&1
}

# Wait for element to appear
# Arguments:
#   $1 - simulator UUID
#   $2 - accessibility identifier
#   $3 - timeout in seconds (default: 10)
# Returns: 0 if found, 32 if timeout
axe_wait_for_element() {
    local uuid="$1"
    local identifier="$2"
    local timeout="${3:-10}"

    local elapsed=0
    local interval=1

    while [ $elapsed -lt "$timeout" ]; do
        if axe_element_exists "$uuid" "$identifier"; then
            _axe_json_response "true" "Element found: $identifier" "\"$identifier\""
            return 0
        fi
        sleep $interval
        elapsed=$((elapsed + interval))
    done

    _axe_error_response 32 "Element not found after ${timeout}s: $identifier"
    return 32
}

# Get element frame (coordinates and size)
# Arguments:
#   $1 - simulator UUID
#   $2 - accessibility identifier
# Outputs: JSON frame {x, y, width, height}
axe_get_element_frame() {
    local uuid="$1"
    local identifier="$2"

    local element
    element=$(axe_find_element "$uuid" "$identifier") || return $?

    if _axe_check_jq; then
        local frame
        frame=$(echo "$element" | jq '.frame // empty')

        if [ -n "$frame" ]; then
            echo "$frame"
            return 0
        fi
    fi

    _axe_error_response 32 "Could not get frame for element: $identifier"
    return 32
}
