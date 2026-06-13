#!/usr/bin/env bash
# lib/build/logging.sh — Logging helper functions for BuildAgent
# Sourced by BuildAgent.sh after color variables are defined.
# No set -euo pipefail: ownership stays with the entrypoint.
# Include guard: safe to source multiple times.
[ -n "${_BUILD_LOGGING_SH:-}" ] && return 0
_BUILD_LOGGING_SH=1

log_info() {
    if [ "${BUILDAGENT_FANCY_UI:-false}" = "true" ] && type get_icon &>/dev/null && type get_color &>/dev/null; then
        local info_color
        info_color=$(get_color "info")
        local reset
        reset=$(get_color "reset")
        local icon
        icon=$(get_icon "info")
        echo -e "${info_color}${icon}${reset} $1" >&2
    else
        echo -e "${BLUE}[INFO]${NC} $1" >&2
    fi
}

log_success() {
    if [ "${BUILDAGENT_FANCY_UI:-false}" = "true" ] && type get_icon &>/dev/null && type get_color &>/dev/null; then
        local success_color
        success_color=$(get_color "success")
        local reset
        reset=$(get_color "reset")
        local icon
        icon=$(get_icon "success")
        echo -e "${success_color}${icon}${reset} $1" >&2
    else
        echo -e "${GREEN}[SUCCESS]${NC} $1" >&2
    fi
}

log_warning() {
    if [ "${BUILDAGENT_FANCY_UI:-false}" = "true" ] && type get_icon &>/dev/null && type get_color &>/dev/null; then
        local warning_color
        warning_color=$(get_color "warning")
        local reset
        reset=$(get_color "reset")
        local icon
        icon=$(get_icon "warning")
        echo -e "${warning_color}${icon}${reset} $1" >&2
    else
        echo -e "${YELLOW}[WARNING]${NC} $1" >&2
    fi
}

log_error() {
    if [ "${BUILDAGENT_FANCY_UI:-false}" = "true" ] && type get_icon &>/dev/null && type get_color &>/dev/null; then
        local error_color
        error_color=$(get_color "error")
        local reset
        reset=$(get_color "reset")
        local icon
        icon=$(get_icon "error")
        echo -e "${error_color}${icon}${reset} $1" >&2
    else
        echo -e "${RED}[ERROR]${NC} $1" >&2
    fi
}

log_section() {
    if [ "${BUILDAGENT_FANCY_UI:-false}" = "true" ] && type get_icon &>/dev/null && type get_color &>/dev/null; then
        local section_color
        section_color=$(get_color "section")
        local reset
        reset=$(get_color "reset")
        local icon
        icon=$(get_icon "section")
        echo -e "${section_color}${icon}${reset} $1" >&2
    else
        echo -e "${CYAN}[BUILD-AGENT]${NC} $1" >&2
    fi
}

log_attempt() {
    if [ "${BUILDAGENT_FANCY_UI:-false}" = "true" ] && type get_icon &>/dev/null && type get_color &>/dev/null; then
        local ai_color
        ai_color=$(get_color "ai")
        local reset
        reset=$(get_color "reset")
        local icon
        icon=$(get_icon "ai")
        echo -e "${ai_color}${icon} [${CURRENT_ATTEMPT}/${MAX_REPAIR_ATTEMPTS}]${reset} $1" >&2
    else
        echo -e "${MAGENTA}[ATTEMPT ${CURRENT_ATTEMPT}/${MAX_REPAIR_ATTEMPTS}]${NC} $1" >&2
    fi
}

log_verbose() {
    if [ "$VERBOSE" = "true" ]; then
        if [ "${BUILDAGENT_FANCY_UI:-false}" = "true" ] && type get_icon &>/dev/null && type get_color &>/dev/null; then
            local debug_color
            debug_color=$(get_color "debug")
            local reset
            reset=$(get_color "reset")
            local icon
            icon=$(get_icon "debug")
            echo -e "${debug_color}${icon}${reset} $1" >&2
        else
            echo -e "${CYAN}[VERBOSE]${NC} $1" >&2
        fi
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# JSON Output Functions (for MCP Integration)
# ─────────────────────────────────────────────────────────────────────────────

# Output structured JSON result for MCP server consumption
# Arguments:
#   $1 - success (true/false)
#   $2 - output message
#   $3 - error message (optional, "null" if not provided)
#   $4 - duration in ms (optional, 0 if not provided)
#   $5 - additional metadata JSON (optional)
#   $6 - nextSteps JSON array (optional, e.g. '["step 1","step 2"]')
