#!/usr/bin/env bats
# repair.bats — characterization tests for classify_error_pattern, select_repair_strategy
# Also tests parity between the Bash fallback and the Rust binary (when built).
#
# Design note: The monolith has top-level assignments REPAIR_STRATEGY_REGISTRY and
# BUILD_STATE_DIR that execute when the snippet is sourced. Tests override these
# AFTER sourcing to avoid that race.

load "test_helper"

MONOLITH="${PHASE5_DIR}/BuildAgent.sh"
REPAIR_LIB="${PHASE5_DIR}/lib/build/repair.sh"
LOGGING_LIB="${PHASE5_DIR}/lib/build/logging.sh"

_make_repair_snippet_file() {
    local tmp
    tmp=$(mktemp /tmp/bats_repair_snippet_XXXXXX.sh)
    if [[ -f "$REPAIR_LIB" ]]; then
        [[ -f "$LOGGING_LIB" ]] && cat "$LOGGING_LIB" >> "$tmp"
        cat "$REPAIR_LIB" >> "$tmp"
    else
        awk 'NR>=263 && NR<=374' "$MONOLITH" >> "$tmp"
        awk 'NR>=3067 && NR<=3310' "$MONOLITH" >> "$tmp"
    fi
    echo "$tmp"
}

setup() {
    SNIPPET_FILE=$(_make_repair_snippet_file)
    export SNIPPET_FILE
}

teardown() {
    rm -f "${SNIPPET_FILE:-}" 2>/dev/null || true
}

# ─── classify_error_pattern ───────────────────────────────────────────────────

@test "classify_error_pattern: type mismatch -> type_error" {
    run bash -c "
        set +e
        export BUILDAGENT_FANCY_UI=false VERBOSE=false ARTIFACTS_DIR=/tmp
        export RED='' GREEN='' YELLOW='' BLUE='' CYAN='' MAGENTA='' NC=''
        source '${SNIPPET_FILE}' 2>/dev/null
        classify_error_pattern 'cannot convert value of type String to expected argument type Int'
    "
    [ "$output" = "type_error" ]
}

@test "classify_error_pattern: unresolved identifier -> missing_import" {
    run bash -c "
        set +e
        export BUILDAGENT_FANCY_UI=false VERBOSE=false ARTIFACTS_DIR=/tmp
        export RED='' GREEN='' YELLOW='' BLUE='' CYAN='' MAGENTA='' NC=''
        source '${SNIPPET_FILE}' 2>/dev/null
        classify_error_pattern 'use of unresolved identifier SwiftUI'
    "
    [ "$output" = "missing_import" ]
}

@test "classify_error_pattern: protocol conformance -> protocol_conformance" {
    run bash -c "
        set +e
        export BUILDAGENT_FANCY_UI=false VERBOSE=false ARTIFACTS_DIR=/tmp
        export RED='' GREEN='' YELLOW='' BLUE='' CYAN='' MAGENTA='' NC=''
        source '${SNIPPET_FILE}' 2>/dev/null
        classify_error_pattern 'does not conform to protocol Equatable'
    "
    [ "$output" = "protocol_conformance" ]
}

@test "classify_error_pattern: nil unwrap -> nil_unwrap" {
    run bash -c "
        set +e
        export BUILDAGENT_FANCY_UI=false VERBOSE=false ARTIFACTS_DIR=/tmp
        export RED='' GREEN='' YELLOW='' BLUE='' CYAN='' MAGENTA='' NC=''
        source '${SNIPPET_FILE}' 2>/dev/null
        classify_error_pattern 'unexpectedly found nil while unwrapping an Optional value'
    "
    [ "$output" = "nil_unwrap" ]
}

@test "classify_error_pattern: syntax error -> syntax" {
    run bash -c "
        set +e
        export BUILDAGENT_FANCY_UI=false VERBOSE=false ARTIFACTS_DIR=/tmp
        export RED='' GREEN='' YELLOW='' BLUE='' CYAN='' MAGENTA='' NC=''
        source '${SNIPPET_FILE}' 2>/dev/null
        classify_error_pattern 'expected expression after return statement'
    "
    [ "$output" = "syntax" ]
}

@test "classify_error_pattern: empty input -> unknown" {
    run bash -c "
        set +e
        export BUILDAGENT_FANCY_UI=false VERBOSE=false ARTIFACTS_DIR=/tmp
        export RED='' GREEN='' YELLOW='' BLUE='' CYAN='' MAGENTA='' NC=''
        source '${SNIPPET_FILE}' 2>/dev/null
        classify_error_pattern ''
    "
    [ "$output" = "unknown" ]
}

@test "classify_error_pattern: unrecognized error -> other" {
    run bash -c "
        set +e
        export BUILDAGENT_FANCY_UI=false VERBOSE=false ARTIFACTS_DIR=/tmp
        export RED='' GREEN='' YELLOW='' BLUE='' CYAN='' MAGENTA='' NC=''
        source '${SNIPPET_FILE}' 2>/dev/null
        classify_error_pattern 'some completely unknown error XYZ123'
    "
    [ "$output" = "other" ]
}

# ─── select_repair_strategy ───────────────────────────────────────────────────

