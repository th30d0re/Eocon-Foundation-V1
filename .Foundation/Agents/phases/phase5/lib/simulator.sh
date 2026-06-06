#!/usr/bin/env bash
# Library: simulator.sh
# Purpose: Simulator management library for iOS/watchOS/tvOS/visionOS simulators
# Dependencies: jq (optional - graceful degradation), xcrun (required)
#
# Functions:
#   list_simulators(platform, state)    - List all simulators with optional filtering
#   get_booted_simulator()              - Find currently booted simulator UDID
#   get_simulator_by_name(name)         - Resolve name to UUID (handles duplicates)
#   get_simulator_by_udid(uuid)         - Validate UUID exists
#   is_simulator_booted(uuid)           - Check boot state
#   is_simulator_available(uuid)        - Check isAvailable flag
#   boot_simulator(name_or_uuid)        - Boot by name/UDID, wait for boot
#   shutdown_simulator(uuid)            - Graceful shutdown
#   erase_simulator(name_or_uuid)       - Reset to factory state
#   clone_simulator(source, name)       - Clone existing simulator
#   set_simulator_location(uuid, lat, lon)   - Set GPS coordinates
#   set_simulator_appearance(uuid, mode)     - Set dark/light/auto mode
#   set_simulator_statusbar(uuid, overrides) - Override status bar
#   reset_simulator_location(uuid)           - Clear GPS override
#   install_app_simulator(uuid, app_path)    - Install .app bundle
#   launch_app_simulator(uuid, bundle_id)    - Launch installed app
#   terminate_app_simulator(uuid, bundle_id) - Terminate running app
#   get_simulator_app_path(uuid, bundle_id)  - Get installed app path
#
# Environment Variables:
#   PROJECT_ROOT                        - Root directory of the project
#   SIMULATOR_BOOT_TIMEOUT              - Boot timeout in seconds (default: 60)
#   SIMULATOR_BOOT_POLL_INTERVAL        - Boot poll interval in seconds (default: 2)
#   JSON_OUTPUT                         - Set to "true" for JSON output mode
#
# Exit Codes:
#   0  - Success
#   1  - General error
#   20 - Simulator not found
#   21 - Simulator unavailable
#   22 - Boot timeout
#   23 - App not found
#   24 - Invalid UUID format

set -euo pipefail

# Verify bash is running
if [ -z "${BASH_VERSION:-}" ]; then
    echo "Error: This library requires bash" >&2
    return 1 2>/dev/null || exit 1
fi

# Path resolution
SIMULATOR_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SIMULATOR_PHASE5_DIR="$(cd "${SIMULATOR_LIB_DIR}/.." && pwd)"
SIMULATOR_PROJECT_ROOT="${PROJECT_ROOT:-$(cd "${SIMULATOR_PHASE5_DIR}/../../../.." && pwd)}"

# Configuration
SIMULATOR_BOOT_TIMEOUT="${SIMULATOR_BOOT_TIMEOUT:-60}"
SIMULATOR_BOOT_POLL_INTERVAL="${SIMULATOR_BOOT_POLL_INTERVAL:-2}"
JSON_OUTPUT="${JSON_OUTPUT:-false}"

# UUID regex pattern
UUID_REGEX='^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'

# Internal state
_JQ_AVAILABLE=""
_SIMULATOR_CACHE=""
_SIMULATOR_CACHE_TIME=0
_SIMULATOR_CACHE_TTL=5  # Cache TTL in seconds

# ─────────────────────────────────────────────────────────────────────────────
# Internal Helpers
# ─────────────────────────────────────────────────────────────────────────────

