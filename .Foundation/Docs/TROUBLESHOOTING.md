# Troubleshooting Guide

Comprehensive troubleshooting for Eocon Foundation Build System issues.

## Table of Contents

- [Common Issues](#common-issues)
- [Build Failures](#build-failures)
- [Simulator Issues](#simulator-issues)
- [Log Capture Issues](#log-capture-issues)
- [Session Issues](#session-issues)
- [UI Issues](#ui-issues)
- [MCP Integration Issues](#mcp-integration-issues)
- [Dependency Issues](#dependency-issues)
- [Performance Issues](#performance-issues)
- [Diagnostic Tools](#diagnostic-tools)

---

## Common Issues

### Issue: Command Not Found

**Symptom**:
```
bash: ./BuildAgent.sh: No such file or directory
```

**Solutions**:

```bash
# 1. Check you're in the correct directory
cd .Foundation/Agents/phases/phase5
ls -la BuildAgent.sh

# 2. Verify script is executable
chmod +x BuildAgent.sh

# 3. Use full path
./BuildAgent.sh

# 4. Check symlinks aren't broken
file BuildAgent.sh
```

### Issue: Permission Denied

**Symptom**:
```
Permission denied: ./BuildAgent.sh
```

**Solutions**:

```bash
# Make script executable
chmod +x BuildAgent.sh
chmod +x lib/*.sh

# Or make all agent scripts executable
chmod +x *.sh
```

### Issue: jq Command Not Found

**Symptom**:
```
jq: command not found
```

**Solutions**:

```bash
# Install via Homebrew
brew install jq

# Or run setup script
./setup.sh

# Verify installation
jq --version
```

---

## Build Failures

### Issue: Scheme Not Found

**Symptom**:
```
Error: Scheme 'MyApp' not found
```

**Solutions**:

```bash
# 1. List available schemes
xcodebuild -list

# 2. Use correct scheme name (case-sensitive)
./BuildAgent.sh --scheme "My App"  # Note the space

# 3. Check workspace vs project
xcodebuild -workspace MyApp.xcworkspace -list
xcodebuild -project MyApp.xcodeproj -list

# 4. Verify scheme is shared
# In Xcode: Product > Scheme > Manage Schemes > Check "Shared"
```

### Issue: Build Fails with Macro Validation Error

**Symptom**:
```
Error: Macro expansion failed
```

**Solutions**:

```bash
# 1. Check macro compatibility
swift --version  # Should be Swift 5.9+

# 2. Clean build
./BuildAgent.sh --clean --scheme MyApp

# 3. Disable macro validation temporarily
./BuildLint.sh --scheme MyApp  # Without --check-macros

# 4. Update macros
# In Xcode: File > Packages > Update to Latest Package Versions
```

### Issue: Incremental Build Fails

**Symptom**:
```
xcodemake: Error building incrementally
```

**Solutions**:

```bash
# 1. Verify xcodemake installed
xcodemake --version

# 2. Fall back to full build
./BuildAgent.sh --scheme MyApp  # Without --enable-incremental

# 3. Clean incremental cache
rm -rf ~/Library/Caches/xcodemake

# 4. Reinstall xcodemake
brew reinstall xcodemake
# Or via setup
./setup.sh
```

### Issue: Signing Errors

**Symptom**:
```
Error: Code signing failed
```

**Solutions**:

```bash
# 1. For simulator builds, use automatic signing
# In Xcode: Target > Signing & Capabilities > Automatically manage signing

# 2. Check provisioning profiles
security find-identity -v -p codesigning

# 3. Use specific configuration
./BuildAgent.sh --scheme MyApp --configuration Debug

# 4. For CI/CD, disable signing for simulator
xcodebuild -scheme MyApp -sdk iphonesimulator CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO
```

---

## Simulator Issues

### Issue: Simulator Won't Boot

**Symptom**:
```
Error: Unable to boot simulator 'iPhone 15 Pro'
Timed out waiting for simulator to boot
```

**Solutions**:

```bash
# 1. Check simulator status
xcrun simctl list devices

# 2. Boot manually
xcrun simctl boot "iPhone 15 Pro"

# 3. Force quit Simulator.app
killall Simulator
xcrun simctl shutdown all

# 4. Recreate simulator
xcrun simctl delete "iPhone 15 Pro"
xcrun simctl create "iPhone 15 Pro" com.apple.CoreSimulator.SimDeviceType.iPhone-15-Pro com.apple.CoreSimulator.SimRuntime.iOS-17-0

# 5. Reset simulator
xcrun simctl erase "iPhone 15 Pro"

# 6. Check system resources
# Free up disk space and RAM
```

### Issue: Simulator Not Found

**Symptom**:
```
Error: Simulator 'iPhone 15 Pro' not found
```

**Solutions**:

```bash
# 1. List available simulators
xcrun simctl list devices

# 2. Use exact name (with quotes if spaces)
./BuildAgent.sh --simulator-name "iPhone 15 Pro"

# 3. Create simulator if missing
xcrun simctl create "iPhone 15 Pro" \
  com.apple.CoreSimulator.SimDeviceType.iPhone-15-Pro \
  com.apple.CoreSimulator.SimRuntime.iOS-17-0

# 4. Use UDID instead of name
./BuildAgent.sh --destination "platform=iOS Simulator,id=UDID-HERE"
```

### Issue: Location Services Not Working

**Symptom**:
```
Warning: Failed to set simulator location
```

**Solutions**:

```bash
# 1. Grant location access
# System Settings > Privacy & Security > Location Services > Simulator

# 2. Reset location and privacy
xcrun simctl privacy "iPhone 15 Pro" reset all

# 3. Manually set location
xcrun simctl location "iPhone 15 Pro" set 37.7749,-122.4194
```

---

## Log Capture Issues

### Issue: Permission Denied Writing Logs

**Symptom**:
```
Error: Permission denied: logs/build-output.log
```

**Solutions**:

```bash
# 1. Create logs directory
mkdir -p logs
chmod 755 logs

# 2. Check disk space
df -h .

# 3. Verify write permissions
touch logs/test.log && rm logs/test.log

# 4. Use different log location
export BUILDAGENT_LOG_DIR="$HOME/build-logs"
./BuildAgent.sh --capture-logs
```

### Issue: Logs Not Being Captured

**Symptom**: No log files created even with `--capture-logs`

**Solutions**:

```bash
# 1. Verify flag is set
./BuildAgent.sh --capture-logs --verbose

# 2. Check log_capture.sh exists
ls -la lib/log_capture.sh

# 3. Source library manually
source lib/log_capture.sh
start_log_capture "test"

# 4. Check for errors in stderr
./BuildAgent.sh --capture-logs 2>&1 | tee debug.log
```

### Issue: Log Files Too Large

**Symptom**: Log files consuming excessive disk space

**Solutions**:

```bash
# 1. Clean old logs
rm -rf logs/*.log
rm -rf logs/*.xcresult

# 2. Implement log rotation
find logs -name "*.log" -mtime +7 -delete

# 3. Compress old logs
gzip logs/*.log

# 4. Limit log size in configuration
export BUILDAGENT_MAX_LOG_SIZE=10485760  # 10MB
```

---

## Session Issues

### Issue: Session Defaults Not Loading

**Symptom**: Must specify all flags even after saving session defaults

**Solutions**:

```bash
# 1. Verify session file exists
ls -la ~/.eocon-session-defaults.json

# 2. Check JSON validity
cat ~/.eocon-session-defaults.json | jq .

# 3. Show current session defaults
./BuildAgent.sh --show-session-defaults

# 4. Re-save session defaults
./BuildAgent.sh --save-session-defaults \
  --scheme MyApp \
  --simulator-name "iPhone 15 Pro"

# 5. Check file permissions
chmod 644 ~/.eocon-session-defaults.json
```

### Issue: Session File Corrupted

**Symptom**:
```
Error: Failed to parse session defaults
```

**Solutions**:

```bash
# 1. Validate JSON
cat ~/.eocon-session-defaults.json | jq .

# 2. Restore from backup (if exists)
cp ~/.eocon-session-defaults.json.backup ~/.eocon-session-defaults.json

# 3. Clear and recreate
./BuildAgent.sh --clear-session-defaults
./BuildAgent.sh --save-session-defaults --scheme MyApp

# 4. Manually fix JSON
nano ~/.eocon-session-defaults.json
```

### Issue: Session Defaults Not Being Used

**Symptom**: Command-line flags override session defaults unexpectedly

**Solutions**:

```bash
# This is correct behavior - flag precedence:
# 1. Command-line flags (highest)
# 2. Environment variables
# 3. Configuration file
# 4. Session defaults
# 5. Built-in defaults (lowest)

# To force session defaults, remove CLI flags
./BuildAgent.sh  # Uses session defaults

# To ignore session defaults
./BuildAgent.sh --no-session-defaults --scheme MyApp
```

---

## UI Issues

### Issue: Fancy UI Not Appearing

**Symptom**: Plain text output instead of styled UI

**Solutions**:

```bash
# 1. Enable fancy UI
export BUILDAGENT_FANCY_UI=true

# 2. Check terminal type
echo $TERM  # Should be xterm-256color or similar

# 3. Verify not in CI mode
echo $CI  # Should be empty

# 4. Check NO_COLOR
echo $NO_COLOR  # Should be empty or 0

# 5. Test terminal capabilities
tput colors  # Should be 256

# 6. Force enable (bypass detection)
BUILDAGENT_FANCY_UI=true TERM=xterm-256color ./BuildAgent.sh
```

### Issue: Unicode Characters Display as Boxes

**Symptom**: `�` or `□` instead of box-drawing characters

**Solutions**:

```bash
# 1. Check locale
locale | grep UTF-8

# 2. Set UTF-8 locale
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# 3. Use ASCII fallback
export BUILDAGENT_ASCII_ONLY=true

# 4. Update terminal font
# Use a font with Unicode support (e.g., SF Mono, Fira Code, JetBrains Mono)
```

### Issue: Colors Look Wrong

**Symptom**: Colors don't match theme or look washed out

**Solutions**:

```bash
# 1. Try different theme
export BUILDAGENT_THEME=light  # If using dark terminal
export BUILDAGENT_THEME=dark   # If using light terminal

# 2. Check terminal color settings
# iTerm2: Preferences > Profiles > Colors
# Terminal.app: Preferences > Profiles > [Your Profile]

# 3. Disable if problematic
export NO_COLOR=1

# 4. Test 256-color support
for i in {0..255}; do
  printf "\x1b[38;5;${i}mcolor${i} "
done
echo
```

---

## MCP Integration Issues

### Issue: MCP Tools Not Found

**Symptom**:
```
Error: MCP tool 'build' not found
```

**Solutions**:

```bash
# 1. Verify XcodeBuildMCP installed
cd ../../../XcodeBuildMCP
npm list

# 2. Install dependencies
npm install

# 3. Test MCP server
npx mcp run list_tools

# 4. Check path to MCP
echo $PATH | grep XcodeBuildMCP
```

### Issue: MCP Connection Timeout

**Symptom**:
```
Error: Connection to MCP server timed out
```

**Solutions**:

```bash
# 1. Check MCP server is running
ps aux | grep mcp

# 2. Restart MCP server
pkill -f "mcp"
cd ../../../XcodeBuildMCP
npm start &

# 3. Increase timeout
export MCP_TIMEOUT=60000  # 60 seconds

# 4. Check network/firewall
# Ensure localhost connections allowed
```

### Issue: MCP Tool Errors

**Symptom**: MCP tools return errors or unexpected results

**Solutions**:

```bash
# 1. Check MCP logs
cat ~/.mcp/logs/xcodebuildmcp.log

# 2. Run with verbose logging
npx mcp run build --scheme MyApp --verbose

# 3. Update XcodeBuildMCP
cd ../../../XcodeBuildMCP
git pull
npm install

# 4. Clear MCP cache
rm -rf ~/.mcp/cache
```

---

## Dependency Issues

### Issue: Xcode Command Line Tools Not Found

**Symptom**:
```
xcode-select: error: tool 'xcodebuild' requires Xcode
```

**Solutions**:

```bash
# 1. Install Command Line Tools
xcode-select --install

# 2. Set Xcode path
sudo xcode-select --switch /Applications/Xcode.app

# 3. Verify installation
xcode-select -p
xcodebuild -version

# 4. Accept Xcode license
sudo xcodebuild -license accept
```

### Issue: Homebrew Not Found

**Symptom**:
```
brew: command not found
```

**Solutions**:

```bash
# 1. Install Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 2. Add to PATH (for Apple Silicon)
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zshrc
source ~/.zshrc

# 3. Verify installation
brew --version
```

### Issue: Node.js Version Incompatible

**Symptom**:
```
Error: Node.js version 14.x required, found 12.x
```

**Solutions**:

```bash
# 1. Update Node.js via Homebrew
brew upgrade node

# 2. Or install specific version with nvm
brew install nvm
nvm install 18
nvm use 18

# 3. Verify version
node --version
npm --version
```

---

## Performance Issues

### Issue: Builds Are Slow

**Symptom**: Builds taking longer than expected

**Solutions**:

```bash
# 1. Enable incremental builds
./BuildAgent.sh --enable-incremental

# 2. Use saved session defaults
./BuildAgent.sh --save-session-defaults ...
./BuildAgent.sh  # Faster subsequent runs

# 3. Disable unnecessary features
./BuildAgent.sh --no-capture-logs

# 4. Clean derived data
rm -rf ~/Library/Developer/Xcode/DerivedData/*

# 5. Check disk space
df -h

# 6. Monitor resources
top  # Check CPU and memory usage
```

### Issue: Fancy UI Causes Slowdown

**Symptom**: Noticeable delay with fancy UI enabled

**Solutions**:

```bash
# 1. Disable fancy UI
export BUILDAGENT_FANCY_UI=false

# 2. Disable witty phrases
export BUILDAGENT_WITTY_PHRASES=false

# 3. Use simpler spinner
export BUILDAGENT_SPINNER_STYLE=classic

# 4. Run in quiet mode
./BuildAgent.sh --quiet
```

---

## Diagnostic Tools

### Doctor Command (XcodeBuildMCP)

```bash
cd ../../../XcodeBuildMCP
npx mcp run doctor

# Checks:
# - Xcode installation
# - Command Line Tools
# - Simulators
# - Dependencies
# - MCP configuration
```

### Manual Diagnostics

```bash
# System info
sw_vers
xcodebuild -version
xcode-select -p

# Dependencies
which xcodemake
which axe
which jq
which node
which npm

# Simulators
xcrun simctl list devices

# Disk space
df -h

# Permissions
ls -la ~/.eocon-session-defaults.json
ls -la logs/

# Session defaults
cat ~/.eocon-session-defaults.json | jq .

# Environment
env | grep BUILDAGENT
env | grep NO_COLOR
env | grep CI
```

### Log Collection for Bug Reports

```bash
# Create diagnostic bundle
mkdir -p ~/eocon-diagnostics
cd ~/eocon-diagnostics

# Collect logs
cp ~/.eocon-session-defaults.json ./
cp -r /path/to/project/.Foundation/Agents/phases/phase5/logs ./
cp /path/to/project/.Foundation/Agents/phases/phase5/defaults.conf ./

# Collect system info
system_profiler SPSoftwareDataType > system-info.txt
xcodebuild -version >> system-info.txt
env | grep -E '(BUILDAGENT|PATH|TERM)' >> env-vars.txt

# Create archive
tar -czf eocon-diagnostics.tar.gz ./*
echo "Diagnostic bundle: ~/eocon-diagnostics/eocon-diagnostics.tar.gz"
```

---

## Getting More Help

If issues persist after trying solutions:

1. **Check Documentation**
   - [Agent Reference](AGENT_REFERENCE.md)
   - [Workflow Examples](WORKFLOW_EXAMPLES.md)
   - [XcodeBuildMCP Troubleshooting](../../../XcodeBuildMCP/docs/TROUBLESHOOTING.md)

2. **Run Diagnostics**
   ```bash
   ./setup.sh --dry-run
   cd ../../../XcodeBuildMCP && npx mcp run doctor
   ```

3. **Create Diagnostic Bundle**
   Use the script above to collect logs

4. **Open Issue**
   - Include diagnostic bundle
   - Describe expected vs actual behavior
   - List steps to reproduce

---

**Last Updated**: January 2026  
**Version**: 3.0
