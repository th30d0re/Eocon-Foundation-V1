#!/usr/bin/env bash
# Purpose: Phase 4 Stages Agent - collect and validate Phase 1 work-node manifests, emit stages.json manifest set.
# Exit Codes: 0 success/dry-run/help, 10 failed after retries, 11 misconfiguration, 20 human intervention.
#
# Phase 4 no longer asks a model to invent a DAG. Per the KGPE tech plan
# (§2 decision 1, §3.3), edges are derived by the graph engine from typed
# produces/consumes declarations and are never authored. Phase 4's job is to
# collect the work-node manifests emitted by Phase 1, validate them against
# the §3.2 schema and the §3.1 closed vocabulary, and emit Plans/stages.json
# as a manifest set (the nodes). The KGPE engine (phase5/orchestrator
# src/kgpe) derives stage layering and the critical path from that set during
# graph validation (tech-plan §4); until it is wired in (Phase C), Phase 4
# succeeds having emitted validated manifests.

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

VERSION="0.2.0"
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

Phase 4 collects the work-node manifests (Plans/planN/waves/waveM/node.json)
emitted by Phase 1, validates them against the KGPE schema and closed
artifact-type vocabulary, and emits Plans/stages.json as a manifest set.
Edges are derived by the KGPE engine, never authored here.
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

## Work Nodes
- plan1.wave1 (DRY-RUN PLACEHOLDER)

## Stage Layering and Critical Path
<!-- DRY-RUN PLACEHOLDER: derived by the KGPE engine from the manifest set -->
EOF
    cat > "$PROJECT_DIR/Plans/stages.json" <<'EOF'
{
  "schemaVersion": 1,
  "kind": "manifestSet",
  "nodes": [
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
  ]
}
EOF
}

if [ "$DRY_RUN" = "true" ]; then
    write_dry_run_outputs
    write_phase_result "$PROJECT_DIR" 4 "StagesAgent" "dry_run" '["Plans/stages.md","Plans/stages.json"]' "false" >/dev/null
    log_success "Phase 4 dry run complete"
    exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
    log_error "Phase 4 requires jq to validate and emit Plans/stages.json"
    exit 11
fi

if [ ! -d "$PLANS_DIR" ] || ! kgpe_collect_wave_manifests "$PLANS_DIR" | grep -q .; then
    log_error "Phase 4 requires work-node manifests under: $PLANS_DIR (Phase 1 emits them)"
    exit 11
fi

# Validate the manifest set: schema, closed vocabulary, per-wave coverage,
# unique ids. Anything invalid is a hard failure, never a silent repair.
if ! kgpe_validate_wave_manifests "$PLANS_DIR"; then
    write_phase_result "$PROJECT_DIR" 4 "StagesAgent" "failed" '[]' "false" >/dev/null
    log_error "Phase 4 failed: invalid work-node manifests under $PLANS_DIR"
    exit 10
fi

mkdir -p "$PROJECT_DIR/Plans"
STAGES_JSON="$PROJECT_DIR/Plans/stages.json"
kgpe_collect_wave_manifests "$PLANS_DIR" | tr '\n' '\0' \
    | xargs -0 jq -s '{schemaVersion: 1, kind: "manifestSet", nodes: [.[]]}' > "$STAGES_JSON"

if ! jq -e '.schemaVersion == 1 and (.nodes | type == "array") and (.nodes | length > 0)' "$STAGES_JSON" >/dev/null 2>&1; then
    write_phase_result "$PROJECT_DIR" 4 "StagesAgent" "failed" '[]' "false" >/dev/null
    log_error "Phase 4 failed: could not emit a valid manifest set"
    exit 10
fi

{
    printf '# Execution Stages\n\n'
    printf 'Work-node manifest set collected and validated by the Phase 4 Stages Agent.\n'
    printf 'Edges are derived by the KGPE engine from typed produces/consumes declarations; none are authored here.\n\n'
    printf '## Work Nodes\n\n'
    jq -r '.nodes[] | "- `\(.id)` - \(.label) (`\(.exec.planPath // .exec.path // "n/a")`)"' "$STAGES_JSON"
    printf '\n## Stage Layering and Critical Path\n\n'
    printf 'Computed by the KGPE engine from this manifest set during graph validation; Phase 4 emits validated nodes only.\n'
} > "$PROJECT_DIR/Plans/stages.md"

OUTPUTS_FILE="$(mktemp "${TMPDIR:-/tmp}/foundation_phase4_outputs_XXXXXX")"
trap 'rm -f "$OUTPUTS_FILE"' EXIT
printf 'Plans/stages.md\nPlans/stages.json\n' > "$OUTPUTS_FILE"

OUTPUTS_JSON="$(phase_outputs_json_from_file "$OUTPUTS_FILE")"
write_phase_result "$PROJECT_DIR" 4 "StagesAgent" "success" "$OUTPUTS_JSON" "false" >/dev/null
log_success "Phase 4 complete"
