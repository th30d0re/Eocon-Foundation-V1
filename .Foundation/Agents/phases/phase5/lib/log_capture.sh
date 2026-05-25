#!/usr/bin/env bash
# Library: log_capture.sh
# Purpose: Log capture library for structured log sessions
# Dependencies: jq (optional - graceful degradation)
#
# Functions:
#   start_log_capture(platform)     - Start a new log capture session
#   stop_log_capture(session_id)    - Stop and finalize a log session
#   append_log(session_id, content) - Append content to log session
#   get_log_path(session_id)        - Get path to log file
#   list_log_sessions(limit)        - List recent log sessions
#   cleanup_old_logs(days)          - Remove logs older than N days
#
# Environment Variables:
#   PROJECT_ROOT                    - Root directory of the project
#   LOG_CAPTURE_DIR                 - Directory for log files (default: $PROJECT_ROOT/.foundation/logs)
#
# JSON Schema for session metadata:
#   {
#     "sessionId": "1234567890_iOS_Simulator",
#     "platform": "iOS Simulator",
#     "startTime": "2024-01-15T10:30:00Z",
#     "endTime": "2024-01-15T10:35:00Z",
#     "status": "active|completed|failed",
#     "buildType": "incremental|clean|test",
#     "scheme": "MyApp",
#     "configuration": "Debug"
#   }

set -euo pipefail

# Verify bash is running
if [ -z "${BASH_VERSION:-}" ]; then
    echo "Error: This library requires bash" >&2
    return 1 2>/dev/null || exit 1
fi

# Path resolution
LOG_CAPTURE_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_CAPTURE_PHASE5_DIR="$(cd "${LOG_CAPTURE_LIB_DIR}/.." && pwd)"
LOG_CAPTURE_PROJECT_ROOT="${PROJECT_ROOT:-$(cd "${LOG_CAPTURE_PHASE5_DIR}/../../../.." && pwd)}"

# Configuration
LOG_CAPTURE_DIR="${LOG_CAPTURE_DIR:-${LOG_CAPTURE_PROJECT_ROOT}/.foundation/logs}"
LOG_RETENTION_DAYS="${LOG_RETENTION_DAYS:-3}"

# Internal state
_LOG_CAPTURE_CURRENT_SESSION=""

# Check if jq is available
_log_capture_has_jq() {
    command -v jq &>/dev/null
}

# Get current ISO 8601 timestamp
_log_capture_timestamp() {
    date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# Ensure log directory exists
_log_capture_ensure_dir() {
    mkdir -p "$LOG_CAPTURE_DIR"
}

# Start a new log capture session
# Arguments:
#   $1 - platform (e.g., "iOS Simulator", "macOS")
#   $2 - build type (optional: "incremental", "clean", "test")
#   $3 - scheme (optional)
#   $4 - configuration (optional)
# Returns: session_id (echoed to stdout)
start_log_capture() {
    local platform="$1"
    local build_type="${2:-incremental}"
    local scheme="${3:-}"
    local configuration="${4:-Debug}"

    _log_capture_ensure_dir

    # Generate unique session ID
    local timestamp=$(date +%s)
    local platform_safe=$(echo "$platform" | tr ' ' '_' | tr -cd 'a-zA-Z0-9_')
    local session_id="${timestamp}_${platform_safe}"

    local log_file="${LOG_CAPTURE_DIR}/session_${session_id}.log"
    local meta_file="${LOG_CAPTURE_DIR}/session_${session_id}.meta.json"

    # Create metadata file
    if _log_capture_has_jq; then
        jq -n \
            --arg session_id "$session_id" \
            --arg platform "$platform" \
            --arg start_time "$(_log_capture_timestamp)" \
            --arg status "active" \
            --arg build_type "$build_type" \
            --arg scheme "$scheme" \
            --arg configuration "$configuration" \
            --arg log_file "$log_file" \
            '{
                sessionId: $session_id,
                platform: $platform,
                startTime: $start_time,
                endTime: null,
                status: $status,
                buildType: $build_type,
                scheme: $scheme,
                configuration: $configuration,
                logFile: $log_file
            }' > "$meta_file"
    else
        cat > "$meta_file" <<EOF
{
  "sessionId": "$session_id",
  "platform": "$platform",
  "startTime": "$(_log_capture_timestamp)",
  "endTime": null,
  "status": "active",
  "buildType": "$build_type",
  "scheme": "$scheme",
  "configuration": "$configuration",
  "logFile": "$log_file"
}
EOF
    fi

    # Create empty log file with header
    echo "=== Log Session: $session_id ===" > "$log_file"
    echo "Platform: $platform" >> "$log_file"
    echo "Started: $(_log_capture_timestamp)" >> "$log_file"
    echo "===========================================" >> "$log_file"
    echo "" >> "$log_file"

    _LOG_CAPTURE_CURRENT_SESSION="$session_id"
    echo "$session_id"
}

