# SPEC A — Build Phase 0–4 Agents

You are implementing in the repo rooted at the directory containing `.Foundation/`.
Work ONLY inside `.Foundation/Agents/phases/` — specifically NEW directories
`phase0/ phase1/ phase2/ phase3/ phase4/ shared/` and a NEW harness
`test-phase-agents.sh` + NEW bats file `phase5/tests/bats/phase_agents.bats` is
NOT where it goes — put bats tests in `.Foundation/Agents/phases/tests/bats/`.

## Objective

Create the five missing Foundation pipeline agents as bash scripts, conforming
EXACTLY to `.Foundation/Agents/phases/PHASE_CONTRACT.md` (read it first — it is
the authoritative contract). The Foundation Constitution
(`.Foundation/Foundation-constitution/Foundation-Constitution.tex`, Article II
§3–§4) defines what each agent does; the contract defines the interface.

## Files to create

1. `.Foundation/Agents/phases/shared/agentCore.sh` — sourced library (include
   guard, functions only):
   - logging helpers (mirror the look of `phase5/lib/build/logging.sh` — read it)
   - `detect_foundation_project <start-dir>` — walk upward looking for a dir
     containing `Constitution/` or `.Foundation/`; echo project root
   - `ensure_five_folders <project-dir>` — mkdir -p Constitution Plans Guides Docs Design
   - `run_phase_ai <provider> <model> <prompt-file> <output-hint>` — headless
     one-shot AI call. Provider invocations (reuse patterns from
     `.Foundation/lib/ai_provider.sh` where they exist):
     - claude: `claude -p "$(cat prompt)" ...` (print mode)
     - codex: `codex exec` with prompt on stdin
     - gemini: gemini CLI print mode
     - cursor/kimi: best-effort analogous; if CLI missing -> return 11
   - `write_phase_result <project> <phase> <agent> <status> <outputs-json-array> <requires-approval>`
     — writes `Artifacts/phase<N>_<ts>/result.json` per contract §4 (use jq if
     available, else printf JSON carefully)
   - `append_decision_log <file> <decision> <rationale>` — timestamped entry
2. `.Foundation/Agents/phases/phase0/ConstitutionAgent.sh`
3. `.Foundation/Agents/phases/phase1/PlannerAgent.sh`
4. `.Foundation/Agents/phases/phase2/QuestionAgent.sh`
5. `.Foundation/Agents/phases/phase3/OptimizationAgent.sh`
6. `.Foundation/Agents/phases/phase4/StagesAgent.sh`
7. `.Foundation/Agents/phases/test-phase-agents.sh` — harness modeled on
   `phase5/test-all-agents.sh` (read it): stage 1 `--help` smoke for all five
   agents + shellcheck (`-S warning -e SC1090,SC1091,SC2154,SC2034`) over
   `phase*/​*.sh` and `shared/*.sh`; stage 2 runs bats suite at
   `.Foundation/Agents/phases/tests/bats/` using the EXISTING bats-core checkout
   at `phase5/tests/bats/lib/bats-core/bin/bats` (do not vendor a second copy).
8. `.Foundation/Agents/phases/tests/bats/phase_agents.bats` (+ a small
   `test_helper.bash`) — see Acceptance.

## Agent behavior (each agent)

Standard skeleton: bash header per `phase5/lib/testUtils.sh` lines 1–45 pattern
(`${BASH_SOURCE[0]}` path detection, source `.Foundation/lib/helpers.sh`,
`check_shell_compatibility || exit 11`), `set -euo pipefail`, arg parsing for
the contract flags, then:

1. Resolve `--project-dir` (or detect); `ensure_five_folders`.
2. Validate phase-specific inputs (contract §2 table); bad input -> exit 11
   with a clear message.
3. **Dry-run path** (`--dry-run`): write template/scaffold outputs containing
   `<!-- DRY-RUN PLACEHOLDER -->` (or `% DRY-RUN PLACEHOLDER` for .tex) at the
   exact paths the contract specifies, write result.json with
   `status: "dry_run"`, exit 0. ZERO AI/network calls.
4. **Real path**: build a phase-specific prompt (see below), call
   `run_phase_ai`, post-process output into the contract's output files, write
   result.json, exit per contract §3.
5. Phase 0 always sets `requiresApproval: true` in result.json.

Phase prompt content (embed as heredoc templates; keep them faithful to the
Constitution):

- **Phase 0**: from the user's NL input, produce `C0.tex` (root constitution:
  concept, business model, constellation structure, high-level requirements)
  and one `CN.tex` per identified micro-app (purpose, requirements, integration
  specs, API contracts). Use the LaTeX section structure from Constitution
  Art. XI §1 (Abstract, Purpose, Requirements, Architecture, User Flows,
  Business Logic, Integration, Testing Criteria, Deployment, Maintenance).
- **Phase 1**: parse each constitution into `planN/` folders with `planN.md`,
  `testN.md`, and wave decomposition `waves/waveM/subplanM.md` + `subtestM.md`.
  Plan format per Art. XI §2 (task description, dependencies, technical
  approach, acceptance criteria, test requirements, complexity, target stack).
  Waves must be sized for one-shot model execution (token-efficient).
- **Phase 2**: scan all plans/waves; emit `Plans/Questions.md` (numbered
  questions grouped by plan, each tagged with the file/section it came from)
  and append ambiguity entries to each plan's `decision_log.md`. This agent
  asks; it NEVER answers.
- **Phase 3**: read Questions.md + plans + `Guides/`, `Design/`, `Docs/`
  context; apply the self-resolution algorithm (Art. II §4 Agent 3: historical
  pattern -> apply; not required -> skip, prevent scope creep; required ->
  industry best practice); rewrite plans/tests/subplans in place, generate
  `waves/waveM/unit_tests.md`, append every decision + rationale to
  `decision_log.md`.
- **Phase 4**: read all plans/waves, build the dependency DAG, emit
  `Plans/stages.md` (format in Constitution Art. II §3 Phase 4) AND
  `Plans/stages.json` per contract §2 schema. For stages.json, prefer having
  the AI emit JSON between sentinel markers, then validate with `jq empty`;
  invalid JSON after 2 retries -> exit 10.

## Constraints

- DO NOT modify anything under `phase5/` (another worker owns it), the
  orchestrator, `.Foundation/lib/*` (read-only), or PHASE_CONTRACT.md itself.
- Do not call `phase5/lib/build/ai_cli.sh`.
- No new external dependencies beyond bash/jq/standard tools already used.
- macOS bash 3.2 compatibility matters — follow whatever `helpers.sh`'s
  `check_shell_compatibility` enforces; avoid bash-4-only features (no
  associative arrays, no `${var,,}`).

## Acceptance criteria (must all be green before you report done)

```bash
bash .Foundation/Agents/phases/test-phase-agents.sh
```

exits 0, and its bats suite must include AT MINIMUM:

- each of the 5 agents: `--help` exits 0 and mentions every contract flag
- each agent: missing required input -> exit 11
- each agent: `--dry-run --yolo --project-dir <mktemp project>` exits 0 AND
  creates the contract §2 outputs for that phase (e.g. phase0 creates
  `Constitution/C0.tex`; phase1 creates `Plans/plan1/plan1.md`,
  `Plans/plan1/testN.md`... at least one full plan+wave scaffold; phase4
  creates `Plans/stages.md` and `Plans/stages.json` that passes `jq empty`)
- each dry-run writes `Artifacts/phase<N>_*/result.json` with
  `status == "dry_run"` and correct `phase` (assert with jq)
- phase0 result.json has `requiresApproval == true`

Report at the end: list of files created, and the full output of the
acceptance command.
