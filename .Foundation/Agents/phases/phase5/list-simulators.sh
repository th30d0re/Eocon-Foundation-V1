#!/usr/bin/env bash

# list-simulators.sh - Comprehensive simulator management and listing
# Enhanced with full simulator management capabilities

set -euo pipefail

# Path resolution
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"
FOUNDATION_LIB_DIR="$(cd "${SCRIPT_DIR}/../../../lib" && pwd)"

# Load Foundation helpers
HELPERS_LIB="${FOUNDATION_LIB_DIR}/helpers.sh"
if [ -f "$HELPERS_LIB" ]; then
    # shellcheck disable=SC1090
    source "$HELPERS_LIB"

    # Check shell compatibility
    if type check_shell_compatibility &>/dev/null; then
        check_shell_compatibility || exit 11
    fi
fi

# Source simulator library
source "${LIB_DIR}/simulator.sh"

# Default values
PLATFORM_FILTER=""
STATE_FILTER=""
NAME_PATTERN=""
JSON_OUTPUT_FLAG=""
INTERACTIVE=false
MANAGEMENT_ACTION=""
SIMULATOR_NAME=""
SIMULATOR_UUID=""
WAIT_FOR_BOOT=true

# Usage information
usage() {
    cat << EOF
Usage: list-simulators.sh [OPTIONS]

Comprehensive Simulator Management

LISTING OPTIONS:
  --platform <name>       Filter by platform (iOS, watchOS, tvOS, visionOS)
  --state <state>         Filter by state (Booted, Shutdown)
  --name <pattern>        Filter by name pattern (regex)
  --json                  JSON output for MCP integration
  --json-output           Alias for --json
  --interactive           Interactive selection mode

MANAGEMENT ACTIONS:
  --boot <name>           Boot simulator by name
  --shutdown <uuid>       Shutdown simulator by UUID
  --erase <name>          Erase simulator (with confirmation)
  --clone <src> <name>    Clone simulator
  --get-booted            Get currently booted simulator UUID
  --is-booted <uuid>      Check if simulator is booted
  --no-wait               Don't wait for boot completion (with --boot)

CONFIGURATION ACTIONS:
  --set-location <uuid> <lat> <lon>    Set GPS location
  --reset-location <uuid>              Reset GPS location
  --set-appearance <uuid> <mode>       Set appearance (dark/light)
  --set-statusbar <uuid> [opts]        Override status bar

APP MANAGEMENT:
  --install <uuid> <path>              Install app
  --launch <uuid> <bundle_id>          Launch app
  --terminate <uuid> <bundle_id>       Terminate app
  --get-app-path <uuid> <bundle_id>    Get installed app path

EXAMPLES:
  # List all simulators
  list-simulators.sh

  # List only booted iOS simulators
  list-simulators.sh --platform iOS --state Booted

  # Boot a simulator
  list-simulators.sh --boot "iPhone 16 Pro"

  # Get JSON output for MCP
  list-simulators.sh --platform iOS --json-output

  # Interactive mode
  list-simulators.sh --interactive

  # Set location
  list-simulators.sh --set-location ABC-123 37.7749 -122.4194

EOF
    exit 0
}

