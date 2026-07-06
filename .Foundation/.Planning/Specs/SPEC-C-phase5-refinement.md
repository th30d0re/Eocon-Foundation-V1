# SPEC C — Phase 5 Build/Test Agent Refinement

Work ONLY inside `.Foundation/Agents/phases/phase5/` and ONLY on these paths:
- `tests/bats/` (new .bats files)
- `lib/build/run.sh` and `lib/build/output.sh` (Guides write-back)
- `BuildAgent.sh` (one new flag)

DO NOT touch: `orchestrator/` (another worker owns it), anything under
`.Foundation/Agents/phases/phase{0,1,2,3,4}` or `phases/shared` or
`phases/tests` (another worker owns those), `tools/`, sub-agent scripts,
`test-all-agents.sh`.

## Context

The phase-5 decomposition is complete: `BuildAgent.sh` sources 11 modules from
`lib/build/`, and `tests/bats/` covers logging, output, detect, repair,
subagents (35 tests, all green — verify yourself first with
`./test-all-agents.sh`). Two refinements remain.

## Part 1 — Close the bats coverage gap

Add characterization tests for the untested pure(ish) functions in the
remaining modules. New files, using the existing `tests/bats/test_helper.bash`
conventions (read it and one existing .bats file first; `load_build_lib`
pattern):

- `tests/bats/queue.bats` — `lib/build/queue.sh`: lock acquire/release
  behavior in a tempdir (init, acquire when free, second acquire blocked or
  queued per current semantics, release frees it, status reporting)
- `tests/bats/context.bats` — `lib/build/context.sh`: cache key computation
  (`_compute_context_cache_key` stable for same inputs / different for
  different), save/load round-trip in tempdir, `read_md_files_from_dir`
  on a fixture dir
- `tests/bats/prompt.bats` — `lib/build/prompt.sh`: `build_initial_prompt` /
  `build_followup_prompt` include the expected sections, `parse_todo_file` +
  `inject_todos_into_prompt` against a fixture todo file,
  `build_followup_prompt_with_strategy` mentions the chosen strategy
- `tests/bats/ui.bats` — `lib/build/ui.sh`: non-interactive-safe functions
  only (`detect_unbuffer_method` returns something sane; config/startup box
  functions emit expected labels when run with a dumb TERM). Skip anything that
  truly needs a TTY with `skip`.

Rules: NO network, NO AI CLI invocations, each test isolated in `$BATS_TEST_TMPDIR`,
characterize CURRENT behavior (if you believe you found a real bug, do not
change behavior — note it in your final report instead).

## Part 2 — Guides/ self-documentation write-back

Constitution Article II §3 Phase 5 step 4 ("Document implementation in
Guides/") and Article XI §3 (Guide format) are unimplemented. Implement:

- New function `write_build_guide` in `lib/build/output.sh`:
  writes `<project>/Guides/build_<YYYYMMDD_HHMMSS>.md` containing the Art. XI
  §3 sections: What was implemented (prompt/plan summary — first ~30 lines of
  the prompt or plan file), How (provider, model, attempts used), Decisions
  made and rationale (repair strategies chosen this run, from the repair loop
  variables already available), Challenges (error patterns encountered),
  Solutions applied, Lessons learned (pass/fail counts). Use only data already
  flowing through the build loop — do not add new bookkeeping beyond a couple
  of accumulator variables if needed.
- Call it from the success paths of the build loop in `lib/build/run.sh`
  (where `write_success_status` is invoked — both single and plans-sequence
  paths).
- New BuildAgent flag `--no-guides` (and env `BUILD_GUIDES=0`) disables it.
  Respect dry-run (no guide written). `--help` documents the flag.
- `tests/bats/guides.bats`: calling `write_build_guide` with stubbed vars in a
  tempdir produces a file with all six section headers; `--no-guides` path
  produces nothing.

## Acceptance criteria (all green before reporting done)

```bash
cd .Foundation/Agents/phases/phase5
./test-all-agents.sh          # exit 0 — includes your new bats files automatically
shellcheck -S warning -e SC1090,SC1091,SC2154,SC2034 lib/build/run.sh lib/build/output.sh BuildAgent.sh
BUILDAGENT_NO_MAIN=1 bash -c 'source ./BuildAgent.sh'   # still sources clean
./BuildAgent.sh --help | grep -q "no-guides"
```

Report at the end: files changed/created, count of new bats tests, any
suspected bugs you characterized but did not fix, and full
`./test-all-agents.sh` tail output.
