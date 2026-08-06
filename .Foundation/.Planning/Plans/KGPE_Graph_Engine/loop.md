# KGPE Graph Engine — Implementation Loops

Source plan: [`plan.md`](plan.md) · Tech contract: [`tech-plan.md`](tech-plan.md) · State: [`STATE.md`](STATE.md)

Each loop is an implementer prompt followed by a verifier prompt. Phases A and B run in
parallel — they own disjoint trees and both build against `tech-plan.md`. Phase C starts only
when both A and B verifiers are green.

---

## Active Loops

| Phase | Worker | Pattern | Status | Trigger | Artifact produced |
|---|---|---|---|---|---|
| A — Graph engine (Rust) | Codex | Goal + implementer/verifier | Dispatched | Manual | `src/kgpe/` module + tests |
| B — Node manifests (bash) | Kimi | Implementer/verifier | Dispatched | Manual | `node.json` manifests, manifest-emitting Phase 1/4 |
| C — Integration | TBD | Implementer/verifier | Blocked on A+B | Both verifiers green | Graph-driven `pipeline_engine.rs`, `/graph` commands |

---

## Worker CLI Reference (verified 2026-08-05)

**Codex** — `codex-cli 0.144.5`

```bash
# implementer (one-shot, workspace-scoped write)
codex exec -s workspace-write -C <repo-root> --output-last-message <file> "<prompt>"

# loop iteration — re-enters the SAME session with context intact
codex exec resume --last "<fix prompt>"
codex exec resume <SESSION_ID> "<fix prompt>"

# structured verdict capture
codex exec --output-schema <schema.json> --json "<verifier prompt>"
```

The `define-goal` skill is installed at `~/.codex/skills/define-goal/`; Codex exposes
`get_goal` / `create_goal`. The implementer prompt below instructs it to open a goal whose
objective carries its own validator, so the loop has a machine-checkable stop condition.

**Kimi** — `kimi 0.31.0`

```bash
# implementer (one-shot, non-interactive)
kimi -p "<prompt>"

# loop iteration — resume the session by id, or continue the cwd's last session
kimi -S <session_id> -p "<fix prompt>"
kimi -c -p "<fix prompt>"

# streaming/structured output
kimi -p "<prompt>" --output-format stream-json
```

`-p` is mutually exclusive with `--yolo` and `--auto` — prompt mode is already the
non-interactive path. Kimi prints `To resume this session: kimi -r <session_id>` on exit;
capture that id for the retry leg.

**Circuit breaker (both workers):** max 3 fix attempts per phase. On the 4th failure, stop and
escalate to the operator with the failing check and the last verifier output. Do not
re-dispatch a fresh session to dodge the counter.

---

## Phase A — Graph Engine (Codex)

### Implementer prompt

