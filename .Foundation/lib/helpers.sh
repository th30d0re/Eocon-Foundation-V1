#!/usr/bin/env bash

# Helper Functions for Foundation Framework
# Provides portable commands, logging, and utility functions

# Detect OS and set portable flags
_detect_os() {
    case "$(uname -s)" in
        Darwin)
            echo "macos"
            ;;
        Linux)
            echo "linux"
            ;;
        FreeBSD|OpenBSD|NetBSD)
            echo "bsd"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

OS_TYPE=$(_detect_os)

# Ensure common tool directories are in PATH (macOS Homebrew, local installs, etc.)
_foundation_ensure_path() {
    local _dirs=""
    case "$OS_TYPE" in
        macos)
            _dirs="/usr/local/bin /opt/homebrew/bin /opt/local/bin ~/.local/bin ~/.cargo/bin"
            ;;
        linux)
            _dirs="/usr/local/bin ~/.local/bin ~/.cargo/bin"
            ;;
    esac
    for _dir in $_dirs; do
        _dir="${_dir/#\~/$HOME}"
        if [ -d "$_dir" ] && [[ ":$PATH:" != *":$_dir:"* ]]; then
            PATH="$_dir:$PATH"
        fi
    done
}
_foundation_ensure_path

# Shell Compatibility Functions
# Ensures scripts are running in bash with minimum required version

# Check if running in bash and verify version
check_shell_compatibility() {
    # Verify bash is running
    if [ -z "${BASH_VERSION:-}" ]; then
        echo "Error: This script requires bash but is running in a different shell." >&2
        echo "Please run with: bash $0" >&2
        return 1
    fi

    # Check bash version (minimum 3.2)
    local bash_major="${BASH_VERSINFO[0]:-0}"
    local bash_minor="${BASH_VERSINFO[1]:-0}"

    # Fail on bash < 3.2
    if [ "$bash_major" -lt 3 ]; then
        echo "Error: This script requires bash 3.2 or later (detected bash $BASH_VERSION)" >&2
        return 1
    fi

    if [ "$bash_major" -eq 3 ] && [ "$bash_minor" -lt 2 ]; then
        echo "Error: This script requires bash 3.2 or later (detected bash $BASH_VERSION)" >&2
        return 1
    fi

    # Warn on bash 3.x (macOS default)
    if [ "$bash_major" -eq 3 ]; then
        echo "Warning: Running on bash 3.x ($BASH_VERSION). Some features may have limitations." >&2
        echo "For full compatibility, install bash 4.0+ via Homebrew: brew install bash" >&2
    fi

    return 0
}

# Get bash major version number
check_bash_version() {
    if [ -n "${BASH_VERSINFO:-}" ]; then
        echo "${BASH_VERSINFO[0]}"
    else
        # Fallback: parse BASH_VERSION string
        echo "${BASH_VERSION%%.*}"
    fi
}

# Require minimum bash version with clear error messaging
require_bash_version() {
    local required_major="${1:-4}"
    local required_minor="${2:-0}"
    local bash_major="${BASH_VERSINFO[0]:-0}"
    local bash_minor="${BASH_VERSINFO[1]:-0}"

    # Check major version first
    if [ "$bash_major" -lt "$required_major" ]; then
        echo "Error: This script requires bash $required_major.$required_minor or later (detected bash $BASH_VERSION)" >&2
        if [ "$OS_TYPE" = "macos" ]; then
            echo "Install newer bash on macOS: brew install bash" >&2
            echo "Then run with: /usr/local/bin/bash $0" >&2
        else
            echo "Please upgrade your bash installation." >&2
        fi
        return 1
    fi

    # Check minor version if major matches
    if [ "$bash_major" -eq "$required_major" ] && [ "$bash_minor" -lt "$required_minor" ]; then
        echo "Error: This script requires bash $required_major.$required_minor or later (detected bash $BASH_VERSION)" >&2
        if [ "$OS_TYPE" = "macos" ]; then
            echo "Install newer bash on macOS: brew install bash" >&2
            echo "Then run with: /usr/local/bin/bash $0" >&2
        else
            echo "Please upgrade your bash installation." >&2
        fi
        return 1
    fi

    return 0
}

