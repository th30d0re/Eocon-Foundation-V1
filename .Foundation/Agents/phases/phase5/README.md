# Phase 5: Build Agents

Phase 5 handles code generation and build verification using AI-assisted development with automatic repair loops.

## Scripts

| Script | Purpose |
|--------|---------|
| `BuildAgent.sh` | Main orchestrator - generates code via Cursor CLI and verifies builds |
| `BuildLint.sh` | Build verification - runs lints and Xcode builds |

---

## BuildAgent.sh

The main build agent that orchestrates code generation and verification.

### Quick Start

```bash
# Generate code from a plan file
./BuildAgent.sh --plan Plans/plan1/plan1.md --scheme MyApp

# Use a simple prompt
./BuildAgent.sh --prompt-string "Add a logout button to SettingsView" --scheme MyApp

# Read prompt from stdin
echo "Fix the authentication bug" | ./BuildAgent.sh --stdin --scheme MyApp
```

### Input Options

You must provide at least one input source:

| Option | Description |
|--------|-------------|
| `--plan <file.md>` | Path to a plan markdown file (from Phase 1-4) |
| `--prompt <file.txt>` | Path to a prompt text file |
| `--prompt-string <str>` | Prompt string directly on command line |
| `--stdin` | Read prompt from standard input |

### Context Options

Add reference documentation to improve code generation:

| Option | Description |
|--------|-------------|
| `--context <path>` | MD file or directory with MD files (repeatable) |
| `--swift-docs <path>` | Path to Swift documentation (default: `Docs/swiftDocs`) |
| `--no-swift-docs` | Skip Swift docs context |

**Example with multiple context sources:**
```bash
./BuildAgent.sh --plan plan.md \
    --context Guides/authentication.md \
    --context Docs/Ref/ \
    --swift-docs Docs/swiftDocs/ \
    --scheme MyApp
```

### Build Options

Configure the Xcode build:

| Option | Description |
|--------|-------------|
| `--target-id <id>` | Device/Simulator UDID (e.g., `00008150-001D5822210A401C`) |
| `--destination <dest>` | Full destination string (overrides --target-id) |
| `--scheme <scheme>` | Xcode scheme to build |
| `--configuration <cfg>` | Build configuration (default: `Debug`) |
| `--skip-lint` | Skip SwiftLint checks on uncommitted files |

**Example targeting a specific device:**
```bash
./BuildAgent.sh --plan plan.md \
    --target-id 00008150-001D5822210A401C \
    --scheme MyApp \
    --configuration Release
```

### Execution Options

| Option | Description |
|--------|-------------|
| `--max-attempts <n>` | Max repair attempts before escalation (default: 3) |
| `--artifacts-dir <dir>` | Output directory for logs and status (default: `Artifacts/`) |
| `--stream` | Stream Cursor CLI and build output in real-time |
| `--dry-run` | Show what would be done without executing |
| `--verbose` | Enable verbose output |
| `--help` | Show help message |

**Note:** By default, BuildAgent shows a spinner animation while working. Use `--stream` to see the full output from Cursor CLI and xcodebuild in real-time.

### Exit Codes

| Code | Meaning |
|------|---------|
| `0` | Success - build passed |
| `10` | Build failed after max retries |
| `11` | Misconfiguration (missing inputs, invalid paths) |
| `20` | Human intervention required |

### Output Artifacts

After running, artifacts are written to `Artifacts/build_<timestamp>/`:

```
Artifacts/build_20241218_120000/
├── logs/
│   ├── session_context.md        # Session history (all attempts tracked)
│   ├── build.log                 # Success log with analytics
│   ├── error_attempt_1.log       # Error from attempt 1
│   ├── error_attempt_2.log       # Error from attempt 2
│   ├── coder_attempt_1.log       # Cursor CLI output attempt 1
│   ├── coder_attempt_2.log       # Cursor CLI output attempt 2
│   ├── prompt_attempt_1.txt      # Full initial prompt (with context)
│   ├── prompt_attempt_2.txt      # Follow-up prompt (error feedback only)
│   ├── buildlint_attempt_1.log   # BuildLint.sh output
│   ├── xcodebuild_raw.log        # Raw xcodebuild output
│   └── swiftlint_output.txt      # SwiftLint results (if applicable)
└── status/
    ├── success.txt               # On successful build
    └── human_intervention.md     # When manual fix needed
```

---

## BuildLint.sh

Handles linting and Xcode build verification.

### Quick Start

```bash
# Build with auto-detected project and scheme
./BuildLint.sh

# Build for specific device
./BuildLint.sh --target-id 00008150-001D5822210A401C --scheme MyApp

# Build for simulator
./BuildLint.sh --destination "platform=iOS Simulator,name=iPhone 16"
```

### Options