```text
Use the define-goal skill. Create a goal whose objective is:

"Implement the KGPE graph engine as a new src/kgpe/ module in
.Foundation/Agents/phases/phase5/orchestrator/, conforming exactly to
.Foundation/.Planning/Plans/KGPE_Graph_Engine/tech-plan.md sections 3-6, verified by
`cargo build --release && cargo test && cargo clippy -- -D warnings` all passing with new
unit tests covering edge derivation, all five validation checks, all three mutation ops, and
graph_state.json round-trip."

Then implement it.

Read first, in this order:
1. .Foundation/.Planning/Plans/KGPE_Graph_Engine/tech-plan.md  (the contract — authoritative)
2. .Foundation/Agents/phases/PHASE_CONTRACT.md  (exit codes §3 and result.json §4 stay binding)
3. src/pipeline_engine.rs  (existing state machine — the seed you are generalizing)

Create src/kgpe/ with:
- types.rs    — Node, Edge, ArtifactRef, NodeKind{Agent,Work}, Gate{None,Human},
                ExecSpec{Script,Wave}, NodeState (8 states per tech-plan §5), and the CLOSED
                artifact-type vocabulary from tech-plan §3.1 as an enum. An unrecognized type
                is a hard parse error, never a fallback variant.
- manifest.rs — load node manifests from disk, serde with #[serde(rename_all="camelCase")],
                schema-validate, unique-id check.
- derive.rs   — edge derivation per tech-plan §3.3 exactly: A→B iff a produced ref matches a
                consumed ref; named refs match on (type,name), unnamed on type alone; a named
                ref NEVER matches an unnamed one. Multiple matching refs yield ONE edge
                carrying all matched refs.
- validate.rs — the five checks in tech-plan §4 in order, returning a GraphReport with stages,
                critical path, errors, warnings. Cycle errors must report the actual cycle
                path. Use Kahn's algorithm. Fan-in (two producers of one named ref) is a
                warning, not an error.
- engine.rs   — execution states, ready-set computation, exit-code mapping
                (0 Succeeded, 10 Failed, 11 Failed, 20 HumanIntervention), human gates, and
                the three mutation ops (retry/amend/append) from tech-plan §5. Every mutation
                re-runs validation; a mutation that would introduce a cycle is REJECTED and
                leaves the graph untouched.
- persist.rs  — graph_state.json (schemaVersion 1) write + reload + resume position.

Register the module in src/lib.rs.

Constraints:
- Work ONLY inside .Foundation/Agents/phases/phase5/orchestrator/. Everything else in the repo
  is read-only context. Another worker owns .Foundation/Agents/phases/ — do not edit it.
- Do NOT modify src/pipeline_engine.rs in this phase. Integration is Phase C.
- The kgpe module must be PURE: no PTY, no crossterm/ratatui types, no terminal I/O. It must be
  fully unit-testable headlessly.
- Do not add new crates. serde/serde_json are already present.
- No fallback behavior: missing or malformed input fails loudly with a named error. Never panic
  on a missing manifest — return a typed error naming the expected path.
- Match existing module style and conventions in the crate.
- No emojis in code, comments, or output.

Add tests in tests/kgpe_*.rs covering at minimum: derivation incl. the named-vs-unnamed
non-match rule; each of the five validation checks failing and passing; a cycle error naming
the cycle path; stage layering with a diamond dependency; retry exhaustion to
HumanIntervention; amend invalidating exactly the transitive dependents and nothing else;
append rejected when it would create a cycle; graph_state.json round-trip.

When done: report files created, the full `cargo test` output, and one paragraph of design
notes. Do NOT start Phase C.
```

### Verifier prompt

```text
Verify Phase A of the KGPE graph engine. Read
.Foundation/.Planning/Plans/KGPE_Graph_Engine/tech-plan.md first as the contract.

Checks:
1. src/kgpe/{types,manifest,derive,validate,engine,persist}.rs all exist and the module is
   registered in src/lib.rs.
2. cd .Foundation/Agents/phases/phase5/orchestrator && cargo build --release && cargo test &&
   cargo clippy -- -D warnings  — all pass, no new warning storm.
3. The artifact-type vocabulary is a closed enum matching tech-plan §3.1 exactly; grep confirms
   an unknown type produces an error, not a default/fallback variant.
4. Edge derivation matches tech-plan §3.3, INCLUDING that a named ref never matches an unnamed
   one, and that multiple matched refs collapse to a single edge. A test proves both.
5. All five validation checks from tech-plan §4 exist and are exercised by tests; the cycle
   error carries the actual cycle path, not a boolean.
6. All three mutation ops exist; a test proves amend invalidates exactly the transitive
   dependents (and a node outside that closure stays Succeeded); a test proves a
   cycle-introducing mutation is rejected with the graph unchanged.
7. The kgpe module imports no PTY/terminal/ratatui/crossterm types (grep the module).
8. src/pipeline_engine.rs is UNCHANGED (git diff shows no modification) and nothing outside
   phase5/orchestrator/ was touched (git status scope check).

Record results in .Foundation/.Planning/Plans/KGPE_Graph_Engine/STATE.md, filling the Phase A
checklist with pass/fail and notes. If any check fails, fix and re-verify. Max 3 fix attempts,
then stop and escalate to the operator with the failing check and the last output.
```

---

## Phase B — Node Manifests and Manifest-Emitting Agents (Kimi)

### Implementer prompt

