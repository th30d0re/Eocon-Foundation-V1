#!/usr/bin/env bash
# test_helper.bash - Shared test setup for phase5 bats tests
#
# Usage in .bats files:
#   load "test_helper"
#   load_build_lib logging    # sources lib/build/logging.sh in isolation
#   source_buildagent         # sources BuildAgent.sh with BUILDAGENT_NO_MAIN=1

BATS_TEST_DIRNAME="${BATS_TEST_DIRNAME:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
PHASE5_DIR="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
LIB_BUILD_DIR="${PHASE5_DIR}/lib/build"
FOUNDATION_LIB_DIR="$(cd "${PHASE5_DIR}/../../../lib" && pwd)"

# ─────────────────────────────────────────────────────────────────────────────
# Minimal color stubs so logging functions work without helpers.sh
# ─────────────────────────────────────────────────────────────────────────────
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export CYAN='\033[0;36m'
export MAGENTA='\033[0;35m'
export NC='\033[0m'

# Minimal globals that lib modules reference
export VERBOSE="${VERBOSE:-false}"
export BUILDAGENT_FANCY_UI="${BUILDAGENT_FANCY_UI:-false}"
export BUILD_QUEUE_AVAILABLE="${BUILD_QUEUE_AVAILABLE:-false}"
export JSON_OUTPUT="${JSON_OUTPUT:-false}"
export LOGS_DIR="${LOGS_DIR:-/tmp}"
export STATUS_DIR="${STATUS_DIR:-/tmp}"
export CURRENT_ATTEMPT="${CURRENT_ATTEMPT:-0}"
export SCHEME="${SCHEME:-TestScheme}"
export PLATFORM="${PLATFORM:-macOS}"
export BUILD_CONFIGURATION="${BUILD_CONFIGURATION:-Debug}"
export STREAM_OUTPUT="${STREAM_OUTPUT:-false}"
export SPINNER_PID=""
export SPINNER_MESSAGE=""
export REPAIR_STRATEGY_REGISTRY="${REPAIR_STRATEGY_REGISTRY:-/tmp/test_repair_registry.json}"
export BUILD_STATE_DIR="${BUILD_STATE_DIR:-/tmp/test_build_state}"
export ARTIFACTS_DIR="${ARTIFACTS_DIR:-/tmp/test_artifacts}"
export CURRENT_ATTEMPT=0
export MAX_REPAIR_ATTEMPTS=3
export SESSION_ID="test-session-$$"

# ─────────────────────────────────────────────────────────────────────────────
# load_build_lib <module>
#   Sources lib/build/<module>.sh after setting up globals, without running main.
# ─────────────────────────────────────────────────────────────────────────────
load_build_lib() {
    local module="$1"
    local lib_file="${LIB_BUILD_DIR}/${module}.sh"
    if [[ ! -f "$lib_file" ]]; then
        echo "SKIP: lib/build/${module}.sh not found (module not yet extracted)" >&3
        skip "lib/build/${module}.sh not yet extracted"
        return 0
    fi
    # shellcheck disable=SC1090
    source "$lib_file"
}

# ─────────────────────────────────────────────────────────────────────────────
# source_buildagent
#   Sources BuildAgent.sh without running main (uses BUILDAGENT_NO_MAIN guard).
# ─────────────────────────────────────────────────────────────────────────────
source_buildagent() {
    export BUILDAGENT_NO_MAIN=1
    # shellcheck disable=SC1090
    source "${PHASE5_DIR}/BuildAgent.sh"
}

# ─────────────────────────────────────────────────────────────────────────────
# make_repair_registry <fixture_json>
#   Writes a registry JSON fixture to a temp file and sets REPAIR_STRATEGY_REGISTRY.
# ─────────────────────────────────────────────────────────────────────────────
make_repair_registry() {
    local json="${1:-{}}"
    local tmp
    tmp=$(mktemp /tmp/bats_registry_XXXXXX.json)
    echo "$json" > "$tmp"
    export REPAIR_STRATEGY_REGISTRY="$tmp"
    echo "$tmp"
}

# cleanup helper
bats_cleanup_registry() {
    [[ -n "${REPAIR_STRATEGY_REGISTRY:-}" && "${REPAIR_STRATEGY_REGISTRY}" == /tmp/bats_registry_* ]] && \
        rm -f "$REPAIR_STRATEGY_REGISTRY" || true
}
