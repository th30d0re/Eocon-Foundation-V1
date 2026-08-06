# KGPE Graph Engine — Tech Plan

Authoritative contract for the unified Knowledge-Graph Prompt Engine. Both workers build
against this file. Derived from the Foundation Constitution: Article II §3-§4 (Unified
Execution Pipeline, Agent Specialization), Article V (The Planner System), Article VII
(Entanglement Layer / Data Contracts), Article VIII (Human-in-the-Loop).

Supersedes the sequencing rule in `.Foundation/Agents/phases/PHASE_CONTRACT.md` §6
("runs phases strictly in order 0→5"). Everything else in PHASE_CONTRACT.md — CLI flags,
exit codes, `result.json` shape — remains binding and must not be broken.

---

## 1. Architectural Approach

One graph engine, two graph **instances** built from the same node and edge types:

| Instance | Nodes are | Replaces today's |
|---|---|---|
| **Agent graph** | Phase agents (ConstitutionAgent, PlannerAgent, QuestionAgent, OptimizationAgent, StagesAgent, BuildAgent, TestAgent) | Hardcoded 0→1→2→3→4→5 marching in `pipeline_engine.rs` |
| **Work graph** | Plan waves | `Plans/stages.json`, invented wholesale by an LLM and checked with `jq empty` |

The engine does not know which instance it is running. A node is a unit of work with a
declared input/output contract; an edge is a derived data dependency. That is the whole model.

**Central rule: edges are derived, never authored.** No manifest, no LLM, and no human writes
an edge. Edges fall out of the typed `produces`/`consumes` declarations. This is what turns
Article V's "the Planner is the *compiler* of Foundation" from a metaphor into a mechanism,
and it is what removes the current dependency on an LLM correctly guessing a whole DAG in one
shot.

---

## 2. Key Architectural Decisions

| # | Decision | Rationale | Rejected alternative |
|---|---|---|---|
| 1 | Edges derived from typed contracts, never declared | An asserted edge cannot be checked; a derived edge is a consequence of two declarations that can each be checked independently | LLM emits the edge list (status quo — unverifiable) |
| 2 | Closed artifact-type vocabulary | Constrained node vocabulary measurably beats free-form generation; unknown type is a loud failure, not a silent new node | Free-string types (typos silently create orphan nodes) |
| 3 | All graph properties computed by classical algorithms | Cycles, reachability, layering, critical path are computable; LLMs are pattern matchers, not solvers | Ask the model whether its own graph is acyclic |
| 4 | Engine is pure — no PTY, no terminal types | Must be unit-testable headlessly; mirrors the existing constraint in SPEC-B | Engine embedded in the TUI event loop |
| 5 | Runtime mutation is first-class, not bolted on | Article II §3 Phase 5 debug loops and Article VI amendments are graph mutations; a static graph cannot express them | Static graph + special-case retry logic |
| 6 | Human gates are node attributes | Article VIII checkpoints become data (`gate: "human"`), so any node can gate, not just Phase 0 | Approval hardcoded to phase 0 (status quo) |
| 7 | Agent graph and work graph share one engine | The two problems are the same problem; two engines means two DAG bugs | Separate stages.json path and pipeline path |

---

## 3. Data Model

### 3.1 Artifact type vocabulary (CLOSED — additions require amending this file)

```
constitution.root      C0
constitution.sub       C1..CN
plan.doc               planN.md
plan.test              testN.md
wave.subplan           waves/waveM/subplanM.md
wave.subtest           waves/waveM/subtestM.md
wave.unittest          waves/waveM/unit_tests.md
questions.doc          Plans/Questions.md
decision.log           decision_log.md
stages.graph           the derived work graph
code.module            generated source unit (named)
test.result            test outcome for a unit (named)
guide.doc              Guides/ self-documentation
```

A declared type outside this list is a validation error (`UnknownArtifactType`). Fail loudly —
no fallback, per repo code-style rules.

### 3.2 Node manifest

```json
{
  "schemaVersion": 1,
  "id": "phase1.planner",
  "kind": "agent",
  "label": "Planner Agent",
  "exec": {
    "type": "script",
    "path": "phase1/PlannerAgent.sh",
    "args": ["--project-dir", "${PROJECT_DIR}", "--yolo"]
  },
  "consumes": [{ "type": "constitution.root" }, { "type": "constitution.sub" }],
  "produces": [
    { "type": "plan.doc" }, { "type": "plan.test" },
    { "type": "wave.subplan" }, { "type": "decision.log" }
  ],
  "gate": "none",
  "retry": { "maxAttempts": 3 }
}
```

Work-graph node, same schema:

```json
{
  "schemaVersion": 1,
  "id": "plan1.wave2",
  "kind": "work",
  "label": "Auth module",
  "exec": { "type": "wave", "planPath": "Plans/plan1/waves/wave2" },
  "consumes": [{ "type": "code.module", "name": "core-models" }],
  "produces": [
    { "type": "code.module", "name": "auth" },
    { "type": "test.result", "name": "auth" }
  ],
  "gate": "none",
  "retry": { "maxAttempts": 3 }
}
```

Fields: `kind` ∈ {`agent`,`work`}. `gate` ∈ {`none`,`human`}. `exec.type` ∈
{`script`,`wave`}. An artifact ref is `{type}` or `{type,name}`.

### 3.3 Edge derivation rule

> Edge `A → B` exists **iff** `A.id ≠ B.id` and ∃ ref `r` such that `r ∈ A.produces` and
> `r ∈ B.consumes`.
> Refs match on `(type, name)` when both carry a `name`; on `type` alone when neither does.
> A named ref never matches an unnamed ref.

