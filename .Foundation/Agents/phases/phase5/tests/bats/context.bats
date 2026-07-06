#!/usr/bin/env bats
# context.bats — characterization tests for context.sh

load "test_helper"

setup() {
    export ARTIFACTS_DIR="$BATS_TEST_TMPDIR/artifacts"
    export CONTEXT_CACHE_DIR="$ARTIFACTS_DIR/.context_cache"
    mkdir -p "$ARTIFACTS_DIR"
    
    export RED='' GREEN='' YELLOW='' BLUE='' CYAN='' MAGENTA='' NC=''
    
    load_build_lib logging >/dev/null 2>&1 || true
    
    # Mock UI functions
    log_verbose() { :; }
    log_info() { :; }
    log_warning() { :; }
    start_spinner() { :; }
    stop_spinner() { :; }
    spinner_success() { :; }
    
    load_build_lib context
}

@test "context: _compute_context_cache_key returns stable hash for same inputs" {
    local key1
    local key2
    key1=$(_compute_context_cache_key "my test prompt")
    key2=$(_compute_context_cache_key "my test prompt")
    
    [ -n "$key1" ]
    [ "$key1" = "$key2" ]
}

@test "context: _compute_context_cache_key returns different hash for different inputs" {
    local key1
    local key2
    key1=$(_compute_context_cache_key "prompt A")
    key2=$(_compute_context_cache_key "prompt B")
    
    [ "$key1" != "$key2" ]
}

@test "context: _save_context_cache and _load_context_cache round-trip" {
    local key="test_key_123"
    local content="this is my cached context"
    
    # No context file initially
    run _load_context_cache "$key"
    [ "$status" -eq 1 ]
    
    # Save it
    _save_context_cache "$key" "$content"
    [ -f "$CONTEXT_CACHE_DIR/build_context.txt" ]
    [ -f "$CONTEXT_CACHE_DIR/build_key.txt" ]
    [ -f "$CONTEXT_CACHE_DIR/build_manifest.txt" ]
    
    # Load it
    run _load_context_cache "$key"
    [ "$status" -eq 0 ]
    [[ "$output" == *"$content"* ]]
}

@test "context: _load_context_cache fails if key mismatches" {
    local key="test_key_123"
    local content="this is my cached context"
    
    _save_context_cache "$key" "$content"
    
    run _load_context_cache "wrong_key"
    [ "$status" -eq 1 ]
}

@test "context: read_md_files_from_dir reads md files from fixture dir" {
    local fixture_dir="$BATS_TEST_TMPDIR/docs"
    mkdir -p "$fixture_dir"
    echo "Doc 1" > "$fixture_dir/one.md"
    echo "Doc 2" > "$fixture_dir/two.md"
    echo "Not a doc" > "$fixture_dir/ignore.txt"
    
    run read_md_files_from_dir "$fixture_dir"
    [ "$status" -eq 0 ]
    [[ "$output" == *"FILE: one.md"* ]]
    [[ "$output" == *"Doc 1"* ]]
    [[ "$output" == *"FILE: two.md"* ]]
    [[ "$output" == *"Doc 2"* ]]
    [[ "$output" != *"ignore.txt"* ]]
}
