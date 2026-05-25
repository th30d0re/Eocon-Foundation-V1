#!/usr/bin/env bash

# Error Handling Library for Foundation Framework
# Provides standardized error codes and error emission

# Verify bash is running
if [ -z "${BASH_VERSION:-}" ]; then
    echo "Error: This library requires bash" >&2
    return 1 2>/dev/null || exit 1
fi

# Detect project root
if [ -z "$PROJECT_ROOT" ]; then
    PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fi

# Load helpers for logging if available
HELPERS_FILE="${PROJECT_ROOT}/.foundation/lib/helpers.sh"
if [ -f "$HELPERS_FILE" ]; then
    # shellcheck disable=SC1090
    source "$HELPERS_FILE"
fi

# Error code to message mapping function (bash 3.2 compatible)
get_error_message() {
    local code="$1"
    case "$code" in
        # Phase 0 errors
        E001) echo "Constitution parsing failed" ;;
        E002) echo "Invalid Constitution format" ;;
        E003) echo "Missing required Constitution section" ;;

        # Phase 1 errors
        E101) echo "Plan generation failed" ;;
        E102) echo "Wave decomposition failed" ;;
        E103) echo "Invalid wave count" ;;
        E104) echo "Test specification generation failed" ;;

        # Phase 2 errors
        E201) echo "Question analysis failed" ;;
        E202) echo "Ambiguity detection failed" ;;
        E203) echo "Questions.md generation failed" ;;

        # Phase 3 errors
        E301) echo "Plan optimization failed" ;;
        E302) echo "Historical pattern analysis failed" ;;
        E303) echo "Test enhancement failed" ;;

        # Phase 4 errors
        E401) echo "Dependency analysis failed" ;;
        E402) echo "Stage calculation failed" ;;
        E403) echo "Critical path identification failed" ;;
        E404) echo "stages.md generation failed" ;;

        # Phase 5 errors
        E501) echo "Code generation failed" ;;
        E502) echo "Test execution failed" ;;
        E503) echo "Debug loop exhausted (3 attempts)" ;;
        E504) echo "Parallel execution failure" ;;
        E505) echo "Integration test failure" ;;
        E506) echo "Cross-wave conflict detected" ;;
        E507) echo "Wave parsing failed" ;;
        E508) echo "Test framework detection failed" ;;
        E509) echo "Code validation failed" ;;
        E510) echo "Backup creation failed" ;;
        E511) echo "File write operation failed" ;;
        E512) echo "Test sandbox setup failed" ;;
        E513) echo "Stage execution failed" ;;

        # System/Orchestrator errors
        E901) echo "AI provider unavailable" ;;
        E902) echo "Configuration error" ;;
        E903) echo "Filesystem error" ;;
        E904) echo "Permission denied" ;;
        E905) echo "Resource limit exceeded" ;;
        E906) echo "Unexpected system error" ;;

        *) echo "Unknown error" ;;
    esac
}

# Error directory for detailed reports
ERRORS_DIR="${PROJECT_ROOT}/.foundation/errors"
mkdir -p "$ERRORS_DIR"

# Emit a structured error with code and message
# Usage: emit_error <error_code> <message> [context]
emit_error() {
    local error_code="$1"
    local message="$2"
    local context="${3:-}"

    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local error_id="$(uuidgen 2>/dev/null || date +%s)"

    # Get standard error message for code
    local standard_message="$(get_error_message "$error_code")"

    # Log to console
    if command -v foundation_log >/dev/null 2>&1; then
        foundation_log "error" "[$error_code] $standard_message: $message"
    else
        echo "[ERROR] [$error_code] $standard_message: $message" >&2
    fi

    # Create detailed error report
    local error_file="${ERRORS_DIR}/${timestamp}_${error_code}.json"
    cat > "$error_file" << EOF
{
  "error_id": "$error_id",
  "error_code": "$error_code",
  "standard_message": "$standard_message",
  "custom_message": "$message",
  "context": "$context",
  "timestamp": "$timestamp",
  "phase": "${CURRENT_PHASE:-unknown}",
  "session_id": "${SESSION_ID:-unknown}",
  "escalated": false,
  "resolved": false
}
EOF

    # Return error code for caller
    return 1
}

