#!/usr/bin/env bash
# Purpose: Phase 1 Planner Agent - constitutions to plan folders and waves.
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
CONSTITUTION_DIR=""

usage() {
    cat <<'USAGE'
PlannerAgent.sh - Phase 1 Planner Agent

Usage:
  PlannerAgent.sh [--constitution-dir <dir>] [contract flags]

Contract flags:
  --project-dir <dir>       Foundation project root
  --ai-provider <p>         claude (default), codex, gemini, cursor, kimi
  --model <m>               optional model override
  --yolo                    fully autonomous; no interactive prompts
  --dry-run                 no AI/network calls; write scaffold outputs
  --verbose                 debug logging
  --help                    print this help and exit 0
  --version                 print semver and exit 0

Phase 1 input flags:
  --constitution-dir <dir>  Constitution directory (default: <project>/Constitution)
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
        --constitution-dir) CONSTITUTION_DIR="${2:-}"; shift 2 ;;
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

if [ -z "$CONSTITUTION_DIR" ]; then
    CONSTITUTION_DIR="$PROJECT_DIR/Constitution"
fi

write_dry_run_outputs() {
    mkdir -p "$PROJECT_DIR/Plans/plan1/waves/wave1"
    cat > "$PROJECT_DIR/Plans/plan1/plan1.md" <<'EOF'
# Plan 1

<!-- DRY-RUN PLACEHOLDER -->

## Task Description and Objectives
<!-- DRY-RUN PLACEHOLDER -->
## Dependencies
<!-- DRY-RUN PLACEHOLDER -->
## Technical Approach
<!-- DRY-RUN PLACEHOLDER -->
## Acceptance Criteria
<!-- DRY-RUN PLACEHOLDER -->
## Test Requirements
<!-- DRY-RUN PLACEHOLDER -->
## Estimated Complexity
<!-- DRY-RUN PLACEHOLDER -->
## Target Stack Specifications
<!-- DRY-RUN PLACEHOLDER -->
EOF
    cat > "$PROJECT_DIR/Plans/plan1/test1.md" <<'EOF'
# Test 1

<!-- DRY-RUN PLACEHOLDER -->
EOF
    cat > "$PROJECT_DIR/Plans/plan1/decision_log.md" <<'EOF'
# Decision Log

<!-- DRY-RUN PLACEHOLDER -->
EOF
    cat > "$PROJECT_DIR/Plans/plan1/waves/wave1/subplan1.md" <<'EOF'
# Wave 1 Subplan

<!-- DRY-RUN PLACEHOLDER -->
EOF
    cat > "$PROJECT_DIR/Plans/plan1/waves/wave1/subtest1.md" <<'EOF'
# Wave 1 Subtest

<!-- DRY-RUN PLACEHOLDER -->
EOF
    cat > "$PROJECT_DIR/Plans/plan1/waves/wave1/node.json" <<'EOF'
{
  "schemaVersion": 1,
  "id": "plan1.wave1",
  "kind": "work",
  "label": "DRY-RUN PLACEHOLDER wave",
  "exec": { "type": "wave", "planPath": "Plans/plan1/waves/wave1" },
  "consumes": [],
  "produces": [ { "type": "code.module", "name": "dry-run-placeholder" } ],
  "gate": "none",
  "retry": { "maxAttempts": 3 }
}
EOF
}

if [ "$DRY_RUN" = "true" ]; then
    write_dry_run_outputs
    write_phase_result "$PROJECT_DIR" 1 "PlannerAgent" "dry_run" '["Plans/plan1/plan1.md","Plans/plan1/test1.md","Plans/plan1/decision_log.md","Plans/plan1/waves/wave1/subplan1.md","Plans/plan1/waves/wave1/subtest1.md","Plans/plan1/waves/wave1/node.json"]' "false" >/dev/null
    log_success "Phase 1 dry run complete"
    exit 0
fi

if [ ! -d "$CONSTITUTION_DIR" ] || ! find "$CONSTITUTION_DIR" -maxdepth 1 -name 'C*.tex' -type f | grep -q .; then
    log_error "Phase 1 requires Constitution files in: $CONSTITUTION_DIR"
    exit 11
fi

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/foundation_phase1_XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

