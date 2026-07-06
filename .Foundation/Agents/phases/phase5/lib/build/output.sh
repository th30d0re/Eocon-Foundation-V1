#!/usr/bin/env bash
# lib/build/output.sh — JSON and status output functions for BuildAgent
[ -n "${_BUILD_OUTPUT_SH:-}" ] && return 0
_BUILD_OUTPUT_SH=1

output_json_result() {
    local success="$1"
    local output="$2"
    local error="${3:-null}"
    local duration="${4:-0}"
    local extra_metadata="$5"
    if [ -z "$extra_metadata" ]; then
        extra_metadata="{}"
    fi
    local next_steps="${6:-[]}"

    if [ "$JSON_OUTPUT" != "true" ]; then
        return 0
    fi

    # Escape special characters for JSON
    output=$(echo "$output" | jq -Rs '.' 2>/dev/null | sed 's/^"//;s/"$//' || echo "$output")

    if [ "$error" != "null" ]; then
        error=$(echo "$error" | jq -Rs '.' 2>/dev/null | sed 's/^"//;s/"$//' || echo "$error")
    fi

    # Build metadata object
    local metadata
    if command -v jq &>/dev/null; then
        metadata=$(jq -n \
            --arg logs_dir "${LOGS_DIR:-}" \
            --arg status_dir "${STATUS_DIR:-}" \
            --argjson attempts "${CURRENT_ATTEMPT:-0}" \
            --arg scheme "${SCHEME:-}" \
            --arg platform "${PLATFORM:-}" \
            --arg configuration "${BUILD_CONFIGURATION:-}" \
            --argjson extra "$extra_metadata" \
            '{
                logsDir: $logs_dir,
                statusDir: $status_dir,
                attempts: $attempts,
                scheme: $scheme,
                platform: $platform,
                configuration: $configuration
            } + $extra')
    else
        metadata="{\"logsDir\":\"${LOGS_DIR:-}\",\"statusDir\":\"${STATUS_DIR:-}\",\"attempts\":${CURRENT_ATTEMPT:-0}}"
    fi

    # Output JSON result (schemaVersion 2 adds nextSteps for agent consumers)
    if command -v jq &>/dev/null; then
        jq -n \
            --argjson success "$success" \
            --arg output "$output" \
            --arg error "$error" \
            --argjson duration "$duration" \
            --argjson metadata "$metadata" \
            --argjson next_steps "$next_steps" \
            '{
                schemaVersion: 2,
                success: $success,
                output: $output,
                error: (if $error == "null" then null else $error end),
                duration: $duration,
                metadata: $metadata,
                exitCode: (if $success then 0 else 1 end),
                nextSteps: $next_steps
            }'
    else
        # Fallback without jq
        local error_json
        if [ "$error" = "null" ]; then
            error_json="null"
        else
            error_json="\"$error\""
        fi

        cat <<EOF
{
  "schemaVersion": 2,
  "success": $success,
  "output": "$output",
  "error": $error_json,
  "duration": $duration,
  "metadata": $metadata,
  "exitCode": $([ "$success" = "true" ] && echo 0 || echo 1),
  "nextSteps": $next_steps
}
EOF
    fi
}

# Write build stage status for the orchestrator pipeline visualizer.
# Same JSON schema as TestAgent's stages.json.
write_build_stage() {
    local stage="$1"
    local status="${2:-running}"
    local duration="${3:-0}"
    local attempt="${4:-0}"

    if [ -z "${STATUS_DIR:-}" ]; then
        return
    fi

    local stages_file="${STATUS_DIR}/build_stages.json"
    if ! command -v jq >/dev/null 2>&1; then
        return
    fi

    local tmp_file
    tmp_file=$(mktemp)
    jq --arg stage "$stage" \
       --arg status "$status" \
       --argjson duration "$duration" \
       --argjson attempt "$attempt" \
       '.stages[$stage] = {"status": $status, "duration": $duration, "attempt": $attempt, "details": ""}' \
       "$stages_file" > "$tmp_file" 2>/dev/null || \
        echo "{\"stages\":{\"$stage\":{\"status\":\"$status\",\"duration\":$duration,\"attempt\":$attempt,\"details\":\"\"}}}" > "$tmp_file"
    mv "$tmp_file" "$stages_file"
}