# Portable sed in-place edit
portable_sed_i() {
    local file="$1"
    shift
    local expr="$1"

    case "$OS_TYPE" in
        macos|bsd)
            # BSD sed requires backup extension
            sed -i '' "$expr" "$file"
            ;;
        linux)
            # GNU sed can use empty extension
            sed -i "$expr" "$file"
            ;;
        *)
            # Fallback: use temp file
            local tmp=$(mktemp)
            sed "$expr" "$file" > "$tmp" && mv "$tmp" "$file"
            ;;
    esac
}

# Check if running in TTY
is_tty() {
    [ -t 1 ] && [ -t 2 ]
}

# Color output (can be disabled)
COLOR_ENABLED=${COLOR_ENABLED:-$(is_tty && echo "1" || echo "0")}

# ANSI color codes (only if enabled)
if [ "$COLOR_ENABLED" = "1" ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    MAGENTA='\033[0;35m'
    ORANGE='\033[0;33m'
    BOLD='\033[1m'
    NC='\033[0m'
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    CYAN=''
    MAGENTA=''
    ORANGE=''
    BOLD=''
    NC=''
fi

# Redact secrets from strings
redact_secrets() {
    local text="$1"
    # Redact API keys (common patterns)
    text=$(echo "$text" | sed -E 's/([Aa][Pp][Ii][_-]?[Kk][Ee][Yy]=)[^[:space:]]+/\1***REDACTED***/g')
    text=$(echo "$text" | sed -E 's/([Aa][Uu][Tt][Hh][Oo][Rr][Ii][Zz][Aa][Tt][Ii][Oo][Nn]:[[:space:]]*Bearer[[:space:]]+)[^[:space:]]+/\1***REDACTED***/g')
    text=$(echo "$text" | sed -E 's/(sk-)[^[:space:]]+/\1***REDACTED***/g')
    text=$(echo "$text" | sed -E 's/(sk-ant-)[^[:space:]]+/\1***REDACTED***/g')
    echo "$text"
}

# Logging levels
LOG_LEVEL=${LOG_LEVEL:-info}  # debug, info, warning, error

# Centralized logger with levels and redaction
foundation_log() {
    local level="$1"
    shift
    local message="$*"
    local log_file="${LOG_FILE:-}"

    # Check if this level should be logged
    case "$LOG_LEVEL" in
        debug) ;;
        info)
            [ "$level" = "debug" ] && return
            ;;
        warning)
            [ "$level" = "debug" ] || [ "$level" = "info" ] && return
            ;;
        error)
            [ "$level" != "error" ] && return
            ;;
    esac

    # Redact secrets
    local safe_message=$(redact_secrets "$message")

    # Format message
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    local level_upper=$(echo "$level" | tr '[:lower:]' '[:upper:]')
    local log_entry="[${timestamp}] [${level_upper}] ${safe_message}"

    # Output to console
    case "$level" in
        debug)
            echo -e "${CYAN}[DEBUG]${NC} ${safe_message}" >&2
            ;;
        info)
            echo -e "${BLUE}[INFO]${NC} ${safe_message}" >&2
            ;;
        warning)
            echo -e "${YELLOW}[WARNING]${NC} ${safe_message}" >&2
            ;;
        error)
            echo -e "${RED}[ERROR]${NC} ${safe_message}" >&2
            ;;
        success)
            echo -e "${GREEN}[SUCCESS]${NC} ${safe_message}" >&2
            ;;
        *)
            echo -e "${safe_message}" >&2
            ;;
    esac

    # Append to log file if set
    if [ -n "$log_file" ]; then
        echo "$log_entry" >> "$log_file" 2>/dev/null || true
    fi
}

