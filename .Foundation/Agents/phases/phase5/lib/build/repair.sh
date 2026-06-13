#!/usr/bin/env bash
# lib/build/repair.sh — Build session state persistence and repair strategy selection (UCB1)
# select_repair_strategy: prefers the Rust helper binary when available, with Bash fallback.
[ -n "${_BUILD_REPAIR_SH:-}" ] && return 0
_BUILD_REPAIR_SH=1

# ─────────────────────────────────────────────────────────────────────────────
# Build Session State Persistence
# ─────────────────────────────────────────────────────────────────────────────

BUILD_STATE_DIR="${ARTIFACTS_DIR:-./Artifacts}/.buildagent_state"

# Compute a stable hash for a prompt string
# Usage: compute_prompt_hash <prompt_string>
compute_prompt_hash() {
    local input="$1"
    if [ -z "$input" ]; then
        echo ""
        return 0
    fi
    # Normalize: trim leading/trailing whitespace, collapse whitespace
    local normalized
    normalized=$(echo "$input" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | tr -s '[:space:]')
    printf '%s' "$normalized" | md5 2>/dev/null || printf '%s' "$normalized" | md5sum 2>/dev/null | awk '{print $1}' || echo ""
}

# Load saved build state for a given prompt hash
# Usage: load_build_state <prompt_hash>
# Returns: echoes JSON content if found, empty otherwise
load_build_state() {
    local prompt_hash="$1"
    local state_file="${BUILD_STATE_DIR}/${prompt_hash}.json"
    if [ -f "$state_file" ]; then
        cat "$state_file"
    fi
}

# Save build state for a given prompt hash
# Usage: save_build_state <prompt_hash> <status> [todos_json]
# status: "completed", "partial", "failed"
save_build_state() {
    local prompt_hash="$1"
    local status="$2"
    local todos_json="${3:-[]}"
    local input_content
    input_content=$(get_input_content)
    local preview=""
    if [ -n "$input_content" ]; then
        preview=$(echo "$input_content" | head -c 120 | tr -d '\n')
    fi

    mkdir -p "$BUILD_STATE_DIR"
    local state_file="${BUILD_STATE_DIR}/${prompt_hash}.json"

    if command -v jq >/dev/null 2>&1; then
        jq -n \
            --arg hash "$prompt_hash" \
            --arg status "$status" \
            --arg preview "$preview" \
            --arg session "$SESSION_ID" \
            --arg timestamp "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
            --argjson todos "$todos_json" \
            '{prompt_hash: $hash, status: $status, prompt_preview: $preview, session_id: $session, timestamp: $timestamp, todos: $todos}' > "$state_file"
    else
        # Fallback without jq
        cat > "$state_file" << EOF
{
  "prompt_hash": "$prompt_hash",
  "status": "$status",
  "prompt_preview": "$preview",
  "session_id": "$SESSION_ID",
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "todos": $todos_json
}
EOF
    fi
    log_verbose "Build state saved: $state_file"
}

# Check if a prompt was already completed in a previous session
# Usage: check_prompt_already_done <prompt>
# Returns: 0 if already done, 1 otherwise
check_prompt_already_done() {
    local prompt="$1"
    local prompt_hash
    prompt_hash=$(compute_prompt_hash "$prompt")
    local state
    state=$(load_build_state "$prompt_hash")

    if [ -z "$state" ]; then
        return 1
    fi

    local status
    if command -v jq >/dev/null 2>&1; then
        status=$(echo "$state" | jq -r '.status' 2>/dev/null || echo "")
    else
        status=$(echo "$state" | grep '"status"' | sed 's/.*"status".*"\([^"]*\)".*/\1/')
    fi

    if [ "$status" = "completed" ]; then
        log_info "Previous session found for this prompt ($prompt_hash) — status: completed"
        return 0
    fi

    return 1
}

# ─────────────────────────────────────────────────────────────────────────────
# Forward Search / MCTS for Repair Planning
# ─────────────────────────────────────────────────────────────────────────────

REPAIR_STRATEGY_REGISTRY="${ARTIFACTS_DIR:-./Artifacts}/.repair_strategies.json"

# Classify build errors into pattern categories
classify_error_pattern() {
    local errors="$1"
    if [ -z "$errors" ]; then
        echo "unknown"
        return 0
    fi
    if echo "$errors" | grep -qiE "cannot convert|type.*mismatch|expected.*found.*type"; then
        echo "type_error"
    elif echo "$errors" | grep -qiE "no such module|unresolved identifier|use of unresolved"; then
        echo "missing_import"
    elif echo "$errors" | grep -qiE "does not conform to protocol|protocol.*requirement"; then
        echo "protocol_conformance"
    elif echo "$errors" | grep -qiE "inaccessible.*protection|internal.*access|private.*access"; then
        echo "access_control"
    elif echo "$errors" | grep -qiE "unexpectedly found nil|force unwrap|optional.*unwrapped"; then
        echo "nil_unwrap"
    elif echo "$errors" | grep -qiE "expected expression|missing brace|syntax error"; then
        echo "syntax"
    elif echo "$errors" | grep -qiE "generic.*specialization|type.*parameter.*inferred"; then
        echo "generic"
    else
        echo "other"
    fi
}

