#!/usr/bin/env bash
#
# generate_and_run.sh — Intelligent test flow generation and execution pipeline.
#
# This script:
#   1. Analyzes git code changes
#   2. Maps changes to test areas
#   3. Generates flows.json with targeted test steps
#   4. Discovers element coordinates at runtime
#   5. Translates to Argent YAML
#   6. Executes the flows
#
# Usage:
#   generate_and_run.sh --project-root PATH --udid UDID [--base-ref REF] [--head-ref REF]
#
# Environment:
#   BUNDLE_ID    — App bundle identifier (auto-detected if not set)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT=""
UDID=""
BASE_REF="HEAD~1"
HEAD_REF="HEAD"
BUNDLE_ID="${BUNDLE_ID:-}"

# ── Argument parsing ─────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --project-root)
            PROJECT_ROOT="$2"
            shift 2
            ;;
        --udid)
            UDID="$2"
            shift 2
            ;;
        --base-ref)
            BASE_REF="$2"
            shift 2
            ;;
        --head-ref)
            HEAD_REF="$2"
            shift 2
            ;;
        --bundle-id)
            BUNDLE_ID="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

if [[ -z "$PROJECT_ROOT" ]]; then
    echo "Error: --project-root is required" >&2
    exit 1
fi

if [[ -z "$UDID" ]]; then
    echo "Error: --udid is required" >&2
    exit 1
fi

PROJECT_ROOT="$(cd "$PROJECT_ROOT" && pwd)"

# Auto-detect bundle ID if not provided
if [[ -z "$BUNDLE_ID" ]]; then
    app_path=$(find "$PROJECT_ROOT" -path "*/Build/Products/Debug-iphonesimulator/*.app" -type d 2>/dev/null | head -1 || true)
    if [[ -n "$app_path" && -f "${app_path}/Info.plist" ]]; then
        BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print CFBundleIdentifier" "${app_path}/Info.plist" 2>/dev/null || true)
    fi
fi

if [[ -z "$BUNDLE_ID" ]]; then
    echo "Error: Could not auto-detect bundle ID. Use --bundle-id or set BUNDLE_ID." >&2
    exit 1
fi

echo "══════════════════════════════════════════════════════════════════"
echo "  Intelligent Test Flow Generator"
echo "══════════════════════════════════════════════════════════════════"
echo "  Project:  $PROJECT_ROOT"
echo "  UDID:     $UDID"
echo "  Bundle:   $BUNDLE_ID"
echo "  Base:     $BASE_REF"
echo "  Head:     $HEAD_REF"
echo ""

# ── Step 1: Analyze code changes ─────────────────────────────────────────────
echo "🔍 STEP 1: Analyzing code changes ($BASE_REF → $HEAD_REF)..."
ANALYSIS_JSON="${PROJECT_ROOT}/.argent/analysis_$(date +%s).json"
python3 "${SCRIPT_DIR}/code_change_analyzer.py" \
    --project-root "$PROJECT_ROOT" \
    --base-ref "$BASE_REF" \
    --head-ref "$HEAD_REF" \
    --include-untracked \
    --output "$ANALYSIS_JSON" 2>&1

CHANGED_FILES=$(python3 -c "import json; d=json.load(open('$ANALYSIS_JSON')); print(d['analysis']['total_swift_files_changed'])")
echo "   Found $CHANGED_FILES changed Swift file(s)"

if [[ "$CHANGED_FILES" -eq 0 ]]; then
    echo ""
    echo "✅ No Swift changes detected. Skipping test generation."
    rm -f "$ANALYSIS_JSON"
    exit 0
fi

# Show what changed
echo ""
echo "   Changed files:"
python3 -c "
import json
d = json.load(open('$ANALYSIS_JSON'))
for i in d['impacts']:
    pri = i['test_priority']
    icon = {'critical':'🔴','high':'🟠','medium':'🟡','low':'🟢'}.get(pri, '⚪')
    print(f'   {icon} {i[\"file_path\"]} ({i[\"lines_added\"]}+/{i[\"lines_deleted\"]}-) [{pri}]')
"

# ── Step 2: Generate flows.json ──────────────────────────────────────────────
echo ""
echo "📝 STEP 2: Generating test flows..."
FLOWS_JSON="${PROJECT_ROOT}/Artifacts/flows_generated.json"
mkdir -p "$(dirname "$FLOWS_JSON")"
python3 "${SCRIPT_DIR}/flow_generator.py" \
    --impact-json "$ANALYSIS_JSON" \
    --project-root "$PROJECT_ROOT" \
    --output "$FLOWS_JSON" 2>&1

FLOW_COUNT=$(python3 -c "import json; d=json.load(open('$FLOWS_JSON')); print(len(d['flows']))")
echo "   Generated $FLOW_COUNT flow(s)"

# ── Step 3: Discover coordinates ─────────────────────────────────────────────
echo ""
echo "🎯 STEP 3: Discovering element coordinates on simulator..."
FLOWS_WITH_COORDS="${PROJECT_ROOT}/Artifacts/flows_with_coords.json"
python3 "${SCRIPT_DIR}/coordinate_discovery.py" \
    --flows "$FLOWS_JSON" \
    --udid "$UDID" \
    --bundle-id "$BUNDLE_ID" \
    --project-root "$PROJECT_ROOT" \
    --output "$FLOWS_WITH_COORDS" 2>&1

# ── Step 4: Translate to Argent YAML ─────────────────────────────────────────
echo ""
echo "🔄 STEP 4: Translating to Argent YAML..."
FLOWS_DIR="${PROJECT_ROOT}/.argent/flows"
rm -rf "$FLOWS_DIR"
mkdir -p "$FLOWS_DIR"

# Copy generated flows to the expected location for translate_flows.sh
cp "$FLOWS_WITH_COORDS" "${PROJECT_ROOT}/Artifacts/flows.json"

# Run translator
bash "${SCRIPT_DIR}/../translate_flows.sh" \
    --project-root "$PROJECT_ROOT" \
    --bundle-id "$BUNDLE_ID" \
    --udid "$UDID" 2>&1

# ── Step 5: Execute flows ────────────────────────────────────────────────────
echo ""
echo "▶️  STEP 5: Executing generated test flows..."
echo ""

YAML_COUNT=$(find "$FLOWS_DIR" -name "*.yaml" | wc -l | tr -d ' ')
echo "   Found $YAML_COUNT YAML flow file(s)"

FAILED=0
PASSED=0

for yaml_file in "$FLOWS_DIR"/*.yaml; do
    [[ -f "$yaml_file" ]] || continue
    flow_name=$(basename "$yaml_file" .yaml)
    echo ""
    echo "   ────────────────────────────────────────────────"
    echo "   ▶️  Running: $flow_name"
    echo "   ────────────────────────────────────────────────"

    if argent run flow-execute \
        --project_root "$PROJECT_ROOT" \
        --name "$flow_name" \
        --prerequisiteAcknowledged 2>&1; then
        echo "   ✅ PASSED"
        PASSED=$((PASSED + 1))
    else
        echo "   ❌ FAILED"
        FAILED=$((FAILED + 1))
    fi
done

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo "══════════════════════════════════════════════════════════════════"
echo "  Test Run Summary"
echo "══════════════════════════════════════════════════════════════════"
echo "  Flows passed: $PASSED"
echo "  Flows failed: $FAILED"
echo "  Total:        $((PASSED + FAILED))"
echo ""

# Cleanup
rm -f "$ANALYSIS_JSON" "$FLOWS_JSON" "$FLOWS_WITH_COORDS"

if [[ "$FAILED" -gt 0 ]]; then
    exit 1
fi

exit 0
