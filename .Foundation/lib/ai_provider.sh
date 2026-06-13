#!/usr/bin/env bash

# AI Provider Abstraction Layer
# Supports Cursor CLI, OpenAI, Anthropic, Google Gemini, and DeepSeek APIs.

set -euo pipefail

# Verify bash is running
if [ -z "${BASH_VERSION:-}" ]; then
    echo "Error: This library requires bash" >&2
    return 1 2>/dev/null || exit 1
fi

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${LIB_DIR}/.." && pwd)"

AI_ENV_LOADED=${AI_ENV_LOADED:-0}
if [ "$AI_ENV_LOADED" -eq 0 ]; then
    if [ -f "${PROJECT_ROOT}/.env" ]; then
        # shellcheck disable=SC1091
        set -a
        source "${PROJECT_ROOT}/.env"
        set +a
    fi
    export AI_ENV_LOADED=1
fi

AI_PROVIDER_DEFAULT="${AI_PROVIDER:-anthropic}"
AI_PROVIDER_DEFAULT="$(echo "$AI_PROVIDER_DEFAULT" | tr '[:upper:]' '[:lower:]')"

AI_PROVIDER_READY=${AI_PROVIDER_READY:-0}

_ai_log_error() {
    local message="$1"
    if declare -F log_error >/dev/null 2>&1; then
        log_error "$message"
    else
        printf 'ERROR: %s\n' "$message" >&2
    fi
}

_ai_log_info() {
    local message="$1"
    if declare -F log_info >/dev/null 2>&1; then
        log_info "$message"
    else
        printf 'INFO: %s\n' "$message" >&2
    fi
}

_ai_provider_default_model() {
    local provider="$1"
    case "$provider" in
        openai)
            echo "${OPENAI_MODEL:-gpt-5-codex}" ;;
        anthropic)
            echo "${ANTHROPIC_MODEL:-claude-fable-5}" ;;
        google)
            echo "${GOOGLE_MODEL:-gemini-1.5-pro-latest}" ;;
        deepseek)
            echo "${DEEPSEEK_MODEL:-deepseek-chat}" ;;
        cursor|*)
            echo "${CURSOR_MODEL:-composer-1}" ;;
    esac
}

_ai_require_binary() {
    local binary="$1"
    if ! command -v "$binary" >/dev/null 2>&1; then
        _ai_log_error "Required binary not found: $binary"
        exit 1
    fi
}

_ai_ensure_provider_ready() {
    if [ "$AI_PROVIDER_READY" -eq 1 ]; then
        return
    fi

    local provider="$AI_PROVIDER_DEFAULT"
    case "$provider" in
        cursor)
            _ai_require_binary cursor
            ;;
        openai)
            : "${OPENAI_API_KEY:?OPENAI_API_KEY must be set for provider=openai}"
            ;;
        anthropic)
            : "${ANTHROPIC_API_KEY:?ANTHROPIC_API_KEY must be set for provider=anthropic}"
            ;;
        google)
            : "${GOOGLE_API_KEY:?GOOGLE_API_KEY must be set for provider=google}"
            ;;
        deepseek)
            : "${DEEPSEEK_API_KEY:?DEEPSEEK_API_KEY must be set for provider=deepseek}"
            ;;
        *)
            _ai_log_error "Unsupported AI provider: $provider"
            exit 1
            ;;
    esac

    export AI_PROVIDER_READY=1
}

ai_provider_request() {
    local prompt="$1"
    local max_tokens="${2:-3500}"
    local model="${3:-}" 

    local provider="${AI_PROVIDER:-$AI_PROVIDER_DEFAULT}"
    provider="$(echo "$provider" | tr '[:upper:]' '[:lower:]')"

    _ai_ensure_provider_ready

    local effective_model="$model"
    if [ -z "$effective_model" ]; then
        effective_model="$(_ai_provider_default_model "$provider")"
    fi

    case "$provider" in
        cursor)
            local output
            if ! output=$(cursor agent --print --model "$effective_model" --output-format text "$prompt" </dev/null 2>/dev/null); then
                _ai_log_error "Cursor agent invocation failed"
                exit 1
            fi
            if [ -z "${output}" ]; then
                _ai_log_error "Cursor agent returned no content"
                exit 1
            fi
            printf '%s' "$output"
            ;;
        openai|anthropic|google|deepseek)
            local script="${LIB_DIR}/ai_request.py"
            if [ ! -f "$script" ]; then
                _ai_log_error "AI request helper not found: $script"
                exit 1
            fi
            local response
            if ! response=$(python3 "$script" --provider "$provider" --model "$effective_model" --max-tokens "$max_tokens" <<< "$prompt"); then
                _ai_log_error "AI provider $provider invocation failed"
                exit 1
            fi
            if [ -z "$response" ]; then
                _ai_log_error "AI provider $provider returned no content"
                exit 1
            fi
            printf '%s' "$response"
            ;;
        *)
            _ai_log_error "Unsupported AI provider: $provider"
            exit 1
            ;;
    esac
}

ai_provider_name() {
    local provider="${AI_PROVIDER:-$AI_PROVIDER_DEFAULT}"
    printf '%s' "$provider"
}