# Parse arguments
POSITIONAL_ARGS=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help|-h)
            usage
            ;;
        --platform)
            PLATFORM_FILTER="$2"
            shift 2
            ;;
        --state)
            STATE_FILTER="$2"
            shift 2
            ;;
        --name)
            NAME_PATTERN="$2"
            shift 2
            ;;
        --json|--json-output)
            JSON_OUTPUT_FLAG="true"
            export JSON_OUTPUT="true"
            shift
            ;;
        --interactive)
            INTERACTIVE=true
            shift
            ;;
        --boot)
            MANAGEMENT_ACTION="boot"
            SIMULATOR_NAME="$2"
            shift 2
            ;;
        --shutdown)
            MANAGEMENT_ACTION="shutdown"
            SIMULATOR_UUID="$2"
            shift 2
            ;;
        --erase)
            MANAGEMENT_ACTION="erase"
            SIMULATOR_NAME="$2"
            shift 2
            ;;
        --clone)
            MANAGEMENT_ACTION="clone"
            POSITIONAL_ARGS+=("$2" "$3")
            shift 3
            ;;
        --get-booted)
            MANAGEMENT_ACTION="get-booted"
            shift
            ;;
        --is-booted)
            MANAGEMENT_ACTION="is-booted"
            SIMULATOR_UUID="$2"
            shift 2
            ;;
        --no-wait)
            WAIT_FOR_BOOT=false
            shift
            ;;
        --set-location)
            MANAGEMENT_ACTION="set-location"
            POSITIONAL_ARGS+=("$2" "$3" "$4")
            shift 4
            ;;
        --reset-location)
            MANAGEMENT_ACTION="reset-location"
            SIMULATOR_UUID="$2"
            shift 2
            ;;
        --set-appearance)
            MANAGEMENT_ACTION="set-appearance"
            POSITIONAL_ARGS+=("$2" "$3")
            shift 3
            ;;
        --set-statusbar)
            MANAGEMENT_ACTION="set-statusbar"
            shift
            # Collect remaining args for status bar
            while [[ $# -gt 0 ]] && [[ "$1" != --* ]]; do
                POSITIONAL_ARGS+=("$1")
                shift
            done
            ;;
        --install)
            MANAGEMENT_ACTION="install"
            POSITIONAL_ARGS+=("$2" "$3")
            shift 3
            ;;
        --launch)
            MANAGEMENT_ACTION="launch"
            POSITIONAL_ARGS+=("$2" "$3")
            shift 3
            ;;
        --terminate)
            MANAGEMENT_ACTION="terminate"
            POSITIONAL_ARGS+=("$2" "$3")
            shift 3
            ;;
        --get-app-path)
            MANAGEMENT_ACTION="get-app-path"
            POSITIONAL_ARGS+=("$2" "$3")
            shift 3
            ;;
        --uuid)
            SIMULATOR_UUID="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage
            ;;
    esac
done

# Execute management actions
if [ -n "$MANAGEMENT_ACTION" ]; then
    case "$MANAGEMENT_ACTION" in
        boot)
            boot_simulator "$SIMULATOR_NAME" "$WAIT_FOR_BOOT"
            ;;
        shutdown)
            shutdown_simulator "$SIMULATOR_UUID"
            ;;
        erase)
            if [ "$INTERACTIVE" = true ] || [ "$JSON_OUTPUT_FLAG" = "true" ]; then
                erase_simulator "$SIMULATOR_NAME"
            else
                echo "WARNING: This will erase all data from simulator: $SIMULATOR_NAME"
                read -p "Are you sure? (yes/no): " -r
                if [[ $REPLY == "yes" ]]; then
                    erase_simulator "$SIMULATOR_NAME"
                else
                    echo "Erase cancelled"
                    exit 0
                fi
            fi
            ;;
        clone)
            clone_simulator "${POSITIONAL_ARGS[0]}" "${POSITIONAL_ARGS[1]}"
            ;;
        get-booted)
            get_booted_simulator
            ;;
        is-booted)
            is_simulator_booted "$SIMULATOR_UUID"
            ;;
        set-location)
            set_simulator_location "${POSITIONAL_ARGS[0]}" "${POSITIONAL_ARGS[1]}" "${POSITIONAL_ARGS[2]}"
            ;;
        reset-location)
            reset_simulator_location "$SIMULATOR_UUID"
            ;;
        set-appearance)
            set_simulator_appearance "${POSITIONAL_ARGS[0]}" "${POSITIONAL_ARGS[1]}"
            ;;
        set-statusbar)
            set_simulator_statusbar "${POSITIONAL_ARGS[@]}"
            ;;
        install)
            install_app_simulator "${POSITIONAL_ARGS[0]}" "${POSITIONAL_ARGS[1]}"
            ;;
        launch)
            launch_app_simulator "${POSITIONAL_ARGS[0]}" "${POSITIONAL_ARGS[1]}"
            ;;
        terminate)
            terminate_app_simulator "${POSITIONAL_ARGS[0]}" "${POSITIONAL_ARGS[1]}"
            ;;
        get-app-path)
            get_simulator_app_path "${POSITIONAL_ARGS[0]}" "${POSITIONAL_ARGS[1]}"
            ;;
        *)
            echo "Error: Unknown management action: $MANAGEMENT_ACTION" >&2
            exit 1
            ;;
    esac
    exit 0
fi

