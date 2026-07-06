#!/usr/bin/env bash
# Purpose: Phase 4 Stages Agent - dependency DAG to stages.md and stages.json.
# Exit Codes: 0 success/dry-run/help, 10 failed after retries, 11 misconfiguration, 20 human intervention.

set -euo pipefail

if [ -z "${BASH_VERSION:-}" ]; then
    echo "Error: This script requires bash" >&2
    exit 11
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PHASES_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
FOUNDATION_DIR="$(cd "${PHASES_DIR}/../.." && pwd)"
HELPERS_LIB="${FOUNDATION_DIR}/lib/helpers.sh"
CORE_LIB="${PHASES_DIR}/shared/agentCore.sh"

if [ -f "$HELPERS_LIB" ]; then
    # shellcheck disable=SC1090
    source "$HELPERS_LIB"
    if type check_shell_compatibility >/dev/null 2>&1; then
        check_shell_compatibility || exit 11
    fi
fi

# shellcheck disable=SC1090
source "$CORE_LIB"

VERSION="0.1.0"
PROJECT_DIR=""
AI_PROVIDER="claude"
MODEL=""
YOLO="false"
DRY_RUN="false"
VERBOSE="false"
PLANS_DIR=""

usage() {
    cat <<'USAGE'
StagesAgent.sh - Phase 4 Stages Agent

Usage:
  StagesAgent.sh [--plans-dir <dir>] [contract flags]

Contract flags:
  --project-dir <dir>    Foundation project root
  --ai-provider <p>      claude (default), codex, gemini, cursor, kimi
  --model <m>            optional model override
  --yolo                 fully autonomous; no interactive prompts
  --dry-run              no AI/network calls; write scaffold outputs
  --verbose              debug logging
  --help                 print this help and exit 0
  --version              print semver and exit 0

Phase 4 input flags:
  --plans-dir <dir>      Plans directory (default: <project>/Plans)
USAGE
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --project-dir) PROJECT_DIR="${2:-}"; shift 2 ;;
        --ai-provider) AI_PROVIDER="${2:-}"; shift 2 ;;
        --model) MODEL="${2:-}"; shift 2 ;;
        --yolo) YOLO="true"; shift ;;
        --dry-run) DRY_RUN="true"; shift ;;
        --verbose) VERBOSE="true"; shift ;;
        --plans-dir) PLANS_DIR="${2:-}"; shift 2 ;;
        --help|-h) usage; exit 0 ;;
        --version) printf '%s\n' "$VERSION"; exit 0 ;;
        *) log_error "Unknown flag: $1"; usage >&2; exit 11 ;;
    esac
done

export AI_PROVIDER VERBOSE
PHASE_STARTED_AT="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
export PHASE_STARTED_AT

if [ -z "$PROJECT_DIR" ]; then
    if ! PROJECT_DIR="$(detect_foundation_project "$PWD")"; then
        log_error "Could not detect Foundation project. Provide --project-dir."
        exit 11
    fi
fi
mkdir -p "$PROJECT_DIR" || { log_error "Cannot create project dir: $PROJECT_DIR"; exit 11; }
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"
ensure_five_folders "$PROJECT_DIR"

if [ -z "$PLANS_DIR" ]; then
    PLANS_DIR="$PROJECT_DIR/Plans"
fi

write_dry_run_outputs() {
    mkdir -p "$PROJECT_DIR/Plans"
    cat > "$PROJECT_DIR/Plans/stages.md" <<'EOF'
# Execution Stages

<!-- DRY-RUN PLACEHOLDER -->

## Stage 1 (Parallel)
- plan1/wave1

## Critical Path
plan1
EOF
    cat > "$PROJECT_DIR/Plans/stages.json" <<'EOF'
{
  "schemaVersion": 1,
  "stages": [
    { "stage": 1, "parallel": true, "waves": ["plan1/wave1"] }
  ],
  "criticalPath": ["plan1"],
  "independentWaves": ["plan1/wave1"]
}
EOF
}

if [ "$DRY_RUN" = "true" ]; then
    write_dry_run_outputs
    write_phase_result "$PROJECT_DIR" 4 "StagesAgent" "dry_run" '["Plans/stages.md","Plans/stages.json"]' "false" >/dev/null
    log_success "Phase 4 dry run complete"
    exit 0
fi