build_prompt() {
    local attempt="$1"
    {
        cat <<EOF
You are the Foundation Phase 1 Planner Agent.

Parse each Constitution into Plans/planN folders with planN.md, testN.md,
decision_log.md, and waves/waveM/subplanM.md + subtestM.md.

Use Foundation Constitution Article II Section 3-4 and Article XI Section 2.
Every plan must include: task description and objectives, dependencies,
technical approach, acceptance criteria, test requirements, estimated complexity,
and target stack specifications. Waves must be token-efficient and sized for
one-shot model execution.

For EVERY wave you emit, also emit exactly one KGPE work-node manifest at
Plans/planN/waves/waveM/node.json using this schema:

{
  "schemaVersion": 1,
  "id": "planN.waveM",
  "kind": "work",
  "label": "<short wave label>",
  "exec": { "type": "wave", "planPath": "Plans/planN/waves/waveM" },
  "consumes": [ { "type": "code.module", "name": "<upstream-module>" } ],
  "produces": [
    { "type": "code.module", "name": "<module>" },
    { "type": "test.result", "name": "<module>" }
  ],
  "gate": "none",
  "retry": { "maxAttempts": 3 }
}

Manifest rules (hard requirements):
- Every "type" value must come ONLY from this closed vocabulary:
  constitution.root, constitution.sub, plan.doc, plan.test, wave.subplan,
  wave.subtest, wave.unittest, questions.doc, decision.log, stages.graph,
  code.module, test.result, guide.doc.
- An artifact ref is {"type": "..."} or {"type": "...", "name": "..."}.
- Do NOT declare dependencies, edges, ordering, or a dependsOn field.
  Dependencies are derived by the graph engine from produces/consumes.

Emit files using this exact marker format:
---FILE: Plans/plan1/plan1.md---
<markdown>
---FILE: Plans/plan1/test1.md---
<markdown>
---FILE: Plans/plan1/waves/wave1/node.json---
<json>

Attempt: $attempt
Constitution inputs follow.
EOF
        find "$CONSTITUTION_DIR" -maxdepth 1 -name 'C*.tex' -type f | sort | while IFS= read -r file; do
            printf '\n===== %s =====\n' "$file"
            cat "$file"
        done
    } > "$TMP_DIR/prompt.md"
}

# Extract into a staging directory first: every emitted wave work-node manifest
# must pass KGPE schema + closed-vocabulary validation BEFORE anything is
# written into the project. Invalid or missing manifests retry the model;
# after MAX_ATTEMPTS the run is a hard failure (exit 10), never a silent skip.
MAX_ATTEMPTS=3
attempt=1
manifests_ok="false"
while [ "$attempt" -le "$MAX_ATTEMPTS" ]; do
    build_prompt "$attempt"
    AI_OUTPUT="$TMP_DIR/ai_output_${attempt}.txt"
    set +e
    run_phase_ai "$AI_PROVIDER" "$MODEL" "$TMP_DIR/prompt.md" "Plans/planN" > "$AI_OUTPUT"
    AI_STATUS=$?
    set -e
    if [ "$AI_STATUS" -ne 0 ]; then
        write_phase_result "$PROJECT_DIR" 1 "PlannerAgent" "failed" '[]' "false" >/dev/null
        exit "$AI_STATUS"
    fi

    EXTRACT_DIR="$TMP_DIR/extract_${attempt}"
    mkdir -p "$EXTRACT_DIR"
    OUTPUTS_FILE="$TMP_DIR/outputs_${attempt}.txt"
    if phase_extract_marked_files "$EXTRACT_DIR" "$AI_OUTPUT" "$OUTPUTS_FILE" \
        && kgpe_validate_wave_manifests "$EXTRACT_DIR/Plans"; then
        manifests_ok="true"
        break
    fi
    log_warning "Phase 1 attempt $attempt: missing or invalid wave work-node manifests; retrying"
    attempt=$((attempt + 1))
done

if [ "$manifests_ok" != "true" ]; then
    write_phase_result "$PROJECT_DIR" 1 "PlannerAgent" "failed" '[]' "false" >/dev/null
    log_error "Phase 1 failed: no valid work-node manifests after $MAX_ATTEMPTS attempts"
    exit 10
fi

# Staged output validated; copy it into the project.
(
    cd "$EXTRACT_DIR"
    find . -type f -print
) | while IFS= read -r rel_path; do
    mkdir -p "$PROJECT_DIR/$(dirname "$rel_path")"
    cp "$EXTRACT_DIR/$rel_path" "$PROJECT_DIR/$rel_path"
done

OUTPUTS_JSON="$(phase_outputs_json_from_file "$OUTPUTS_FILE")"
write_phase_result "$PROJECT_DIR" 1 "PlannerAgent" "success" "$OUTPUTS_JSON" "false" >/dev/null
log_success "Phase 1 complete"
