#!/usr/bin/env bash
# lib/build/context.sh — MD/docs filtering, context caching, and context gathering
[ -n "${_BUILD_CONTEXT_SH:-}" ] && return 0
_BUILD_CONTEXT_SH=1

read_md_files_from_dir() {
    local dir="$1"
    local content=""

    if [ ! -d "$dir" ]; then
        return
    fi

    while IFS= read -r -d '' md_file; do
        local filename
        filename=$(basename "$md_file")
        content+="
--- FILE: $filename ---
$(cat "$md_file")
--- END FILE ---
"
    done < <(find "$dir" -maxdepth 2 -name "*.md" -type f -print0 2>/dev/null)

    echo "$content"
}

# Extract keywords from error messages or prompts for doc filtering
# Returns lowercase keywords, one per line
extract_keywords_for_docs() {
    local input="$1"
    local keywords=()

    # Extract Swift type names (PascalCase identifiers)
    local types
    types=$(echo "$input" | grep -oE '\b[A-Z][a-zA-Z0-9]+\b' | sort -u)
    while IFS= read -r type; do
        [ -n "$type" ] && keywords+=("$(echo "$type" | tr '[:upper:]' '[:lower:]')")
    done <<< "$types"

    # Extract framework names from imports or common patterns
    local frameworks
    frameworks=$(echo "$input" | grep -oE '\b(SwiftUI|UIKit|Foundation|SwiftData|CoreData|Vision|AVFoundation|CoreImage|CoreML|Combine|CoreAnimation|Metal|MapKit|PhotosUI|StoreKit|CloudKit|HealthKit|HomeKit|LocalAuthentication|Security|Keychain|PDFKit|VisionKit|Charts)\b' | sort -u | tr '[:upper:]' '[:lower:]')
    while IFS= read -r fw; do
        [ -n "$fw" ] && keywords+=("$fw")
    done <<< "$frameworks"

    # Extract common Swift patterns from errors
    if echo "$input" | grep -qiE 'singleton|shared|\.shared'; then
        keywords+=("singleton" "shared" "class")
    fi
    if echo "$input" | grep -qiE '@Observable|@State|@Binding|@Environment'; then
        keywords+=("observable" "state" "binding" "swiftui")
    fi
    if echo "$input" | grep -qiE '@Model|SwiftData|PersistentModel'; then
        keywords+=("swiftdata" "model" "persistent")
    fi
    if echo "$input" | grep -qiE 'async|await|Task|actor'; then
        keywords+=("async" "concurrency" "actor" "task")
    fi
    if echo "$input" | grep -qiE 'View|body|some View'; then
        keywords+=("view" "swiftui")
    fi

    # Remove duplicates and output
    printf '%s\n' "${keywords[@]}" | sort -u | head -20
}

