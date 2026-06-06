#!/usr/bin/env bash
#
# translate_flows.sh — Convert flows.json → .argent/flows/*.yaml
#
# Usage:
#   translate_flows.sh [--flows <path>] [--project-root <path>] [--bundle-id <id>]
#
# Defaults:
#   --flows        ./Artifacts/flows.json
#   --project-root $(pwd)
#   --bundle-id    auto-detected from .app Info.plist
#
# Outputs:
#   Creates .argent/flows/<flow-name>.yaml for each flow in flows.json

set -euo pipefail

FLOWS_FILE=""
PROJECT_ROOT=""
BUNDLE_ID=""
UDID=""

resolve_project_root() {
    if [ -n "$PROJECT_ROOT" ]; then
        echo "$PROJECT_ROOT"
        return 0
    fi
    echo "$(pwd)"
}

resolve_bundle_id() {
    if [ -n "$BUNDLE_ID" ]; then
        echo "$BUNDLE_ID"
        return 0
    fi
    local app_path
    app_path=$(find "$(resolve_project_root)" -path "*/Build/Products/Debug-iphonesimulator/*.app" -type d 2>/dev/null | head -1 || true)
    if [ -n "$app_path" ] && [ -f "${app_path}/Info.plist" ]; then
        /usr/libexec/PlistBuddy -c "Print CFBundleIdentifier" "${app_path}/Info.plist" 2>/dev/null || true
    fi
}

resolve_flows_file() {
    if [ -n "$FLOWS_FILE" ]; then
        echo "$FLOWS_FILE"
        return 0
    fi
    local candidate="$(resolve_project_root)/Artifacts/flows.json"
    if [ -f "$candidate" ]; then
        echo "$candidate"
    fi
}

slugify() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-//;s/-$//'
}

onboarding_preamble() {
    cat << 'ONBOARDING'
  # ── Simulator bypass: app auto-completes onboarding & logs in as Owner ─────
  - echo: "Launch app (simulator bypass handles first-run setup)"
  - tool: launch-app
    args:
      udid: "{{UDID}}"
      bundleId: "{{BUNDLE_ID}}"
    delayMs: 2500
ONBOARDING
}

translate_step() {
    local action="$1"
    local element="${2:-}"
    local direction="${3:-}"
    local id="${4:-}"
    local description="${5:-}"

    case "$action" in
        launch)
            cat << STEP
  - echo: "Launch app (ensure in foreground)"
  - tool: launch-app
    args:
      udid: "{{UDID}}"
      bundleId: "{{BUNDLE_ID}}"
    delayMs: 1000
STEP
            ;;
        tap)
            cat << STEP
  - echo: "Tap element: ${element}"
  - tool: gesture-tap
    args:
      udid: "{{UDID}}"
      x: 0.5
      y: 0.5
STEP
            ;;
        screenshot)
            cat << STEP
  - echo: "Screenshot: ${description}"
  - tool: screenshot
    args:
      udid: "{{UDID}}"
STEP
            ;;
        scroll)
            local swipe_args
            case "$direction" in
                down)
                    swipe_args='{"udid": "{{UDID}}", "x": 0.5, "y": 0.7, "toX": 0.5, "toY": 0.3}'
                    ;;
                up)
                    swipe_args='{"udid": "{{UDID}}", "x": 0.5, "y": 0.3, "toX": 0.5, "toY": 0.7}'
                    ;;
                left)
                    swipe_args='{"udid": "{{UDID}}", "x": 0.7, "y": 0.5, "toX": 0.3, "toY": 0.5}'
                    ;;
                right)
                    swipe_args='{"udid": "{{UDID}}", "x": 0.3, "y": 0.5, "toX": 0.7, "toY": 0.5}'
                    ;;
                *)
                    swipe_args='{"udid": "{{UDID}}", "x": 0.5, "y": 0.7, "toX": 0.5, "toY": 0.3}'
                    ;;
            esac
            cat << STEP
  - echo: "Scroll ${direction}: ${description}"
  - tool: gesture-swipe
    args:
      udid: "{{UDID}}"
      x: $(echo "$swipe_args" | jq -r '.x')
      y: $(echo "$swipe_args" | jq -r '.y')
      toX: $(echo "$swipe_args" | jq -r '.toX')
      toY: $(echo "$swipe_args" | jq -r '.toY')
STEP
            ;;
        *)
            cat << STEP
  - echo: "Unknown action: ${action} (${description})"
STEP
            ;;
    esac
}

main() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --flows)
                FLOWS_FILE="$2"
                shift 2
                ;;
            --project-root)
                PROJECT_ROOT="$2"
                shift 2
                ;;
            --bundle-id)
                BUNDLE_ID="$2"
                shift 2
                ;;
            --udid)
                UDID="$2"
                shift 2
                ;;
            *)
                echo "Unknown option: $1" >&2
                exit 1
                ;;
        esac
    done

    local project_root flows_file bundle_id
    project_root=$(resolve_project_root)
    flows_file=$(resolve_flows_file)
    bundle_id=$(resolve_bundle_id)

    if [ -z "$flows_file" ] || [ ! -f "$flows_file" ]; then
        echo "Error: flows.json not found. Use --flows or ensure ./Artifacts/flows.json exists." >&2
        exit 1
    fi

    if [ -z "$bundle_id" ]; then
        echo "Error: Could not auto-detect bundle ID. Use --bundle-id." >&2
        exit 1
    fi

    if ! command -v jq >/dev/null 2>&1; then
        echo "Error: jq is required for flow translation." >&2
        exit 1
    fi

    local flows_dir="${project_root}/.argent/flows"
    mkdir -p "$flows_dir"

    local flow_count
    flow_count=$(jq '.flows | length' "$flows_file")
    echo "Translating ${flow_count} flow(s) from ${flows_file} → ${flows_dir}/" >&2

    local i=0
    while [ "$i" -lt "$flow_count" ]; do
        local flow_name
        flow_name=$(jq -r ".flows[${i}].name" "$flows_file")
        local slug
        slug=$(slugify "$flow_name")
        local yaml_file="${flows_dir}/${slug}.yaml"

        {
            echo "executionPrerequisite: App installed on simulator; simulator bypass auto-logs in as Owner"
            echo "steps:"

            # Onboarding preamble — navigates first-run welcome → name entry → account creation
            onboarding_preamble

            local step_count
            step_count=$(jq ".flows[${i}].steps | length" "$flows_file")
            local j=0
            while [ "$j" -lt "$step_count" ]; do
                local action element direction id description
                action=$(jq -r ".flows[${i}].steps[${j}].action" "$flows_file")
                element=$(jq -r ".flows[${i}].steps[${j}].element // empty" "$flows_file")
                direction=$(jq -r ".flows[${i}].steps[${j}].direction // empty" "$flows_file")
                id=$(jq -r ".flows[${i}].steps[${j}].id // empty" "$flows_file")
                description=$(jq -r ".flows[${i}].steps[${j}].description // empty" "$flows_file")

                translate_step "$action" "$element" "$direction" "$id" "$description"
                j=$((j + 1))
            done
        } | sed "s/{{BUNDLE_ID}}/${bundle_id}/g; s/{{UDID}}/${UDID}/g" > "$yaml_file"

        echo "  Created: ${yaml_file}" >&2
        i=$((i + 1))
    done

    echo "Done. ${flow_count} flow YAML file(s) written to ${flows_dir}/" >&2
}

main "$@"
