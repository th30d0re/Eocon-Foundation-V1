use std::collections::BTreeSet;
use std::path::Path;

use orch::pipeline_engine::load_agent_graph;

#[test]
fn real_manifests_match_verified_edge_set_and_stages() {
    let phases = Path::new(env!("CARGO_MANIFEST_DIR")).parent().unwrap().parent().unwrap();
    let graph = load_agent_graph(phases).expect("the real agent manifests must validate");
    let actual = graph
        .edges
        .iter()
        .map(|edge| (edge.from.as_str(), edge.to.as_str()))
        .collect::<BTreeSet<_>>();
    let expected = BTreeSet::from([
        ("phase0.constitution", "phase1.planner"),
        ("phase1.planner", "phase2.question"),
        ("phase1.planner", "phase3.optimization"),
        ("phase1.planner", "phase4.stages"),
        ("phase1.planner", "phase5.build"),
        ("phase2.question", "phase3.optimization"),
        ("phase3.optimization", "phase4.stages"),
        ("phase3.optimization", "phase5.build"),
        ("phase4.stages", "phase5.build"),
        ("phase5.build", "phase5.test"),
    ]);
    assert_eq!(actual, expected);
    assert_eq!(
        graph.report.stages,
        vec![
            vec!["phase0.constitution".to_string()],
            vec!["phase1.planner".to_string()],
            vec!["phase2.question".to_string()],
            vec!["phase3.optimization".to_string()],
            vec!["phase4.stages".to_string()],
            vec!["phase5.build".to_string()],
            vec!["phase5.test".to_string()],
        ]
    );
}

#[test]
fn invalid_manifest_returns_a_named_error_without_panicking() {
    let temp = tempfile::tempdir().unwrap();
    let phases = temp.path();
    for phase in 0..=5 {
        std::fs::create_dir_all(phases.join(format!("phase{phase}"))).unwrap();
        std::fs::write(phases.join(format!("phase{phase}/node.json")), "{}").unwrap();
    }
    let error = load_agent_graph(phases).unwrap_err();
    assert!(error.contains("phase0/node.json"), "{error}");
}
