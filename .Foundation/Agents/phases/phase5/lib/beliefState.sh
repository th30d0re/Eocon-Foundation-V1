#!/usr/bin/env bash
# Belief State Tracking for Code Understanding
# Tracks what the AI "knows" about the codebase to optimize context inclusion
#
# Usage: source this file, then call:
#   init_belief_state <project_dir>
#   update_belief <file_path> <content_hash> <types_found>
#   should_include_file <file_path> <content_hash> → 0 if should include, 1 if belief is current
#   get_belief_summary → human-readable summary

set -euo pipefail

BELIEF_STATE_FILE="${ARTIFACTS_DIR:-./Artifacts}/.belief_state.json"
BELIEF_PROJECT_DIR=""

# Initialize belief state for a project
init_belief_state() {
    local project_dir="$1"
    BELIEF_PROJECT_DIR="$project_dir"
    if [ ! -f "$BELIEF_STATE_FILE" ]; then
        mkdir -p "$(dirname "$BELIEF_STATE_FILE")"
        echo '{"files":{},"last_updated":""}' > "$BELIEF_STATE_FILE"
    fi
}

# Update belief for a file after the AI has seen it
update_belief() {
    local file_path="$1"
    local content_hash="$2"
    local types_found="${3:-}"
    local file_name
    file_name=$(basename "$file_path")

    if [ ! -f "$BELIEF_STATE_FILE" ]; then
        return 0
    fi

    local tmp_file
    tmp_file=$(mktemp)
    jq --arg f "$file_name" --arg h "$content_hash" --arg t "$types_found" --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
       '.files[$f] = {"hash": $h, "types": $t, "last_seen": $ts, "confidence": 0.8}' \
       "$BELIEF_STATE_FILE" > "$tmp_file" 2>/dev/null || cat "$BELIEF_STATE_FILE" > "$tmp_file"
    mv "$tmp_file" "$BELIEF_STATE_FILE"
}

# Check if a file should be included in context (belief is stale or missing)
should_include_file() {
    local file_path="$1"
    local current_hash="$2"
    local file_name
    file_name=$(basename "$file_path")

    if [ ! -f "$BELIEF_STATE_FILE" ]; then
        return 0  # No belief state, include everything
    fi

    local stored_hash
    stored_hash=$(jq -r ".files.\"$file_name\".hash // \"\"" "$BELIEF_STATE_FILE" 2>/dev/null || echo "")

    if [ -z "$stored_hash" ]; then
        return 0  # No belief for this file, must include
    fi

    if [ "$stored_hash" != "$current_hash" ]; then
        return 0  # File changed since last seen, must include
    fi

    return 1  # Belief is current, can skip
}

# Get files that need context inclusion (changed or unseen)
get_files_needing_context() {
    local file_list="$1"
    local need_context=()

    while IFS= read -r file; do
        [ -z "$file" ] && continue
        if [ ! -f "$file" ]; then
            continue
        fi
        local current_hash
        current_hash=$(md5 -q "$file" 2>/dev/null || md5sum "$file" 2>/dev/null | awk '{print $1}' || echo "")
        if should_include_file "$file" "$current_hash"; then
            need_context+=("$file")
        fi
    done <<< "$file_list"

    printf '%s\n' "${need_context[@]}"
}

# Mark all files in a directory as seen (after context sent to AI)
mark_directory_seen() {
    local dir="$1"
    if [ ! -d "$dir" ]; then
        return 0
    fi

    while IFS= read -r file; do
        [ -z "$file" ] && continue
        local content_hash
        content_hash=$(md5 -q "$file" 2>/dev/null || md5sum "$file" 2>/dev/null | awk '{print $1}' || echo "")
        local types_found
        types_found=$(grep -oE "^(class|struct|enum|actor|protocol|extension)\s+\w+" "$file" 2>/dev/null | sed 's/[:{].*$//' | tr '\n' ',' || echo "")
        update_belief "$file" "$content_hash" "$types_found"
    done < <(find "$dir" -name "*.swift" -type f 2>/dev/null)
}

# Get summary of belief state
get_belief_summary() {
    if [ ! -f "$BELIEF_STATE_FILE" ]; then
        echo "No belief state"
        return 0
    fi

    local total_files known_files
    total_files=$(find "${BELIEF_PROJECT_DIR:-.}" -name "*.swift" -type f 2>/dev/null | wc -l | tr -d ' ')
    known_files=$(jq '.files | length' "$BELIEF_STATE_FILE" 2>/dev/null || echo "0")

    echo "Belief state: $known_files/$total_files files known"
    jq -r '.files | to_entries | map("\(.key): seen \(.value.last_seen), types=[\(.value.types)]") | .[]' "$BELIEF_STATE_FILE" 2>/dev/null || true
}

export -f init_belief_state
export -f update_belief
export -f should_include_file
export -f get_files_needing_context
export -f mark_directory_seen
export -f get_belief_summary