Multiple matching refs still yield one edge, carrying the matched refs as its label.

**Self-edges are never derived.** A node that both produces and consumes the same ref does not
depend on itself — it reads and appends to the same artifact within one execution. This case is
real and expected: the Optimization Agent consumes `decision.log` and appends its own decisions
to it. Without this rule the agent graph would contain a `phase3 → phase3` self-loop and fail
acyclicity. Implemented at `src/kgpe/derive.rs:9`.

**In-place rewrites are not `produces`.** An agent that modifies an existing artifact in place
must not declare that artifact in `produces` — doing so derives a back-edge to whichever node
consumes it, creating a cycle. The Optimization Agent rewrites `plan.doc` and `wave.subplan` in
place but declares only `wave.unittest` and `decision.log`, so `phase2 → phase3` does not gain a
false `phase3 → phase2` partner. In-place revision is a runtime `amend` concern (§5), not a
dependency.

---

## 4. Validation (deterministic — no LLM in this path)

Run in order; all are hard failures unless noted.

1. **Schema** — every manifest parses; every declared type is in §3.1; ids unique.
2. **Producer completeness** — every consumed ref has ≥1 producing node. Otherwise
   `MissingProducer { node, ref }`.
3. **Acyclicity** — Kahn's algorithm. On failure report the actual cycle path, not just "cycle".
4. **Reachability** — every node reachable from some in-degree-0 root. Orphans are an error
   (`UnreachableNode`), because an unreachable node silently never runs.
5. **Stage layering** — longest-path layering. Stage(n) = 1 + max(Stage(predecessors)),
   roots at stage 1. All nodes in a stage are parallel-safe by construction.
6. **Critical path** — longest path through the DAG; reported, not enforced.

Output of validation is a `GraphReport` carrying stages, critical path, and any errors.
`Plans/stages.md` (human) and `Plans/stages.json` (machine) are **rendered from** this report —
they become derived artifacts, not authored ones.

---

## 5. Execution Semantics

States: `Pending | Ready | Running | AwaitingApproval | Succeeded | Failed | HumanIntervention | Skipped`.

- **Ready set** — a node is Ready when every predecessor is `Succeeded` or `Skipped`.
- **Parallelism** — all Ready nodes may run concurrently; the engine never serializes beyond
  the dependency constraint.
- **Gates** — a node with `gate: "human"` enters `AwaitingApproval` after its own successful
  run and blocks successors until approved. Agents never block waiting on a human
  (PHASE_CONTRACT.md §4 keeps this true).
- **Exit-code mapping** (unchanged from PHASE_CONTRACT.md §3): 0 → `Succeeded`,
  10 → `Failed`, 11 → `Failed` (misconfiguration), 20 → `HumanIntervention`.

### Mutation operations (this is why the graph is dynamic, not static)

| Op | Meaning | Constitution basis |
|---|---|---|
| `retry(node)` | Failed node returns to `Ready` while `attempts < retry.maxAttempts`; on exhaustion → `HumanIntervention` | Art. II §3 Phase 5 debug loop |
| `amend(artifactRef)` | Invalidate the ref's producer node and the transitive closure of its dependents back to `Pending`; everything else stays `Succeeded` | Art. II §3 Phase 6 "only changed components re-executed" |
| `append(node)` | Insert a node at runtime; re-derive edges and re-validate before it becomes schedulable | Art. V §4 Adaptive Planning |

Every mutation re-runs §4 validation before the graph is schedulable again. A mutation that
would introduce a cycle is rejected and the graph is left untouched.

---

## 6. Component Boundaries

```
phase5/orchestrator/src/kgpe/        ← Codex owns (Phase A)
    types.rs        node/edge/artifact-ref types, closed vocabulary
    manifest.rs     load + schema-validate manifests
    derive.rs       edge derivation (§3.3)
    validate.rs     §4 checks, GraphReport
    engine.rs       execution states, ready set, mutation ops
    persist.rs      graph_state.json round-trip
.Foundation/Agents/phases/*/node.json   ← Kimi owns (Phase B)
.Foundation/Agents/phases/phase1/       ← Kimi owns: emit work-node manifests
.Foundation/Agents/phases/phase4/       ← Kimi owns: emit manifests, stop inventing edges
```

Neither worker edits the other's tree. Phase C wires `kgpe` into `pipeline_engine.rs`.

---

## 7. Failure Modes

| Mode | Detection | Response |
|---|---|---|
| LLM emits an unknown artifact type | Validation §4.1 | Hard fail with the offending type named; no silent coercion |
| LLM omits a `consumes` entry | Validation §4.4 — node becomes unreachable, or runs too early | Hard fail; surfaces as `UnreachableNode` |
| LLM invents a circular dependency | Validation §4.3 | Hard fail with the cycle path printed |
| Two nodes produce the same named ref | Derivation | Allowed (fan-in), but reported in `GraphReport.warnings` |
| Mutation introduces a cycle | Re-validation after mutation | Mutation rejected, graph unchanged |
| Manifest missing for an agent | Manifest load | Hard fail naming the expected path — never panic (SPEC-B precedent) |
| Worker collision in the repo | Directory ownership in §6 | Loop prompts forbid cross-tree edits; verifier checks `git diff` scope |

---

## 8. Explicitly Out of Scope

Training a graph neural encoder — MAML-style meta-learning, contrastive pre-training, or
GraphPrompt-style parameter-efficient tuning. Foundation has one Constitution per project, not
a corpus of graphs to train on. The design above is prompting + schema discipline + classical
algorithms, which is where the agentic literature (ControlLLM, TwoStepChat, GRASP, AgentKit)
says the benefit actually comes from without training anything.
