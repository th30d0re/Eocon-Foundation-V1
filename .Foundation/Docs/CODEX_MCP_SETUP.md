# Codex CLI MCP Server Setup

## Status: ✅ Configured

The XcodeBuildMCP server has been successfully added to Codex CLI and is ready to use.

> **See also**: [Gemini CLI MCP Setup](GEMINI_MCP_SETUP.md) for Gemini CLI configuration

## Configuration

### XcodeBuildMCP Server
- **Name**: `xcodebuildmcp`
- **Status**: ✅ Enabled
- **Transport**: stdio
- **Command**: `node /Users/emmanuel/.smithery/cache/servers/cameroncooke/xcodebuildmcp/current/index.cjs`
- **Tools Available**: 71 MCP tools

### Verification

```bash
# List all MCP servers
codex mcp list

# Get details about xcodebuildmcp
codex mcp get xcodebuildmcp
```

Expected output:
```
Name           Command  Args                                                                                  Env  Cwd  Status   Auth       
xcodebuildmcp  node     /Users/emmanuel/.smithery/cache/servers/cameroncooke/xcodebuildmcp/current/index.cjs  -    -    enabled  Unsupported
```

## Usage

### Using Codex CLI with MCP Tools

When you run Codex CLI, it will automatically have access to all 71 XcodeBuildMCP tools:

```bash
# Codex will have access to Xcode tools automatically
codex exec --full-auto "Build the Foundation app for iOS"

# Or in interactive mode
codex "What simulators are available?"
```

### Available Tool Categories

The Codex agent now has access to:

- **Build Tools** (15): build, clean, analyze
- **Test Tools** (12): run_tests, debug_test
- **Simulator Tools** (19): boot, list, manage simulators
- **Device Tools** (14): list, install, manage devices
- **UI Testing** (11): describe_ui, accessibility_audit
- **Debugging** (8): attach_debugger, set_breakpoint
- **Swift Package** (6): spm_build, spm_resolve
- **macOS** (11): build, run, test macOS apps
- **Project Discovery** (5): discover projects, list schemes
- **Session Management** (3): set defaults, show defaults
- **Utilities** (1): doctor

### Example Commands

```bash
# Build the app
codex exec --full-auto "Build the Foundation scheme for iOS Simulator"

# Run tests
codex exec --full-auto "Run tests for Foundation scheme on iPhone 17 Pro"

# List simulators
codex "List all available iOS simulators"

# Describe UI
codex "Describe the UI elements in the running Foundation app"

# Set session defaults
codex "Set Xcode session defaults: project Foundation.xcodeproj, scheme Foundation, simulator iPhone 17 Pro"
```

## Managing MCP Servers

### List Servers
```bash
codex mcp list
```

### Get Server Details
```bash
codex mcp get xcodebuildmcp
```

### Remove Server
```bash
codex mcp remove xcodebuildmcp
```

### Add Another Server
```bash
# For stdio transport (like XcodeBuildMCP)
codex mcp add <name> -- <command> [args...]

# For HTTP transport
codex mcp add <name> --url <url> [--bearer-token-env-var <ENV_VAR>]
```

### Environment Variables
You can set environment variables for MCP servers:

```bash
codex mcp add myserver --env KEY=value -- <command>
```

## Integration with BuildAgent

The Codex CLI with MCP support can be used with BuildAgent:

```bash
# BuildAgent will use Codex with MCP tools available
.Foundation/Agents/phases/phase5/BuildAgent.sh \
  --ai-provider codex \
  --yolo \
  --plans-dir <dir> \
  --prompt "description"
```

## Configuration File

MCP server configurations are stored in `~/.codex/config.toml`. The XcodeBuildMCP server is configured as a global MCP server.

## Troubleshooting

### Server Not Available

1. **Check server status**:
   ```bash
   codex mcp list
   ```

2. **Verify server path**:
   ```bash
   ls -la /Users/emmanuel/.smithery/cache/servers/cameroncooke/xcodebuildmcp/current/index.cjs
   ```

3. **Test server manually**:
   ```bash
   node /Users/emmanuel/.smithery/cache/servers/cameroncooke/xcodebuildmcp/current/index.cjs
   ```

### Tools Not Appearing

- Ensure the server is enabled: `codex mcp list` should show `enabled`
- Restart Codex CLI after adding servers
- Check server logs for errors

### Permission Issues

- Ensure Node.js can execute the server file
- Check file permissions: `chmod +x /path/to/index.cjs` if needed

## Next Steps

1. ✅ XcodeBuildMCP server added to Codex CLI
2. ✅ Server is enabled and ready
3. 🎯 Start using Codex with Xcode tools!

You can now:
- Use Codex CLI with full Xcode MCP tool access
- Build, test, and debug via Codex commands
- Manage simulators and devices through Codex
- Use UI automation tools in Codex sessions

---

**Last Updated**: January 12, 2026  
**Version**: 1.0
