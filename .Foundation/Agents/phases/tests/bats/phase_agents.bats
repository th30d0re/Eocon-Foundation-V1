#!/usr/bin/env bats

load "test_helper"

@test "each phase agent --help exits 0 and mentions every contract flag" {
    for rel in \
        "phase0/ConstitutionAgent.sh" \
        "phase1/PlannerAgent.sh" \
        "phase2/QuestionAgent.sh" \
        "phase3/OptimizationAgent.sh" \
        "phase4/StagesAgent.sh"; do
        run "$(agent_path "$rel")" --help
        [ "$status" -eq 0 ]
        for flag in --project-dir --ai-provider --model --yolo --dry-run --verbose --help --version; do
            [[ "$output" == *"$flag"* ]]
        done
    done
}

@test "each phase agent missing required input exits 11" {
    project="$(make_project)"

    run "$(agent_path "phase0/ConstitutionAgent.sh")" --project-dir "$project" --yolo
    [ "$status" -eq 11 ]

    run "$(agent_path "phase1/PlannerAgent.sh")" --project-dir "$project" --yolo
    [ "$status" -eq 11 ]

    run "$(agent_path "phase2/QuestionAgent.sh")" --project-dir "$project" --yolo
    [ "$status" -eq 11 ]

    run "$(agent_path "phase3/OptimizationAgent.sh")" --project-dir "$project" --yolo
    [ "$status" -eq 11 ]

    run "$(agent_path "phase4/StagesAgent.sh")" --project-dir "$project" --yolo
    [ "$status" -eq 11 ]
}

@test "phase0 dry-run writes constitutions and result requiring approval" {
    project="$(make_project)"
    run "$(agent_path "phase0/ConstitutionAgent.sh")" --dry-run --yolo --project-dir "$project" --prompt "Build a constellation app"
    [ "$status" -eq 0 ]
    [ -f "$project/Constitution/C0.tex" ]
    [ -f "$project/Constitution/C1.tex" ]
    grep -q "DRY-RUN PLACEHOLDER" "$project/Constitution/C0.tex"
    assert_result "$project" 0 "dry_run"
    result="$(latest_result "$project" 0)"
    [ "$(jq -r '.requiresApproval' "$result")" = "true" ]
}

@test "phase1 dry-run writes one full plan and wave scaffold" {
    project="$(make_project)"
    run "$(agent_path "phase1/PlannerAgent.sh")" --dry-run --yolo --project-dir "$project"
    [ "$status" -eq 0 ]
    [ -f "$project/Plans/plan1/plan1.md" ]
    [ -f "$project/Plans/plan1/test1.md" ]
    [ -f "$project/Plans/plan1/decision_log.md" ]
    [ -f "$project/Plans/plan1/waves/wave1/subplan1.md" ]
    [ -f "$project/Plans/plan1/waves/wave1/subtest1.md" ]
    grep -q "DRY-RUN PLACEHOLDER" "$project/Plans/plan1/plan1.md"
    assert_result "$project" 1 "dry_run"
}

@test "phase2 dry-run writes Questions.md and decision log" {
    project="$(make_project)"
    run "$(agent_path "phase2/QuestionAgent.sh")" --dry-run --yolo --project-dir "$project"
    [ "$status" -eq 0 ]
    [ -f "$project/Plans/Questions.md" ]
    [ -f "$project/Plans/plan1/decision_log.md" ]
    grep -q "DRY-RUN PLACEHOLDER" "$project/Plans/Questions.md"
    assert_result "$project" 2 "dry_run"
}

@test "phase3 dry-run writes optimized plan artifacts and unit tests" {
    project="$(make_project)"
    run "$(agent_path "phase3/OptimizationAgent.sh")" --dry-run --yolo --project-dir "$project"
    [ "$status" -eq 0 ]
    [ -f "$project/Plans/plan1/plan1.md" ]
    [ -f "$project/Plans/plan1/test1.md" ]
    [ -f "$project/Plans/plan1/waves/wave1/subplan1.md" ]
    [ -f "$project/Plans/plan1/waves/wave1/subtest1.md" ]
    [ -f "$project/Plans/plan1/waves/wave1/unit_tests.md" ]
    [ -f "$project/Plans/plan1/decision_log.md" ]
    grep -q "DRY-RUN PLACEHOLDER" "$project/Plans/plan1/waves/wave1/unit_tests.md"
    assert_result "$project" 3 "dry_run"
}

@test "phase4 dry-run writes stages.md and valid stages.json" {
    project="$(make_project)"
    run "$(agent_path "phase4/StagesAgent.sh")" --dry-run --yolo --project-dir "$project"
    [ "$status" -eq 0 ]
    [ -f "$project/Plans/stages.md" ]
    [ -f "$project/Plans/stages.json" ]
    grep -q "DRY-RUN PLACEHOLDER" "$project/Plans/stages.md"
    jq empty "$project/Plans/stages.json"
    assert_result "$project" 4 "dry_run"
}
