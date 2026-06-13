#!/usr/bin/env bash
# lib/build/provider.sh — AI provider install, detection, switching, auth, and Letta memory
[ -n "${_BUILD_PROVIDER_SH:-}" ] && return 0
_BUILD_PROVIDER_SH=1

letta_memory_available() {
    [ -n "$LETTA_MEMORY_AGENT" ] && [ -n "$LETTA_MEMORY_SCRIPT" ] && [ -f "$LETTA_MEMORY_SCRIPT" ]
}

# Retrieve memory context for build
retrieve_memory_context() {
    if ! letta_memory_available; then
        return 0
    fi

    log_verbose "Retrieving memory context from Letta..."

    # Search for relevant error patterns and learnings
    local search_result
    search_result=$(python3 "$LETTA_MEMORY_SCRIPT" search \
        --agent "$LETTA_MEMORY_AGENT" \
        --query "error patterns solutions Swift SwiftUI build" 2>/dev/null || echo "")

    if [ -n "$search_result" ] && [ "$search_result" != "[]" ]; then
        LETTA_MEMORY_CONTEXT="
=== LEARNED PATTERNS FROM PREVIOUS SESSIONS ===
The following patterns and solutions were learned from previous build sessions:

$search_result

Use these patterns to avoid repeating past mistakes.
=== END LEARNED PATTERNS ===
"
        log_info "Retrieved memory context from previous sessions"
    fi
}

# Store build result to memory
store_build_result() {
    local status="$1"  # success or failure
    local error_info="${2:-}"

    if ! letta_memory_available; then
        return 0
    fi

    log_verbose "Storing build result to memory: $status"

    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    if [ "$status" = "success" ]; then
        local data
        data=$(cat << EOF
{
    "status": "success",
    "session_id": "$SESSION_ID",
    "scheme": "${DETECTED_SCHEME:-unknown}",
    "attempts": $CURRENT_ATTEMPT,
    "ai_provider": "$AI_PROVIDER",
    "timestamp": "$timestamp"
}
EOF
)
        python3 "$LETTA_MEMORY_SCRIPT" store \
            --agent "$LETTA_MEMORY_AGENT" \
            --block "success_patterns" \
            --data "$data" >/dev/null 2>&1 || true

        # Also remember the successful approach for implicit learning
        python3 "$LETTA_MEMORY_SCRIPT" remember \
            --agent "$LETTA_MEMORY_AGENT" \
            --content "Build succeeded for scheme ${DETECTED_SCHEME:-unknown} after $CURRENT_ATTEMPT attempts using $AI_PROVIDER" >/dev/null 2>&1 || true
    else
        local data
        data=$(cat << EOF
{
    "status": "failure",
    "session_id": "$SESSION_ID",
    "scheme": "${DETECTED_SCHEME:-unknown}",
    "attempts": $CURRENT_ATTEMPT,
    "max_attempts": $MAX_REPAIR_ATTEMPTS,
    "ai_provider": "$AI_PROVIDER",
    "error_summary": "${error_info:0:500}",
    "timestamp": "$timestamp"
}
EOF
)
        python3 "$LETTA_MEMORY_SCRIPT" store \
            --agent "$LETTA_MEMORY_AGENT" \
            --block "error_patterns" \
            --data "$data" >/dev/null 2>&1 || true
    fi
}

# Write build stage status for the orchestrator pipeline visualizer.
# Same JSON schema as TestAgent's stages.json.

