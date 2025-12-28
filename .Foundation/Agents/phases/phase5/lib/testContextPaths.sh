#!/bin/bash

# Test Context Paths Configuration
# Defines context path arrays for documentation used by test agents

# ─────────────────────────────────────────────────────────────────────────────
# Base Documentation Paths
# ─────────────────────────────────────────────────────────────────────────────

# Detect project root if not set
if [ -z "${PROJECT_ROOT:-}" ]; then
    PROJECT_ROOT="${PWD}"
fi

# Base documentation directory (auto-detect)
DOCS_BASE="${PROJECT_ROOT}/.Foundation/Docs/swiftDocs"
if [ ! -d "$DOCS_BASE" ]; then
    DOCS_BASE="${PROJECT_ROOT}/Docs/swiftDocs"
fi
if [ ! -d "$DOCS_BASE" ]; then
    DOCS_BASE="${PROJECT_ROOT}/.foundation/docs/swiftDocs"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Testing Documentation Paths
# ─────────────────────────────────────────────────────────────────────────────

# XCTest and Swift Testing framework documentation
TEST_CONTEXT_PATHS=(
    "${DOCS_BASE}/Development-Tools/XCTest"
    "${DOCS_BASE}/Testing/swift-testing-repo"
    "${DOCS_BASE}/Testing/SwiftTests"
    "${DOCS_BASE}/Testing/UITests"
    "${DOCS_BASE}/Testing/XCTest"
    "${DOCS_BASE}/Testing"
)

# Unit test specific documentation
UNIT_TEST_CONTEXT_PATHS=(
    "${DOCS_BASE}/Testing/XCTest"
    "${DOCS_BASE}/Testing/swift-testing-repo"
    "${DOCS_BASE}/Testing/SwiftTests"
    "${DOCS_BASE}/Development-Tools/XCTest"
)

# UI test specific documentation
UI_TEST_CONTEXT_PATHS=(
    "${DOCS_BASE}/Testing/UITests"
    "${DOCS_BASE}/Testing/XCTest"
    "${DOCS_BASE}/Development-Tools/XCTest"
    "${DOCS_BASE}/Swift-SwiftUI/SwiftUI/Accessibility-fundamentals.md"
)

# ─────────────────────────────────────────────────────────────────────────────
# Accessibility Documentation Paths
# ─────────────────────────────────────────────────────────────────────────────

# SwiftUI accessibility documentation
ACCESSIBILITY_CONTEXT_PATHS=(
    "${DOCS_BASE}/Swift-SwiftUI/SwiftUI/Accessibility-fundamentals.md"
    "${DOCS_BASE}/Swift-SwiftUI/SwiftUI/Accessible-appearance.md"
    "${DOCS_BASE}/Swift-SwiftUI/SwiftUI/Accessible-controls.md"
    "${DOCS_BASE}/Swift-SwiftUI/SwiftUI/Accessible-descriptions.md"
    "${DOCS_BASE}/Swift-SwiftUI/SwiftUI/Accessible-navigation.md"
    "${DOCS_BASE}/Swift-SwiftUI/SwiftUI/Accessibility"
)

# ─────────────────────────────────────────────────────────────────────────────
# SwiftUI Documentation Paths
# ─────────────────────────────────────────────────────────────────────────────

# General SwiftUI documentation (for flow analysis, UI understanding)
SWIFTUI_CONTEXT_PATHS=(
    "${DOCS_BASE}/Swift-SwiftUI/SwiftUI"
    "${DOCS_BASE}/Swift-SwiftUI/SwiftUI/Navigation"
    "${DOCS_BASE}/Swift-SwiftUI/SwiftUI/Views"
    "${DOCS_BASE}/Swift-SwiftUI/SwiftUI/State-management"
)

# Navigation-specific documentation (for flow analysis)
NAVIGATION_CONTEXT_PATHS=(
    "${DOCS_BASE}/Swift-SwiftUI/SwiftUI/Navigation"
    "${DOCS_BASE}/Swift-SwiftUI/SwiftUI/NavigationStack.md"
    "${DOCS_BASE}/Swift-SwiftUI/SwiftUI/NavigationLink.md"
    "${DOCS_BASE}/Swift-SwiftUI/SwiftUI/Sheet.md"
)

# ─────────────────────────────────────────────────────────────────────────────
# Helper Functions
# ─────────────────────────────────────────────────────────────────────────────

# Get valid context paths (only returns paths that exist)
# Usage: get_valid_paths "${TEST_CONTEXT_PATHS[@]}"
get_valid_paths() {
    local paths=("$@")
    local valid_paths=()

    for path in "${paths[@]}"; do
        if [ -e "$path" ]; then
            valid_paths+=("$path")
        fi
    done

    echo "${valid_paths[@]}"
}

# Count available documentation files
# Usage: count_docs "${TEST_CONTEXT_PATHS[@]}"
count_docs() {
    local paths=("$@")
    local count=0

    for path in "${paths[@]}"; do
        if [ -f "$path" ]; then
            count=$((count + 1))
        elif [ -d "$path" ]; then
            local dir_count
            dir_count=$(find "$path" -name "*.md" -type f 2>/dev/null | wc -l | tr -d ' ')
            count=$((count + dir_count))
        fi
    done

    echo "$count"
}

# Print available documentation summary
# Usage: print_docs_summary
print_docs_summary() {
    echo "Documentation Summary:"
    echo "  Base path: $DOCS_BASE"
    echo "  Testing docs: $(count_docs "${TEST_CONTEXT_PATHS[@]}") files"
    echo "  Accessibility docs: $(count_docs "${ACCESSIBILITY_CONTEXT_PATHS[@]}") files"
    echo "  SwiftUI docs: $(count_docs "${SWIFTUI_CONTEXT_PATHS[@]}") files"
    echo "  Navigation docs: $(count_docs "${NAVIGATION_CONTEXT_PATHS[@]}") files"
}

# ─────────────────────────────────────────────────────────────────────────────
# Export Arrays (for use in other scripts)
# ─────────────────────────────────────────────────────────────────────────────

export DOCS_BASE
export TEST_CONTEXT_PATHS
export UNIT_TEST_CONTEXT_PATHS
export UI_TEST_CONTEXT_PATHS
export ACCESSIBILITY_CONTEXT_PATHS
export SWIFTUI_CONTEXT_PATHS
export NAVIGATION_CONTEXT_PATHS
export -f get_valid_paths
export -f count_docs
export -f print_docs_summary
