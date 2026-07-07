#!/bin/bash
# Add XcodeBuildMCP server to Gemini CLI for the current project
# Usage: ./add_gemini_mcp.sh [project_directory]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${1:-$(pwd)}"
GEMINI_DIR="${PROJECT_ROOT}/.gemini"
SETTINGS_FILE="${GEMINI_DIR}/settings.json"
SERVER_PATH="${XCODEBUILDMCP_SERVER:-${HOME}/.smithery/cache/servers/cameroncooke/xcodebuildmcp/current/index.cjs}"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "Adding XcodeBuildMCP server to Gemini CLI..."
echo "Project: ${PROJECT_ROOT}"

# Check if server file exists
if [ ! -f "$SERVER_PATH" ]; then
    echo "Error: XcodeBuildMCP server not found at: $SERVER_PATH"
    exit 1
fi

# Create .gemini directory if it doesn't exist
mkdir -p "$GEMINI_DIR"

# Check if settings.json exists
if [ -f "$SETTINGS_FILE" ]; then
    # Check if xcodebuildmcp is already configured
    if grep -q "xcodebuildmcp" "$SETTINGS_FILE" 2>/dev/null; then
        echo -e "${YELLOW}Warning: xcodebuildmcp is already configured in ${SETTINGS_FILE}${NC}"
        echo "Skipping configuration."
        exit 0
    fi
    
    # Backup existing file
    cp "$SETTINGS_FILE" "${SETTINGS_FILE}.bak"
    echo "Backed up existing settings to ${SETTINGS_FILE}.bak"
    
    # Use jq to add the server if available, otherwise use Python
    if command -v jq &> /dev/null; then
        # Use jq to merge the server configuration
        jq ".mcpServers.xcodebuildmcp = {
            \"command\": \"node\",
            \"args\": [\"$SERVER_PATH\"]
        }" "$SETTINGS_FILE" > "${SETTINGS_FILE}.tmp" && mv "${SETTINGS_FILE}.tmp" "$SETTINGS_FILE"
    elif command -v python3 &> /dev/null; then
        # Use Python to merge the server configuration
        python3 << EOF
import json
import sys

try:
    with open("$SETTINGS_FILE", "r") as f:
        settings = json.load(f)
except (json.JSONDecodeError, FileNotFoundError):
    settings = {}

if "mcpServers" not in settings:
    settings["mcpServers"] = {}

settings["mcpServers"]["xcodebuildmcp"] = {
    "command": "node",
    "args": ["$SERVER_PATH"]
}

with open("$SETTINGS_FILE", "w") as f:
    json.dump(settings, f, indent=2)
EOF
    else
        # Fallback: create new file with just the server config
        cat > "$SETTINGS_FILE" << EOF
{
  "mcpServers": {
    "xcodebuildmcp": {
      "command": "node",
      "args": [
        "$SERVER_PATH"
      ]
    }
  }
}
EOF
        echo -e "${YELLOW}Warning: jq and python3 not found. Created new settings file.${NC}"
        echo "If you had existing settings, they may have been overwritten."
        echo "Check ${SETTINGS_FILE}.bak for your previous configuration."
    fi
else
    # Create new settings file
    cat > "$SETTINGS_FILE" << EOF
{
  "mcpServers": {
    "xcodebuildmcp": {
      "command": "node",
      "args": [
        "$SERVER_PATH"
      ]
    }
  }
}
EOF
fi

echo -e "${GREEN}✓ XcodeBuildMCP server added to Gemini CLI${NC}"
echo "Configuration saved to: ${SETTINGS_FILE}"
echo ""
echo "To verify, run: cd ${PROJECT_ROOT} && gemini mcp list"