install_ai_provider() {
    local provider="$1"
    local install_cmd="$2"

    log_warning "AI provider '$provider' not found"

    # Check if cursor-agent is available for installation
    if ! command -v cursor-agent >/dev/null 2>&1; then
        log_error "Cannot auto-install: cursor-agent not available"
        log_info "Please install manually: $install_cmd"
        return 1
    fi

    echo "" >&2
    log_section "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_section "AUTO-INSTALLATION ATTEMPT"
    log_section "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "" >&2

    log_info "Attempting to install '$provider' using Cursor AI..."
    log_info "Install command: $install_cmd"
    echo "" >&2

    # Create installation prompt for Cursor
    local install_prompt="Please install the $provider CLI tool by running this command:

$install_cmd

After running the command, verify the installation by running:
command -v ${provider}

Respond with 'INSTALLED' when complete."

    # Save prompt to temp file
    local prompt_file="/tmp/buildagent_install_${provider}_$$.txt"
    echo "$install_prompt" > "$prompt_file"

    log_info "Asking Cursor AI to install $provider..."

    # Run cursor-agent to install (in WORK_DIR where user invoked the command)
    local cursor_output
    if cursor_output=$(cd "$WORK_DIR" && cursor-agent --force --print --output-format text "$install_prompt" 2>&1); then
        log_verbose "Cursor response received"

        # Wait a moment for installation to complete
        sleep 2

        # Check if the provider is now available
        if command -v "$provider" >/dev/null 2>&1; then
            echo "" >&2
            log_success "✓ Successfully installed $provider!"
            echo "" >&2
            rm -f "$prompt_file"
            return 0
        else
            log_warning "Installation attempted but $provider not found in PATH"
            log_info "You may need to restart your terminal or source your profile"
            log_info "Manual installation: $install_cmd"
            rm -f "$prompt_file"
            return 1
        fi
    else
        log_error "Cursor AI installation attempt failed"
        log_info "Please install manually: $install_cmd"
        rm -f "$prompt_file"
        return 1
    fi
}

# Auto-install Letta Code CLI
# Handles nvm environments, Node.js version validation, and PATH issues
install_letta() {
    log_info "Letta CLI not found. Attempting auto-installation..."

    # Check for Node.js
    if ! command -v node >/dev/null 2>&1; then
        # Try to load nvm if available
        if [ -f "$HOME/.nvm/nvm.sh" ]; then
            log_info "Loading nvm..."
            export NVM_DIR="$HOME/.nvm"
            # shellcheck disable=SC1091
            . "$NVM_DIR/nvm.sh"
        elif [ -f "/usr/local/opt/nvm/nvm.sh" ]; then
            # Homebrew nvm location
            export NVM_DIR="/usr/local/opt/nvm"
            # shellcheck disable=SC1091
            . "$NVM_DIR/nvm.sh"
        elif [ -f "/opt/homebrew/opt/nvm/nvm.sh" ]; then
            # Apple Silicon Homebrew location
            export NVM_DIR="/opt/homebrew/opt/nvm"
            # shellcheck disable=SC1091
            . "$NVM_DIR/nvm.sh"
        fi
    fi

    # Verify Node.js is available
    if ! command -v node >/dev/null 2>&1; then
        log_error "Node.js not found. Install Node.js 18+ first:"
        echo "  brew install node" >&2
        echo "  # or" >&2
        echo "  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash" >&2
        echo "  nvm install 18" >&2
        return 1
    fi

    # Check Node.js version (requires 18+)
    local node_version
    node_version=$(node -v | sed 's/v//' | cut -d. -f1)
    if [ "$node_version" -lt 18 ]; then
        log_error "Node.js 18+ required. Current version: $(node -v)"
        echo "  nvm install 18 && nvm use 18" >&2
        return 1
    fi

    # Check for npm
    if ! command -v npm >/dev/null 2>&1; then
        log_error "npm not found. Install npm or reinstall Node.js"
        return 1
    fi

    # Install Letta Code CLI globally
    log_info "Installing @letta-ai/letta-code via npm..."
    local install_log="/tmp/letta-install-$$.log"
    if npm install -g @letta-ai/letta-code 2>&1 | tee "$install_log"; then
        # Verify installation
        if command -v letta >/dev/null 2>&1; then
            log_success "Letta Code CLI installed successfully: $(letta --version 2>/dev/null || echo 'installed')"
            rm -f "$install_log"
            return 0
        else
            # Check if npm global bin is in PATH
            local npm_bin
            npm_bin=$(npm bin -g 2>/dev/null)
            if [ -n "$npm_bin" ] && [ -x "$npm_bin/letta" ]; then
                log_warning "Letta installed but not in PATH. Adding temporarily..."
                export PATH="$npm_bin:$PATH"
                if command -v letta >/dev/null 2>&1; then
                    log_success "Letta Code CLI available: $(letta --version 2>/dev/null || echo 'installed')"
                    rm -f "$install_log"
                    return 0
                fi
            fi
            log_error "Letta installed but 'letta' command not found in PATH"
            echo "  Add npm global bin to PATH: export PATH=\"\$(npm bin -g):\$PATH\"" >&2
            rm -f "$install_log"
            return 1
        fi
    else
        log_error "Failed to install Letta. Check $install_log for details"
        return 1
    fi
}

