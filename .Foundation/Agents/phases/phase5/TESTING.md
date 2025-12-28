# Phase 5 Agent Testing Guide

This guide provides test commands for each Phase 5 agent.

## Quick Test Suite

Run all agents' validation tests:
```bash
.Foundation/Agents/phases/phase5/test-all-agents.sh
```

## Individual Agent Tests

### 1. BuildAgent.sh - Main Build Orchestrator

**Help/Syntax Tests:**
```bash
# Show help
.Foundation/Agents/phases/phase5/BuildAgent.sh --help

# Show version
.Foundation/Agents/phases/phase5/BuildAgent.sh --version
```

**Dry-Run Tests (no actual building):**
```bash
# Test auto-detection
.Foundation/Agents/phases/phase5/BuildAgent.sh --dry-run

# Test with different AI providers
.Foundation/Agents/phases/phase5/BuildAgent.sh --ai-provider claude --dry-run
.Foundation/Agents/phases/phase5/BuildAgent.sh --ai-provider cursor --dry-run
.Foundation/Agents/phases/phase5/BuildAgent.sh --ai-provider letta --dry-run
```

**Safe Integration Tests:**
```bash
# Test with a simple prompt (requires AI setup)
cd Foundation
.Foundation/Agents/phases/phase5/BuildAgent.sh --prompt "Add a comment to ContentView.swift"

# Test with YOLO mode (fully automated)
.Foundation/Agents/phases/phase5/BuildAgent.sh --yolo --prompt "Add documentation"
```

---

### 2. BuildLint.sh - Build Verification

**Help/Syntax Tests:**
```bash
# Show help
.Foundation/Agents/phases/phase5/BuildLint.sh --help
```

**Integration Tests:**
```bash
# Run on Foundation project
cd Foundation
.Foundation/Agents/phases/phase5/BuildLint.sh --project Foundation.xcodeproj --scheme Foundation

# Auto-detect mode
cd Foundation
.Foundation/Agents/phases/phase5/BuildLint.sh
```

---

### 3. BuildVerify.sh - Build + Test Orchestrator

**Help/Syntax Tests:**
```bash
# Show help
.Foundation/Agents/phases/phase5/BuildVerify.sh --help
```

**Integration Tests:**
```bash
# Run build verification with memory
cd Foundation
.Foundation/Agents/phases/phase5/BuildVerify.sh --project Foundation.xcodeproj

# With specific AI provider
.Foundation/Agents/phases/phase5/BuildVerify.sh --ai-provider claude
```

---

### 4. testAgent.sh - Test Orchestrator

**Help/Syntax Tests:**
```bash
# Show help
.Foundation/Agents/phases/phase5/testAgent.sh --help
```

**Dry-Run Tests:**
```bash
# Test stage detection
.Foundation/Agents/phases/phase5/testAgent.sh --dry-run

# Test specific stage
.Foundation/Agents/phases/phase5/testAgent.sh --stage unit --dry-run
.Foundation/Agents/phases/phase5/testAgent.sh --stage accessibility --dry-run
```

**Integration Tests:**
```bash
# Run unit test stage only
cd Foundation
.Foundation/Agents/phases/phase5/testAgent.sh --stage unit

# Run complete pipeline
cd Foundation
.Foundation/Agents/phases/phase5/testAgent.sh --project Foundation.xcodeproj
```

---

### 5. unitTestAgent.sh - Unit Test Generation

**Help/Syntax Tests:**
```bash
# Show help
.Foundation/Agents/phases/phase5/unitTestAgent.sh --help
```

**Integration Tests:**
```bash
# Generate tests for specific files
cd Foundation
.Foundation/Agents/phases/phase5/unitTestAgent.sh --files "Foundation/Models/*.swift"

# Generate with coverage target
.Foundation/Agents/phases/phase5/unitTestAgent.sh --target-coverage 80

# With AI provider
.Foundation/Agents/phases/phase5/unitTestAgent.sh --ai-provider claude --yolo
```

---

### 6. accessibilityAgent.sh - Accessibility Enhancement

**Help/Syntax Tests:**
```bash
# Show help
.Foundation/Agents/phases/phase5/accessibilityAgent.sh --help
```

**Integration Tests:**
```bash
# Scan only (no modifications)
cd Foundation
.Foundation/Agents/phases/phase5/accessibilityAgent.sh --scan-only

# Generate accessibility audit
.Foundation/Agents/phases/phase5/accessibilityAgent.sh --audit

# Fix specific views
.Foundation/Agents/phases/phase5/accessibilityAgent.sh --files "Foundation/Views/*.swift"
```

---

### 7. flowAgent.sh - Flow Analysis

**Help/Syntax Tests:**
```bash
# Show help
.Foundation/Agents/phases/phase5/flowAgent.sh --help
```

**Integration Tests:**
```bash
# Analyze all flows
cd Foundation
.Foundation/Agents/phases/phase5/flowAgent.sh --project Foundation.xcodeproj

# Focus on specific feature
.Foundation/Agents/phases/phase5/flowAgent.sh --feature "Configuration"

# Output to JSON
.Foundation/Agents/phases/phase5/flowAgent.sh --output flows.json
```

