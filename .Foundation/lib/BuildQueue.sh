#!/bin/bash

# BuildQueue.sh - Centralized Build Coordination System
# Prevents concurrent write/build conflicts across multiple BuildAgent instances
#
# Usage:
#   source .Foundation/lib/BuildQueue.sh
#   bq_init "/path/to/project"
#   bq_acquire_write_lock || { echo "Waiting..."; bq_wait_for_write; }
#   # ... do code writing ...
#   bq_release_write_lock
#
# States:
#   IDLE     - No operations running
#   WRITING  - Agent is modifying code (exclusive)
#   BUILDING - Build in progress (blocks writes)
#   QUEUED   - Agent waiting for turn

set -euo pipefail

# =============================================================================
# Configuration
# =============================================================================

# Lock timeout in seconds (stale lock detection)
BQ_LOCK_TIMEOUT=${BQ_LOCK_TIMEOUT:-600}  # 10 minutes default

# Poll interval when waiting (seconds)
BQ_POLL_INTERVAL=${BQ_POLL_INTERVAL:-5}

# Max wait time before giving up (seconds, 0 = infinite)
BQ_MAX_WAIT=${BQ_MAX_WAIT:-1800}  # 30 minutes default

# Queue directory (set per-project via bq_init)
BQ_QUEUE_DIR=""

# Current agent's unique ID
BQ_AGENT_ID=""

# =============================================================================
# Initialization
# =============================================================================

# Initialize build queue for a project directory
# Usage: bq_init "/path/to/project" ["agent-identifier"]
bq_init() {
    local project_dir="$1"
    local agent_id="${2:-}"

    # Resolve to absolute path
    project_dir="$(cd "$project_dir" 2>/dev/null && pwd)"

    # Create queue directory in project's .Foundation folder
    BQ_QUEUE_DIR="${project_dir}/.Foundation/.buildqueue"
    mkdir -p "$BQ_QUEUE_DIR"

    # Generate unique agent ID if not provided
    if [ -z "$agent_id" ]; then
        BQ_AGENT_ID="agent_$$_$(date +%s)_${RANDOM}"
    else
        BQ_AGENT_ID="$agent_id"
    fi

    # Create subdirectories
    mkdir -p "${BQ_QUEUE_DIR}/locks"
    mkdir -p "${BQ_QUEUE_DIR}/queue"

    # Initialize state file if not exists
    if [ ! -f "${BQ_QUEUE_DIR}/state" ]; then
        echo "IDLE" > "${BQ_QUEUE_DIR}/state"
    fi

    _bq_log "debug" "Initialized build queue: $BQ_QUEUE_DIR (agent: $BQ_AGENT_ID)"
    return 0
}

# =============================================================================
# Lock Management
# =============================================================================

# Create a lock file with metadata
_bq_create_lock() {
    local lock_type="$1"  # "write" or "build"
    local lock_file="${BQ_QUEUE_DIR}/locks/${lock_type}.lock"

    # Write lock metadata
    cat > "$lock_file" << EOF
AGENT_ID=$BQ_AGENT_ID
PID=$$
TIMESTAMP=$(date +%s)
HOSTNAME=$(hostname)
TYPE=$lock_type
EOF

    chmod 644 "$lock_file"
    return 0
}

# Remove a lock file
_bq_remove_lock() {
    local lock_type="$1"
    local lock_file="${BQ_QUEUE_DIR}/locks/${lock_type}.lock"

    # Only remove if we own it
    if _bq_owns_lock "$lock_type"; then
        rm -f "$lock_file"
        return 0
    fi
    return 1
}

# Check if we own a lock
_bq_owns_lock() {
    local lock_type="$1"
    local lock_file="${BQ_QUEUE_DIR}/locks/${lock_type}.lock"

    if [ ! -f "$lock_file" ]; then
        return 1
    fi

    local lock_agent=$(grep "^AGENT_ID=" "$lock_file" 2>/dev/null | cut -d= -f2)
    [ "$lock_agent" = "$BQ_AGENT_ID" ]
}

