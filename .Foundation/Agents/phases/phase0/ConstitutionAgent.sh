#!/usr/bin/env bash
# Purpose: Phase 0 Constitution Agent - natural language to C0/CN constitutions.
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
INPUT_FILE=""
PROMPT_TEXT=""

usage() {
    cat <<'USAGE'
ConstitutionAgent.sh - Phase 0 Constitution Agent

Usage:
  ConstitutionAgent.sh --input <file> | --prompt "<text>" [contract flags]

Contract flags:
  --project-dir <dir>    Foundation project root
  --ai-provider <p>      claude (default), codex, gemini, cursor, kimi
  --model <m>            optional model override
  --yolo                 fully autonomous; no interactive prompts
  --dry-run              no AI/network calls; write scaffold outputs
  --verbose              debug logging
  --help                 print this help and exit 0
  --version              print semver and exit 0

Phase 0 input flags:
  --input <file>         natural-language input file
  --prompt "<text>"      natural-language input text
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
        --input) INPUT_FILE="${2:-}"; shift 2 ;;
        --prompt) PROMPT_TEXT="${2:-}"; shift 2 ;;
        --help|-h) usage; exit 0 ;;
        --version) printf '%s\n' "$VERSION"; exit 0 ;;
        *) log_error "Unknown flag: $1"; usage >&2; exit 11 ;;
    esac
done

export AI_PROVIDER VERBOSE
PHASE_STARTED_AT="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
export PHASE_STARTED_AT

if [ -z "$INPUT_FILE" ] && [ -z "$PROMPT_TEXT" ]; then
    log_error "Phase 0 requires --input <file> or --prompt \"<text>\""
    exit 11
fi

if [ -n "$INPUT_FILE" ] && [ ! -f "$INPUT_FILE" ]; then
    log_error "Input file not found: $INPUT_FILE"
    exit 11
fi

if [ -z "$PROJECT_DIR" ]; then
    if ! PROJECT_DIR="$(detect_foundation_project "$PWD")"; then
        PROJECT_DIR="$PWD"
    fi
fi
mkdir -p "$PROJECT_DIR" || { log_error "Cannot create project dir: $PROJECT_DIR"; exit 11; }
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"
ensure_five_folders "$PROJECT_DIR"

write_dry_run_outputs() {
    mkdir -p "$PROJECT_DIR/Constitution"
    cat > "$PROJECT_DIR/Constitution/C0.tex" <<'EOF'
\section{Abstract}
% DRY-RUN PLACEHOLDER
\section{Purpose}
% DRY-RUN PLACEHOLDER
\section{Requirements}
% DRY-RUN PLACEHOLDER
\section{Architecture}
% DRY-RUN PLACEHOLDER
\section{User Flows}
% DRY-RUN PLACEHOLDER
\section{Business Logic}
% DRY-RUN PLACEHOLDER
\section{Integration}
% DRY-RUN PLACEHOLDER
\section{Testing Criteria}
% DRY-RUN PLACEHOLDER
\section{Deployment}
% DRY-RUN PLACEHOLDER
\section{Maintenance}
% DRY-RUN PLACEHOLDER
EOF
    cp "$PROJECT_DIR/Constitution/C0.tex" "$PROJECT_DIR/Constitution/C1.tex"
}

if [ "$DRY_RUN" = "true" ]; then
    write_dry_run_outputs
    write_phase_result "$PROJECT_DIR" 0 "ConstitutionAgent" "dry_run" '["Constitution/C0.tex","Constitution/C1.tex"]' "true" >/dev/null
    log_success "Phase 0 dry run complete"
    exit 0
fi

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/foundation_phase0_XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT
INPUT_CONTENT="$PROMPT_TEXT"
if [ -n "$INPUT_FILE" ]; then
    INPUT_CONTENT="$(cat "$INPUT_FILE")"
fi

cat > "$TMP_DIR/prompt.md" <<EOF
You are the Foundation Phase 0 Constitution Agent.

Transform the user's natural-language product input into Constitution files.
Follow the Foundation Constitution Article II Section 3-4 and Article XI Section 1.

Required outputs:
- Root constitution at Constitution/C0.tex covering concept, business model, constellation structure, and high-level requirements.
- One Constitution/CN.tex per identified micro-app, covering purpose, requirements, integration specs, and API contracts.

Every .tex file must contain these LaTeX sections in order:
Abstract, Purpose, Requirements, Architecture, User Flows, Business Logic,
Integration, Testing Criteria, Deployment, Maintenance.

Emit files using this exact marker format:
---FILE: Constitution/C0.tex---
<latex content>
---FILE: Constitution/C1.tex---
<latex content>

User input:
$INPUT_CONTENT
EOF

AI_OUTPUT="$TMP_DIR/ai_output.txt"
set +e
run_phase_ai "$AI_PROVIDER" "$MODEL" "$TMP_DIR/prompt.md" "Constitution/*.tex" > "$AI_OUTPUT"
AI_STATUS=$?
set -e
if [ "$AI_STATUS" -ne 0 ]; then
    write_phase_result "$PROJECT_DIR" 0 "ConstitutionAgent" "failed" '[]' "true" >/dev/null
    exit "$AI_STATUS"
fi

OUTPUTS_FILE="$TMP_DIR/outputs.txt"
if ! phase_extract_marked_files "$PROJECT_DIR" "$AI_OUTPUT" "$OUTPUTS_FILE"; then
    cp "$AI_OUTPUT" "$PROJECT_DIR/Constitution/C0.tex"
    cat > "$PROJECT_DIR/Constitution/C1.tex" <<'EOF'
\section{Abstract}
Generated micro-app constitution placeholder. The provider did not emit split file markers.
\section{Purpose}
See C0.tex for the generated constitutional content.
\section{Requirements}
See C0.tex.
\section{Architecture}
See C0.tex.
\section{User Flows}
See C0.tex.
\section{Business Logic}
See C0.tex.
\section{Integration}
See C0.tex.
\section{Testing Criteria}
See C0.tex.
\section{Deployment}
See C0.tex.
\section{Maintenance}
See C0.tex.
EOF
    printf 'Constitution/C0.tex\nConstitution/C1.tex\n' > "$OUTPUTS_FILE"
fi

OUTPUTS_JSON="$(phase_outputs_json_from_file "$OUTPUTS_FILE")"
write_phase_result "$PROJECT_DIR" 0 "ConstitutionAgent" "success" "$OUTPUTS_JSON" "true" >/dev/null
log_success "Phase 0 complete"
