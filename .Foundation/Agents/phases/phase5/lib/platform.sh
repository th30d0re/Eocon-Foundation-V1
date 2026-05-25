#!/usr/bin/env bash
# Library: platform.sh
# Purpose: Multi-platform destination construction for xcodebuild
# Dependencies: xcrun (optional - graceful degradation if unavailable)
#
# Functions:
#   construct_destination()     - Build -destination string for xcodebuild
#   is_simulator_platform()     - Check if platform requires simulator
#   get_generic_destination()   - Return generic destination for platform
#   validate_destination()      - Validate destination string and availability
#
# Supported Platforms:
#   - iOS Simulator
#   - iOS Device
#   - macOS
#   - watchOS Simulator
#   - tvOS Simulator
#   - visionOS Simulator
#
# Return Codes:
#   0 - Success
#   1 - Invalid platform
#   2 - Simulator/device not found
#
# Usage:
#   source platform.sh
#   destination=$(construct_destination "iOS Simulator" "iPhone 16")

set -euo pipefail

# Verify bash is running
if [ -z "${BASH_VERSION:-}" ]; then
    echo "Error: This library requires bash" >&2
    return 1 2>/dev/null || exit 1
fi

# Path resolution using BASH_SOURCE[0] for PATH-installed agents
PLATFORM_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLATFORM_PHASE5_DIR="$(cd "${PLATFORM_LIB_DIR}/.." && pwd)"
PLATFORM_PROJECT_ROOT="${PROJECT_ROOT:-$(cd "${PLATFORM_PHASE5_DIR}/../../../.." && pwd)}"

# Internal state
_XCRUN_AVAILABLE=""

# Check if xcrun is available
_check_xcrun_available() {
    if [ -z "$_XCRUN_AVAILABLE" ]; then
        if command -v xcrun &>/dev/null; then
            _XCRUN_AVAILABLE="true"
        else
            _XCRUN_AVAILABLE="false"
            echo "⚠️  xcrun not found, destination validation disabled" >&2
        fi
    fi
    [ "$_XCRUN_AVAILABLE" = "true" ]
}

# Check if a platform is a simulator platform
# Arguments:
#   $1 - platform name
# Returns: 0 if simulator platform, 1 if not
is_simulator_platform() {
    local platform="$1"

    case "$platform" in
        "iOS Simulator"|"watchOS Simulator"|"tvOS Simulator"|"visionOS Simulator")
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Get generic destination for a platform
# Arguments:
#   $1 - platform name
# Outputs: Generic destination string to stdout
# Returns: 0 on success, 1 on invalid platform
get_generic_destination() {
    local platform="$1"

    case "$platform" in
        "iOS Simulator")
            echo "platform=iOS Simulator,name=Any iOS Simulator Device"
            ;;
        "iOS"|"iOS Device")
            echo "generic/platform=iOS"
            ;;
        "macOS")
            echo "platform=macOS"
            ;;
        "watchOS Simulator")
            echo "platform=watchOS Simulator,name=Any watchOS Simulator Device"
            ;;
        "watchOS"|"watchOS Device")
            echo "generic/platform=watchOS"
            ;;
        "tvOS Simulator")
            echo "platform=tvOS Simulator,name=Any tvOS Simulator Device"
            ;;
        "tvOS"|"tvOS Device")
            echo "generic/platform=tvOS"
            ;;
        "visionOS Simulator")
            echo "platform=visionOS Simulator,name=Any visionOS Simulator Device"
            ;;
        "visionOS"|"visionOS Device")
            echo "generic/platform=visionOS"
            ;;
        *)
            echo "⚠️  Unknown platform: $platform" >&2
            return 1
            ;;
    esac
    return 0
}

# Get available simulators for a platform
# Arguments:
#   $1 - platform name (e.g., "iOS Simulator")
# Outputs: List of available simulator names to stdout
_get_available_simulators() {
    local platform="$1"

    if ! _check_xcrun_available; then
        return 1
    fi

    local device_type=""
    case "$platform" in
        "iOS Simulator")
            device_type="iPhone"
            ;;
        "watchOS Simulator")
            device_type="Apple Watch"
            ;;
        "tvOS Simulator")
            device_type="Apple TV"
            ;;
        "visionOS Simulator")
            device_type="Apple Vision"
            ;;
        *)
            return 1
            ;;
    esac

    xcrun simctl list devices available 2>/dev/null | grep -E "^\s+$device_type" | sed 's/^[[:space:]]*//' | cut -d'(' -f1 | sed 's/[[:space:]]*$//'
}

