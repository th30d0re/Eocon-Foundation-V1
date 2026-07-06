#!/usr/bin/env bash
# Shared helpers for Foundation Phase 0-4 agents.
# Sourced library only: no strict mode and no top-level work beyond this guard.

[ -n "${_FOUNDATION_PHASE_AGENT_CORE_SH:-}" ] && return 0
_FOUNDATION_PHASE_AGENT_CORE_SH=1

log_info() {
    echo -e "${BLUE:-}[INFO]${NC:-} $1" >&2
}

log_success() {
    echo -e "${GREEN:-}[SUCCESS]${NC:-} $1" >&2
}

log_warning() {
    echo -e "${YELLOW:-}[WARNING]${NC:-} $1" >&2
}

log_error() {
    echo -e "${RED:-}[ERROR]${NC:-} $1" >&2
}

log_section() {
    local prefix="${LOG_PREFIX:-[PHASE-AGENT]}"
    echo -e "${CYAN:-}${prefix}${NC:-} $1" >&2
}

log_verbose() {
    if [ "${VERBOSE:-false}" = "true" ]; then
        echo -e "${CYAN:-}[VERBOSE]${NC:-} $1" >&2
    fi
}

detect_foundation_project() {
    local start_dir="$1"
    local current

    if [ -z "$start_dir" ]; then
        start_dir="$PWD"
    fi

    if ! current="$(cd "$start_dir" 2>/dev/null && pwd)"; then
        return 1
    fi

    while [ "$current" != "/" ]; do
        if [ -d "$current/Constitution" ] || [ -d "$current/.Foundation" ]; then
            printf '%s\n' "$current"
            return 0
        fi
        current="$(dirname "$current")"
    done

    return 1
}

ensure_five_folders() {
    local project_dir="$1"
    mkdir -p "$project_dir/Constitution" \
        "$project_dir/Plans" \
        "$project_dir/Guides" \
        "$project_dir/Docs" \
        "$project_dir/Design"
}

run_phase_ai() {
    local provider="$1"
    local model="$2"
    local prompt_file="$3"
    local output_hint="$4"
    local prompt
    local provider_lc

    if [ ! -f "$prompt_file" ]; then
        log_error "Prompt file not found: $prompt_file"
        return 11
    fi

    prompt="$(cat "$prompt_file")"
    provider_lc="$(printf '%s' "$provider" | tr '[:upper:]' '[:lower:]')"

    case "$provider_lc" in
        claude)
            if ! command -v claude >/dev/null 2>&1; then
                log_error "Provider CLI not found: claude"
                return 11
            fi
            if [ -n "$model" ]; then
                claude -p "$prompt" --model "$model"
            else
                claude -p "$prompt"
            fi
            ;;
        codex)
            if ! command -v codex >/dev/null 2>&1; then
                log_error "Provider CLI not found: codex"
                return 11
            fi
            if [ -n "$model" ]; then
                printf '%s\n' "$prompt" | codex exec --model "$model"
            else
                printf '%s\n' "$prompt" | codex exec
            fi
            ;;
        gemini)
            if ! command -v gemini >/dev/null 2>&1; then
                log_error "Provider CLI not found: gemini"
                return 11
            fi
            if [ -n "$model" ]; then
                gemini -m "$model" -p "$prompt"
            else
                gemini -p "$prompt"
            fi
            ;;
        cursor)
            if ! command -v cursor >/dev/null 2>&1; then
                log_error "Provider CLI not found: cursor"
                return 11
            fi
            if [ -n "$model" ]; then
                cursor agent --print --model "$model" --output-format text "$prompt" </dev/null
            else
                cursor agent --print --output-format text "$prompt" </dev/null
            fi
            ;;
        kimi)
            if ! command -v kimi >/dev/null 2>&1; then
                log_error "Provider CLI not found: kimi"
                return 11
            fi
            if [ -n "$model" ]; then
                kimi -m "$model" -p "$prompt"
            else
                kimi -p "$prompt"
            fi
            ;;
        *)
            log_error "Unsupported AI provider: $provider"
            return 11
            ;;
    esac

    log_verbose "AI provider completed for ${output_hint:-phase output}"
}

