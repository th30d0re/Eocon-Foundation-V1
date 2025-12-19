# Phase 5: Build Agents

Phase 5 handles AI-powered code generation and build verification with automatic repair loops, multi-provider support, and intelligent auto-detection.

## Scripts

| Script | Purpose |
|--------|---------|
| `BuildAgent.sh` | Main orchestrator - generates code via AI CLI and verifies builds |
| `BuildLint.sh` | Build verification - runs lints and Xcode builds |

---

## 🚀 Quick Start

### Installation to PATH (Recommended)

Make BuildAgent and BuildLint available as global commands:

```bash
# From the repository root
sudo ln -s $(pwd)/.Foundation/Agents/phases/phase5/BuildAgent.sh /usr/local/bin/BuildAgent
sudo ln -s $(pwd)/.Foundation/Agents/phases/phase5/BuildLint.sh /usr/local/bin/BuildLint

# Now use from any Swift project!
cd /path/to/your/project
BuildAgent --plan plan.md
```

### Basic Usage

```bash
# Minimal - auto-detects everything
BuildAgent --plan plan.md

# Use Claude instead of Cursor
BuildAgent --plan plan.md --ai-provider claude

# Full automation mode
BuildAgent --plan plan.md --ai-provider claude --yolo
```

---

## BuildAgent.sh

The main build agent that orchestrates AI-powered code generation and verification.

### ✨ Features

- **🤖 Multi-AI Provider Support**: Choose from Cursor, Claude, Codex, Gemini, or Aider
- **🔧 Auto-Installation**: Missing providers are installed automatically using Cursor AI
- **🔍 Smart Auto-Detection**: 
  - Swift documentation (searches working directory first)
  - Xcode projects/workspaces (always detects, even with --scheme)
  - Build folders
  - Git repositories (auto-initializes in YOLO mode)
- **🔐 Auth Error Detection**: Detects authentication errors and provides setup instructions
- **⚡ Auto-Approval Flags**: Each provider gets automatic flags for unattended operation
- **🌍 PATH Support**: Install globally and use from any project directory
- **📁 Custom Build Folders**: Specify or auto-detect custom build output locations
- **🔄 Git Auto-Init**: Automatically initializes git repositories in YOLO mode for SwiftLint

### AI Provider Options

BuildAgent supports multiple AI providers:

| Provider | Command | Auto-Approval Flag | Installation |
|----------|---------|-------------------|--------------|
| **Cursor** (default) | `cursor-agent` | `--force` | Manual |
| **Claude** | `claude` | `--dangerously-skip-permissions` | Auto |
| **Codex/OpenAI** | `openai` | `--full-auto` | Auto |
| **Gemini** | `gemini` | `--yolo` | Auto |
| **Aider** | `aider` | `--yes` | Auto |

**Auto-Installation**: If a provider is not installed, BuildAgent will use Cursor AI to install it automatically!

```bash
# Use Claude (auto-installs if not present)
BuildAgent --plan plan.md --ai-provider claude

# Use Gemini with specific model
BuildAgent --plan plan.md --ai-provider gemini --ai-model gemini-2.0-pro
```

For full documentation, run:
```bash
BuildAgent --help
```

### 🔍 Smart Auto-Detection

BuildAgent automatically detects your project structure:

**Swift Documentation:**
- Searches `swiftDocs/`, `Docs/swiftDocs/`, `Documentation/swiftDocs/` in working directory first
- Falls back to searching in project root
- Over 15 search paths checked

**Xcode Projects:**
- Searches for `.xcworkspace` (preferred) or `.xcodeproj`
- Always runs detection, even when `--scheme` is provided
- Searches working directory first, then project root
- Automatically passes detected paths to BuildLint

**Git Repository:**
- Checks if git repository exists
- **YOLO mode**: Automatically runs `git init` if missing
- Creates initial commit for SwiftLint compatibility
- Non-fatal: continues if initialization fails

**Build Folders:**
- Auto-detects `Build/` folder in script directory
- Can specify custom path with `--derived-data`

---

## Requirements

### Required
- **Xcode**: Command line tools installed (`xcode-select --install`)
- **At least one AI provider**:
  - Cursor CLI (install from [cursor.sh](https://cursor.sh)) - Required for auto-installation
  - Or Claude CLI: `npm install -g @anthropic-ai/claude-cli`
  - Or OpenAI CLI: `pip install openai-cli`
  - Or Gemini CLI: `npm install -g @google/generative-ai-cli`
  - Or Aider: `pip install aider-chat`

### Optional
- **SwiftLint**: `brew install swiftlint` (for code linting)
- **Git**: `brew install git` (auto-initialized in YOLO mode if missing repository)

### Authentication Setup

Each AI provider requires authentication:

```bash
# Claude
export ANTHROPIC_API_KEY=sk-ant-...

# OpenAI/Codex
export OPENAI_API_KEY=sk-...

# Gemini
export GOOGLE_API_KEY=...

# Cursor - Already authenticated if Cursor IDE is logged in
# Aider - Uses OPENAI_API_KEY or ANTHROPIC_API_KEY
```

---

## Version History

**v2.1** (December 2024)
- Added automatic Xcode project detection (works even with --scheme provided)
- Added git repository auto-initialization in YOLO mode
- Fixed bash 3.2 compatibility (macOS default)
- Enhanced Swift docs detection to prioritize working directory
- Improved PATH support with WORK_DIR vs PROJECT_ROOT handling
- Added comprehensive debug logging

**v2.0** (December 2024)
- Added multi-AI provider support (Cursor, Claude, Codex, Gemini, Aider)
- Added automatic provider installation
- Added authentication error detection
- Added provider-specific auto-approval flags
- Added auto-detection (Swift docs, Xcode schemes, build folders)
- Added PATH support for global installation
- Added custom build folder support
- Enhanced help documentation

**v1.0** (Initial Release)
- Basic BuildAgent with Cursor CLI integration
- BuildLint for build verification
- Automatic repair loops

---

For complete documentation, run: `BuildAgent --help` or `BuildLint --help`
