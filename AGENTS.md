# Agent Instructions — Eocon Foundation V1

These instructions apply to all agents working in this repository (`Eocon-Foundation-V1`). They supplement the parent instructions in `$HOME/Dev/Tools/AGENTS.md`; where the two conflict, this project-specific file takes precedence.

## Project Overview

Eocon Foundation V1 is the reference implementation of the Foundation methodology: Constitution-driven, wave-based, multi-agent software construction. The repository contains:

- **Constitution documents** (LaTeX source of truth): `.Foundation/Foundation-constitution/`
- **Planning artifacts**: `.Foundation/.Planning/`
- **Agent scripts**: `.Foundation/Agents/phases/phase0/` through `phase5/`
- **Shared libraries**: `.Foundation/lib/`
- **SwiftUI macOS/iOS app**: `Foundation/` (separate git repo: Eocon-Foundation-Swift)
- **Rust TUI orchestrator**: `.Foundation/Agents/phases/phase5/orchestrator/`
- **BATS test suite**: `.Foundation/Agents/phases/phase5/tests/bats/`

The canonical project structure for any Foundation project is the **Five-Folder Foundation**:

1. `Constitution/` — LaTeX documents defining what the system IS and DOES.
2. `Plans/` — Wave-based execution plans, test specs, and decision logs.
3. `Guides/` — Self-documentation created by agents.
4. `Docs/` — External documentation and API references.
5. `Design/` — Shared code and reusable components.

## Build Commands

Use the root `setup.sh` to bootstrap a new checkout:

```bash
./setup.sh                # interactive, full setup
./setup.sh --yes          # non-interactive
./setup.sh --dry-run      # preview only
./setup.sh --skip-builds  # verify deps, skip Swift/Rust builds and tests
```

### Swift app

The Swift app lives in `Foundation/` (separate git repository). Build it with:

```bash
cd Foundation
xcodebuild -scheme Foundation -sdk macosx -destination 'platform=macOS' build
```

For iOS simulator:

```bash
xcodebuild -scheme Foundation -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15' build
```

### Rust orchestrator

```bash
cd .Foundation/Agents/phases/phase5/orchestrator
cargo build --release
ln -sf "$(pwd)/target/release/orch" ~/.local/bin/orch
```

Run mock mode: `orch --mock`  
Run real pipeline: `orch`

### Phase 5 BuildAgent

```bash
.Foundation/Agents/phases/phase5/BuildAgent.sh --plans-dir <dir> --prompt "description"
.Foundation/Agents/phases/phase5/BuildAgent.sh --ai-provider claude --plans-dir <dir> --prompt "description"
.Foundation/Agents/phases/phase5/BuildAgent.sh --yolo --plans-dir <dir> --prompt "description"
```

Supported providers: `cursor` (default), `claude`, `codex`, `gemini`, `aider`, `letta`.

### Build verification

```bash
.Foundation/Agents/phases/phase5/BuildLint.sh
.Foundation/Agents/phases/phase5/BuildVerify.sh
```

### BATS tests

```bash
.Foundation/Agents/phases/phase5/tests/bats/lib/bats-core/bin/bats \
  .Foundation/Agents/phases/phase5/tests/bats
```

Or, after running `setup.sh`:

```bash
./setup.sh --skip-builds
```

## Conventions

### Constitution-driven development

The LaTeX Constitution in `.Foundation/Foundation-constitution/` is the authoritative specification. All phases derive from it. When implementing a feature, first identify the relevant section of the Constitution and reference it in comments or commit messages.

### Module naming

Use `EoconFoundation` as `PRODUCT_MODULE_NAME` in Swift targets to avoid collisions with Apple's `Foundation` framework.

### Separate git repositories

`Foundation/` is a nested git repository (`Eocon-Foundation-Swift`). Do not commit it to the parent repo; it is already listed in `.gitignore`.

### Wave-based planning

Plans decompose into "waves" for token efficiency and parallel execution. Prefer small, dependency-ordered waves over monolithic plans.

### Shell style

- Entrypoint scripts use `set -euo pipefail`.
- Sourced libraries use include guards and define functions only.
- Load `.Foundation/lib/helpers.sh` and call `check_shell_compatibility || exit 11` where applicable.
- Resolve paths via `${BASH_SOURCE[0]}` symlinks, mirroring `BuildAgent.sh`.
- Run shellcheck before committing: `shellcheck -S warning -e SC1090,SC1091,SC2154,SC2034 <file>`.
- Limit emoji usage in code and logs to the existing ✓/✗ glyph convention.

### Exit codes