---

### 8. uiTestAgent.sh - UI Test Generation

**Help/Syntax Tests:**
```bash
# Show help
.Foundation/Agents/phases/phase5/uiTestAgent.sh --help
```

**Integration Tests:**
```bash
# Generate from flows (requires flowAgent output)
cd Foundation
.Foundation/Agents/phases/phase5/uiTestAgent.sh --flows flows.json

# Generate for specific flow types
.Foundation/Agents/phases/phase5/uiTestAgent.sh --flows flows.json --type happy
.Foundation/Agents/phases/phase5/uiTestAgent.sh --flows flows.json --type sad

# Generate test plans
.Foundation/Agents/phases/phase5/uiTestAgent.sh --generate-test-plan
```

---

### 9. testRunner.sh - Test Execution

**Help/Syntax Tests:**
```bash
# Show help
.Foundation/Agents/phases/phase5/testRunner.sh --help
```

**Integration Tests:**
```bash
# Run all tests
cd Foundation
.Foundation/Agents/phases/phase5/testRunner.sh --project Foundation.xcodeproj --scheme Foundation

# Run with recording
.Foundation/Agents/phases/phase5/testRunner.sh --record --screenshots

# Run specific test plan
.Foundation/Agents/phases/phase5/testRunner.sh --test-plan UITests.xctestplan

# Run on multiple devices
.Foundation/Agents/phases/phase5/testRunner.sh --destinations "iPhone 15,iPad Pro"

# Parallel execution
.Foundation/Agents/phases/phase5/testRunner.sh --parallel --max-concurrent 4
```

---

## Full Pipeline Test

Test the complete workflow:

```bash
# 1. Build with BuildAgent
cd Foundation
.Foundation/Agents/phases/phase5/BuildAgent.sh --prompt "Add inline documentation"

# 2. Verify with BuildLint
.Foundation/Agents/phases/phase5/BuildLint.sh

# 3. Generate tests with testAgent
.Foundation/Agents/phases/phase5/testAgent.sh --stage unit

# 4. Run tests with testRunner
.Foundation/Agents/phases/phase5/testRunner.sh --scheme Foundation

# Or use BuildVerify for full automation
.Foundation/Agents/phases/phase5/BuildVerify.sh --ai-provider claude --yolo
```

---

## Test Results

Last test run: **All 9 agents passed** ✅

```
Total Agents: 9
Passed: 9
Failed: 0

Additional Infrastructure:
✓ lib/ directory (2 files)
✓ templates/ directory (3 files)
✓ README.md exists
```

### Agent Status Summary

| Agent | Status | Features Validated |
|-------|--------|-------------------|
| BuildAgent.sh | ✅ PASS | Multi-provider, Auto-detection, YOLO mode |
| BuildLint.sh | ✅ PASS | SwiftLint, Xcode build |
| BuildVerify.sh | ✅ PASS | Letta memory, BuildAgent + TestAgent orchestration |
| testAgent.sh | ✅ PASS | Stage management, Sub-agent orchestration |
| unitTestAgent.sh | ✅ PASS | AI provider support |
| accessibilityAgent.sh | ✅ PASS | AI provider support |
| flowAgent.sh | ✅ PASS | AI provider support |
| uiTestAgent.sh | ✅ PASS | AI provider support |
| testRunner.sh | ✅ PASS | Test execution |

---

## CI/CD Integration

Example GitHub Actions workflow:

```yaml
name: Phase5 Agent Tests

on: [push, pull_request]

jobs:
  test-agents:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Install Xcode
        run: sudo xcode-select -s /Applications/Xcode.app
      
      - name: Run Agent Test Suite
        run: .Foundation/Agents/phases/phase5/test-all-agents.sh
      
      - name: Test BuildLint
        run: |
          cd Foundation
          .Foundation/Agents/phases/phase5/BuildLint.sh
```

---

## Prerequisites

Before testing agents that require AI providers:

```bash
# Set up API keys
export ANTHROPIC_API_KEY=sk-ant-...    # For Claude
export OPENAI_API_KEY=sk-...           # For Codex
export GOOGLE_API_KEY=...              # For Gemini
export LETTA_API_KEY=letta-...         # For Letta

# Or use Cursor (auto-authenticated if logged in)
# No API key needed
```

---

## Troubleshooting

### Agent not found
```bash
# Make sure you're in the project root
cd /path/to/Eocon-Foundation-V1

# Or use absolute paths
/path/to/.Foundation/Agents/phases/phase5/BuildAgent.sh --help
```

### Permission denied
```bash
# Make agents executable
chmod +x .Foundation/Agents/phases/phase5/*.sh
```

### Missing dependencies
```bash
# Agents auto-install most dependencies, but verify:
xcode-select --install          # Xcode command line tools
brew install swiftlint          # SwiftLint (auto-installed by BuildLint)
```

---

## Next Steps

1. **Run validation suite**: `./test-all-agents.sh`
2. **Test individual agents**: Use commands above
3. **Integrate into CI/CD**: See example workflow
4. **Customize for your project**: Adjust parameters as needed
