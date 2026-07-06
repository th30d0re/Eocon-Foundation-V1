#!/usr/bin/env bash
# Shared helpers for Phase 0-4 bats tests.

BATS_TEST_DIRNAME="${BATS_TEST_DIRNAME:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
PHASES_DIR="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"

agent_path() {
    local rel="$1"
    printf '%s/%s\n' "$PHASES_DIR" "$rel"
}

make_project() {
    local project
    project="$(mktemp -d "${TMPDIR:-/tmp}/foundation_phase_agents_XXXXXX")"
    mkdir -p "$project"
    printf '%s\n' "$project"
}

latest_result() {
    local project="$1"
    local phase="$2"
    ls -d "$project/Artifacts/phase${phase}_"* 2>/dev/null | sort | tail -1 | sed 's|$|/result.json|'
}

assert_result() {
    local project="$1"
    local phase="$2"
    local expected_status="$3"
    local result
    result="$(latest_result "$project" "$phase")"
    [ -f "$result" ]
    [ "$(jq -r '.status' "$result")" = "$expected_status" ]
    [ "$(jq -r '.phase' "$result")" = "$phase" ]
}
