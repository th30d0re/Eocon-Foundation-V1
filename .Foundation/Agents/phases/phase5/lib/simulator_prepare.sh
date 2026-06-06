#!/usr/bin/env bash

# simulator_prepare.sh - Unified simulator preparation workflow for testing
# Provides a single function to prepare simulators with all necessary configurations

set -euo pipefail

# Verify bash is running
if [ -z "${BASH_VERSION:-}" ]; then
    echo "Error: This library requires bash" >&2
    return 1 2>/dev/null || exit 1
fi

# Path resolution
PREPARE_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source required libraries
source "${PREPARE_LIB_DIR}/simulator.sh"
source "${PREPARE_LIB_DIR}/axe_helpers.sh"

# ─────────────────────────────────────────────────────────────────────────────
# Simulator Preparation Workflow
# ─────────────────────────────────────────────────────────────────────────────

# Prepare simulator for testing with full configuration
# Arguments:
#   $1 - simulator name or UUID
#   $2 - app path (optional)
#   $3 - bundle ID (optional)
#   $4 - configuration JSON (optional)
#
# Configuration JSON structure:
# {
#   "autoboot": true,
#   "location": {"lat": 37.7749, "lon": -122.4194},
#   "appearance": "dark" or "light",
#   "statusBar": {
#     "time": "9:41",
#     "battery": 100,
#     "wifi": 3,
#     "cellular": 4
#   },
#   "erase": false,
#   "waitForBoot": true
# }
#
# Returns: simulator UUID
prepare_simulator_for_testing() {
    local simulator="$1"
    local app_path="${2:-}"
    local bundle_id="${3:-}"
    local config="$4"
    if [ -z "$config" ]; then
        config="{}"
    fi
    
    # Parse configuration (use jq if available, otherwise use defaults)
    local autoboot=true
    local erase=false
    local wait_for_boot=true
    local location_lat=""
    local location_lon=""
    local appearance=""
    local statusbar_time=""
    local statusbar_battery=""
    local statusbar_wifi=""
    local statusbar_cellular=""
    
    if command -v jq >/dev/null 2>&1 && [ -n "$config" ] && [ "$config" != "{}" ]; then
        autoboot=$(echo "$config" | jq -r '.autoboot // true')
        erase=$(echo "$config" | jq -r '.erase // false')
        wait_for_boot=$(echo "$config" | jq -r '.waitForBoot // true')
        location_lat=$(echo "$config" | jq -r '.location.lat // empty')
        location_lon=$(echo "$config" | jq -r '.location.lon // empty')
        appearance=$(echo "$config" | jq -r '.appearance // empty')
        statusbar_time=$(echo "$config" | jq -r '.statusBar.time // empty')
        statusbar_battery=$(echo "$config" | jq -r '.statusBar.battery // empty')
        statusbar_wifi=$(echo "$config" | jq -r '.statusBar.wifi // empty')
        statusbar_cellular=$(echo "$config" | jq -r '.statusBar.cellular // empty')
    fi
    
    # Resolve to UUID
    local uuid
    uuid=$(get_simulator_by_name "$simulator") || {
        echo "Error: Failed to resolve simulator: $simulator" >&2
        return 20
    }
    
    echo "Preparing simulator: $uuid"
    
    # Erase if requested
    if [ "$erase" = "true" ]; then
        echo "Erasing simulator..."
        erase_simulator "$uuid" >/dev/null || true
    fi
    
    # Boot if requested and not already booted
    if [ "$autoboot" = "true" ]; then
        if [ "$(is_simulator_booted "$uuid")" != "true" ]; then
            echo "Booting simulator..."
            boot_simulator "$uuid" "$wait_for_boot" >/dev/null || {
                echo "Error: Failed to boot simulator" >&2
                return 22
            }
        else
            echo "Simulator already booted"
        fi
    fi
    
    # Apply location configuration
    if [ -n "$location_lat" ] && [ -n "$location_lon" ]; then
        echo "Setting GPS location: $location_lat, $location_lon"
        set_simulator_location "$uuid" "$location_lat" "$location_lon" >/dev/null || {
            echo "Warning: Failed to set location" >&2
        }
    fi
    
    # Apply appearance configuration
    if [ -n "$appearance" ]; then
        echo "Setting appearance: $appearance"
        set_simulator_appearance "$uuid" "$appearance" >/dev/null || {
            echo "Warning: Failed to set appearance" >&2
        }
    fi
    
    # Apply status bar overrides
    if [ -n "$statusbar_time" ] || [ -n "$statusbar_battery" ]; then
        echo "Configuring status bar..."
        set_simulator_statusbar "$uuid" "$statusbar_time" "$statusbar_battery" "$statusbar_wifi" "$statusbar_cellular" >/dev/null || {
            echo "Warning: Failed to configure status bar" >&2
        }
    fi
    
    # Install app if provided
    if [ -n "$app_path" ]; then
        if [ ! -d "$app_path" ]; then
            echo "Warning: App path not found: $app_path" >&2
        else
            echo "Installing app: $app_path"
            install_app_simulator "$uuid" "$app_path" >/dev/null || {
                echo "Warning: Failed to install app" >&2
            }
        fi
    fi
    
    # Launch app if bundle ID provided
    if [ -n "$bundle_id" ]; then
        echo "Launching app: $bundle_id"
        launch_app_simulator "$uuid" "$bundle_id" >/dev/null || {
            echo "Warning: Failed to launch app" >&2
        }
        
        # Small delay to let app start
        sleep 2
    fi
    
    echo "Simulator prepared: $uuid"
    echo "$uuid"
    return 0
}