# Initialize or resume directory-specific Letta agent
# Each project directory gets its own dedicated agent with persistent memory
init_letta_directory_agent() {
    local project_dir="${1:-$WORK_DIR}"
    local project_name
    project_name=$(basename "$project_dir")
    local letta_config="$project_dir/.letta/settings.local.json"

    # Check if agent already exists for this directory
    if [ -f "$letta_config" ]; then
        # Letta auto-resumes the pinned agent when run from this directory
        log_verbose "Resuming Letta agent for: $project_name"
        return 0
    fi

    # First run: Create and initialize new agent
    log_info "Creating new Letta agent for: $project_name"

    # Create agent with project-specific name and initialize memory
    # Use --new to create a fresh agent, run /init to learn the codebase
    if (cd "$project_dir" && echo "You are the build agent for '$project_name'. Please run /init to learn this codebase structure." | letta --new --yolo -p 2>/dev/null); then
        # Pin agent locally to this directory
        if (cd "$project_dir" && echo "/pin -l ${project_name}-builder" | letta 2>/dev/null); then
            log_success "Letta agent initialized and pinned locally for: $project_name"
            return 0
        else
            log_warning "Agent created but local pinning failed - agent will still work"
            return 0
        fi
    else
        log_warning "Could not initialize Letta agent - will use default agent"
        return 1
    fi
}

# Detect whether cursor-agent supports streaming output
# NOTE: cursor-agent has --stream-partial-output (requires --output-format stream-json).
# The stream-json parsing pipeline is now wired up (shared with Kimi provider).
detect_cursor_stream_support() {
    CURSOR_STREAM_SUPPORTED="true"
}

