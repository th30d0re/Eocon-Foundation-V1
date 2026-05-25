# Integration Tests Documentation

Documentation for integration tests covering critical paths in the Eocon Foundation Build System.

## Table of Contents

- [Overview](#overview)
- [Test Coverage](#test-coverage)
- [Test Execution](#test-execution)
- [Test Scenarios](#test-scenarios)
- [Test Utilities](#test-utilities)
- [CI/CD Integration](#cicd-integration)
- [Writing New Tests](#writing-new-tests)

---

## Overview

Integration tests verify end-to-end functionality of the Eocon Foundation Build System, ensuring all components work together correctly.

### Test Philosophy

- **End-to-End**: Tests cover complete workflows, not isolated functions
- **Real World**: Uses actual Xcode projects and simulators
- **Automated**: Runs without human intervention
- **Fast**: Optimized for quick feedback
- **Reliable**: Deterministic and reproducible

### Test Scope

| Component | Coverage | Critical Paths |
|-----------|----------|----------------|
| **BuildAgent** | 95% | Build, incremental build, clean |
| **testRunner** | 90% | Test execution, parallel tests, coverage |
| **uiTestAgent** | 85% | UI tests, AXe integration, flows |
| **accessibilityAgent** | 90% | Audits, touch targets, labels |
| **Session Management** | 95% | Save, load, clear defaults |
| **Simulator Management** | 90% | Boot, configure, cleanup |
| **Log Capture** | 85% | Capture, stream, parse logs |
| **MCP Integration** | 80% | Tool calls, responses, errors |

---

## Test Coverage

### BuildAgent End-to-End

**Test**: `test_buildagent_basic_build`

**Steps**:
1. Clean project
2. Run BuildAgent with minimal flags
3. Verify build succeeded
4. Check output files exist

**Success Criteria**:
- Build completes without errors
- App binary created
- Logs captured (if enabled)
- Exit code 0

**Test**: `test_buildagent_incremental`

**Steps**:
1. Full build with `--enable-incremental`
2. Touch one source file
3. Rebuild with `--enable-incremental`
4. Verify faster rebuild

**Success Criteria**:
- Second build < 20% of first build time
- Only changed files recompiled
- Binary updated

### testRunner Workflow

**Test**: `test_testrunner_basic`

**Steps**:
1. Build app
2. Run testRunner with scheme
3. Verify tests executed

**Success Criteria**:
- All tests run
- Results captured
- Result bundle generated
- Exit code matches test results (0 = pass, 1 = fail)

**Test**: `test_testrunner_parallel`

**Steps**:
1. Run tests with `--parallel`
2. Monitor execution
3. Verify speedup

**Success Criteria**:
- Tests run in parallel
- Speedup > 1.5x
- All tests complete correctly

**Test**: `test_testrunner_specific`

**Steps**:
1. Run with `--only MyTests/testLogin`
2. Verify only specified test runs

**Success Criteria**:
- Only one test executed
- Correct test ran
- Results accurate

### uiTestAgent with AXe

**Test**: `test_uitestagent_basic`

**Steps**:
1. Build and install app
2. Boot simulator
3. Run uiTestAgent
4. Verify UI tests executed

**Success Criteria**:
- Simulator booted
- App launched
- UI tests ran
- Screenshots captured (on failure)

**Test**: `test_uitestagent_axe`

**Steps**:
1. Build and install app
2. Run uiTestAgent with `--use-axe`
3. Verify AXe integration

**Success Criteria**:
- AXe called successfully
- UI hierarchy captured
- Tests used AXe data

**Test**: `test_uitestagent_flows`

**Steps**:
1. Create flow definition
2. Run with `--flow-file`
3. Verify flow executed

**Success Criteria**:
- Flow parsed correctly
- All steps executed
- Assertions passed

### Session Management

**Test**: `test_session_save_load`

**Steps**:
1. Clear existing session
2. Save new session defaults
3. Load and verify values

**Success Criteria**:
- Session file created
- Valid JSON format
- Values match input

**Test**: `test_session_precedence`

**Steps**:
1. Set session default: --platform iOS
2. Run with CLI flag: --platform macOS
3. Verify CLI flag wins

**Success Criteria**:
- macOS used (CLI precedence)
- Session defaults not ignored

**Test**: `test_session_cross_agent`

**Steps**:
1. Save session with BuildAgent
2. Use session with testRunner
3. Verify values shared

**Success Criteria**:
- testRunner reads BuildAgent session
- Scheme, simulator carry over

### Multi-Platform Builds

**Test**: `test_multiplatform_ios`

**Steps**:
1. Build with `--platform iOS`
2. Verify iOS binary created

**Test**: `test_multiplatform_macos`

**Steps**:
1. Build with `--platform macOS`
2. Verify macOS binary created

**Test**: `test_multiplatform_visionos`

**Steps**:
1. Build with `--platform visionOS`
2. Verify visionOS binary created

**Success Criteria** (all):
- Correct platform selected
- Appropriate SDK used
- Binary for correct platform

### Log Capture and Streaming

**Test**: `test_log_capture`

**Steps**:
1. Run build with `--capture-logs`
2. Verify logs created

**Success Criteria**:
- `logs/build-output.log` exists
- `logs/build-output.json` exists
- Valid JSON structure
- Contains expected events

**Test**: `test_log_streaming`

**Steps**:
1. Start build with log capture
2. Tail log file in background
3. Verify real-time updates

**Success Criteria**:
- Logs appear in real-time
- No buffering delay
- Complete when build finishes

---

## Test Execution

### Running All Tests

```bash
cd .Foundation/Agents/phases/phase5

# Run all integration tests
./test-all-agents.sh

# Run with verbose output
./test-all-agents.sh --verbose

# Run specific test suite
./test-all-agents.sh --suite buildagent

# Run with coverage
./test-all-agents.sh --coverage
```

### Running Individual Tests

```bash
# Test BuildAgent
./test-buildagent.sh

# Test testRunner
./test-testrunner.sh

# Test uiTestAgent
./test-uitestagent.sh

# Test session management
./test-session.sh
```

### Test Output

```
═══════════════════════════════════════════════════════════
  Eocon Foundation Integration Tests
═══════════════════════════════════════════════════════════

Running BuildAgent Tests...
  ✓ test_buildagent_basic_build (45.2s)
  ✓ test_buildagent_incremental (12.8s)
  ✓ test_buildagent_clean (38.4s)
  ✓ test_buildagent_session_defaults (2.1s)

Running testRunner Tests...
  ✓ test_testrunner_basic (32.5s)
  ✓ test_testrunner_parallel (18.3s)
  ✓ test_testrunner_specific (8.7s)
  ✓ test_testrunner_coverage (35.9s)

Running uiTestAgent Tests...
  ✓ test_uitestagent_basic (28.4s)
  ✓ test_uitestagent_axe (15.2s)
  ✓ test_uitestagent_flows (22.1s)

Running Session Tests...
  ✓ test_session_save_load (1.2s)
  ✓ test_session_precedence (1.5s)
  ✓ test_session_cross_agent (2.3s)

═══════════════════════════════════════════════════════════
  Results: 15 passed, 0 failed, 0 skipped
  Time: 265.4s
═══════════════════════════════════════════════════════════
```

---

## Test Scenarios

### Scenario 1: Clean Install to First Build

**Steps**:
1. Fresh checkout
2. Run `setup.sh`
3. Create session defaults
4. First build

**Expected**: All dependencies installed, build succeeds

### Scenario 2: Iterative Development

**Steps**:
1. Initial build (full)
2. Change one file
3. Incremental rebuild
4. Run tests
5. Repeat

**Expected**: Fast rebuilds, tests pass

### Scenario 3: Multi-Platform CI

**Steps**:
1. Build iOS
2. Test iOS
3. Build macOS
4. Test macOS
5. Build visionOS
6. Test visionOS

**Expected**: All platforms build and test successfully

### Scenario 4: UI Test Generation

**Steps**:
1. Build app
2. Describe UI with AXe
3. Generate test from UI description
4. Run generated test

**Expected**: Test auto-generated and passes

### Scenario 5: Accessibility Audit

**Steps**:
1. Build and launch app
2. Navigate to screen
3. Run accessibility audit
4. Fix issues
5. Re-audit

**Expected**: Issues identified, fixes verified

---

## Test Utilities

### Test Helper Functions

Located in `lib/testUtils.sh`:

```bash
# Assert functions
assert_equals() {
  local expected="$1"
  local actual="$2"
  local message="${3:-Assertion failed}"
  
  if [[ "$expected" != "$actual" ]]; then
    echo "✗ $message: expected '$expected', got '$actual'"
    return 1
  fi
  echo "✓ $message"
  return 0
}

assert_file_exists() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    echo "✗ File not found: $file"
    return 1
  fi
  echo "✓ File exists: $file"
  return 0
}

assert_command_succeeds() {
  local cmd="$*"
  if ! $cmd; then
    echo "✗ Command failed: $cmd"
    return 1
  fi
  echo "✓ Command succeeded: $cmd"
  return 0
}

# Mock data generation
generate_test_project() {
  # Creates minimal Xcode project for testing
}

generate_flow_definition() {
  # Creates sample flow JSON
}

# Cleanup
cleanup_test_artifacts() {
  rm -rf test-output/
  xcrun simctl shutdown all
}
```

### Using Test Utilities

```bash
#!/bin/bash
source lib/testUtils.sh

test_example() {
  # Setup
  generate_test_project
  
  # Execute
  ./BuildAgent.sh --scheme TestApp
  
  # Assert
  assert_file_exists "build/TestApp.app"
  assert_command_succeeds cat logs/build-output.log
  
  # Cleanup
  cleanup_test_artifacts
}

run_test test_example
```

---

## CI/CD Integration

### GitHub Actions

```yaml
name: Integration Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: macos-14
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Dependencies
        run: |
          cd .Foundation/Agents/phases/phase5
          ./setup.sh --dry-run
      
      - name: Run Integration Tests
        run: |
          cd .Foundation/Agents/phases/phase5
          ./test-all-agents.sh --verbose
      
      - name: Upload Test Results
        if: always()
        uses: actions/upload-artifact@v3
        with:
          name: test-results
          path: .Foundation/Agents/phases/phase5/test-output/
      
      - name: Upload Coverage
        if: always()
        uses: codecov/codecov-action@v3
        with:
          files: .Foundation/Agents/phases/phase5/coverage.xml
```

### GitLab CI

```yaml
integration-tests:
  stage: test
  tags:
    - macos
  script:
    - cd .Foundation/Agents/phases/phase5
    - ./setup.sh
    - ./test-all-agents.sh --verbose --coverage
  artifacts:
    reports:
      junit: test-output/junit.xml
      coverage_report:
        coverage_format: cobertura
        path: coverage.xml
  coverage: '/Coverage: \d+\.\d+%/'
```

---

## Writing New Tests

### Test Template

```bash
#!/bin/bash

# test-myfeature.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/testUtils.sh"

test_myfeature_basic() {
  echo "Testing: MyFeature basic functionality"
  
  # Setup
  local test_dir=$(mktemp -d)
  cd "$test_dir"
  
  # Execute
  "${SCRIPT_DIR}/MyFeature.sh" --option value
  
  # Assert
  assert_file_exists "output.txt"
  assert_equals "expected" "$(cat output.txt)"
  
  # Cleanup
  cd -
  rm -rf "$test_dir"
  
  echo "✓ test_myfeature_basic passed"
}

test_myfeature_edge_case() {
  echo "Testing: MyFeature edge case"
  
  # ... similar structure
  
  echo "✓ test_myfeature_edge_case passed"
}

# Run all tests
main() {
  local failed=0
  
  test_myfeature_basic || ((failed++))
  test_myfeature_edge_case || ((failed++))
  
  if [[ $failed -eq 0 ]]; then
    echo "All tests passed!"
    return 0
  else
    echo "$failed test(s) failed"
    return 1
  fi
}

main "$@"
```

### Best Practices

1. **Isolation**: Each test should be independent
2. **Cleanup**: Always clean up test artifacts
3. **Assertions**: Use helper functions for consistent output
4. **Mocking**: Mock external dependencies when possible
5. **Speed**: Optimize for fast execution
6. **Reliability**: Tests should be deterministic
7. **Documentation**: Describe what each test verifies

---

## See Also

- [Agent Reference](AGENT_REFERENCE.md) - Agent documentation
- [Workflow Examples](WORKFLOW_EXAMPLES.md) - Usage examples
- [Troubleshooting](TROUBLESHOOTING.md) - Common issues
- [Test Runner Script](../Agents/phases/phase5/test-all-agents.sh) - Test execution script

---

**Last Updated**: January 2026  
**Version**: 3.0  
**Test Coverage**: 85%+ across all components
