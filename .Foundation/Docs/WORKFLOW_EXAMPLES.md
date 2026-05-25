# Workflow Examples

10+ comprehensive workflows demonstrating Eocon Foundation Build System capabilities with AI integration.

## Table of Contents

1. [Fast Incremental Development](#1-fast-incremental-development)
2. [Multi-Platform Testing](#2-multi-platform-testing)
3. [UI Testing with AXe](#3-ui-testing-with-axe)
4. [Accessibility Validation](#4-accessibility-validation)
5. [Debug Failed Test](#5-debug-failed-test)
6. [Swift Package Build](#6-swift-package-build)
7. [AI-Driven Build Repair](#7-ai-driven-build-repair)
8. [Multi-Platform CI Pipeline](#8-multi-platform-ci-pipeline)
9. [UI Test Generation from Flows](#9-ui-test-generation-from-flows)
10. [Performance Testing](#10-performance-testing)
11. [Accessibility Compliance Audit](#11-accessibility-compliance-audit)
12. [Device Testing](#12-device-testing)

---

## 1. Fast Incremental Development

**Use Case**: Rapid iteration during active development with minimal rebuild time.

**Features**: Session defaults, incremental builds, auto-simulator

### Setup (One Time)

```bash
cd .Foundation/Agents/phases/phase5

# Save session defaults for your project
./BuildAgent.sh --save-session-defaults \
  --scheme MyApp \
  --simulator-name "iPhone 15 Pro" \
  --platform iOS \
  --enable-incremental \
  --auto-simulator \
  --capture-logs
```

### Daily Workflow

```bash
# Just run - it remembers everything!
./BuildAgent.sh

# Make code changes, then rebuild (10x faster with incremental)
./BuildAgent.sh

# Run tests after changes
./testRunner.sh

# Check UI after changes
./uiTestAgent.sh
```

### Expected Results

- ✅ First build: Normal time (e.g., 2 minutes)
- ✅ Subsequent builds: ~10-20 seconds (incremental)
- ✅ Simulator auto-boots if not running
- ✅ Logs captured for analysis
- ✅ No need to specify flags repeatedly

### AI Integration

```
AI Prompt: "Build my app with the latest changes"
→ AI calls BuildAgent.sh using session defaults
→ Returns build status and any errors
→ AI can analyze captured logs if build fails
```

---

## 2. Multi-Platform Testing

**Use Case**: Ensure app works across iOS, macOS, tvOS, watchOS, visionOS.

**Features**: Platform support, parallel testing

### Workflow

```bash
# Test on iOS
./testRunner.sh \
  --scheme MyApp \
  --platform iOS \
  --simulator-name "iPhone 15 Pro" \
  --parallel

# Test on macOS
./testRunner.sh \
  --scheme MyApp \
  --platform macOS

# Test on visionOS
./testRunner.sh \
  --scheme MyApp \
  --platform visionOS \
  --simulator-name "Apple Vision Pro"

# Test on tvOS
./testRunner.sh \
  --scheme MyApp \
  --platform tvOS \
  --simulator-name "Apple TV"

# Test on watchOS
./testRunner.sh \
  --scheme MyApp \
  --platform watchOS \
  --simulator-name "Apple Watch Series 9 (45mm)"
```

### Parallel Multi-Platform Script

```bash
#!/bin/bash
# test-all-platforms.sh

platforms=("iOS" "macOS" "visionOS")
pids=()

for platform in "${platforms[@]}"; do
  ./testRunner.sh --scheme MyApp --platform "$platform" &
  pids+=($!)
done

# Wait for all
for pid in "${pids[@]}"; do
  wait "$pid"
done

echo "✅ All platforms tested"
```

### Expected Results

- ✅ Tests run on all target platforms
- ✅ Platform-specific issues identified
- ✅ Result bundles generated for each platform
- ✅ Coverage reports combined

---

## 3. UI Testing with AXe

**Use Case**: Automated UI testing with accessibility inspection.

**Features**: AXe integration, UI hierarchy, screenshot capture

### Workflow

```bash
# 1. Start app on simulator
./BuildAgent.sh --scheme MyApp --auto-simulator

# 2. Get UI hierarchy
cd ../../../XcodeBuildMCP
npx mcp run describe_ui \
  --simulator "iPhone 15 Pro" \
  --bundle-id com.example.MyApp

# 3. Generate test from UI description
# (AI model generates test based on UI hierarchy)

# 4. Run UI tests
cd ../Eocon-Foundation-V1/.Foundation/Agents/phases/phase5
./uiTestAgent.sh \
  --scheme MyApp \
  --simulator-name "iPhone 15 Pro" \
  --use-axe \
  --capture-screenshots
```

### AI-Assisted Test Generation

```
AI Prompt: "Generate UI test for login flow"

AI Actions:
1. Calls describe_ui to get current screen
2. Identifies username field, password field, login button
3. Generates XCTest code:
   - Tap username field
   - Enter text
   - Tap password field
   - Enter text
   - Tap login button
   - Assert success screen appears
4. Saves test to project
5. Runs uiTestAgent.sh to execute
```

### Expected Results

- ✅ UI hierarchy captured via AXe
- ✅ Tests generated based on actual UI elements
- ✅ Screenshots captured on failure
- ✅ Accessibility identifiers validated

---

## 4. Accessibility Validation

**Use Case**: Ensure app meets accessibility guidelines.

**Features**: AXe accessibility audit, touch target validation

### Workflow

```bash
# 1. Build and run app
./BuildAgent.sh --scheme MyApp --auto-simulator

# Wait for app to launch
sleep 5

# 2. Run full accessibility audit
./accessibilityAgent.sh \
  --simulator-name "iPhone 15 Pro" \
  --bundle-id com.example.MyApp \
  --audit-type full \
  --check-touch-targets \
  --check-labels \
  --check-identifiers \
  --output html

# 3. Review report
open accessibility-report.html
```

### Continuous Accessibility Monitoring

```bash
#!/bin/bash
# accessibility-ci.sh

./BuildAgent.sh --scheme MyApp --auto-simulator
sleep 5

./accessibilityAgent.sh \
  --simulator-name "iPhone 15 Pro" \
  --bundle-id com.example.MyApp \
  --audit-type full \
  --output json > accessibility-results.json

# Parse results
issues=$(jq '.issues | length' accessibility-results.json)

if [[ $issues -gt 0 ]]; then
  echo "❌ Found $issues accessibility issues"
  jq '.issues' accessibility-results.json
  exit 1
else
  echo "✅ No accessibility issues"
  exit 0
fi
```

### Expected Results

- ✅ Touch targets meet minimum size (44x44pt)
- ✅ All interactive elements have labels
- ✅ All elements have accessibility identifiers
- ✅ Contrast ratios meet WCAG guidelines
- ✅ VoiceOver navigation works correctly

---

## 5. Debug Failed Test

**Use Case**: Investigate and fix a failing test using LLDB integration.

**Features**: Debug mode, breakpoint setting, log analysis

### Workflow

```bash
# 1. Run tests to identify failure
./testRunner.sh \
  --scheme MyApp \
  --simulator-name "iPhone 15 Pro" \
  --capture-logs

# Test fails - review logs
cat logs/test-results.log

# 2. Use XcodeBuildMCP to debug
cd ../../../XcodeBuildMCP

# Attach debugger to next test run
npx mcp run debug_test \
  --scheme MyApp \
  --test "MyAppTests/testCheckout" \
  --simulator "iPhone 15 Pro" \
  --breakpoint "MyApp.CheckoutView:45"

# 3. Inspect variables when breakpoint hits
npx mcp run lldb_evaluate \
  --expression "po cartItems"

# 4. Continue execution
npx mcp run lldb_continue

# 5. Fix issue and re-run
cd ../Eocon-Foundation-V1/.Foundation/Agents/phases/phase5
./testRunner.sh --only MyAppTests/testCheckout
```

### AI-Assisted Debugging

```
AI Prompt: "Debug why testCheckout is failing"

AI Actions:
1. Reads test logs to identify failure point
2. Sets breakpoint at suspected line
3. Runs test with debugger attached
4. Evaluates relevant variables
5. Analyzes values and identifies issue (e.g., cart empty)
6. Suggests fix: "Initialize cart before checkout test"
7. AI can even generate the fix if requested
```

### Expected Results

- ✅ Failure cause identified via debugger
- ✅ Variable values inspected at failure point
- ✅ Fix applied and verified
- ✅ Test passes on re-run

---

## 6. Swift Package Build

**Use Case**: Build and test a Swift Package Manager library.

**Features**: SPM detection, dependency resolution

### Workflow

```bash
# 1. Navigate to SPM package
cd MySwiftPackage

# 2. Build package
../../Eocon-Foundation-V1/.Foundation/Agents/phases/phase5/BuildAgent.sh \
  --scheme MyPackage \
  --platform macOS

# 3. Run package tests
../../Eocon-Foundation-V1/.Foundation/Agents/phases/phase5/testRunner.sh \
  --scheme MyPackage \
  --platform macOS \
  --parallel
```

### Using XcodeBuildMCP SPM Tools

```bash
cd ../../../XcodeBuildMCP

# Resolve dependencies
npx mcp run spm_resolve

# Update dependencies
npx mcp run spm_update

# Build specific product
npx mcp run spm_build --product MyLibrary

# Run tests
npx mcp run spm_test
```

### Expected Results

- ✅ SPM dependencies resolved
- ✅ Package builds successfully
- ✅ All tests pass
- ✅ Products available for import

---

## 7. AI-Driven Build Repair

**Use Case**: AI automatically diagnoses and fixes build failures.

**Features**: Log streaming, AI analysis, automated fixes

### Workflow

```bash
# 1. Build with log capture
./BuildAgent.sh --scheme MyApp --capture-logs

# Build fails - logs captured

# 2. AI analyzes logs
# (AI model reads logs/build-output.log)

# 3. AI identifies issue
# Example: "Missing import for UIKit in ViewController.swift"

# 4. AI applies fix
# (AI edits file to add import)

# 5. Rebuild
./BuildAgent.sh

# 6. Success!
```

### AI Integration Example

```
User: "My build is failing, please fix it"

AI Actions:
1. Runs BuildAgent.sh --capture-logs
2. Reads captured logs
3. Identifies error: "Use of unresolved identifier 'UITableView'"
4. Searches codebase for file
5. Adds: import UIKit
6. Commits change
7. Re-runs build
8. Confirms success
9. Reports: "Fixed missing UIKit import in ViewController.swift"
```

### Expected Results

- ✅ Build error diagnosed automatically
- ✅ Fix applied by AI
- ✅ Build succeeds on retry
- ✅ Developer informed of changes

---

## 8. Multi-Platform CI Pipeline

**Use Case**: Complete CI/CD pipeline testing all platforms.

**Features**: Parallel builds, result aggregation

### GitHub Actions Example

```yaml
name: Multi-Platform CI

on: [push, pull_request]

jobs:
  build-ios:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4
      - name: Build iOS
        run: |
          cd .Foundation/Agents/phases/phase5
          ./BuildAgent.sh --scheme MyApp --platform iOS \
            --simulator-name "iPhone 15 Pro" \
            --enable-incremental
      - name: Test iOS
        run: |
          cd .Foundation/Agents/phases/phase5
          ./testRunner.sh --scheme MyApp --platform iOS \
            --simulator-name "iPhone 15 Pro" \
            --code-coverage --parallel
  
  build-macos:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4
      - name: Build macOS
        run: |
          cd .Foundation/Agents/phases/phase5
          ./BuildAgent.sh --scheme MyApp --platform macOS
      - name: Test macOS
        run: |
          cd .Foundation/Agents/phases/phase5
          ./testRunner.sh --scheme MyApp --platform macOS \
            --code-coverage --parallel
  
  build-visionos:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4
      - name: Build visionOS
        run: |
          cd .Foundation/Agents/phases/phase5
          ./BuildAgent.sh --scheme MyApp --platform visionOS \
            --simulator-name "Apple Vision Pro"
      - name: Test visionOS
        run: |
          cd .Foundation/Agents/phases/phase5
          ./testRunner.sh --scheme MyApp --platform visionOS \
            --simulator-name "Apple Vision Pro" \
            --code-coverage
```

### Expected Results

- ✅ All platforms built in parallel
- ✅ Tests run on all platforms
- ✅ Coverage reports generated
- ✅ Failures reported per platform

---

## 9. UI Test Generation from Flows

**Use Case**: Generate comprehensive UI tests from flow definitions.

**Features**: Flow-based testing, test generation

### Flow Definition Example

```json
{
  "flow_name": "Login Flow",
  "steps": [
    {
      "action": "tap",
      "element": "usernameField",
      "identifier": "login_username"
    },
    {
      "action": "type",
      "text": "testuser@example.com"
    },
    {
      "action": "tap",
      "element": "passwordField",
      "identifier": "login_password"
    },
    {
      "action": "type",
      "text": "password123"
    },
    {
      "action": "tap",
      "element": "loginButton",
      "identifier": "login_submit"
    },
    {
      "action": "assert",
      "condition": "exists",
      "element": "welcomeLabel",
      "identifier": "home_welcome"
    }
  ]
}
```

### Workflow

```bash
# 1. Create flow definition
cat > flows/login-flow.json << 'EOF'
{ /* JSON from above */ }
EOF

# 2. Validate flow
./flowAgent.sh --flow-file flows/login-flow.json --validate

# 3. Generate test code
./flowAgent.sh --flow-file flows/login-flow.json --generate-tests
# Creates: Tests/LoginFlowTests.swift

# 4. Run generated tests
./uiTestAgent.sh \
  --scheme MyApp \
  --simulator-name "iPhone 15 Pro" \
  --flow-file flows/login-flow.json
```

### Expected Results

- ✅ Flow validated successfully
- ✅ XCTest code generated from flow
- ✅ Tests run automatically
- ✅ Flow assertions verified

---

## 10. Performance Testing

**Use Case**: Measure and optimize app performance.

**Features**: Repeated tests, log analysis, metrics collection

### Workflow

```bash
# 1. Run performance test suite
./testRunner.sh \
  --scheme MyApp \
  --simulator-name "iPhone 15 Pro" \
  --only PerformanceTests \
  --repeat 10 \
  --capture-logs

# 2. Analyze performance metrics
grep "Performance:" logs/test-results.log | \
  awk '{sum+=$2; count++} END {print "Average:", sum/count "ms"}'

# 3. Run with Instruments (via XcodeBuildMCP)
cd ../../../XcodeBuildMCP
npx mcp run profile_app \
  --scheme MyApp \
  --simulator "iPhone 15 Pro" \
  --template "Time Profiler"

# 4. Compare results
npx mcp run analyze_trace \
  --trace performance.trace
```

### Expected Results

- ✅ Baseline performance established
- ✅ Performance regression detected
- ✅ Hotspots identified via profiler
- ✅ Optimization opportunities found

---

## 11. Accessibility Compliance Audit

**Use Case**: Full WCAG compliance audit for app store submission.

### Workflow

```bash
# 1. Build app
./BuildAgent.sh --scheme MyApp --auto-simulator

# Wait for app
sleep 5

# 2. Navigate through all screens
# (Manual or automated navigation)

# 3. Run audit on each screen
for screen in Home Profile Settings Checkout; do
  echo "Auditing $screen..."
  
  # Navigate to screen (via AXe or manual)
  
  # Run audit
  ./accessibilityAgent.sh \
    --simulator-name "iPhone 15 Pro" \
    --bundle-id com.example.MyApp \
    --audit-type full \
    --output json > "accessibility-$screen.json"
done

# 4. Combine results
jq -s 'add' accessibility-*.json > accessibility-full-report.json

# 5. Generate HTML report
./accessibilityAgent.sh \
  --simulator-name "iPhone 15 Pro" \
  --bundle-id com.example.MyApp \
  --audit-type full \
  --output html

open accessibility-report.html
```

### Expected Results

- ✅ All screens audited
- ✅ WCAG AA compliance verified
- ✅ Issues categorized by severity
- ✅ Remediation suggestions provided

---

## 12. Device Testing

**Use Case**: Test on physical iOS devices.

**Features**: Device detection, deployment, testing

### Workflow

```bash
# 1. List connected devices
cd ../../../XcodeBuildMCP
npx mcp run list_devices

# 2. Build for device
cd ../Eocon-Foundation-V1/.Foundation/Agents/phases/phase5
./BuildAgent.sh \
  --scheme MyApp \
  --destination "platform=iOS,name=John's iPhone"

# 3. Run tests on device
./testRunner.sh \
  --scheme MyApp \
  --destination "platform=iOS,name=John's iPhone" \
  --capture-logs

# 4. Monitor device logs
cd ../../../XcodeBuildMCP
npx mcp run stream_device_logs \
  --device "John's iPhone"
```

### Expected Results

- ✅ App deployed to physical device
- ✅ Tests run on real hardware
- ✅ Device-specific issues identified
- ✅ Real-world performance measured

---

## See Also

- [Agent Reference](AGENT_REFERENCE.md) - Detailed flag documentation
- [Features](FEATURES.md) - Feature descriptions
- [UI Customization](UI_CUSTOMIZATION.md) - Theming guide
- [Troubleshooting](TROUBLESHOOTING.md) - Common issues
- [XcodeBuildMCP Tools](../../../XcodeBuildMCP/docs/TOOLS.md) - MCP tool reference

---

**Last Updated**: January 2026  
**Version**: 3.0  
**Examples**: 12 workflows
