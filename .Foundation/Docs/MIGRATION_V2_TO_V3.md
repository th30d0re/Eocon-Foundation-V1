# Migration Guide: v2.2 to v3.0

This guide helps you migrate from Eocon Foundation Build System v2.2 to v3.0.

## Table of Contents

- [Overview](#overview)
- [What's New](#whats-new)
- [Breaking Changes](#breaking-changes)
- [Step-by-Step Migration](#step-by-step-migration)
- [Compatibility Matrix](#compatibility-matrix)
- [Flag Mapping](#flag-mapping)
- [Troubleshooting Migration](#troubleshooting-migration)
- [Rollback Instructions](#rollback-instructions)

---

## Overview

v3.0 is a feature-rich update focused on performance, developer experience, and AI integration. The migration is designed to be **non-breaking** for most users, with automatic upgrades and backward compatibility.

**Estimated Migration Time**: 10-15 minutes

**Key Improvements**:
- ⚡ Up to 10x faster rebuilds with incremental builds
- 🎨 Beautiful terminal UI with themes
- 🌍 Multi-platform support (iOS, macOS, tvOS, watchOS, visionOS)
- 💾 Session management for saved configurations
- 🤖 71 MCP tools for AI integration

---

## What's New

### Major Features

#### 1. Incremental Builds
- **xcodemake integration** for intelligent caching
- Up to 10x faster rebuild times
- Enable with `--enable-incremental` flag

#### 2. Enhanced UI System
- Beautiful terminal output with Catppuccin-inspired themes
- Progress bars, spinners, and status indicators
- Dark and light theme support
- Enable with `export BUILDAGENT_FANCY_UI=true`

#### 3. Multi-Platform Support
- Unified platform detection and management
- Support for iOS, macOS, tvOS, watchOS, visionOS
- Use `--platform <name>` flag

#### 4. Session Management
- Save and reuse build configurations
- Persistent session defaults in `~/.eocon-session-defaults.json`
- Use `--save-session-defaults` to save

#### 5. Log Streaming
- Real-time log capture and analysis
- Structured logging for AI consumption
- Enable with `--capture-logs`

#### 6. UI Automation
- AXe integration for accessibility testing
- UI hierarchy inspection
- Flow-based testing

#### 7. XcodeBuildMCP Integration
- 71 MCP tools for AI-driven development
- Comprehensive build, test, and debug capabilities
- Seamless integration with agents

### Minor Improvements

- Better error messages with actionable suggestions
- Improved dependency detection
- Enhanced simulator management
- Graceful degradation for missing dependencies
- Comprehensive documentation and examples

---

## Breaking Changes

### ⚠️ None for Standard Usage

v3.0 maintains **backward compatibility** with v2.2 for all standard workflows. Your existing scripts should work without modification.

### Optional Migration Items

These are **recommended** but not required:

1. **Session Defaults Format**
   - Old: No structured format
   - New: JSON format in `~/.eocon-session-defaults.json`
   - Migration: Automatic via `migrate-v2-to-v3.sh`

2. **Environment Variables**
   - Old: No UI customization variables
   - New: `BUILDAGENT_FANCY_UI`, `BUILDAGENT_THEME`, etc.
   - Migration: Optional, add to shell RC file

3. **Dependency Management**
   - Old: Manual dependency installation
   - New: Automated via `setup.sh`
   - Migration: Run `setup.sh` once

---

## Step-by-Step Migration

### Prerequisites

- Xcode 14.0 or later
- macOS 12.0 or later
- Shell: bash or zsh

### Step 1: Backup Your Configuration

```bash
# The migration script creates automatic backups, but you can also:
cp ~/.eocon-session-defaults.json ~/.eocon-session-defaults.json.backup 2>/dev/null || true
```

### Step 2: Run Migration Script

```bash
cd .Foundation/Agents/phases/phase5

# Dry run first (recommended)
./migrate-v2-to-v3.sh --dry-run

# Actual migration
./migrate-v2-to-v3.sh
```

The script will:
1. ✅ Create backup in `~/.eocon-foundation-backup-TIMESTAMP/`
2. ✅ Migrate session defaults to v3.0 format
3. ✅ Check for new dependencies
4. ✅ Optionally update your shell configuration
5. ✅ Verify migration success

### Step 3: Install New Dependencies

```bash
# Run setup script
./setup.sh

# Or dry-run to see what would be installed
./setup.sh --dry-run
```

The setup script installs:
- **xcodemake** - Incremental build tool (optional but recommended)
- **AXe** - UI automation tool (optional)
- **jq** - JSON processor (required for session defaults)
- **Node.js** - For XcodeBuildMCP (optional)

### Step 4: Update Environment Variables (Optional)

Add to your `~/.zshrc` or `~/.bashrc`:

```bash
# Eocon Foundation v3.0
export BUILDAGENT_FANCY_UI=true
export BUILDAGENT_THEME=dark  # or 'light'
export BUILDAGENT_SHOW_TIPS=true
```

Then reload:

```bash
source ~/.zshrc  # or ~/.bashrc
```

### Step 5: Test Your Existing Workflows

```bash
# Test with your existing build command
./BuildAgent.sh --scheme YourScheme --simulator-name "iPhone 15 Pro"

# Or use session defaults
./BuildAgent.sh --save-session-defaults \
  --scheme YourScheme \
  --simulator-name "iPhone 15 Pro"

# Then simply:
./BuildAgent.sh
```

### Step 6: Enable New Features Incrementally

```bash
# Try incremental builds
./BuildAgent.sh --enable-incremental

# Try log capture
./BuildAgent.sh --capture-logs

# Try UI automation (if AXe installed)
./accessibilityAgent.sh \
  --simulator-name "iPhone 15 Pro" \
  --bundle-id com.example.YourApp
```

### Step 7: Explore New Workflows

See [Workflow Examples](WORKFLOW_EXAMPLES.md) for 10+ ready-to-use workflows.

---

## Compatibility Matrix

| Feature | v2.2 | v3.0 | Notes |
|---------|------|------|-------|
| **Basic Build** | ✅ | ✅ | Fully compatible |
| **Testing** | ✅ | ✅ | Fully compatible |
| **Simulator Management** | ✅ | ✅ | Enhanced in v3.0 |
| **Platform Support** | iOS only | iOS, macOS, tvOS, watchOS, visionOS | New platforms in v3.0 |
| **Incremental Builds** | ❌ | ✅ | New in v3.0 |
| **Session Defaults** | Basic | JSON-based | Enhanced in v3.0 |
| **UI Theming** | ❌ | ✅ | New in v3.0 |
| **Log Streaming** | Basic | Structured | Enhanced in v3.0 |
| **UI Automation** | ❌ | ✅ AXe | New in v3.0 |
| **MCP Integration** | Basic | 71 tools | Enhanced in v3.0 |

---

## Flag Mapping

### Changed Flags

| v2.2 Flag | v3.0 Flag | Notes |
|-----------|-----------|-------|
| (No changes - all v2.2 flags still work) |||

### New Flags in v3.0

| Flag | Purpose |
|------|---------|
| `--enable-incremental` | Enable xcodemake incremental builds |
| `--platform <name>` | Specify target platform |
| `--capture-logs` | Enable structured log capture |
| `--auto-simulator` | Auto-boot simulator if needed |
| `--no-auto-simulator` | Disable auto-boot |
| `--no-capture-logs` | Disable log capture |
| `--save-session-defaults` | Save current configuration |
| `--use-session-defaults` | Use saved configuration (default: true) |
| `--no-session-defaults` | Ignore saved configuration |
| `--show-session-defaults` | Display saved configuration |
| `--clear-session-defaults` | Clear saved configuration |

### Deprecated Flags

**None** - All v2.2 flags remain functional.

---

## Troubleshooting Migration

### Issue: Migration Script Fails

**Symptom**: `migrate-v2-to-v3.sh` exits with error

**Solutions**:
```bash
# 1. Check if jq is installed
brew install jq

# 2. Run with dry-run to see what would happen
./migrate-v2-to-v3.sh --dry-run

# 3. Check backup directory permissions
ls -la ~/
```

### Issue: Session Defaults Not Working

**Symptom**: Flags not being read from session defaults

**Solutions**:
```bash
# 1. Verify session file exists and is valid JSON
cat ~/.eocon-session-defaults.json | jq .

# 2. Check version field
jq -r '.version' ~/.eocon-session-defaults.json

# 3. Re-save session defaults
./BuildAgent.sh --save-session-defaults --scheme YourScheme

# 4. Manually fix JSON if needed
nano ~/.eocon-session-defaults.json
```

### Issue: xcodemake Not Found

**Symptom**: `--enable-incremental` fails with "xcodemake not found"

**Solutions**:
```bash
# 1. Run setup script
./setup.sh

# 2. Or manually install
curl -fsSL https://github.com/subdigital/xcodemake/releases/latest/download/xcodemake -o /tmp/xcodemake
chmod +x /tmp/xcodemake
sudo mv /tmp/xcodemake /usr/local/bin/

# 3. Verify installation
xcodemake --version
```

### Issue: AXe Not Available

**Symptom**: UI automation features don't work

**Solutions**:
```bash
# 1. Install AXe
brew tap cameroncooke/axe
brew install axe

# 2. Verify installation
axe --version

# 3. Agents gracefully degrade if AXe unavailable
# No action needed if you don't need UI automation
```

### Issue: Fancy UI Not Appearing

**Symptom**: No visual improvements in terminal

**Solutions**:
```bash
# 1. Enable fancy UI
export BUILDAGENT_FANCY_UI=true

# 2. Check terminal capabilities
echo $TERM  # Should be xterm-256color or similar

# 3. Try light theme if dark doesn't work
export BUILDAGENT_THEME=light

# 4. Disable if terminal incompatible
export BUILDAGENT_FANCY_UI=false
```

### Issue: Performance Regression

**Symptom**: Builds slower than v2.2

**Solutions**:
```bash
# 1. Disable new features one by one
./BuildAgent.sh --no-capture-logs --no-auto-simulator

# 2. Check if fancy UI causing slowness
export BUILDAGENT_FANCY_UI=false

# 3. Enable incremental builds for speedup
./BuildAgent.sh --enable-incremental

# 4. Check for disk space issues
df -h
```

---

## Rollback Instructions

If you need to rollback to v2.2:

### Option 1: Use Backup

```bash
# The migration script created a backup directory
~/$ ls ~/.eocon-foundation-backup-*/

# Run restore script
~/.eocon-foundation-backup-TIMESTAMP/restore-backup.sh
```

### Option 2: Manual Rollback

```bash
# 1. Restore session defaults from backup
cp ~/.eocon-session-defaults.json.backup ~/.eocon-session-defaults.json

# 2. Remove environment variables from shell RC
nano ~/.zshrc  # or ~/.bashrc
# Remove the v3.0 environment variables

# 3. Reload shell
source ~/.zshrc
```

### Option 3: Git Revert (if applicable)

```bash
# If agents are in git repository
cd .Foundation/Agents/phases/phase5
git log  # Find v2.2 commit
git checkout <v2.2-commit-hash>
```

---

## Post-Migration Checklist

- [ ] Migration script completed successfully
- [ ] Session defaults working (`--show-session-defaults`)
- [ ] Existing build commands still work
- [ ] New dependencies installed (run `setup.sh --dry-run`)
- [ ] Environment variables added to shell RC (optional)
- [ ] Fancy UI enabled and working (optional)
- [ ] Incremental builds tested (optional)
- [ ] Reviewed new workflows in [WORKFLOW_EXAMPLES.md](WORKFLOW_EXAMPLES.md)
- [ ] Read [UI_CUSTOMIZATION.md](UI_CUSTOMIZATION.md) for theming
- [ ] Bookmarked [TROUBLESHOOTING.md](TROUBLESHOOTING.md)

---

## Getting Help

If you encounter issues during migration:

1. **Check Troubleshooting**: [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
2. **Review Examples**: [WORKFLOW_EXAMPLES.md](WORKFLOW_EXAMPLES.md)
3. **Run Diagnostics**: `./setup.sh --dry-run`
4. **Check Logs**: Review migration output and backup directory
5. **Ask for Help**: Open an issue with migration output

---

## Next Steps

After successful migration:

1. ✅ **Explore New Features**: Try incremental builds, UI automation
2. ✅ **Customize UI**: Set up themes and preferences
3. ✅ **Set Up Session Defaults**: Save your common configurations
4. ✅ **Try Example Workflows**: See [WORKFLOW_EXAMPLES.md](WORKFLOW_EXAMPLES.md)
5. ✅ **Integrate with AI**: Explore XcodeBuildMCP tools

Welcome to v3.0! 🎉

---

**Last Updated**: January 2026  
**Version**: 3.0  
**Migration Script**: `migrate-v2-to-v3.sh`