# Check if a lock exists and is still valid (not stale)
_bq_lock_exists() {
    local lock_type="$1"
    local lock_file="${BQ_QUEUE_DIR}/locks/${lock_type}.lock"

    if [ ! -f "$lock_file" ]; then
        return 1
    fi

    # Check if lock is stale
    local lock_timestamp=$(grep "^TIMESTAMP=" "$lock_file" 2>/dev/null | cut -d= -f2)
    local lock_pid=$(grep "^PID=" "$lock_file" 2>/dev/null | cut -d= -f2)
    local current_time=$(date +%s)

    # If timestamp is missing or empty, treat as stale
    if [ -z "$lock_timestamp" ]; then
        _bq_log "warning" "Stale lock detected (no timestamp): $lock_file"
        rm -f "$lock_file"
        return 1
    fi

    # Check if lock has expired
    local age=$((current_time - lock_timestamp))
    if [ "$age" -gt "$BQ_LOCK_TIMEOUT" ]; then
        _bq_log "warning" "Stale lock detected (age: ${age}s > ${BQ_LOCK_TIMEOUT}s): $lock_file"
        rm -f "$lock_file"
        return 1
    fi

    # Check if owning process is still running (only on same host)
    local lock_host=$(grep "^HOSTNAME=" "$lock_file" 2>/dev/null | cut -d= -f2)
    if [ "$lock_host" = "$(hostname)" ] && [ -n "$lock_pid" ]; then
        if ! kill -0 "$lock_pid" 2>/dev/null; then
            _bq_log "warning" "Stale lock detected (PID $lock_pid not running): $lock_file"
            rm -f "$lock_file"
            return 1
        fi
    fi

    return 0
}

# Get lock holder info
_bq_get_lock_holder() {
    local lock_type="$1"
    local lock_file="${BQ_QUEUE_DIR}/locks/${lock_type}.lock"

    if [ -f "$lock_file" ]; then
        cat "$lock_file"
    fi
}

# =============================================================================
# Write Lock Operations (Exclusive - for code modification)
# =============================================================================

# Attempt to acquire write lock (non-blocking)
# Returns 0 if acquired, 1 if blocked
bq_acquire_write_lock() {
    _bq_require_init

    # Cannot write if build is in progress
    if _bq_lock_exists "build"; then
        _bq_log "info" "Write blocked: build in progress"
        return 1
    fi

    # Cannot write if another agent is writing
    if _bq_lock_exists "write"; then
        if ! _bq_owns_lock "write"; then
            _bq_log "info" "Write blocked: another agent is writing"
            return 1
        fi
        # We already own it
        return 0
    fi

    # Acquire the lock
    _bq_create_lock "write"
    _bq_update_state "WRITING"
    _bq_log "info" "Write lock acquired by $BQ_AGENT_ID"
    return 0
}

# Release write lock
bq_release_write_lock() {
    _bq_require_init

    if _bq_remove_lock "write"; then
        _bq_update_state_if_idle
        _bq_log "info" "Write lock released by $BQ_AGENT_ID"
        return 0
    fi
    return 1
}

# Wait until write lock is available, then acquire it
# Returns 0 on success, 1 on timeout
bq_wait_for_write() {
    _bq_require_init

    local start_time=$(date +%s)
    local waited=0

    # Add ourselves to the queue
    _bq_enqueue "write"

    while ! bq_acquire_write_lock; do
        # Check timeout
        if [ "$BQ_MAX_WAIT" -gt 0 ]; then
            local elapsed=$(($(date +%s) - start_time))
            if [ "$elapsed" -gt "$BQ_MAX_WAIT" ]; then
                _bq_log "error" "Timeout waiting for write lock (${elapsed}s)"
                _bq_dequeue "write"
                return 1
            fi
        fi

        # Log waiting status periodically
        waited=$((waited + BQ_POLL_INTERVAL))
        if [ $((waited % 30)) -eq 0 ]; then
            _bq_log "info" "Still waiting for write lock... (${waited}s)"
            _bq_log_queue_status
        fi

        sleep "$BQ_POLL_INTERVAL"
    done

    _bq_dequeue "write"
    return 0
}

# =============================================================================
# Build Lock Operations (Blocks writes while building)
# =============================================================================

