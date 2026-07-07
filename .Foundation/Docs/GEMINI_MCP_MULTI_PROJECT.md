# Adding XcodeBuildMCP to Multiple Gemini Projects

## Quick Reference

Gemini CLI uses **project-level** MCP server configuration. The XcodeBuildMCP server needs to be added to each project where you want to use it.

## Quick Setup

### Using the Helper Script

```bash
# From any project directory
.Foundation/scripts/add_gemini_mcp.sh

# Or specify a project path
.Foundation/scripts/add_gemini_mcp.sh /path/to/project
```

### Using Gemini CLI

```bash
cd /path/to/project
gemini mcp add xcodebuildmcp node "$HOME/.smithery/cache/servers/cameroncooke/xcodebuildmcp/current/index.cjs"
```

### Manual Setup

1. Create `.gemini/settings.json` in your project:
   ```json
   {
     "mcpServers": {
       "xcodebuildmcp": {
         "command": "node",
         "args": [
           "$HOME/.smithery/cache/servers/cameroncooke/xcodebuildmcp/current/index.cjs"
         ]
       }
     }
   }
   ```

2. Verify:
   ```bash
   gemini mcp list
   ```

## Batch Setup for Multiple Projects

If you have many projects, you can use a simple loop:

```bash
# List of project directories
projects=(
  "$HOME/Dev/Project1"
  "$HOME/Dev/Project2"
  "$HOME/Dev/Project3"
)

# Add MCP server to each
for project in "${projects[@]}"; do
  echo "Adding to: $project"
  .Foundation/scripts/add_gemini_mcp.sh "$project"
done
```

## Verification

After adding to a project, verify it works:

```bash
cd /path/to/project
gemini mcp list
```

You should see:
```
Configured MCP servers:

✓ xcodebuildmcp: node $HOME/.smithery/cache/servers/cameroncooke/xcodebuildmcp/current/index.cjs (stdio) - Connected
```

## Why Project-Level?

Gemini CLI uses project-level configuration to:
- ✅ Allow different projects to have different MCP servers
- ✅ Keep configurations isolated per project
- ✅ Support team collaboration with project-specific setups
- ✅ Enable project-specific tooling configurations

## Comparison: Codex vs Gemini

| Feature | Codex CLI | Gemini CLI |
|---------|-----------|------------|
| **Configuration** | Global (`~/.codex/config.toml`) | Project-level (`.gemini/settings.json`) |
| **Setup Once** | ✅ Yes | ❌ No (per project) |
| **Flexibility** | Same servers everywhere | Different servers per project |

---

**Last Updated**: January 12, 2026