# Check if jq is available
_check_jq() {
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
_json_response() {
    local success="$1"
    local message="$2"
    local data="${3:-null}"

    if [ "$JSON_OUTPUT" = "true" ]; then
        if _check_jq; then
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
_error_response() {
    local code="$1"
    local message="$2"
    _json_response "false" "$message" "null"
    return "$code"
}

# Check if input looks like a UUID
_is_uuid() {
    local input="$1"
    [[ "$input" =~ $UUID_REGEX ]]
}

# Get simulator list from simctl (with caching)
_get_simulators_json() {
    local current_time
    current_time=$(date +%s)

    # Check cache validity
    if [ -n "$_SIMULATOR_CACHE" ] && [ $((current_time - _SIMULATOR_CACHE_TIME)) -lt $_SIMULATOR_CACHE_TTL ]; then
        echo "$_SIMULATOR_CACHE"
        return 0
    fi

    # Fetch fresh data
    local devices_json
    devices_json=$(xcrun simctl list devices -j 2>/dev/null) || {
        _error_response 1 "Failed to list simulators"
        return 1
    }

    _SIMULATOR_CACHE="$devices_json"
    _SIMULATOR_CACHE_TIME=$current_time
    echo "$devices_json"
}

# Invalidate simulator cache
_invalidate_simulator_cache() {
    _SIMULATOR_CACHE=""
    _SIMULATOR_CACHE_TIME=0
}

# ─────────────────────────────────────────────────────────────────────────────
# Simulator Listing & Discovery
# ─────────────────────────────────────────────────────────────────────────────

# List all simulators with optional filtering
# Arguments:
#   $1 - platform filter (optional: iOS, watchOS, tvOS, visionOS)
#   $2 - state filter (optional: Booted, Shutdown)
#   $3 - name pattern filter (optional: regex pattern)
# Outputs: JSON array of simulators or formatted text
list_simulators() {
    local platform_filter="${1:-}"
    local state_filter="${2:-}"
    local name_pattern="${3:-}"

    local devices_json
    devices_json=$(_get_simulators_json) || return 1

    if _check_jq; then
        local jq_filter='.devices | to_entries | .[] | .key as $runtime | .value[] | {name: .name, udid: .udid, state: .state, isAvailable: .isAvailable, runtime: $runtime}'

        # Apply platform filter
        if [ -n "$platform_filter" ]; then
            jq_filter="$jq_filter | select(.runtime | test(\"$platform_filter\"; \"i\"))"
        fi

        # Apply state filter
        if [ -n "$state_filter" ]; then
            jq_filter="$jq_filter | select(.state == \"$state_filter\")"
        fi

        # Apply name pattern filter
        if [ -n "$name_pattern" ]; then
            jq_filter="$jq_filter | select(.name | test(\"$name_pattern\"; \"i\"))"
        fi

        echo "$devices_json" | jq -s "[$jq_filter]"
    else
        # Fallback: basic text output using grep
        if [ -n "$platform_filter" ]; then
            xcrun simctl list devices | grep -i "$platform_filter" || echo "No simulators found"
        else
            xcrun simctl list devices
        fi
    fi
}

# Get the currently booted simulator UDID
# Outputs: UDID of first booted simulator or empty string
get_booted_simulator() {
    local devices_json
    devices_json=$(_get_simulators_json) || return 1

    if _check_jq; then
        local udid
        udid=$(echo "$devices_json" | jq -r '.devices | to_entries | .[].value | .[] | select(.state == "Booted") | .udid' | head -1)
        echo "$udid"
    else
        # Fallback: parse simctl output
        xcrun simctl list devices booted 2>/dev/null | grep -o '([A-F0-9-]*)' | head -1 | tr -d '()'
    fi
}

# Get simulator UUID by name
# Arguments:
#   $1 - simulator name
# Outputs: UDID if found
# Returns: 0 on success, 20 if not found, 21 if unavailable
get_simulator_by_name() {
    local name="$1"

    # Check if input is already a UUID
    if _is_uuid "$name"; then
        echo "$name"
        return 0
    fi

    local devices_json
    devices_json=$(_get_simulators_json) || return 1

    if _check_jq; then
        # First try to find a booted device with exact name match
        local udid
        udid=$(echo "$devices_json" | jq -r --arg name "$name" \
            '.devices | to_entries | .[].value | .[] | select(.name == $name and .state == "Booted" and .isAvailable == true) | .udid' | head -1)

        # If no booted device, fall back to first available
        if [ -z "$udid" ]; then
            udid=$(echo "$devices_json" | jq -r --arg name "$name" \
                '.devices | to_entries | .[].value | .[] | select(.name == $name and .isAvailable == true) | .udid' | head -1)
        fi

        if [ -n "$udid" ]; then
            # Check for duplicates and warn
            local count
            count=$(echo "$devices_json" | jq -r --arg name "$name" \
                '[.devices | to_entries | .[].value | .[] | select(.name == $name and .isAvailable == true)] | length')

            if [ "$count" -gt 1 ]; then
                local booted_count
                booted_count=$(echo "$devices_json" | jq -r --arg name "$name" \
                    '[.devices | to_entries | .[].value | .[] | select(.name == $name and .state == "Booted" and .isAvailable == true)] | length')
                if [ "$booted_count" -gt 0 ]; then
                    echo "Warning: Multiple simulators named '$name' found, using booted device" >&2
                else
                    echo "Warning: Multiple simulators named '$name' found, using first available" >&2
                fi
            fi

            echo "$udid"
            return 0
        fi

        # Check if device exists but is unavailable
        local unavailable
        unavailable=$(echo "$devices_json" | jq -r --arg name "$name" \
            '.devices | to_entries | .[].value | .[] | select(.name == $name and .isAvailable == false) | .udid' | head -1)

        if [ -n "$unavailable" ]; then
            _error_response 21 "Simulator '$name' exists but is not available"
            return 21
        fi

        _error_response 20 "Simulator '$name' not found"
        return 20
    else
        # Fallback: grep based parsing
        local udid
        udid=$(xcrun simctl list devices available | grep -E "^\s+$name " | grep -o '([A-F0-9-]*)' | head -1 | tr -d '()')

        if [ -n "$udid" ]; then
            echo "$udid"
            return 0
        fi

        _error_response 20 "Simulator '$name' not found"
        return 20
    fi
}

# Validate simulator UUID exists
# Arguments:
#   $1 - simulator UUID
# Returns: 0 if exists, 20 if not found, 24 if invalid UUID format
get_simulator_by_udid() {
    local uuid="$1"

    # Validate UUID format
    if ! _is_uuid "$uuid"; then
        _error_response 24 "Invalid UUID format: $uuid"
        return 24
    fi

    local devices_json
    devices_json=$(_get_simulators_json) || return 1

    if _check_jq; then
        local exists
        exists=$(echo "$devices_json" | jq -r --arg uuid "$uuid" \
            '[.devices | to_entries | .[].value | .[] | select(.udid == $uuid)] | length')

        if [ "$exists" -gt 0 ]; then
            echo "$uuid"
            return 0
        fi
    else
        if xcrun simctl list devices | grep -q "$uuid"; then
            echo "$uuid"
            return 0
        fi
    fi

    _error_response 20 "Simulator with UUID '$uuid' not found"
    return 20
}

# Check if simulator is booted
# Arguments:
#   $1 - simulator UUID
# Outputs: "true" or "false"
is_simulator_booted() {
    local uuid="$1"

    local devices_json
    devices_json=$(_get_simulators_json) || return 1

    if _check_jq; then
        local state
        state=$(echo "$devices_json" | jq -r --arg uuid "$uuid" \
            '.devices | to_entries | .[].value | .[] | select(.udid == $uuid) | .state')

        if [ "$state" = "Booted" ]; then
            echo "true"
        else
            echo "false"
        fi
    else
        if xcrun simctl list devices booted | grep -q "$uuid"; then
            echo "true"
        else
            echo "false"
        fi
    fi
}

# Check if simulator is available
# Arguments:
#   $1 - simulator UUID
# Outputs: "true" or "false"
is_simulator_available() {
    local uuid="$1"

    local devices_json
    devices_json=$(_get_simulators_json) || return 1

    if _check_jq; then
        local available
        available=$(echo "$devices_json" | jq -r --arg uuid "$uuid" \
            '.devices | to_entries | .[].value | .[] | select(.udid == $uuid) | .isAvailable')

        if [ "$available" = "true" ]; then
            echo "true"
        else
            echo "false"
        fi
    else
        if xcrun simctl list devices available | grep -q "$uuid"; then
            echo "true"
        else
            echo "false"
        fi
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Simulator Lifecycle
# ─────────────────────────────────────────────────────────────────────────────

# Boot a simulator by name or UUID
# Arguments:
#   $1 - simulator name or UUID
#   $2 - wait for boot (optional, default: true)
# Outputs: UDID of booted simulator
# Returns: 0 on success, 22 on timeout
boot_simulator() {
    local name_or_uuid="$1"
    local wait_for_boot="${2:-true}"

    # Resolve to UUID
    local uuid
    uuid=$(get_simulator_by_name "$name_or_uuid") || return $?

    # Check if already booted
    if [ "$(is_simulator_booted "$uuid")" = "true" ]; then
        _json_response "true" "Simulator already booted" "\"$uuid\""
        echo "$uuid"
        return 0
    fi

    # Boot simulator
    _invalidate_simulator_cache
    xcrun simctl boot "$uuid" 2>/dev/null || {
        # Boot may fail if already booting - check state
        sleep 1
        if [ "$(is_simulator_booted "$uuid")" = "true" ]; then
            _json_response "true" "Simulator booted" "\"$uuid\""
            echo "$uuid"
            return 0
        fi
        _error_response 1 "Failed to boot simulator $uuid"
        return 1
    }

    if [ "$wait_for_boot" = "true" ]; then
        local elapsed=0
        while [ $elapsed -lt "$SIMULATOR_BOOT_TIMEOUT" ]; do
            _invalidate_simulator_cache
            if [ "$(is_simulator_booted "$uuid")" = "true" ]; then
                _json_response "true" "Simulator booted successfully" "\"$uuid\""
                echo "$uuid"
                return 0
            fi
            sleep "$SIMULATOR_BOOT_POLL_INTERVAL"
            elapsed=$((elapsed + SIMULATOR_BOOT_POLL_INTERVAL))
        done

        _error_response 22 "Simulator boot timed out after ${SIMULATOR_BOOT_TIMEOUT}s"
        return 22
    fi

    echo "$uuid"
    return 0
}

# Shutdown a simulator
# Arguments:
#   $1 - simulator UUID
# Returns: 0 on success
shutdown_simulator() {
    local uuid="$1"

    # Validate UUID
    if ! _is_uuid "$uuid"; then
        uuid=$(get_simulator_by_name "$uuid") || return $?
    fi

    # Check if already shutdown
    if [ "$(is_simulator_booted "$uuid")" = "false" ]; then
        _json_response "true" "Simulator already shutdown" "\"$uuid\""
        return 0
    fi

    _invalidate_simulator_cache
    if xcrun simctl shutdown "$uuid" 2>/dev/null; then
        _json_response "true" "Simulator shutdown successfully" "\"$uuid\""
        return 0
    else
        _error_response 1 "Failed to shutdown simulator $uuid"
        return 1
    fi
}

# Erase (reset) a simulator
# Arguments:
#   $1 - simulator name or UUID
# Returns: 0 on success
erase_simulator() {
    local name_or_uuid="$1"

    # Resolve to UUID
    local uuid
    uuid=$(get_simulator_by_name "$name_or_uuid") || return $?

    # Shutdown first if booted
    if [ "$(is_simulator_booted "$uuid")" = "true" ]; then
        shutdown_simulator "$uuid" >/dev/null || true
        sleep 2
    fi

    _invalidate_simulator_cache
    if xcrun simctl erase "$uuid" 2>/dev/null; then
        _json_response "true" "Simulator erased successfully" "\"$uuid\""
        return 0
    else
        _error_response 1 "Failed to erase simulator $uuid"
        return 1
    fi
}

# Clone an existing simulator
# Arguments:
#   $1 - source simulator name or UUID
#   $2 - new simulator name
# Outputs: UDID of cloned simulator
clone_simulator() {
    local source="$1"
    local new_name="$2"

    # Resolve source to UUID
    local source_uuid
    source_uuid=$(get_simulator_by_name "$source") || return $?

    _invalidate_simulator_cache
    local clone_output
    clone_output=$(xcrun simctl clone "$source_uuid" "$new_name" 2>&1) || {
        _error_response 1 "Failed to clone simulator: $clone_output"
        return 1
    }

    # The clone command outputs the new UUID
    local new_uuid
    new_uuid=$(echo "$clone_output" | grep -o '[A-F0-9-]\{36\}' | head -1)

    if [ -n "$new_uuid" ]; then
        _json_response "true" "Simulator cloned successfully" "\"$new_uuid\""
        echo "$new_uuid"
        return 0
    else
        _error_response 1 "Clone succeeded but could not determine new UUID"
        return 1
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Simulator Configuration
# ─────────────────────────────────────────────────────────────────────────────

# Set simulator GPS location
# Arguments:
#   $1 - simulator UUID
#   $2 - latitude
#   $3 - longitude
set_simulator_location() {
    local uuid="$1"
    local lat="$2"
    local lon="$3"

    # Validate UUID
    if ! _is_uuid "$uuid"; then
        uuid=$(get_simulator_by_name "$uuid") || return $?
    fi

    # Ensure simulator is booted
    if [ "$(is_simulator_booted "$uuid")" = "false" ]; then
        _error_response 1 "Simulator must be booted to set location"
        return 1
    fi

    if xcrun simctl location "$uuid" set "$lat,$lon" 2>/dev/null; then
        _json_response "true" "Location set to $lat,$lon" "{\"lat\": $lat, \"lon\": $lon}"
        return 0
    else
        _error_response 1 "Failed to set simulator location"
        return 1
    fi
}

# Reset simulator GPS location
# Arguments:
#   $1 - simulator UUID
reset_simulator_location() {
    local uuid="$1"

    # Validate UUID
    if ! _is_uuid "$uuid"; then
        uuid=$(get_simulator_by_name "$uuid") || return $?
    fi

    if xcrun simctl location "$uuid" clear 2>/dev/null; then
        _json_response "true" "Location reset" "null"
        return 0
    else
        _error_response 1 "Failed to reset simulator location"
        return 1
    fi
}

# Set simulator appearance mode
# Arguments:
#   $1 - simulator UUID
#   $2 - appearance mode (dark, light)
set_simulator_appearance() {
    local uuid="$1"
    local mode="$2"

    # Validate mode
    case "$mode" in
        dark|light)
            ;;
        *)
            _error_response 1 "Invalid appearance mode: $mode (use 'dark' or 'light')"
            return 1
            ;;
    esac

    # Validate UUID
    if ! _is_uuid "$uuid"; then
        uuid=$(get_simulator_by_name "$uuid") || return $?
    fi

    # Ensure simulator is booted
    if [ "$(is_simulator_booted "$uuid")" = "false" ]; then
        _error_response 1 "Simulator must be booted to set appearance"
        return 1
    fi

    if xcrun simctl ui "$uuid" appearance "$mode" 2>/dev/null; then
        _json_response "true" "Appearance set to $mode" "\"$mode\""
        return 0
    else
        _error_response 1 "Failed to set simulator appearance"
        return 1
    fi
}

# Override simulator status bar
# Arguments:
#   $1 - simulator UUID
#   $2 - time (optional, e.g., "9:41")
#   $3 - battery level (optional, 0-100)
#   $4 - wifi bars (optional, 0-3)
#   $5 - cellular bars (optional, 0-4)
set_simulator_statusbar() {
    local uuid="$1"
    local time="${2:-}"
    local battery="${3:-}"
    local wifi="${4:-}"
    local cellular="${5:-}"

    # Validate UUID
    if ! _is_uuid "$uuid"; then
        uuid=$(get_simulator_by_name "$uuid") || return $?
    fi

    # Ensure simulator is booted
    if [ "$(is_simulator_booted "$uuid")" = "false" ]; then
        _error_response 1 "Simulator must be booted to override status bar"
        return 1
    fi

    local cmd_args=("xcrun" "simctl" "status_bar" "$uuid" "override")

    [ -n "$time" ] && cmd_args+=("--time" "$time")
    [ -n "$battery" ] && cmd_args+=("--batteryLevel" "$battery")
    [ -n "$wifi" ] && cmd_args+=("--wifiBars" "$wifi")
    [ -n "$cellular" ] && cmd_args+=("--cellularBars" "$cellular")

    if "${cmd_args[@]}" 2>/dev/null; then
        _json_response "true" "Status bar overridden" "null"
        return 0
    else
        _error_response 1 "Failed to override status bar"
        return 1
    fi
}

# Clear status bar overrides
# Arguments:
#   $1 - simulator UUID
clear_simulator_statusbar() {
    local uuid="$1"

    # Validate UUID
    if ! _is_uuid "$uuid"; then
        uuid=$(get_simulator_by_name "$uuid") || return $?
    fi

    if xcrun simctl status_bar "$uuid" clear 2>/dev/null; then
        _json_response "true" "Status bar overrides cleared" "null"
        return 0
    else
        _error_response 1 "Failed to clear status bar overrides"
        return 1
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# App Management
# ─────────────────────────────────────────────────────────────────────────────

# Install an app on a simulator
# Arguments:
#   $1 - simulator UUID
#   $2 - path to .app bundle
install_app_simulator() {
    local uuid="$1"
    local app_path="$2"

    # Validate UUID
    if ! _is_uuid "$uuid"; then
        uuid=$(get_simulator_by_name "$uuid") || return $?
    fi

    # Validate app path
    if [ ! -d "$app_path" ]; then
        _error_response 23 "App bundle not found: $app_path"
        return 23
    fi

    # Ensure simulator is booted
    if [ "$(is_simulator_booted "$uuid")" = "false" ]; then
        boot_simulator "$uuid" >/dev/null || return $?
    fi

    if xcrun simctl install "$uuid" "$app_path" 2>/dev/null; then
        _json_response "true" "App installed successfully" "\"$app_path\""
        return 0
    else
        _error_response 1 "Failed to install app"
        return 1
    fi
}

# Launch an app on a simulator
# Arguments:
#   $1 - simulator UUID
#   $2 - bundle identifier
#   $3 - additional arguments (optional)
launch_app_simulator() {
    local uuid="$1"
    local bundle_id="$2"
    local args="${3:-}"

    # Validate UUID
    if ! _is_uuid "$uuid"; then
        uuid=$(get_simulator_by_name "$uuid") || return $?
    fi

    # Ensure simulator is booted
    if [ "$(is_simulator_booted "$uuid")" = "false" ]; then
        boot_simulator "$uuid" >/dev/null || return $?
    fi

    local launch_args=("xcrun" "simctl" "launch" "$uuid" "$bundle_id")
    if [ -n "$args" ]; then
        # shellcheck disable=SC2086
        launch_args+=($args)
    fi

    local pid
    pid=$("${launch_args[@]}" 2>/dev/null) || {
        _error_response 23 "Failed to launch app: $bundle_id"
        return 23
    }

    _json_response "true" "App launched" "{\"bundleId\": \"$bundle_id\", \"pid\": \"$pid\"}"
    return 0
}

# Terminate an app on a simulator
# Arguments:
#   $1 - simulator UUID
#   $2 - bundle identifier
terminate_app_simulator() {
    local uuid="$1"
    local bundle_id="$2"

    # Validate UUID
    if ! _is_uuid "$uuid"; then
        uuid=$(get_simulator_by_name "$uuid") || return $?
    fi

    if xcrun simctl terminate "$uuid" "$bundle_id" 2>/dev/null; then
        _json_response "true" "App terminated" "\"$bundle_id\""
        return 0
    else
        # App might not be running, which is fine
        _json_response "true" "App terminated or not running" "\"$bundle_id\""
        return 0
    fi
}

# Get the installed path of an app on a simulator
# Arguments:
#   $1 - simulator UUID
#   $2 - bundle identifier
# Outputs: Path to installed app
get_simulator_app_path() {
    local uuid="$1"
    local bundle_id="$2"

    # Validate UUID
    if ! _is_uuid "$uuid"; then
        uuid=$(get_simulator_by_name "$uuid") || return $?
    fi

    local app_path
    app_path=$(xcrun simctl get_app_container "$uuid" "$bundle_id" app 2>/dev/null) || {
        _error_response 23 "App not found: $bundle_id"
        return 23
    }

    _json_response "true" "App path found" "\"$app_path\""
    echo "$app_path"
    return 0
}

# ─────────────────────────────────────────────────────────────────────────────
# Utility Functions
# ─────────────────────────────────────────────────────────────────────────────

# Get simulator runtime info
# Arguments:
#   $1 - simulator UUID
# Outputs: Runtime information
get_simulator_runtime() {
    local uuid="$1"

    local devices_json
    devices_json=$(_get_simulators_json) || return 1

    if _check_jq; then
        echo "$devices_json" | jq -r --arg uuid "$uuid" \
            '.devices | to_entries | .[] | select(.value | .[] | select(.udid == $uuid)) | .key'
    else
        _error_response 1 "jq required for runtime info"
        return 1
    fi
}

# Take a screenshot of a simulator
# Arguments:
#   $1 - simulator UUID
#   $2 - output path
take_simulator_screenshot() {
    local uuid="$1"
    local output_path="$2"

    # Validate UUID
    if ! _is_uuid "$uuid"; then
        uuid=$(get_simulator_by_name "$uuid") || return $?
    fi

    # Ensure simulator is booted
    if [ "$(is_simulator_booted "$uuid")" = "false" ]; then
        _error_response 1 "Simulator must be booted to take screenshot"
        return 1
    fi

    if xcrun simctl io "$uuid" screenshot "$output_path" 2>/dev/null; then
        _json_response "true" "Screenshot saved" "\"$output_path\""
        return 0
    else
        _error_response 1 "Failed to take screenshot"
        return 1
    fi
}

# Open URL in simulator
# Arguments:
#   $1 - simulator UUID
#   $2 - URL
open_url_simulator() {
    local uuid="$1"
    local url="$2"

    # Validate UUID
    if ! _is_uuid "$uuid"; then
        uuid=$(get_simulator_by_name "$uuid") || return $?
    fi

    # Ensure simulator is booted
    if [ "$(is_simulator_booted "$uuid")" = "false" ]; then
        boot_simulator "$uuid" >/dev/null || return $?
    fi

    if xcrun simctl openurl "$uuid" "$url" 2>/dev/null; then
        _json_response "true" "URL opened" "\"$url\""
        return 0
    else
        _error_response 1 "Failed to open URL"
        return 1
    fi
}

# Push notification to simulator
# Arguments:
#   $1 - simulator UUID
#   $2 - bundle identifier
#   $3 - path to payload JSON file
push_notification_simulator() {
    local uuid="$1"
    local bundle_id="$2"
    local payload_path="$3"

    # Validate UUID
    if ! _is_uuid "$uuid"; then
        uuid=$(get_simulator_by_name "$uuid") || return $?
    fi

    # Validate payload file
    if [ ! -f "$payload_path" ]; then
        _error_response 1 "Payload file not found: $payload_path"
        return 1
    fi

    if xcrun simctl push "$uuid" "$bundle_id" "$payload_path" 2>/dev/null; then
        _json_response "true" "Notification sent" "null"
        return 0
    else
        _error_response 1 "Failed to send notification"
        return 1
    fi
}

# Get destination string for xcodebuild
# Arguments:
#   $1 - simulator name or UUID
# Outputs: Destination string
get_destination_string() {
    local name_or_uuid="$1"

    local uuid
    uuid=$(get_simulator_by_name "$name_or_uuid") || return $?

    echo "platform=iOS Simulator,id=$uuid"
}