# Attempt to acquire build lock (non-blocking)
# Returns 0 if acquired, 1 if blocked
bq_acquire_build_lock() {
    _bq_require_init

    # Cannot build if write is in progress
    if _bq_lock_exists "write"; then
        if ! _bq_owns_lock "write"; then
            _bq_log "info" "Build blocked: write in progress"
            return 1
        fi
        # We own the write lock, so we can also build
    fi

    # Check if another build is running
    if _bq_lock_exists "build"; then
        if ! _bq_owns_lock "build"; then
            _bq_log "info" "Build blocked: another build in progress"
            return 1
        fi
        # We already own it
        return 0
    fi

    # Acquire the lock
    _bq_create_lock "build"
    _bq_update_state "BUILDING"
    _bq_log "info" "Build lock acquired by $BQ_AGENT_ID"
    return 0
}

# Release build lock
bq_release_build_lock() {
    _bq_require_init

    if _bq_remove_lock "build"; then
        _bq_update_state_if_idle
        _bq_log "info" "Build lock released by $BQ_AGENT_ID"
        return 0
    fi
    return 1
}

# Wait until build lock is available, then acquire it
bq_wait_for_build() {
    _bq_require_init

    local start_time=$(date +%s)
    local waited=0

    _bq_enqueue "build"

    while ! bq_acquire_build_lock; do
        if [ "$BQ_MAX_WAIT" -gt 0 ]; then
            local elapsed=$(($(date +%s) - start_time))
            if [ "$elapsed" -gt "$BQ_MAX_WAIT" ]; then
                _bq_log "error" "Timeout waiting for build lock (${elapsed}s)"
                _bq_dequeue "build"
                return 1
            fi
        fi

        waited=$((waited + BQ_POLL_INTERVAL))
        if [ $((waited % 30)) -eq 0 ]; then
            _bq_log "info" "Still waiting for build lock... (${waited}s)"
        fi

        sleep "$BQ_POLL_INTERVAL"
    done

    _bq_dequeue "build"
    return 0
}

# =============================================================================
# Combined Operations
# =============================================================================

# Acquire both write and build locks (for exclusive operations)
bq_acquire_exclusive() {
    _bq_require_init

    if ! bq_acquire_write_lock; then
        return 1
    fi

    if ! bq_acquire_build_lock; then
        bq_release_write_lock
        return 1
    fi

    _bq_update_state "EXCLUSIVE"
    return 0
}

# Release all locks held by this agent
bq_release_all() {
    _bq_require_init

    bq_release_write_lock 2>/dev/null || true
    bq_release_build_lock 2>/dev/null || true
    _bq_update_state_if_idle
}

# Wait for exclusive access (both write and build)
bq_wait_for_exclusive() {
    _bq_require_init

    if ! bq_wait_for_write; then
        return 1
    fi

    if ! bq_wait_for_build; then
        bq_release_write_lock
        return 1
    fi

    return 0
}

# =============================================================================
# Queue Management
# =============================================================================

# Add agent to wait queue
_bq_enqueue() {
    local operation="$1"
    local queue_file="${BQ_QUEUE_DIR}/queue/${operation}_queue.txt"
    local entry="${BQ_AGENT_ID}|$(date +%s)|$$"

    # Add to queue if not already present
    if ! grep -q "^${BQ_AGENT_ID}|" "$queue_file" 2>/dev/null; then
        echo "$entry" >> "$queue_file"
        _bq_log "debug" "Enqueued for $operation: $BQ_AGENT_ID"
    fi
}

# Remove agent from wait queue
_bq_dequeue() {
    local operation="$1"
    local queue_file="${BQ_QUEUE_DIR}/queue/${operation}_queue.txt"

    if [ -f "$queue_file" ]; then
        # Remove our entry
        grep -v "^${BQ_AGENT_ID}|" "$queue_file" > "${queue_file}.tmp" 2>/dev/null || true
        mv "${queue_file}.tmp" "$queue_file" 2>/dev/null || true
        _bq_log "debug" "Dequeued from $operation: $BQ_AGENT_ID"
    fi
}

# Get queue position (1-based, 0 if not in queue)
bq_get_queue_position() {
    local operation="${1:-write}"
    local queue_file="${BQ_QUEUE_DIR}/queue/${operation}_queue.txt"

    if [ ! -f "$queue_file" ]; then
        echo "0"
        return
    fi

    local pos=$(grep -n "^${BQ_AGENT_ID}|" "$queue_file" 2>/dev/null | cut -d: -f1)
    echo "${pos:-0}"
}