# Rotate log file if it exceeds max size
rotate_log_if_needed() {
    local log_file="$1"
    local max_size_mb="${MAX_LOG_SIZE_MB:-100}"
    local max_size_bytes=$((max_size_mb * 1024 * 1024))

    if [ ! -f "$log_file" ]; then
        return 0
    fi

    local file_size=$(stat -f%z "$log_file" 2>/dev/null || stat -c%s "$log_file" 2>/dev/null || echo "0")

    if [ "$file_size" -gt "$max_size_bytes" ]; then
        local backup_file="${log_file}.$(date +%Y%m%d_%H%M%S).bak"
        mv "$log_file" "$backup_file"
        foundation_log "info" "Rotated log file: $backup_file"

        # Keep only last 5 backups
        ls -t "${log_file}".*.bak 2>/dev/null | tail -n +6 | xargs rm -f 2>/dev/null || true
    fi
}

# Validate AI provider setup
validate_ai_provider_setup() {
    local ai_provider_lib="$1"
    local skip_ai="${SKIP_AI:-false}"

    # Check if AI provider library exists
    if [ ! -f "$ai_provider_lib" ]; then
        foundation_log "error" "AI provider library not found: $ai_provider_lib"
        foundation_log "error" ""
        foundation_log "error" "SETUP REQUIRED:"
        foundation_log "error" "1. Ensure .foundation/lib/ai_provider.sh exists"
        foundation_log "error" "2. For AI-dependent phases, configure one of:"
        foundation_log "error" "   - Cursor CLI (cursor command)"
        foundation_log "error" "   - OpenAI API (OPENAI_API_KEY)"
        foundation_log "error" "   - Anthropic API (ANTHROPIC_API_KEY)"
        foundation_log "error" "   - Google API (GOOGLE_API_KEY)"
        foundation_log "error" "   - DeepSeek API (DEEPSEEK_API_KEY)"
        foundation_log "error" ""
        foundation_log "error" "See Docs/ for API key setup instructions"
        return 1
    fi

    # Source the library to check environment
    if [ "$skip_ai" != "true" ]; then
        # shellcheck disable=SC1090
        if ! source "$ai_provider_lib" 2>/dev/null; then
            foundation_log "error" "Failed to load AI provider library"
            return 1
        fi

        # Check required environment variables based on provider
        local provider="${AI_PROVIDER:-cursor}"
        provider="${provider,,}"

        case "$provider" in
            cursor)
                if ! command -v cursor >/dev/null 2>&1; then
                    foundation_log "warning" "Cursor CLI not found in PATH"
                    foundation_log "info" "Install: https://cursor.sh or use another provider"
                fi
                ;;
            openai)
                if [ -z "${OPENAI_API_KEY:-}" ]; then
                    foundation_log "error" "OPENAI_API_KEY not set (required for provider=openai)"
                    return 1
                fi
                ;;
            anthropic)
                if [ -z "${ANTHROPIC_API_KEY:-}" ]; then
                    foundation_log "error" "ANTHROPIC_API_KEY not set (required for provider=anthropic)"
                    return 1
                fi
                ;;
            google)
                if [ -z "${GOOGLE_API_KEY:-}" ] && [ -z "${GEMINI_API_KEY:-}" ]; then
                    foundation_log "error" "GOOGLE_API_KEY or GEMINI_API_KEY not set (required for provider=google)"
                    return 1
                fi
                ;;
            deepseek)
                if [ -z "${DEEPSEEK_API_KEY:-}" ]; then
                    foundation_log "error" "DEEPSEEK_API_KEY not set (required for provider=deepseek)"
                    return 1
                fi
                ;;
        esac
    fi

    return 0
}

# Simple YAML value extractor (for basic key: value pairs)
parse_yaml_value() {
    local yaml_text="$1"
    local key="$2"

    # Extract value after key: (handles indentation)
    echo "$yaml_text" | grep -E "^[[:space:]]*${key}:[[:space:]]" | sed "s/^[[:space:]]*${key}:[[:space:]]*//" | sed 's/^"//;s/"$//' | head -1
}

# Extract YAML array items
parse_yaml_array() {
    local yaml_text="$1"
    local key="$2"

    # Extract items under key (assumes simple list format)
    echo "$yaml_text" | awk "/^[[:space:]]*- /" | sed 's/^[[:space:]]*-[[:space:]]*//'
}

