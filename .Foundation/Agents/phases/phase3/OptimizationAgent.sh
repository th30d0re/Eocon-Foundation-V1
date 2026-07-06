#!/usr/bin/env bash
# Purpose: Phase 3 Optimization Agent - self-resolve questions and optimize plans.
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
QUESTIONS_FILE=""

usage() {
    cat <<'USAGE'
OptimizationAgent.sh - Phase 3 Optimization Agent

Usage:
  OptimizationAgent.sh [--plans-dir <dir>] [--questions <file>] [contract flags]

Contract flags:
  --project-dir <dir>    Foundation project root
  --ai-provider <p>      claude (default), codex, gemini, cursor, kimi
  --model <m>            optional model override
  --yolo                 fully autonomous; no interactive prompts
  --dry-run              no AI/network calls; write scaffold outputs
  --verbose              debug logging
  --help                 print this help and exit 0
  --version              print semver and exit 0

Phase 3 input flags:
  --plans-dir <dir>      Plans directory (default: <project>/Plans)
  --questions <file>     Questions file (default: <project>/Plans/Questions.md)
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
        --questions) QUESTIONS_FILE="${2:-}"; shift 2 ;;
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
if [ -z "$QUESTIONS_FILE" ]; then
    QUESTIONS_FILE="$PROJECT_DIR/Plans/Questions.md"
fi

write_dry_run_outputs() {
    mkdir -p "$PROJECT_DIR/Plans/plan1/waves/wave1"
    cat > "$PROJECT_DIR/Plans/plan1/plan1.md" <<'EOF'
# Optimized Plan 1

<!-- DRY-RUN PLACEHOLDER -->
EOF
    cat > "$PROJECT_DIR/Plans/plan1/test1.md" <<'EOF'
# Enhanced Test 1

<!-- DRY-RUN PLACEHOLDER -->
EOF
    cat > "$PROJECT_DIR/Plans/plan1/waves/wave1/subplan1.md" <<'EOF'
# Optimized Wave 1 Subplan

<!-- DRY-RUN PLACEHOLDER -->
EOF
    cat > "$PROJECT_DIR/Plans/plan1/waves/wave1/subtest1.md" <<'EOF'
# Optimized Wave 1 Subtest

<!-- DRY-RUN PLACEHOLDER -->
EOF
    cat > "$PROJECT_DIR/Plans/plan1/waves/wave1/unit_tests.md" <<'EOF'
# Wave 1 Unit Tests

<!-- DRY-RUN PLACEHOLDER -->
EOF
    append_decision_log "$PROJECT_DIR/Plans/plan1/decision_log.md" "DRY-RUN PLACEHOLDER optimization" "DRY-RUN PLACEHOLDER"
}

if [ "$DRY_RUN" = "true" ]; then
    write_dry_run_outputs
    write_phase_result "$PROJECT_DIR" 3 "OptimizationAgent" "dry_run" '["Plans/plan1/plan1.md","Plans/plan1/test1.md","Plans/plan1/waves/wave1/subplan1.md","Plans/plan1/waves/wave1/subtest1.md","Plans/plan1/waves/wave1/unit_tests.md","Plans/plan1/decision_log.md"]' "false" >/dev/null
    log_success "Phase 3 dry run complete"
    exit 0
fi

if [ ! -f "$QUESTIONS_FILE" ]; then
    log_error "Phase 3 requires questions file: $QUESTIONS_FILE"
    exit 11
fi
if [ ! -d "$PLANS_DIR" ] || ! find "$PLANS_DIR" -type f \( -name 'plan*.md' -o -name 'subplan*.md' \) | grep -q .; then
    log_error "Phase 3 requires plan files in: $PLANS_DIR"
    exit 11
fi

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/foundation_phase3_XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT
{
    cat <<'EOF'
You are the Foundation Phase 3 Optimization Agent acting as a senior engineer.

Read Questions.md, plans, Guides/, Design/, and Docs/. Apply the self-resolution
algorithm from Foundation Constitution Article II Section 4 Agent 3:
1. If historical pattern found, apply it.
2. If not required, skip to prevent scope creep.
3. If required, apply industry-standard best practice.

Rewrite plans, tests, subplans, and subtests in place. Generate
waves/waveM/unit_tests.md. Append every decision and rationale to each
decision_log.md.

Emit changed files using:
---FILE: Plans/plan1/plan1.md---
<markdown>

Project context follows.
EOF
    printf '\n===== QUESTIONS %s =====\n' "$QUESTIONS_FILE"
    cat "$QUESTIONS_FILE"
    find "$PLANS_DIR" "$PROJECT_DIR/Guides" "$PROJECT_DIR/Design" "$PROJECT_DIR/Docs" -type f 2>/dev/null | sort | while IFS= read -r file; do
        printf '\n===== %s =====\n' "$file"
        cat "$file"
    done
} > "$TMP_DIR/prompt.md"

AI_OUTPUT="$TMP_DIR/ai_output.txt"
set +e
run_phase_ai "$AI_PROVIDER" "$MODEL" "$TMP_DIR/prompt.md" "optimized Plans/" > "$AI_OUTPUT"
AI_STATUS=$?
set -e
if [ "$AI_STATUS" -ne 0 ]; then
    write_phase_result "$PROJECT_DIR" 3 "OptimizationAgent" "failed" '[]' "false" >/dev/null
    exit "$AI_STATUS"
fi

OUTPUTS_FILE="$TMP_DIR/outputs.txt"
if ! phase_extract_marked_files "$PROJECT_DIR" "$AI_OUTPUT" "$OUTPUTS_FILE"; then
    find "$PLANS_DIR" -maxdepth 2 -type f \( -name 'plan*.md' -o -name 'test*.md' \) | sort | while IFS= read -r file; do
        {
            printf '\n## Phase 3 Optimization Notes\n\n'
            cat "$AI_OUTPUT"
            printf '\n'
        } >> "$file"
        printf '%s\n' "${file#$PROJECT_DIR/}" >> "$OUTPUTS_FILE"
    done
fi

find "$PLANS_DIR" -type d -name 'wave*' | sort | while IFS= read -r wave_dir; do
    unit_file="$wave_dir/unit_tests.md"
    if [ ! -f "$unit_file" ]; then
        cat > "$unit_file" <<'EOF'
# Unit Tests

Generated by Phase 3 Optimization Agent. Validate this wave's implementation against its subplan and subtest.
EOF
    fi
    printf '%s\n' "${unit_file#$PROJECT_DIR/}" >> "$OUTPUTS_FILE"
done

find "$PLANS_DIR" -maxdepth 1 -type d -name 'plan*' | sort | while IFS= read -r plan_dir; do
    append_decision_log "$plan_dir/decision_log.md" "Phase 3 self-resolution applied" "Resolved questions using historical patterns, scope checks, or industry best practices per Article II Section 4."
    printf '%s\n' "${plan_dir#$PROJECT_DIR/}/decision_log.md" >> "$OUTPUTS_FILE"
done

OUTPUTS_JSON="$(phase_outputs_json_from_file "$OUTPUTS_FILE")"
write_phase_result "$PROJECT_DIR" 3 "OptimizationAgent" "success" "$OUTPUTS_JSON" "false" >/dev/null
log_success "Phase 3 complete"