# Get total queue length
bq_get_queue_length() {
    local operation="${1:-write}"
    local queue_file="${BQ_QUEUE_DIR}/queue/${operation}_queue.txt"

    if [ ! -f "$queue_file" ]; then
        echo "0"
        return
    fi

    wc -l < "$queue_file" | tr -d ' '
}

# Clean stale entries from queue
_bq_clean_queue() {
    local operation="$1"
    local queue_file="${BQ_QUEUE_DIR}/queue/${operation}_queue.txt"
    local current_time=$(date +%s)

    if [ ! -f "$queue_file" ]; then
        return
    fi

    # Remove entries older than max wait time or with dead PIDs
    local temp_file="${queue_file}.tmp"
    > "$temp_file"

    while IFS='|' read -r agent_id timestamp pid; do
        local age=$((current_time - timestamp))

        # Skip if too old
        if [ "$age" -gt "$BQ_MAX_WAIT" ] && [ "$BQ_MAX_WAIT" -gt 0 ]; then
            continue
        fi

        # Skip if process is dead (on same host)
        if [ -n "$pid" ] && ! kill -0 "$pid" 2>/dev/null; then
            continue
        fi

        echo "${agent_id}|${timestamp}|${pid}" >> "$temp_file"
    done < "$queue_file"

    mv "$temp_file" "$queue_file"
}

# =============================================================================
# State Management
# =============================================================================

# Update global state
_bq_update_state() {
    local new_state="$1"
    echo "$new_state" > "${BQ_QUEUE_DIR}/state"
}

# Update state to IDLE if no locks are held
_bq_update_state_if_idle() {
    if ! _bq_lock_exists "write" && ! _bq_lock_exists "build"; then
        _bq_update_state "IDLE"
    elif _bq_lock_exists "write" && _bq_lock_exists "build"; then
        _bq_update_state "EXCLUSIVE"
    elif _bq_lock_exists "write"; then
        _bq_update_state "WRITING"
    elif _bq_lock_exists "build"; then
        _bq_update_state "BUILDING"
    fi
}

# Get current state
bq_get_state() {
    _bq_require_init

    # Refresh state based on actual locks
    _bq_update_state_if_idle

    cat "${BQ_QUEUE_DIR}/state" 2>/dev/null || echo "UNKNOWN"
}

# Check if operations are blocked
bq_is_blocked() {
    _bq_require_init

    local state=$(bq_get_state)
    case "$state" in
        IDLE)
            return 1
            ;;
        *)
            # Check if we own the locks
            if _bq_owns_lock "write" || _bq_owns_lock "build"; then
                return 1
            fi
            return 0
            ;;
    esac
}

# =============================================================================
# Status and Diagnostics
# =============================================================================

# Print human-readable status
bq_status() {
    _bq_require_init

    local state=$(bq_get_state)
    local write_queue=$(bq_get_queue_length "write")
    local build_queue=$(bq_get_queue_length "build")

    echo "=== Build Queue Status ==="
    echo "Directory: $BQ_QUEUE_DIR"
    echo "Agent ID:  $BQ_AGENT_ID"
    echo "State:     $state"
    echo ""

    if _bq_lock_exists "write"; then
        echo "Write Lock: HELD"
        _bq_get_lock_holder "write" | sed 's/^/  /'
    else
        echo "Write Lock: FREE"
    fi

    if _bq_lock_exists "build"; then
        echo "Build Lock: HELD"
        _bq_get_lock_holder "build" | sed 's/^/  /'
    else
        echo "Build Lock: FREE"
    fi

    echo ""
    echo "Write Queue: $write_queue waiting"
    echo "Build Queue: $build_queue waiting"

    if [ "$write_queue" -gt 0 ]; then
        echo "  Write queue contents:"
        cat "${BQ_QUEUE_DIR}/queue/write_queue.txt" 2>/dev/null | sed 's/^/    /'
    fi

    if [ "$build_queue" -gt 0 ]; then
        echo "  Build queue contents:"
        cat "${BQ_QUEUE_DIR}/queue/build_queue.txt" 2>/dev/null | sed 's/^/    /'
    fi
}

# Log queue status (for periodic updates)
_bq_log_queue_status() {
    local state=$(bq_get_state)
    local write_pos=$(bq_get_queue_position "write")
    local write_len=$(bq_get_queue_length "write")

    if [ "$write_pos" -gt 0 ]; then
        _bq_log "info" "Queue position: $write_pos of $write_len (state: $state)"
    fi
}

