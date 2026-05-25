#!/usr/bin/env bash
# Library: xcodemake.sh
# Purpose: Incremental build support via xcodemake Makefile generation
# Dependencies: xcodemake (optional - graceful degradation if unavailable)
#
# Functions:
#   is_makefile_available()      - Check if DerivedData/Build/Makefile exists
#   generate_makefile()          - Execute xcodemake to generate Makefile
#   execute_incremental_build()  - Run make with appropriate flags
#   should_regenerate()          - Compare project config hash against stored hash
#   hash_project_config()        - Generate SHA-256 hash of project config files
#
# Environment Variables:
#   INCREMENTAL_BUILDS_ENABLED - Set to "false" to globally disable (default: true)
#   DERIVED_DATA_PATH          - Path to DerivedData directory
#   PROJECT_ROOT               - Root directory of the project
#
# Usage:
#   source xcodemake.sh
#   if is_makefile_available && ! should_regenerate; then
#       execute_incremental_build "$make_target"
#   fi

set -euo pipefail

# Verify bash is running
if [ -z "${BASH_VERSION:-}" ]; then
    echo "Error: This library requires bash" >&2
    return 1 2>/dev/null || exit 1
fi

# Path resolution using BASH_SOURCE[0] for PATH-installed agents
XCODEMAKE_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
XCODEMAKE_PHASE5_DIR="$(cd "${XCODEMAKE_LIB_DIR}/.." && pwd)"
XCODEMAKE_PROJECT_ROOT="${PROJECT_ROOT:-$(cd "${XCODEMAKE_PHASE5_DIR}/../../../.." && pwd)}"

# Configuration
INCREMENTAL_BUILDS_ENABLED="${INCREMENTAL_BUILDS_ENABLED:-true}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-}"

# Internal state
_XCODEMAKE_AVAILABLE=""

# Check if xcodemake is available on the system
# Returns: 0 if available, 1 if not
_check_xcodemake_available() {
    if [ -z "$_XCODEMAKE_AVAILABLE" ]; then
        if command -v xcodemake &>/dev/null; then
            _XCODEMAKE_AVAILABLE="true"
        else
            _XCODEMAKE_AVAILABLE="false"
            echo "⚠️  xcodemake not found, using full xcodebuild" >&2
        fi
    fi
    [ "$_XCODEMAKE_AVAILABLE" = "true" ]
}

# Get the Makefile path based on DerivedData location
# Arguments: None
# Returns: Path to Makefile
_get_makefile_path() {
    local derived_data="${DERIVED_DATA_PATH:-${XCODEMAKE_PROJECT_ROOT}/DerivedData}"
    echo "${derived_data}/Build/Makefile"
}

# Get the Makefile metadata path
# Arguments: None
# Returns: Path to Makefile.meta.json
_get_makefile_meta_path() {
    local derived_data="${DERIVED_DATA_PATH:-${XCODEMAKE_PROJECT_ROOT}/DerivedData}"
    echo "${derived_data}/Build/Makefile.meta.json"
}

# Check if Makefile is available for incremental builds
# Arguments: None
# Returns: 0 if Makefile exists and incremental builds enabled, 1 otherwise
is_makefile_available() {
    # Check if incremental builds are globally disabled
    if [ "${INCREMENTAL_BUILDS_ENABLED}" != "true" ]; then
        return 1
    fi

    # Check if xcodemake is available
    if ! _check_xcodemake_available; then
        return 1
    fi

    local makefile_path
    makefile_path="$(_get_makefile_path)"

    [ -f "$makefile_path" ]
}