# Prepare simulator with session-aware defaults
# This function loads configuration from session store if available
# Arguments:
#   $1 - simulator name or UUID
#   $2 - app path (optional)
#   $3 - bundle ID (optional)
#   $4 - override config JSON (optional)
prepare_simulator_with_session() {
    local simulator="$1"
    local app_path="${2:-}"
    local bundle_id="${3:-}"
    local override_config="$4"
    if [ -z "$override_config" ]; then
        override_config="{}"
    fi
    
    # Check if session_store.sh is available
    local session_config="{}"
    if [ -f "${PREPARE_LIB_DIR}/session_store.sh" ]; then
        source "${PREPARE_LIB_DIR}/session_store.sh"
        
        # Try to load session preferences
        local session_simulator
        local session_location
        local session_appearance
        
        session_simulator=$(session_get "test.simulator" 2>/dev/null || echo "")
        session_location=$(session_get "test.location" 2>/dev/null || echo "")
        session_appearance=$(session_get "test.appearance" 2>/dev/null || echo "")
        
        # Build session config
        if command -v jq >/dev/null 2>&1; then
            session_config=$(jq -n \
                --arg sim "${session_simulator:-$simulator}" \
                --arg loc "$session_location" \
                --arg app "$session_appearance" \
                '{
                    simulator: $sim,
                    location: ($loc | if . == "" then null else fromjson end),
                    appearance: ($app | if . == "" then null else . end)
                }')
        fi
        
        # Use session simulator if not explicitly provided
        if [ -z "$simulator" ] && [ -n "$session_simulator" ]; then
            simulator="$session_simulator"
        fi
    fi
    
    # Merge session config with override config
    local final_config="$override_config"
    if command -v jq >/dev/null 2>&1 && [ -n "$session_config" ] && [ "$session_config" != "{}" ]; then
        final_config=$(echo "$session_config" "$override_config" | jq -s '.[0] * .[1]')
    fi
    
    # Prepare simulator
    prepare_simulator_for_testing "$simulator" "$app_path" "$bundle_id" "$final_config"
}

# Quick boot function - just boot without configuration
# Arguments:
#   $1 - simulator name or UUID
quick_boot_simulator() {
    local simulator="$1"
    
    local uuid
    uuid=$(get_simulator_by_name "$simulator") || return $?
    
    if [ "$(is_simulator_booted "$uuid")" = "true" ]; then
        echo "$uuid"
        return 0
    fi
    
    boot_simulator "$uuid" true >/dev/null
    echo "$uuid"
}

# Shutdown and cleanup function
# Arguments:
#   $1 - simulator UUID
cleanup_simulator() {
    local uuid="$1"
    
    echo "Cleaning up simulator: $uuid"
    
    # Clear location override
    reset_simulator_location "$uuid" >/dev/null 2>&1 || true
    
    # Clear status bar overrides
    clear_simulator_statusbar "$uuid" >/dev/null 2>&1 || true
    
    # Shutdown simulator
    shutdown_simulator "$uuid" >/dev/null 2>&1 || true
    
    echo "Simulator cleanup complete"
}

# Batch prepare multiple simulators
# Arguments:
#   $@ - list of simulator names or UUIDs
prepare_multiple_simulators() {
    local simulators=("$@")
    local prepared_uuids=()
    
    for sim in "${simulators[@]}"; do
        echo "Preparing simulator: $sim"
        local uuid
        uuid=$(prepare_simulator_for_testing "$sim") || {
            echo "Warning: Failed to prepare $sim, skipping" >&2
            continue
        }
        prepared_uuids+=("$uuid")
    done
    
    # Return prepared UUIDs as JSON array if jq available
    if command -v jq >/dev/null 2>&1; then
        printf '%s\n' "${prepared_uuids[@]}" | jq -R . | jq -s .
    else
        printf '%s\n' "${prepared_uuids[@]}"
    fi
}

# Export functions for use by other scripts
export -f prepare_simulator_for_testing
export -f prepare_simulator_with_session
export -f quick_boot_simulator
export -f cleanup_simulator
export -f prepare_multiple_simulators
