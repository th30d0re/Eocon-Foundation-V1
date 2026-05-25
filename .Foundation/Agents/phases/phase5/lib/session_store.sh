#!/usr/bin/env bash
# Library: session_store.sh
# Purpose: Session management for persistent defaults and flag learning
# Dependencies: jq (optional - graceful degradation if unavailable)
#
# Functions:
#   session_load()                    - Load defaults from .foundation-session.json
#   session_save()                    - Atomic write to session file
#   session_get_default(key)          - Retrieve default value for key
#   session_set_default(key, value)   - Set default value for key
#   session_track_flag(flag, value)   - Track flag usage with timestamp
#   session_should_offer_persist()    - Check if flag used 3+ times in 7 days
#   cleanup_old_logs(days)            - Remove logs older than N days
#
# Environment Variables:
#   SESSION_DEFAULTS_ENABLED      - Set to "false" to globally disable (default: true)
#   SESSION_LEARNING_THRESHOLD    - Number of uses before offering persist (default: 3)
#   SESSION_LEARNING_WINDOW_DAYS  - Time window for learning in days (default: 7)
#   PROJECT_ROOT                  - Root directory of the project
#
# JSON Schema:
#   {
#     "version": "1.0",
#     "lastUpdated": "2024-01-15T10:30:00Z",
#     "flagHistory": [
#       {"flag": "--scheme", "value": "MyApp", "count": 3, "lastUsed": "..."}
#     ],
#     "defaults": {
#       "scheme": "MyApp",
#       "platform": "iOS Simulator",
#       "simulator": "iPhone 16",
#       "configuration": "Debug",
#       "arch": "arm64"
#     },
#     "preferences": {
#       "fancyUI": true,
#       "incrementalBuilds": true
#     }
#   }
#
# Usage:
#   source session_store.sh
#   session_load
#   scheme=$(session_get_default "scheme")

set -euo pipefail

# Verify bash is running
if [ -z "${BASH_VERSION:-}" ]; then
    echo "Error: This library requires bash" >&2
    return 1 2>/dev/null || exit 1
fi

# Path resolution using BASH_SOURCE[0] for PATH-installed agents
SESSION_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SESSION_PHASE5_DIR="$(cd "${SESSION_LIB_DIR}/.." && pwd)"
SESSION_PROJECT_ROOT="${PROJECT_ROOT:-$(cd "${SESSION_PHASE5_DIR}/../../../.." && pwd)}"

# Configuration
SESSION_DEFAULTS_ENABLED="${SESSION_DEFAULTS_ENABLED:-true}"
SESSION_LEARNING_THRESHOLD="${SESSION_LEARNING_THRESHOLD:-3}"
SESSION_LEARNING_WINDOW_DAYS="${SESSION_LEARNING_WINDOW_DAYS:-7}"
SESSION_LOG_RETENTION_DAYS="${SESSION_LOG_RETENTION_DAYS:-3}"

# Session file path
SESSION_FILE="${SESSION_PROJECT_ROOT}/.foundation-session.json"

# Internal state
_JQ_AVAILABLE=""
_SESSION_LOADED="false"
_SESSION_DATA=""

# Check if jq is available
_check_jq_available() {
    if [ -z "$_JQ_AVAILABLE" ]; then
        if command -v jq &>/dev/null; then
            _JQ_AVAILABLE="true"
        else
            _JQ_AVAILABLE="false"
            echo "⚠️  jq not found, session features disabled" >&2
        fi
    fi
    [ "$_JQ_AVAILABLE" = "true" ]
}

# Check if session features are enabled
_is_session_enabled() {
    [ "${SESSION_DEFAULTS_ENABLED}" = "true" ] && _check_jq_available
}

