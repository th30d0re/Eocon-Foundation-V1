# Path Audit Report — Eocon-Foundation-V1

**Date:** 2026-07-06  
**Scope:** Replace hardcoded `/Users/emmanuel/...` absolute paths with portable alternatives.

## Summary

- **Paths changed:** 33
- **Files changed:** 12
- **Paths left untouched:** Generated error logs in `.Foundation/errors/`, LaTeX auxiliary files (`.fdb_latexmk`, `.fls`), and the `.Foundation/Docs/swiftDocs` submodule.

## Changes

| File | Original path | Replacement | Reasoning |
|------|---------------|-------------|-----------|
| `AGENTS.md` | `/Users/emmanuel/Dev/Tools/Eocon-Foundation-V1/` | `this repository (Eocon-Foundation-V1)` | Self-reference; remove hardcoded absolute path. |
| `AGENTS.md` | `/Users/emmanuel/Dev/Tools/AGENTS.md` | `$HOME/Dev/Tools/AGENTS.md` | Parent instructions reference; example path. |
| `AGENTS.md` | `/Users/emmanuel/Library/Mobile Documents/...` | `$HOME/Library/Mobile Documents/...` | Log directory example. |
| `.Foundation/Agents/phases/phase5/BuildAgent.sh` | `/Users/emmanuel/Dev/Tools/Eocon-Foundation-V1/.Foundation/lib` | `${PROJECT_ROOT}/.Foundation/lib` | Use already-computed project root. |
| `.Foundation/Agents/phases/phase5/BuildAgent.sh` | `/Users/emmanuel/Dev/Tools/Eocon-Foundation-V1/.Foundation/Docs/swiftDocs` | `${PROJECT_ROOT}/.Foundation/Docs/swiftDocs` | Use already-computed project root. |
| `.Foundation/Agents/phases/phase5/lib/build/detect.sh` | `/Users/emmanuel/Dev/Tools/Eocon-Foundation-V1/.Foundation/Docs/swiftDocs` | `${PROJECT_ROOT}/.Foundation/Docs/swiftDocs` | Use already-computed project root. |
| `.Foundation/Agents/phases/phase5/lib/build/prompt.sh` | `/Users/emmanuel/Dev/Tools/Eocon-Foundation-V1/.Foundation/Docs/swiftDocs/Testing/XCODEBUILD_MCP_WORKFLOW.md` (×3) | `${PROJECT_ROOT}/.Foundation/Docs/swiftDocs/Testing/XCODEBUILD_MCP_WORKFLOW.md` | Use already-computed project root. |
| `.Foundation/Agents/phases/phase5/orchestrator/src/chat.rs` | `/Users/emmanuel/.bun/bin/codex` | `home_path(".bun/bin/codex")` | User home binary; resolve via `$HOME`. |
| `.Foundation/Agents/phases/phase5/orchestrator/src/chat.rs` | `/Users/emmanuel/.local/bin/cursor` | `home_path(".local/bin/cursor")` | User home binary; resolve via `$HOME`. |
| `.Foundation/scripts/add_gemini_mcp.sh` | `/Users/emmanuel/.smithery/cache/servers/...` | `${XCODEBUILDMCP_SERVER:-${HOME}/.smithery/cache/servers/...}` | User home tool path; allow env override. |
| `.Foundation/Docs/XCODE_MCP_SETUP.md` | `/Users/emmanuel/Dev/Tools/Eocon-Foundation-V1/Foundation/Foundation.xcodeproj` | `${EOCON_PROJECT_ROOT:-$HOME/Dev/Tools/Eocon-Foundation-V1}/Foundation/Foundation.xcodeproj` | Documentation example; use env var. |
| `.Foundation/Docs/XCODE_MCP_SETUP.md` | `/Users/emmanuel/.bun/bin/codex` | `$HOME/.bun/bin/codex` | Documentation example. |
| `.Foundation/Docs/GEMINI_MCP_*.md`, `CODEX_MCP_SETUP.md` | `/Users/emmanuel/.smithery/cache/servers/...` (×13) | `$HOME/.smithery/cache/servers/...` | Documentation examples. |
| `.Foundation/Docs/GEMINI_MCP_MULTI_PROJECT.md` | `/Users/emmanuel/Dev/Project1` etc. | `$HOME/Dev/Project1` etc. | Documentation examples. |

## New/Updated Environment Variables

- `PROJECT_ROOT` — already used by agent scripts; now used in place of hardcoded Foundation paths.
- `EOCON_PROJECT_ROOT` — optional override for Foundation project root in documentation examples.
- `XCODEBUILDMCP_SERVER` — optional override for the XcodeBuildMCP server path.

## Verification

- `cargo check` in `.Foundation/Agents/phases/phase5/orchestrator/` passes.
- `bash -n` passes on all modified shell scripts:
  - `.Foundation/Agents/phases/phase5/BuildAgent.sh`
  - `.Foundation/Agents/phases/phase5/lib/build/detect.sh`
  - `.Foundation/Agents/phases/phase5/lib/build/prompt.sh`
  - `.Foundation/scripts/add_gemini_mcp.sh`

## Paths Not Replaced

- `.Foundation/errors/human_intervention_*.md` — generated build error logs; ephemeral artifacts.
- `.Foundation/.Planning/Constitution/*.fdb_latexmk`, `*.fls` and `.Foundation/Foundation-constitution/*.fdb_latexmk`, `*.fls` — generated LaTeX auxiliary files.
- `.Foundation/Docs/swiftDocs/` — external git submodule; left untouched per the conservative scope.
