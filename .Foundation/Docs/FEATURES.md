# Features Documentation

Comprehensive guide to Eocon Foundation Build System features.

## Table of Contents

- [Incremental Builds](#incremental-builds)
- [Multi-Platform Support](#multi-platform-support)
- [Session Management](#session-management)
- [Log Streaming](#log-streaming)
- [UI Automation](#ui-automation)
- [Simulator Management](#simulator-management)
- [Fancy UI System](#fancy-ui-system)
- [MCP Integration](#mcp-integration)

---

## Incremental Builds

**Speed up your rebuild times by up to 10x** with intelligent caching and incremental compilation.

### Overview

Incremental builds use **xcodemake** to track file changes and rebuild only what's necessary, dramatically reducing build times for iterative development.

### Benefits

- ⚡ **10x faster rebuilds** - Only changed files recompile
- 💾 **Smart caching** - Dependency graph analysis
- 🔄 **Automatic detection** - Knows what needs rebuilding
- 🎯 **Zero configuration** - Works out of the box

### Usage

```bash
# Enable incremental builds
./BuildAgent.sh --enable-incremental --scheme MyApp

# Save as default
./BuildAgent.sh --save-session-defaults \
  --scheme MyApp \
  --enable-incremental
```

### Performance Comparison

| Scenario | Regular Build | Incremental Build |
|----------|--------------|-------------------|
| Full rebuild | 120s | 120s |
| One file change | 120s | ~12s (10x faster) |
| Few files changed | 120s | ~25s (5x faster) |
| Many files changed | 120s | ~60s (2x faster) |

### How It Works

1. **First Build**: xcodemake analyzes your project and creates a dependency graph
2. **File Change Detection**: Monitors changed files since last build
3. **Smart Rebuild**: Compiles only affected files and their dependents
4. **Cache Management**: Maintains build artifacts for reuse

### Requirements

- xcodemake installed (via `setup.sh` or brew)
- Xcode project (not SPM)
- macOS 12.0+

### Limitations

- First build always full (creates cache)
- Clean builds ignore cache
- Works best with modular code

---

## Multi-Platform Support

**Build and test across all Apple platforms** from a unified interface.

### Supported Platforms

| Platform | Availability | Example Device |
|----------|-------------|----------------|
| **iOS** | ✅ | iPhone 15 Pro |
| **macOS** | ✅ | Mac (My Mac) |
| **tvOS** | ✅ | Apple TV 4K |
| **watchOS** | ✅ | Apple Watch Series 9 |
| **visionOS** | ✅ | Apple Vision Pro |

### Usage

```bash
# iOS (default)
./BuildAgent.sh --scheme MyApp --platform iOS

# macOS
./BuildAgent.sh --scheme MyApp --platform macOS

# visionOS
./BuildAgent.sh --scheme MyApp --platform visionOS \
  --simulator-name "Apple Vision Pro"

# tvOS
./BuildAgent.sh --scheme MyApp --platform tvOS \
  --simulator-name "Apple TV"

# watchOS (requires paired iPhone simulator)
./BuildAgent.sh --scheme MyApp --platform watchOS \
  --simulator-name "Apple Watch Series 9 (45mm)"
```

### Platform Detection

The system automatically:
- Detects available simulators per platform
- Selects appropriate SDK
- Configures build settings
- Validates platform compatibility

### Cross-Platform Workflows

```bash
# Test on all platforms
for platform in iOS macOS visionOS; do
  ./testRunner.sh --scheme MyApp --platform $platform
done

# Build universal binary
./BuildAgent.sh --scheme MyApp --platform macOS \
  --destination "generic/platform=macOS"
```

---

## Session Management

**Save and reuse build configurations** to eliminate repetitive flag specifications.

### Overview

Session management persists your build configuration across invocations, allowing you to run builds with minimal flags.

### Session Storage

**Location**: `~/.eocon-session-defaults.json`

**Format**:
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

### Usage

```bash
# Save session defaults
./BuildAgent.sh --save-session-defaults \
  --scheme MyApp \
  --simulator-name "iPhone 15 Pro" \
  --enable-incremental \
  --auto-simulator

# Use saved defaults (automatic)
./BuildAgent.sh

# Show current defaults
./BuildAgent.sh --show-session-defaults

# Override specific flag
./BuildAgent.sh --configuration Release

# Ignore session defaults
./BuildAgent.sh --no-session-defaults --scheme OtherApp

# Clear saved defaults
./BuildAgent.sh --clear-session-defaults
```

### Flag Precedence

When multiple sources provide the same flag:

1. **Command-line flags** (highest priority)
2. **Environment variables**
3. **Configuration file** (`defaults.conf`)
4. **Session defaults**
5. **Built-in defaults** (lowest priority)

### Multi-Project Workflow

```bash
# Project 1
cd Project1
.Foundation/Agents/phases/phase5/BuildAgent.sh --save-session-defaults \
  --scheme Project1 --simulator-name "iPhone 15 Pro"

# Project 2
cd ../Project2
.Foundation/Agents/phases/phase5/BuildAgent.sh --save-session-defaults \
  --scheme Project2 --simulator-name "iPad Pro"

# Each project uses its own defaults when you're in that directory
```

---

## Log Streaming

**Real-time log capture and analysis** for debugging and AI consumption.

### Overview

Structured logging captures build output, test results, and runtime logs in machine-readable formats for analysis.

### Features

- 📊 **Structured Logging** - JSON and plain text formats
- 🔴 **Real-time Streaming** - Watch logs as they happen
- 💾 **Persistent Storage** - Logs saved for later analysis
- 🤖 **AI-Ready** - Formatted for AI model consumption

### Usage

```bash
# Enable log capture
./BuildAgent.sh --capture-logs --scheme MyApp

# Logs saved to:
# - logs/build-output.log (plain text)
# - logs/build-output.json (structured)
# - logs/xcodebuild-TIMESTAMP.log (raw xcodebuild)

# View logs in real-time
tail -f logs/build-output.log

# Parse structured logs
cat logs/build-output.json | jq '.errors'
```

### Log Types

| Type | File | Format | Purpose |
|------|------|--------|---------|
| **Build** | `build-output.log` | Plain | Human-readable build output |
| **Test** | `test-results.log` | Plain | Test execution results |
| **Structured** | `*.json` | JSON | Machine parsing |
| **Raw** | `xcodebuild-*.log` | Raw | Full xcodebuild output |
| **Runtime** | `runtime-*.log` | Plain | App runtime logs |

### Configuration

```bash
# Set custom log directory
export BUILDAGENT_LOG_DIR="$HOME/my-logs"

# Set log level
./BuildAgent.sh --log-level debug  # debug, info, warn, error

# Disable log capture
./BuildAgent.sh --no-capture-logs
```

### AI Integration

```
AI Prompt: "Analyze the build failure"

AI Actions:
1. Reads logs/build-output.json
2. Identifies error: "Missing dependency: Alamofire"
3. Suggests: "Add Alamofire to Package.swift"
4. Can automatically apply fix if requested
```

---

## UI Automation

**AXe-powered UI testing and accessibility** validation.

### Overview

Integration with **AXe** (Accessibility Automation) provides powerful UI inspection, automation, and accessibility auditing.

### Features

- 🔍 **UI Hierarchy Inspection** - Full UI tree analysis
- ♿ **Accessibility Auditing** - WCAG compliance checking
- 🎯 **Element Interaction** - Tap, swipe, type automation
- 📸 **Screenshot Capture** - Visual test verification

### Usage

#### UI Hierarchy

```bash
# Get full UI hierarchy
cd ../../../XcodeBuildMCP
npx mcp run describe_ui \
  --simulator "iPhone 15 Pro" \
  --bundle-id com.example.MyApp

# Returns JSON with all UI elements, labels, accessibility info
```

#### Accessibility Audit

```bash
# Full accessibility audit
./accessibilityAgent.sh \
  --simulator-name "iPhone 15 Pro" \
  --bundle-id com.example.MyApp \
  --audit-type full

# Quick audit
./accessibilityAgent.sh \
  --simulator-name "iPhone 15 Pro" \
  --bundle-id com.example.MyApp \
  --audit-type quick

# Specific checks
./accessibilityAgent.sh \
  --simulator-name "iPhone 15 Pro" \
  --bundle-id com.example.MyApp \
  --check-touch-targets \
  --check-labels
```

#### UI Testing

```bash
# Run UI tests with AXe
./uiTestAgent.sh \
  --scheme MyApp \
  --simulator-name "iPhone 15 Pro" \
  --use-axe

# Flow-based testing
./uiTestAgent.sh \
  --scheme MyApp \
  --simulator-name "iPhone 15 Pro" \
  --flow-file flows/login.json
```

### Requirements

- AXe installed (via `setup.sh` or `brew install axe`)
- Simulator running with app installed
- Accessibility enabled in simulator

### Accessibility Checks

| Check | Description | WCAG Level |
|-------|-------------|------------|
| **Touch Targets** | Minimum 44x44pt | AA |
| **Labels** | All elements labeled | A |
| **Identifiers** | Unique accessibility IDs | Best Practice |
| **Contrast** | Text contrast ratios | AA/AAA |
| **Dynamic Type** | Supports text scaling | AA |
| **VoiceOver** | Screen reader navigation | A |

---

## Simulator Management

**Automated simulator lifecycle** management.

### Overview

Intelligent simulator management handles booting, configuration, and cleanup automatically.

### Features

- 🚀 **Auto-Boot** - Starts simulators as needed
- ⚙️ **Configuration** - Location, language, accessibility
- 🔄 **State Management** - Tracks simulator status
- 🧹 **Cleanup** - Automatic shutdown and cleanup

### Usage

```bash
# Auto-boot simulator
./BuildAgent.sh --auto-simulator --scheme MyApp

# Disable auto-boot
./BuildAgent.sh --no-auto-simulator --scheme MyApp

# List simulators
./list-simulators.sh

# Or via XcodeBuildMCP
cd ../../../XcodeBuildMCP
npx mcp run list_simulators --platform iOS
```

### Simulator Configuration

The system automatically:
- Boots simulator if not running
- Sets location (if specified)
- Configures language/region
- Enables accessibility features
- Waits for full boot before proceeding

### Manual Control

```bash
# Boot specific simulator
xcrun simctl boot "iPhone 15 Pro"

# Shutdown all
xcrun simctl shutdown all

# Erase simulator
xcrun simctl erase "iPhone 15 Pro"

# Set location
xcrun simctl location "iPhone 15 Pro" set 37.7749,-122.4194
```

---

## Fancy UI System

**Beautiful terminal output** with themes, components, and animations.

### Overview

The Fancy UI system transforms plain terminal output into a visually rich experience with progress indicators, themes, and smart formatting.

See **[UI Customization Guide](UI_CUSTOMIZATION.md)** for complete documentation.

### Quick Start

```bash
export BUILDAGENT_FANCY_UI=true
export BUILDAGENT_THEME=dark  # or 'light'
./BuildAgent.sh --scheme MyApp
```

### Components

- 🎨 **Themes** - Dark and light color schemes
- 📦 **Box Drawing** - Unicode boxes with rounded corners
- 📊 **Progress Bars** - Visual build progress
- ⚡ **Spinners** - Animated status indicators
- 🌈 **Gradients** - Smooth color transitions
- 📝 **Status Footer** - Persistent status bar

---

## MCP Integration

**71 MCP tools** for AI-driven development.

### Overview

Model Context Protocol (MCP) integration enables AI models to interact with the build system through structured tool calls.

### Tool Categories

| Category | Count | Examples |
|----------|-------|----------|
| **Build** | 15 | build, clean, analyze |
| **Test** | 12 | run_tests, debug_test |
| **Simulator** | 10 | boot_simulator, list_simulators |
| **Device** | 8 | list_devices, install_on_device |
| **UI Testing** | 14 | describe_ui, accessibility_audit |
| **Debugging** | 12 | attach_debugger, set_breakpoint |
| **SPM** | 8 | spm_build, spm_resolve |

### Usage from AI

```
AI: "Build the app for iOS"
→ Calls: build(scheme="MyApp", platform="iOS")

AI: "Run tests on iPhone 15 Pro"
→ Calls: run_tests(scheme="MyApp", simulator="iPhone 15 Pro")

AI: "What UI elements are on screen?"
→ Calls: describe_ui(simulator="iPhone 15 Pro", bundle_id="com.example.MyApp")
```

### Documentation

See **[XcodeBuildMCP Tools Reference](../../../XcodeBuildMCP/docs/TOOLS.md)** for complete tool documentation.

---

## See Also

- [Agent Reference](AGENT_REFERENCE.md) - Agent flags and usage
- [Workflow Examples](WORKFLOW_EXAMPLES.md) - Practical examples
- [UI Customization](UI_CUSTOMIZATION.md) - Theming guide
- [Troubleshooting](TROUBLESHOOTING.md) - Common issues

---

**Last Updated**: January 2026  
**Version**: 3.0  
**Features**: 8 major features documented
