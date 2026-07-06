#!/usr/bin/env bats
# prompt.bats — characterization tests for prompt.sh

load "test_helper"

setup() {
    export RED='' GREEN='' YELLOW='' BLUE='' CYAN='' MAGENTA='' NC=''
    load_build_lib logging >/dev/null 2>&1 || true
    load_build_lib prompt
}

@test "prompt: build_initial_prompt includes expected sections" {
    local task="Create a login view"
    local ctx="Some context here"
    
    run build_initial_prompt "$task" "$ctx"
    [ "$status" -eq 0 ]
    [[ "$output" == *"=== TASK/REQUIREMENTS ==="* ]]
    [[ "$output" == *"Create a login view"* ]]
    [[ "$output" == *"=== REFERENCE CONTEXT ==="* ]]
    [[ "$output" == *"Some context here"* ]]
    [[ "$output" == *"TESTING & DEBUGGING REFERENCE:"* ]]
}

@test "prompt: build_followup_prompt includes expected sections" {
    local error="Build failed with unknown type"
    local attempt=3
    local task="Original task"
    local ctx="Some context"
    
    run build_followup_prompt "$error" "$attempt" "$task" "$ctx"
    [ "$status" -eq 0 ]
    [[ "$output" == *"=== ORIGINAL TASK ==="* ]]
    [[ "$output" == *"Original task"* ]]
    [[ "$output" == *"=== BUILD ATTEMPT 2 FAILED ==="* ]]
    [[ "$output" == *"Build failed with unknown type"* ]]
    [[ "$output" == *"=== INSTRUCTIONS FOR ATTEMPT 3 ==="* ]]
}

@test "prompt: build_followup_prompt_with_strategy mentions chosen strategy" {
    local error="Type error"
    local attempt=2
    local task="Original task"
    local ctx="Context string"
    local strategy="add_guards"
    
    run build_followup_prompt_with_strategy "$error" "$attempt" "$task" "$ctx" "$strategy"
    [ "$status" -eq 0 ]
    [[ "$output" == *"=== REPAIR STRATEGY FOR ATTEMPT 2 ==="* ]]
    [[ "$output" == *"Selected strategy: add_guards"* ]]
    [[ "$output" == *"Add GUARDS and safety checks"* ]]
}

@test "prompt: parse_todo_file parses a fixture todo file into JSON" {
    local todo_file="$BATS_TEST_TMPDIR/todo.md"
    echo "- [ ] pending task" > "$todo_file"
    echo "- [x] done task" >> "$todo_file"
    echo "just text" >> "$todo_file" # ignored line without checkbox
    
    run parse_todo_file "$todo_file"
    [ "$status" -eq 0 ]
    [[ "$output" == *"pending task"* ]]
    [[ "$output" == *"done task"* ]]
    [[ "$output" == *"\"status\":\"pending\""* ]]
    [[ "$output" == *"\"status\":\"completed\""* ]]
    
    # check valid JSON
    echo "$output" | jq . >/dev/null
}

@test "prompt: inject_todos_into_prompt adds todos to prompt" {
    local base_prompt="This is the base prompt"
    local todos_json='[{"id":1,"task":"Task 1","status":"pending"},{"id":2,"task":"Task 2","status":"completed"}]'
    
    run inject_todos_into_prompt "$base_prompt" "$todos_json"
    [ "$status" -eq 0 ]
    [[ "$output" == *"This is the base prompt"* ]]
    [[ "$output" == *"TASK TRACKING"* ]]
    [[ "$output" == *"[pending] Task 1"* ]]
    [[ "$output" == *"[completed] Task 2"* ]]
}