# Detect and configure AI CLI provider
detect_ai_provider() {
    local provider
    provider=$(echo "$AI_PROVIDER" | tr '[:upper:]' '[:lower:]')  # Convert to lowercase

    log_verbose "Detecting AI provider: $provider"
    CURSOR_STREAM_SUPPORTED="false"

    case "$provider" in
        cursor)
            if command -v cursor-agent >/dev/null 2>&1; then
                AI_CMD="cursor-agent"
                detect_cursor_stream_support
                log_info "Using Cursor AI (cursor-agent)"
                # Pre-flight auth check. If CURSOR_API_KEY is exported we trust it.
                if [ -n "${CURSOR_API_KEY:-}" ]; then
                    log_verbose "CURSOR_API_KEY is set; skipping cursor-agent auth check"
                else
                    local _auth_check="" _auth_exit=0
                    # Newer cursor-agent has a lightweight "status" / "whoami" command.
                    if cursor-agent --help 2>&1 | grep -qE 'status\|whoami'; then
                        _auth_check=$(cursor-agent status 2>&1) || _auth_exit=$?
                    else
                        # Fall back to models endpoint; tolerate missing `timeout` on macOS.
                        local _timeout_cmd=""
                        _timeout_cmd=$(command -v timeout 2>/dev/null || command -v gtimeout 2>/dev/null)
                        if [ -n "$_timeout_cmd" ]; then
                            _auth_check=$($_timeout_cmd 8 cursor-agent models 2>&1) || _auth_exit=$?
                        else
                            _auth_check=$(cursor-agent models 2>&1) || _auth_exit=$?
                        fi
                    fi
                    if [ $_auth_exit -eq 0 ]; then
                        log_verbose "cursor-agent authenticated"
                    else
                        if echo "$_auth_check" | grep -qiE 'authentication required|agent login|api[ ._-]?key|not logged|unauthorized|invalid.*token|sign in|please log|no credentials|session expired|not authenticated|login required'; then
                            log_error "cursor-agent is not authenticated."
                            log_info "Run: cursor-agent login"
                            log_info "Or:  export CURSOR_API_KEY=<your_key>  (from cursor.com/settings)"
                            return 1
                        fi
                        log_verbose "cursor-agent auth check inconclusive (timeout or network) — proceeding"
                    fi
                fi
                return 0
            elif command -v cursor >/dev/null 2>&1; then
                AI_CMD="cursor agent"
                log_info "Using Cursor AI (cursor)"
                return 0
            else
                log_error "Cursor CLI not found. Install from https://cursor.sh"
                log_info "Cursor is required - it cannot auto-install itself"
                return 1
            fi
            ;;

        claude)
            if command -v claude >/dev/null 2>&1; then
                AI_CMD="claude"
                log_info "Using Claude CLI (with --dangerously-skip-permissions)"
                return 0
            else
                # Attempt auto-installation
                if install_ai_provider "claude" "npm install -g @anthropic-ai/claude-cli"; then
                    AI_CMD="claude"
                    log_info "Using Claude CLI (with --dangerously-skip-permissions)"
                    return 0
                fi
                return 1
            fi
            ;;

        codex|openai)
            if command -v codex >/dev/null 2>&1; then
                AI_CMD="codex"
                log_info "Using OpenAI Codex CLI (with --full-auto)"
                return 0
            elif command -v openai >/dev/null 2>&1; then
                AI_CMD="openai"
                log_info "Using OpenAI CLI (with --full-auto)"
                return 0
            else
                # Attempt auto-installation
                if install_ai_provider "openai" "pip install openai-cli"; then
                    if command -v openai >/dev/null 2>&1; then
                        AI_CMD="openai"
                        log_info "Using OpenAI CLI (with --full-auto)"
                        return 0
                    fi
                fi
                return 1
            fi
            ;;

        gemini|google)
            if command -v gemini >/dev/null 2>&1; then
                AI_CMD="gemini"
                log_info "Using Google Gemini CLI (with --yolo)"
                return 0
            elif command -v gcloud >/dev/null 2>&1; then
                AI_CMD="gcloud ai"
                log_info "Using Google Cloud AI CLI (with --yolo)"
                return 0
            else
                # Attempt auto-installation (gemini CLI)
                if install_ai_provider "gemini" "npm install -g @google/generative-ai-cli"; then
                    AI_CMD="gemini"
                    log_info "Using Google Gemini CLI (with --yolo)"
                    return 0
                fi
                return 1
            fi
            ;;

        aider)
            if command -v aider >/dev/null 2>&1; then
                AI_CMD="aider"
                log_info "Using Aider CLI"
                return 0
            else
                # Attempt auto-installation
                if install_ai_provider "aider" "pip install aider-chat"; then
                    AI_CMD="aider"
                    log_info "Using Aider CLI"
                    return 0
                fi
                return 1
            fi
            ;;

        letta)
            if command -v letta >/dev/null 2>&1; then
                AI_CMD="letta"
                log_info "Using Letta Code CLI: $(letta --version 2>/dev/null || echo 'installed')"
                log_info "Letta provides stateful agents with persistent memory"
                return 0
            else
                # Attempt auto-installation via npm
                if install_letta; then
                    AI_CMD="letta"
                    return 0
                fi
                return 1
            fi
            ;;

        copilot|github-copilot)
            # GitHub Copilot CLI - new @github/copilot npm package
            # Check for the new copilot command that supports -p flag
            if command -v copilot >/dev/null 2>&1; then
                # Verify it's the correct copilot (has -p option)
                if copilot --help 2>&1 | grep -q "\-p, --prompt"; then
                    AI_CMD="copilot"
                    log_info "Using GitHub Copilot CLI (@github/copilot)"
                    return 0
                fi
            fi

            # Try to install via npm
            log_info "GitHub Copilot CLI not found, attempting to install..."
            if install_ai_provider "copilot" "npm install -g @github/copilot"; then
                if command -v copilot >/dev/null 2>&1; then
                    AI_CMD="copilot"
                    log_info "GitHub Copilot CLI installed successfully"
                    return 0
                fi
            fi

            log_error "Failed to install GitHub Copilot CLI"
            log_info "Install manually: npm install -g @github/copilot"
            log_info "Requires Node.js 18+ and active Copilot subscription"
            return 1
            ;;

        kimi|kimi-code|moonshot)
            # Kimi Code CLI - Moonshot AI's CLI agent
            if command -v kimi >/dev/null 2>&1; then
                AI_CMD="kimi"
                log_info "Using Kimi Code CLI (moonshot-ai)"
                # Pre-flight auth check; tolerate missing `timeout` on macOS.
                local _auth_check _auth_exit=0
                local _timeout_cmd=""
                _timeout_cmd=$(command -v timeout 2>/dev/null || command -v gtimeout 2>/dev/null)
                if [ -n "$_timeout_cmd" ]; then
                    _auth_check=$($_timeout_cmd 8 kimi info 2>&1) || _auth_exit=$?
                else
                    _auth_check=$(kimi info 2>&1) || _auth_exit=$?
                fi
                if [ $_auth_exit -eq 0 ]; then
                    log_verbose "Kimi CLI authenticated"
                else
                    if echo "$_auth_check" | grep -qiE 'authentication required|login required|not logged|unauthorized|invalid.*token|sign in|please log|no credentials|session expired|not authenticated'; then
                        log_error "Kimi CLI is not authenticated."
                        log_info "Run: kimi login"
                        log_info "Or:  export KIMI_API_KEY=<your_key>"
                        return 1
                    fi
                    log_verbose "Kimi auth check inconclusive (timeout or network) — proceeding"
                fi
                return 0
            else
                log_error "Kimi CLI not found. Install from https://moonshotai.github.io/kimi-cli/"
                log_info "Install: curl -sSL https://install.kimi.com | sh"
                log_info "Or:     npm install -g @moonshotai/kimi-cli"
                return 1
            fi
            ;;

        *)
            log_error "Unknown AI provider: $provider"
            log_info "Supported providers: claude, cursor, codex, gemini, aider, letta, copilot, kimi"
            return 1
            ;;
    esac
}

