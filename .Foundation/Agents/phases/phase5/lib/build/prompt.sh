#!/usr/bin/env bash
# lib/build/prompt.sh — Initial and follow-up prompt construction, todo injection, chat ID
[ -n "${_BUILD_PROMPT_SH:-}" ] && return 0
_BUILD_PROMPT_SH=1

build_followup_prompt_with_strategy() {
    local error_feedback="$1"
    local attempt_num="$2"
    local original_task="$3"
    local context="$4"
    local strategy="$5"

    local strategy_instructions=""
    case "$strategy" in
        minimal_fix)
            strategy_instructions="Apply the MINIMAL possible fix — change only what's necessary to resolve the reported errors. Do not refactor or rewrite unrelated code."
            ;;
        rewrite_file)
            strategy_instructions="REWRITE the entire implementation from scratch. The current approach may have fundamental flaws. Start fresh with a clean, correct implementation."
            ;;
        add_guards)
            strategy_instructions="Add GUARDS and safety checks (nil checks, bounds checks, error handling). The code likely fails because it assumes valid inputs or states that aren't guaranteed."
            ;;
        refactor_types)
            strategy_instructions="REFACTOR the type signatures and casts. The code likely has type mismatches — ensure all variables, parameters, and return types are correctly declared and converted."
            ;;
        alternative_impl)
            strategy_instructions="Try a COMPLETELY DIFFERENT implementation approach. If you were using approach A, try approach B. Use different algorithms, data structures, or design patterns."
            ;;
    esac

    local prompt="You are a Swift/SwiftUI developer. A previous attempt to complete a task failed.

TESTING & DEBUGGING REFERENCE:
For building, testing, and debugging iOS/macOS apps, reference this workflow guide:
${PROJECT_ROOT}/.Foundation/Docs/swiftDocs/Testing/XCODEBUILD_MCP_WORKFLOW.md

This guide covers:
- XcodeBuild MCP server tools for programmatic Xcode interaction
- Building for simulator, booting simulators, installing/launching apps
- UI automation: screenshots, accessibility hierarchy, tap simulation
- Debugging UI issues (button taps, gestures, navigation)

=== ORIGINAL TASK ===
$original_task
=== END ORIGINAL TASK ===
"

    if [ -n "$context" ]; then
        prompt+="
=== REFERENCE CONTEXT ===
$context
=== END CONTEXT ===
"
    fi

    if [ -n "$LETTA_MEMORY_CONTEXT" ]; then
        prompt+="
$LETTA_MEMORY_CONTEXT
"
    fi

    prompt+="
=== BUILD ATTEMPT $((attempt_num - 1)) FAILED ===
The previous implementation failed with the following errors:

$error_feedback

=== REPAIR STRATEGY FOR ATTEMPT $attempt_num ===
Selected strategy: $strategy
$strategy_instructions

1. Analyze what went wrong in the previous approach
2. Apply the selected repair strategy above
3. Do NOT repeat the same mistakes
4. Write the corrected code directly - do not explain, just implement

Please fix the issues and provide the corrected implementation."

    echo "$prompt"
}

