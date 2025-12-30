# Traycer CLI Agent Scripts

This guide explains how to create Traycer scripts to run various agents in different configurations.

## Overview

Traycer CLI agent scripts are shell scripts placed in `~/.traycer/cli-agents/` that wrap AI-powered tools for use within the Traycer workflow system. Each script receives prompts via environment variables and executes a specific agent configuration.

## Directory Structure

```
~/.traycer/cli-agents/
├── buildAgent-claude.sh    # BuildAgent with Claude provider
├── buildAgent-codex.sh     # BuildAgent with Codex provider
├── buildAgent-gemini.sh    # BuildAgent with Gemini provider
├── BuildAgent-letta.sh     # BuildAgent with Letta (stateful agents)
├── Claude.sh               # Direct Claude CLI
├── Codex.sh                # Direct Codex CLI
├── Cursor.sh               # Direct Cursor CLI
└── Gemini.sh               # Direct Gemini CLI
```

## Environment Variables

Traycer provides these environment variables at runtime:

| Variable | Description |
|----------|-------------|
| `$TRAYCER_PROMPT` | The prompt text (for short prompts) |
| `$TRAYCER_PROMPT_TMP_FILE` | Path to temp file containing the prompt (for large prompts) |
| `$TRAYCER_TASK_ID` | Task identifier - use for persistent sessions across phase iterations |
| `$TRAYCER_PHASE_BREAKDOWN_ID` | Phase breakdown ID - same session for current list of phases |
| `$TRAYCER_PHASE_ID` | Per-phase ID - same session for plan/review and verification |

## Script Template

### Basic BuildAgent Wrapper

```bash
#!/bin/bash
# BuildAgent <Provider> Wrapper - YOLO mode
stdbuf -oL -eL buildAgent --prompt "$TRAYCER_PROMPT_TMP_FILE" --verbose --ai-provider <provider> --yolo
```

### Why `stdbuf -oL -eL`?

The `stdbuf` command ensures unbuffered output:
- `-oL` - Line-buffered stdout (output appears immediately line by line)
- `-eL` - Line-buffered stderr (errors appear immediately)

This is critical for Traycer to display real-time progress from long-running agent processes.

## BuildAgent Configurations

### Claude Provider (Recommended)

```bash
#!/bin/bash
# BuildAgent Claude Wrapper - YOLO mode
stdbuf -oL -eL buildAgent --prompt "$TRAYCER_PROMPT_TMP_FILE" --verbose --ai-provider claude --yolo
```

### Letta Provider (Stateful Agents)

```bash
#!/bin/bash
# BuildAgent Letta Wrapper - YOLO mode
stdbuf -oL -eL buildAgent --prompt "$TRAYCER_PROMPT_TMP_FILE" --verbose --ai-provider letta --yolo
```

Letta creates directory-specific agents with persistent memory that learn your codebase over time.

### Codex Provider

```bash
#!/bin/bash
# BuildAgent Codex Wrapper - YOLO mode
stdbuf -oL -eL buildAgent --prompt "$TRAYCER_PROMPT_TMP_FILE" --verbose --ai-provider codex --yolo
```

### Gemini Provider

```bash
#!/bin/bash
# BuildAgent Gemini Wrapper - YOLO mode
stdbuf -oL -eL buildAgent --prompt "$TRAYCER_PROMPT_TMP_FILE" --verbose --ai-provider gemini --yolo
```

### Cursor Provider (Default)

```bash
#!/bin/bash
# BuildAgent Cursor Wrapper - YOLO mode
stdbuf -oL -eL buildAgent --prompt "$TRAYCER_PROMPT_TMP_FILE" --verbose --ai-provider cursor --yolo
```

## BuildAgent Options Reference

| Option | Description |
|--------|-------------|
| `--prompt <file>` | Path to prompt file (use `$TRAYCER_PROMPT_TMP_FILE`) |
| `--ai-provider <name>` | AI provider: `cursor`, `claude`, `codex`, `gemini`, `aider`, `letta` |
| `--verbose` | Enable detailed output logging |
| `--yolo` | Fully automated mode (auto-inits git, no confirmations) |
| `--plans-dir <dir>` | Directory for wave-based execution plans |
| `--swift-docs <dir>` | Path to Swift documentation for context |
| `--max-retries <n>` | Maximum build retry attempts (default: 3) |

## Direct CLI Agent Scripts

For running AI CLIs directly without BuildAgent:

### Claude Direct

```bash
#!/bin/sh
# Direct Claude CLI
claude --dangerously-skip-permissions "$TRAYCER_PROMPT"
```

### Using Prompt File (for large prompts)

```bash
#!/bin/sh
# Direct Claude CLI with file input
claude --dangerously-skip-permissions "$(cat $TRAYCER_PROMPT_TMP_FILE)"
```

## Creating a New Script

1. Create the script file:
   ```bash
   touch ~/.traycer/cli-agents/my-agent.sh
   chmod +x ~/.traycer/cli-agents/my-agent.sh
   ```

2. Add the shebang and configuration:
   ```bash
   #!/bin/bash
   # My Custom Agent Configuration
   stdbuf -oL -eL buildAgent --prompt "$TRAYCER_PROMPT_TMP_FILE" --verbose --ai-provider claude --yolo
   ```

3. The script will appear in Traycer's agent selection.

## Advanced Configurations

### Non-YOLO Mode (Interactive)

Remove `--yolo` for manual confirmations:

```bash
#!/bin/bash
# BuildAgent Claude - Interactive mode
stdbuf -oL -eL buildAgent --prompt "$TRAYCER_PROMPT_TMP_FILE" --verbose --ai-provider claude
```

### With Swift Documentation Context

```bash
#!/bin/bash
# BuildAgent with Swift docs
stdbuf -oL -eL buildAgent --prompt "$TRAYCER_PROMPT_TMP_FILE" --verbose --ai-provider claude --swift-docs Docs/swiftDocs --yolo
```

### With Custom Plans Directory

```bash
#!/bin/bash
# BuildAgent with custom plans
stdbuf -oL -eL buildAgent --prompt "$TRAYCER_PROMPT_TMP_FILE" --verbose --ai-provider claude --plans-dir .Foundation/.Planning/Plans --yolo
```

### Increased Retry Attempts

```bash
#!/bin/bash
# BuildAgent with more retries
stdbuf -oL -eL buildAgent --prompt "$TRAYCER_PROMPT_TMP_FILE" --verbose --ai-provider claude --max-retries 5 --yolo
```

## Environment Variables for API Keys

Set these in your shell profile (`~/.zshrc` or `~/.bashrc`):

```bash
# Claude
export ANTHROPIC_API_KEY=sk-ant-...

# OpenAI/Codex
export OPENAI_API_KEY=sk-...

# Gemini
export GOOGLE_API_KEY=...

# Letta
export LETTA_API_KEY=letta-...
export LETTA_BASE_URL=http://localhost:8283  # Optional: self-hosted
export LETTA_MODEL=sonnet-4.5                # Optional: specific model
```

## Troubleshooting

### Output Not Appearing in Real-Time

Ensure you're using `stdbuf -oL -eL` prefix.

### "buildAgent not found"

Add to PATH or use full path:
```bash
stdbuf -oL -eL ~/.local/bin/buildAgent --prompt ...
```

### Large Prompts Failing

Always use `$TRAYCER_PROMPT_TMP_FILE` instead of `$TRAYCER_PROMPT` for BuildAgent - it handles large prompts better.