write_stream_timeline() {
    local event="$1"
    local details="${2:-}"
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    if [ -n "$STREAM_TIMELINE_FILE" ]; then
        printf "[%s] %-18s | %s\n" "$timestamp" "$event" "$details" >> "$STREAM_TIMELINE_FILE"
    fi
}


write_success_status() {
    local status_file="${STATUS_DIR}/success.txt"

    cat > "$status_file" << EOF
Build Agent Completed Successfully
===================================
Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
Attempts: $CURRENT_ATTEMPT
Scheme: ${SCHEME:-auto-detected}
Configuration: $BUILD_CONFIGURATION

Artifacts:
- Build log: ${LOGS_DIR}/build.log
- Coder logs: ${LOGS_DIR}/coder_attempt_*.log
EOF

    log_success "Status written to: $status_file"

    # Write build_output.txt with the .app path for downstream consumers (e.g. test runners)
    if [ -n "$BUILT_PRODUCTS_DIR_CAPTURED" ] && [ -n "$SCHEME" ]; then
        local app_path="${BUILT_PRODUCTS_DIR_CAPTURED}/${SCHEME}.app"
        echo "$app_path" > "${ARTIFACTS_RUN_DIR:-$STATUS_DIR}/build_output.txt"
        log_success "build_output.txt written: $app_path"
    else
        log_warning "build_output.txt not written: BUILT_PRODUCTS_DIR_CAPTURED or SCHEME is empty"
    fi

    # Store success to Letta memory
    store_build_result "success"

    # Prompt to persist frequently-used flags as session defaults
    if type session_should_offer_persist &>/dev/null && type session_set_default &>/dev/null && type session_save &>/dev/null; then
        local prompted_any=false

        # Check scheme
        if [ -n "${user_provided_scheme:-}" ]; then
            if [ "$(session_should_offer_persist "--scheme" "$user_provided_scheme")" = "true" ]; then
                echo "" >&2
                log_info "You've used --scheme $user_provided_scheme multiple times recently."
                read -p "Save --scheme $user_provided_scheme as default? (y/N) " -n 1 -r save
                echo "" >&2
                if [[ $save =~ ^[Yy]$ ]]; then
                    session_set_default "scheme" "$user_provided_scheme"
                    prompted_any=true
                    log_success "Saved scheme as default"
                fi
            fi
        fi

        # Check configuration
        if [ -n "${user_provided_configuration:-}" ]; then
            if [ "$(session_should_offer_persist "--configuration" "$user_provided_configuration")" = "true" ]; then
                echo "" >&2
                log_info "You've used --configuration $user_provided_configuration multiple times recently."
                read -p "Save --configuration $user_provided_configuration as default? (y/N) " -n 1 -r save
                echo "" >&2
                if [[ $save =~ ^[Yy]$ ]]; then
                    session_set_default "configuration" "$user_provided_configuration"
                    prompted_any=true
                    log_success "Saved configuration as default"
                fi
            fi
        fi

        # Check platform
        if [ -n "${user_provided_platform:-}" ]; then
            if [ "$(session_should_offer_persist "--platform" "$user_provided_platform")" = "true" ]; then
                echo "" >&2
                log_info "You've used --platform $user_provided_platform multiple times recently."
                read -p "Save --platform $user_provided_platform as default? (y/N) " -n 1 -r save
                echo "" >&2
                if [[ $save =~ ^[Yy]$ ]]; then
                    session_set_default "platform" "$user_provided_platform"
                    prompted_any=true
                    log_success "Saved platform as default"
                fi
            fi
        fi

        # Check AI provider
        if [ -n "${user_provided_ai_provider:-}" ]; then
            if [ "$(session_should_offer_persist "--ai-provider" "$user_provided_ai_provider")" = "true" ]; then
                echo "" >&2
                log_info "You've used --ai-provider $user_provided_ai_provider multiple times recently."
                read -p "Save --ai-provider $user_provided_ai_provider as default? (y/N) " -n 1 -r save
                echo "" >&2
                if [[ $save =~ ^[Yy]$ ]]; then
                    session_set_default "ai_provider" "$user_provided_ai_provider"
                    prompted_any=true
                    log_success "Saved AI provider as default"
                fi
            fi
        fi

        # Save session if any defaults were updated
        if [ "$prompted_any" = true ]; then
            session_save
            log_info "Session defaults saved to .foundation-session.json"
        fi
    fi
}