# Parse a todo file into a JSON array string
# Usage: parse_todo_file <file_path>
# Returns: JSON array string like '[{"id":1,"task":"...","status":"pending"},...]'
parse_todo_file() {
    local file_path="$1"
    if [ ! -f "$file_path" ]; then
        echo "[]"
        return 0
    fi

    local todos="["
    local id=0
    local first=true
    while IFS= read -r line || [ -n "$line" ]; do
        # Skip empty lines and comments
        [ -z "$line" ] && continue
        [[ "$line" =~ ^[[:space:]]*# ]] && continue

        # Strip leading markdown checkbox if present
        local task
        task=$(echo "$line" | sed -E 's/^[[:space:]]*(- |[[:space:]]*)?(\[x\]|\[ \])[[:space:]]*//')
        [ -z "$task" ] && continue

        # Detect status from checkbox
        local status="pending"
        if echo "$line" | grep -qE '^[[:space:]]*(- |[[:space:]]*)?\[x\]'; then
            status="completed"
        fi

        id=$((id + 1))
        if [ "$first" = "true" ]; then
            first=false
        else
            todos+=","
        fi
        # Escape for JSON
        local escaped_task
        escaped_task=$(echo "$task" | sed 's/\\/\\\\/g; s/"/\\"/g')
        todos+="{\"id\":$id,\"task\":\"$escaped_task\",\"status\":\"$status\"}"
    done < "$file_path"
    todos+="]"

    echo "$todos"
}

# Inject todos into a prompt string
# Usage: inject_todos_into_prompt <prompt> <todos_json>
inject_todos_into_prompt() {
    local prompt="$1"
    local todos_json="$2"

    if [ "$todos_json" = "[]" ]; then
        echo "$prompt"
        return 0
    fi

    local todo_list
    if command -v jq >/dev/null 2>&1; then
        todo_list=$(echo "$todos_json" | jq -r '.[] | "\(.id). [\(.status)] \(.task)"' 2>/dev/null)
    else
        todo_list=$(echo "$todos_json" | grep -o '"task":"[^"]*"' | sed 's/"task":"//;s/"$//' | nl -w1 -s'. ')
    fi

    echo "$prompt

TASK TRACKING — Please update the status of these items as you work:
$todo_list

Mark completed items with [x] and pending items with [ ]."
}

# Value of Information for Context Gathering
# Returns 0 if context gathering is worth the cost, 1 otherwise

build_initial_prompt() {
    local input_content="$1"
    local context="$2"

    local prompt="You are a Swift/SwiftUI developer. Your task is to implement the following requirements.

IMPORTANT INSTRUCTIONS:
1. Write clean, production-ready Swift code
2. Follow Apple's Swift API Design Guidelines
3. Use SwiftUI for UI components where appropriate
4. Include proper error handling
5. The code must compile without errors
6. After writing code, the build will be verified automatically
7. If the build fails, you will receive error feedback and should try a DIFFERENT approach

TESTING & DEBUGGING REFERENCE:
For building, testing, and debugging iOS/macOS apps, reference this workflow guide:
${PROJECT_ROOT}/.Foundation/Docs/swiftDocs/Testing/XCODEBUILD_MCP_WORKFLOW.md

This guide covers:
- XcodeBuild MCP server tools for programmatic Xcode interaction
- Building for simulator, booting simulators, installing/launching apps
- UI automation: screenshots, accessibility hierarchy, tap simulation
- Debugging UI issues (button taps, gestures, navigation)

=== TASK/REQUIREMENTS ===
$input_content
=== END TASK ===
"

    if [ -n "$context" ]; then
        prompt+="

=== REFERENCE CONTEXT ===
Use the following documentation and context as reference:
$context
=== END CONTEXT ===
"
    fi

    # Inject todo items if available
    if [ -n "${TODO_FILE:-}" ] && [ -f "$TODO_FILE" ]; then
        local todos_str
        todos_str=$(parse_todo_file "$TODO_FILE" | jq -r '.[] | "- \(.text) [\(.status)]"' 2>/dev/null || echo "")
        if [ -n "$todos_str" ]; then
            prompt+="

=== TODO ITEMS ===
Track your progress against these items. Mark each as [x] when done:
$todos_str
=== END TODO ===
"
        fi
    fi

    # Inject memory context if available (learned patterns from previous sessions)
    if [ -n "$LETTA_MEMORY_CONTEXT" ]; then
        prompt+="
$LETTA_MEMORY_CONTEXT
"
    fi

    prompt+="

Please implement the requirements above. Write the code directly - do not explain, just write the implementation."

    echo "$prompt"
}

# Build follow-up prompt (subsequent attempts - includes original task + error feedback)
build_followup_prompt() {
    local error_feedback="$1"
    local attempt_num="$2"
    local original_task="$3"
    local context="$4"

    local prompt="You are a Swift/SwiftUI developer. A previous attempt to complete a task failed.

TESTING & DEBUGGING REFERENCE:
For building, testing, and debugging iOS/macOS apps, reference this workflow guide:
${PROJECT_ROOT}/.Foundation/Docs/swiftDocs/Testing/XCODEBUILD_MCP_WORKFLOW.md

This guide covers:
- XcodeBuild MCP server tools for programmatic Xcode interaction
- Building for simulator, booting simulators, installing/launching apps
- UI automation: screenshots, accessibility hierarchy, tap simulation
- Debugging UI issues (button taps, gestures, navigation)

=== ORIGINAL TASK ===
$original_task
=== END ORIGINAL TASK ===
"

    if [ -n "$context" ]; then
        prompt+="
=== REFERENCE CONTEXT ===
$context
=== END CONTEXT ===
"
    fi

    # Inject memory context if available (learned patterns from previous sessions)
    if [ -n "$LETTA_MEMORY_CONTEXT" ]; then
        prompt+="
$LETTA_MEMORY_CONTEXT
"
    fi

    prompt+="
=== BUILD ATTEMPT $((attempt_num - 1)) FAILED ===
The previous implementation failed with the following errors:

$error_feedback

=== INSTRUCTIONS FOR ATTEMPT $attempt_num ===
1. Analyze what went wrong in the previous approach
2. Try a DIFFERENT approach or fix the specific issues
3. Do NOT repeat the same mistakes
4. If the same approach keeps failing, consider an alternative implementation strategy
5. Write the corrected code directly - do not explain, just implement

Please fix the issues and provide the corrected implementation."

    echo "$prompt"
}

# Update session context file (tracks attempts for debugging)
update_session_context() {
    local attempt="$1"
    local status="$2"
    local details="${3:-}"

    {
        echo "## Attempt $attempt"
        echo "Status: $status"
        echo "Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
        if [ -n "$details" ]; then
            echo "Details:"
            echo '```'
            echo "$details" | head -50
            echo '```'
        fi
        echo ""
    } >> "$SESSION_FILE"
}

# Get the latest chat ID (currently only supported for Cursor)
get_latest_chat_id() {
    # Only supported for cursor-agent format
    if [ "$AI_PROVIDER" = "cursor" ] && [ "$AI_CMD" = "cursor-agent" ]; then
        # Try to get the latest chat ID with timeout to prevent hangs
        local chat_list
        local pid

        # Run cursor-agent ls in background with kill-based timeout
        # This is more reliable than timeout command which can't handle stopped processes
        if command -v timeout >/dev/null 2>&1 || command -v gtimeout >/dev/null 2>&1; then
            # Create temp file for output
            local tmpfile
            tmpfile=$(mktemp)

            # Run in background
            (cd "$PROJECT_ROOT" && cursor-agent ls 2>/dev/null | head -1 > "$tmpfile") &
            pid=$!

            # Wait max 2 seconds
            local count=0
            while [ $count -lt 20 ]; do
                if ! kill -0 "$pid" 2>/dev/null; then
                    # Process finished
                    chat_list=$(cat "$tmpfile" 2>/dev/null)
                    rm -f "$tmpfile"
                    break
                fi
                sleep 0.1
                count=$((count + 1))
            done

            # Kill if still running
            if kill -0 "$pid" 2>/dev/null; then
                kill -9 "$pid" 2>/dev/null
                wait "$pid" 2>/dev/null
                log_verbose "cursor-agent ls timed out after 2 seconds"
            fi
            rm -f "$tmpfile"
        else
            # No timeout available, skip to avoid potential hang
            log_verbose "timeout command not available, skipping chat ID capture"
            echo ""
            return
        fi

        if [ -n "$chat_list" ]; then
            # Extract chat ID (usually first field or UUID-like string)
            echo "$chat_list" | awk '{print $1}' | head -1
        fi
    fi
    # Return empty if not available or not supported for this provider
    echo ""
}

# Write an event to the stream timeline log