# Get current ISO 8601 timestamp
_get_timestamp() {
    date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# Get timestamp N days ago in ISO 8601 format
_get_timestamp_days_ago() {
    local days="$1"
    local os_type
    os_type="$(uname -s)"

    local timestamp=""
    if [ "$os_type" = "Darwin" ]; then
        timestamp=$(date -u -v-"${days}"d +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null)
    elif [ "$os_type" = "Linux" ]; then
        timestamp=$(date -u -d "${days} days ago" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null)
    else
        # Try both approaches with suppressed errors
        timestamp=$(date -u -v-"${days}"d +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || \
                   date -u -d "${days} days ago" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null)
    fi

    if [ -z "$timestamp" ]; then
        echo "⚠️  Unable to calculate timestamp ${days} days ago, session learning disabled" >&2
    fi

    echo "$timestamp"
}

# Initialize empty session data
_init_session_data() {
    local timestamp
    timestamp=$(_get_timestamp)

    _SESSION_DATA=$(cat <<EOF
{
  "version": "1.0",
  "lastUpdated": "${timestamp}",
  "flagHistory": [],
  "defaults": {},
  "preferences": {
    "fancyUI": true,
    "incrementalBuilds": true
  }
}
EOF
)
}

# Load session from file
# Arguments: None
# Returns: 0 on success (or graceful init), 0 if session disabled (no-op)
session_load() {
    if ! _is_session_enabled; then
        return 0
    fi

    if [ -f "$SESSION_FILE" ]; then
        _SESSION_DATA=$(cat "$SESSION_FILE" 2>/dev/null || echo "")

        # Validate JSON
        if ! echo "$_SESSION_DATA" | jq empty 2>/dev/null; then
            echo "⚠️  Invalid session file, reinitializing" >&2
            _init_session_data
        fi
    else
        _init_session_data
    fi

    _SESSION_LOADED="true"

    # Cleanup old logs on load
    cleanup_old_logs "$SESSION_LOG_RETENTION_DAYS"

    return 0
}

# Save session to file atomically
# Arguments: None
# Returns: 0 on success, 0 if session disabled (no-op), 1 on write failure
session_save() {
    if ! _is_session_enabled; then
        return 0
    fi

    if [ -z "$_SESSION_DATA" ]; then
        return 1
    fi

    # Update lastUpdated timestamp
    local timestamp
    timestamp=$(_get_timestamp)
    _SESSION_DATA=$(echo "$_SESSION_DATA" | jq --arg ts "$timestamp" '.lastUpdated = $ts')

    # Atomic write using temp file + rename
    local temp_file="${SESSION_FILE}.tmp"

    if echo "$_SESSION_DATA" | jq '.' > "$temp_file" 2>/dev/null; then
        mv "$temp_file" "$SESSION_FILE"
        return 0
    else
        rm -f "$temp_file" 2>/dev/null
        echo "⚠️  Failed to save session file" >&2
        return 1
    fi
}

# Get default value for a key
# Arguments:
#   $1 - key name (scheme, platform, simulator, configuration, arch)
# Outputs: Value to stdout (empty if not set)
# Returns: 0 on success
session_get_default() {
    local key="$1"

    if ! _is_session_enabled; then
        echo ""
        return 0
    fi

    if [ "$_SESSION_LOADED" != "true" ]; then
        session_load || true
    fi

    if [ -z "$_SESSION_DATA" ]; then
        echo ""
        return 0
    fi

    local value
    value=$(echo "$_SESSION_DATA" | jq -r --arg key "$key" '.defaults[$key] // ""' 2>/dev/null || echo "")
    echo "$value"
}

# Set default value for a key
# Arguments:
#   $1 - key name
#   $2 - value
# Returns: 0 on success, 0 if session disabled (no-op)
session_set_default() {
    local key="$1"
    local value="$2"

    if ! _is_session_enabled; then
        return 0
    fi

    if [ "$_SESSION_LOADED" != "true" ]; then
        session_load || true
    fi

    if [ -z "$_SESSION_DATA" ]; then
        _init_session_data
    fi

    _SESSION_DATA=$(echo "$_SESSION_DATA" | jq --arg key "$key" --arg val "$value" '.defaults[$key] = $val')

    return 0
}

# Get preference value
# Arguments:
#   $1 - preference name
# Outputs: Value to stdout ("true", "false", or empty)
session_get_preference() {
    local key="$1"

    if ! _is_session_enabled; then
        echo ""
        return 0
    fi

    if [ "$_SESSION_LOADED" != "true" ]; then
        session_load || true
    fi

    if [ -z "$_SESSION_DATA" ]; then
        echo ""
        return 0
    fi

    local value
    value=$(echo "$_SESSION_DATA" | jq -r --arg key "$key" '.preferences[$key] // ""' 2>/dev/null || echo "")
    echo "$value"
}

# Set preference value
# Arguments:
#   $1 - preference name
#   $2 - value (true/false)
# Returns: 0 on success, 0 if session disabled (no-op)
session_set_preference() {
    local key="$1"
    local value="$2"

    if ! _is_session_enabled; then
        return 0
    fi

    if [ "$_SESSION_LOADED" != "true" ]; then
        session_load || true
    fi

    if [ -z "$_SESSION_DATA" ]; then
        _init_session_data
    fi

    # Convert string to boolean for JSON
    local bool_value="false"
    if [ "$value" = "true" ] || [ "$value" = "1" ]; then
        bool_value="true"
    fi

    _SESSION_DATA=$(echo "$_SESSION_DATA" | jq --arg key "$key" --argjson val "$bool_value" '.preferences[$key] = $val')

    return 0
}

# Track flag usage for learning
# Arguments:
#   $1 - flag name (e.g., "--scheme")
#   $2 - flag value
# Returns: 0 on success, 0 if session disabled (no-op)
session_track_flag() {
    local flag="$1"
    local value="$2"

    if ! _is_session_enabled; then
        return 0
    fi

    if [ "$_SESSION_LOADED" != "true" ]; then
        session_load || true
    fi

    if [ -z "$_SESSION_DATA" ]; then
        _init_session_data
    fi

    local timestamp
    timestamp=$(_get_timestamp)

    # Check if flag+value combo already exists in history
    local existing_index
    existing_index=$(echo "$_SESSION_DATA" | jq -r --arg flag "$flag" --arg val "$value" \
        '.flagHistory | to_entries | .[] | select(.value.flag == $flag and .value.value == $val) | .key' 2>/dev/null | head -1)

    if [ -n "$existing_index" ]; then
        # Update existing entry: increment count and update lastUsed
        _SESSION_DATA=$(echo "$_SESSION_DATA" | jq --argjson idx "$existing_index" --arg ts "$timestamp" \
            '.flagHistory[$idx].count += 1 | .flagHistory[$idx].lastUsed = $ts')
    else
        # Add new entry
        local new_entry
        new_entry=$(jq -n --arg flag "$flag" --arg val "$value" --arg ts "$timestamp" \
            '{flag: $flag, value: $val, count: 1, lastUsed: $ts}')
        _SESSION_DATA=$(echo "$_SESSION_DATA" | jq --argjson entry "$new_entry" '.flagHistory += [$entry]')
    fi

    return 0
}

# Check if a flag should be offered for persistence
# Arguments:
#   $1 - flag name
#   $2 - flag value
# Outputs: "true" or "false" to stdout
# Returns: 0
session_should_offer_persist() {
    local flag="$1"
    local value="$2"

    if ! _is_session_enabled; then
        echo "false"
        return 0
    fi

    if [ "$_SESSION_LOADED" != "true" ]; then
        session_load || true
    fi

    if [ -z "$_SESSION_DATA" ]; then
        echo "false"
        return 0
    fi

    # Get the cutoff date
    local cutoff_date
    cutoff_date=$(_get_timestamp_days_ago "$SESSION_LEARNING_WINDOW_DAYS")

    if [ -z "$cutoff_date" ]; then
        echo "false"
        return 0
    fi

    # Find the entry and check count and date
    local result
    result=$(echo "$_SESSION_DATA" | jq -r --arg flag "$flag" --arg val "$value" \
        --arg cutoff "$cutoff_date" --argjson threshold "$SESSION_LEARNING_THRESHOLD" \
        '.flagHistory[] | select(.flag == $flag and .value == $val and .lastUsed >= $cutoff and .count >= $threshold) | "true"' 2>/dev/null | head -1)

    if [ "$result" = "true" ]; then
        echo "true"
    else
        echo "false"
    fi
}

# Get all defaults as JSON
# Outputs: JSON object of defaults to stdout
session_get_all_defaults() {
    if ! _is_session_enabled; then
        echo "{}"
        return 0
    fi

    if [ "$_SESSION_LOADED" != "true" ]; then
        session_load || true
    fi

    if [ -z "$_SESSION_DATA" ]; then
        echo "{}"
        return 0
    fi

    echo "$_SESSION_DATA" | jq '.defaults // {}' 2>/dev/null || echo "{}"
}

# Cleanup old logs (called automatically on session_load)
# Cleans both .foundation-logs and Artifacts/build_* directories
# Arguments:
#   $1 - days to retain (default: 3)
# Returns: 0
cleanup_old_logs() {
    local days="${1:-$SESSION_LOG_RETENTION_DAYS}"

    if ! _is_session_enabled; then
        return 0
    fi

    # Clean up old Foundation logs if they exist
    local logs_dir="${LOGS_DIR:-${SESSION_PROJECT_ROOT}/.foundation-logs}"
    if [ -d "$logs_dir" ]; then
        find "$logs_dir" -type f -mtime +"$days" -delete 2>/dev/null || true
    fi

    # Clean up old BuildLint.sh artifacts structure (Artifacts/build_*)
    if [ -d "${SESSION_PROJECT_ROOT}/Artifacts" ]; then
        find "${SESSION_PROJECT_ROOT}/Artifacts" -type d -name "build_*" -mtime +"$days" -exec rm -rf {} \; 2>/dev/null || true
    fi

    return 0
}

# Clear all session data
# Returns: 0
session_clear() {
    if ! _is_session_enabled; then
        return 0
    fi

    _init_session_data
    session_save

    return 0
}

# Check if session file exists
# Returns: 0 if exists, 1 if not
session_exists() {
    [ -f "$SESSION_FILE" ]
}

# Export session file path (for external use)
get_session_file_path() {
    echo "$SESSION_FILE"
}
