# Phase 5: Build Agents

Phase 5 handles AI-powered code generation and build verification with automatic repair loops, multi-provider support, and intelligent auto-detection.

## Shell Compatibility

**All Phase 5 agents require bash 3.2 or later.** Bash 4.0+ is recommended for full compatibility.

### Quick Check

```bash
# Check your bash version
bash --version

# macOS users: Install newer bash (recommended)
brew install bash

# Verify installation
/usr/local/bin/bash --version
```

### macOS Users

macOS ships with bash 3.2 (2007) due to licensing. While all agents work with bash 3.2, some features have limitations:

- ✅ **Fully Compatible**: Core build/test functionality, basic arrays, parameter expansion
- ⚠️ **Limited on bash 3.2**: Associative arrays, `readarray`/`mapfile` (requires bash 4.0+)
- 💡 **Recommended**: Install bash 4.0+ via Homebrew for full feature support

**Install newer bash on macOS:**

```bash
# Install via Homebrew
brew install bash

# Add to /etc/shells (for default shell, optional)
echo "/usr/local/bin/bash" | sudo tee -a /etc/shells

# Run agents with newer bash
/usr/local/bin/bash BuildAgent.sh --help
```

### Troubleshooting

**Error: "This script requires bash"**
```bash
# You're running in a different shell (zsh, sh, etc.)
# Solution: Execute with bash explicitly
bash BuildAgent.sh --plan plan.md
```

**Warning: "Running on bash 3.x"**
```bash
# Using macOS default bash (3.2) - agents work but with limitations
# Solution: Install bash 4.0+ via Homebrew (optional)
brew install bash
```

All agents use `#!/usr/bin/env bash` for maximum portability across environments. See [Shell Compatibility Guide](../../Docs/SHELL_COMPATIBILITY.md) for detailed information.

## Scripts

| Script | Purpose |
|--------|---------|
| `BuildAgent.sh` | Main orchestrator - generates code via AI CLI and verifies builds |
| `BuildLint.sh` | Build verification - runs SwiftLint and Xcode builds |

---

## 🚀 Quick Start

### Installation to PATH (Recommended)

Make BuildAgent and BuildLint available as global commands:

```bash
# From the repository root
sudo ln -s $(pwd)/.Foundation/Agents/phases/phase5/BuildAgent.sh /usr/local/bin/BuildAgent.sh
sudo ln -s $(pwd)/.Foundation/Agents/phases/phase5/BuildLint.sh /usr/local/bin/BuildLint.sh

# Now use from any Swift project!
cd /path/to/your/project
BuildAgent.sh --plan plan.md
```

### Basic Usage

```bash
# Auto-detect mode: runs build first, uses errors as AI input if any
BuildAgent.sh

# With a plan file - auto-detects everything (Xcode project, scheme, Swift docs)
BuildAgent.sh --plan plan.md

# Use Claude instead of Cursor
BuildAgent.sh --plan plan.md --ai-provider claude

# Full automation mode (5 retries, verbose, streaming)
BuildAgent.sh --plan plan.md --ai-provider claude --yolo
```

---

## BuildAgent.sh

The main build agent that orchestrates AI-powered code generation and verification.

### ✨ Features

- **🤖 Multi-AI Provider Support**: Choose from Cursor, Claude, Codex, Gemini, Aider, or Letta
- **🎯 Auto-Detect Mode**: Run without input - builds first, uses errors as AI input if any
- **🔧 Auto-Installation**: Missing AI providers are installed automatically using Cursor AI
- **🔍 Deep Auto-Detection**: Finds Xcode projects/workspaces and swiftDocs up to 5 levels deep
- **🚫 Smart Exclusions**: Automatically excludes `.build`, `Pods`, `Carthage`, `checkouts`, `DerivedData`
- **📚 Shortest Path Priority**: Finds your main project, not dependency projects
- **🔐 Auth Error Detection**: Detects authentication errors and provides setup instructions
- **⚡ Auto-Approval Flags**: Each provider gets automatic flags for unattended operation
- **🌍 PATH Support**: Install globally and use from any project directory
- **📁 Custom Build Folders**: Specify or auto-detect custom build output locations
- **🔄 Git Auto-Init**: Automatically initializes git repositories in YOLO mode for SwiftLint

### AI Provider Options

BuildAgent supports multiple AI providers:

| Provider | Command | Auto-Approval Flag | Installation | Notes |
|----------|---------|-------------------|--------------|-------|
| **Cursor** (default) | `cursor-agent` | `--force` | Manual | Requires Cursor IDE login |
| **Claude** | `claude` | `--dangerously-skip-permissions` | Auto | Via npm |
| **Codex/OpenAI** | `openai` | `--full-auto` | Auto | Via pip |
| **Gemini** | `gemini` | `--yolo` | Auto | Via npm |
| **Aider** | `aider` | `--yes` | Auto | Via pip |
| **Letta** | `letta` | `--yolo` | Auto | Via npm, stateful agents |