# Get first available simulator ID for a platform using xcodebuild
# This ensures we get a simulator that Xcode actually supports
# Arguments:
#   $1 - platform name (e.g., "iOS Simulator")
# Environment variables (optional):
#   XCODE_PROJECT - path to .xcodeproj
#   XCODE_WORKSPACE - path to .xcworkspace
#   SCHEME - scheme name
# Outputs: First available simulator ID to stdout
_get_first_available_simulator_id() {
    local platform="$1"

    if ! _check_xcrun_available; then
        return 1
    fi

    # If we have project and scheme info, query xcodebuild for supported destinations
    if [ -n "${XCODE_PROJECT:-}${XCODE_WORKSPACE:-}" ] && [ -n "${SCHEME:-}" ]; then
        local xcode_arg=""
        if [ -n "${XCODE_WORKSPACE:-}" ]; then
            xcode_arg="-workspace ${XCODE_WORKSPACE}"
        elif [ -n "${XCODE_PROJECT:-}" ]; then
            xcode_arg="-project ${XCODE_PROJECT}"
        fi

        if [ -n "$xcode_arg" ]; then
            # Get first available simulator ID from xcodebuild's supported destinations
            case "$platform" in
                "iOS Simulator")
                    local sim_id
                    sim_id=$(xcodebuild $xcode_arg -scheme "${SCHEME}" -showdestinations 2>/dev/null | \
                        grep "platform:iOS Simulator" | \
                        grep -v "placeholder" | \
                        grep "id:" | \
                        head -1 | \
                        sed -n 's/.*id:\([A-F0-9-]*\).*/\1/p')
                    if [ -n "$sim_id" ]; then
                        echo "$sim_id"
                        return 0
                    fi
                    ;;
            esac
        fi
    fi

    # Fallback to simctl if xcodebuild query fails
    local device_type=""
    case "$platform" in
        "iOS Simulator")
            device_type="iPhone"
            ;;
        "watchOS Simulator")
            device_type="Apple Watch"
            ;;
        "tvOS Simulator")
            device_type="Apple TV"
            ;;
        "visionOS Simulator")
            device_type="Apple Vision"
            ;;
        *)
            return 1
            ;;
    esac

    # Extract UDID from lines like: "iPhone 17 (6F49B5CD-8345-4888-92B2-48CDDB265CAA) (Shutdown)"
    xcrun simctl list devices available 2>/dev/null | grep -E "^\s+$device_type" | head -1 | sed -n 's/.*(\([A-F0-9-]*\)).*/\1/p'
}

# Get the first available simulator for a platform
# Arguments:
#   $1 - platform name
# Outputs: First available simulator name to stdout
_get_first_available_simulator() {
    local platform="$1"
    _get_available_simulators "$platform" | head -1
}

# Validate that a simulator exists
# Arguments:
#   $1 - simulator name
# Returns: 0 if exists, 2 if not found
_validate_simulator_exists() {
    local simulator_name="$1"

    if ! _check_xcrun_available; then
        echo "⚠️  xcrun not available, skipping simulator validation" >&2
        return 0
    fi

    if xcrun simctl list devices available 2>/dev/null | grep -q "$simulator_name"; then
        return 0
    else
        return 2
    fi
}

# Validate that a device UDID exists
# Arguments:
#   $1 - device UDID
# Returns: 0 if exists, 2 if not found
_validate_device_exists() {
    local device_udid="$1"

    if ! _check_xcrun_available; then
        echo "⚠️  xcrun not available, skipping device validation" >&2
        return 0
    fi

    if xcrun xctrace list devices 2>/dev/null | grep -q "$device_udid"; then
        return 0
    else
        return 2
    fi
}