# JSON status output
bq_status_json() {
    _bq_require_init

    local state=$(bq_get_state)
    local write_holder=""
    local build_holder=""

    if _bq_lock_exists "write"; then
        write_holder=$(grep "^AGENT_ID=" "${BQ_QUEUE_DIR}/locks/write.lock" 2>/dev/null | cut -d= -f2)
    fi

    if _bq_lock_exists "build"; then
        build_holder=$(grep "^AGENT_ID=" "${BQ_QUEUE_DIR}/locks/build.lock" 2>/dev/null | cut -d= -f2)
    fi

    cat << EOF
{
  "state": "$state",
  "agent_id": "$BQ_AGENT_ID",
  "write_lock": {
    "held": $(_bq_lock_exists "write" && echo "true" || echo "false"),
    "holder": "$write_holder",
    "owned": $(_bq_owns_lock "write" && echo "true" || echo "false")
  },
  "build_lock": {
    "held": $(_bq_lock_exists "build" && echo "true" || echo "false"),
    "holder": "$build_holder",
    "owned": $(_bq_owns_lock "build" && echo "true" || echo "false")
  },
  "write_queue_length": $(bq_get_queue_length "write"),
  "build_queue_length": $(bq_get_queue_length "build"),
  "queue_position": $(bq_get_queue_position "write")
}
EOF
}

# =============================================================================
# Safe Operations (allowed while waiting)
# =============================================================================

# Create a temporary workspace for planning while waiting
# Returns path to temp directory
bq_create_temp_workspace() {
    _bq_require_init

    local temp_dir="${BQ_QUEUE_DIR}/temp/${BQ_AGENT_ID}"
    mkdir -p "$temp_dir"
    echo "$temp_dir"
}

# Clean up temporary workspace
bq_cleanup_temp_workspace() {
    _bq_require_init

    local temp_dir="${BQ_QUEUE_DIR}/temp/${BQ_AGENT_ID}"
    rm -rf "$temp_dir" 2>/dev/null || true
}

# Check if an operation is "safe" (doesn't require lock)
bq_is_safe_operation() {
    local operation="$1"

    case "$operation" in
        read|plan|analyze|gather_context|fetch_docs)
            return 0
            ;;
        write|modify|build|test)
            return 1
            ;;
        *)
            return 1
            ;;
    esac
}

# =============================================================================
# Heartbeat (Keep locks alive for long operations)
# =============================================================================

# Start heartbeat background process
bq_start_heartbeat() {
    _bq_require_init

    local heartbeat_interval=${BQ_HEARTBEAT_INTERVAL:-60}

    (
        while true; do
            sleep "$heartbeat_interval"

            # Update timestamp on our locks
            for lock_type in write build; do
                if _bq_owns_lock "$lock_type"; then
                    local lock_file="${BQ_QUEUE_DIR}/locks/${lock_type}.lock"
                    # Update timestamp
                    sed -i.bak "s/^TIMESTAMP=.*/TIMESTAMP=$(date +%s)/" "$lock_file" 2>/dev/null || true
                    rm -f "${lock_file}.bak" 2>/dev/null || true
                fi
            done
        done
    ) &

    BQ_HEARTBEAT_PID=$!
    _bq_log "debug" "Started heartbeat process: $BQ_HEARTBEAT_PID"
}

# Stop heartbeat
bq_stop_heartbeat() {
    if [ -n "${BQ_HEARTBEAT_PID:-}" ]; then
        kill "$BQ_HEARTBEAT_PID" 2>/dev/null || true
        BQ_HEARTBEAT_PID=""
        _bq_log "debug" "Stopped heartbeat process"
    fi
}

# =============================================================================
# Cleanup
# =============================================================================

# Clean up all resources held by this agent
bq_cleanup() {
    bq_stop_heartbeat
    bq_release_all
    bq_cleanup_temp_workspace
    _bq_dequeue "write"
    _bq_dequeue "build"
    _bq_log "info" "Cleanup complete for $BQ_AGENT_ID"
}

