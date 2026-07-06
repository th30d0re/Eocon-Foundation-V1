#!/usr/bin/env bash
# Purpose: Phase 2 Question Agent - plans to Questions.md and ambiguity logs.
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
QuestionAgent.sh - Phase 2 Question Agent

Usage:
  QuestionAgent.sh [--plans-dir <dir>] [contract flags]

Contract flags:
  --project-dir <dir>    Foundation project root
  --ai-provider <p>      claude (default), codex, gemini, cursor, kimi
  --model <m>            optional model override
  --yolo                 fully autonomous; no interactive prompts
  --dry-run              no AI/network calls; write scaffold outputs
  --verbose              debug logging
  --help                 print this help and exit 0
  --version              print semver and exit 0

Phase 2 input flags:
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
    mkdir -p "$PROJECT_DIR/Plans/plan1"
    cat > "$PROJECT_DIR/Plans/Questions.md" <<'EOF'
# Questions

## Plan 1

1. <!-- DRY-RUN PLACEHOLDER --> [Plans/plan1/plan1.md#task-description]
EOF
    append_decision_log "$PROJECT_DIR/Plans/plan1/decision_log.md" "DRY-RUN PLACEHOLDER ambiguity" "DRY-RUN PLACEHOLDER"
}

if [ "$DRY_RUN" = "true" ]; then
    write_dry_run_outputs
    write_phase_result "$PROJECT_DIR" 2 "QuestionAgent" "dry_run" '["Plans/Questions.md","Plans/plan1/decision_log.md"]' "false" >/dev/null
    log_success "Phase 2 dry run complete"
    exit 0
fi

if [ ! -d "$PLANS_DIR" ] || ! find "$PLANS_DIR" -type f \( -name 'plan*.md' -o -name 'subplan*.md' \) | grep -q .; then
    log_error "Phase 2 requires plan files in: $PLANS_DIR"
    exit 11
fi

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/foundation_phase2_XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT
{
    cat <<'EOF'
You are the Foundation Phase 2 Question Agent.

Scan all plans, tests, subplans, and waves for ambiguities. Emit Plans/Questions.md
with numbered questions grouped by plan. Every question must be tagged with the
file and section it came from.

Critical limitation: ask questions only. NEVER answer them.

Also identify ambiguity log entries that should be appended to each plan's
decision_log.md.

Emit Questions.md using:
---FILE: Plans/Questions.md---
<markdown>

Plan inputs follow.
EOF
    find "$PLANS_DIR" -type f \( -name '*.md' \) | sort | while IFS= read -r file; do
        printf '\n===== %s =====\n' "$file"
        cat "$file"
    done
} > "$TMP_DIR/prompt.md"

AI_OUTPUT="$TMP_DIR/ai_output.txt"
set +e
run_phase_ai "$AI_PROVIDER" "$MODEL" "$TMP_DIR/prompt.md" "Plans/Questions.md" > "$AI_OUTPUT"
AI_STATUS=$?
set -e
if [ "$AI_STATUS" -ne 0 ]; then
    write_phase_result "$PROJECT_DIR" 2 "QuestionAgent" "failed" '[]' "false" >/dev/null
    exit "$AI_STATUS"
fi

OUTPUTS_FILE="$TMP_DIR/outputs.txt"
if ! phase_extract_marked_files "$PROJECT_DIR" "$AI_OUTPUT" "$OUTPUTS_FILE"; then
    cp "$AI_OUTPUT" "$PROJECT_DIR/Plans/Questions.md"
    printf 'Plans/Questions.md\n' > "$OUTPUTS_FILE"
fi

find "$PLANS_DIR" -maxdepth 1 -type d -name 'plan*' | sort | while IFS= read -r plan_dir; do
    append_decision_log "$plan_dir/decision_log.md" "Ambiguities recorded by QuestionAgent" "Questions are listed in Plans/Questions.md for human or Phase 3 self-resolution."
    printf '%s\n' "${plan_dir#$PROJECT_DIR/}/decision_log.md" >> "$OUTPUTS_FILE"
done

OUTPUTS_JSON="$(phase_outputs_json_from_file "$OUTPUTS_FILE")"
write_phase_result "$PROJECT_DIR" 2 "QuestionAgent" "success" "$OUTPUTS_JSON" "false" >/dev/null
log_success "Phase 2 complete"
