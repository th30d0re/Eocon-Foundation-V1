use orch::kgpe::{
    derive_edges, validate_graph, ArtifactRef, ArtifactType, Edge, ExecSpec, Gate, GraphError,
    GraphWarning, Node, NodeKind, RetrySpec,
};

fn artifact(kind: ArtifactType) -> ArtifactRef {
    ArtifactRef::unnamed(kind)
}
fn named(kind: ArtifactType, name: &str) -> ArtifactRef {
    ArtifactRef::named(kind, name)
}
fn node(id: &str, consumes: Vec<ArtifactRef>, produces: Vec<ArtifactRef>) -> Node {
    Node {
        schema_version: 1,
        id: id.into(),
        kind: NodeKind::Work,
        label: id.into(),
        exec: ExecSpec::Wave {
            plan_path: format!("Plans/{id}"),
        },
        consumes,
        produces,
        gate: Gate::None,
        retry: RetrySpec { max_attempts: 2 },
    }
}

#[test]
fn derivation_collapses_matches_and_never_matches_named_to_unnamed() {
    let producer = node(
        "producer",
        vec![],
        vec![
            named(ArtifactType::CodeModule, "core"),
            named(ArtifactType::TestResult, "core"),
            artifact(ArtifactType::GuideDoc),
        ],
    );
    let consumer = node(
        "consumer",
        vec![
            named(ArtifactType::CodeModule, "core"),
            named(ArtifactType::TestResult, "core"),
            named(ArtifactType::GuideDoc, "named"),
        ],
        vec![],
    );
    assert_eq!(
        derive_edges(&[producer, consumer]),
        vec![Edge {
            from: "producer".into(),
            to: "consumer".into(),
            refs: vec![
                named(ArtifactType::CodeModule, "core"),
                named(ArtifactType::TestResult, "core")
            ]
        }]
    );
}

#[test]
fn schema_check_fails_and_valid_schema_passes() {
    let mut invalid = node("", vec![], vec![]);
    invalid.schema_version = 2;
    let report = validate_graph(&[invalid]);
    assert!(report
        .errors
        .iter()
        .any(|e| matches!(e, GraphError::Schema { .. })));
    assert!(validate_graph(&[node("valid", vec![], vec![])]).is_valid());
}

#[test]
fn producer_completeness_fails_and_passes() {
    let consumer = node("consumer", vec![artifact(ArtifactType::PlanDoc)], vec![]);
    assert!(validate_graph(std::slice::from_ref(&consumer))
        .errors
        .iter()
        .any(|e| matches!(e, GraphError::MissingProducer { node, .. } if node == "consumer")));
    let producer = node("producer", vec![], vec![artifact(ArtifactType::PlanDoc)]);
    assert!(validate_graph(&[producer, consumer]).is_valid());
}

#[test]
fn acyclicity_and_reachability_fail_with_actual_cycle_and_dag_passes() {
    let a = node(
        "a",
        vec![named(ArtifactType::CodeModule, "b")],
        vec![named(ArtifactType::CodeModule, "a")],
    );
    let b = node(
        "b",
        vec![named(ArtifactType::CodeModule, "a")],
        vec![named(ArtifactType::CodeModule, "b")],
    );
    let report = validate_graph(&[a, b]);
    let path = report
        .errors
        .iter()
        .find_map(|e| {
            if let GraphError::Cycle { path } = e {
                Some(path)
            } else {
                None
            }
        })
        .expect("cycle path");
    assert_eq!(path.first(), path.last());
    assert!(path.contains(&"a".to_string()));
    assert!(path.contains(&"b".to_string()));
    assert!(report
        .errors
        .iter()
        .any(|e| matches!(e, GraphError::UnreachableNode { .. })));
    assert!(validate_graph(&[node("root", vec![], vec![])]).is_valid());
}

#[test]
fn stage_layering_and_critical_path_cover_diamond() {
    let root = node(
        "root",
        vec![],
        vec![named(ArtifactType::CodeModule, "root")],
    );
    let left = node(
        "left",
        vec![named(ArtifactType::CodeModule, "root")],
        vec![named(ArtifactType::CodeModule, "left")],
    );
    let right = node(
        "right",
        vec![named(ArtifactType::CodeModule, "root")],
        vec![named(ArtifactType::CodeModule, "right")],
    );
    let join = node(
        "join",
        vec![
            named(ArtifactType::CodeModule, "left"),
            named(ArtifactType::CodeModule, "right"),
        ],
        vec![],
    );
    let report = validate_graph(&[root, left, right, join]);
    assert!(report.is_valid());
    assert_eq!(
        report.stages,
        vec![vec!["root"], vec!["left", "right"], vec!["join"]]
    );
    assert_eq!(report.critical_path.len(), 3);
}

#[test]
fn named_ref_fan_in_is_warning_not_error() {
    let reference = named(ArtifactType::CodeModule, "shared");
    let report = validate_graph(&[
        node("a", vec![], vec![reference.clone()]),
        node("b", vec![], vec![reference.clone()]),
        node("c", vec![reference], vec![]),
    ]);
    assert!(report.is_valid());
    assert!(
        matches!(&report.warnings[0], GraphWarning::FanIn { producers, .. } if producers == &["a", "b"])
    );
}
