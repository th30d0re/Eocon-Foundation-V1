#!/usr/bin/env bats
# KGPE Phase B: node manifest tests.
# Covers: agent manifests validate against the tech-plan §3.2 schema, every
# declared type is in the §3.1 closed vocabulary, ids are unique, phase0
# carries the human gate, no manifest declares edges, phase1/phase4 dry runs
# emit valid work-node manifests / manifest sets, and out-of-vocabulary
# manifests are rejected.

load "test_helper"

# shellcheck disable=SC1091
source "$PHASES_DIR/shared/agentCore.sh"

agent_manifest_files() {
    printf '%s\n' \
        "$PHASES_DIR/phase0/node.json" \
        "$PHASES_DIR/phase1/node.json" \
        "$PHASES_DIR/phase2/node.json" \
        "$PHASES_DIR/phase3/node.json" \
        "$PHASES_DIR/phase4/node.json" \
        "$PHASES_DIR/phase5/node.json"
}

# Expand a manifest file (which may carry a top-level array) into one temp
# file per manifest object, printing the temp paths.
expand_manifest_file() {
    local manifest="$1"
    local prefix="$2"
    local count
    local i
    count="$(jq 'if type == "array" then length else 1 end' "$manifest")"
    i=0
    while [ "$i" -lt "$count" ]; do
        local tmp
        tmp="$(mktemp "${TMPDIR:-/tmp}/${prefix}_XXXXXX.json")"
        jq --argjson i "$i" 'if type == "array" then .[$i] else . end' "$manifest" > "$tmp"
        printf '%s\n' "$tmp"
        i=$((i + 1))
    done
}

@test "every agent node.json parses and validates against the schema" {
    while IFS= read -r manifest; do
        [ -f "$manifest" ]
        while IFS= read -r expanded; do
            run kgpe_validate_manifest "$expanded"
            [ "$status" -eq 0 ]
            rm -f "$expanded"
        done <<EXPANDED_EOF
$(expand_manifest_file "$manifest" "kgpe_agent")
EXPANDED_EOF
    done <<MANIFESTS_EOF
$(agent_manifest_files)
MANIFESTS_EOF
}

@test "every declared artifact type is in the closed vocabulary" {
    types_file="$(mktemp "${TMPDIR:-/tmp}/kgpe_types_XXXXXX")"
    while IFS= read -r manifest; do
        jq -r '(if type == "array" then .[] else . end) | .consumes[].type, .produces[].type' \
            "$manifest" >> "$types_file"
    done <<MANIFESTS_EOF
$(agent_manifest_files)
MANIFESTS_EOF
    [ -s "$types_file" ]
    while IFS= read -r artifact_type; do
        [ -n "$artifact_type" ] || continue
        run kgpe_is_artifact_type "$artifact_type"
        [ "$status" -eq 0 ]
    done < "$types_file"
    rm -f "$types_file"
}

@test "node ids are unique across all agent manifests" {
    ids_file="$(mktemp "${TMPDIR:-/tmp}/kgpe_ids_XXXXXX")"
    while IFS= read -r manifest; do
        jq -r '(if type == "array" then .[] else . end) | .id' "$manifest" >> "$ids_file"
    done <<MANIFESTS_EOF
$(agent_manifest_files)
MANIFESTS_EOF
    [ -s "$ids_file" ]
    [ "$(sort "$ids_file" | uniq -d | wc -l | tr -d ' ')" -eq 0 ]
    rm -f "$ids_file"
}

@test "phase0 node.json carries the human gate (Constitution Art. VIII §1)" {
    [ "$(jq -r '.gate' "$PHASES_DIR/phase0/node.json")" = "human" ]
}

@test "no agent manifest declares edges or a dependency list" {
    while IFS= read -r manifest; do
        run grep -E '"(edges|dependsOn|dependencies)"' "$manifest"
        [ "$status" -eq 1 ]
    done <<MANIFESTS_EOF
$(agent_manifest_files)
MANIFESTS_EOF
}