```text
Implement Phase B of the KGPE graph engine: the bash side.

Read first, in this order:
1. .Foundation/.Planning/Plans/KGPE_Graph_Engine/tech-plan.md  (the contract — authoritative,
   especially §3.1 the closed artifact-type vocabulary and §3.2 the node manifest schema)
2. .Foundation/Agents/phases/PHASE_CONTRACT.md  (CLI flags §2, exit codes §3, result.json §4 —
   all stay binding and must not break)
3. .Foundation/Agents/phases/phase1/PlannerAgent.sh and phase4/StagesAgent.sh (what you change)

Deliverables:

1. A node.json manifest for every agent in the agent graph, at
   .Foundation/Agents/phases/phase<N>/node.json for N in 0..4, plus manifests for the phase5
   build and test agents at .Foundation/Agents/phases/phase5/node.json (one file may carry an
   array if multiple phase5 agents are declared). Each manifest follows tech-plan §3.2 exactly,
   with kind "agent". Declare produces/consumes using ONLY types from tech-plan §3.1. Derive
   each agent's real contract from PHASE_CONTRACT.md §2's input/output table and the
   Constitution Article II §3 — for example the Question Agent consumes plan.doc/wave.subplan
   and produces questions.doc + decision.log. Phase 0 carries gate "human" (Art. VIII §1).
   Do NOT declare edges — edges are derived by the engine, never authored.

2. phase1/PlannerAgent.sh — in addition to its existing markdown outputs, emit one work-node
   manifest per wave at Plans/plan<N>/waves/wave<M>/node.json, kind "work", following
   tech-plan §3.2. The prompt sent to the model must instruct it to declare produces/consumes
   using only the closed vocabulary, and must NOT ask it for a dependency list — dependencies
   are derived. Validate every emitted manifest with `jq` before writing; a manifest that fails
   schema validation is a hard failure (exit 10 after retries), not a silent skip.

3. phase4/StagesAgent.sh — stop asking the model to invent the DAG. Its new job: collect the
   work-node manifests produced by Phase 1, validate them against the vocabulary, and emit
   Plans/stages.json as a MANIFEST SET (the nodes), not an edge list. Keep writing
   Plans/stages.md as a human-readable summary. Remove the `jq empty`-only validation. If the
   engine binary is available it may be invoked to produce the derived report; if not, Phase 4
   still succeeds having emitted validated manifests.

4. Tests at .Foundation/Agents/phases/tests/bats/kgpe_manifests.bats using the EXISTING
   bats-core checkout at phase5/tests/bats/lib/bats-core/bin/bats (do not vendor a second
   copy). Cover: every agent node.json parses with jq and validates against the schema; every
   declared type is in the closed vocabulary; ids are unique across manifests; phase0 has gate
   "human"; phase1 --dry-run emits at least one valid work-node manifest; phase4 --dry-run
   emits a valid manifest set; a manifest with an out-of-vocabulary type is REJECTED.

Constraints:
- Work ONLY inside .Foundation/Agents/phases/. Another worker owns
  phase5/orchestrator/ (Rust) — do not edit anything under it except reading for context, and
  do not touch phase5/tests/bats/lib/.
- Do NOT break the existing PHASE_CONTRACT.md interface: every agent keeps its flags, its
  --dry-run path writing DRY-RUN PLACEHOLDER scaffolds and exiting 0, its exit codes, and its
  Artifacts/phase<N>_<ts>/result.json.
- macOS bash 3.2 compatible: no associative arrays, no ${var,,}.
- shellcheck -S warning -e SC1090,SC1091,SC2154,SC2034 must pass on everything you touch.
- No fallback behavior: a malformed manifest fails loudly and is never silently repaired.
- No emojis beyond the existing checkmark/cross glyph convention.

When done: report files created/changed, and the full output of
`bash .Foundation/Agents/phases/test-phase-agents.sh`. Do NOT start Phase C.
```

### Verifier prompt