# Extract JSON block from markdown
extract_json_block() {
    local file="$1"
    local block_name="$2"

    if [ ! -f "$file" ]; then
        return 1
    fi

    # Extract JSON between ```json and ```
    awk "/^```json[[:space:]]*${block_name}/,/^```/" "$file" | sed '1d;$d' | jq -r '.' 2>/dev/null || cat
}

# Validate integer with bounds
validate_integer() {
    local value="$1"
    local min="${2:-0}"
    local max="${3:-999}"

    if ! [[ "$value" =~ ^[0-9]+$ ]]; then
        return 1
    fi

    if [ "$value" -lt "$min" ] || [ "$value" -gt "$max" ]; then
        return 1
    fi

    return 0
}

# Cleanup temporary directory on exit
cleanup_temp_dir() {
    local temp_dir="${1:-}"
    if [ -n "$temp_dir" ] && [ -d "$temp_dir" ]; then
        rm -rf "$temp_dir" 2>/dev/null || true
    fi
}

# Setup cleanup trap
setup_cleanup_trap() {
    local temp_dir="$1"
    trap "cleanup_temp_dir '$temp_dir'" EXIT INT TERM
}

# ─────────────────────────────────────────────────────────────────────────────
# Themed Logging Functions
# ─────────────────────────────────────────────────────────────────────────────
# These functions check BUILDAGENT_FANCY_UI flag and use themed colors/icons
# when enabled, falling back to standard ANSI colors otherwise.

# Check if fancy UI is enabled
_is_fancy_ui_enabled() {
    [ "${BUILDAGENT_FANCY_UI:-false}" = "true" ] && [ -t 1 ] && [ -t 2 ]
}

# Get themed color (uses ui_themes.sh if loaded, otherwise falls back to ANSI)
_get_themed_color() {
    local name="$1"

    # Try to use get_color from ui_themes.sh if available
    if type get_color &>/dev/null 2>&1; then
        get_color "$name"
        return
    fi

    # Fallback to basic ANSI colors
    case "$name" in
        reset) echo '\033[0m' ;;
        success|green) echo '\033[0;32m' ;;
        error|red) echo '\033[0;31m' ;;
        warning|yellow) echo '\033[1;33m' ;;
        info|blue|primary) echo '\033[0;34m' ;;
        section|cyan) echo '\033[0;36m' ;;
        ai|magenta|accent) echo '\033[0;35m' ;;
        muted) echo '\033[0;37m' ;;
        *) echo '' ;;
    esac
}

# Get themed icon (uses ui_themes.sh if loaded, otherwise falls back to ASCII)
_get_themed_icon() {
    local name="$1"

    # Try to use get_icon from ui_themes.sh if available
    if type get_icon &>/dev/null 2>&1; then
        get_icon "$name"
        return
    fi

    # Check if terminal supports unicode
    local unicode_supported="false"
    local lang="${LANG:-}"
    local lc_all="${LC_ALL:-}"
    if [[ "$lang" == *"UTF-8"* ]] || [[ "$lang" == *"utf-8"* ]] || \
       [[ "$lc_all" == *"UTF-8"* ]] || [[ "$lc_all" == *"utf-8"* ]]; then
        unicode_supported="true"
    fi

    if [ "$unicode_supported" = "true" ] && _is_fancy_ui_enabled; then
        case "$name" in
            info) echo "" ;;
            success) echo "" ;;
            warning) echo "" ;;
            error) echo "" ;;
            section) echo "" ;;
            build) echo "" ;;
            ai) echo "" ;;
            test) echo "" ;;
            debug) echo "" ;;
            *) echo "" ;;
        esac
    else
        case "$name" in
            info) echo "[INFO]" ;;
            success) echo "[SUCCESS]" ;;
            warning) echo "[WARNING]" ;;
            error) echo "[ERROR]" ;;
            section) echo "[SECTION]" ;;
            build) echo "[BUILD]" ;;
            ai) echo "[AI]" ;;
            test) echo "[TEST]" ;;
            debug) echo "[DEBUG]" ;;
            *) echo "" ;;
        esac
    fi
}