# Generate SHA-256 hash of project configuration files
# Arguments: None
# Outputs: Hash string to stdout
# Returns: 0 on success
hash_project_config() {
    local project_root="${PROJECT_ROOT:-$XCODEMAKE_PROJECT_ROOT}"
    local hash_input=""

    # Collect content from project configuration files
    if [ -f "${project_root}/project.pbxproj" ]; then
        hash_input+="$(cat "${project_root}/project.pbxproj" 2>/dev/null || true)"
    fi

    # Check for .xcodeproj directories and their project.pbxproj files
    for xcodeproj in "${project_root}"/*.xcodeproj; do
        if [ -d "$xcodeproj" ] && [ -f "${xcodeproj}/project.pbxproj" ]; then
            hash_input+="$(cat "${xcodeproj}/project.pbxproj" 2>/dev/null || true)"
        fi
    done

    # Include Package.swift if it exists
    if [ -f "${project_root}/Package.swift" ]; then
        hash_input+="$(cat "${project_root}/Package.swift" 2>/dev/null || true)"
    fi

    # Generate hash
    if [ -n "$hash_input" ]; then
        echo "$hash_input" | shasum -a 256 | cut -d' ' -f1
    else
        echo "empty"
    fi
}

# Check if Makefile should be regenerated based on config changes
# Arguments: None
# Returns: 0 if should regenerate, 1 if Makefile is fresh
should_regenerate() {
    local meta_path
    meta_path="$(_get_makefile_meta_path)"

    # If no metadata file, should regenerate
    if [ ! -f "$meta_path" ]; then
        return 0
    fi

    # Check if jq is available for JSON parsing
    if ! command -v jq &>/dev/null; then
        echo "⚠️  jq not found, cannot check Makefile staleness" >&2
        return 0
    fi

    # Get stored hash from metadata
    local stored_hash
    stored_hash=$(jq -r '.sourceHash // ""' "$meta_path" 2>/dev/null || echo "")

    if [ -z "$stored_hash" ]; then
        return 0
    fi

    # Generate current hash
    local current_hash
    current_hash=$(hash_project_config)

    # Compare hashes
    [ "$stored_hash" != "$current_hash" ]
}

# Generate Makefile from xcodebuild command
# Arguments:
#   $1 - xcodebuild command (full command line)
# Returns: 0 on success, 1 on failure
generate_makefile() {
    local xcodebuild_command="$1"

    if ! _check_xcodemake_available; then
        return 1
    fi

    local derived_data="${DERIVED_DATA_PATH:-${XCODEMAKE_PROJECT_ROOT}/DerivedData}"
    local build_dir="${derived_data}/Build"
    local makefile_path="${build_dir}/Makefile"
    local meta_path="${build_dir}/Makefile.meta.json"
    local xcodemake_log="${build_dir}/xcodemake.log"

    # Ensure build directory exists
    mkdir -p "$build_dir"

    echo "🔧 Regenerating Makefile (project config changed)" >&2

    # Run xcodemake to generate Makefile and capture output
    if ! xcodemake generate --output "$makefile_path" -- $xcodebuild_command > "$xcodemake_log" 2>&1; then
        echo "⚠️  Failed to generate Makefile. See $xcodemake_log for details" >&2
        tail -10 "$xcodemake_log" >&2
        rm -f "$makefile_path" "$meta_path" 2>/dev/null
        return 1
    fi

    # Generate and store metadata
    local current_hash
    current_hash=$(hash_project_config)

    local xcodemake_version
    xcodemake_version=$(xcodemake --version 2>/dev/null || echo "unknown")

    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Write metadata file
    cat > "$meta_path" << EOF
{
  "generated": "${timestamp}",
  "xcodebuildCommand": "${xcodebuild_command}",
  "xcodemakeVersion": "${xcodemake_version}",
  "sourceHash": "${current_hash}",
  "platforms": []
}
EOF

    # Clean up log on success
    rm -f "$xcodemake_log"
    
    echo "✓ Makefile generated successfully" >&2
    return 0
}

# Execute incremental build using make
# Arguments:
#   $1 - make target (optional, defaults to "build")
#   $2 - additional make flags (optional)
# Returns: 0 on success, non-zero on failure
execute_incremental_build() {
    local target="${1:-build}"
    local make_flags="${2:-}"

    local makefile_path
    makefile_path="$(_get_makefile_path)"

    if [ ! -f "$makefile_path" ]; then
        echo "⚠️  Makefile not found at ${makefile_path}" >&2
        return 1
    fi

    local derived_data="${DERIVED_DATA_PATH:-${XCODEMAKE_PROJECT_ROOT}/DerivedData}"
    local build_dir="${derived_data}/Build"

    echo "⚡ Using incremental build (Makefile found)" >&2

    local start_time
    start_time=$(date +%s)

    # Run make with the Makefile
    local make_result=0
    if [ -n "$make_flags" ]; then
        make -C "$build_dir" -f "$makefile_path" $make_flags "$target" || make_result=$?
    else
        make -C "$build_dir" -f "$makefile_path" "$target" || make_result=$?
    fi

    local end_time
    end_time=$(date +%s)
    local elapsed=$((end_time - start_time))

    if [ $make_result -eq 0 ]; then
        echo "✓ Build succeeded in ${elapsed}s (vs ~28s full build)" >&2
    fi

    return $make_result
}

# Get xcodemake availability status (for external checks)
# Returns: 0 if available, 1 if not
is_xcodemake_available() {
    _check_xcodemake_available
}