# Emit an error with escalation
# Usage: emit_error_and_escalate <error_code> <message> [context]
emit_error_and_escalate() {
    local error_code="$1"
    local message="$2"
    local context="${3:-}"

    emit_error "$error_code" "$message" "$context"

    # Mark as escalated in the error file
    local error_file=$(ls -t "${ERRORS_DIR}"/*_${error_code}.json 2>/dev/null | head -1)
    if [ -f "$error_file" ]; then
        python3 -c "
import json
try:
    with open('$error_file', 'r') as f:
        data = json.load(f)
    data['escalated'] = True
    with open('$error_file', 'w') as f:
        json.dump(data, f, indent=2)
except: pass
" 2>/dev/null || true
    fi

    # Trigger human intervention workflow
    escalate_to_human "$error_code" "$message" "$context"
}

# Escalate to human intervention
escalate_to_human() {
    local error_code="$1"
    local message="$2"
    local context="${3:-}"

    echo "" >&2
    echo "═══════════════════════════════════════════════════════" >&2
    echo "  HUMAN INTERVENTION REQUIRED" >&2
    echo "═══════════════════════════════════════════════════════" >&2
    echo "" >&2
    echo "Error Code: $error_code" >&2
    echo "Message: $message" >&2
    if [ -n "$context" ]; then
        echo "Context: $context" >&2
    fi
    echo "" >&2
    echo "Error details saved to: ${ERRORS_DIR}/" >&2
    echo "" >&2
    echo "Options:" >&2
    echo "  1. Review error details and fix manually" >&2
    echo "  2. Skip this step and continue (may cause failures)" >&2
    echo "  3. Abort execution" >&2
    echo "" >&2

    # Wait for user input
    read -p "Enter choice (1/2/3): " -n 1 -r
    echo "" >&2

    case $REPLY in
        1)
            echo "Please fix the error and press Enter to retry..." >&2
            read -r
            return 0
            ;;
        2)
            echo "Skipping... (this may cause downstream failures)" >&2
            return 0
            ;;
        3)
            echo "Aborting execution." >&2
            exit 1
            ;;
        *)
            echo "Invalid choice. Aborting." >&2
            exit 1
            ;;
    esac
}

# Check if error code should trigger escalation
should_escalate() {
    local error_code="$1"
    local retry_count="${2:-0}"

    # Critical errors (E5xx series for Phase 5)
    case "$error_code" in
        E503)
            # Debug loop exhausted - always escalate
            return 0
            ;;
        E504)
            # Parallel execution failure - escalate if multiple failures
            [ "$retry_count" -ge 2 ] && return 0
            ;;
        E505)
            # Integration test failure - escalate immediately
            return 0
            ;;
        E506)
            # Cross-wave conflict - escalate immediately
            return 0
            ;;
        E50[1-2])
            # Code generation or test execution - escalate after 3 retries
            [ "$retry_count" -ge 3 ] && return 0
            ;;
        E9*)
            # System errors - escalate immediately
            return 0
            ;;
    esac

    return 1
}

# Log error recovery attempt
log_error_recovery() {
    local error_code="$1"
    local attempt="$2"
    local action="$3"

    if command -v foundation_log >/dev/null 2>&1; then
        foundation_log "info" "[$error_code] Recovery attempt $attempt: $action"
    else
        echo "[INFO] [$error_code] Recovery attempt $attempt: $action" >&2
    fi
}

# Mark error as resolved
resolve_error() {
    local error_code="$1"

    local error_file=$(ls -t "${ERRORS_DIR}"/*_${error_code}.json 2>/dev/null | head -1)
    if [ -f "$error_file" ]; then
        python3 -c "
import json
try:
    with open('$error_file', 'r') as f:
        data = json.load(f)
    data['resolved'] = True
    data['resolved_at'] = '$(date -u +"%Y-%m-%dT%H:%M:%SZ")'
    with open('$error_file', 'w') as f:
        json.dump(data, f, indent=2)
except: pass
" 2>/dev/null || true

        if command -v foundation_log >/dev/null 2>&1; then
            foundation_log "success" "[$error_code] Error resolved"
        else
            echo "[SUCCESS] [$error_code] Error resolved" >&2
        fi
    fi
}

# Get list of unresolved errors
get_unresolved_errors() {
    if [ ! -d "$ERRORS_DIR" ]; then
        return 0
    fi

    python3 -c "
import json
import os
import sys

errors_dir = '$ERRORS_DIR'
unresolved = []

try:
    for filename in os.listdir(errors_dir):
        if filename.endswith('.json'):
            filepath = os.path.join(errors_dir, filename)
            with open(filepath, 'r') as f:
                data = json.load(f)
            if not data.get('resolved', False):
                unresolved.append({
                    'code': data['error_code'],
                    'message': data['standard_message'],
                    'timestamp': data['timestamp']
                })

    if unresolved:
        print('Unresolved errors:')
        for err in unresolved:
            print(f\"  [{err['code']}] {err['message']} ({err['timestamp']})\")
    else:
        print('No unresolved errors')

except Exception as e:
    print(f'Error reading error logs: {e}', file=sys.stderr)
    sys.exit(1)
" 2>/dev/null || echo "Could not read error logs"
}

# Export functions for use in other scripts
export -f emit_error
export -f emit_error_and_escalate
export -f should_escalate
export -f log_error_recovery
export -f resolve_error
