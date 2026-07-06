# SPEC B — Multi-Phase Foundation Orchestrator (Rust TUI)

Work ONLY inside `.Foundation/Agents/phases/phase5/orchestrator/`. Everything
else in the repo is read-only context for you (other workers own it).

## Objective

Evolve the `orch` Rust TUI from a phase-5 build/test cockpit into the
Foundation Orchestrator that can run the full pipeline Phase 0 → Phase 5 with
human approval gates, per `.Foundation/Agents/phases/PHASE_CONTRACT.md`
(read it first; contract §4 result.json and §6 orchestrator obligations are
your requirements) and the Foundation Constitution Article II §3 + Article VIII
(human checkpoints).

## Current architecture (read these before designing)

- `src/app.rs` — main event loop / state (~1530 lines)
- `src/agents/{runner.rs,build_agent.rs,test_agent.rs,parser.rs}` — `AgentCmd`
  spawned in a PTY; this is HOW you must spawn phase agents too
- `src/chat.rs` — slash command handling
- `src/ui/pipeline.rs` — existing UI pane (phase-5 stages); extend or
  generalize it for the 6-phase pipeline view
- `src/lib.rs`, `src/startup.rs`, `src/detect.rs` — wiring/project detection

## Required behavior

1. **Pipeline state machine** (new module, e.g. `src/pipeline_engine.rs` or
   `src/pipeline/` — your call; do not collide with `src/ui/pipeline.rs`):
   - Phases 0..=5 with statuses: `Pending | Running | AwaitingApproval |
     Approved | Succeeded | Failed | HumanIntervention | Skipped`
   - Legal transitions only; phase N+1 cannot start until N is `Succeeded`
     (or `Approved` when `requiresApproval` was set) — contract §6
   - Phase agent locations (relative to the phases dir, which is the parent of
     the phase5 dir the orchestrator already knows):
     `phase0/ConstitutionAgent.sh`, `phase1/PlannerAgent.sh`,
     `phase2/QuestionAgent.sh`, `phase3/OptimizationAgent.sh`,
     `phase4/StagesAgent.sh`; phase 5 = existing BuildAgent/TestAgent flow
     (reuse the existing build+test spawn path as the phase-5 step:
     BuildAgent then TestAgent).
   - Missing agent script -> phase `Failed` with actionable message (the
     phase 0–4 scripts may not exist yet in this checkout; NEVER panic).
2. **Spawning**: each phase runs via the existing PTY `AgentCmd` runner with
   args `--project-dir <detected project> --yolo --ai-provider <current>`.
   Exit code mapping per contract §3 (0 success, 10 failed, 11 misconfig,
   20 -> `HumanIntervention`).
3. **Result parsing**: after a phase exits, find the newest
   `<project>/Artifacts/phase<N>_*/result.json`, parse per contract §4
   (serde structs with `#[serde(rename_all = "camelCase")]`), honor
   `requiresApproval` -> state `AwaitingApproval` until `/approve`.
4. **Persistence + resume**: write `<project>/Artifacts/pipeline_state.json`
   (schemaVersion 1, per-phase status + timestamps + approvals + last
   result.json path) after every transition; on startup, if it exists, offer
   resume (load it and continue from the first non-succeeded phase).
5. **New slash commands** (extend chat.rs help text too):
   - `/pipeline` — run full pipeline from first incomplete phase
   - `/pipeline status` — render per-phase status summary in chat
   - `/phase <n>` — run a single phase n (0–5), respecting gating unless
     `--force` suffix given (`/phase 3 --force`)
   - `/approve` / `/reject` — resolve an `AwaitingApproval` gate; reject marks
     the phase Failed and stops the pipeline
   - `/skip-phase <n>` — mark a phase Skipped (counts as satisfied for gating)
6. **UI**: pipeline pane shows the 6 phases with status glyphs and highlights
   the active one; AwaitingApproval state must be visually obvious and the
   status bar should hint `/approve`.
7. **Do not break** existing `/build`, `/test`, `/test-from`, `/test-stage`,
   `/provider`, `/model`, `/apply` flows or existing tests.

## Constraints

- Keep dependencies as-is (ratatui/crossterm/portable-pty/vte/clap/serde);
  `tempfile` is already a dev-dependency for tests. Do not add new crates.
- Match existing code style/module conventions.
- All new logic must be testable without a TTY: keep the state machine and
  result.json/pipeline_state.json parsing pure (no PTY/terminal types in the
  pipeline engine module).

## Acceptance criteria (all must pass before you report done)

```bash
cd .Foundation/Agents/phases/phase5/orchestrator
cargo build --release 2>&1 | tail -5   # no errors, no new warnings storm
cargo test                              # ALL tests green
```

`cargo test` must include NEW unit tests covering at least:
- legal/illegal transitions (cannot start phase 2 while phase 1 Pending/Failed)
- exit-code → status mapping incl. 20 → HumanIntervention
- `requiresApproval` → AwaitingApproval → `/approve` → Approved → next phase
  may start; `/reject` → Failed
- pipeline_state.json round-trip (serialize, reload, resume position correct)
- result.json parsing of a contract §4 fixture (use tempfile)
- missing agent script → Failed with message (no panic)

Report at the end: files changed/created, design notes (one paragraph), and
full `cargo test` output.
