#!/usr/bin/env bash

# Phase 5: BuildAgent
# Orchestrates code generation via Cursor CLI with build verification loop
# Based on: Foundation-Constitution.tex Phase 5 (Execution)
#
# Workflow:
#   1. Gather context (plan/prompt + MD files + Swift docs)
#   2. Send to Cursor CLI for code generation
#   3. Run BuildLint.sh to verify
#   4. If errors, feed back to Cursor CLI (max 3 attempts)
#   5. On success: emit build.log | On failure: emit human_intervention.md
#
# Exit Codes:
#   0  - Success
#   10 - Build failed after max retries
#   11 - Misconfiguration
#   20 - Human intervention required

set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────────────────────────────────────

# Expand bare ~ in BUILDAGENT_USE_CWD (mirrors XcodeBuildMCP XCODEBUILDMCP_CWD fix)
BUILDAGENT_USE_CWD="${BUILDAGENT_USE_CWD:-}"
BUILDAGENT_USE_CWD="${BUILDAGENT_USE_CWD/#\~/$HOME}"

# When script is in PATH, use current working directory as project root
# Otherwise, calculate from script location
if [ -n "${BUILDAGENT_USE_CWD:-}" ] || [ "${PWD}" != "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" ]; then
    # Script is likely in PATH, use current working directory
    PROJECT_ROOT="${PROJECT_ROOT:-$PWD}"
else
    # Script is run from its own directory, calculate relative path
    PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)}"
fi

