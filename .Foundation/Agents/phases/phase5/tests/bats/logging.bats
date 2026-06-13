#!/usr/bin/env bats
# logging.bats — characterization tests for log_* functions
# Works against lib/build/logging.sh (preferred) or by extracting functions
# from the monolith via awk (fallback, avoids sourcing the 6k-line file).

load "test_helper"

# Produce a minimal script that has just the logging functions.
# When lib/build/logging.sh exists, use it directly.
# When it doesn't, extract only the 7 log_* functions from BuildAgent.sh.
_log_source_snippet() {
    if [[ -f "${PHASE5_DIR}/lib/build/logging.sh" ]]; then
        echo "source '${PHASE5_DIR}/lib/build/logging.sh'"
    else
        # Extract just the logging function definitions from the monolith (lines 263-374)
        echo "$(awk 'NR>=263 && NR<=374' "${PHASE5_DIR}/BuildAgent.sh")"
    fi
}

@test "log_info writes [INFO] prefix to stderr" {
    run bash -c "
        export BUILDAGENT_FANCY_UI=false VERBOSE=false
        export RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[1;33m'
        export BLUE='\033[0;34m' CYAN='\033[0;36m' MAGENTA='\033[0;35m' NC='\033[0m'
        $(_log_source_snippet)
        log_info 'hello world' 2>&1
    "
    [[ "$output" == *"[INFO]"*"hello world"* ]]
}

@test "log_success writes [SUCCESS] prefix to stderr" {
    run bash -c "
        export BUILDAGENT_FANCY_UI=false VERBOSE=false
        export RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[1;33m'
        export BLUE='\033[0;34m' CYAN='\033[0;36m' MAGENTA='\033[0;35m' NC='\033[0m'
        $(_log_source_snippet)
        log_success 'done' 2>&1
    "
    [[ "$output" == *"[SUCCESS]"*"done"* ]]
}

@test "log_warning writes [WARNING] prefix to stderr" {
    run bash -c "
        export BUILDAGENT_FANCY_UI=false VERBOSE=false
        export RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[1;33m'
        export BLUE='\033[0;34m' CYAN='\033[0;36m' MAGENTA='\033[0;35m' NC='\033[0m'
        $(_log_source_snippet)
        log_warning 'watch out' 2>&1
    "
    [[ "$output" == *"[WARNING]"*"watch out"* ]]
}

@test "log_error writes [ERROR] prefix to stderr" {
    run bash -c "
        export BUILDAGENT_FANCY_UI=false VERBOSE=false
        export RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[1;33m'
        export BLUE='\033[0;34m' CYAN='\033[0;36m' MAGENTA='\033[0;35m' NC='\033[0m'
        $(_log_source_snippet)
        log_error 'something broke' 2>&1
    "
    [[ "$output" == *"[ERROR]"*"something broke"* ]]
}

@test "log_section writes BUILD-AGENT prefix to stderr" {
    run bash -c "
        export BUILDAGENT_FANCY_UI=false VERBOSE=false
        export RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[1;33m'
        export BLUE='\033[0;34m' CYAN='\033[0;36m' MAGENTA='\033[0;35m' NC='\033[0m'
        $(_log_source_snippet)
        log_section 'Starting phase' 2>&1
    "
    [[ "$output" == *"BUILD-AGENT"*"Starting phase"* ]]
}

@test "log_verbose is silent when VERBOSE=false" {
    run bash -c "
        export BUILDAGENT_FANCY_UI=false VERBOSE=false
        export RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[1;33m'
        export BLUE='\033[0;34m' CYAN='\033[0;36m' MAGENTA='\033[0;35m' NC='\033[0m'
        $(_log_source_snippet)
        log_verbose 'this should not appear' 2>&1
    "
    [[ -z "$output" ]]
}

@test "log_verbose emits output when VERBOSE=true" {
    run bash -c "
        export BUILDAGENT_FANCY_UI=false VERBOSE=true
        export RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[1;33m'
        export BLUE='\033[0;34m' CYAN='\033[0;36m' MAGENTA='\033[0;35m' NC='\033[0m'
        $(_log_source_snippet)
        log_verbose 'detail info' 2>&1
    "
    [[ "$output" == *"detail info"* ]]
}