| Option | Description |
|--------|-------------|
| `--target-id <id>` | Device/Simulator UDID |
| `--destination <dest>` | Full destination string |
| `--scheme <scheme>` | Xcode scheme to build |
| `--project <path>` | Path to `.xcodeproj` |
| `--workspace <path>` | Path to `.xcworkspace` |
| `--configuration <cfg>` | Build configuration (default: `Debug`) |
| `--derived-data <path>` | Custom DerivedData path |
| `--artifacts-dir <dir>` | Output directory for logs |
| `--skip-lint` | Skip SwiftLint on uncommitted files |
| `--verbose` | Enable verbose output |
| `--help` | Show help message |

### Exit Codes

| Code | Meaning |
|------|---------|
| `0` | Success |
| `10` | Build or lint failed |
| `11` | Misconfiguration |

### Output

- `logs/build.log` - On success, contains build analytics (duration, warnings count)
- `logs/error.log` - On failure, contains error details and failing command

---

## Context & Repair Loop

BuildAgent maintains context between repair attempts:

1. **First attempt**: Full prompt with task + all context (plan, Swift docs, reference files)
2. **Follow-up attempts**: Original task + context + error feedback from the failed build
3. **Smart retries**: Each attempt includes what went wrong, encouraging different approaches

**Session tracking artifacts:**
- `logs/session_context.md` - Tracks all attempts and their outcomes
- `logs/prompt_attempt_N.txt` - The actual prompt sent for each attempt
- `logs/error_attempt_N.log` - Build errors from each failed attempt

---

## Workflow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                      BuildAgent.sh                          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Input (plan.md / prompt.txt / stdin)                       │
│         +                                                   │
│  Context (MD files + Swift docs)                            │
│         ↓                                                   │
│  ┌─────────────────────────────────────┐                    │
│  │   Cursor CLI                        │                    │
│  │   [⠹] Generating code...            │                    │
│  └────────────────┬────────────────────┘                    │
│                   ↓                                         │
│  ┌─────────────────┐                                        │
│  │  BuildLint.sh   │ ← Lint + xcodebuild                    │
│  │  [⠧] Building..│                                        │
│  └────────┬────────┘                                        │
│           ↓                                                 │
│     ┌─────┴─────┐                                           │
│     ↓           ↓                                           │
│  [PASS]      [FAIL]                                         │
│     ↓           ↓                                           │
│  success    ┌───────────────────────────┐                   │
│   .txt      │ Retry with:               │                   │
│             │ • Original task           │──→ (max 3x)       │
│             │ • Context                 │                   │
│             │ • Error feedback          │                   │
│             └───────────────────────────┘                   │
│                           ↓                                 │
│                    [Still failing]                          │
│                           ↓                                 │
│                  human_intervention.md                      │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## Examples

### Example 1: Implement a Feature from Plan

```bash
./BuildAgent.sh \
    --plan Plans/plan1/plan1.md \
    --context Guides/ \
    --scheme MyApp \
    --verbose
```

### Example 2: Quick Fix with Prompt

```bash
./BuildAgent.sh \
    --prompt-string "Fix the crash in UserProfileView when user is nil" \
    --scheme MyApp \
    --max-attempts 5
```

### Example 3: Build for Physical Device

```bash
./BuildAgent.sh \
    --plan plan.md \
    --target-id 00008150-001D5822210A401C \
    --scheme MyApp \
    --configuration Release
```

### Example 4: Dry Run to Preview

```bash
./BuildAgent.sh \
    --plan plan.md \
    --scheme MyApp \
    --dry-run \
    --verbose
```

### Example 5: Pipe Prompt from Another Command

```bash
cat << 'EOF' | ./BuildAgent.sh --stdin --scheme MyApp
Implement a dark mode toggle in SettingsView:
1. Add a toggle switch bound to UserDefaults
2. Apply the color scheme to the app's root view
3. Persist the preference across app launches
EOF
```

---

## Requirements

- **Cursor CLI**: Install from [cursor.sh](https://cursor.sh)
- **Xcode**: Command line tools installed (`xcode-select --install`)
- **SwiftLint** (optional): `brew install swiftlint`

---

## Troubleshooting

### "Cursor CLI not found"
Install Cursor and ensure the CLI is in your PATH:
```bash
which cursor
```

### "No Xcode project or workspace found"
Ensure you're running from the project root or specify paths:
```bash
./BuildAgent.sh --workspace MyApp.xcworkspace --scheme MyApp --plan plan.md
```

### "Human intervention required"
Check `status/human_intervention.md` for:
- Error history from all attempts
- Recommendations for manual fixes
- Links to relevant log files

---

## Related Documentation

- [Phase 5 Additions Draft](../../../Guides/phase_5_additions_draft_for_the_constitution.md)
- [Foundation Constitution](../../Foundation-constitution/Foundation-Constitution.pdf)