**Auto-Installation**: Missing providers are installed automatically!
- **Letta**: Installed via `npm install -g @letta-ai/letta-code` (requires Node.js 18+)
- **Others**: Installed using Cursor AI assistance

```bash
# Use Claude (auto-installs if not present)
BuildAgent.sh --plan plan.md --ai-provider claude

# Use Gemini with specific model
BuildAgent.sh --plan plan.md --ai-provider gemini --ai-model gemini-2.0-pro

# Use Letta (stateful agent with persistent memory per directory)
BuildAgent.sh --plan plan.md --ai-provider letta

# Use Letta with specific model
LETTA_MODEL=sonnet-4.5 BuildAgent.sh --plan plan.md --ai-provider letta
```

#### Letta: Stateful Agents

Letta is unique among providers - it creates **directory-specific agents** with persistent memory:

- **First Run**: Creates and pins an agent specific to your project directory
- **Subsequent Runs**: Resumes the same agent, which remembers:
  - Your codebase structure (via `/init`)
  - Previous build errors and fixes
  - Learned preferences and patterns
- **Benefits**: Agent improves over time, learns from failures, and retains context across build attempts

For full documentation, run:
```bash
BuildAgent.sh --help
```

### 🔍 Smart Auto-Detection

BuildAgent automatically detects your project structure:

**Swift Documentation:**
- Searches up to 5 levels deep for `swiftDocs/` directories
- Excludes dependency folders (`.build`, `Pods`, `Carthage`, `checkouts`, `Ref`)
- Prioritizes shortest path (main project docs, not dependencies)
- Searches working directory first, then project root

**Xcode Projects:**
- Searches up to 5 levels deep for `.xcworkspace` (preferred) or `.xcodeproj`
- Excludes dependency folders automatically
- Prioritizes shortest path (main project, not dependency projects)
- Always runs detection, even when `--scheme` is provided
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

## BuildLint.sh

Build verification script that runs SwiftLint and Xcode builds.

### ✨ Features

- **🔧 Auto-Install SwiftLint**: Automatically installs SwiftLint via Homebrew if not present
- **🍺 Auto-Install Homebrew**: Even installs Homebrew if missing (macOS/Linux)
- **📝 Smart Linting**: Only lints uncommitted Swift files (faster CI)
- **🎯 Deep Project Detection**: Finds Xcode projects up to 5 levels deep
- **🚫 Dependency Exclusion**: Skips `.build`, `Pods`, `Carthage`, `checkouts` folders

---

## Requirements

### Required
- **Xcode**: Command line tools installed (`xcode-select --install`)
- **At least one AI provider**:
  - Cursor CLI (install from [cursor.sh](https://cursor.sh)) - Required for auto-installation of others
  - Or Claude CLI: `npm install -g @anthropic-ai/claude-cli`
  - Or OpenAI CLI: `pip install openai-cli`
  - Or Gemini CLI: `npm install -g @google/generative-ai-cli`
  - Or Aider: `pip install aider-chat`
  - Or Letta: `npm install -g @letta-ai/letta-code` (requires Node.js 18+)

### Auto-Installed (if missing)
- **Homebrew**: Auto-installed on macOS/Linux if needed
- **SwiftLint**: Auto-installed via Homebrew for code linting
- **Git**: Auto-initialized in YOLO mode if repository missing

### Authentication Setup

Each AI provider requires authentication:

```bash
# Claude
export ANTHROPIC_API_KEY=sk-ant-...

# OpenAI/Codex
export OPENAI_API_KEY=sk-...

# Gemini
export GOOGLE_API_KEY=...

# Letta
export LETTA_API_KEY=letta-...
# Optional: Self-hosted instance
export LETTA_BASE_URL=http://localhost:8283

# Cursor - Already authenticated if Cursor IDE is logged in
# Aider - Uses OPENAI_API_KEY or ANTHROPIC_API_KEY
```

---

## Version History

**v2.2** (December 2024)
- Added Letta AI provider support (stateful agents with persistent memory)
- Directory-based agent strategy: each project gets its own agent
- Auto-installation via npm for Letta (requires Node.js 18+)
- nvm environment detection for Letta installation
- Agent memory persistence across build attempts

**v2.1** (December 2024)
- Deep auto-detection: Xcode projects and swiftDocs up to 5 levels deep
- Smart exclusions: Skips dependency folders (`.build`, `Pods`, `Carthage`, etc.)
- Shortest path priority: Finds main project, not dependency projects
- Auto-install SwiftLint via Homebrew
- Auto-install Homebrew if missing (macOS/Linux)
- Git repository auto-initialization in YOLO mode
- Fixed `pipefail` compatibility issues
- Fixed bash 3.2 compatibility (macOS default)
- Enhanced WORK_DIR vs PROJECT_ROOT handling

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

For complete documentation, run: `BuildAgent.sh --help` or `BuildLint.sh --help`