# Force cleanup (for admin use - removes all locks and queues)
bq_force_cleanup() {
    _bq_require_init

    _bq_log "warning" "Force cleanup initiated"

    rm -f "${BQ_QUEUE_DIR}/locks/"*.lock 2>/dev/null || true
    rm -f "${BQ_QUEUE_DIR}/queue/"*.txt 2>/dev/null || true
    rm -rf "${BQ_QUEUE_DIR}/temp/"* 2>/dev/null || true

    _bq_update_state "IDLE"
    _bq_log "info" "Force cleanup complete"
}

# =============================================================================
# Internal Helpers
# =============================================================================

# Ensure init has been called
_bq_require_init() {
    if [ -z "$BQ_QUEUE_DIR" ]; then
        echo "ERROR: Build queue not initialized. Call bq_init() first." >&2
        return 1
    fi
}

# Logging helper
_bq_log() {
    local level="$1"
    shift
    local message="$*"

    # Use foundation_log if available, otherwise basic output
    if type foundation_log &>/dev/null; then
        foundation_log "$level" "[BuildQueue] $message"
    else
        local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
        case "$level" in
            error)
                echo "[$timestamp] [BQ ERROR] $message" >&2
                ;;
            warning)
                echo "[$timestamp] [BQ WARN] $message" >&2
                ;;
            info)
                echo "[$timestamp] [BQ INFO] $message" >&2
                ;;
            debug)
                if [ "${BQ_DEBUG:-0}" = "1" ]; then
                    echo "[$timestamp] [BQ DEBUG] $message" >&2
                fi
                ;;
        esac
    fi
}

# =============================================================================
# CLI Interface (when run directly)
# =============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Script is being run directly, not sourced

    case "${1:-help}" in
        init)
            bq_init "${2:-.}"
            echo "Initialized build queue in: $BQ_QUEUE_DIR"
            ;;
        status)
            bq_init "${2:-.}"
            bq_status
            ;;
        status-json)
            bq_init "${2:-.}"
            bq_status_json
            ;;
        acquire-write)
            bq_init "${2:-.}" "${3:-cli_$$}"
            if bq_acquire_write_lock; then
                echo "Write lock acquired"
                exit 0
            else
                echo "Write lock not available"
                exit 1
            fi
            ;;
        release-write)
            bq_init "${2:-.}" "${3:-cli_$$}"
            bq_release_write_lock
            echo "Write lock released"
            ;;
        acquire-build)
            bq_init "${2:-.}" "${3:-cli_$$}"
            if bq_acquire_build_lock; then
                echo "Build lock acquired"
                exit 0
            else
                echo "Build lock not available"
                exit 1
            fi
            ;;
        release-build)
            bq_init "${2:-.}" "${3:-cli_$$}"
            bq_release_build_lock
            echo "Build lock released"
            ;;
        wait-write)
            bq_init "${2:-.}" "${3:-cli_$$}"
            bq_wait_for_write
            echo "Write lock acquired after waiting"
            ;;
        wait-build)
            bq_init "${2:-.}" "${3:-cli_$$}"
            bq_wait_for_build
            echo "Build lock acquired after waiting"
            ;;
        cleanup)
            bq_init "${2:-.}"
            bq_force_cleanup
            ;;
        help|*)
            cat << 'HELP'
BuildQueue - Centralized Build Coordination System

Usage: BuildQueue.sh <command> [project_dir] [agent_id]

Commands:
  init          Initialize build queue for project
  status        Show human-readable status
  status-json   Show JSON status
  acquire-write Acquire write lock (non-blocking)
  release-write Release write lock
  acquire-build Acquire build lock (non-blocking)
  release-build Release build lock
  wait-write    Wait for and acquire write lock
  wait-build    Wait for and acquire build lock
  cleanup       Force cleanup all locks and queues
  help          Show this help

Environment Variables:
  BQ_LOCK_TIMEOUT   Lock expiration time in seconds (default: 600)
  BQ_POLL_INTERVAL  Wait poll interval in seconds (default: 5)
  BQ_MAX_WAIT       Max wait time in seconds (default: 1800)
  BQ_DEBUG          Enable debug logging (default: 0)

Examples:
  # Check status
  ./BuildQueue.sh status /path/to/project

  # Acquire write lock for code generation
  ./BuildQueue.sh acquire-write /path/to/project my_agent_001

  # Wait for write lock (blocking)
  ./BuildQueue.sh wait-write /path/to/project my_agent_001

HELP
            ;;
    esac
fi
