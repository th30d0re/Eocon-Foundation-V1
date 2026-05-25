# Phase 5: Test Agent Integration & Automation

## Overview
Fully automated test workflows with simulator management, log capture, and UI automation.

## Enhanced Agents

### testRunner.sh
- Automatic simulator boot and configuration
- Structured log capture for all test runs
- AXe UI description before tests
- Zero manual simulator management

**Usage:**
```bash
testRunner.sh --auto-boot --simulator-name "iPhone 16" \
  --capture-logs --use-axe --describe-ui
```

**Key Features:**
- `--auto-boot`: Automatically boot simulator if not running
- `--capture-logs`: Enable structured log capture
- `--use-axe`: Enable AXe UI automation support
- `--describe-ui`: Capture UI hierarchy before tests
- `--set-location <lat,lon>`: Set GPS location
- `--appearance <mode>`: Set dark/light mode

### uiTestAgent.sh
- Integrated UI description before test generation
- Automatic accessibility validation
- Live UI hierarchy for accurate targeting

**Usage:**
```bash
uiTestAgent.sh --flows flows.json --use-axe \
  --simulator-name "iPhone 16" --app-path MyApp.app \
  --bundle-id com.example.MyApp
```

**Key Features:**
- Automatically captures UI hierarchy when AXe is enabled
- Generates tests based on live UI elements
- Validates element identifiers against running app
- Provides accurate coordinates and accessibility labels

### accessibilityAgent.sh
- Live UI validation via AXe
- Compare code accessibility vs running app
- Touch target size validation

**Usage:**
```bash
accessibilityAgent.sh --use-axe --validate-live \
  --simulator-name "iPhone 16" --app-path MyApp.app \
  --bundle-id com.example.MyApp
```

**Key Features:**
- `--use-axe`: Enable AXe UI automation
- `--validate-live`: Compare code accessibility vs running app
- `--axe-audit`: Generate audit from live hierarchy
- `--check-touch-targets`: Verify 44x44pt minimum sizes

### testAgent.sh
- Automatic simulator preparation
- Unified pipeline log capture
- Session defaults for all stages

**Usage:**
```bash
testAgent.sh --prepare-simulator --simulator-name "iPhone 16" \
  --set-location "37.7749,-122.4194" --capture-pipeline-logs
```

**Key Features:**
- `--prepare-simulator`: Boot and configure simulator before pipeline
- `--set-location <lat,lon>`: Set GPS location
- `--appearance <mode>`: Set dark/light mode
- `--capture-pipeline-logs`: Unified log session for entire pipeline

### BuildVerify.sh, flowAgent.sh, unitTestAgent.sh
- Session defaults integration
- Persistent configuration across runs

**Usage:**
```bash
# Set session defaults
BuildVerify.sh --session --session-set scheme=MyApp

# Use saved defaults
BuildVerify.sh --session
```

**Key Features:**
- `--session`: Use session defaults for configuration
- `--session-set <k=v>`: Set session default (scheme, platform, simulator)
- Automatic persistence across pipeline stages

## Testing Libraries

### simulator.sh
Complete simulator lifecycle management with caching and graceful degradation.

**Features:**
- Boot and shutdown simulators
- Set GPS location and appearance
- Query simulator state
- Caching for performance

### log_capture.sh
Structured log sessions with automatic cleanup and metadata tracking.

**Features:**
- Start/stop log capture sessions
- Append logs with timestamps
- Get log paths and metadata
- Automatic cleanup on exit

### axe_helpers.sh
AXe UI automation with element finding, gestures, and validation.

**Features:**
- Describe UI hierarchy
- Find elements by identifier
- Capture screenshots
- Tap, swipe, and input gestures
- Element existence validation

### session_store.sh
Persistent defaults with automatic learning and flag tracking.

**Features:**
- Set/get session defaults
- Save/load session state
- Per-directory isolation
- Automatic cleanup

## Dependencies

Install required dependencies:

```bash
# AXe for UI automation
brew tap cameroncooke/axe && brew install axe

# jq for JSON processing
brew install jq

# xcodemake for Xcode project management
brew install xcodemake
```

## Backward Compatibility

All enhancements are opt-in via flags:
- `--no-auto-simulator`: Disable automatic simulator management
- `--no-capture-logs`: Disable log capture
- `--no-session`: Disable session defaults

Existing workflows continue to work without modifications.

## Workflow Examples

### Complete Test Pipeline with Automation

```bash
# Prepare simulator and run full test pipeline
testAgent.sh \
  --prepare-simulator \
  --simulator-name "iPhone 16" \
  --set-location "37.7749,-122.4194" \
  --appearance dark \
  --capture-pipeline-logs
```

