#!/bin/bash

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

