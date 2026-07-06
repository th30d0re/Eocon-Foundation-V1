#!/usr/bin/env bats
# queue.bats — characterization tests for queue.sh

load "test_helper"

setup() {
    export WORK_DIR="$BATS_TEST_TMPDIR/work"
    mkdir -p "$WORK_DIR"
    export BUILD_QUEUE_AVAILABLE="true"
    export SESSION_ID="test_session"
    
    export RED='' GREEN='' YELLOW='' BLUE='' CYAN='' MAGENTA='' NC=''
    
    # Load logging to prevent unbound function errors
    load_build_lib logging >/dev/null 2>&1 || true
    
    # Mock UI functions
    start_spinner() { :; }
    stop_spinner() { :; }
    
    # Source the underlying BuildQueue library
    if [[ -f "${FOUNDATION_LIB_DIR}/BuildQueue.sh" ]]; then
        source "${FOUNDATION_LIB_DIR}/BuildQueue.sh"
    fi

    # Never fork a real heartbeat background loop inside bats — it keeps the
    # test subshell from exiting.
    bq_start_heartbeat() { :; }
    bq_stop_heartbeat() { :; }

    # Load module under test
    load_build_lib queue
}

@test "queue: init_build_queue creates queue dir when available" {
    run init_build_queue
    [ "$status" -eq 0 ]
    [ -d "$WORK_DIR/.Foundation/.buildqueue" ]
}

@test "queue: acquire_write_access when free creates lock file" {
    init_build_queue
    run acquire_write_access
    [ "$status" -eq 0 ]
    [ -f "$WORK_DIR/.Foundation/.buildqueue/locks/write.lock" ]
}

@test "queue: acquire_write_access fails when lock unavailable and wait times out" {
    init_build_queue
    # simulate another process holding the lock
    bq_acquire_write_lock() { return 1; }
    # mock wait so it doesn't actually block the test
    bq_wait_for_write() { return 1; }

    run acquire_write_access
    [ "$status" -eq 1 ]
}

@test "queue: release_write_access frees the lock" {
    init_build_queue
    acquire_write_access
    [ -f "$WORK_DIR/.Foundation/.buildqueue/locks/write.lock" ]

    run release_write_access
    [ "$status" -eq 0 ]
    [ ! -f "$WORK_DIR/.Foundation/.buildqueue/locks/write.lock" ]
}

@test "queue: check_queue_status reports blocked (0) when bq_is_blocked returns true" {
    init_build_queue
    bq_is_blocked() { return 0; }

    run check_queue_status
    [ "$status" -eq 0 ]
}
