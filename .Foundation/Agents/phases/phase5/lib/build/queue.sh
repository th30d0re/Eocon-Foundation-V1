#!/usr/bin/env bash
# lib/build/queue.sh — Build queue coordination (locking) functions for BuildAgent
[ -n "${_BUILD_QUEUE_SH:-}" ] && return 0
_BUILD_QUEUE_SH=1

# ─────────────────────────────────────────────────────────────────────────────
# Build Queue Coordination Functions
# ─────────────────────────────────────────────────────────────────────────────

# Initialize build queue for this session
init_build_queue() {
    if [ "$BUILD_QUEUE_AVAILABLE" != "true" ]; then
        log_verbose "Build queue coordination disabled or unavailable"
        return 0
    fi

    # Initialize queue for this project
    bq_init "$WORK_DIR" "buildagent_${SESSION_ID}"
    log_info "Build queue initialized (coordination enabled)"

    # Start heartbeat to keep locks alive during long operations
    bq_start_heartbeat
}

# Acquire write lock (for code generation) - blocks until available
acquire_write_access() {
    if [ "$BUILD_QUEUE_AVAILABLE" != "true" ]; then
        return 0
    fi

    log_verbose "Acquiring write lock for code generation..."

    if ! bq_acquire_write_lock; then
        log_warning "Write lock not immediately available, waiting..."
        echo "" >&2
        log_info "Another BuildAgent instance is active. Waiting for access..."
        log_info "Queue status: $(bq_get_state)"

        # Start spinner while waiting
        start_spinner "Waiting for write access"

        if ! bq_wait_for_write; then
            stop_spinner
            log_error "Timeout waiting for write lock"
            return 1
        fi

        stop_spinner
        log_success "Write lock acquired after waiting"
    else
        log_verbose "Write lock acquired immediately"
    fi

    return 0
}

# Release write lock
release_write_access() {
    if [ "$BUILD_QUEUE_AVAILABLE" != "true" ]; then
        return 0
    fi

    bq_release_write_lock
    log_verbose "Write lock released"
}

# Acquire build lock (for compilation) - blocks until available
acquire_build_access() {
    if [ "$BUILD_QUEUE_AVAILABLE" != "true" ]; then
        return 0
    fi

    log_verbose "Acquiring build lock for compilation..."

    if ! bq_acquire_build_lock; then
        log_warning "Build lock not immediately available, waiting..."
        log_info "Another agent is modifying code. Waiting for stability..."

        start_spinner "Waiting for code changes to complete"

        if ! bq_wait_for_build; then
            stop_spinner
            log_error "Timeout waiting for build lock"
            return 1
        fi

        stop_spinner
        log_success "Build lock acquired after waiting"
    else
        log_verbose "Build lock acquired immediately"
    fi

    return 0
}

# Release build lock
release_build_access() {
    if [ "$BUILD_QUEUE_AVAILABLE" != "true" ]; then
        return 0
    fi

    bq_release_build_lock
    log_verbose "Build lock released"
}

# Check if we're blocked by another operation
check_queue_status() {
    if [ "$BUILD_QUEUE_AVAILABLE" != "true" ]; then
        return 1  # Not blocked (queue not available)
    fi

    if bq_is_blocked; then
        log_info "Build queue status: $(bq_get_state)"
        return 0  # Blocked
    fi

    return 1  # Not blocked
}