# Construct destination string for xcodebuild
# Arguments:
#   $1 - platform (e.g., "iOS Simulator", "macOS", "iOS Device")
#   $2 - simulator name OR device UDID (optional)
#   $3 - architecture (optional, for macOS: arm64 or x86_64)
# Outputs: Destination string to stdout
# Returns: 0 on success, 1 on invalid platform, 2 on device/simulator not found
construct_destination() {
    local platform="$1"
    local device_or_simulator="${2:-}"
    local arch="${3:-}"

    # Clean up "OS:latest" which is invalid in xcodebuild
    device_or_simulator="${device_or_simulator//,OS:latest/}"
    device_or_simulator="${device_or_simulator//OS:latest/}"

    case "$platform" in
        "iOS Simulator")
            if [ -z "$device_or_simulator" ]; then
                # Use first available simulator ID for reliable builds
                local simulator_id
                simulator_id=$(_get_first_available_simulator_id "iOS Simulator")
                if [ -n "$simulator_id" ]; then
                    echo "id=${simulator_id}"
                    return 0
                else
                    # Fallback to generic placeholder
                    echo "platform=iOS Simulator,name=Any iOS Simulator Device"
                    return 0
                fi
            fi
            if ! _validate_simulator_exists "$device_or_simulator"; then
                echo "⚠️  Simulator not found: $device_or_simulator" >&2
                return 2
            fi
            echo "platform=iOS Simulator,name=${device_or_simulator}"
            ;;

        "iOS"|"iOS Device")
            if [ -z "$device_or_simulator" ]; then
                echo "generic/platform=iOS"
            else
                if ! _validate_device_exists "$device_or_simulator"; then
                    echo "⚠️  Device not found: $device_or_simulator" >&2
                    return 2
                fi
                echo "id=${device_or_simulator}"
            fi
            ;;

        "macOS")
            if [ -n "$arch" ]; then
                echo "platform=macOS,arch=${arch}"
            else
                echo "platform=macOS"
            fi
            ;;

        "watchOS Simulator")
            if [ -z "$device_or_simulator" ]; then
                device_or_simulator=$(_get_first_available_simulator "watchOS Simulator")
                if [ -z "$device_or_simulator" ]; then
                    echo "platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)"
                    return 0
                fi
            fi
            if ! _validate_simulator_exists "$device_or_simulator"; then
                echo "⚠️  Simulator not found: $device_or_simulator" >&2
                return 2
            fi
            echo "platform=watchOS Simulator,name=${device_or_simulator}"
            ;;

        "watchOS"|"watchOS Device")
            if [ -z "$device_or_simulator" ]; then
                echo "generic/platform=watchOS"
            else
                echo "id=${device_or_simulator}"
            fi
            ;;

        "tvOS Simulator")
            if [ -z "$device_or_simulator" ]; then
                device_or_simulator=$(_get_first_available_simulator "tvOS Simulator")
                if [ -z "$device_or_simulator" ]; then
                    echo "platform=tvOS Simulator,name=Apple TV 4K (3rd generation)"
                    return 0
                fi
            fi
            if ! _validate_simulator_exists "$device_or_simulator"; then
                echo "⚠️  Simulator not found: $device_or_simulator" >&2
                return 2
            fi
            echo "platform=tvOS Simulator,name=${device_or_simulator}"
            ;;

        "tvOS"|"tvOS Device")
            if [ -z "$device_or_simulator" ]; then
                echo "generic/platform=tvOS"
            else
                echo "id=${device_or_simulator}"
            fi
            ;;

        "visionOS Simulator")
            if [ -z "$device_or_simulator" ]; then
                device_or_simulator=$(_get_first_available_simulator "visionOS Simulator")
                if [ -z "$device_or_simulator" ]; then
                    echo "platform=visionOS Simulator,name=Apple Vision Pro"
                    return 0
                fi
            fi
            if ! _validate_simulator_exists "$device_or_simulator"; then
                echo "⚠️  Simulator not found: $device_or_simulator" >&2
                return 2
            fi
            echo "platform=visionOS Simulator,name=${device_or_simulator}"
            ;;

        "visionOS"|"visionOS Device")
            if [ -z "$device_or_simulator" ]; then
                echo "generic/platform=visionOS"
            else
                echo "id=${device_or_simulator}"
            fi
            ;;

        *)
            echo "⚠️  Invalid platform: $platform" >&2
            return 1
            ;;
    esac

    return 0
}

# Validate a destination string
# Arguments:
#   $1 - destination string to validate
# Returns: 0 on valid, 1 on invalid format, 2 on simulator/device not found
validate_destination() {
    local destination="$1"

    # Check for empty destination
    if [ -z "$destination" ]; then
        echo "⚠️  Empty destination string" >&2
        return 1
    fi

    # Check for simulator destination
    if [[ "$destination" == *"Simulator,name="* ]]; then
        local simulator_name
        simulator_name=$(echo "$destination" | sed 's/.*name=//' | cut -d',' -f1)
        if ! _validate_simulator_exists "$simulator_name"; then
            return 2
        fi
        return 0
    fi

    # Check for device/simulator ID destination (always valid - let xcodebuild handle it)
    if [[ "$destination" == "id="* ]]; then
        return 0
    fi

    # Check for generic/platform destinations
    if [[ "$destination" == "generic/platform="* ]] || [[ "$destination" == "platform="* ]]; then
        return 0
    fi

    echo "⚠️  Invalid destination format: $destination" >&2
    return 1
}

# Get xcrun availability status (for external checks)
is_xcrun_available() {
    _check_xcrun_available
}