_phase_json_escape() {
    printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

write_phase_result() {
    local project_dir="$1"
    local phase="$2"
    local agent="$3"
    local status="$4"
    local outputs_json_array="$5"
    local requires_approval="$6"
    local ts
    local artifact_dir
    local started_at
    local finished_at
    local provider

    ts="$(date +"%Y%m%d_%H%M%S")"
    artifact_dir="$project_dir/Artifacts/phase${phase}_${ts}"
    mkdir -p "$artifact_dir"

    started_at="${PHASE_STARTED_AT:-$(date -u +"%Y-%m-%dT%H:%M:%SZ")}"
    finished_at="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    provider="${AI_PROVIDER:-claude}"

    case "$requires_approval" in
        true|false) ;;
        *) requires_approval="false" ;;
    esac

    if command -v jq >/dev/null 2>&1; then
        if ! printf '%s' "$outputs_json_array" | jq empty >/dev/null 2>&1; then
            outputs_json_array="[]"
        fi
        jq -n \
            --argjson schemaVersion 1 \
            --argjson phase "$phase" \
            --arg agent "$agent" \
            --arg status "$status" \
            --arg startedAt "$started_at" \
            --arg finishedAt "$finished_at" \
            --arg provider "$provider" \
            --argjson outputs "$outputs_json_array" \
            --argjson requiresApproval "$requires_approval" \
            '{schemaVersion: $schemaVersion, phase: $phase, agent: $agent, status: $status, startedAt: $startedAt, finishedAt: $finishedAt, provider: $provider, outputs: $outputs, requiresApproval: $requiresApproval, humanIntervention: null, errors: []}' \
            > "$artifact_dir/result.json"
    else
        printf '{\n' > "$artifact_dir/result.json"
        printf '  "schemaVersion": 1,\n' >> "$artifact_dir/result.json"
        printf '  "phase": %s,\n' "$phase" >> "$artifact_dir/result.json"
        printf '  "agent": "%s",\n' "$(_phase_json_escape "$agent")" >> "$artifact_dir/result.json"
        printf '  "status": "%s",\n' "$(_phase_json_escape "$status")" >> "$artifact_dir/result.json"
        printf '  "startedAt": "%s",\n' "$(_phase_json_escape "$started_at")" >> "$artifact_dir/result.json"
        printf '  "finishedAt": "%s",\n' "$(_phase_json_escape "$finished_at")" >> "$artifact_dir/result.json"
        printf '  "provider": "%s",\n' "$(_phase_json_escape "$provider")" >> "$artifact_dir/result.json"
        printf '  "outputs": %s,\n' "$outputs_json_array" >> "$artifact_dir/result.json"
        printf '  "requiresApproval": %s,\n' "$requires_approval" >> "$artifact_dir/result.json"
        printf '  "humanIntervention": null,\n' >> "$artifact_dir/result.json"
        printf '  "errors": []\n' >> "$artifact_dir/result.json"
        printf '}\n' >> "$artifact_dir/result.json"
    fi

    printf '%s\n' "$artifact_dir/result.json"
}

append_decision_log() {
    local file="$1"
    local decision="$2"
    local rationale="$3"
    local timestamp

    timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    mkdir -p "$(dirname "$file")"
    {
        printf '## %s\n' "$timestamp"
        printf -- '- Decision: %s\n' "$decision"
        printf -- '- Rationale: %s\n\n' "$rationale"
    } >> "$file"
}

phase_outputs_json_from_file() {
    local outputs_file="$1"
    if [ ! -f "$outputs_file" ]; then
        printf '[]'
        return 0
    fi

    if command -v jq >/dev/null 2>&1; then
        jq -R -s 'split("\n") | map(select(length > 0))' "$outputs_file"
    else
        awk 'BEGIN { printf "[" } NF { gsub(/\\/,"\\\\"); gsub(/"/,"\\\""); if (n++) printf ","; printf "\"%s\"", $0 } END { printf "]" }' "$outputs_file"
    fi
}

phase_extract_marked_files() {
    local project_dir="$1"
    local ai_output_file="$2"
    local outputs_file="$3"
    local current_file=""
    local rel_path=""
    local count=0
    local line

    : > "$outputs_file"
    while IFS= read -r line || [ -n "$line" ]; do
        if printf '%s\n' "$line" | grep -Eq '^---FILE: .+---$'; then
            rel_path="$(printf '%s\n' "$line" | sed -E 's/^---FILE: (.+)---$/\1/')"
            case "$rel_path" in
                /*|*..*)
                    current_file=""
                    ;;
                *)
                    current_file="$project_dir/$rel_path"
                    mkdir -p "$(dirname "$current_file")"
                    : > "$current_file"
                    printf '%s\n' "$rel_path" >> "$outputs_file"
                    count=$((count + 1))
                    ;;
            esac
        elif [ -n "$current_file" ]; then
            printf '%s\n' "$line" >> "$current_file"
        fi
    done < "$ai_output_file"

    [ "$count" -gt 0 ]
}