### UI Test Generation with Live Validation

```bash
# Generate UI tests from flows with live validation
uiTestAgent.sh \
  --flows flows.json \
  --use-axe \
  --simulator-name "iPhone 16" \
  --app-path Build/MyApp.app \
  --bundle-id com.example.MyApp
```

### Accessibility Audit with Live Comparison

```bash
# Audit accessibility against running app
accessibilityAgent.sh \
  --use-axe \
  --validate-live \
  --axe-audit \
  --simulator-name "iPhone 16" \
  --app-path Build/MyApp.app \
  --bundle-id com.example.MyApp
```

### Session-Based Development

```bash
# Set session defaults once
BuildVerify.sh --session-set scheme=MyApp
BuildVerify.sh --session-set platform=iOS
BuildVerify.sh --session-set simulator="iPhone 16"

# Run agents with saved defaults
testAgent.sh --session
testRunner.sh --session
```

## Sequence Diagram

```
Developer → testAgent.sh --prepare-simulator
  ↓
testAgent.sh → Simulator Library: prepare_simulator_for_pipeline()
  ↓
Simulator Library: boot_simulator("iPhone 16")
Simulator Library: set_simulator_location()
Simulator Library: set_simulator_appearance()
  ↓
testAgent.sh → Log Capture: start_pipeline_log_capture()
  ↓
testAgent.sh → testRunner.sh: Execute test pipeline
  ↓
testRunner.sh → Simulator Library: ensure_simulator_booted()
  ↓
testRunner.sh → AXe Helpers: axe_describe_ui()
  ↓
testRunner.sh: run_tests()
testRunner.sh → Log Capture: append_log()
  ↓
testRunner.sh → Log Capture: stop_log_capture()
  ↓
testAgent.sh → Log Capture: stop_pipeline_log_capture()
  ↓
testAgent.sh → Developer: Pipeline complete with logs
```

## Integration Points

### 1. Simulator Management
- `prepare_simulator_for_testing()` - Prepare simulator with app
- `boot_simulator()` - Boot simulator with wait
- `set_simulator_location()` - Configure GPS
- `set_simulator_appearance()` - Set dark/light mode

### 2. Log Capture
- `start_log_capture()` - Begin log session
- `append_log()` - Add logs to session
- `stop_log_capture()` - End session and save
- `get_log_path()` - Retrieve log file path

### 3. AXe Integration
- `is_axe_available()` - Check AXe installation
- `axe_describe_ui()` - Get UI hierarchy JSON
- `axe_element_exists()` - Validate element
- `axe_tap()` - Perform tap gesture
- `axe_screenshot()` - Capture screenshot

### 4. Session Defaults
- `session_set_default()` - Store default value
- `session_get_default()` - Retrieve default value
- `session_save()` - Persist to disk
- `session_load()` - Load from disk

## Error Handling

All enhancements include graceful degradation:

1. **Missing Dependencies**: Warning logged, feature disabled
2. **Simulator Errors**: Detailed error messages, non-zero exit codes
3. **AXe Failures**: Fallback to basic test generation
4. **Session Errors**: Silent failure, continue without defaults

## Performance Considerations

- **Simulator Caching**: UUID lookups cached for 5 minutes
- **Log Buffering**: Logs buffered before writing to disk
- **AXe Timeouts**: Configurable timeouts for UI operations
- **Session Persistence**: Minimal overhead for save/load

## Troubleshooting

### AXe Not Found
```bash
# Install AXe
brew tap cameroncooke/axe && brew install axe

# Verify installation
axe --version
```

### Simulator Won't Boot
```bash
# Reset simulator caches
rm -rf ~/Library/Developer/CoreSimulator/Caches

# Boot manually first
xcrun simctl boot "iPhone 16"
```

### Session Defaults Not Persisting
```bash
# Check session file
cat .test-session

# Clear session
rm .test-session

# Set defaults again
BuildVerify.sh --session-set scheme=MyApp
```

### Log Capture Fails
```bash
# Check log directory permissions
ls -la /tmp/test-logs

# Clear old logs
rm -rf /tmp/test-logs/*
```

## Summary

This integration enhances Phase 5 test agents by connecting existing testing libraries to create fully automated workflows. The approach focuses on:

1. **Zero-Friction Automation**: Automatic simulator management and log capture
2. **Live UI Validation**: Compare code against running app via AXe
3. **Session Persistence**: Share configuration across pipeline stages
4. **Backward Compatibility**: All enhancements are opt-in
5. **Robust Error Handling**: Graceful degradation when dependencies unavailable

The result is a comprehensive test automation system that enables both developers and AI models to execute end-to-end test workflows without manual intervention.