# Filter docs using keyword matching (fast, no AI dependency)
# Matches keywords against filenames and optionally file content
filter_docs_by_keywords() {
    local docs_dir="$1"
    shift
    local keywords=("$@")
    local matched_files=()
    local max_files=20

    if [ ${#keywords[@]} -eq 0 ]; then
        return 1
    fi

    log_verbose "Filtering docs by keywords: ${keywords[*]}"

    # Build grep pattern from keywords
    local pattern
    pattern=$(printf '%s\|' "${keywords[@]}" | sed 's/\\|$//')

    # First pass: match filenames (fast)
    while IFS= read -r -d '' file; do
        local filename
        filename=$(basename "$file" | tr '[:upper:]' '[:lower:]')
        for kw in "${keywords[@]}"; do
            if [[ "$filename" == *"$kw"* ]]; then
                matched_files+=("$file")
                break
            fi
        done
    done < <(find "$docs_dir" -name "*.md" -type f -print0 2>/dev/null)

    # If we have enough matches from filenames, return early
    if [ ${#matched_files[@]} -ge 5 ]; then
        printf '%s\n' "${matched_files[@]}" | head -$max_files
        return 0
    fi

    # Second pass: search file contents for remaining keywords (slower but thorough)
    local content_matches
    content_matches=$(grep -l -i -E "$pattern" "$docs_dir"/*.md "$docs_dir"/**/*.md 2>/dev/null | head -$((max_files - ${#matched_files[@]})) || true)

    while IFS= read -r file; do
        if [ -n "$file" ] && [ -f "$file" ]; then
            # Avoid duplicates
            local is_dup=false
            for existing in "${matched_files[@]}"; do
                if [ "$existing" = "$file" ]; then
                    is_dup=true
                    break
                fi
            done
            if [ "$is_dup" = false ]; then
                matched_files+=("$file")
            fi
        fi
    done <<< "$content_matches"

    if [ ${#matched_files[@]} -eq 0 ]; then
        return 1
    fi

    printf '%s\n' "${matched_files[@]}" | head -$max_files
    return 0
}

# Filter swift docs using AI RAG (cursor-agent or claude)
# Falls back to keyword filtering if AI unavailable
filter_swift_docs_via_ai() {
    local prompt="$1"
    local docs_dir="$2"
    local filtered_files=()

    # Try cursor-agent first (has RAG index)
    if command -v cursor-agent >/dev/null 2>&1; then
        log_verbose "Trying cursor-agent for smart docs filtering..."

        local selector_prompt="Given this task: $prompt

List ONLY the absolute file paths from $docs_dir that are most relevant to this task.
Output one path per line, nothing else. Maximum 15 files."

        local cursor_output
        cursor_output=$(cursor-agent --print --force --output-format text --workspace "$WORK_DIR" "$selector_prompt" 2>/dev/null || true)

        while IFS= read -r line; do
            local cleaned_path
            cleaned_path=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | grep -E '\.md$' || true)
            if [ -n "$cleaned_path" ] && [ -f "$cleaned_path" ]; then
                filtered_files+=("$cleaned_path")
            elif [ -n "$cleaned_path" ]; then
                local rel_path="${docs_dir}/${cleaned_path#./}"
                if [ -f "$rel_path" ]; then
                    filtered_files+=("$rel_path")
                fi
            fi
        done <<< "$cursor_output"

        if [ ${#filtered_files[@]} -gt 0 ]; then
            log_info "Smart docs (cursor-agent): Selected ${#filtered_files[@]} relevant files"
            printf '%s\n' "${filtered_files[@]}"
            return 0
        fi
    fi

    # Try claude CLI as fallback
    if command -v claude >/dev/null 2>&1; then
        log_verbose "Trying claude CLI for smart docs filtering..."

        # Get list of doc files
        local doc_list
        doc_list=$(find "$docs_dir" -name "*.md" -type f 2>/dev/null | head -200)

        local selector_prompt="Given this Swift development task/error:
$prompt

Here are available documentation files:
$doc_list

List ONLY the file paths (from the list above) that are most relevant. Output one path per line, maximum 15 files. No explanations."

        local claude_output
        claude_output=$(echo "$selector_prompt" | claude --print --dangerously-skip-permissions 2>/dev/null || true)

        while IFS= read -r line; do
            local cleaned_path
            cleaned_path=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | grep -E '\.md$' || true)
            if [ -n "$cleaned_path" ] && [ -f "$cleaned_path" ]; then
                filtered_files+=("$cleaned_path")
            fi
        done <<< "$claude_output"

        if [ ${#filtered_files[@]} -gt 0 ]; then
            log_info "Smart docs (claude): Selected ${#filtered_files[@]} relevant files"
            printf '%s\n' "${filtered_files[@]}"
            return 0
        fi
    fi

    log_verbose "AI-based filtering unavailable"
    return 1
}

# Main smart docs filter - tries AI first, falls back to keywords
filter_swift_docs() {
    local prompt="$1"
    local docs_dir="$2"

    # Try AI-based filtering first
    if filter_swift_docs_via_ai "$prompt" "$docs_dir"; then
        return 0
    fi

    # Fall back to keyword-based filtering
    log_verbose "Falling back to keyword-based doc filtering..."

    local keywords=()
    while IFS= read -r kw; do
        [ -n "$kw" ] && keywords+=("$kw")
    done < <(extract_keywords_for_docs "$prompt")

    if [ ${#keywords[@]} -gt 0 ]; then
        if filter_docs_by_keywords "$docs_dir" "${keywords[@]}"; then
            log_info "Smart docs (keywords): Filtered docs by ${#keywords[@]} keywords"
            return 0
        fi
    fi

    log_verbose "Smart filtering returned no results"
    return 1
}

# Read specific MD files (used with smart docs filtering)
read_filtered_md_files() {
    local content=""

    while IFS= read -r md_file; do
        if [ -f "$md_file" ]; then
            local filename
            filename=$(basename "$md_file")
            content+="
--- FILE: $filename ---
$(cat "$md_file")
--- END FILE ---
"
        fi
    done

    echo "$content"
}

# Gather all context into a single string
# Context cache directory (shared with test agents)
CONTEXT_CACHE_DIR="${ARTIFACTS_DIR:-./Artifacts}/.context_cache"

# Offer user a chance to skip context gathering before it starts
# Returns: 0 if user chose to skip, 1 otherwise
prompt_skip_context() {
    local description="${1:-context gathering}"

    # Only prompt if running interactively
    if [ ! -t 0 ]; then
        return 1
    fi

    # Respect env flag to disable prompt (for CI/automation)
    if [ "${SKIP_CONTEXT_PROMPT:-false}" = "true" ]; then
        return 1
    fi

    local timeout_secs=3
    local spin_chars="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
    local spin_len=${#spin_chars}
    echo "" >&2
    log_info "$description starting..."

    (
        local elapsed=0
        local spin_idx=0
        while [ $elapsed -lt $timeout_secs ]; do
            local spin_char="${spin_chars:spin_idx:1}"
            local remaining=$((timeout_secs - elapsed))
            printf "\r\033[K\033[36m[%s]\033[0m Press \033[1m's'\033[0m to skip %s (%ds left)" "$spin_char" "$description" "$remaining" >&2
            spin_idx=$(((spin_idx + 1) % spin_len))
            sleep 0.15
            local _tmp=$((elapsed * 100 + 15))
            if [ "$_tmp" -ge $(((elapsed + 1) * 100)) ]; then
                elapsed=$((elapsed + 1))
            fi
        done
        printf "\r\033[K" >&2
    ) &
    local spinner_pid=$!

    local key=""
    if IFS= read -rs -t $timeout_secs -n 1 key 2>/dev/null; then
        kill "$spinner_pid" 2>/dev/null
        wait "$spinner_pid" 2>/dev/null
        printf "\r\033[K" >&2
        if [ "$key" = "s" ] || [ "$key" = "S" ]; then
            echo "" >&2
            log_info "Skipping $description"
            echo "" >&2
            return 0
        fi
    fi

    kill "$spinner_pid" 2>/dev/null
    wait "$spinner_pid" 2>/dev/null
    printf "\r\033[K" >&2
    echo "" >&2
    return 1
}

# Compute cache key for BuildAgent context (includes prompt hash + settings)
_compute_context_cache_key() {
    local input_content="$1"
    local key_input=""

    # Hash of input/prompt
    if command -v md5 >/dev/null 2>&1; then
        key_input=$(echo "$input_content" | md5)
    elif command -v md5sum >/dev/null 2>&1; then
        key_input=$(echo "$input_content" | md5sum | awk '{print $1}')
    else
        key_input=$(echo "$input_content" | tr -dc '[:alnum:]._-' | head -c 32)
    fi

    # Add settings that affect context selection
    key_input+="|SMART_DOCS=${SMART_DOCS:-true}"
    key_input+="|SWIFT_DOCS_PATH=${SWIFT_DOCS_PATH:-}"
    for p in "${CONTEXT_PATHS[@]}"; do
        key_input+="|CTX=${p}"
    done

    echo "$key_input"
}

# Save gathered context to disk cache with manifest
_save_context_cache() {
    local key="$1"
    local context="$2"

    mkdir -p "$CONTEXT_CACHE_DIR"
    echo "$context" > "${CONTEXT_CACHE_DIR}/build_context.txt"
    echo "$key" > "${CONTEXT_CACHE_DIR}/build_key.txt"

    # Build manifest of all source paths
    local manifest="${CONTEXT_CACHE_DIR}/build_manifest.txt"
    > "$manifest"

    if [ -n "$SWIFT_DOCS_PATH" ] && [ "$SWIFT_DOCS_PATH" != "DISABLED" ] && [ -d "$SWIFT_DOCS_PATH" ]; then
        # For swift docs directory, track newest .md mtime
        local latest_mtime
        latest_mtime=$(find "$SWIFT_DOCS_PATH" -maxdepth 2 -name "*.md" -type f -exec stat -f %m {} + 2>/dev/null | sort -rn | head -1 || echo "0")
        echo "D|${SWIFT_DOCS_PATH}|${latest_mtime}|0" >> "$manifest"
    fi

    for ctx_path in "${CONTEXT_PATHS[@]}"; do
        if [ -f "$ctx_path" ]; then
            local mtime size
            mtime=$(stat -f %m "$ctx_path" 2>/dev/null || stat -c %Y "$ctx_path" 2>/dev/null || echo "0")
            size=$(stat -f %z "$ctx_path" 2>/dev/null || stat -c %s "$ctx_path" 2>/dev/null || echo "0")
            echo "F|${ctx_path}|${mtime}|${size}" >> "$manifest"
        elif [ -d "$ctx_path" ]; then
            local latest_mtime
            latest_mtime=$(find "$ctx_path" -maxdepth 2 -name "*.md" -type f -exec stat -f %m {} + 2>/dev/null | sort -rn | head -1 || echo "0")
            echo "D|${ctx_path}|${latest_mtime}|0" >> "$manifest"
        fi
    done
}

# Load cached context if key and all mtimes match
_load_context_cache() {
    local key="$1"

    local context_file="${CONTEXT_CACHE_DIR}/build_context.txt"
    local key_file="${CONTEXT_CACHE_DIR}/build_key.txt"
    local manifest="${CONTEXT_CACHE_DIR}/build_manifest.txt"

    if [ ! -f "$context_file" ] || [ ! -f "$key_file" ] || [ ! -f "$manifest" ]; then
        return 1
    fi

    local cached_key
    cached_key=$(cat "$key_file" 2>/dev/null || echo "")
    if [ "$cached_key" != "$key" ]; then
        log_verbose "Build context cache key mismatch, regathering..."
        return 1
    fi

    while IFS='|' read -r type path mtime size; do
        if [ "$type" = "F" ]; then
            if [ ! -f "$path" ]; then
                log_verbose "Build context cache stale: missing file $path"
                return 1
            fi
            local current_mtime current_size
            current_mtime=$(stat -f %m "$path" 2>/dev/null || stat -c %Y "$path" 2>/dev/null || echo "0")
            current_size=$(stat -f %z "$path" 2>/dev/null || stat -c %s "$path" 2>/dev/null || echo "0")
            if [ "$current_mtime" != "$mtime" ] || [ "$current_size" != "$size" ]; then
                log_verbose "Build context cache stale: modified file $path"
                return 1
            fi
        elif [ "$type" = "D" ]; then
            if [ ! -d "$path" ]; then
                log_verbose "Build context cache stale: missing directory $path"
                return 1
            fi
            local current_mtime
            current_mtime=$(find "$path" -maxdepth 2 -name "*.md" -type f -exec stat -f %m {} + 2>/dev/null | sort -rn | head -1 || echo "0")
            if [ "$current_mtime" != "$mtime" ]; then
                log_verbose "Build context cache stale: modified directory $path"
                return 1
            fi
        fi
    done < "$manifest"

    log_info "Using cached context (sources unchanged since last gather)"
    cat "$context_file"
    return 0
}


should_gather_context() {
    local is_followup="${1:-false}"
    local voic_file="${ARTIFACTS_DIR:-./Artifacts}/.voi_context.json"

    if [ ! -f "$voic_file" ] || ! command -v jq >/dev/null 2>&1; then
        return 0  # No data yet, gather context
    fi

    local with_ctx_attempts
    with_ctx_attempts=$(jq '.with_context.attempts // 0' "$voic_file" 2>/dev/null || echo "0")
    local without_ctx_attempts
    without_ctx_attempts=$(jq '.without_context.attempts // 0' "$voic_file" 2>/dev/null || echo "0")

    if [ "$with_ctx_attempts" -lt 3 ] || [ "$without_ctx_attempts" -lt 3 ]; then
        return 0  # Not enough data yet
    fi

    local with_ctx_avg
    with_ctx_avg=$(jq '.with_context.avg_attempts // 99' "$voic_file" 2>/dev/null || echo "99")
    local without_ctx_avg
    without_ctx_avg=$(jq '.without_context.avg_attempts // 99' "$voic_file" 2>/dev/null || echo "99")

    # Cost of gathering context: ~30 seconds + tokens
    # Benefit: reduction in expected repair attempts
    local gather_cost=1.0  # normalized cost (1 retry worth)
    local expected_savings
    expected_savings=$(awk -v with="$with_ctx_avg" -v without="$without_ctx_avg" 'BEGIN {print without - with}')

    if [ "$(awk -v s="$expected_savings" -v c="$gather_cost" 'BEGIN {print (s > c) ? 1 : 0}')" -eq 1 ]; then
        log_info "VOI: Context gathering beneficial (avg savings: ${expected_savings}x attempts)"
        return 0
    else
        log_info "VOI: Context gathering not worth cost (avg savings: ${expected_savings}x attempts)"
        return 1
    fi
}

# Record context gathering outcome for VOI learning
record_context_outcome() {
    local had_context="$1"
    local attempts="$2"
    local voic_file="${ARTIFACTS_DIR:-./Artifacts}/.voi_context.json"

    mkdir -p "$(dirname "$voic_file")"
    if [ ! -f "$voic_file" ]; then
        echo '{"with_context":{"attempts":0,"total_attempts":0,"avg_attempts":0},"without_context":{"attempts":0,"total_attempts":0,"avg_attempts":0}}' > "$voic_file"
    fi

    local key
    if [ "$had_context" = "true" ]; then
        key="with_context"
    else
        key="without_context"
    fi

    local tmp_file
    tmp_file=$(mktemp)
    jq --arg k "$key" --argjson a "$attempts" \
       '.[$k].attempts += 1 | .[$k].total_attempts += $a | .[$k].avg_attempts = (.[$k].total_attempts / .[$k].attempts)' \
       "$voic_file" > "$tmp_file" 2>/dev/null || cat "$voic_file" > "$tmp_file"
    mv "$tmp_file" "$voic_file"
}

gather_context() {
    local context=""
    local has_context=false

    # Check if there's any context to gather
    if [ -n "$SWIFT_DOCS_PATH" ] && [ "$SWIFT_DOCS_PATH" != "DISABLED" ] && [ -d "$SWIFT_DOCS_PATH" ]; then
        has_context=true
    fi

    if [ ${#CONTEXT_PATHS[@]} -gt 0 ]; then
        has_context=true
    fi

    # Try cache first
    if [ "$has_context" = true ]; then
        local cache_key input_content
        input_content=$(get_input_content)
        cache_key=$(_compute_context_cache_key "$input_content")
        if _load_context_cache "$cache_key"; then
            return 0
        fi
    fi

    # Value of Information check: is context gathering worth the cost?
    if [ "$has_context" = true ] && ! should_gather_context; then
        log_info "Skipping context gathering (VOI analysis)"
        return
    fi

    # Offer user chance to skip
    if prompt_skip_context "Context gathering"; then
        echo "" >&2
        return
    fi

    if [ "$has_context" = true ]; then
        start_spinner "Gathering context"
    fi

    # Add Swift docs if available (with smart filtering by default)
    if [ -n "$SWIFT_DOCS_PATH" ] && [ "$SWIFT_DOCS_PATH" != "DISABLED" ] && [ -d "$SWIFT_DOCS_PATH" ]; then
        log_verbose "Adding Swift docs from: $SWIFT_DOCS_PATH"
        local swift_docs_content=""
        local input_content
        input_content=$(get_input_content)

        # Try smart filtering first (AI or keyword-based)
        if [ "$SMART_DOCS" = "true" ] && [ -n "$input_content" ]; then
            local filtered_files
            if filtered_files=$(filter_swift_docs "$input_content" "$SWIFT_DOCS_PATH"); then
                swift_docs_content=$(echo "$filtered_files" | read_filtered_md_files)
            fi
        fi

        # Fall back to reading all docs if smart filtering failed or disabled
        if [ -z "$swift_docs_content" ]; then
            if [ "$SMART_DOCS" = "true" ]; then
                log_verbose "Smart docs filtering returned no results, using all docs"
            fi
            swift_docs_content=$(read_md_files_from_dir "$SWIFT_DOCS_PATH")
        fi

        if [ -n "$swift_docs_content" ]; then
            context+="
=== SWIFT DOCUMENTATION ===
$swift_docs_content
=== END SWIFT DOCUMENTATION ===
"
        fi
    fi

    # Add context from provided paths
    if [ ${#CONTEXT_PATHS[@]} -gt 0 ]; then
        for ctx_path in "${CONTEXT_PATHS[@]}"; do
            if [ -f "$ctx_path" ]; then
                log_verbose "Adding context file: $ctx_path"
                context+="
--- CONTEXT FILE: $(basename "$ctx_path") ---
$(cat "$ctx_path")
--- END CONTEXT FILE ---
"
            elif [ -d "$ctx_path" ]; then
                log_verbose "Adding context directory: $ctx_path"
                local dir_content
                dir_content=$(read_md_files_from_dir "$ctx_path")
                if [ -n "$dir_content" ]; then
                    context+="
=== CONTEXT FROM: $ctx_path ===
$dir_content
=== END CONTEXT ===
"
                fi
            fi
        done
    fi

    # Hard cap on context size before returning — prevents 5MB+ prompts
    if [ "${#context}" -gt "$MAX_CONTEXT_CHARS" ]; then
        log_warning "Context truncated from ${#context} to ${MAX_CONTEXT_CHARS} chars (set MAX_CONTEXT_CHARS env var to override)"
        context="${context:0:$MAX_CONTEXT_CHARS}"
        context+="
... [CONTEXT TRUNCATED — set MAX_CONTEXT_CHARS env var to increase limit] ..."
    fi

    # Save to cache
    if [ "$has_context" = true ]; then
        local cache_key input_content
        input_content=$(get_input_content)
        cache_key=$(_compute_context_cache_key "$input_content")
        _save_context_cache "$cache_key" "$context"
        spinner_success "Context gathered"
    fi

    echo "$context"
}

# Get the main prompt/plan content
get_input_content() {
    # Use cached content if available (avoids temp file deletion issues)
    if [ -n "$PROMPT_CONTENT" ]; then
        echo "$PROMPT_CONTENT"
        return
    fi

    # Fallback to reading files (may fail if temp files were deleted)
    local content=""
    if [ -n "$PLAN_FILE" ] && [ -f "$PLAN_FILE" ]; then
        content=$(cat "$PLAN_FILE" 2>/dev/null || true)
    elif [ -n "$PROMPT_FILE" ] && [ -f "$PROMPT_FILE" ]; then
        content=$(cat "$PROMPT_FILE" 2>/dev/null || true)
    elif [ -n "$PROMPT_STRING" ]; then
        content="$PROMPT_STRING"
    fi

    echo "$content"
}

# ─────────────────────────────────────────────────────────────────────────────
# Cursor CLI Functions (with session support)
# ─────────────────────────────────────────────────────────────────────────────

# Build the initial prompt (first attempt - includes full context)