write_build_guide() {
    if [ "${BUILD_GUIDES:-1}" = "0" ] || [ "$DRY_RUN" = "true" ]; then
        return 0
    fi

    local guides_dir="${PROJECT_ROOT:-.}/Guides"
    mkdir -p "$guides_dir"

    local timestamp
    timestamp=$(date -u +"%Y%m%d_%H%M%S")
    local guide_file="${guides_dir}/build_${timestamp}.md"

    # Extract first ~30 lines of prompt/plan
    local input_summary=""
    if [ -n "${PROMPT_CONTENT:-}" ]; then
        input_summary=$(echo "$PROMPT_CONTENT" | head -n 30)
    elif type get_input_content &>/dev/null; then
        input_summary=$(get_input_content | head -n 30)
    fi

    local strategies="${ACCUMULATED_STRATEGIES:-None recorded}"
    local errors="${ACCUMULATED_ERRORS:-None recorded}"

    cat > "$guide_file" << EOF
# Build Agent Implementation Guide
**Date:** $(date -u +"%Y-%m-%d %H:%M:%S UTC")

## What was implemented
\`\`\`text
$input_summary
\`\`\`

## How
- **Provider:** ${AI_PROVIDER:-unknown}
- **Model:** ${AI_MODEL:-unknown}
- **Total Attempts Used:** ${CURRENT_ATTEMPT:-0}

## Decisions made and rationale
- **Repair Strategies Applied:** $strategies

## Challenges
- **Error Patterns Encountered:** $errors

## Solutions applied
(Solutions implemented by the build agent based on the repair strategies above)

## Lessons learned
- **Status:** $([ "${CURRENT_ATTEMPT:-0}" -lt "${MAX_REPAIR_ATTEMPTS:-3}" ] && echo "Passed" || echo "Failed")
- **Pass/Fail Counts:** Attempts: ${CURRENT_ATTEMPT:-0}
EOF

    log_success "Build guide written to: $guide_file"
}

write_human_intervention() {
    local status_file="${STATUS_DIR}/human_intervention.md"
    local all_errors=""

    # Collect all error logs
    for error_log in "${LOGS_DIR}"/error_attempt_*.log; do
        if [ -f "$error_log" ]; then
            all_errors+="
### $(basename "$error_log")
\`\`\`
$(cat "$error_log")
\`\`\`
"
        fi
    done

    cat > "$status_file" << EOF
# Human Intervention Required

## Summary
Build Agent failed after $MAX_REPAIR_ATTEMPTS repair attempts.

## Timestamp
$(date -u +"%Y-%m-%dT%H:%M:%SZ")

## Configuration
- Scheme: ${SCHEME:-auto-detected}
- Configuration: $BUILD_CONFIGURATION
- Target: ${TARGET_ID:-${DESTINATION:-default simulator}}

## Input
$(get_input_content | head -50)
...

## Error History
$all_errors

## Recommendations
1. Review the error logs above
2. Check for missing dependencies or configuration issues
3. Manually fix the problematic code
4. Re-run the build agent after fixes

## Artifacts Location
\`${LOGS_DIR}\`

---
*Generated by BuildAgent - Phase 5*
EOF

    log_error "Human intervention required: $status_file"

    # Also emit to errors directory if available
    if [ -d "${PROJECT_ROOT}/.foundation/errors" ]; then
        cp "$status_file" "${PROJECT_ROOT}/.foundation/errors/human_intervention_$(date +%Y%m%d_%H%M%S).md"
    fi

    # Store failure to Letta memory
    store_build_result "failure" "$all_errors"
}

# ─────────────────────────────────────────────────────────────────────────────