# Switch to the next available AI provider using bandit strategy or round-robin
switch_ai_provider() {
    local current="$AI_PROVIDER"
    local next_provider=""

    # Use bandit strategy if available and strategy is not round-robin
    if [ "$PROVIDER_STRATEGY" != "round-robin" ] && command -v select_provider_auto >/dev/null 2>&1; then
        case "$PROVIDER_STRATEGY" in
            ucb1)
                next_provider=$(select_provider_ucb1 0.5 2>/dev/null)
                ;;
            thompson)
                next_provider=$(select_provider_thompson 2>/dev/null)
                ;;
            epsilon-greedy)
                next_provider=$(select_provider_epsilon_greedy 0.3 0.95 2>/dev/null)
                ;;
            explore-then-commit)
                next_provider=$(select_provider_explore_then_commit 2 2>/dev/null)
                ;;
            auto|*)
                next_provider=$(select_provider_auto 2>/dev/null)
                ;;
        esac

        # Ensure we don't pick the same provider that just timed out
        if [ "$next_provider" = "$current" ]; then
            next_provider=""
        fi
    fi

    # Fallback to round-robin if bandit didn't produce a different provider
    if [ -z "$next_provider" ]; then
        # Provider rotation. Claude/Fable 5 is the preferred orchestrator now that
        # the Anthropic subscription is active; the rest are fallback candidates.
        local providers=("claude" "cursor" "kimi" "codex" "gemini" "aider" "copilot")
        local found=false
        for p in "${providers[@]}"; do
            if [ "$found" = "true" ]; then
                if command -v "$p" >/dev/null 2>&1 || \
                   ( [ "$p" = "cursor" ] && (command -v cursor-agent >/dev/null 2>&1 || command -v cursor >/dev/null 2>&1) ); then
                    next_provider="$p"
                    break
                fi
            fi
            if [ "$p" = "$current" ]; then
                found=true
            fi
        done
        # Wrap around
        if [ -z "$next_provider" ]; then
            for p in "${providers[@]}"; do
                if [ "$p" != "$current" ]; then
                    if command -v "$p" >/dev/null 2>&1 || \
                       ( [ "$p" = "cursor" ] && (command -v cursor-agent >/dev/null 2>&1 || command -v cursor >/dev/null 2>&1) ); then
                        next_provider="$p"
                        break
                    fi
                fi
            done
        fi
    fi

    if [ -n "$next_provider" ] && [ "$next_provider" != "$current" ]; then
        log_warning "Switching AI provider: $current → $next_provider (strategy: $PROVIDER_STRATEGY)"
        AI_PROVIDER="$next_provider"
        AI_CMD=""
        if detect_ai_provider; then
            return 0
        fi
    fi

    log_error "No alternative AI provider available after timeout"
    return 1
}