# Themed log_info - Blue info icon or [INFO]
log_info_themed() {
    local message="$1"
    local color reset icon

    if _is_fancy_ui_enabled; then
        color=$(_get_themed_color "info")
        reset=$(_get_themed_color "reset")
        icon=$(_get_themed_icon "info")
        echo -e "${color}${icon}${reset} ${message}" >&2
    else
        echo -e "${BLUE}[INFO]${NC} ${message}" >&2
    fi
}

# Themed log_success - Green checkmark or [SUCCESS]
log_success_themed() {
    local message="$1"
    local color reset icon

    if _is_fancy_ui_enabled; then
        color=$(_get_themed_color "success")
        reset=$(_get_themed_color "reset")
        icon=$(_get_themed_icon "success")
        echo -e "${color}${icon}${reset} ${message}" >&2
    else
        echo -e "${GREEN}[SUCCESS]${NC} ${message}" >&2
    fi
}

# Themed log_warning - Yellow warning or [WARNING]
log_warning_themed() {
    local message="$1"
    local color reset icon

    if _is_fancy_ui_enabled; then
        color=$(_get_themed_color "warning")
        reset=$(_get_themed_color "reset")
        icon=$(_get_themed_icon "warning")
        echo -e "${color}${icon}${reset} ${message}" >&2
    else
        echo -e "${YELLOW}[WARNING]${NC} ${message}" >&2
    fi
}

# Themed log_error - Red X or [ERROR]
log_error_themed() {
    local message="$1"
    local color reset icon

    if _is_fancy_ui_enabled; then
        color=$(_get_themed_color "error")
        reset=$(_get_themed_color "reset")
        icon=$(_get_themed_icon "error")
        echo -e "${color}${icon}${reset} ${message}" >&2
    else
        echo -e "${RED}[ERROR]${NC} ${message}" >&2
    fi
}

# Themed log_section - Purple arrow or [SECTION]
log_section_themed() {
    local message="$1"
    local color reset icon

    if _is_fancy_ui_enabled; then
        color=$(_get_themed_color "section")
        reset=$(_get_themed_color "reset")
        icon=$(_get_themed_icon "section")
        echo -e "${color}${icon}${reset} ${message}" >&2
    else
        echo -e "${CYAN}[SECTION]${NC} ${message}" >&2
    fi
}

# Themed log_build - Blue hammer or [BUILD]
log_build_themed() {
    local message="$1"
    local color reset icon

    if _is_fancy_ui_enabled; then
        color=$(_get_themed_color "build")
        reset=$(_get_themed_color "reset")
        icon=$(_get_themed_icon "build")
        echo -e "${color}${icon}${reset} ${message}" >&2
    else
        echo -e "${BLUE}[BUILD]${NC} ${message}" >&2
    fi
}

# Themed log_ai - Purple robot or [AI]
log_ai_themed() {
    local message="$1"
    local color reset icon

    if _is_fancy_ui_enabled; then
        color=$(_get_themed_color "ai")
        reset=$(_get_themed_color "reset")
        icon=$(_get_themed_icon "ai")
        echo -e "${color}${icon}${reset} ${message}" >&2
    else
        echo -e "${MAGENTA}[AI]${NC} ${message}" >&2
    fi
}

# Themed log_test - Green test tube or [TEST]
log_test_themed() {
    local message="$1"
    local color reset icon

    if _is_fancy_ui_enabled; then
        color=$(_get_themed_color "test")
        reset=$(_get_themed_color "reset")
        icon=$(_get_themed_icon "test")
        echo -e "${color}${icon}${reset} ${message}" >&2
    else
        echo -e "${GREEN}[TEST]${NC} ${message}" >&2
    fi
}

# Themed log_debug - Gray bug or [DEBUG]
log_debug_themed() {
    local message="$1"

    # Only show debug logs if LOG_LEVEL is debug
    if [ "${LOG_LEVEL:-info}" != "debug" ]; then
        return 0
    fi

    local color reset icon

    if _is_fancy_ui_enabled; then
        color=$(_get_themed_color "muted")
        reset=$(_get_themed_color "reset")
        icon=$(_get_themed_icon "debug")
        echo -e "${color}${icon}${reset} ${message}" >&2
    else
        echo -e "${CYAN}[DEBUG]${NC} ${message}" >&2
    fi
}
