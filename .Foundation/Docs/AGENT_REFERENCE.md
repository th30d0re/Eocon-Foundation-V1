# Agent Reference Guide

Complete reference for all Eocon Foundation agents with flags, features, and examples.

## Table of Contents

- [Shell Requirements](#shell-requirements)
- [BuildAgent](#buildagent)
- [BuildLint](#buildlint)
- [testRunner](#testrunner)
- [uiTestAgent](#uitestagent)
- [accessibilityAgent](#accessibilityagent)
- [flowAgent](#flowagent)
- [Common Flags](#common-flags)
- [Session Integration](#session-integration)

---

## Shell Requirements

All Foundation agents and libraries require **bash 3.2 or later** to run. Bash 4.0+ is recommended for full feature compatibility.

### Minimum Requirements

- **Bash Version**: 3.2+ (macOS default), 4.0+ recommended
- **Shebang**: All scripts use `#!/usr/bin/env bash` for portability
- **Execution**: Scripts must be executed (not sourced from non-bash shells)

### Bash Version Check

All main agents automatically check bash compatibility at startup. If you encounter shell compatibility errors:

```bash
# Check your current bash version
bash --version

# On macOS, install newer bash via Homebrew (recommended)
brew install bash

# Run script with explicit bash path
/usr/local/bin/bash BuildAgent.sh --help
```

### macOS Users

macOS ships with bash 3.2 by default (due to licensing). While this version works, some features have limitations:

- ✅ **Works**: All core functionality, basic arrays, parameter expansion
- ⚠️ **Limited**: Associative arrays (bash 4.0+), `readarray`/`mapfile` (bash 4.0+)
- 💡 **Recommended**: Install bash 4.0+ via Homebrew for full compatibility

### Compatibility Features

- **Automatic Detection**: Scripts detect bash version and warn if features may be limited
- **Graceful Degradation**: Core functionality works on bash 3.2 with warnings
- **Clear Error Messages**: Non-bash execution provides instructions to use bash
- **Portable Shebangs**: `#!/usr/bin/env bash` ensures scripts find bash in any environment

### Troubleshooting

**Error: "This script requires bash"**
```bash
# You're running the script in a different shell (zsh, sh, etc.)
# Solution: Execute with bash explicitly
bash BuildAgent.sh --help
```

**Warning: "Running on bash 3.x"**
```bash
# You're using macOS default bash (3.2)
# Solution: Install newer bash (optional but recommended)
brew install bash
/usr/local/bin/bash BuildAgent.sh --help
```

**Script fails with "command not found"**
```bash
# Script might not have execute permissions
# Solution: Add execute permission or use bash explicitly
chmod +x BuildAgent.sh
./BuildAgent.sh --help

# Or run with bash directly
bash BuildAgent.sh --help
```

For more details, see [Shell Compatibility Guide](SHELL_COMPATIBILITY.md).

---

## BuildAgent

**Purpose**: Primary build orchestration agent with incremental build support and MCP integration.

**Location**: `.Foundation/Agents/phases/phase5/BuildAgent.sh`

### Flags

#### Required Flags (or from session defaults)

| Flag | Type | Description | Example |
|------|------|-------------|---------|
| `--scheme <name>` | string | Xcode scheme to build | `--scheme MyApp` |
| `--simulator-name <name>` | string | Target simulator | `--simulator-name "iPhone 15 Pro"` |

#### Optional Flags

| Flag | Type | Default | Description |
|------|------|---------|-------------|
| `--platform <platform>` | string | iOS | Target platform (iOS, macOS, tvOS, watchOS, visionOS) |
| `--enable-incremental` | boolean | false | Use xcodemake for incremental builds |
| `--capture-logs` | boolean | false | Capture build logs for analysis |
| `--auto-simulator` | boolean | false | Auto-boot simulator if not running |
| `--no-auto-simulator` | boolean | false | Disable auto-boot |
| `--no-capture-logs` | boolean | false | Disable log capture |
| `--clean` | boolean | false | Clean before build |
| `--configuration <config>` | string | Debug | Build configuration (Debug/Release) |
| `--destination <dest>` | string | auto | Custom xcodebuild destination |
| `--log-level <level>` | string | info | Logging verbosity (debug, info, warn, error) |

#### Session Management

| Flag | Description |
|------|-------------|
| `--save-session-defaults` | Save current flags as session defaults |
| `--use-session-defaults` | Use saved session defaults (default: true) |
| `--no-session-defaults` | Ignore session defaults |
| `--show-session-defaults` | Display current session defaults |
| `--clear-session-defaults` | Clear all session defaults |

### Features

- **Incremental Builds**: Automatically uses xcodemake when `--enable-incremental` is set
- **Smart Simulator Management**: Auto-boots simulators based on `--auto-simulator`
- **Log Capture**: Streams logs to files when `--capture-logs` is enabled
- **Session Persistence**: Remembers your build configuration
- **Multi-Platform**: Supports all Apple platforms via `--platform`
- **MCP Integration**: Exposes build capabilities to AI models

### Examples

#### Basic Build

```bash
./BuildAgent.sh --scheme MyApp --simulator-name "iPhone 15 Pro"
```

#### Incremental Build with Log Capture

```bash
./BuildAgent.sh \
  --scheme MyApp \
  --simulator-name "iPhone 15 Pro" \
  --enable-incremental \
  --capture-logs \
  --auto-simulator
```

#### Save Session Defaults

```bash
./BuildAgent.sh \
  --save-session-defaults \
  --scheme MyApp \
  --simulator-name "iPhone 15 Pro" \
  --platform iOS \
  --enable-incremental \
  --auto-simulator
```

#### Use Session Defaults

```bash
# After saving session defaults, simply run:
./BuildAgent.sh
```

#### Multi-Platform Build

```bash
./BuildAgent.sh --scheme MyApp --platform macOS
./BuildAgent.sh --scheme MyApp --platform visionOS --simulator-name "Apple Vision Pro"
```

#### Clean Build

```bash
./BuildAgent.sh --scheme MyApp --clean
```

---

## BuildLint

**Purpose**: Build analysis and linting agent with macro validation and code quality checks.

**Location**: `.Foundation/Agents/phases/phase5/BuildLint.sh`

### Flags

| Flag | Type | Default | Description |
|------|------|---------|-------------|
| `--scheme <name>` | string | required | Xcode scheme to analyze |
| `--check-macros` | boolean | false | Validate Swift macros |
| `--analyze` | boolean | false | Run static analysis |
| `--output <format>` | string | text | Output format (text, json, xml) |
| `--fail-on-warnings` | boolean | false | Treat warnings as errors |

### Examples

```bash
# Basic lint
./BuildLint.sh --scheme MyApp

# With macro validation
./BuildLint.sh --scheme MyApp --check-macros

# Full analysis
./BuildLint.sh --scheme MyApp --analyze --fail-on-warnings
```

---

## testRunner

**Purpose**: Comprehensive test execution agent with simulator automation and log streaming.

**Location**: `.Foundation/Agents/phases/phase5/testRunner.sh`

### Flags

#### Test Selection

| Flag | Type | Description |
|------|------|-------------|
| `--scheme <name>` | string | Xcode scheme containing tests |
| `--test-plan <name>` | string | Specific test plan to run |
| `--only <test>` | string | Run specific test (class or method) |
| `--skip <test>` | string | Skip specific test |

#### Test Configuration

| Flag | Type | Default | Description |
|------|------|---------|-------------|
| `--parallel` | boolean | false | Run tests in parallel |
| `--repeat <n>` | integer | 1 | Repeat tests n times |
| `--randomize` | boolean | false | Randomize test order |
| `--simulator-name <name>` | string | required | Target simulator |
| `--platform <platform>` | string | iOS | Target platform |

#### Logging and Analysis

| Flag | Type | Default | Description |
|------|------|---------|-------------|
| `--capture-logs` | boolean | true | Capture test logs |
| `--code-coverage` | boolean | false | Enable code coverage |
| `--result-bundle` | boolean | true | Generate result bundle |
| `--auto-simulator` | boolean | true | Auto-boot simulator |

### Examples

#### Run All Tests

```bash
./testRunner.sh --scheme MyApp --simulator-name "iPhone 15 Pro"
```

#### Run Specific Test

```bash
./testRunner.sh \
  --scheme MyApp \
  --simulator-name "iPhone 15 Pro" \
  --only MyAppTests/testLogin
```

#### Parallel Tests with Coverage

```bash
./testRunner.sh \
  --scheme MyApp \
  --simulator-name "iPhone 15 Pro" \
  --parallel \
  --code-coverage
```

#### Stress Test

```bash
./testRunner.sh \
  --scheme MyApp \
  --simulator-name "iPhone 15 Pro" \
  --repeat 10 \
  --randomize
```

---

## uiTestAgent

**Purpose**: UI test automation with AXe integration and flow-based testing.

**Location**: `.Foundation/Agents/phases/phase5/uiTestAgent.sh`

### Flags

| Flag | Type | Default | Description |
|------|------|---------|-------------|
| `--scheme <name>` | string | required | Xcode scheme with UI tests |
| `--simulator-name <name>` | string | required | Target simulator |
| `--flow-file <path>` | string | - | Path to flow definition JSON |
| `--generate-flows` | boolean | false | Auto-generate flow definitions |
| `--capture-screenshots` | boolean | true | Capture screenshots on failure |
| `--use-axe` | boolean | true | Enable AXe integration |
| `--auto-simulator` | boolean | true | Auto-boot simulator |

### Examples

#### Run UI Tests

```bash
./uiTestAgent.sh \
  --scheme MyApp \
  --simulator-name "iPhone 15 Pro"
```

#### Flow-Based Testing

```bash
./uiTestAgent.sh \
  --scheme MyApp \
  --simulator-name "iPhone 15 Pro" \
  --flow-file flows/login-flow.json
```

#### Generate Flow Definitions

```bash
./uiTestAgent.sh \
  --scheme MyApp \
  --simulator-name "iPhone 15 Pro" \
  --generate-flows
```

---

## accessibilityAgent

**Purpose**: Accessibility auditing and validation using AXe.

**Location**: `.Foundation/Agents/phases/phase5/accessibilityAgent.sh`

### Flags

| Flag | Type | Default | Description |
|------|------|---------|-------------|
| `--simulator-name <name>` | string | required | Target simulator (must be running) |
| `--bundle-id <id>` | string | required | App bundle identifier |
| `--audit-type <type>` | string | full | Audit type (full, quick, targeted) |
| `--check-touch-targets` | boolean | true | Validate touch target sizes |
| `--check-labels` | boolean | true | Validate accessibility labels |
| `--check-identifiers` | boolean | true | Validate accessibility identifiers |
| `--output <format>` | string | json | Output format (json, html, text) |

### Examples

#### Full Accessibility Audit

```bash
./accessibilityAgent.sh \
  --simulator-name "iPhone 15 Pro" \
  --bundle-id com.example.MyApp
```

#### Quick Audit

```bash
./accessibilityAgent.sh \
  --simulator-name "iPhone 15 Pro" \
  --bundle-id com.example.MyApp \
  --audit-type quick
```

#### Touch Target Validation

```bash
./accessibilityAgent.sh \
  --simulator-name "iPhone 15 Pro" \
  --bundle-id com.example.MyApp \
  --check-touch-targets \
  --output html
```

---

## flowAgent

**Purpose**: Flow-based testing and validation agent.

**Location**: `.Foundation/Agents/phases/phase5/flowAgent.sh`

### Flags

| Flag | Type | Description |
|------|------|-------------|
| `--flow-file <path>` | string | Path to flow definition |
| `--validate` | boolean | Validate flow without running |
| `--generate-tests` | boolean | Generate XCTest code from flow |
| `--simulator-name <name>` | string | Target simulator |

### Examples

```bash
# Validate flow
./flowAgent.sh --flow-file flows/checkout.json --validate

# Generate tests
./flowAgent.sh --flow-file flows/checkout.json --generate-tests

# Run flow
./flowAgent.sh \
  --flow-file flows/checkout.json \
  --simulator-name "iPhone 15 Pro"
```

---

## Common Flags

These flags are available across most agents:

| Flag | Description |
|------|-------------|
| `--help, -h` | Show help message |
| `--version` | Show agent version |
| `--verbose, -v` | Enable verbose output |
| `--quiet, -q` | Suppress non-essential output |
| `--dry-run` | Show what would be done without doing it |

---

## Session Integration

All agents integrate with the session management system, allowing you to save and reuse common configurations.

### Session File Location

`~/.eocon-session-defaults.json`

### Session Schema

```json
{
  "version": "3.0",
  "scheme": "MyApp",
  "simulator_name": "iPhone 15 Pro",
  "platform": "iOS",
  "enable_incremental": true,
  "auto_simulator": true,
  "capture_logs": true,
  "configuration": "Debug"
}
```

### Session Flag Precedence

1. **Command-line flags** (highest priority)
2. **Environment variables**
3. **Configuration file** (`defaults.conf`)
4. **Session defaults**
5. **Built-in defaults** (lowest priority)

### Example Session Workflow

```bash
# 1. Save session defaults
./BuildAgent.sh --save-session-defaults \
  --scheme MyApp \
  --simulator-name "iPhone 15 Pro" \
  --enable-incremental \
  --auto-simulator

# 2. Use defaults in any agent
./BuildAgent.sh  # Uses session defaults
./testRunner.sh  # Uses session defaults
./uiTestAgent.sh  # Uses session defaults

# 3. Override specific flags
./testRunner.sh --parallel  # Uses session defaults + parallel flag

# 4. Show current defaults
./BuildAgent.sh --show-session-defaults

# 5. Clear defaults
./BuildAgent.sh --clear-session-defaults
```

---

## See Also

- [Flags Reference](FLAGS_REFERENCE.md) - Detailed flag documentation
- [Workflow Examples](WORKFLOW_EXAMPLES.md) - Practical usage examples
- [Features](FEATURES.md) - Feature documentation
- [Troubleshooting](TROUBLESHOOTING.md) - Common issues

---

**Last Updated**: January 2026  
**Version**: 3.0