# Select best repair strategy for an error pattern using UCB1-like exploration.
# When the foundation-repair-classifier binary is available, delegates to it
# for typed regex + accurate UCB1 math. Falls back to the Bash/awk implementation.
_REPAIR_CLASSIFIER_BIN=""
_locate_repair_classifier() {
    local candidates=(
        "${SCRIPT_DIR:-}/tools/repair-classifier/target/release/foundation-repair-classifier"
        "$(command -v foundation-repair-classifier 2>/dev/null || true)"
    )
    for c in "${candidates[@]}"; do
        if [ -n "$c" ] && [ -x "$c" ]; then
            echo "$c"
            return 0
        fi
    done
    return 1
}

select_repair_strategy() {
    local error_pattern="$1"
    local registry="$REPAIR_STRATEGY_REGISTRY"

    # Try the Rust helper binary first (typed regex + UCB1 without awk floats)
    if [ -z "$_REPAIR_CLASSIFIER_BIN" ]; then
        _REPAIR_CLASSIFIER_BIN=$(_locate_repair_classifier 2>/dev/null || echo "none")
    fi
    if [ "$_REPAIR_CLASSIFIER_BIN" != "none" ] && [ -x "$_REPAIR_CLASSIFIER_BIN" ]; then
        local result
        result=$(printf '%s' "$error_pattern" | "$_REPAIR_CLASSIFIER_BIN" --registry "$registry" 2>/dev/null || true)
        if [ -n "$result" ]; then
            # Binary returns "pattern\tstrategy"; we only need the strategy
            echo "${result#*$'\t'}"
            return 0
        fi
        # Fall through to Bash implementation on any failure
    fi

    # ── Bash/awk fallback ────────────────────────────────────────────────────
    if [ ! -f "$registry" ] || ! command -v jq >/dev/null 2>&1; then
        echo "minimal_fix"
        return 0
    fi

    local strategies
    strategies=$(jq -r ".patterns.\"$error_pattern\".strategies // {}" "$registry" 2>/dev/null)
    if [ -z "$strategies" ] || [ "$strategies" = "{}" ]; then
        echo "minimal_fix"
        return 0
    fi

    # UCB1 selection across strategies for this pattern
    local best_strategy=""
    local best_score=-1
    local total_pulls
    total_pulls=$(echo "$strategies" | jq '[.[] | (.successes + .failures)] | add' 2>/dev/null || echo "0")
    if [ -z "$total_pulls" ] || [ "$total_pulls" = "0" ] || [ "$total_pulls" = "null" ]; then
        total_pulls=1
    fi

    while IFS= read -r line; do
        local strategy="${line%%$'\t'*}"
        local stats="${line#*$'\t'}"
        local successes=$(echo "$stats" | jq '.successes // 0')
        local failures=$(echo "$stats" | jq '.failures // 0')
        local pulls=$((successes + failures))

        if [ $pulls -eq 0 ]; then
            echo "$strategy"  # Unexplored strategy — prioritize
            return 0
        fi

        local mean_reward
        mean_reward=$(awk "BEGIN {print $successes / $pulls}")
        local ucb
        ucb=$(awk -v mean="$mean_reward" -v total="$total_pulls" -v pulls="$pulls" \
              'BEGIN {print mean + 1.414 * sqrt(log(total) / pulls)}')

        if [ "$best_score" = "-1" ] || [ "$(awk -v a="$ucb" -v b="$best_score" 'BEGIN {print (a > b) ? 1 : 0}')" -eq 1 ]; then
            best_score="$ucb"
            best_strategy="$strategy"
        fi
    done <<< "$(echo "$strategies" | jq -r 'to_entries[] | "\(.key)\t\(.value)"' 2>/dev/null)"

    if [ -n "$best_strategy" ]; then
        echo "$best_strategy"
    else
        echo "minimal_fix"
    fi
}

# Record success or failure of a repair strategy
record_repair_result() {
    local error_pattern="$1"
    local strategy="$2"
    local result="$3"  # success or failure
    local registry="$REPAIR_STRATEGY_REGISTRY"

    mkdir -p "$(dirname "$registry")"
    if [ ! -f "$registry" ]; then
        echo '{"patterns":{}}' > "$registry"
    fi

    local tmp_file
    tmp_file=$(mktemp)

    if [ "$result" = "success" ]; then
        jq --arg p "$error_pattern" --arg s "$strategy" \
           '.patterns[$p] //= {"strategies":{}} | .patterns[$p].strategies[$s] //= {"successes":0,"failures":0} | .patterns[$p].strategies[$s].successes += 1' \
           "$registry" > "$tmp_file" 2>/dev/null || cat "$registry" > "$tmp_file"
    else
        jq --arg p "$error_pattern" --arg s "$strategy" \
           '.patterns[$p] //= {"strategies":{}} | .patterns[$p].strategies[$s] //= {"successes":0,"failures":0} | .patterns[$p].strategies[$s].failures += 1' \
           "$registry" > "$tmp_file" 2>/dev/null || cat "$registry" > "$tmp_file"
    fi

    mv "$tmp_file" "$registry"
}