# Stop a log capture session
# Arguments:
#   $1 - session_id
#   $2 - status (optional: "completed", "failed")
# Returns: path to log file (echoed to stdout)
stop_log_capture() {
    local session_id="${1:-$_LOG_CAPTURE_CURRENT_SESSION}"
    local status="${2:-completed}"

    if [ -z "$session_id" ]; then
        echo "No active session to stop" >&2
        return 1
    fi

    local meta_file="${LOG_CAPTURE_DIR}/session_${session_id}.meta.json"
    local log_file="${LOG_CAPTURE_DIR}/session_${session_id}.log"

    if [ ! -f "$meta_file" ]; then
        echo "Session not found: $session_id" >&2
        return 1
    fi

    # Update metadata with end time and status
    local end_time="$(_log_capture_timestamp)"
    if _log_capture_has_jq; then
        jq --arg end_time "$end_time" \
           --arg status "$status" \
           '.endTime = $end_time | .status = $status' \
           "$meta_file" > "${meta_file}.tmp" && mv "${meta_file}.tmp" "$meta_file"
    else
        # Fallback: recreate JSON without jq using existing metadata
        local session_id platform start_time build_type scheme configuration log_file_path

        # Extract values using basic shell tools
        session_id=$(grep -o '"sessionId"[[:space:]]*:[[:space:]]*"[^"]*"' "$meta_file" | sed 's/.*"\([^"]*\)".*/\1/')
        platform=$(grep -o '"platform"[[:space:]]*:[[:space:]]*"[^"]*"' "$meta_file" | sed 's/.*"\([^"]*\)".*/\1/')
        start_time=$(grep -o '"startTime"[[:space:]]*:[[:space:]]*"[^"]*"' "$meta_file" | sed 's/.*"\([^"]*\)".*/\1/')
        build_type=$(grep -o '"buildType"[[:space:]]*:[[:space:]]*"[^"]*"' "$meta_file" | sed 's/.*"\([^"]*\)".*/\1/')
        scheme=$(grep -o '"scheme"[[:space:]]*:[[:space:]]*"[^"]*"' "$meta_file" | sed 's/.*"\([^"]*\)".*/\1/')
        configuration=$(grep -o '"configuration"[[:space:]]*:[[:space:]]*"[^"]*"' "$meta_file" | sed 's/.*"\([^"]*\)".*/\1/')
        log_file_path=$(grep -o '"logFile"[[:space:]]*:[[:space:]]*"[^"]*"' "$meta_file" | sed 's/.*"\([^"]*\)".*/\1/')

        # Recreate JSON with updated endTime and status
        cat > "${meta_file}.tmp" <<EOF
{
  "sessionId": "$session_id",
  "platform": "$platform",
  "startTime": "$start_time",
  "endTime": "$end_time",
  "status": "$status",
  "buildType": "$build_type",
  "scheme": "$scheme",
  "configuration": "$configuration",
  "logFile": "$log_file_path"
}
EOF
        mv "${meta_file}.tmp" "$meta_file"
    fi

    # Add footer to log file
    echo "" >> "$log_file"
    echo "===========================================" >> "$log_file"
    echo "Ended: $(_log_capture_timestamp)" >> "$log_file"
    echo "Status: $status" >> "$log_file"
    echo "=== End Log Session ===" >> "$log_file"

    _LOG_CAPTURE_CURRENT_SESSION=""
    echo "$log_file"
}

