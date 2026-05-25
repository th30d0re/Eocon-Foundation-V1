# Gemini CLI MCP Server Setup

## Status: ✅ Configured

The XcodeBuildMCP server has been successfully added to Gemini CLI and is ready to use.

## Configuration

### XcodeBuildMCP Server
- **Name**: `xcodebuildmcp`
- **Status**: ✅ Connected
- **Transport**: stdio
- **Command**: `node /Users/emmanuel/.smithery/cache/servers/cameroncooke/xcodebuildmcp/current/index.cjs`
- **Tools Available**: 71 MCP tools
- **Scope**: Project-level (configured for current project)

### Verification

```bash
# List all MCP servers
gemini mcp list
```

Expected output:
```
Configured MCP servers:

✓ xcodebuildmcp: node /Users/emmanuel/.smithery/cache/servers/cameroncooke/xcodebuildmcp/current/index.cjs (stdio) - Connected
```

## Usage

### Using Gemini CLI with MCP Tools

When you run Gemini CLI in this project, it will automatically have access to all 71 XcodeBuildMCP tools:

```bash
# Gemini will have access to Xcode tools automatically
gemini "Build the Foundation app for iOS"

# With YOLO mode (auto-approve all actions)
gemini --yolo "Build and test the Foundation app"

# Interactive mode with MCP tools
gemini --prompt-interactive "Help me build the app"
```

### Available Tool Categories

The Gemini agent now has access to:

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
gemini --yolo "Build the Foundation scheme for iOS Simulator"

# Run tests
gemini --yolo "Run tests for Foundation scheme on iPhone 17 Pro"

# List simulators
gemini "List all available iOS simulators"

# Describe UI
gemini "Describe the UI elements in the running Foundation app"

# Set session defaults
gemini "Set Xcode session defaults: project Foundation.xcodeproj, scheme Foundation, simulator iPhone 17 Pro"

# Interactive session
gemini --prompt-interactive "Help me debug the Foundation app"
```

### Approval Modes

Gemini CLI supports different approval modes for tool execution:

```bash
# Default: Prompt for approval
gemini "Build the app"

# Auto-approve edit tools only
gemini --approval-mode auto_edit "Build and fix any errors"

# YOLO mode: Auto-approve all tools
gemini --yolo "Build and test everything"

# Or use the flag
gemini --approval-mode yolo "Build and test everything"
```

## Managing MCP Servers

### List Servers
```bash
gemini mcp list
```

### Add Server
```bash
# For stdio transport (like XcodeBuildMCP)
gemini mcp add <name> <command> [args...]

# Example:
gemini mcp add xcodebuildmcp node /path/to/server/index.cjs
```

### Remove Server
```bash
gemini mcp remove <name>
```

### Allowed MCP Servers

You can restrict which MCP servers are allowed:

```bash
# Only allow specific servers
gemini --allowed-mcp-server-names xcodebuildmcp "Build the app"
```

## Integration with BuildAgent

The Gemini CLI with MCP support can be used with BuildAgent:

```bash
# BuildAgent will use Gemini with MCP tools available
.Foundation/Agents/phases/phase5/BuildAgent.sh \
  --ai-provider gemini \
  --yolo \
  --plans-dir <dir> \
  --prompt "description"
```

## Configuration Storage

Gemini CLI stores MCP server configurations at the **project level**. The configuration is saved in the project directory (typically in a `.gemini/settings.json` file).

### Project-Level Configuration

- MCP servers are configured per-project
- Each project can have different MCP servers
- Configuration persists across sessions
- **Other projects won't see these servers unless explicitly added**

### Adding to Other Projects

Since Gemini CLI uses project-level configuration, you need to add the MCP server to each project where you want to use it.

#### Option 1: Use the Helper Script (Recommended)

We've created a helper script to easily add the XcodeBuildMCP server to any project:

```bash
# From the project root where you want to add the server
.Foundation/scripts/add_gemini_mcp.sh