# Check for authentication errors in AI CLI output
check_auth_error() {
    local output="$1"
    local provider
    provider=$(echo "$AI_PROVIDER" | tr '[:upper:]' '[:lower:]')  # Convert to lowercase

    # Common authentication error patterns
    local auth_patterns=(
        "not authenticated"
        "authentication failed"
        "not logged in"
        "please sign in"
        "please login"
        "invalid api key"
        "api key not found"
        "unauthorized"
        "401"
        "403 Forbidden"
        "authentication required"
        "token expired"
        "credentials not found"
        "no api key"
    )

    local output_lower
    output_lower=$(echo "$output" | tr '[:upper:]' '[:lower:]')  # Convert to lowercase for case-insensitive matching

    for pattern in "${auth_patterns[@]}"; do
        if echo "$output_lower" | grep -q "$pattern"; then
            log_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            log_error "AUTHENTICATION ERROR DETECTED"
            log_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "" >&2
            log_error "The AI CLI ($provider) requires authentication."
            echo "" >&2

            # Provider-specific instructions
            case "$provider" in
                cursor)
                    log_info "To authenticate cursor-agent CLI:"
                    echo "  1. Run: cursor-agent login" >&2
                    echo "     (opens browser to authenticate the CLI separately from the IDE)" >&2
                    echo "  2. Or set: export CURSOR_API_KEY=<your_api_key>" >&2
                    echo "     (get key from: https://cursor.com/settings → API Keys)" >&2
                    ;;
                claude)
                    log_info "To authenticate Claude CLI:"
                    echo "  1. Get your API key from: https://console.anthropic.com/" >&2
                    echo "  2. Set environment variable: export ANTHROPIC_API_KEY=your_key" >&2
                    echo "  3. Or run: claude auth login" >&2
                    ;;
                codex|openai)
                    log_info "To authenticate OpenAI:"
                    echo "  1. Get your API key from: https://platform.openai.com/api-keys" >&2
                    echo "  2. Set environment variable: export OPENAI_API_KEY=your_key" >&2
                    echo "  3. Or run: openai auth login" >&2
                    ;;
                gemini|google)
                    log_info "To authenticate Gemini:"
                    echo "  1. Get your API key from: https://makersuite.google.com/app/apikey" >&2
                    echo "  2. Set environment variable: export GOOGLE_API_KEY=your_key" >&2
                    echo "  3. Or run: gcloud auth login" >&2
                    ;;
                aider)
                    log_info "To authenticate Aider:"
                    echo "  1. Get your API key from your AI provider" >&2
                    echo "  2. Set environment variable (e.g., OPENAI_API_KEY, ANTHROPIC_API_KEY)" >&2
                    echo "  3. Or run: aider --help for setup instructions" >&2
                    ;;
                letta)
                    log_info "To authenticate Letta Code:"
                    echo "  1. Get your API key from: https://app.letta.com/api-keys" >&2
                    echo "  2. Set environment variable: export LETTA_API_KEY=your_key" >&2
                    echo "  3. Or run: letta (first run prompts for authentication)" >&2
                    if [ -n "${LETTA_BASE_URL:-}" ]; then
                        echo "" >&2
                        echo "  Self-hosted instance detected: $LETTA_BASE_URL" >&2
                        echo "  Ensure your API key is valid for this server." >&2
                    fi
                    ;;
                copilot|github-copilot)
                    log_info "To authenticate GitHub Copilot CLI:"
                    echo "  1. Copilot CLI uses GitHub authentication" >&2
                    echo "  2. Run: gh auth login (or copilot auth if standalone)" >&2
                    echo "  3. Ensure you have a GitHub Copilot subscription" >&2
                    echo "  4. Install: npm install -g @github/copilot" >&2
                    ;;
                kimi|kimi-code|moonshot)
                    log_info "To authenticate Kimi CLI:"
                    echo "  1. Run: kimi login" >&2
                    echo "  2. Or set: export KIMI_API_KEY=<your_key>" >&2
                    echo "  3. Install: curl -sSL https://install.kimi.com | sh" >&2
                    ;;
            esac

            echo "" >&2
            log_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            return 0  # Auth error detected
        fi
    done

    return 1  # No auth error
}

# ─────────────────────────────────────────────────────────────────────────────
# Context Gathering Functions
# ─────────────────────────────────────────────────────────────────────────────

# Read all MD files from a directory
