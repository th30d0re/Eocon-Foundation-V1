#!/usr/bin/env bash

# Argent Runtime Agent - Stage 5b
# Boots a simulator via Argent CLI, installs the just-built .app, executes
# user flows from flows.json step-by-step, captures screenshots, and writes
# structured output consumed by the repair cycle.
#
# Exit Codes:
#   0  - All flows passed (or smoke test passed)
#   10 - Verification failed
#   11 - Misconfiguration (missing simulator / argent not on PATH / jq missing)

set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# Script directory resolution (supports symlinks)
# ─────────────────────────────────────────────────────────────────────────────

SOURCE="${BASH_SOURCE[0]}"
while [ -L "$SOURCE" ]; do
    SCRIPT_DIR="$(cd "$(dirname "$SOURCE")" && pwd)"
    SOURCE="$(readlink "$SOURCE")"
    [[ $SOURCE != /* ]] && SOURCE="$SCRIPT_DIR/$SOURCE"
done
SCRIPT_DIR="$(cd "$(dirname "$SOURCE")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"
FOUNDATION_LIB_DIR="$(cd "${SCRIPT_DIR}/../../../lib" 2>/dev/null && pwd || echo "")"

# Load Foundation helpers
HELPERS_LIB="${FOUNDATION_LIB_DIR}/helpers.sh"
if [ -f "$HELPERS_LIB" ]; then
    # shellcheck disable=SC1090
    source "$HELPERS_LIB"
    if type check_shell_compatibility &>/dev/null; then
        check_shell_compatibility || exit 11
    fi
fi

LOG_PREFIX="[ARGENT-AGENT]"

# ─────────────────────────────────────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────────────────────────────────────

SIMULATOR_NAME=""
SIMULATOR_UDID=""
BUNDLE_ID=""
ARTIFACTS_DIR="${ARTIFACTS_DIR:-./Artifacts}"
APP_PATH=""
FLOWS_FILE=""
SKIP_FLOWS="${SKIP_FLOWS:-false}"
VERBOSE="${VERBOSE:-false}"
DRY_RUN="${DRY_RUN:-false}"
SMART_FLOWS="${SMART_FLOWS:-false}"
WORK_DIR="$(pwd)"

ARGENT_DIR=""

# ─────────────────────────────────────────────────────────────────────────────
# Usage
# ─────────────────────────────────────────────────────────────────────────────

show_usage() {
    cat << EOF
Argent Runtime Agent - Stage 5b Runtime Verification

DESCRIPTION:
    Boots a simulator, installs the app, executes user flows defined in
    flows.json via Argent CLI, captures per-step screenshots, and writes
    structured output for the BuildAgent repair cycle.

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --simulator <name>      Simulator name (required; resolved to UDID via simulator.sh)
    --artifacts-dir <path>  Artifacts output directory (default: ./Artifacts)
    --app-path <path>       Explicit .app bundle path (auto-detected from build_output.txt if omitted)
    --bundle-id <id>        App bundle identifier (auto-detected from Info.plist if omitted)
    --flows <path>          Path to flows.json (defaults to <artifacts-dir>/flows.json)
    --smart-flows           Auto-generate test flows from git code changes (intelligent testing)
    --skip-flows            Skip flow execution; smoke test only (launch + no crash = pass)
    --verbose               Enable verbose output
    --dry-run               Show what would be done without executing
    --help                  Show this help message

PREREQUISITES:
    Run once in the project root before using Stage 5b:
        npx @swmansion/argent init

    Note: `argent install` is an alias for `init` — it does NOT install an app on a simulator.
    App install/launch uses: argent run reinstall-app / argent run launch-app

EXIT CODES:
    0   All flows passed (or smoke test passed)
    10  Verification failed
    11  Misconfiguration (no simulator / argent not on PATH / jq missing)

OUTPUT:
    <artifacts-dir>/argent/
    ├── screens/        Per-step screenshots captured during flow execution
    ├── errors.json     Structured verification errors consumed by BuildAgent --repair-from-errors
    └── summary.json    Per-flow verification results, step counts, and screenshots list

EXAMPLES:
    # Basic run
    $0 --simulator "iPhone 16 Pro"

    # Explicit app path
    $0 --simulator "iPhone 16 Pro" --app-path /path/to/MyApp.app

    # Smoke test only (no flows required)
    $0 --simulator "iPhone 16 Pro" --skip-flows

    # Skip Stage 5b via testAgent
    ./testAgent.sh --scheme MyApp --simulator-name "iPhone 16 Pro" --skip-argent
EOF
}

# ─────────────────────────────────────────────────────────────────────────────
# Logging helpers (inline fallback when helpers.sh is not sourced)
# ─────────────────────────────────────────────────────────────────────────────

if ! type log_info &>/dev/null 2>&1; then
    GREEN='\033[0;32m'
    RED='\033[0;31m'
    YELLOW='\033[1;33m'
    CYAN='\033[0;36m'
    NC='\033[0m'
    log_info()    { echo -e "${CYAN}[INFO]${NC}  ${LOG_PREFIX} $*" >&2; }
    log_success() { echo -e "${GREEN}[OK]${NC}    ${LOG_PREFIX} $*" >&2; }
    log_warning() { echo -e "${YELLOW}[WARN]${NC}  ${LOG_PREFIX} $*" >&2; }
    log_error()   { echo -e "${RED}[ERROR]${NC} ${LOG_PREFIX} $*" >&2; }
    log_section() { echo -e "${CYAN}$*${NC}" >&2; }
fi

log_verbose() {
    [ "$VERBOSE" = "true" ] && log_info "$*" || true
}

# ─────────────────────────────────────────────────────────────────────────────
# Argument parsing
# ─────────────────────────────────────────────────────────────────────────────

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --simulator)
                SIMULATOR_NAME="${2:-}"
                shift 2
                ;;
            --artifacts-dir)
                ARTIFACTS_DIR="${2:-./Artifacts}"
                shift 2
                ;;
            --app-path)
                APP_PATH="${2:-}"
                shift 2
                ;;
            --bundle-id)
                BUNDLE_ID="${2:-}"
                shift 2
                ;;
            --flows)
                FLOWS_FILE="${2:-}"
                shift 2
                ;;
            --smart-flows)
                SMART_FLOWS="true"
                shift 1
                ;;
            --skip-flows)
                SKIP_FLOWS="true"
                shift 1
                ;;
            --verbose|-v)
                VERBOSE="true"
                shift 1
                ;;
            --dry-run)
                DRY_RUN="true"
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
}

# ─────────────────────────────────────────────────────────────────────────────
# Prerequisite checks
# ─────────────────────────────────────────────────────────────────────────────

check_prerequisites() {
    local ok=true

    if [ -z "$SIMULATOR_NAME" ]; then
        log_warning "No simulator specified (--simulator) — Stage 5b skipped"
        ok=false
    fi

    if ! command -v argent >/dev/null 2>&1; then
        log_warning "argent not found on PATH — Stage 5b skipped"
        log_warning "Run: npx @swmansion/argent init"
        ok=false
    fi

    if ! command -v jq >/dev/null 2>&1; then
        log_warning "jq not found on PATH — Stage 5b skipped (jq is a pipeline dependency)"
        ok=false
    fi

    [ "$ok" = "true" ] && return 0 || return 11
}

# Invoke an argent tool via `argent run <tool>` (v0.8+ CLI)
run_argent_tool() {
    local tool="$1"
    shift
    log_verbose "argent run $tool $*"
    argent run "$tool" "$@" --json
}

# ─────────────────────────────────────────────────────────────────────────────
# Bundle ID resolution
# ─────────────────────────────────────────────────────────────────────────────

resolve_bundle_id() {
    if [ -n "$BUNDLE_ID" ]; then
        log_verbose "Using explicit bundle ID: $BUNDLE_ID"
        return 0
    fi

    if [ -n "$APP_PATH" ] && [ -f "${APP_PATH}/Info.plist" ]; then
        BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print CFBundleIdentifier" "${APP_PATH}/Info.plist" 2>/dev/null || true)
        if [ -n "$BUNDLE_ID" ]; then
            log_verbose "Auto-detected bundle ID: $BUNDLE_ID"
            return 0
        fi
    fi

    log_error "Could not resolve bundle ID — provide --bundle-id or ensure Info.plist exists in .app"
    return 11
}

# ─────────────────────────────────────────────────────────────────────────────
# App path resolution
# ─────────────────────────────────────────────────────────────────────────────

resolve_app_path() {
    if [ -n "$APP_PATH" ]; then
        if [ -d "$APP_PATH" ]; then
            log_verbose "Using explicit app path: $APP_PATH"
            return 0
        else
            log_error "Specified --app-path does not exist: $APP_PATH"
            return 11
        fi
    fi

    # Prefer the most recently written build_output.txt under the artifacts dir
    local build_output
    build_output=$(ls -t "${ARTIFACTS_DIR}"/build_*/build_output.txt 2>/dev/null | head -1 || true)
    if [ -f "$build_output" ]; then
        local candidate
        candidate=$(cat "$build_output")
        if [ -d "$candidate" ]; then
            APP_PATH="$candidate"
            log_verbose "Auto-detected app path from build_output.txt: $APP_PATH"
            return 0
        fi
        log_warning "build_output.txt points to non-existent path: $candidate"
    fi

    # Fallback: glob for any .app bundle under the artifacts dir
    local found_app
    found_app=$(find "$ARTIFACTS_DIR" -name "*.app" -maxdepth 5 2>/dev/null | head -1 || true)
    if [ -n "$found_app" ]; then
        APP_PATH="$found_app"
        log_verbose "Fallback app detection: $APP_PATH"
        return 0
    fi

    # Fallback: most recent Debug-iphonesimulator build in project derived-data
    found_app=$(find "$WORK_DIR" -path "*/Build/Products/Debug-iphonesimulator/*.app" -type d 2>/dev/null | head -1 || true)
    if [ -n "$found_app" ]; then
        APP_PATH="$found_app"
        log_verbose "Derived-data app detection: $APP_PATH"
        return 0
    fi

    log_error "Could not resolve .app path — provide --app-path or ensure build_output.txt exists"
    return 10
}

