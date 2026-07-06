# Foundation Phase Agent Contract (v1)

Authoritative interface contract between the Foundation Orchestrator and every
phase agent. Derived from the Foundation Constitution
(`.Foundation/Foundation-constitution/Foundation-Constitution.tex`), Article II
§3 (Unified Execution Pipeline) and §4 (Agent Specialization).

Any agent that violates this contract is non-conforming; the orchestrator only
speaks this protocol.

## 1. Layout

```
.Foundation/Agents/phases/
├── PHASE_CONTRACT.md            # this file
├── phase0/ConstitutionAgent.sh  # NL → C0 + sub-constitutions
├── phase1/PlannerAgent.sh       # Constitutions → Plans/ with waves
├── phase2/QuestionAgent.sh      # Plans → Questions.md + decision logs
├── phase3/OptimizationAgent.sh  # Questions + history → optimized plans/tests
├── phase4/StagesAgent.sh        # Plans → stages.md + stages.json (DAG)
├── phase5/                      # Execution: BuildAgent, testAgent, sub-agents (existing)
└── shared/agentCore.sh          # shared logging / provider / artifact helpers
```

## 2. CLI Contract (every phase agent)

Required flags — same semantics everywhere:

| Flag | Meaning |
|------|---------|
| `--project-dir <dir>` | Foundation project root (contains/should contain the five folders: Constitution/, Plans/, Guides/, Docs/, Design/). Default: auto-detect upward from CWD; error 11 if not found and not creatable. |
| `--ai-provider <p>` | `claude` (default), `codex`, `gemini`, `cursor`, `kimi` |
| `--model <m>` | optional model override passed to the provider CLI |
| `--yolo` | fully autonomous; no interactive prompts |
| `--dry-run` | NO AI calls, NO network. Write scaffold/template outputs with `<!-- DRY-RUN PLACEHOLDER -->` markers. Must exit 0. This is the testability hook. |
| `--verbose` | debug logging |
| `--help` / `--version` | exit 0, print usage / semver |

Phase-specific required inputs:

| Phase | Required input flags | Primary outputs |
|-------|---------------------|-----------------|
| 0 Constitution | `--input <file>` (NL text) or `--prompt "<text>"` | `Constitution/C0.tex`, `Constitution/C1..CN.tex` |
| 1 Planner | `--constitution-dir <dir>` (default `<project>/Constitution`) | `Plans/planN/{planN.md,testN.md,decision_log.md,waves/waveM/{subplanM.md,subtestM.md}}` |
| 2 Question | `--plans-dir <dir>` (default `<project>/Plans`) | `Plans/Questions.md`; appends ambiguities to each `planN/decision_log.md` |
| 3 Optimization | `--plans-dir`, `--questions <file>` (default `Plans/Questions.md`) | optimized `planN.md`/`testN.md`/subplans in place; `waves/waveM/unit_tests.md`; decision rationale appended to `decision_log.md` |
| 4 Stages | `--plans-dir` | `Plans/stages.md` (human) + `Plans/stages.json` (machine) |

`Plans/stages.json` schema:

```json
{
  "schemaVersion": 1,
  "stages": [
    { "stage": 1, "parallel": true, "waves": ["plan1/wave1", "plan2/wave1"] }
  ],
  "criticalPath": ["plan1", "plan2"],
  "independentWaves": ["plan3/wave1"]
}
```

## 3. Exit Codes (identical to phase5 BuildAgent)

| Code | Meaning |
|------|---------|
| 0 | Success (including `--dry-run`, `--help`) |
| 10 | Failed after max retries |
| 11 | Misconfiguration (bad flags, missing input, no provider CLI) |
| 20 | Human intervention required — agent has written details to `result.json.humanIntervention` and a `human_intervention_*.md` under `.Foundation/errors/` |

## 4. Result Artifact (machine contract for the orchestrator)

Every run (success or failure, including dry-run) writes:

```
<project>/Artifacts/phase<N>_<YYYYMMDD_HHMMSS>/result.json
```

```json
{
  "schemaVersion": 1,
  "phase": 1,
  "agent": "PlannerAgent",
  "status": "success | failed | human_intervention | dry_run",
  "startedAt": "ISO-8601",
  "finishedAt": "ISO-8601",
  "provider": "claude",
  "outputs": ["Plans/plan1/plan1.md", "..."],
  "requiresApproval": false,
  "humanIntervention": null,
  "errors": []
}
```

`requiresApproval: true` is set by Phase 0 always (Constitution approval is a
mandatory human checkpoint per Art. VIII §1). The agent still exits 0; the
ORCHESTRATOR enforces the gate — agents never block waiting for a human.

## 5. Conventions

- Bash, sourcing `.Foundation/lib/helpers.sh`, `check_shell_compatibility || exit 11`,
  path detection via `${BASH_SOURCE[0]}` — copy the header pattern from
  `phase5/lib/testUtils.sh`.
- `set -euo pipefail` in entrypoints only; sourced libs use include guards and
  define functions only (no top-level side effects).
- AI invocation goes through `shared/agentCore.sh::run_phase_ai` — a thin
  wrapper (headless one-shot per provider CLI) — NOT through phase5's
  `lib/build/ai_cli.sh` (that one is build-loop specific; do not couple to it).
- All autonomous decisions appended to the relevant `decision_log.md` with
  timestamp + rationale (Constitution Art. II §1 "Decision Logging").
- shellcheck `-S warning -e SC1090,SC1091,SC2154,SC2034` must pass.
- No emojis in code or logs beyond the existing ✓/✗ glyph convention.

## 6. Orchestrator Obligations

- Runs phases strictly in order 0→5 unless the user pins a phase; phase N+1 may
  start only when phase N's `result.json` has `status: success` AND any
  `requiresApproval` gate has been approved by the human (`/approve`).
- Persists pipeline state to `<project>/Artifacts/pipeline_state.json`
  (`schemaVersion`, current phase, per-phase status, approvals, timestamps) and
  can resume from it after restart.
- Surfaces exit 20 (`human_intervention`) immediately with the contents of the
  agent's intervention report.
