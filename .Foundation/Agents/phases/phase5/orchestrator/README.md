# orch — Foundation Orchestrator

A Rust TUI orchestrator for the Foundation build pipeline. Replaces the legacy Bash `BuildVerify.sh` split-pane UI with a robust ratatui-based terminal interface while preserving the native fancy/colored output of `BuildAgent.sh` and `testAgent.sh`.

## Installation

```bash
# Build release binary
cargo build --release

# Symlink to ~/.local/bin (already done)
ln -sf $(pwd)/target/release/orch ~/.local/bin/orch

# Ensure ~/.local/bin is in your PATH. Add to ~/.bash_profile if needed:
export PATH="$HOME/.local/bin:$PATH"
```

## Usage

```bash
# Mock mode — renders the full UI with synthetic output, no subprocesses.
orch --mock

# Real build + test pipeline (auto-detects project and scheme)
orch

# With explicit project / scheme
orch --project MyApp.xcodeproj --scheme MyApp

# With full options
orch \
  --project MyApp.xcodeproj \
  --scheme MyApp \
  --ai-provider openai \
  --artifacts-dir ./Artifacts \
  --verbose
```

## Controls

| Key | Action |
|-----|--------|
| `Tab` | Cycle pane layout: Split → OutputOnly → InteractionOnly |
| `Shift+Tab` | Expand/contract info panel |
| `Esc` / `Ctrl+C` | Quit / abort |
| `y` / `n` | Confirm yes/no (in Failed state only) |
| `Enter` | Submit command from input bar |
| `Backspace` | Delete character in input bar |
| `←` / `→` | Move cursor in input bar |

## Input Bar Commands

Type in the bottom input bar and press `Enter`:

| Command | Description |
|---------|-------------|
| `/help` | List all commands |
| `/skip` | Skip current phase |
| `/quit` | Exit orchestrator |
| `/yes` | Confirm re-run build |
| `/no` | Abort |
| `/Model <name>` | Switch AI provider |
| `/artifacts` | Show Artifacts view (full paths) |
| `/metrics` | Show Metrics view |
| `/info` | Toggle between views |
| `/status` | Show current status |
| `--project <name>` | Set project |
| `--scheme <name>` | Set scheme |
| `--yolo` | Enable yolo mode |
| `--verbose` | Toggle verbose |

## Info Panel

- **Contracted** (1 line): `Provider: anthropic | Model: claude-sonnet-4`
- **Expanded Metrics view**: version, provider/model, phase, errors, elapsed time, layout
- **Expanded Artifacts view**: agents dir, artifacts dir, cwd, project, scheme (all full paths for copy/paste debug)

## Why PTY?

The Bash agents gate fancy UI and colors on `[ -t 2 ]` (stderr is a TTY) and read interactive keys from `/dev/tty`. Capturing them through a plain pipe strips ANSI colors and disables the fancy UI. The orchestrator spawns each agent inside a **pseudo-terminal (PTY)** via `portable-pty` so:

- The agent believes it owns a terminal and emits its full colored/fancy output.
- The agent's `/dev/tty` keyreader does not conflict with the orchestrator's own input loop.
- ANSI sequences are decoded by a VTE virtual screen and rendered into the right output pane.

## Files

```
src/
├── main.rs            # Thin CLI entry point
├── lib.rs             # Re-exports, Config, run()
├── app.rs             # App state machine (Model)
├── action.rs          # Action enum
├── event.rs           # crossterm poll loop + mpsc drain
├── tui.rs             # Terminal lifecycle RAII guard
├── pty_screen.rs      # VTE virtual screen -> ratatui Text
├── mock.rs            # Mock generators for --mock
├── ui/
│   ├── mod.rs         # Single draw() render
│   ├── layout.rs      # Constraint splits
│   ├── panes.rs       # Interaction + output widgets
│   ├── info_bar.rs    # Info line + panel + input bar
│   ├── status_bar.rs  # Status line
│   ├── prompt.rs      # Bottom prompt / help
│   └── theme.rs       # Voice colors
└── agents/
    ├── mod.rs
    ├── runner.rs      # PTY spawn + reader thread
    ├── build_agent.rs # BuildAgent arg builder
    ├── test_agent.rs  # TestAgent arg builder
    └── parser.rs      # Error/warning/[PASS]/[FAIL] scanner
```

## License

Same as the parent Foundation project.