# ─────────────────────────────────────────────────────────────────────────────
# Simulator boot
# ─────────────────────────────────────────────────────────────────────────────

boot_simulator_for_argent() {
    log_info "Resolving simulator: $SIMULATOR_NAME"

    if [ -f "${LIB_DIR}/simulator.sh" ]; then
        # shellcheck disable=SC1091
        source "${LIB_DIR}/simulator.sh"
        SIMULATOR_UDID=$(get_simulator_by_name "$SIMULATOR_NAME") || {
            log_error "Could not resolve simulator UDID for: $SIMULATOR_NAME"
            return 11
        }
        log_verbose "Simulator UDID: $SIMULATOR_UDID"

        if [ "$(is_simulator_booted "$SIMULATOR_UDID")" != "true" ]; then
            log_info "Booting simulator via argent..."
        else
            log_info "Simulator already booted"
        fi
    else
        # Direct xcrun simctl fallback when simulator.sh is not available
        log_verbose "simulator.sh not found — using xcrun simctl directly"
        SIMULATOR_UDID=$(xcrun simctl list devices available -j 2>/dev/null | \
            jq -r --arg name "$SIMULATOR_NAME" \
            '.devices | to_entries[] | .value[] | select(.name == $name and .isAvailable == true) | .udid' | \
            head -1 || true)
        if [ -z "$SIMULATOR_UDID" ]; then
            log_error "Simulator not found via xcrun simctl: $SIMULATOR_NAME"
            return 11
        fi
        log_verbose "Simulator UDID: $SIMULATOR_UDID"
    fi

    if [ "$DRY_RUN" = "true" ]; then
        log_info "[DRY RUN] Would boot simulator UDID: $SIMULATOR_UDID"
        return 0
    fi

    # Argent owns boot/wait-for-ready (handles cold boot, timeouts, etc.)
    local boot_output boot_exit=0
    boot_output=$(run_argent_tool boot-device --udid "$SIMULATOR_UDID" 2>&1) || boot_exit=$?
    if [ $boot_exit -ne 0 ]; then
        log_warning "argent boot-device returned exit $boot_exit (simulator may already be ready)"
        log_verbose "$boot_output"
    else
        log_success "Simulator ready"
    fi

    return 0
}