All phase agents share these exit codes:

| Code | Meaning |
|------|---------|
| 0 | Success (including `--dry-run`, `--help`) |
| 10 | Failed after max retries |
| 11 | Misconfiguration (bad flags, missing input, no provider CLI) |
| 20 | Human intervention required; details are in `result.json` and a `human_intervention_*.md` file |

## Phase Structure

Agents are organized by phase under `.Foundation/Agents/phases/`:

| Phase | Script | Responsibility |
|-------|--------|----------------|
| 0 | `phase0/ConstitutionAgent.sh` | Natural language → `Constitution/C0.tex` + sub-constitutions |
| 1 | `phase1/PlannerAgent.sh` | Constitutions → `Plans/` with waves |
| 2 | `phase2/QuestionAgent.sh` | Plans → `Plans/Questions.md` + decision logs |
| 3 | `phase3/OptimizationAgent.sh` | Questions + history → optimized plans/tests |
| 4 | `phase4/StagesAgent.sh` | Plans → `Plans/stages.md` + `Plans/stages.json` DAG |
| 5 | `phase5/BuildAgent.sh` + sub-agents | Execution: code generation, build, test, repair |

The orchestrator (`orch`) runs phases 0→5 in order, resuming from `<project>/Artifacts/pipeline_state.json`. Phase 0 always sets `requiresApproval: true` because Constitution approval is a mandatory human checkpoint.

The full phase contract is in `.Foundation/Agents/phases/PHASE_CONTRACT.md`.

## Testing

- **BATS**: Run the phase5 BATS suite after any change to `.Foundation/Agents/phases/phase5/` or `.Foundation/lib/`.
- **shellcheck**: Run on all new or modified shell scripts before commit.
- **Dry-run smoke tests**: Use `--dry-run` on agent scripts to verify scaffolding without AI calls or side effects.
- **Swift/Rust builds**: Verify both the Swift app and Rust orchestrator build cleanly before marking a task complete.

## Logging Requirements

This project follows the session-logging requirement defined in the parent `$HOME/Dev/Tools/AGENTS.md`:

- Create a comprehensive markdown log for every request that results in code changes, configuration changes, or implementations.
- Store logs in `$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/Root/AI Session Logs/`.
- Name the log `session-YYYY-MM-DD-HHMMSS.md`.
- Include: what was requested, how it was fixed, challenges encountered, and six next ideas.
- Specify the model name at the top of the log file.

## Cross-Audit Recommendations Being Adopted

The following cross-audit practices are in effect for this repository:

1. **Constitution-first changes.** Every non-trivial implementation must map to a section of the Foundation Constitution. If no section exists, flag it before proceeding.
2. **shellcheck before commit.** All shell scripts must pass `shellcheck -S warning -e SC1090,SC1091,SC2154,SC2034`.
3. **Dry-run testing.** Run agent scripts with `--dry-run` to confirm scaffolding and argument parsing before enabling AI calls.
4. **Commit before batch edits.** Follow the parent `AGENTS.md` commit safety rule: commit before any operation that could destroy or corrupt work, including batch edits >10 lines, automated transformations, or destructive operations.
5. **Verify builds before marking done.** Do not report a task complete while the Swift app, Rust orchestrator, or BATS tests are failing.
6. **Minimal, scoped changes.** Avoid opportunistic refactors. Match surrounding code style and naming conventions.

## Key Files

| Path | Purpose |
|------|---------|
| `.Foundation/Foundation-constitution/Foundation-Constitution.tex` | Main Constitution (source of truth) |
| `.Foundation/Agents/phases/PHASE_CONTRACT.md` | Phase agent CLI contract |
| `.Foundation/Agents/phases/phase5/BuildAgent.sh` | AI-powered build orchestrator |
| `.Foundation/Agents/phases/phase5/BuildLint.sh` | SwiftLint and Xcode build verification |
| `.Foundation/Agents/phases/phase5/orchestrator/` | Rust TUI orchestrator |
| `.Foundation/lib/helpers.sh` | Shared shell utilities |
| `setup.sh` | Root automated setup script |

## AI Provider Configuration

Agents may need API keys for the providers they invoke:

```bash
export ANTHROPIC_API_KEY=sk-ant-...        # Claude
export OPENAI_API_KEY=sk-...                # Codex
export GOOGLE_API_KEY=...                   # Gemini
export LETTA_API_KEY=letta-...              # Letta
```

Cursor is auto-authenticated when logged into the IDE. Letta supports optional `LETTA_BASE_URL` and `LETTA_MODEL` overrides.
