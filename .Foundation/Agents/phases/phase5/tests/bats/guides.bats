#!/usr/bin/env bats

load "test_helper"

setup() {
    export PROJECT_ROOT="${BATS_TEST_TMPDIR}/project"
    mkdir -p "${PROJECT_ROOT}/Guides"
    
    # Need logging so log_success does not fail
    load_build_lib logging
    load_build_lib output
}

teardown() {
    rm -rf "${BATS_TEST_TMPDIR}/project"
}

@test "guides: respects BUILD_GUIDES=0 flag" {
    export BUILD_GUIDES="0"
    
    run write_build_guide
    [ "$status" -eq 0 ]
    
    # Should not create any guide files
    local guide_count=$(ls -1 "${PROJECT_ROOT}/Guides" 2>/dev/null | wc -l | tr -d ' ')
    [ "$guide_count" -eq 0 ]
}

@test "guides: respects DRY_RUN=true flag" {
    export DRY_RUN="true"
    
    run write_build_guide
    [ "$status" -eq 0 ]
    
    local guide_count=$(ls -1 "${PROJECT_ROOT}/Guides" 2>/dev/null | wc -l | tr -d ' ')
    [ "$guide_count" -eq 0 ]
}

@test "guides: creates guide file in Guides/ directory with current timestamp" {
    export BUILD_GUIDES="1"
    
    run write_build_guide
    [ "$status" -eq 0 ]
    
    local guide_count=$(ls -1 "${PROJECT_ROOT}/Guides" 2>/dev/null | wc -l | tr -d ' ')
    [ "$guide_count" -eq 1 ]
    
    local guide_file=$(ls -1 "${PROJECT_ROOT}/Guides/build_"*.md 2>/dev/null)
    [ -f "$guide_file" ]
}

@test "guides: populates guide with strategies and errors" {
    export BUILD_GUIDES="1"
    export ACCUMULATED_STRATEGIES="strategy_a, strategy_b"
    export ACCUMULATED_ERRORS="pattern_x, pattern_y"
    
    run write_build_guide
    [ "$status" -eq 0 ]
    
    local guide_file=$(ls -1 "${PROJECT_ROOT}/Guides/build_"*.md 2>/dev/null | head -n 1)
    
    run cat "$guide_file"
    [[ "$output" == *"strategy_a, strategy_b"* ]]
    [[ "$output" == *"pattern_x, pattern_y"* ]]
}

@test "guides: includes prompt summary if PROMPT_CONTENT is set" {
    export BUILD_GUIDES="1"
    export PROMPT_CONTENT="Line 1
Line 2
Line 3"
    
    run write_build_guide
    [ "$status" -eq 0 ]
    
    local guide_file=$(ls -1 "${PROJECT_ROOT}/Guides/build_"*.md 2>/dev/null | head -n 1)
    
    run cat "$guide_file"
    [[ "$output" == *"Line 1"* ]]
    [[ "$output" == *"Line 2"* ]]
    [[ "$output" == *"Line 3"* ]]
}