# ─────────────────────────────────────────────────────────────────────────────
# App installation
# ─────────────────────────────────────────────────────────────────────────────

install_app() {
    log_info "Installing app: $APP_PATH"

    if [ "$DRY_RUN" = "true" ]; then
        log_info "[DRY RUN] Would reinstall: $APP_PATH on $SIMULATOR_UDID ($BUNDLE_ID)"
        return 0
    fi

    local install_output install_exit=0
    install_output=$(run_argent_tool reinstall-app \
        --udid "$SIMULATOR_UDID" \
        --bundleId "$BUNDLE_ID" \
        --appPath "$APP_PATH" 2>&1) || install_exit=$?

    if [ $install_exit -ne 0 ]; then
        log_error "Failed to install app on simulator"
        log_verbose "$install_output"
        return 10
    fi

    log_success "App installed"
    log_verbose "$install_output"
}

# ─────────────────────────────────────────────────────────────────────────────
# Smart flow generation from code changes
# ─────────────────────────────────────────────────────────────────────────────

generate_smart_flows() {
    local testgen_dir="${SCRIPT_DIR}/lib/testgen"
    local analyzer="${testgen_dir}/code_change_analyzer.py"
    local generator="${testgen_dir}/flow_generator.py"
    local coordinate_discovery="${testgen_dir}/coordinate_discovery.py"
    local translator="${SCRIPT_DIR}/lib/translate_flows.sh"

    if [ ! -f "$analyzer" ] || [ ! -f "$generator" ]; then
        log_warning "Smart flow generation tools not found — falling back to default flows"
        return 1
    fi

    log_info "🔍 Analyzing code changes for intelligent test flow generation..."

    local analysis_json="${WORK_DIR}/.argent/analysis.json"
    local generated_flows="${WORK_DIR}/Artifacts/flows_generated.json"
    local flows_with_coords="${WORK_DIR}/Artifacts/flows_with_coords.json"

    # Step 1: Analyze changes
    if ! python3 "$analyzer" \
        --project-root "$WORK_DIR" \
        --base-ref HEAD \
        --head-ref HEAD \
        --include-untracked \
        --output "$analysis_json" 2>&1; then
        log_warning "Code change analysis failed — falling back to default flows"
        return 1
    fi

    local changed_count
    changed_count=$(python3 -c "import json; print(json.load(open('$analysis_json'))['analysis']['total_swift_files_changed'])")

    if [ "$changed_count" -eq 0 ]; then
        log_info "No Swift changes detected — using default flows or smoke test"
        rm -f "$analysis_json"
        return 1
    fi

    log_success "Detected $changed_count changed file(s)"

    # Step 2: Generate flows
    log_info "📝 Generating test flows from impact analysis..."
    if ! python3 "$generator" \
        --impact-json "$analysis_json" \
        --project-root "$WORK_DIR" \
        --output "$generated_flows" 2>&1; then
        log_warning "Flow generation failed — falling back to default flows"
        return 1
    fi

    local flow_count
    flow_count=$(python3 -c "import json; print(len(json.load(open('$generated_flows'))['flows']))")
    log_success "Generated $flow_count test flow(s)"

    # Step 3: Discover coordinates (if simulator is available)
    if [ -n "$SIMULATOR_UDID" ] && [ -n "$BUNDLE_ID" ]; then
        log_info "🎯 Discovering element coordinates on simulator..."
        if python3 "$coordinate_discovery" \
            --flows "$generated_flows" \
            --udid "$SIMULATOR_UDID" \
            --bundle-id "$BUNDLE_ID" \
            --project-root "$WORK_DIR" \
            --output "$flows_with_coords" 2>&1; then
            log_success "Coordinates discovered"
            cp "$flows_with_coords" "${WORK_DIR}/Artifacts/flows.json"
        else
            log_warning "Coordinate discovery failed — using generic coordinates"
            cp "$generated_flows" "${WORK_DIR}/Artifacts/flows.json"
        fi
    else
        cp "$generated_flows" "${WORK_DIR}/Artifacts/flows.json"
    fi

    # Step 4: Translate to Argent YAML
    log_info "🔄 Translating to Argent YAML..."
    rm -rf "${WORK_DIR}/.argent/flows"
    if [ -x "$translator" ]; then
        "$translator" --project-root "$WORK_DIR" --bundle-id "$BUNDLE_ID" --udid "$SIMULATOR_UDID" >/dev/null 2>&1 || true
    fi

    # Cleanup
    rm -f "$analysis_json" "$generated_flows" "$flows_with_coords"

    FLOWS_FILE="${WORK_DIR}/Artifacts/flows.json"
    return 0
}

