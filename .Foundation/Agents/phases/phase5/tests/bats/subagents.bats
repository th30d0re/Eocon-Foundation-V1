#!/usr/bin/env bats
# subagents.bats — characterization smoke tests for the four test sub-agents

load "test_helper"

PHASE5="${PHASE5_DIR}"

@test "unitTestAgent.sh --help exits 0 and shows usage" {
    run bash "${PHASE5}/unitTestAgent.sh" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"USAGE"* ]] || [[ "$output" == *"usage"* ]] || [[ "$output" == *"Usage"* ]]
}

@test "accessibilityAgent.sh --help exits 0 and shows usage" {
    run bash "${PHASE5}/accessibilityAgent.sh" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"USAGE"* ]] || [[ "$output" == *"usage"* ]] || [[ "$output" == *"Usage"* ]]
}

@test "flowAgent.sh --help exits 0 and shows usage" {
    run bash "${PHASE5}/flowAgent.sh" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"USAGE"* ]] || [[ "$output" == *"usage"* ]] || [[ "$output" == *"Usage"* ]]
}

@test "uiTestAgent.sh --help exits 0 and shows usage" {
    run bash "${PHASE5}/uiTestAgent.sh" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"USAGE"* ]] || [[ "$output" == *"usage"* ]] || [[ "$output" == *"Usage"* ]]
}

@test "testAgent.sh --help exits 0" {
    run bash "${PHASE5}/testAgent.sh" --help
    [ "$status" -eq 0 ]
}

@test "BuildAgent.sh --help exits 0 after adding BUILDAGENT_NO_MAIN guard" {
    run bash "${PHASE5}/BuildAgent.sh" --help
    [ "$status" -eq 0 ]
}

@test "BuildAgent.sh --version or --help does not execute main when BUILDAGENT_NO_MAIN=1" {
    run bash -c "
        export BUILDAGENT_NO_MAIN=1
        source '${PHASE5}/BuildAgent.sh'
        echo 'sourced_ok'
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"sourced_ok"* ]]
}