if [ ! -d "$PLANS_DIR" ] || ! find "$PLANS_DIR" -type f \( -name 'plan*.md' -o -name 'subplan*.md' \) | grep -q .; then
    log_error "Phase 4 requires plan files in: $PLANS_DIR"
    exit 11
fi

if ! command -v jq >/dev/null 2>&1; then
    log_error "Phase 4 requires jq to validate Plans/stages.json"
    exit 11
fi

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/foundation_phase4_XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

build_prompt() {
    local attempt="$1"
    {
        cat <<EOF
You are the Foundation Phase 4 Stages Agent.

Read all plans and waves, build the dependency DAG, and emit:
1. Plans/stages.md in the Foundation Constitution Article II Section 3 format:
   # Execution Stages, Stage N (Parallel), Critical Path.
2. Plans/stages.json matching exactly:
{
  "schemaVersion": 1,
  "stages": [
    { "stage": 1, "parallel": true, "waves": ["plan1/wave1"] }
  ],
  "criticalPath": ["plan1", "plan2"],
  "independentWaves": ["plan3/wave1"]
}

Return stages.json between these sentinel markers:
---STAGES_JSON_START---
<valid JSON>
---STAGES_JSON_END---

If also emitting files, use:
---FILE: Plans/stages.md---
<markdown>

Attempt: $attempt
Plan inputs follow.
EOF
        find "$PLANS_DIR" -type f \( -name '*.md' \) | sort | while IFS= read -r file; do
            printf '\n===== %s =====\n' "$file"
            cat "$file"
        done
    } > "$TMP_DIR/prompt.md"
}

extract_json() {
    local source_file="$1"
    local target_file="$2"
    awk '/^---STAGES_JSON_START---$/ { capture=1; next } /^---STAGES_JSON_END---$/ { capture=0 } capture { print }' "$source_file" > "$target_file"
    if [ ! -s "$target_file" ]; then
        cp "$source_file" "$target_file"
    fi
}

attempt=1
valid_json="false"
while [ "$attempt" -le 2 ]; do
    build_prompt "$attempt"
    AI_OUTPUT="$TMP_DIR/ai_output_${attempt}.txt"
    set +e
    run_phase_ai "$AI_PROVIDER" "$MODEL" "$TMP_DIR/prompt.md" "Plans/stages.md and stages.json" > "$AI_OUTPUT"
    AI_STATUS=$?
    set -e
    if [ "$AI_STATUS" -ne 0 ]; then
        write_phase_result "$PROJECT_DIR" 4 "StagesAgent" "failed" '[]' "false" >/dev/null
        exit "$AI_STATUS"
    fi

    extract_json "$AI_OUTPUT" "$TMP_DIR/stages.json"
    if jq empty "$TMP_DIR/stages.json" >/dev/null 2>&1; then
        valid_json="true"
        break
    fi
    attempt=$((attempt + 1))
done

if [ "$valid_json" != "true" ]; then
    write_phase_result "$PROJECT_DIR" 4 "StagesAgent" "failed" '[]' "false" >/dev/null
    log_error "Phase 4 failed: invalid stages.json after 2 attempts"
    exit 10
fi

mkdir -p "$PROJECT_DIR/Plans"
cp "$TMP_DIR/stages.json" "$PROJECT_DIR/Plans/stages.json"
OUTPUTS_FILE="$TMP_DIR/outputs.txt"
if ! phase_extract_marked_files "$PROJECT_DIR" "$AI_OUTPUT" "$OUTPUTS_FILE" || [ ! -f "$PROJECT_DIR/Plans/stages.md" ]; then
    cat > "$PROJECT_DIR/Plans/stages.md" <<EOF
# Execution Stages

Generated by Phase 4 Stages Agent.

## Stage 1 (Parallel)
See Plans/stages.json.

## Critical Path
See Plans/stages.json.
EOF
    printf 'Plans/stages.md\n' > "$OUTPUTS_FILE"
fi
printf 'Plans/stages.json\n' >> "$OUTPUTS_FILE"

OUTPUTS_JSON="$(phase_outputs_json_from_file "$OUTPUTS_FILE")"
write_phase_result "$PROJECT_DIR" 4 "StagesAgent" "success" "$OUTPUTS_JSON" "false" >/dev/null
log_success "Phase 4 complete"
