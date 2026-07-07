# Xcode MCP Server Setup Guide

## Status: ✅ Fully Configured

The XcodeBuildMCP server is set up and ready to use with the Foundation project.

## Current Configuration

### XcodeBuildMCP Server
- **Status**: ✅ Running (71 tools available)
- **Version**: 1.15.1
- **Server**: `user-xcodebuildmcp`
- **Tools Available**: 71 MCP tools across 13 categories

### Session Defaults
```json
{
  "projectPath": "${EOCON_PROJECT_ROOT:-$HOME/Dev/Tools/Eocon-Foundation-V1}/Foundation/Foundation.xcodeproj",
  "scheme": "Foundation",
  "simulatorName": "iPhone 17 Pro",
  "useLatestOS": true
}
```

### Available Tools Categories
- **Build Tools**: 15 tools (build, clean, analyze)
- **Test Tools**: 12 tools (run_tests, debug_test)
- **Simulator Tools**: 19 tools (boot, list, manage simulators)
- **Device Tools**: 14 tools (list, install, manage devices)
- **UI Testing**: 11 tools (describe_ui, accessibility_audit)
- **Debugging**: 8 tools (attach_debugger, set_breakpoint)
- **Swift Package**: 6 tools (spm_build, spm_resolve)
- **macOS**: 11 tools (build, run, test macOS apps)
- **Project Discovery**: 5 tools (discover projects, list schemes)
- **Session Management**: 3 tools (set defaults, show defaults)
- **Utilities**: 1 tool (doctor)

## CLI Integration

### Codex CLI Setup

**Status**: ✅ Installed and Configured

- **CLI Location**: `$HOME/.bun/bin/codex`
- **API Key**: ✅ Set (OPENAI_API_KEY)
- **Provider**: OpenAI Codex
- **MCP Server**: ✅ Added (`xcodebuildmcp`)
- **See**: [Codex CLI MCP Setup](CODEX_MCP_SETUP.md)

### Gemini CLI Setup

**Status**: ✅ Installed and Configured

- **CLI Location**: `/opt/homebrew/bin/gemini`
- **Version**: 0.23.0
- **API Key**: ✅ Set (GOOGLE_API_KEY)
- **Provider**: Google Gemini
- **MCP Server**: ✅ Added (`xcodebuildmcp`)
- **See**: [Gemini CLI MCP Setup](GEMINI_MCP_SETUP.md)

### Usage with BuildAgent

The Codex CLI can be used with BuildAgent:

```bash
# Run BuildAgent with Codex provider
.Foundation/Agents/phases/phase5/BuildAgent.sh \
  --ai-provider codex \
  --plans-dir <dir> \
  --prompt "description"

# YOLO mode (fully automated)
.Foundation/Agents/phases/phase5/BuildAgent.sh \
  --ai-provider codex \
  --yolo \
  --plans-dir <dir> \
  --prompt "description"
```

### Environment Variables

```bash
# Required for Codex/OpenAI
export OPENAI_API_KEY=sk-...

# Optional: Model override
export OPENAI_MODEL=gpt-5-codex
```

## Quick Start Examples

### Using XcodeBuildMCP Tools

The MCP server provides direct access to Xcode operations:

**Build the app:**
```
AI: "Build the Foundation app for iOS"
→ Uses: build_sim() with session defaults
```

**Run tests:**
```
AI: "Run tests on iPhone 17 Pro"
→ Uses: test_sim() with session defaults
```

**List simulators:**
```
AI: "What simulators are available?"
→ Uses: list_sims()
```

**Describe UI:**
```
AI: "What UI elements are visible?"
→ Uses: describe_ui()
```

### Using Codex CLI Directly

```bash
# Check version/help
codex --version
codex --help

# Use with BuildAgent
BuildAgent.sh --ai-provider codex --prompt "Your prompt here"

# Use with MCP tools
codex exec --full-auto "Build the Foundation app"
```

### Using Gemini CLI Directly

```bash
# Check version/help
gemini --version
gemini --help

# Use with BuildAgent
BuildAgent.sh --ai-provider gemini --prompt "Your prompt here"

# Use with MCP tools
gemini --yolo "Build the Foundation app"
```

## Verification

### Check XcodeBuildMCP Status
```bash
# From AI: Use mcp_xcodebuildmcp_doctor tool
# Or check MCP resources: list_mcp_resources
```

### Check Codex CLI
```bash
which codex
codex --version
echo $OPENAI_API_KEY | head -c 10  # Should show first 10 chars
```

### Check Session Defaults
```bash
# From AI: Use mcp_xcodebuildmcp_session-show-defaults
```

## Troubleshooting

### XcodeBuildMCP Issues

1. **Server not responding**
   - Check Cursor MCP settings
   - Restart Cursor
   - Verify server is enabled in Cursor settings

2. **Missing session defaults**
   - Set defaults: `mcp_xcodebuildmcp_session-set-defaults`
   - Verify project path exists
   - Check scheme name matches

3. **Simulator not found**
   - List simulators: `mcp_xcodebuildmcp_list_sims`
   - Use exact simulator name or UUID
   - Boot simulator first if needed

### Codex CLI Issues

1. **Command not found**
   ```bash
   # Install via pip
   pip install openai-cli
   
   # Or via npm
   npm install -g @openai/cli
   ```

2. **API key not set**
   ```bash
   export OPENAI_API_KEY=sk-...
   # Add to ~/.zshrc or ~/.bashrc for persistence
   ```

3. **Authentication failed**
   - Verify API key at: https://platform.openai.com/api-keys
   - Check key has proper permissions
   - Ensure key is not expired

## Advanced Configuration

### Custom Session Defaults

```bash
# Set custom defaults via MCP
mcp_xcodebuildmcp_session-set-defaults {
  "projectPath": "/path/to/project.xcodeproj",
  "scheme": "YourScheme",
  "simulatorName": "iPhone 15 Pro",
  "configuration": "Debug",
  "useLatestOS": true
}
```

### BuildAgent with Codex

The BuildAgent automatically detects and uses Codex CLI when:
- `--ai-provider codex` is specified
- `codex` command is available in PATH
- `OPENAI_API_KEY` environment variable is set

### MCP Tool Usage

All 71 MCP tools are available for AI-driven development:
- Build operations
- Test execution
- Simulator management
- Device operations
- UI automation
- Debugging
- Swift Package Manager operations

See `.Foundation/Docs/FEATURES.md` for complete MCP integration documentation.

## Next Steps

1. ✅ XcodeBuildMCP server is configured
2. ✅ Session defaults are set for Foundation project
3. ✅ Codex CLI is installed and configured
4. 🎯 Ready to use!

You can now:
- Use MCP tools for Xcode operations
- Run BuildAgent with `--ai-provider codex`
- Build, test, and debug via AI commands

---

**Last Updated**: January 12, 2026  
**Version**: 1.0
