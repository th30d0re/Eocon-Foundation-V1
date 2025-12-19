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

### ✨ New Features

- **🤖 Multi-AI Provider Support**: Choose from Cursor, Claude, Codex, Gemini, or Aider
- **🔧 Auto-Installation**: Missing providers are installed automatically using Cursor AI
- **🔍 Auto-Detection**: Automatically finds Swift docs, Xcode schemes, and build folders
- **🔐 Auth Error Detection**: Detects authentication errors and provides setup instructions
- **⚡ Auto-Approval Flags**: Each provider gets automatic flags for unattended operation
- **🌍 PATH Support**: Install globally and use from any project directory
- **📁 Custom Build Folders**: Specify or auto-detect custom build output locations

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