```text
Verify Phase B of the KGPE graph engine. Read
.Foundation/.Planning/Plans/KGPE_Graph_Engine/tech-plan.md first as the contract.

Checks:
1. node.json exists for phases 0-4 and for the phase5 agents; each parses with jq and matches
   the tech-plan §3.2 schema (schemaVersion, id, kind, label, exec, consumes, produces, gate).
2. Every declared artifact type across ALL manifests is in the closed vocabulary of tech-plan
   §3.1 — enumerate them and diff against the list. Any extra type is a failure.
3. No manifest declares an edge, a dependency list, a "dependsOn", or an ordering field.
   grep to confirm.
4. Node ids are unique across all manifests.
5. phase0/node.json has gate "human" (Constitution Art. VIII §1).
6. Reachability sanity by hand: for every consumed type in the agent manifests, some other
   manifest produces it. Name any consumed type with no producer.
7. phase1/PlannerAgent.sh --dry-run --yolo --project-dir <mktemp> exits 0 and emits at least one
   valid work-node manifest; phase4/StagesAgent.sh --dry-run likewise emits a valid manifest
   set; both still write Artifacts/phase<N>_*/result.json with status "dry_run".
8. `jq empty`-as-sole-validation is gone from phase4/StagesAgent.sh.
9. bash .Foundation/Agents/phases/test-phase-agents.sh exits 0, including the new
   kgpe_manifests.bats suite; shellcheck clean on changed files.
10. Nothing under phase5/orchestrator/ was modified (git diff scope check).

Record results in .Foundation/.Planning/Plans/KGPE_Graph_Engine/STATE.md, filling the Phase B
checklist with pass/fail and notes. If any check fails, fix and re-verify. Max 3 fix attempts,
then stop and escalate to the operator with the failing check and the last output.
```

---

## Phase C — Integration (solo worker: Codex)

Single worker owns BOTH trees for this phase — the disjoint-ownership split used in A and B
does not apply. Codex takes it solo: it authored `kgpe` and holds the engine context, and the
bulk of C is Rust.

This is the first time the Phase B manifests meet the Phase A engine at runtime. Everything
green so far is unit tests plus hand-derivation; a contract mismatch, if one exists, surfaces
here.

### Implementer prompt

