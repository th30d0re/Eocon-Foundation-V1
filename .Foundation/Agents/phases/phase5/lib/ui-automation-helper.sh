#!/usr/bin/env bash

# ui-automation-helper.sh - CLI wrapper for AXe UI automation
# Provides command-line interface for MCP tools to interact with AXe

set -euo pipefail

# Verify bash is running
if [ -z "${BASH_VERSION:-}" ]; then
    echo "Error: This library requires bash" >&2
    return 1 2>/dev/null || exit 1
fi

# Path resolution
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PHASE5_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Source libraries
source "${SCRIPT_DIR}/axe_helpers.sh"
source "${SCRIPT_DIR}/simulator.sh"

# Default values
ACTION=""
SIMULATOR_UUID=""
X_COORD=""
Y_COORD=""
IDENTIFIER=""
LABEL=""
DIRECTION=""
TEXT=""
DURATION="1.0"
OUTPUT_PATH=""
BUTTON=""
KEY=""
KEY_SEQUENCE=""
JSON_OUTPUT_FLAG=""

# Usage information
usage() {
    cat << EOF
Usage: ui-automation-helper.sh [OPTIONS]

UI Automation Helper for iOS Simulators using AXe

OPTIONS:
  --uuid <uuid>           Simulator UUID (required)
  --json-output           Output in JSON format
  
ACTIONS:
  --describe-ui           Get full UI hierarchy
  --tap                   Tap at coordinates or by element
    --x <x>               X coordinate (with --y)
    --y <y>               Y coordinate (with --x)
    --id <id>             Accessibility identifier
    --label <label>       Accessibility label
  --swipe                 Swipe gesture
    --direction <dir>     Direction (up/down/left/right)
  --type                  Type text
    --text <text>         Text to type
  --long-press            Long press gesture
    --x <x>               X coordinate
    --y <y>               Y coordinate
    --duration <sec>      Duration in seconds (default: 1.0)
  --screenshot            Capture screenshot
    --path <path>         Output path
  --button                Hardware button press
    --button <btn>        Button name (home/lock/volumeUp/volumeDown)
  --key-press             Simulate key press
    --key <key>           Key name
  --key-sequence          Type key sequence
    --sequence <keys>     Space-separated key names
  --find-element          Find element by identifier
    --id <id>             Accessibility identifier
  --find-by-label         Find element by label
    --label <label>       Accessibility label
  --wait-for-element      Wait for element to appear
    --id <id>             Accessibility identifier
    --timeout <sec>       Timeout in seconds (default: 10)
  --get-frame             Get element frame
    --id <id>             Accessibility identifier

EXAMPLES:
  # Describe UI hierarchy
  ui-automation-helper.sh --uuid ABC123 --describe-ui --json-output
  
  # Tap at coordinates
  ui-automation-helper.sh --uuid ABC123 --tap --x 100 --y 200
  
  # Tap by identifier
  ui-automation-helper.sh --uuid ABC123 --tap --id "loginButton"
  
  # Swipe down
  ui-automation-helper.sh --uuid ABC123 --swipe --direction down
  
  # Type text
  ui-automation-helper.sh --uuid ABC123 --type --text "Hello World"
  
  # Screenshot
  ui-automation-helper.sh --uuid ABC123 --screenshot --path screenshot.png

EOF
    exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help|-h)
            usage
            ;;
        --uuid)
            SIMULATOR_UUID="$2"
            shift 2
            ;;
        --json-output)
            JSON_OUTPUT_FLAG="true"
            export JSON_OUTPUT="true"
            shift
            ;;
        --describe-ui)
            ACTION="describe-ui"
            shift
            ;;
        --tap)
            ACTION="tap"
            shift
            ;;
        --swipe)
            ACTION="swipe"
            shift
            ;;
        --type)
            ACTION="type"
            shift
            ;;
        --long-press)
            ACTION="long-press"
            shift
            ;;
        --screenshot)
            ACTION="screenshot"
            shift
            ;;
        --button)
            if [ -z "${2:-}" ] || [[ "$2" == --* ]]; then
                ACTION="button"
            else
                BUTTON="$2"
                shift
            fi
            shift
            ;;
        --key-press)
            ACTION="key-press"
            shift
            ;;
        --key-sequence)
            ACTION="key-sequence"
            shift
            ;;
        --find-element)
            ACTION="find-element"
            shift
            ;;
        --find-by-label)
            ACTION="find-by-label"
            shift
            ;;
        --wait-for-element)
            ACTION="wait-for-element"
            shift
            ;;
        --get-frame)
            ACTION="get-frame"
            shift
            ;;
        --x)
            X_COORD="$2"
            shift 2
            ;;
        --y)
            Y_COORD="$2"
            shift 2
            ;;
        --id)
            IDENTIFIER="$2"
            shift 2
            ;;
        --label)
            LABEL="$2"
            shift 2
            ;;
        --direction)
            DIRECTION="$2"
            shift 2
            ;;
        --text)
            TEXT="$2"
            shift 2
            ;;
        --duration)
            DURATION="$2"
            shift 2
            ;;
        --path)
            OUTPUT_PATH="$2"
            shift 2
            ;;
        --key)
            KEY="$2"
            shift 2
            ;;
        --sequence)
            KEY_SEQUENCE="$2"
            shift 2
            ;;
        --timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage
            ;;
    esac
