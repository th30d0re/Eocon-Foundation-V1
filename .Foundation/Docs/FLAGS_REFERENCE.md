# Flags Reference

Complete reference for all flags across Eocon Foundation agents.

## Table of Contents

- [Build Flags](#build-flags)
- [Test Flags](#test-flags)
- [UI Flags](#ui-flags)
- [Session Flags](#session-flags)
- [Platform Flags](#platform-flags)
- [Logging Flags](#logging-flags)
- [Opt-Out Flags](#opt-out-flags)
- [Common Flags](#common-flags)

---

## Build Flags

Flags for controlling build behavior.

### --scheme <name>

**Type**: String (required or from session)  
**Description**: Xcode scheme to build  
**Example**: `--scheme MyApp`  
**Agents**: BuildAgent, BuildLint, testRunner, uiTestAgent

### --configuration <config>

**Type**: String  
**Default**: `Debug`  
**Description**: Build configuration  
**Values**: `Debug`, `Release`, custom  
**Example**: `--configuration Release`  
**Agents**: BuildAgent, testRunner

### --enable-incremental

**Type**: Boolean  
**Default**: `false`  
**Description**: Enable xcodemake incremental builds  
**Example**: `--enable-incremental`  
**Agents**: BuildAgent  
**Requires**: xcodemake installed

### --clean

**Type**: Boolean  
**Default**: `false`  
**Description**: Clean before building  
**Example**: `--clean`  
**Agents**: BuildAgent

### --destination <dest>

**Type**: String  
**Default**: Auto-generated  
**Description**: Custom xcodebuild destination  
**Example**: `--destination "platform=iOS,name=My iPhone"`  
**Agents**: BuildAgent, testRunner, uiTestAgent

---

## Test Flags

Flags specific to testing.

### --test-plan <name>

**Type**: String  
**Default**: Default test plan  
**Description**: Specific test plan to run  
**Example**: `--test-plan "Regression Tests"`  
**Agents**: testRunner, uiTestAgent

### --only <test>

**Type**: String  
**Default**: Run all tests  
**Description**: Run specific test class or method  
**Example**: `--only MyAppTests/testLogin`  
**Agents**: testRunner, uiTestAgent

### --skip <test>

**Type**: String  
**Default**: None  
**Description**: Skip specific test class or method  
**Example**: `--skip MyAppTests/testSlowTest`  
**Agents**: testRunner, uiTestAgent

### --parallel

**Type**: Boolean  
**Default**: `false`  
**Description**: Run tests in parallel  
**Example**: `--parallel`  
**Agents**: testRunner, uiTestAgent

### --repeat <n>

**Type**: Integer  
**Default**: `1`  
**Description**: Repeat tests n times  
**Example**: `--repeat 10`  
**Agents**: testRunner

### --randomize

**Type**: Boolean  
**Default**: `false`  
**Description**: Randomize test execution order  
**Example**: `--randomize`  
**Agents**: testRunner

### --code-coverage

**Type**: Boolean  
**Default**: `false`  
**Description**: Enable code coverage collection  
**Example**: `--code-coverage`  
**Agents**: testRunner, uiTestAgent

### --result-bundle

**Type**: Boolean  
**Default**: `true`  
**Description**: Generate .xcresult bundle  
**Example**: `--result-bundle`  
**Agents**: testRunner, uiTestAgent

---

## UI Flags

Flags for UI testing and accessibility.

### --flow-file <path>

**Type**: String (file path)  
**Default**: None  
**Description**: Path to flow definition JSON  
**Example**: `--flow-file flows/login-flow.json`  
**Agents**: uiTestAgent, flowAgent

### --generate-flows

**Type**: Boolean  
**Default**: `false`  
**Description**: Auto-generate flow definitions from UI  
**Example**: `--generate-flows`  
**Agents**: uiTestAgent

### --capture-screenshots

**Type**: Boolean  
**Default**: `true`  
**Description**: Capture screenshots on test failure  
**Example**: `--capture-screenshots`  
**Agents**: uiTestAgent

### --use-axe

**Type**: Boolean  
**Default**: `true` (if AXe available)  
**Description**: Enable AXe UI automation  
**Example**: `--use-axe`  
**Agents**: uiTestAgent, accessibilityAgent  
**Requires**: AXe installed

### --bundle-id <id>

**Type**: String (bundle identifier)  
**Default**: None (required for accessibility)  
**Description**: App bundle identifier  
**Example**: `--bundle-id com.example.MyApp`  
**Agents**: accessibilityAgent

### --audit-type <type>

**Type**: String  
**Default**: `full`  
**Description**: Accessibility audit scope  
**Values**: `full`, `quick`, `targeted`  
**Example**: `--audit-type quick`  
**Agents**: accessibilityAgent

### --check-touch-targets

**Type**: Boolean  
**Default**: `true`  
**Description**: Validate touch target sizes (44x44pt minimum)  
**Example**: `--check-touch-targets`  
**Agents**: accessibilityAgent

### --check-labels

**Type**: Boolean  
**Default**: `true`  
**Description**: Validate accessibility labels  
**Example**: `--check-labels`  
**Agents**: accessibilityAgent

### --check-identifiers

**Type**: Boolean  
**Default**: `true`  
**Description**: Validate accessibility identifiers  
**Example**: `--check-identifiers`  
**Agents**: accessibilityAgent

---

## Session Flags

Flags for session management.

### --save-session-defaults

**Type**: Boolean  
**Default**: `false`  
**Description**: Save current flags as session defaults  
**Example**: `--save-session-defaults --scheme MyApp`  
**Agents**: All agents  
**File**: `~/.eocon-session-defaults.json`

### --use-session-defaults

**Type**: Boolean  
**Default**: `true`  
**Description**: Load and use saved session defaults  
**Example**: `--use-session-defaults`  
**Agents**: All agents

### --no-session-defaults

**Type**: Boolean  
**Default**: `false`  
**Description**: Ignore session defaults  
**Example**: `--no-session-defaults`  
**Agents**: All agents

### --show-session-defaults

**Type**: Boolean  
**Default**: `false`  
**Description**: Display current session defaults and exit  
**Example**: `--show-session-defaults`  
**Agents**: All agents

### --clear-session-defaults

**Type**: Boolean  
**Default**: `false`  
**Description**: Clear all session defaults  
**Example**: `--clear-session-defaults`  
**Agents**: All agents

---

## Platform Flags

Flags for platform and simulator selection.

### --platform <platform>

**Type**: String  
**Default**: `iOS`  
**Description**: Target platform  
**Values**: `iOS`, `macOS`, `tvOS`, `watchOS`, `visionOS`  
**Example**: `--platform visionOS`  
**Agents**: BuildAgent, testRunner, uiTestAgent

### --simulator-name <name>

**Type**: String  
**Default**: None (required for simulators)  
**Description**: Target simulator device name  
**Example**: `--simulator-name "iPhone 15 Pro"`  
**Agents**: BuildAgent, testRunner, uiTestAgent, accessibilityAgent

### --auto-simulator

**Type**: Boolean  
**Default**: `false`  
**Description**: Auto-boot simulator if not running  
**Example**: `--auto-simulator`  
**Agents**: BuildAgent, testRunner, uiTestAgent

### --no-auto-simulator

**Type**: Boolean  
**Default**: `false`  
**Description**: Disable auto-boot simulator  
**Example**: `--no-auto-simulator`  
**Agents**: BuildAgent, testRunner, uiTestAgent

---

## Logging Flags

Flags for log capture and verbosity.

### --capture-logs

**Type**: Boolean  
**Default**: `false`  
**Description**: Enable structured log capture  
**Example**: `--capture-logs`  
**Agents**: BuildAgent, testRunner, uiTestAgent  
**Output**: `logs/*.log`, `logs/*.json`

### --no-capture-logs

**Type**: Boolean  
**Default**: `false`  
**Description**: Disable log capture  
**Example**: `--no-capture-logs`  
**Agents**: BuildAgent, testRunner, uiTestAgent

### --log-level <level>

**Type**: String  
**Default**: `info`  
**Description**: Logging verbosity  
**Values**: `debug`, `info`, `warn`, `error`  
**Example**: `--log-level debug`  
**Agents**: All agents

### --output <format>

**Type**: String  
**Default**: `text`  
**Description**: Output format  
**Values**: `text`, `json`, `xml`, `html`  
**Example**: `--output json`  
**Agents**: BuildLint, accessibilityAgent

---

## Opt-Out Flags

Flags to disable specific features.

### --no-auto-simulator

Disable automatic simulator booting.

**Alternative**: `--auto-simulator` set to false in session defaults

### --no-capture-logs

Disable log capture and streaming.

**Alternative**: `--capture-logs` set to false in session defaults

### --no-session-defaults

Ignore saved session defaults.

**Use Case**: Testing with different configuration without modifying session

### --quiet, -q

Suppress non-essential output.

**Example**: `--quiet` or `-q`  
**Agents**: All agents

---

## Common Flags

Flags available in all agents.

### --help, -h

**Type**: Boolean  
**Description**: Show help message and exit  
**Example**: `--help` or `-h`  
**Agents**: All agents

### --version

**Type**: Boolean  
**Description**: Show agent version and exit  
**Example**: `--version`  
**Agents**: All agents

### --verbose, -v

**Type**: Boolean  
**Default**: `false`  
**Description**: Enable verbose output  
**Example**: `--verbose` or `-v`  
**Agents**: All agents

### --quiet, -q

**Type**: Boolean  
**Default**: `false`  
**Description**: Suppress non-essential output  
**Example**: `--quiet` or `-q`  
**Agents**: All agents

### --dry-run

**Type**: Boolean  
**Default**: `false`  
**Description**: Show what would be done without doing it  
**Example**: `--dry-run`  
**Agents**: Most agents

---

## Flag Precedence

When the same flag is specified multiple ways, this is the priority order:

1. **Command-line flags** ← Highest priority
2. **Environment variables**
3. **Configuration file** (`defaults.conf`)
4. **Session defaults** (`~/.eocon-session-defaults.json`)
5. **Built-in defaults** ← Lowest priority

### Example

```bash
# Session defaults say: --platform iOS
# defaults.conf says: --platform macOS
# Command-line says: --platform visionOS

./BuildAgent.sh --platform visionOS
# Result: Uses visionOS (command-line wins)

./BuildAgent.sh
# Result: Uses macOS (defaults.conf wins over session defaults)
```

---

## Flag Combinations

### Recommended Combinations

#### Fast Development

```bash
--enable-incremental \
--auto-simulator \
--capture-logs
```

#### CI/CD

```bash
--clean \
--code-coverage \
--result-bundle \
--parallel
```

#### Accessibility Testing

```bash
--use-axe \
--check-touch-targets \
--check-labels \
--check-identifiers \
--audit-type full
```

#### Debugging

```bash
--verbose \
--capture-logs \
--log-level debug
```

### Conflicting Flags

These flag combinations conflict or are redundant:

| Flag 1 | Flag 2 | Result |
|--------|--------|--------|
| `--auto-simulator` | `--no-auto-simulator` | Last one wins |
| `--capture-logs` | `--no-capture-logs` | Last one wins |
| `--use-session-defaults` | `--no-session-defaults` | Last one wins |
| `--verbose` | `--quiet` | Last one wins |

---

## Environment Variable Equivalents

Many flags can be set via environment variables:

| Flag | Environment Variable | Example |
|------|---------------------|---------|
| `--enable-incremental` | `BUILDAGENT_INCREMENTAL=true` | `export BUILDAGENT_INCREMENTAL=true` |
| `--auto-simulator` | `BUILDAGENT_AUTO_SIMULATOR=true` | `export BUILDAGENT_AUTO_SIMULATOR=true` |
| `--capture-logs` | `BUILDAGENT_CAPTURE_LOGS=true` | `export BUILDAGENT_CAPTURE_LOGS=true` |
| `--log-level <level>` | `BUILDAGENT_LOG_LEVEL=debug` | `export BUILDAGENT_LOG_LEVEL=debug` |
| `--platform <platform>` | `BUILDAGENT_PLATFORM=iOS` | `export BUILDAGENT_PLATFORM=iOS` |

---

## See Also

- [Agent Reference](AGENT_REFERENCE.md) - Detailed agent documentation
- [Workflow Examples](WORKFLOW_EXAMPLES.md) - Flag usage examples
- [Features](FEATURES.md) - Feature descriptions
- [Session Management](FEATURES.md#session-management) - Session defaults

---

**Last Updated**: January 2026  
**Version**: 3.0  
**Total Flags**: 40+