# ─────────────────────────────────────────────────────────────────────────────
# Flows file resolution
# ─────────────────────────────────────────────────────────────────────────────

resolve_flows_file() {
    if [ -n "$FLOWS_FILE" ]; then
        if [ -f "$FLOWS_FILE" ]; then
            log_verbose "Using flows file: $FLOWS_FILE"
            return 0
        else
            log_warning "Specified --flows file not found: $FLOWS_FILE — falling back to smoke test"
            SKIP_FLOWS="true"
            return 0
        fi
    fi

    local default_flows="${ARTIFACTS_DIR}/flows.json"
    if [ -f "$default_flows" ]; then
        FLOWS_FILE="$default_flows"
        log_verbose "Auto-detected flows file: $FLOWS_FILE"
        return 0
    fi

    log_warning "No flows.json found — running smoke test only"
    SKIP_FLOWS="true"
    return 0
}

# ─────────────────────────────────────────────────────────────────────────────
# Artifact writers
# ─────────────────────────────────────────────────────────────────────────────

write_summary() {
    local status="$1"
    local flows_json="$2"
    local passed="$3"
    local failed="$4"
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    local screenshots
    screenshots=$(find "${ARGENT_DIR}/screens" -name "*.png" 2>/dev/null | sort | jq -R . | jq -s . 2>/dev/null || echo "[]")

    jq -n \
        --arg status "$status" \
        --argjson flows "$flows_json" \
        --argjson passed "$passed" \
        --argjson failed "$failed" \
        --arg simulator "$SIMULATOR_NAME" \
        --arg appPath "${APP_PATH:-}" \
        --arg timestamp "$timestamp" \
        --argjson screenshots "$screenshots" \
        '{
            status: $status,
            simulator: $simulator,
            appPath: $appPath,
            timestamp: $timestamp,
            flowsPassed: $passed,
            flowsFailed: $failed,
            flows: (if ($flows | type) == "array" then $flows else ($flows.flows // []) end),
            screenshots: $screenshots
        }' > "${ARGENT_DIR}/summary.json"

    log_verbose "Wrote: ${ARGENT_DIR}/summary.json"
}

write_errors() {
    local errors_json="$1"
    echo "$errors_json" | jq . > "${ARGENT_DIR}/errors.json"
    log_verbose "Wrote: ${ARGENT_DIR}/errors.json"
}

# ─────────────────────────────────────────────────────────────────────────────
# HTML Report generation
# ─────────────────────────────────────────────────────────────────────────────

generate_report() {
    local flow_results="$1"
    local total_passed="$2"
    local total_failed="$3"
    shift 3
    local exec_files=("$@")

    local report_generator="${SCRIPT_DIR}/lib/testgen/report_generator.py"
    if [ ! -f "$report_generator" ]; then
        log_warning "Report generator not found — skipping HTML report"
        return 1
    fi

    log_info "📊 Generating HTML report..."

    # Combine all execution JSONs into one (validate each first)
    local combined_json="${ARGENT_DIR}/executions_combined.json"
    local valid_flows="[]"
    for f in "${exec_files[@]}"; do
        [ -f "$f" ] || continue
        # Check if it's valid JSON and contains 'steps' (flow-execute output)
        if jq -e '.steps' "$f" >/dev/null 2>&1; then
            valid_flows=$(echo "$valid_flows" | jq --argjson flow "$(cat "$f")" '. + [$flow]' 2>/dev/null || echo "$valid_flows")
        fi
    done
    echo "{\"flows\": $valid_flows}" > "$combined_json"

    local analysis_json="${WORK_DIR}/.argent/analysis.json"
    local report_html="${ARGENT_DIR}/report.html"

    if python3 "$report_generator" \
        --execution-json "$combined_json" \
        ${analysis_json:+--analysis-json "$analysis_json"} \
        --screenshots-dir "${ARGENT_DIR}/screens" \
        --project-name "AmmoScan" \
        --bundle-id "$BUNDLE_ID" \
        --simulator "$SIMULATOR_UDID" \
        --output "$report_html" 2>&1; then
        log_success "HTML report generated: $report_html"
        # Also copy to Artifacts root for easy access
        cp "$report_html" "${ARTIFACTS_DIR}/test_report.html" 2>/dev/null || true
    else
        log_warning "HTML report generation failed"
    fi

    rm -f "$combined_json"
}

# ─────────────────────────────────────────────────────────────────────────────
# Flow execution
# ─────────────────────────────────────────────────────────────────────────────

run_flows() {
    local screens_dir="${ARGENT_DIR}/screens"
    mkdir -p "$screens_dir"

    # ── Smoke test mode ───────────────────────────────────────────────────────
    if [ "$SKIP_FLOWS" = "true" ]; then
        log_info "Running smoke test (launch + screenshot)..."

        if [ "$DRY_RUN" = "true" ]; then
            log_info "[DRY RUN] Would launch $BUNDLE_ID on $SIMULATOR_UDID"
            write_summary "passed" "[]" 0 0
            return 0
        fi

        local launch_output launch_exit=0
        launch_output=$(run_argent_tool launch-app \
            --udid "$SIMULATOR_UDID" \
            --bundleId "$BUNDLE_ID" 2>&1) || launch_exit=$?

        if [ $launch_exit -ne 0 ]; then
            log_error "App launch failed (exit $launch_exit)"
            log_verbose "$launch_output"
            write_errors "[{\"type\":\"launch_failure\",\"message\":\"App failed to launch on simulator\",\"exitCode\":$launch_exit}]"
            write_summary "failed" "[]" 0 1
            return 10
        fi

        log_verbose "$launch_output"

        local screenshot_exit=0
        run_argent_tool screenshot \
            --udid "$SIMULATOR_UDID" \
            --out "${screens_dir}/launch.png" >/dev/null 2>&1 || screenshot_exit=$?

        if [ $screenshot_exit -ne 0 ]; then
            log_warning "Screenshot capture failed (exit $screenshot_exit) — launch succeeded"
        fi

        log_success "Smoke test passed"
        write_summary "passed" "[]" 1 0
        return 0
    fi

    # ── Full flow execution (.argent/flows/*.yaml via flow-execute) ─────────────
    log_info "Executing flows from: $FLOWS_FILE"

    if [ "$DRY_RUN" = "true" ]; then
        log_info "[DRY RUN] Would execute .argent/flows on $SIMULATOR_UDID"
        write_summary "passed" "[]" 0 0
        return 0
    fi

    local flows_dir="${WORK_DIR}/.argent/flows"
    if [ ! -d "$flows_dir" ] || [ -z "$(find "$flows_dir" -name '*.yaml' -o -name '*.yml' 2>/dev/null | head -1)" ]; then
        log_warning "No .argent/flows/*.yaml found — attempting auto-translation from flows.json"

        local translator="${SCRIPT_DIR}/lib/translate_flows.sh"
        if [ -x "$translator" ] && [ -f "${WORK_DIR}/Artifacts/flows.json" ]; then
            if "$translator" --flows "${WORK_DIR}/Artifacts/flows.json" --project-root "$WORK_DIR" --bundle-id "$BUNDLE_ID" --udid "$SIMULATOR_UDID" >/dev/null 2>&1; then
                log_success "Auto-translated flows.json to .argent/flows/*.yaml"
            else
                log_warning "Auto-translation failed — falling back to smoke test"
                SKIP_FLOWS="true"
                run_flows
                return $?
            fi
        else
            log_warning "flows.json must be translated to Argent YAML flows first"
            log_warning "Falling back to smoke test (launch + screenshot)"
            SKIP_FLOWS="true"
            run_flows
            return $?
        fi
    fi

    local total_passed=0
    local total_failed=0
    local flow_results="[]"
    local all_executions=()
    local yaml_flow

    for yaml_flow in "$flows_dir"/*.yaml "$flows_dir"/*.yml; do
        [ -f "$yaml_flow" ] || continue
        local flow_name
        flow_name=$(basename "$yaml_flow" .yaml)
        flow_name=$(basename "$flow_name" .yml)
        log_info "Running flow: $flow_name"

        local flow_output flow_exit=0
        flow_output=$(run_argent_tool flow-execute \
            --name "$flow_name" \
            --project_root "$WORK_DIR" \
            --prerequisiteAcknowledged true 2>&1) || flow_exit=$?

        # Save execution JSON for report generation (wrap NDJSON into flow object)
        local exec_json="${ARGENT_DIR}/execution_${flow_name}.json"
        local flow_status="failed"
        [ $flow_exit -eq 0 ] && flow_status="passed"
        if [ -n "$flow_output" ]; then
            echo "$flow_output" | jq -s \
                --arg name "$flow_name" \
                --arg status "$flow_status" \
                '{name: $name, status: $status, steps: .}' > "$exec_json" 2>/dev/null || \
                echo "{\"name\":\"$flow_name\",\"status\":\"$flow_status\",\"steps\":[]}" > "$exec_json"
        else
            echo "{\"name\":\"$flow_name\",\"status\":\"$flow_status\",\"steps\":[]}" > "$exec_json"
        fi
        all_executions+=("$exec_json")

        if [ $flow_exit -eq 0 ]; then
            total_passed=$((total_passed + 1))
            flow_results=$(echo "$flow_results" | jq --arg name "$flow_name" --arg status "passed" \
                '. + [{name: $name, status: $status}]' 2>/dev/null || echo "$flow_results")
        else
            total_failed=$((total_failed + 1))
            log_error "Flow failed: $flow_name (exit $flow_exit)"
            log_verbose "$flow_output"
            flow_results=$(echo "$flow_results" | jq --arg name "$flow_name" --arg status "failed" \
                '. + [{name: $name, status: $status}]' 2>/dev/null || echo "$flow_results")
        fi
    done

    # Generate HTML report
    generate_report "$flow_results" "$total_passed" "$total_failed" "${all_executions[@]}"

    if [ $total_failed -eq 0 ] && [ $total_passed -gt 0 ]; then
        log_success "All flows passed (passed: $total_passed)"
        write_summary "passed" "$flow_results" "$total_passed" 0
        return 0
    fi

    write_errors "[{\"type\":\"flow_failure\",\"message\":\"One or more flows failed\",\"passed\":$total_passed,\"failed\":$total_failed}]"
    write_summary "failed" "$flow_results" "$total_passed" "$total_failed"
    return 10
}

# ─────────────────────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────────────────────

main() {
    parse_arguments "$@"

    log_section "────────────────────────────────────────"
    log_section "Argent Runtime Agent — Stage 5b"
    log_section "────────────────────────────────────────"
    echo "" >&2

    # Prerequisite guard — exits 11 on misconfiguration so the pipeline skips
    check_prerequisites || exit 11

    ARGENT_DIR="${ARTIFACTS_DIR}/argent"
    mkdir -p "${ARGENT_DIR}/screens"

    log_info "Simulator:     $SIMULATOR_NAME"
    log_info "Artifacts dir: $ARTIFACTS_DIR"
    echo "" >&2

    # Boot simulator
    boot_simulator_for_argent || exit 11

    # Resolve .app bundle path
    local app_exit=0
    resolve_app_path || app_exit=$?
    if [ $app_exit -eq 11 ]; then
        exit 11
    fi
    if [ $app_exit -ne 0 ]; then
        write_errors "[{\"type\":\"app_not_found\",\"message\":\"Could not resolve .app bundle path\"}]"
        write_summary "failed" "[]" 0 1
        exit 10
    fi

    log_info "App path:      $APP_PATH"

    resolve_bundle_id || exit 11
    log_info "Bundle ID:     $BUNDLE_ID"

    # Install app on simulator
    install_app || {
        write_errors "[{\"type\":\"install_failure\",\"message\":\"Failed to install app on simulator\",\"appPath\":\"$APP_PATH\"}]"
        write_summary "failed" "[]" 0 1
        exit 10
    }

    # Smart flow generation: auto-generate test flows from code changes
    if [ "$SMART_FLOWS" = "true" ]; then
        log_info "Smart flow generation enabled"
        generate_smart_flows || true
    fi

    # Determine flows file (sets SKIP_FLOWS if not found)
    resolve_flows_file

    # Execute flows (or smoke test)
    local flow_exit=0
    run_flows || flow_exit=$?

    if [ $flow_exit -eq 0 ]; then
        log_success "Stage 5b complete — all verifications passed"
        exit 0
    else
        log_error "Stage 5b complete — verification failed (see ${ARGENT_DIR}/errors.json)"
        exit 10
    fi
}

main "$@"