@test "select_repair_strategy: no registry file -> minimal_fix" {
    run bash -c "
        set +e
        export BUILDAGENT_FANCY_UI=false VERBOSE=false ARTIFACTS_DIR=/tmp
        export RED='' GREEN='' YELLOW='' BLUE='' CYAN='' MAGENTA='' NC=''
        source '${SNIPPET_FILE}' 2>/dev/null
        # Override AFTER source to win over top-level assignment in snippet
        REPAIR_STRATEGY_REGISTRY=/tmp/nonexistent_registry_\$\$.json
        select_repair_strategy 'type_error'
    "
    [ "$output" = "minimal_fix" ]
}

@test "select_repair_strategy: unexplored strategy is prioritized" {
    local registry
    registry=$(mktemp /tmp/bats_registry_XXXXXX.json)
    cat > "$registry" << 'EOF'
{
  "patterns": {
    "type_error": {
      "strategies": {
        "minimal_fix":       { "successes": 5, "failures": 1 },
        "rewrite_signature": { "successes": 0, "failures": 0 }
      }
    }
  }
}
EOF
    run bash -c "
        set +e
        export BUILDAGENT_FANCY_UI=false VERBOSE=false ARTIFACTS_DIR=/tmp
        export RED='' GREEN='' YELLOW='' BLUE='' CYAN='' MAGENTA='' NC=''
        source '${SNIPPET_FILE}' 2>/dev/null
        REPAIR_STRATEGY_REGISTRY='${registry}'
        select_repair_strategy 'type_error'
    "
    rm -f "$registry"
    [ "$output" = "rewrite_signature" ]
}

@test "select_repair_strategy: unknown pattern -> minimal_fix" {
    local registry
    registry=$(mktemp /tmp/bats_registry_XXXXXX.json)
    echo '{"patterns":{}}' > "$registry"
    run bash -c "
        set +e
        export BUILDAGENT_FANCY_UI=false VERBOSE=false ARTIFACTS_DIR=/tmp
        export RED='' GREEN='' YELLOW='' BLUE='' CYAN='' MAGENTA='' NC=''
        source '${SNIPPET_FILE}' 2>/dev/null
        REPAIR_STRATEGY_REGISTRY='${registry}'
        select_repair_strategy 'no_such_pattern'
    "
    rm -f "$registry"
    [ "$output" = "minimal_fix" ]
}

# ─── compute_prompt_hash ─────────────────────────────────────────────────────

@test "compute_prompt_hash: identical prompts produce same hash" {
    run bash -c "
        set +e
        export BUILDAGENT_FANCY_UI=false VERBOSE=false ARTIFACTS_DIR=/tmp
        export RED='' GREEN='' YELLOW='' BLUE='' CYAN='' MAGENTA='' NC=''
        source '${SNIPPET_FILE}' 2>/dev/null
        h1=\$(compute_prompt_hash 'Fix the login button')
        h2=\$(compute_prompt_hash 'Fix the login button')
        [ \"\$h1\" = \"\$h2\" ] && echo 'match' || echo 'mismatch'
    "
    [ "$output" = "match" ]
}

@test "compute_prompt_hash: different prompts produce different hashes" {
    run bash -c "
        set +e
        export BUILDAGENT_FANCY_UI=false VERBOSE=false ARTIFACTS_DIR=/tmp
        export RED='' GREEN='' YELLOW='' BLUE='' CYAN='' MAGENTA='' NC=''
        source '${SNIPPET_FILE}' 2>/dev/null
        h1=\$(compute_prompt_hash 'Fix the login button')
        h2=\$(compute_prompt_hash 'Add a logout button')
        [ \"\$h1\" != \"\$h2\" ] && echo 'different' || echo 'same'
    "
    [ "$output" = "different" ]
}

# ─── Rust binary parity ───────────────────────────────────────────────────────

@test "Rust binary classify+select matches Bash for type_error (unexplored)" {
    local binary="${PHASE5_DIR}/tools/repair-classifier/target/release/foundation-repair-classifier"
    if [[ ! -x "$binary" ]]; then
        skip "foundation-repair-classifier not built yet (run: cargo build --release)"
    fi

    local registry
    registry=$(mktemp /tmp/bats_registry_XXXXXX.json)
    echo '{"patterns":{"type_error":{"strategies":{"minimal_fix":{"successes":0,"failures":0}}}}}' > "$registry"

    local rust_out
    rust_out=$(echo "cannot convert value of type String" | "$binary" --registry "$registry")

    local bash_out
    bash_out=$(bash -c "
        set +e
        export BUILDAGENT_FANCY_UI=false VERBOSE=false ARTIFACTS_DIR=/tmp
        export RED='' GREEN='' YELLOW='' BLUE='' CYAN='' MAGENTA='' NC=''
        source '${SNIPPET_FILE}' 2>/dev/null
        REPAIR_STRATEGY_REGISTRY='${registry}'
        pattern=\$(classify_error_pattern 'cannot convert value of type String')
        strategy=\$(select_repair_strategy \"\$pattern\")
        printf '%s\t%s' \"\$pattern\" \"\$strategy\"
    ")
    rm -f "$registry"
    [ "$rust_out" = "$bash_out" ]
}