# Append content to log session
# Arguments:
#   $1 - session_id (or uses current session if not provided)
#   $2 - content to append (or reads from stdin if not provided)
append_log() {
    local session_id="${1:-$_LOG_CAPTURE_CURRENT_SESSION}"
    local content="${2:-}"

    if [ -z "$session_id" ]; then
        echo "No session specified" >&2
        return 1
    fi

    local log_file="${LOG_CAPTURE_DIR}/session_${session_id}.log"

    if [ ! -f "$log_file" ]; then
        echo "Log file not found for session: $session_id" >&2
        return 1
    fi

    if [ -n "$content" ]; then
        echo "$content" >> "$log_file"
    else
        # Read from stdin
        cat >> "$log_file"
    fi
}

# Get path to log file for a session
# Arguments:
#   $1 - session_id
# Returns: path to log file
get_log_path() {
    local session_id="$1"
    echo "${LOG_CAPTURE_DIR}/session_${session_id}.log"
}

# Get path to metadata file for a session
# Arguments:
#   $1 - session_id
# Returns: path to metadata file
get_meta_path() {
    local session_id="$1"
    echo "${LOG_CAPTURE_DIR}/session_${session_id}.meta.json"
}

# List recent log sessions
# Arguments:
#   $1 - limit (default: 10)
# Returns: JSON array of sessions (if jq available) or plain text
list_log_sessions() {
    local limit="${1:-10}"

    _log_capture_ensure_dir

    if _log_capture_has_jq; then
        # Collect all metadata files and merge into array
        local sessions="[]"
        local count=0

        # Sort by modification time (most recent first)
        for meta_file in $(ls -t "${LOG_CAPTURE_DIR}"/session_*.meta.json 2>/dev/null | head -n "$limit"); do
            if [ -f "$meta_file" ]; then
                local session_data=$(cat "$meta_file")
                sessions=$(echo "$sessions" | jq --argjson session "$session_data" '. + [$session]')
                ((count++)) || true
            fi
        done

        echo "$sessions"
    else
        # Fallback: list files
        echo "Recent log sessions:"
        ls -lt "${LOG_CAPTURE_DIR}"/session_*.log 2>/dev/null | head -n "$limit" || echo "No sessions found"
    fi
}

# Cleanup old log files
# Arguments:
#   $1 - retention days (default: 3)
# Returns: number of files deleted
cleanup_old_logs() {
    local days="${1:-$LOG_RETENTION_DAYS}"
    local deleted=0

    if [ ! -d "$LOG_CAPTURE_DIR" ]; then
        echo "0"
        return 0
    fi

    # Delete old log files
    while IFS= read -r file; do
        rm -f "$file" && ((deleted++)) || true
    done < <(find "$LOG_CAPTURE_DIR" -name "session_*.log" -mtime +"$days" 2>/dev/null)

    # Delete corresponding metadata files
    while IFS= read -r file; do
        rm -f "$file"
    done < <(find "$LOG_CAPTURE_DIR" -name "session_*.meta.json" -mtime +"$days" 2>/dev/null)

    echo "$deleted"
}

# Get session metadata
# Arguments:
#   $1 - session_id
# Returns: JSON metadata or empty
get_session_metadata() {
    local session_id="$1"
    local meta_file="${LOG_CAPTURE_DIR}/session_${session_id}.meta.json"

    if [ -f "$meta_file" ]; then
        cat "$meta_file"
    else
        echo "{}"
    fi
}

# Search logs for a pattern
# Arguments:
#   $1 - pattern (grep regex)
#   $2 - session_id (optional, searches all if not provided)
#   $3 - context lines (optional, default: 2)
# Returns: matching lines with context
search_logs() {
    local pattern="$1"
    local session_id="${2:-}"
    local context="${3:-2}"

    if [ -n "$session_id" ]; then
        local log_file="${LOG_CAPTURE_DIR}/session_${session_id}.log"
        if [ -f "$log_file" ]; then
            grep -C "$context" -n "$pattern" "$log_file" 2>/dev/null || echo "No matches found"
        else
            echo "Log file not found: $log_file" >&2
            return 1
        fi
    else
        # Search all logs
        grep -C "$context" -n "$pattern" "${LOG_CAPTURE_DIR}"/session_*.log 2>/dev/null || echo "No matches found"
    fi
}

# Export current session ID
get_current_session() {
    echo "${_LOG_CAPTURE_CURRENT_SESSION:-}"
}