done

# Validate required parameters
if [ -z "$SIMULATOR_UUID" ]; then
    echo "Error: --uuid is required" >&2
    exit 1
fi

if [ -z "$ACTION" ]; then
    echo "Error: No action specified" >&2
    usage
fi

# Execute action
case "$ACTION" in
    describe-ui)
        axe_describe_ui "$SIMULATOR_UUID"
        ;;
    
    tap)
        if [ -n "$X_COORD" ] && [ -n "$Y_COORD" ]; then
            axe_tap "$SIMULATOR_UUID" "$X_COORD" "$Y_COORD"
        elif [ -n "$IDENTIFIER" ]; then
            axe_tap_element "$SIMULATOR_UUID" "$IDENTIFIER"
        elif [ -n "$LABEL" ]; then
            axe_tap_label "$SIMULATOR_UUID" "$LABEL"
        else
            echo "Error: --tap requires either (--x and --y) or --id or --label" >&2
            exit 1
        fi
        ;;
    
    swipe)
        if [ -z "$DIRECTION" ]; then
            echo "Error: --swipe requires --direction" >&2
            exit 1
        fi
        axe_swipe "$SIMULATOR_UUID" "$DIRECTION"
        ;;
    
    type)
        if [ -z "$TEXT" ]; then
            echo "Error: --type requires --text" >&2
            exit 1
        fi
        axe_type_text "$SIMULATOR_UUID" "$TEXT"
        ;;
    
    long-press)
        if [ -z "$X_COORD" ] || [ -z "$Y_COORD" ]; then
            echo "Error: --long-press requires --x and --y" >&2
            exit 1
        fi
        axe_long_press "$SIMULATOR_UUID" "$X_COORD" "$Y_COORD" "$DURATION"
        ;;
    
    screenshot)
        if [ -z "$OUTPUT_PATH" ]; then
            echo "Error: --screenshot requires --path" >&2
            exit 1
        fi
        axe_screenshot "$SIMULATOR_UUID" "$OUTPUT_PATH"
        ;;
    
    button)
        if [ -z "$BUTTON" ]; then
            echo "Error: --button requires button name" >&2
            exit 1
        fi
        axe_hardware_button "$SIMULATOR_UUID" "$BUTTON"
        ;;
    
    key-press)
        if [ -z "$KEY" ]; then
            echo "Error: --key-press requires --key" >&2
            exit 1
        fi
        axe_key_press "$SIMULATOR_UUID" "$KEY"
        ;;
    
    key-sequence)
        if [ -z "$KEY_SEQUENCE" ]; then
            echo "Error: --key-sequence requires --sequence" >&2
            exit 1
        fi
        axe_key_sequence "$SIMULATOR_UUID" "$KEY_SEQUENCE"
        ;;
    
    find-element)
        if [ -z "$IDENTIFIER" ]; then
            echo "Error: --find-element requires --id" >&2
            exit 1
        fi
        axe_find_element "$SIMULATOR_UUID" "$IDENTIFIER"
        ;;
    
    find-by-label)
        if [ -z "$LABEL" ]; then
            echo "Error: --find-by-label requires --label" >&2
            exit 1
        fi
        axe_find_by_label "$SIMULATOR_UUID" "$LABEL"
        ;;
    
    wait-for-element)
        if [ -z "$IDENTIFIER" ]; then
            echo "Error: --wait-for-element requires --id" >&2
            exit 1
        fi
        TIMEOUT="${TIMEOUT:-10}"
        axe_wait_for_element "$SIMULATOR_UUID" "$IDENTIFIER" "$TIMEOUT"
        ;;
    
    get-frame)
        if [ -z "$IDENTIFIER" ]; then
            echo "Error: --get-frame requires --id" >&2
            exit 1
        fi
        axe_get_element_frame "$SIMULATOR_UUID" "$IDENTIFIER"
        ;;
    
    *)
        echo "Error: Unknown action: $ACTION" >&2
        exit 1
        ;;
esac