@test "phase1 --dry-run emits at least one valid work-node manifest" {
    project="$(make_project)"
    run "$(agent_path "phase1/PlannerAgent.sh")" --dry-run --yolo --project-dir "$project"
    [ "$status" -eq 0 ]
    found="$(find "$project/Plans" -type f -path '*/waves/wave*/node.json' | wc -l | tr -d ' ')"
    [ "$found" -ge 1 ]
    while IFS= read -r manifest; do
        [ -n "$manifest" ] || continue
        run kgpe_validate_manifest "$manifest"
        [ "$status" -eq 0 ]
    done <<WAVES_EOF
$(find "$project/Plans" -type f -path '*/waves/wave*/node.json')
WAVES_EOF
}

@test "phase4 --dry-run emits a valid work-node manifest set" {
    project="$(make_project)"
    run "$(agent_path "phase4/StagesAgent.sh")" --dry-run --yolo --project-dir "$project"
    [ "$status" -eq 0 ]
    [ -f "$project/Plans/stages.json" ]
    run jq -e '.schemaVersion == 1 and (.nodes | type == "array") and (.nodes | length >= 1)' \
        "$project/Plans/stages.json"
    [ "$status" -eq 0 ]
    count="$(jq '.nodes | length' "$project/Plans/stages.json")"
    i=0
    while [ "$i" -lt "$count" ]; do
        tmp="$(mktemp "${TMPDIR:-/tmp}/kgpe_stage_node_XXXXXX.json")"
        jq --argjson i "$i" '.nodes[$i]' "$project/Plans/stages.json" > "$tmp"
        run kgpe_validate_manifest "$tmp"
        [ "$status" -eq 0 ]
        rm -f "$tmp"
        i=$((i + 1))
    done
}

@test "phase4 collects phase1 manifests into stages.json without any AI call" {
    project="$(make_project)"
    run "$(agent_path "phase1/PlannerAgent.sh")" --dry-run --yolo --project-dir "$project"
    [ "$status" -eq 0 ]
    run "$(agent_path "phase4/StagesAgent.sh")" --yolo --project-dir "$project"
    [ "$status" -eq 0 ]
    [ -f "$project/Plans/stages.json" ]
    [ -f "$project/Plans/stages.md" ]
    run jq -e '.schemaVersion == 1 and (.nodes | length >= 1) and (.nodes[0].id == "plan1.wave1")' \
        "$project/Plans/stages.json"
    [ "$status" -eq 0 ]
    assert_result "$project" 4 "success"
}

@test "a manifest with an out-of-vocabulary type is rejected" {
    bad="$(mktemp "${TMPDIR:-/tmp}/kgpe_bad_XXXXXX.json")"
    cat > "$bad" <<'BAD_EOF'
{
  "schemaVersion": 1,
  "id": "plan1.wave9",
  "kind": "work",
  "label": "Bad wave",
  "exec": { "type": "wave", "planPath": "Plans/plan1/waves/wave9" },
  "consumes": [],
  "produces": [ { "type": "banana" } ],
  "gate": "none",
  "retry": { "maxAttempts": 3 }
}
BAD_EOF
    run kgpe_validate_manifest "$bad"
    [ "$status" -eq 1 ]
    rm -f "$bad"
}

@test "a manifest declaring edges is rejected" {
    bad="$(mktemp "${TMPDIR:-/tmp}/kgpe_edges_XXXXXX.json")"
    cat > "$bad" <<'BAD_EOF'
{
  "schemaVersion": 1,
  "id": "plan1.wave9",
  "kind": "work",
  "label": "Bad wave",
  "exec": { "type": "wave", "planPath": "Plans/plan1/waves/wave9" },
  "consumes": [],
  "produces": [ { "type": "code.module", "name": "x" } ],
  "dependsOn": ["plan1.wave1"],
  "gate": "none",
  "retry": { "maxAttempts": 3 }
}
BAD_EOF
    run kgpe_validate_manifest "$bad"
    [ "$status" -eq 1 ]
    rm -f "$bad"
}