# List simulators
if [ "$JSON_OUTPUT_FLAG" = "true" ]; then
    list_simulators "$PLATFORM_FILTER" "$STATE_FILTER" "$NAME_PATTERN"
elif [ "$INTERACTIVE" = true ]; then
    echo "Interactive Simulator Selection"
    echo "================================"
    echo ""

    # Get booted simulator
    BOOTED=$(get_booted_simulator || echo "")
    if [ -n "$BOOTED" ]; then
        echo "Currently booted: $BOOTED"
        echo ""
    fi

    # List simulators and let user choose
    mapfile -t SIMULATOR_LIST < <(xcrun simctl list devices available | grep -E "^\s+(iPhone|iPad)" | sed 's/^[[:space:]]*//')

    if [ ${#SIMULATOR_LIST[@]} -eq 0 ]; then
        echo "No simulators available"
        exit 1
    fi

    echo "Available Simulators:"
    for i in "${!SIMULATOR_LIST[@]}"; do
        echo "$((i+1)). ${SIMULATOR_LIST[$i]}"
    done
    echo ""

    read -p "Select simulator number (or 'q' to quit): " -r selection

    if [[ "$selection" == "q" ]]; then
        exit 0
    fi

    if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt ${#SIMULATOR_LIST[@]} ]; then
        echo "Invalid selection"
        exit 1
    fi

    SELECTED="${SIMULATOR_LIST[$((selection-1))]}"
    DEVICE_NAME=$(echo "$SELECTED" | sed 's/ ([A-F0-9-]*).*//')
    DEVICE_UUID=$(echo "$SELECTED" | grep -o '([A-F0-9-]*)' | tr -d '()')

    echo ""
    echo "Selected Device: $DEVICE_NAME"
    echo "UUID: $DEVICE_UUID"
    echo ""
    echo "Destination string for xcodebuild:"
    echo "platform=iOS Simulator,id=$DEVICE_UUID"
    echo ""
    echo "or"
    echo ""
    echo "platform=iOS Simulator,name=$DEVICE_NAME"

else
    # Default: formatted text output
    echo "Available Simulators"
    echo "===================="
    echo ""

    # Get booted simulator
    BOOTED=$(get_booted_simulator || echo "")
    if [ -n "$BOOTED" ]; then
        echo "🟢 Currently booted: $BOOTED"
        echo ""
    fi

    # Use platform filter if specified
    if [ -n "$PLATFORM_FILTER" ]; then
        GREP_PATTERN="$PLATFORM_FILTER"
    else
        GREP_PATTERN="iPhone|iPad|Apple Watch|Apple TV|Apple Vision"
    fi

    # List devices
    xcrun simctl list devices available | grep -E "^\s+($GREP_PATTERN)" | while IFS= read -r line; do
        device=$(echo "$line" | sed 's/^[[:space:]]*//' | sed 's/ ([A-F0-9-]*).*//')
        uuid=$(echo "$line" | grep -o '([A-F0-9-]*)' | head -1 | tr -d '()')

        # Check boot state
        STATE="Shutdown"
        if is_simulator_booted "$uuid" | grep -q "true"; then
            STATE="🟢 Booted"
        fi

        # Apply state filter
        if [ -n "$STATE_FILTER" ]; then
            if [[ "$STATE" != *"$STATE_FILTER"* ]]; then
                continue
            fi
        fi

        # Apply name pattern
        if [ -n "$NAME_PATTERN" ]; then
            if ! echo "$device" | grep -qE "$NAME_PATTERN"; then
                continue
            fi
        fi

        echo "Device: $device"
        echo "State:  $STATE"
        echo "UUID:   $uuid"
        echo "Destination: platform=iOS Simulator,id=$uuid"
        echo "---"
    done

    echo ""
    echo "Usage Examples:"
    echo "==============="
    echo ""
    echo "# Boot a simulator:"
    echo "list-simulators.sh --boot \"iPhone 16 Pro\""
    echo ""
    echo "# Use in xcodebuild:"
    echo "xcodebuild test -destination \"platform=iOS Simulator,name=iPhone 16 Pro\" ..."
    echo ""
    echo "# Get JSON output:"
    echo "list-simulators.sh --json-output"
    echo ""
    echo "NOTE: Prefer 'platform=iOS Simulator,name=<device>' format for portability."
fi