# Resolve symlinks to get actual script directory (supports running via symlink in PATH)
SOURCE="${BASH_SOURCE[0]}"
while [ -L "$SOURCE" ]; do
    SCRIPT_DIR="$(cd "$(dirname "$SOURCE")" && pwd)"
    SOURCE="$(readlink "$SOURCE")"
    [[ $SOURCE != /* ]] && SOURCE="$SCRIPT_DIR/$SOURCE"
done
SCRIPT_DIR="$(cd "$(dirname "$SOURCE")" && pwd)"
WORK_DIR="$PWD"  # Current working directory where user invoked the command

# Find Foundation lib directory (check multiple locations)
find_foundation_lib() {
    local lib_locations=(
        "${FOUNDATION_LIB_PATH:-}"
        "${PROJECT_ROOT}/.Foundation/lib"
        "${PROJECT_ROOT}/.foundation/lib"
        "${WORK_DIR}/.Foundation/lib"
        "${WORK_DIR}/.Foundation/lib"
        "${HOME}/.foundation/lib"
        "/Users/emmanuel/Dev/Tools/Eocon-Foundation-V1/.Foundation/lib"
    )

    for loc in "${lib_locations[@]}"; do
        if [ -n "$loc" ] && [ -d "$loc" ]; then
            echo "$loc"
            return 0
        fi
    done
    return 1
}

FOUNDATION_LIB_DIR=$(find_foundation_lib) || FOUNDATION_LIB_DIR=""

# Load helper libraries
if [ -n "$FOUNDATION_LIB_DIR" ]; then
    HELPERS_LIB="${FOUNDATION_LIB_DIR}/helpers.sh"
    ERRORS_LIB="${FOUNDATION_LIB_DIR}/errors.sh"
    AI_PROVIDER_LIB="${FOUNDATION_LIB_DIR}/ai_provider.sh"
else
    HELPERS_LIB=""
    ERRORS_LIB=""
    AI_PROVIDER_LIB=""
fi

if [ -n "$HELPERS_LIB" ] && [ -f "$HELPERS_LIB" ]; then
    # shellcheck disable=SC1090
    source "$HELPERS_LIB"

    # Check shell compatibility
    if type check_shell_compatibility &>/dev/null; then
        check_shell_compatibility || exit 11
    fi
fi

if [ -n "$ERRORS_LIB" ] && [ -f "$ERRORS_LIB" ]; then
    # shellcheck disable=SC1090
    source "$ERRORS_LIB"
fi

# Build queue coordination library (prevents concurrent write/build conflicts)
BUILD_QUEUE_ENABLED="${BUILD_QUEUE_ENABLED:-true}"  # Set to false to disable coordination
BUILD_QUEUE_LIB=""
if [ -n "$FOUNDATION_LIB_DIR" ]; then
    BUILD_QUEUE_LIB="${FOUNDATION_LIB_DIR}/BuildQueue.sh"
fi

if [ -n "$BUILD_QUEUE_LIB" ] && [ -f "$BUILD_QUEUE_LIB" ] && [ "$BUILD_QUEUE_ENABLED" = "true" ]; then
    # shellcheck disable=SC1090
    source "$BUILD_QUEUE_LIB"
    BUILD_QUEUE_AVAILABLE=true
else
    BUILD_QUEUE_AVAILABLE=false
fi

# Load defaults configuration file (unless disabled)
LOAD_DEFAULTS="${LOAD_DEFAULTS:-true}"
PHASE5_DIR="${SCRIPT_DIR}"
DEFAULTS_CONF="${PHASE5_DIR}/defaults.conf"
if [ "$LOAD_DEFAULTS" = "true" ] && [ -f "$DEFAULTS_CONF" ]; then
    # shellcheck disable=SC1090,SC1091
    source "$DEFAULTS_CONF"
fi

# Load Phase 5 UI libraries (optional - graceful degradation if not available)
PHASE5_LIB_DIR="${SCRIPT_DIR}/lib"
if [ -f "${PHASE5_LIB_DIR}/ui_themes.sh" ]; then
    # shellcheck disable=SC1090
    source "${PHASE5_LIB_DIR}/ui_themes.sh"
fi
if [ -f "${PHASE5_LIB_DIR}/ui_components.sh" ]; then
    # shellcheck disable=SC1090
    source "${PHASE5_LIB_DIR}/ui_components.sh"
fi
if [ -f "${PHASE5_LIB_DIR}/witty_phrases.sh" ]; then
    # shellcheck disable=SC1090
    source "${PHASE5_LIB_DIR}/witty_phrases.sh"
fi
if [ -f "${PHASE5_LIB_DIR}/session_store.sh" ]; then
    # shellcheck disable=SC1090
    source "${PHASE5_LIB_DIR}/session_store.sh"
fi
if [ -f "${PHASE5_LIB_DIR}/platform.sh" ]; then
    # shellcheck disable=SC1090
    source "${PHASE5_LIB_DIR}/platform.sh"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Load BuildAgent library modules (extracted from this file for maintainability)
# ─────────────────────────────────────────────────────────────────────────────
_BUILD_LIB_DIR="${SCRIPT_DIR}/lib/build"
if [ -d "$_BUILD_LIB_DIR" ]; then
    for _m in logging ui queue output detect provider context prompt repair ai_cli run; do
        # shellcheck disable=SC1090
        if [ -f "${_BUILD_LIB_DIR}/${_m}.sh" ]; then
            source "${_BUILD_LIB_DIR}/${_m}.sh"
        else
            echo "[BuildAgent] WARNING: lib/build/${_m}.sh not found" >&2
        fi
    done
    unset _m
else
    echo "[BuildAgent] ERROR: lib/build/ directory not found at ${_BUILD_LIB_DIR}" >&2
    exit 1
fi
unset _BUILD_LIB_DIR


# Colors (fallback if helpers not loaded)
RED="${RED:-\033[0;31m}"
GREEN="${GREEN:-\033[0;32m}"
YELLOW="${YELLOW:-\033[1;33m}"
BLUE="${BLUE:-\033[0;34m}"
CYAN="${CYAN:-\033[0;36m}"
MAGENTA="${MAGENTA:-\033[0;35m}"
NC="${NC:-\033[0m}"

# BuildLint script
BUILD_LINT_SCRIPT="${SCRIPT_DIR}/BuildLint.sh"

# Default artifact output directory
ARTIFACTS_DIR="${ARTIFACTS_DIR:-${PROJECT_ROOT}/Artifacts}"
LOGS_DIR=""
STATUS_DIR=""
ARTIFACTS_RUN_DIR=""  # Root of the per-run artifact directory (parent of logs/ and status/)
BUILT_PRODUCTS_DIR_CAPTURED=""  # Populated after a successful build (read from built_products_dir.txt)

# Input configuration
PLAN_FILE=""
PROMPT_FILE=""
PROMPT_STRING=""
PROMPT_CONTENT=""  # Cached content (read immediately to avoid temp file deletion)
CONTEXT_PATHS=()
SWIFT_DOCS_PATH="${PROJECT_ROOT}/Docs/swiftDocs"

# Build configuration (passed to BuildLint.sh)
TARGET_ID=""
DESTINATION=""
SCHEME=""
BUILD_CONFIGURATION="${BUILD_CONFIGURATION:-Debug}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-}"
XCODE_WORKSPACE=""  # Auto-detected workspace path
XCODE_PROJECT=""    # Auto-detected project path

# Repair loop configuration
MAX_REPAIR_ATTEMPTS="${MAX_REPAIR_ATTEMPTS:-3}"
CURRENT_ATTEMPT=0
MAX_TIMEOUT_RETRIES="${MAX_TIMEOUT_RETRIES:-3}"  # Cap timeout retries to avoid infinite loops
TIMEOUT_RETRY_COUNT=0
REPAIR_FROM_ERRORS_FILE=""  # Path to argent errors JSON file (set by --repair-from-errors)
PLANS_DIR=""               # Directory containing multiple plan files to execute sequentially
PLAN_FILES=()              # Ordered list of discovered plan files

# Build-first mode: run build before AI loop, skip AI if build already passes
BUILD_FIRST_MODE="${BUILD_FIRST_MODE:-false}"

# Todo file: inject todo items into AI prompt and track completion
TODO_FILE="${TODO_FILE:-}"

# Force mode: skip state check and re-run even if previously completed
FORCE_RUN="${FORCE_RUN:-false}"

# Session configuration (maintains context between attempts)
SESSION_ID=""
SESSION_FILE=""
CURSOR_CHAT_ID=""  # Cursor CLI chat session ID for --resume
AI_PROVIDER="${AI_PROVIDER:-claude}"  # AI CLI provider: claude (default), copilot, codex, cursor, gemini
AI_CMD=""          # Detected AI CLI command
AI_MODEL="${AI_MODEL:-}"  # Specific AI model (provider-dependent)
PROVIDER_STRATEGY="${PROVIDER_STRATEGY:-auto}"  # auto | ucb1 | thompson | epsilon-greedy | explore-then-commit | round-robin

# Flags
VERBOSE="${VERBOSE:-false}"
DRY_RUN="${DRY_RUN:-false}"
SKIP_LINT="${SKIP_LINT:-false}"
STREAM_OUTPUT="${STREAM_OUTPUT:-true}"
CURSOR_STREAM_SUPPORTED="false"
STREAM_HEARTBEAT_INTERVAL="${STREAM_HEARTBEAT_INTERVAL:-15}"  # Seconds between stream status updates
STREAM_HEARTBEAT_ENABLED="${STREAM_HEARTBEAT_ENABLED:-true}"  # Set to false to disable stream heartbeat
STREAM_ZERO_BYTES_TIMEOUT="${STREAM_ZERO_BYTES_TIMEOUT:-60}"  # Kill provider if 0 bytes for this many seconds
STREAM_MAX_TOTAL_TIME="${STREAM_MAX_TOTAL_TIME:-300}"  # Hard cap on total generation time
STREAM_BUILD_GRACE_TIME="${STREAM_BUILD_GRACE_TIME:-300}"  # Extra seconds when AI is detected running a build
STREAM_TIMELINE_FILE=""  # Populated during streaming runs
AI_LAST_TIMEOUT="false"  # Set to true when AI CLI times out (zero bytes)
AI_LAST_TIMEOUT_TYPE="timeout"  # "timeout" = zero bytes, "stall" = partial output then stopped
SKIP_CHAT_ID_CAPTURE="${SKIP_CHAT_ID_CAPTURE:-false}"  # Skip cursor chat ID capture (can be slow/unreliable)
YOLO_MODE="${YOLO_MODE:-false}"  # Automation mode: enables verbose, skip-chat-id, stream output
LINT_ONLY_MODE="${LINT_ONLY_MODE:-false}"  # No AI input - just run lint and build
SIDEBAR_MODE="${SIDEBAR_MODE:-false}"  # Enable persistent top status bar (sidebar UI)
SIDEBAR_STAGE="Initializing"  # Current stage displayed in sidebar
CURRENT_PLAN_INDEX=0  # Index of current plan in sequence
SMART_DOCS="${SMART_DOCS:-true}"  # Use cursor-agent RAG to filter relevant swift docs
MAX_CONTEXT_CHARS="${MAX_CONTEXT_CHARS:-400000}"  # Hard cap on gathered context sent to AI (~400KB)

# Verbosity control
LOG_LEVEL="${LOG_LEVEL:-info}"  # error, warning, info, debug

# Multi-platform build configuration
PLATFORM=""  # Specific platform to build for (empty = auto-detect)
MULTI_PLATFORM_FAIL_FAST="${MULTI_PLATFORM_FAIL_FAST:-false}"  # Stop on first platform failure
AUTO_MULTI_PLATFORM="${AUTO_MULTI_PLATFORM:-true}"  # Auto-detect and build for all platforms
JSON_OUTPUT="${JSON_OUTPUT:-false}"  # Output results in JSON format
MCP_CALLER="${MCP_CALLER:-false}"  # Set by MCP server when calling BuildAgent

# UI configuration (can be overridden by environment or command-line)
BUILDAGENT_FANCY_UI="${BUILDAGENT_FANCY_UI:-true}"
BUILDAGENT_THEME="${BUILDAGENT_THEME:-dark}"
BUILDAGENT_SPINNER_STYLE="${BUILDAGENT_SPINNER_STYLE:-braille}"
BUILDAGENT_WITTY_PHRASES="${BUILDAGENT_WITTY_PHRASES:-true}"
BUILDAGENT_SHOW_TIPS="${BUILDAGENT_SHOW_TIPS:-true}"

# Letta Memory integration (set by BuildVerify.sh orchestrator)
LETTA_MEMORY_AGENT="${LETTA_MEMORY_AGENT:-}"  # Memory agent name
LETTA_MEMORY_SCRIPT="${LETTA_MEMORY_SCRIPT:-}"  # Path to letta_memory.py
LETTA_MEMORY_CONTEXT=""  # Retrieved memory context (populated at runtime)

# Spinner state
SPINNER_PID=""

# Unbuffering configuration (for streaming mode)
UNBUFFER_METHOD=""  # Detected at runtime: stdbuf, unbuffer, script, or none



# ─────────────────────────────────────────────────────────────────────────────
# Usage
# ─────────────────────────────────────────────────────────────────────────────

show_usage() {
    # Show logo if fancy UI is enabled
    if [ "${BUILDAGENT_FANCY_UI:-false}" = "true" ] && type show_logo &>/dev/null; then
        show_logo "auto" >&2
        echo "" >&2
    fi

    cat << EOF
Phase 5: BuildAgent - AI-Powered Code Generation & Build Verification

DESCRIPTION:
    BuildAgent orchestrates AI-powered code generation with automatic build
    verification and repair loops. Supports multiple AI providers with auto-
    detection of project configuration.

    PROJECT ROOT:
    When script is in PATH, it uses your current working directory (PWD) as
    the project root. You can override with: export PROJECT_ROOT=/path/to/project

USAGE:
    $0 [OPTIONS]

INPUT OPTIONS (optional - if none provided, runs lint/build only):
    --plan <file.md>        Path to plan markdown file
    --plans-dir <dir>       Directory containing multiple plans to execute sequentially
                            Looks for sequence.md for custom order, or auto-discovers *.md
    --prompt <file.txt>     Path to prompt text file
    --prompt-string <str>   Prompt string directly (or use stdin)
    --stdin                 Read prompt from stdin

    If no input is provided, BuildAgent runs in auto-detect mode:
    - First runs lint/build to check for errors
    - If build passes: exits successfully (no AI needed)
    - If build fails: uses the errors as AI input and starts repair loop

CONTEXT OPTIONS:
    --context <path>        MD file or directory with MD files (can be repeated)
    --swift-docs <path>     Path to Swift documentation (auto-detected if not provided)
    --no-swift-docs         Skip Swift docs context (disables auto-detection)
    --no-smart-docs         Disable smart docs filtering (include all docs instead of RAG-selected)

    Smart docs filtering (enabled by default):
      Automatically selects only relevant Swift docs for the task, dramatically
      reducing context size. Uses cascading fallback:
        1. cursor-agent RAG (if available)
        2. claude CLI (if available)
        3. Keyword-based filtering (extracts types/frameworks from errors)
        4. All docs (final fallback)

    Auto-detection and auto-update:
      • Primary: /Users/emmanuel/Dev/Tools/Eocon-Foundation-V1/.Foundation/Docs/swiftDocs
        - Auto-clones from https://github.com/th30d0re/swiftDocs.git if missing
        - Auto-updates on each run (checks for new commits)
      • Fallback search locations:
        - Docs/swiftDocs, docs/swiftDocs
        - Documentation/swiftDocs, documentation/swiftDocs
        - .foundation/docs/swiftDocs, .Foundation/docs/swiftDocs
        - And more...

AI PROVIDER OPTIONS:
    --ai-provider <name>    AI CLI provider to use (default: cursor)

                            Supported providers:
                              cursor  - Cursor AI (default)
                              claude  - Anthropic Claude
                              codex   - OpenAI Codex
                              gemini  - Google Gemini
                              aider   - Aider AI pair programming
                              letta   - Letta stateful agents (persistent memory)
                              copilot - GitHub Copilot CLI
                              kimi    - Moonshot Kimi Code CLI

                            Auto-installation:
                              If a provider is not installed, the script will
                              attempt to install it automatically!
                              - Letta: via npm (requires Node.js 18+)
                              - Copilot: via npm (@githubnext/github-copilot-cli)
                              - Others: via Cursor AI assistance

                            Auto-approval flags (for unattended operation):
                              copilot → --allow-all-tools --allow-all-paths
                              cursor  → --force
                              claude  → --dangerously-skip-permissions
                              codex   → --full-auto
                              gemini  → --yolo
                              aider   → --yes
                              letta   → --yolo
                              kimi    → --yolo

    --ai-model <model>      Specific AI model to use (provider-dependent)
                            Example: --ai-model gemini-2.0-pro
                            For Letta: set LETTA_MODEL env var instead

    --provider-strategy <s> Provider selection strategy (default: auto)
                            auto, ucb1, thompson, epsilon-greedy, explore-then-commit, round-robin

BUILD OPTIONS:
    --target-id <id>        Device/Simulator UDID (e.g., 00008150-001D5822210A401C)
    --destination <dest>    Full destination string (overrides --target-id)
                            Example: "platform=iOS Simulator,name=iPhone 16"
    --scheme <scheme>       Xcode scheme to build (auto-detected if not provided)
                            Auto-detection searches for .xcworkspace or .xcodeproj
    --configuration <cfg>   Build configuration (default: Debug)
    --derived-data <path>   Custom DerivedData/build folder path
                            Auto-detects: phase5/Build folder if exists
    --skip-lint             Skip SwiftLint checks

EXECUTION OPTIONS:
    --max-attempts <n>      Max repair attempts (default: 3)
    --artifacts-dir <dir>   Artifacts output directory
    --stream                Stream AI CLI output in real-time
    --no-stream-heartbeat   Disable periodic heartbeat/status updates during streaming
    --sidebar               Enable persistent sidebar status bar (interactive terminals only)
    --yolo                  Automation mode: max-attempts=5, verbose, skip-chat-id, streaming
    --skip-chat-id          Skip cursor chat ID capture (faster, but no session resume)
    --skip-stage            Auto-skip interactive stage prompts
    --parallel-platforms    Enable parallel multi-platform builds (default: auto)
    --max-parallel-platforms <n>  Max concurrent platform builds (default: all detected)
    --build-first           Run build BEFORE AI loop; skip AI if build passes
    --todo-file <file.md>   Inject todo items into AI prompt and track completion
    --force                 Re-run even if prompt was previously completed
    --dry-run               Show what would be done without executing
    --verbose               Enable verbose output
    --no-defaults           Skip loading defaults.conf (for testing)
    --fancy-ui              Enable fancy terminal UI (colors, icons, progress bars)
    --no-fancy-ui           Disable fancy UI (plain text, CI/CD friendly)
    --help                  Show this help message

SESSION MANAGEMENT:
    --session-show          Display current session defaults
    --session-clear <key>   Clear a specific session default (e.g., scheme, platform)
    --session-clear-all     Clear all session defaults

    Session defaults are saved in .foundation-session.json and automatically
    applied when flags are not provided. After using a flag 3+ times in 7 days,
    you'll be prompted to save it as a default.

EXIT CODES:
    0   Success
    10  Build failed after max retries
    11  Misconfiguration
    20  Human intervention required

OUTPUTS:
    logs/build.log              - Build success log
    logs/error.log              - Error details (on failure)
    logs/coder.log              - AI CLI output
    status/success.txt          - On successful completion
    status/human_intervention.md - When human help needed

AUTHENTICATION:
    Each AI provider requires authentication. If you see an authentication
    error, the script will provide provider-specific setup instructions.

    Quick setup:
      cursor:  Already authenticated if Cursor IDE is logged in
      claude:  export ANTHROPIC_API_KEY=sk-ant-...
      codex:   export OPENAI_API_KEY=sk-...
      gemini:  export GOOGLE_API_KEY=...
      aider:   export OPENAI_API_KEY=... or ANTHROPIC_API_KEY=...
      letta:   export LETTA_API_KEY=letta-...
               Optional: export LETTA_BASE_URL=http://localhost:8283 (self-hosted)
      kimi:    export KIMI_API_KEY=sk-... or run: kimi login
      copilot: Uses GitHub authentication (gh auth login)

ENVIRONMENT VARIABLES:
    PROJECT_ROOT            Override project root directory (default: $PWD)
    BUILDAGENT_USE_CWD      Force use of current working directory
    BUILD_CONFIGURATION     Default build configuration (default: Debug)
    MAX_REPAIR_ATTEMPTS     Default max repair attempts (default: 3)
    AI_PROVIDER             Default AI provider (default: claude)

    UI CUSTOMIZATION:
    BUILDAGENT_FANCY_UI     Enable fancy terminal UI (default: true)
    BUILDAGENT_THEME        Color theme: dark or light (default: dark)
    BUILDAGENT_SPINNER_STYLE Spinner style: braille, dots, arrows, bounce, etc. (default: braille)
    BUILDAGENT_WITTY_PHRASES Show witty loading phrases (default: true)
    BUILDAGENT_SHOW_TIPS    Show helpful tips on startup (default: true)

EXAMPLES:

    ┌─────────────────────────────────────────────────────────────────────┐
    │ Basic Usage (Auto-Detection)                                        │
    └─────────────────────────────────────────────────────────────────────┘

    # Lint/build only - no AI, just verify the build
    $0
    BuildAgent.sh  # When in PATH

    # Minimal - auto-detects scheme, Swift docs, uses Cursor
    $0 --plan Plans/plan1/plan1.md

    # When script is in PATH, run from your project directory
    cd /path/to/your/project
    BuildAgent.sh --plan plan.md

    # Explicitly specify scheme (overrides auto-detection)
    $0 --plan Plans/plan1/plan1.md --scheme MyApp

    ┌─────────────────────────────────────────────────────────────────────┐
    │ Different AI Providers                                               │
    └─────────────────────────────────────────────────────────────────────┘

    # Use Claude (automatically adds --dangerously-skip-permissions)
    $0 --plan plan.md --ai-provider claude

    # Use Gemini with specific model (automatically adds --yolo)
    $0 --plan plan.md --ai-provider gemini --ai-model gemini-2.0-pro

    # Use Codex (automatically adds --full-auto)
    $0 --plan plan.md --ai-provider codex

    # Use Letta (stateful agent with persistent memory)
    $0 --plan plan.md --ai-provider letta

    # Use Letta with specific model
    LETTA_MODEL=sonnet-4.5 $0 --plan plan.md --ai-provider letta

    # Use Letta with self-hosted instance
    LETTA_BASE_URL=http://localhost:8283 $0 --plan plan.md --ai-provider letta

    ┌─────────────────────────────────────────────────────────────────────┐
    │ Build Configuration                                                  │
    └─────────────────────────────────────────────────────────────────────┘

    # Custom build folder
    $0 --plan plan.md --derived-data ./CustomBuild

    # Physical device with Release build
    $0 --plan plan.md --target-id 00008150-001D5822210A401C --configuration Release

    # Simulator with specific destination
    $0 --plan plan.md --destination "platform=iOS Simulator,name=iPhone 16"

    ┌─────────────────────────────────────────────────────────────────────┐
    │ Input Methods                                                        │
    └─────────────────────────────────────────────────────────────────────┘

    # From prompt string
    $0 --prompt-string "Add a login button" --context Guides/

    # From stdin
    echo "Fix the bug in AuthManager" | $0 --stdin

    # With additional context files
    $0 --plan plan.md --context Docs/ --context Guidelines/

    ┌─────────────────────────────────────────────────────────────────────┐
    │ UI Customization                                                     │
    └─────────────────────────────────────────────────────────────────────┘

    # Enable fancy UI with custom theme
    $0 --plan plan.md --fancy-ui
    BUILDAGENT_THEME=light $0 --plan plan.md

    # Disable fancy UI for CI/CD (plain text output)
    $0 --plan plan.md --no-fancy-ui

    # Custom spinner style
    BUILDAGENT_SPINNER_STYLE=dots $0 --plan plan.md

    # Quiet mode (disables fancy UI automatically)
    $0 --plan plan.md --quiet

    ┌─────────────────────────────────────────────────────────────────────┐
    │ Automation & CI/CD                                                   │
    └─────────────────────────────────────────────────────────────────────┘

    # YOLO mode - 10 retries, verbose, streaming (zero user interaction)
    $0 --plan plan.md --ai-provider claude --yolo

    # Custom retry count with automation
    $0 --plan plan.md --max-attempts 20 --yolo

    # Stream output in real-time (good for CI/CD logs)
    $0 --plan plan.md --stream --verbose

NOTES:
    • Auto-detection is non-fatal; falls back gracefully if nothing found
    • Auto-approval flags enable unattended operation (use in trusted environments)
    • Missing AI providers will be auto-installed using Cursor (if available)
    • All options can be combined as needed
    • Exit codes are designed for CI/CD integration

For more information, see: .Foundation/docs/BuildAgent.md
EOF
}

# ─────────────────────────────────────────────────────────────────────────────
# Setup Functions
# ─────────────────────────────────────────────────────────────────────────────


main() {
    local read_stdin=false

    # Track which flags were explicitly provided by user
    local user_provided_scheme=""
    local user_provided_configuration=""
    local user_provided_platform=""
    local user_provided_ai_provider=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --plan)
                PLAN_FILE="${2:-}"
                shift 2
                ;;
            --plans-dir)
                PLANS_DIR="${2:-}"
                shift 2
                ;;
            --prompt)
                PROMPT_FILE="${2:-}"
                shift 2
                ;;
            --prompt-string)
                PROMPT_STRING="${2:-}"
                shift 2
                ;;
            --stdin)
                read_stdin=true
                shift 1
                ;;
            --context)
                CONTEXT_PATHS+=("${2:-}")
                shift 2
                ;;
            --swift-docs)
                SWIFT_DOCS_PATH="${2:-}"
                shift 2
                ;;
            --no-swift-docs)
                SWIFT_DOCS_PATH="DISABLED"
                shift 1
                ;;
            --no-smart-docs)
                SMART_DOCS="false"
                shift 1
                ;;
            --ai-provider)
                AI_PROVIDER="${2:-}"
                user_provided_ai_provider="$AI_PROVIDER"
                shift 2
                ;;
            --ai-model)
                AI_MODEL="${2:-}"
                shift 2
                ;;
            --provider-strategy)
                PROVIDER_STRATEGY="${2:-auto}"
                shift 2
                ;;
            --target-id)
                TARGET_ID="${2:-}"
                shift 2
                ;;
            --destination)
                DESTINATION="${2:-}"
                shift 2
                ;;
            --scheme)
                SCHEME="${2:-}"
                user_provided_scheme="$SCHEME"
                shift 2
                ;;
            --configuration)
                BUILD_CONFIGURATION="${2:-}"
                user_provided_configuration="$BUILD_CONFIGURATION"
                shift 2
                ;;
            --derived-data)
                DERIVED_DATA_PATH="${2:-}"
                shift 2
                ;;
            --skip-lint)
                SKIP_LINT="true"
                shift 1
                ;;
            --max-attempts)
                MAX_REPAIR_ATTEMPTS="${2:-3}"
                shift 2
                ;;
            --artifacts-dir)
                ARTIFACTS_DIR="${2:-}"
                shift 2
                ;;
            --stream)
                STREAM_OUTPUT="true"
                shift 1
                ;;
            --no-stream-heartbeat)
                STREAM_HEARTBEAT_ENABLED="false"
                shift 1
                ;;
            --sidebar)
                SIDEBAR_MODE="true"
                shift 1
                ;;
            --skip-chat-id)
                SKIP_CHAT_ID_CAPTURE="true"
                shift 1
                ;;
            --skip-stage)
                SKIP_STAGE_PROMPT="true"
                shift 1
                ;;
            --dry-run)
                DRY_RUN="true"
                shift 1
                ;;
            --verbose|-v)
                VERBOSE="true"
                shift 1
                ;;
            --yolo)
                YOLO_MODE="true"
                VERBOSE="true"
                SKIP_CHAT_ID_CAPTURE="true"
                STREAM_OUTPUT="true"
                # Increase max attempts to 5 for YOLO mode (unless already set)
                if [ "$MAX_REPAIR_ATTEMPTS" = "3" ]; then
                    MAX_REPAIR_ATTEMPTS="5"
                fi
                log_info "YOLO mode enabled: verbose + skip-chat-id + streaming + max-attempts=${MAX_REPAIR_ATTEMPTS}"
                shift 1
                ;;
            --quiet|-q)
                LOG_LEVEL="error"
                BUILDAGENT_FANCY_UI="false"
                VERBOSE="false"
                shift 1
                ;;
            --debug)
                LOG_LEVEL="debug"
                VERBOSE="true"
                shift 1
                ;;
            --no-fancy-ui)
                BUILDAGENT_FANCY_UI="false"
                shift 1
                ;;
            --fancy-ui)
                BUILDAGENT_FANCY_UI="true"
                shift 1
                ;;
            --no-defaults)
                LOAD_DEFAULTS="false"
                shift 1
                ;;
            --session-show)
                # Display current session defaults
                if type session_get_all_defaults &>/dev/null && type session_load &>/dev/null; then
                    session_load || true

                    if [ "$JSON_OUTPUT" = "true" ]; then
                        local defaults_json
                        defaults_json=$(session_get_all_defaults | jq '.' 2>/dev/null || echo "{}")
                        echo "{\"success\":true,\"output\":\"$defaults_json\",\"error\":null,\"duration\":0,\"metadata\":$defaults_json,\"exitCode\":0}"
                    else
                        # Use draw_box if available, otherwise plain output
                        if type draw_box &>/dev/null && type select_theme &>/dev/null; then
                            select_theme "${BUILDAGENT_THEME:-dark}"
                            local defaults_json
                            defaults_json=$(session_get_all_defaults | jq '.' 2>/dev/null || session_get_all_defaults)
                            local defaults_display
                            defaults_display=$(echo "$defaults_json" | jq -r 'to_entries | .[] | "\(.key): \(.value)"' 2>/dev/null || echo "No defaults set")

                            if [ -z "$defaults_display" ] || [ "$defaults_display" = "{}" ]; then
                                defaults_display="No session defaults set"
                            fi

                            draw_box "Defaults" "$defaults_display"
                        else
                            session_get_all_defaults | jq '.' 2>/dev/null || session_get_all_defaults
                        fi
                    fi
                else
                    if [ "$JSON_OUTPUT" = "true" ]; then
                        echo "{\"success\":false,\"output\":\"\",\"error\":\"Session management not available (jq required)\",\"duration\":0,\"metadata\":{},\"exitCode\":1}"
                    else
                        echo "Session management not available (jq required)" >&2
                    fi
                    exit 1
                fi
                exit 0
                ;;
            --session-clear)
                # Clear specific default
                local key_to_clear="${2:-}"
                if [ -z "$key_to_clear" ]; then
                    if [ "$JSON_OUTPUT" = "true" ]; then
                        echo "{\"success\":false,\"output\":\"\",\"error\":\"--session-clear requires a key name\",\"duration\":0,\"metadata\":{},\"exitCode\":11}"
                    else
                        echo -e "${RED}[ERROR]${NC} --session-clear requires a key name" >&2
                    fi
                    exit 11
                fi
                if type session_set_default &>/dev/null && type session_save &>/dev/null && type session_load &>/dev/null; then
                    session_load || true
                    session_set_default "$key_to_clear" ""
                    session_save
                    if [ "$JSON_OUTPUT" = "true" ]; then
                        echo "{\"success\":true,\"output\":\"Cleared session default: $key_to_clear\",\"error\":null,\"duration\":0,\"metadata\":{\"key\":\"$key_to_clear\"},\"exitCode\":0}"
                    else
                        echo -e "${GREEN}[SUCCESS]${NC} Cleared session default: $key_to_clear" >&2
                    fi
                else
                    if [ "$JSON_OUTPUT" = "true" ]; then
                        echo "{\"success\":false,\"output\":\"\",\"error\":\"Session management not available (jq required)\",\"duration\":0,\"metadata\":{},\"exitCode\":1}"
                    else
                        echo -e "${RED}[ERROR]${NC} Session management not available (jq required)" >&2
                    fi
                    exit 1
                fi
                shift  # consume the key argument
                exit 0
                ;;
            --session-clear-all)
                # Clear all session defaults
                if type session_clear &>/dev/null && type session_save &>/dev/null; then
                    session_clear
                    session_save
                    if [ "$JSON_OUTPUT" = "true" ]; then
                        echo "{\"success\":true,\"output\":\"All session defaults cleared\",\"error\":null,\"duration\":0,\"metadata\":{},\"exitCode\":0}"
                    else
                        echo -e "${GREEN}[SUCCESS]${NC} All session defaults cleared" >&2
                    fi
                else
                    if [ "$JSON_OUTPUT" = "true" ]; then
                        echo "{\"success\":false,\"output\":\"\",\"error\":\"Session management not available (jq required)\",\"duration\":0,\"metadata\":{},\"exitCode\":1}"
                    else
                        echo -e "${RED}[ERROR]${NC} Session management not available (jq required)" >&2
                    fi
                    exit 1
                fi
                exit 0
                ;;
            --platform)
                # Multi-platform support - build for specific platform
                PLATFORM="${2:-}"
                user_provided_platform="$PLATFORM"
                shift 2
                ;;
            --fail-fast)
                MULTI_PLATFORM_FAIL_FAST="true"
                shift 1
                ;;
            --continue-on-error)
                MULTI_PLATFORM_FAIL_FAST="false"
                shift 1
                ;;
            --json-output)
                JSON_OUTPUT="true"
                shift 1
                ;;
            --session-set)
                # Set a session default: --session-set key=value
                local kv="${2:-}"
                if [ -z "$kv" ]; then
                    echo -e "${RED}[ERROR]${NC} --session-set requires key=value" >&2
                    exit 11
                fi
                if type session_set_default &>/dev/null && type session_save &>/dev/null && type session_load &>/dev/null; then
                    session_load || true
                    local key="${kv%%=*}"
                    local value="${kv#*=}"
                    session_set_default "$key" "$value"
                    session_save
                    if [ "$JSON_OUTPUT" = "true" ]; then
                        echo "{\"success\":true,\"output\":\"Set session default: $key=$value\",\"error\":null,\"duration\":0,\"metadata\":{\"key\":\"$key\",\"value\":\"$value\"},\"exitCode\":0}"
                    else
                        echo -e "${GREEN}[SUCCESS]${NC} Set session default: $key=$value" >&2
                    fi
                else
                    if [ "$JSON_OUTPUT" = "true" ]; then
                        echo "{\"success\":false,\"output\":\"\",\"error\":\"Session management not available (jq required)\",\"duration\":0,\"metadata\":{},\"exitCode\":1}"
                    else
                        echo -e "${RED}[ERROR]${NC} Session management not available (jq required)" >&2
                    fi
                    exit 1
                fi
                shift 2
                exit 0
                ;;
            --session-get)
                # Get a session default: --session-get key
                local key="${2:-}"
                if [ -z "$key" ]; then
                    echo -e "${RED}[ERROR]${NC} --session-get requires a key name" >&2
                    exit 11
                fi
                if type session_get_default &>/dev/null && type session_load &>/dev/null; then
                    session_load || true
                    local value
                    value=$(session_get_default "$key")
                    if [ "$JSON_OUTPUT" = "true" ]; then
                        echo "{\"success\":true,\"output\":\"$value\",\"error\":null,\"duration\":0,\"metadata\":{\"key\":\"$key\",\"value\":\"$value\"},\"exitCode\":0}"
                    else
                        echo "$value"
                    fi
                else
                    if [ "$JSON_OUTPUT" = "true" ]; then
                        echo "{\"success\":false,\"output\":\"\",\"error\":\"Session management not available (jq required)\",\"duration\":0,\"metadata\":{},\"exitCode\":1}"
                    else
                        echo -e "${RED}[ERROR]${NC} Session management not available (jq required)" >&2
                    fi
                    exit 1
                fi
                shift 2
                exit 0
                ;;
            --repair-from-errors)
                if [ -z "${2:-}" ]; then
                    log_error "--repair-from-errors requires a file path argument"
                    exit 11
                fi
                if [ ! -f "$2" ]; then
                    log_error "--repair-from-errors: file not found: $2"
                    exit 11
                fi
                REPAIR_FROM_ERRORS_FILE="$2"
                shift 2
                ;;
            --parallel-platforms)
                AUTO_MULTI_PLATFORM="true"
                shift 1
                ;;
            --max-parallel-platforms)
                MULTI_PLATFORM_PARALLELISM="${2:-0}"
                shift 2
                ;;
            --build-first)
                BUILD_FIRST_MODE="true"
                shift 1
                ;;
            --todo-file)
                TODO_FILE="${2:-}"
                if [ -n "$TODO_FILE" ] && [ ! -f "$TODO_FILE" ]; then
                    log_error "--todo-file: file not found: $TODO_FILE"
                    exit 11
                fi
                shift 2
                ;;
            --force)
                FORCE_RUN="true"
                shift 1
                ;;
            --force)
                FORCE_RUN="true"
                log_info "Force mode: ignoring saved state"
                shift 1
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 11
                ;;
        esac
    done

    # Load session defaults early (after parsing flags)
    if type session_load &>/dev/null; then
        session_load || true

        # Apply session defaults when flags are absent (if SESSION_DEFAULTS_ENABLED)
        if [ "${SESSION_DEFAULTS_ENABLED:-true}" = "true" ]; then
            # Apply saved defaults using ${VAR:-$(func)} pattern
            if [ -z "$user_provided_scheme" ]; then
                SCHEME=${SCHEME:-$(session_get_default "scheme" 2>/dev/null || echo "")}
            fi
            if [ -z "$user_provided_configuration" ]; then
                BUILD_CONFIGURATION=${BUILD_CONFIGURATION:-$(session_get_default "configuration" 2>/dev/null || echo "")}
                [ -z "$BUILD_CONFIGURATION" ] && BUILD_CONFIGURATION="${BUILD_CONFIGURATION:-Debug}"
            fi
            if [ -z "$user_provided_platform" ]; then
                PLATFORM=${PLATFORM:-$(session_get_default "platform" 2>/dev/null || echo "")}
            fi
            if [ -z "$user_provided_ai_provider" ]; then
                AI_PROVIDER=${AI_PROVIDER:-$(session_get_default "ai_provider" 2>/dev/null || echo "")}
                [ -z "$AI_PROVIDER" ] && AI_PROVIDER="${AI_PROVIDER:-claude}"
            fi
        fi
    fi

    # Track flag usage for learning (if explicitly provided by user)
    if type session_track_flag &>/dev/null; then
        [ -n "$user_provided_scheme" ] && session_track_flag "--scheme" "$user_provided_scheme"
        [ -n "$user_provided_configuration" ] && session_track_flag "--configuration" "$user_provided_configuration"
        [ -n "$user_provided_platform" ] && session_track_flag "--platform" "$user_provided_platform"
        [ -n "$user_provided_ai_provider" ] && session_track_flag "--ai-provider" "$user_provided_ai_provider"
    fi

    # Read from stdin if requested
    if [ "$read_stdin" = true ]; then
        if [ -t 0 ]; then
            log_error "No input on stdin. Pipe content or use --prompt-string"
            exit 11
        fi
        PROMPT_STRING=$(cat)
    fi

    # CRITICAL: Cache prompt/plan content IMMEDIATELY after argument parsing
    # Traycer deletes temp files after 30 seconds, so read them NOW before any slow operations
    if [ -n "$PROMPT_FILE" ] && [ -f "$PROMPT_FILE" ] && [ -z "$PROMPT_CONTENT" ]; then
        PROMPT_CONTENT=$(cat "$PROMPT_FILE" 2>/dev/null || true)
        if [ "${VERBOSE:-false}" = "true" ]; then echo "[VERBOSE] Early-cached prompt content (${#PROMPT_CONTENT} chars)" >&2; fi
    elif [ -n "$PLAN_FILE" ] && [ -f "$PLAN_FILE" ] && [ -z "$PROMPT_CONTENT" ]; then
        PROMPT_CONTENT=$(cat "$PLAN_FILE" 2>/dev/null || true)
        if [ "${VERBOSE:-false}" = "true" ]; then echo "[VERBOSE] Early-cached plan content (${#PROMPT_CONTENT} chars)" >&2; fi
    fi

    # Discover plans in --plans-dir
    if [ -n "$PLANS_DIR" ]; then
        if [ ! -d "$PLANS_DIR" ]; then
            log_error "Plans directory not found: $PLANS_DIR"
            exit 11
        fi
        mapfile -t PLAN_FILES < <(discover_plans_in_dir "$PLANS_DIR")
        if [ ${#PLAN_FILES[@]} -eq 0 ]; then
            log_error "No plan files found in: $PLANS_DIR"
            exit 11
        fi
        log_info "Discovered ${#PLAN_FILES[@]} plan(s) in $PLANS_DIR"
        for i in "${!PLAN_FILES[@]}"; do
            log_info "  [$((i + 1))] ${PLAN_FILES[$i]}"
        done
    fi

    # Initialize UI system
    init_ui

    echo "" >&2

    # Debug: Show UI status
    if [ "${VERBOSE:-false}" = "true" ]; then
        echo "[DEBUG] BUILDAGENT_FANCY_UI=${BUILDAGENT_FANCY_UI:-false}" >&2
        type get_icon &>/dev/null && echo "[DEBUG] get_icon: available" >&2 || echo "[DEBUG] get_icon: MISSING" >&2
        type get_color &>/dev/null && echo "[DEBUG] get_color: available" >&2 || echo "[DEBUG] get_color: MISSING" >&2
    fi

    # Show startup UI (logo, banner, tip) if fancy UI enabled
    if [ "${BUILDAGENT_FANCY_UI:-false}" = "true" ]; then
        show_startup_ui
    else
        log_section "=========================================="
        log_section "Phase 5: BuildAgent Starting"
        log_section "=========================================="
    fi
    echo "" >&2

    # Log if defaults were loaded
    if [ -f "${PHASE5_DIR}/defaults.conf" ] && [ "${LOAD_DEFAULTS:-true}" = "true" ]; then
        log_info "Loaded defaults from ${PHASE5_DIR}/defaults.conf"
    fi

    # Setup directories
    setup_directories

    # Initialize build queue coordination (prevents concurrent conflicts)
    init_build_queue

    # Validate inputs
    if ! validate_inputs; then
        exit 11
    fi

    # Detect supported platforms
    detect_project_platforms || true

    # Show configuration box (if fancy UI enabled)
    show_config_box

    log_info "Working Directory: $WORK_DIR"
    log_info "Project Root: $PROJECT_ROOT"
    if [ "$LINT_ONLY_MODE" = "true" ]; then
        log_info "Mode: Auto-detect (build first, AI repair if errors found)"
        log_info "AI Provider: $AI_PROVIDER (used if build fails)"
        log_info "Max Repair Attempts: $MAX_REPAIR_ATTEMPTS"
    else
        log_info "Max Repair Attempts: $MAX_REPAIR_ATTEMPTS"
        log_info "AI Provider: $AI_PROVIDER"
        if [ -n "$AI_MODEL" ]; then
            log_info "AI Model: $AI_MODEL"
        fi
    fi
    log_info "Artifacts: $ARTIFACTS_DIR"
    if [ "$YOLO_MODE" = "true" ]; then
        log_info "Mode: YOLO (automation mode active)"
    fi
    if [ -n "$SCHEME" ]; then
        log_info "Scheme: $SCHEME"
    fi
    if [ -n "$TARGET_ID" ]; then
        log_info "Target Device ID: $TARGET_ID"
    fi
    if [ -n "$DESTINATION" ]; then
        log_info "Destination: $DESTINATION"
    fi
    if [ -n "$BUILD_CONFIGURATION" ]; then
        log_info "Configuration: $BUILD_CONFIGURATION"
    fi
    if [ -n "$DERIVED_DATA_PATH" ]; then
        log_info "DerivedData Path: $DERIVED_DATA_PATH"
    fi
    echo "" >&2

    # Enable sidebar mode before starting build loop (if requested)
    if [ "$SIDEBAR_MODE" = "true" ]; then
        enable_sidebar_mode
    fi

    # Run the build loop
    local exit_code=0
    run_build_loop || exit_code=$?

    # Disable sidebar mode after build loop completes
    if [ "$SIDEBAR_MODE_ACTIVE" = "true" ]; then
        disable_sidebar_mode
    fi

    echo "" >&2
    log_section "=========================================="
    if [ $exit_code -eq 0 ]; then
        log_success "BuildAgent Complete!"
    elif [ $exit_code -eq 20 ]; then
        log_error "BuildAgent requires human intervention"
    else
        log_error "BuildAgent failed"
    fi
    log_section "=========================================="
    echo "" >&2
    log_info "Logs: $LOGS_DIR"
    log_info "Status: $STATUS_DIR"

    # List what was created
    if [ -d "$LOGS_DIR" ]; then
        log_verbose "Files in logs directory:"
        ls -la "$LOGS_DIR" >&2 2>/dev/null || true
    fi
    echo "" >&2

    # Output machine-friendly result
    if [ "$JSON_OUTPUT" = "true" ]; then
        # JSON output for MCP server
        local status_msg
        local error_msg="null"
        if [ $exit_code -eq 0 ]; then
            status_msg="Build completed successfully"
        elif [ $exit_code -eq 20 ]; then
            status_msg="Build requires human intervention"
            error_msg="Human intervention required after $CURRENT_ATTEMPT attempts"
        else
            status_msg="Build failed"
            error_msg="Build failed with exit code $exit_code"
        fi

        # Locate the most recent xcresult bundle for AI diagnostic consumers
        local xcresult_path=""
        local search_root="${DERIVED_DATA_PATH:-${WORK_DIR:-$PWD}}"
        xcresult_path=$(find "$search_root" -name "*.xcresult" -maxdepth 8 2>/dev/null | tail -1 || true)
        # Also check inside LOGS_DIR as a fallback
        if [ -z "$xcresult_path" ] && [ -d "${LOGS_DIR:-}" ]; then
            xcresult_path=$(find "$LOGS_DIR" -name "*.xcresult" -maxdepth 4 2>/dev/null | tail -1 || true)
        fi

        # Build extra_metadata with xcresultPath and logsPath
        local extra_meta="{}"
        if command -v jq &>/dev/null; then
            extra_meta=$(jq -n \
                --arg xr "$xcresult_path" \
                --arg lp "${LOGS_DIR:-}" \
                '{xcresultPath: (if $xr == "" then null else $xr end), logsPath: $lp}')
        fi

        # Build nextSteps hints for agent consumers
        local next_steps_json
        if [ $exit_code -eq 0 ]; then
            next_steps_json="$(jq -n \
                --arg ts "Run TestAgent.sh to verify: ${LOGS_DIR}" \
                --arg bv "Run BuildVerify.sh --skip-build to confirm" \
                '[$ts, $bv]' 2>/dev/null || echo '["Run TestAgent.sh to verify","Run BuildVerify.sh --skip-build"]')"
        elif [ $exit_code -eq 20 ]; then
            next_steps_json="$(jq -n \
                --arg er "Review error report in: ${LOGS_DIR}/error_attempt_${CURRENT_ATTEMPT}.log" \
                --arg re "Fix errors then re-run BuildAgent.sh" \
                '[$er, $re]' 2>/dev/null || echo '["Review error report in logs directory","Fix errors then re-run BuildAgent.sh"]')"
        else
            next_steps_json="$(jq -n \
                --arg lg "Check build log: ${LOGS_DIR}/buildlint_attempt_${CURRENT_ATTEMPT}.log" \
                --arg rv "Re-run with --verbose for detailed output" \
                '[$lg, $rv]' 2>/dev/null || echo '["Check build log in logs directory","Re-run with --verbose for detailed output"]')"
        fi

        output_json_result \
            "$([ $exit_code -eq 0 ] && echo true || echo false)" \
            "$status_msg" \
            "$error_msg" \
            "0" \
            "$extra_meta" \
            "$next_steps_json"
    else
        # Legacy output format
        if [ $exit_code -eq 0 ]; then
            printf 'BUILD_AGENT_STATUS=success\n'
        elif [ $exit_code -eq 20 ]; then
            printf 'BUILD_AGENT_STATUS=human_intervention\n'
        else
            printf 'BUILD_AGENT_STATUS=failed\n'
        fi
        printf 'BUILD_AGENT_LOGS_DIR=%q\n' "$LOGS_DIR"
        printf 'BUILD_AGENT_STATUS_DIR=%q\n' "$STATUS_DIR"
        printf 'BUILD_AGENT_ATTEMPTS=%d\n' "$CURRENT_ATTEMPT"
    fi

    exit $exit_code
}

# Run main (skip when sourced by tests)
[ "${BUILDAGENT_NO_MAIN:-}" = "1" ] || main "$@"
