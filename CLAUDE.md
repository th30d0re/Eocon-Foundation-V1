# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Eocon-Foundation-V1 is a framework for building agentic applications using the Foundation methodology. It contains:
- **Constitution documents** (LaTeX source of truth in `.Foundation/Foundation-constitution/`)
- **Build agents** (AI-powered code generation in `.Foundation/Agents/phases/phase5/`)
- **Foundation** (macOS/iOS/visionOS SwiftUI app in `Foundation/` - separate git repo)
- **Planning tools and shared libraries** (`.Foundation/.Planning/` and `.Foundation/lib/`)

The Swift application in `Foundation/` is also available as a separate repository: [Eocon-Foundation-Swift](https://github.com/nottinghillai/Eocon-Foundation-Swift)

## Build Commands

### BuildAgent (AI-powered code generation)
```bash
# Run from project root (auto-detects Xcode project up to 5 levels deep)
.Foundation/Agents/phases/phase5/BuildAgent.sh --plans-dir <dir> --prompt "description"

# With specific AI provider
.Foundation/Agents/phases/phase5/BuildAgent.sh --ai-provider claude --plans-dir <dir> --prompt "description"

# YOLO mode (fully automated, auto-inits git if needed)
.Foundation/Agents/phases/phase5/BuildAgent.sh --yolo --plans-dir <dir> --prompt "description"
```

Supported AI providers: `cursor` (default), `claude`, `codex`, `gemini`, `aider`, `letta`

**Letta** is unique - it creates directory-specific stateful agents with persistent memory that learn your codebase over time.

### BuildLint (verification)
```bash
.Foundation/Agents/phases/phase5/BuildLint.sh
```

### Foundation App (SwiftUI)
```bash
cd Foundation
open Foundation.xcodeproj

# Build for iOS
xcodebuild -scheme Foundation -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15'

# Build for macOS
xcodebuild -scheme Foundation -sdk macosx -destination 'platform=macOS'

# Run tests
xcodebuild test -scheme Foundation -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15'
```

## Architecture

### Five-Folder Foundation Structure
Every Foundation project maintains:
1. **Constitution/** - LaTeX documents defining system behavior (source of truth)
2. **Plans/** - Wave-based execution plans for token efficiency
3. **Guides/** - Self-documentation and patterns
4. **Docs/** - External documentation (auto-scraped Swift docs in `swiftDocs/`)
5. **Design/** - Shared code and reusable components

### Foundation App Architecture (MVVM-S Pattern)
- **Models/** - Data structures (`BuildAgentConfig`, `BuildSession`, `AIProvider`, etc.)
- **Views/** - SwiftUI views organized by feature (Configuration/, Logs/, Progress/, etc.)
- **ViewModels/** - State management (`BuildAgentViewModel` orchestrates all state)
- **Styles/** - Separate style modules per view for consistent HIG-compliant layout
- **Utilities/** - Shared utilities (`ANSIParser`, `DateFormatters`, `ConfigPersistence`)

### Build Phases (6-phase workflow)
`gatheringContext` → `generatingCode` → `building` → `testing` → `completed` | `failed`

### BuildAgent Exit Codes
- `0`: Success
- `10`: Build failed after max retries
- `11`: Misconfiguration
- `20`: Human intervention required

## Key Files

| Path | Purpose |
|------|---------|
| `.Foundation/Foundation-constitution/Foundation-Constitution.tex` | Main 70+ page Constitution (source of truth) |
| `.Foundation/Agents/phases/phase5/BuildAgent.sh` | AI-powered build orchestrator (2000+ lines) |
| `.Foundation/Agents/phases/phase5/BuildLint.sh` | SwiftLint and Xcode build verification |
| `.Foundation/lib/helpers.sh` | Shared utilities (OS detection, logging) |
| `Foundation/Foundation/ViewModels/BuildAgentViewModel.swift` | Main state management |
| `Foundation/Foundation/Utilities/ConfigPersistence.swift` | Configuration persistence |
| `.Foundation/Version_and_updates/CHANGELOG.md` | Detailed version history |

## AI Provider Configuration

```bash
# Claude (required for auto-install fallback)
export ANTHROPIC_API_KEY=sk-ant-...

# OpenAI/Codex
export OPENAI_API_KEY=sk-...

# Gemini
export GOOGLE_API_KEY=...

# Letta (stateful agents with persistent memory)
export LETTA_API_KEY=letta-...
# Optional: self-hosted instance
export LETTA_BASE_URL=http://localhost:8283
# Optional: specific model
export LETTA_MODEL=sonnet-4.5

# Cursor - auto-authenticated if logged into IDE
```

## Important Conventions

1. **Constitution-Driven Development**: The LaTeX Constitution in `.Foundation/Foundation-constitution/` is the authoritative specification. All phases derive from it.

2. **Module Naming**: Use `EoconFoundation` as `PRODUCT_MODULE_NAME` to avoid conflicts with Apple's Foundation framework.

3. **Separate Git Repos**: The `Foundation/` directory is a separate git repository (Eocon-Foundation-Swift). Be mindful when committing.

4. **BuildAgent Auto-Detection**: Automatically finds Xcode projects up to 5 levels deep, excluding dependency folders (.build, Pods, Carthage, checkouts).

5. **Wave-Based Planning**: Plans decompose into "waves" for token efficiency and parallel execution.
