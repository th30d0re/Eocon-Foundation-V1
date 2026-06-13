#!/usr/bin/env bats
# output.bats — characterization tests for output_json_result and write_build_stage

load "test_helper"

MONOLITH="${PHASE5_DIR}/BuildAgent.sh"
OUTPUT_LIB="${PHASE5_DIR}/lib/build/output.sh"
LOGGING_LIB="${PHASE5_DIR}/lib/build/logging.sh"

_output_source_snippet() {
    if [[ -f "$OUTPUT_LIB" ]]; then
        local log_src=""
        [[ -f "$LOGGING_LIB" ]] && log_src="source '${LOGGING_LIB}'"
        echo "${log_src}; source '${OUTPUT_LIB}'"
    else
        # Extract logging + output_json_result (lines 375-461) + write_build_stage (lines 909-936)
        local log_block
        log_block=$(awk 'NR>=263 && NR<=374' "$MONOLITH")
        local out_block
        out_block=$(awk 'NR>=375 && NR<=461' "$MONOLITH")
        local stage_block
        stage_block=$(awk 'NR>=909 && NR<=936' "$MONOLITH")
        echo "${log_block}
${out_block}
${stage_block}"
    fi
}

setup() {
    TMPDIR_TEST=$(mktemp -d /tmp/bats_output_XXXXXX)
    export STATUS_DIR="$TMPDIR_TEST"
    export LOGS_DIR="$TMPDIR_TEST"
}

teardown() {
    rm -rf "${TMPDIR_TEST:-}" 2>/dev/null || true
}

@test "output_json_result: silent when JSON_OUTPUT=false" {
    run bash -c "
        export BUILDAGENT_FANCY_UI=false VERBOSE=false JSON_OUTPUT=false
        export STATUS_DIR='${TMPDIR_TEST}' LOGS_DIR='${TMPDIR_TEST}'
        export CURRENT_ATTEMPT=0 SCHEME=Test PLATFORM=macOS BUILD_CONFIGURATION=Debug
        export RED='' GREEN='' YELLOW='' BLUE='' CYAN='' MAGENTA='' NC=''
        $(_output_source_snippet)
        output_json_result true 'hello' null 0 '' '[]'
    "
    [ -z "$output" ]
}

@test "output_json_result: emits valid JSON when JSON_OUTPUT=true" {
    run bash -c "
        export BUILDAGENT_FANCY_UI=false VERBOSE=false JSON_OUTPUT=true
        export STATUS_DIR='${TMPDIR_TEST}' LOGS_DIR='${TMPDIR_TEST}'
        export CURRENT_ATTEMPT=0 SCHEME=Test PLATFORM=macOS BUILD_CONFIGURATION=Debug
        export RED='' GREEN='' YELLOW='' BLUE='' CYAN='' MAGENTA='' NC=''
        $(_output_source_snippet)
        output_json_result true 'build complete' null 1234 '' '[]'
    "
    echo "$output" | jq . > /dev/null 2>&1
    [ $? -eq 0 ]
    echo "$output" | jq -e '.success == true' > /dev/null
}

@test "output_json_result: schemaVersion is 2" {
    run bash -c "
        export BUILDAGENT_FANCY_UI=false VERBOSE=false JSON_OUTPUT=true
        export STATUS_DIR='${TMPDIR_TEST}' LOGS_DIR='${TMPDIR_TEST}'
        export CURRENT_ATTEMPT=0 SCHEME=Test PLATFORM=macOS BUILD_CONFIGURATION=Debug
        export RED='' GREEN='' YELLOW='' BLUE='' CYAN='' MAGENTA='' NC=''
        $(_output_source_snippet)
        output_json_result true 'ok' null 0 '' '[]'
    "
    echo "$output" | jq -e '.schemaVersion == 2' > /dev/null
}

@test "write_build_stage: creates build_stages.json in STATUS_DIR" {
    local stages_file="${TMPDIR_TEST}/build_stages.json"
    echo '{"stages":{}}' > "$stages_file"

    run bash -c "
        export BUILDAGENT_FANCY_UI=false VERBOSE=false JSON_OUTPUT=false
        export STATUS_DIR='${TMPDIR_TEST}' LOGS_DIR='${TMPDIR_TEST}'
        export CURRENT_ATTEMPT=0 SCHEME=Test PLATFORM=macOS BUILD_CONFIGURATION=Debug
        export RED='' GREEN='' YELLOW='' BLUE='' CYAN='' MAGENTA='' NC=''
        $(_output_source_snippet)
        write_build_stage 'build' 'running' 0 1
        cat '${TMPDIR_TEST}/build_stages.json'
    "
    echo "$output" | jq -e '.stages.build.status == "running"' > /dev/null
}