```text
Use the define-goal skill. Create a goal whose objective is:

"Wire the KGPE engine into the Foundation orchestrator so the pipeline executes from the
derived agent graph instead of a hardcoded 0-to-5 sequence, verified by `cargo build --release
&& cargo test && cargo clippy --all-targets -- -D warnings` passing, a new test that loads the
seven real .Foundation/Agents/phases/phase*/node.json manifests and asserts the derived graph
matches the 10 edges and 7-stage layering recorded in STATE.md check 11, and all pre-existing
orchestrator flows (/build, /test, /test-from, /test-stage, /provider, /model, /apply) still
passing their existing tests."

Then implement it.

Read first, in this order:
1. .Foundation/.Planning/Plans/KGPE_Graph_Engine/tech-plan.md  (contract; note §3.3 was amended
   after Phase A — it now documents the self-edge rule and the in-place-rewrite rule)
2. .Foundation/.Planning/Plans/KGPE_Graph_Engine/STATE.md  (check 11 holds the expected edge set
   and stage layering — your integration test asserts against exactly this)
3. src/kgpe/  (the engine you wrote in Phase A)
4. src/pipeline_engine.rs  (the linear state machine you are replacing)
5. .Foundation/Agents/phases/PHASE_CONTRACT.md  (§6 is what you amend; §2/§3/§4 stay binding)

Deliverables:

1. Manifest discovery + load: locate the agent-graph manifests at
   .Foundation/Agents/phases/phase*/node.json (phase5/node.json carries an ARRAY of two nodes),
   load them through kgpe::load_manifests, derive edges, and validate. A validation failure is a
   loud, actionable startup error naming the offending node/type — never a panic, never a
   silent fall back to the old linear order.

2. Graph-driven execution in pipeline_engine.rs: replace the fixed PipelinePhase march with
   ready-set scheduling over the derived graph. Preserve exactly, from PHASE_CONTRACT.md:
   exit-code mapping (0/10/11/20), result.json parsing, requiresApproval -> AwaitingApproval,
   and the /approve gate. Node exec comes from the manifest's exec.path, not a hardcoded name.
   Phase 5 keeps its existing BuildAgent-then-TestAgent spawn path, now driven by the
   phase5.build and phase5.test nodes.

3. Persistence: keep pipeline_state.json working for existing users, and persist graph state via
   kgpe::persist. If an old pipeline_state.json is found, either migrate it or start clean with
   a clear message — do not crash on it.

4. Slash commands in chat.rs (extend the help text and SLASH_COMMANDS picker too):
   - /graph            — render the derived graph with per-node status
   - /graph validate   — run validation and print the GraphReport (errors, warnings, stages,
                         critical path)
   - /graph render     — emit the graph as Mermaid or DOT text
   Keep /pipeline and /phase <n> working as aliases over the new engine.

5. ui/pipeline.rs: render the derived graph (nodes by stage, status glyphs, active node
   highlighted, AwaitingApproval visually obvious) instead of a fixed six-phase list.

6. Amend .Foundation/Agents/phases/PHASE_CONTRACT.md §6: replace "runs phases strictly in order
   0→5" with dependency-derived ordering (a node runs when all predecessors are Succeeded or
   Skipped), and reference tech-plan.md §3.3 for the derivation rule. Leave §2, §3, and §4
   untouched — they are still binding.

Constraints:
- You own both trees this phase, but touch ONLY what the deliverables require. Do not
  refactor unrelated modules, and do not modify src/startup.rs — it carries unrelated
  uncommitted user work (ASCII wordmark constants) that must be preserved byte-for-byte.
- Do not change the Phase B manifests to make integration easier. If a manifest is genuinely
  wrong, STOP and escalate — do not silently edit the other worker's verified output.
- Do not weaken crate lint policy. Per-module #[allow] on pre-existing debt is already in
  lib.rs; do not add crate-wide allows, and fix any lint your own new code triggers.
- Do not add new crates.
- No fallback behavior; fail loudly with named errors. No emojis.

Add tests: an integration test loading the SEVEN REAL manifests from disk and asserting the
derived edge set and stage layering match STATE.md check 11 exactly; a test that a validation
failure produces a named error rather than a panic; and coverage that the existing pipeline
flows still behave.

When done: report files changed, the full `cargo test` output, whether the real manifests
validated on first attempt, and any contract mismatch you found between the Phase A engine and
the Phase B manifests.
```

### Verifier prompt

```text
Verify Phase C. You are verifying integration between two independently built halves —
assume nothing works until observed.

Checks:
1. cargo build --release && cargo test && cargo clippy --all-targets -- -D warnings all pass.
2. The integration test loads the seven REAL .Foundation/Agents/phases/phase*/node.json files
   from disk (not fixtures, not inlined copies — confirm by reading the test) and asserts the
   derived graph. Its expected edge set and stage layering match STATE.md check 11 exactly:
   10 edges, topological order phase0 → phase1 → phase2 → phase3 → phase4 → phase5.build →
   phase5.test, 7 stages.
3. pipeline_engine.rs no longer contains a hardcoded phase sequence; node execution paths come
   from manifest exec.path. grep to confirm no residual fixed 0..=5 ordering drives execution.
4. PHASE_CONTRACT.md §3 exit codes and §4 result.json handling are preserved and still
   exercised; §6 now describes dependency-derived ordering.
5. /graph, /graph validate, /graph render exist, appear in help and the command picker, and are
   covered by tests. /pipeline and /phase still work.
6. A deliberately invalid manifest set produces a named, actionable error and NOT a panic and
   NOT a silent fallback to linear order. Prove it with a test.
7. src/startup.rs is byte-for-byte unchanged (git diff src/startup.rs shows only the
   pre-existing wordmark work that was there before this phase).
8. The Phase B manifests under .Foundation/Agents/phases/phase*/node.json are UNCHANGED
   (git diff clean for those paths). If the implementer edited them, that is a FAIL — report it.
9. No crate-wide #![allow] was added to lib.rs; per-module allows are unchanged from Phase A.
10. Pre-existing orchestrator tests all still pass; count them and compare against the 46 green
    at the end of Phase A.

Record results in .Foundation/.Planning/Plans/KGPE_Graph_Engine/STATE.md under Phase C. Max 3
fix attempts, then stop and escalate.
```
