#!/usr/bin/env bats
# detect.bats — characterization tests for validate_identifier

load "test_helper"

MONOLITH="${PHASE5_DIR}/BuildAgent.sh"
DETECT_LIB="${PHASE5_DIR}/lib/build/detect.sh"
LOGGING_LIB="${PHASE5_DIR}/lib/build/logging.sh"

_make_detect_snippet_file() {
    local tmp
    tmp=$(mktemp /tmp/bats_detect_snippet_XXXXXX.sh)
    if [[ -f "$DETECT_LIB" ]]; then
        [[ -f "$LOGGING_LIB" ]] && cat "$LOGGING_LIB" >> "$tmp"
        cat "$DETECT_LIB" >> "$tmp"
    else
        awk 'NR>=263 && NR<=374' "$MONOLITH" >> "$tmp"
        awk 'NR>=1234 && NR<=1455' "$MONOLITH" >> "$tmp"
    fi
    echo "$tmp"
}

setup() {
    SNIPPET_FILE=$(_make_detect_snippet_file)
    export SNIPPET_FILE
}

teardown() {
    rm -f "${SNIPPET_FILE:-}" 2>/dev/null || true
}

@test "validate_identifier: accepts valid alphanumeric identifier" {
    run bash -c "
        export BUILDAGENT_FANCY_UI=false VERBOSE=false
        export RED='' GREEN='' YELLOW='' BLUE='' CYAN='' MAGENTA='' NC=''
        source '${SNIPPET_FILE}'
        validate_identifier 'MyApp123' 2>/dev/null && echo 'ok'
    "
    [ "$output" = "ok" ]
}

@test "validate_identifier: accepts identifier with hyphens and underscores" {
    run bash -c "
        export BUILDAGENT_FANCY_UI=false VERBOSE=false
        export RED='' GREEN='' YELLOW='' BLUE='' CYAN='' MAGENTA='' NC=''
        source '${SNIPPET_FILE}'
        validate_identifier 'My-App_123' 2>/dev/null && echo 'ok'
    "
    [ "$output" = "ok" ]
}

@test "validate_identifier: accepts empty string (means auto-detect)" {
    run bash -c "
        set +e
        export BUILDAGENT_FANCY_UI=false VERBOSE=false
        export RED='' GREEN='' YELLOW='' BLUE='' CYAN='' MAGENTA='' NC=''
        source '${SNIPPET_FILE}' 2>/dev/null
        validate_identifier '' 2>/dev/null
        echo \"exit:\$?\"
    "
    [[ "$output" == *"exit:0"* ]]
}

@test "validate_identifier: rejects identifier with invalid characters" {
    run bash -c "
        set +e
        export BUILDAGENT_FANCY_UI=false VERBOSE=false
        export RED='' GREEN='' YELLOW='' BLUE='' CYAN='' MAGENTA='' NC=''
        source '${SNIPPET_FILE}' 2>/dev/null
        validate_identifier 'My@App!' 2>/dev/null
        echo \"exit:\$?\"
    "
    [[ "$output" == *"exit:1"* ]]
}