# Or specify a project directory
.Foundation/scripts/add_gemini_mcp.sh /path/to/other/project
```

The script will:
- Create `.gemini/settings.json` if it doesn't exist
- Add the XcodeBuildMCP server configuration
- Preserve any existing MCP server configurations
- Backup existing settings before modifying

#### Option 2: Manual Configuration

1. Navigate to your project directory:
   ```bash
   cd /path/to/your/project
   ```

2. Create `.gemini` directory if it doesn't exist:
   ```bash
   mkdir -p .gemini
   ```

3. Create or edit `.gemini/settings.json`:
   ```json
   {
     "mcpServers": {
       "xcodebuildmcp": {
         "command": "node",
         "args": [
           "/Users/emmanuel/.smithery/cache/servers/cameroncooke/xcodebuildmcp/current/index.cjs"
         ]
       }
     }
   }
   ```

4. If you have existing MCP servers, merge this configuration with your existing `mcpServers` object.

#### Option 3: Use Gemini CLI Command

```bash
# Navigate to the project directory
cd /path/to/your/project

# Add the server
gemini mcp add xcodebuildmcp node /Users/emmanuel/.smithery/cache/servers/cameroncooke/xcodebuildmcp/current/index.cjs
```

### Why Project-Level?

Gemini CLI uses project-level configuration to:
- Allow different projects to have different MCP servers
- Keep project configurations isolated
- Enable project-specific tooling setups
- Support team collaboration with project-specific configs

## Troubleshooting

### Server Not Available

1. **Check server status**:
   ```bash
   gemini mcp list
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

- Ensure the server is connected: `gemini mcp list` should show `Connected`
- Restart Gemini CLI after adding servers
- Check that you're in the correct project directory
- Verify Node.js can execute the server file

### Permission Issues

- Ensure Node.js can execute the server file
- Check file permissions: `chmod +x /path/to/index.cjs` if needed
- Verify the server path is correct and accessible

### Server Connection Issues

If the server shows as not connected:

1. Check if Node.js is available:
   ```bash
   which node
   node --version
   ```

2. Verify the server file exists and is executable:
   ```bash
   ls -la /Users/emmanuel/.smithery/cache/servers/cameroncooke/xcodebuildmcp/current/index.cjs
   ```

3. Try removing and re-adding the server:
   ```bash
   gemini mcp remove xcodebuildmcp
   gemini mcp add xcodebuildmcp node /Users/emmanuel/.smithery/cache/servers/cameroncooke/xcodebuildmcp/current/index.cjs
   ```

## Comparison with Codex CLI

| Feature | Codex CLI | Gemini CLI |
|---------|-----------|------------|
| **Configuration Scope** | Global (`~/.codex/config.toml`) | Project-level |
| **MCP Command** | `codex mcp` | `gemini mcp` |
| **Auto-approval** | `--full-auto` | `--yolo` or `--approval-mode yolo` |
| **Server Status** | `enabled` | `Connected` |
| **Configuration File** | `~/.codex/config.toml` | Project directory |

## Adding to Multiple Projects

Since Gemini CLI uses project-level configuration, you'll need to add the MCP server to each project. Use the helper script:

```bash
# Quick setup for any project
.Foundation/scripts/add_gemini_mcp.sh [project_directory]
```

Or manually add to `.gemini/settings.json` in each project directory.

## Next Steps

1. ✅ XcodeBuildMCP server added to Gemini CLI (current project)
2. 🔄 Add to other projects as needed using the helper script
3. 🎯 Start using Gemini with Xcode tools!

You can now:
- Use Gemini CLI with full Xcode MCP tool access (in configured projects)
- Build, test, and debug via Gemini commands
- Manage simulators and devices through Gemini
- Use UI automation tools in Gemini sessions

**Note**: Remember to add the MCP server to each project where you want to use it!

---

**Last Updated**: January 12, 2026  
**Version**: 1.0
