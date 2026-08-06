use orch::kgpe::{
    ArtifactRef, ArtifactType, ExecSpec, Gate, GraphEngine, GraphError, MutationError, Node,
    NodeKind, NodeState, RetrySpec,
};

fn named(name: &str) -> ArtifactRef {
    ArtifactRef::named(ArtifactType::CodeModule, name)
}
fn node(id: &str, consumes: Vec<ArtifactRef>, produces: Vec<ArtifactRef>) -> Node {
    Node {
        schema_version: 1,
        id: id.into(),
        kind: NodeKind::Work,
        label: id.into(),
        exec: ExecSpec::Wave {
            plan_path: id.into(),
        },
        consumes,
        produces,
        gate: Gate::None,
        retry: RetrySpec { max_attempts: 2 },
    }
}
fn succeed(engine: &mut GraphEngine, id: &str) {
    engine.start(id).unwrap();
    assert_eq!(engine.apply_exit_code(id, 0).unwrap(), NodeState::Succeeded);
}

#[test]
fn exit_codes_gates_and_ready_set_follow_contract() {
    let mut gated = node("gate", vec![], vec![named("g")]);
    gated.gate = Gate::Human;
    let child = node("child", vec![named("g")], vec![]);
    let mut engine = GraphEngine::new(vec![gated, child]).unwrap();
    assert_eq!(engine.ready_set(), vec!["gate"]);
    engine.start("gate").unwrap();
    assert_eq!(
        engine.apply_exit_code("gate", 0).unwrap(),
        NodeState::AwaitingApproval
    );
    assert!(engine.ready_set().is_empty());
    engine.approve("gate").unwrap();
    assert_eq!(engine.ready_set(), vec!["child"]);
    engine.start("child").unwrap();
    assert_eq!(
        engine.apply_exit_code("child", 11).unwrap(),
        NodeState::Failed
    );
}

#[test]
fn retry_exhaustion_becomes_human_intervention() {
    let mut engine = GraphEngine::new(vec![node("work", vec![], vec![])]).unwrap();
    engine.start("work").unwrap();
    engine.apply_exit_code("work", 10).unwrap();
    assert_eq!(engine.retry("work").unwrap(), NodeState::Ready);
    engine.start("work").unwrap();
    engine.apply_exit_code("work", 10).unwrap();
    assert_eq!(engine.retry("work").unwrap(), NodeState::HumanIntervention);
}

#[test]
fn amend_invalidates_exactly_transitive_dependents() {
    let root = node("root", vec![], vec![named("root")]);
    let child = node("child", vec![named("root")], vec![named("child")]);
    let grandchild = node("grandchild", vec![named("child")], vec![]);
    let outside = node("outside", vec![], vec![]);
    let mut engine = GraphEngine::new(vec![root, child, grandchild, outside]).unwrap();
    succeed(&mut engine, "outside");
    succeed(&mut engine, "root");
    succeed(&mut engine, "child");
    succeed(&mut engine, "grandchild");
    assert_eq!(
        engine.amend(&named("root")).unwrap(),
        vec!["child", "grandchild", "root"]
    );
    assert_eq!(engine.states["outside"], NodeState::Succeeded);
    assert_eq!(engine.states["root"], NodeState::Ready);
    assert_eq!(engine.states["child"], NodeState::Pending);
    assert_eq!(engine.states["grandchild"], NodeState::Pending);
}

#[test]
fn append_that_creates_cycle_is_rejected_without_changes() {
    let root = node("root", vec![], vec![named("a")]);
    let existing = node("existing", vec![named("a")], vec![named("b")]);
    let mut engine = GraphEngine::new(vec![root, existing]).unwrap();
    let before = engine.clone();
    let circular = node("circular", vec![named("b")], vec![named("a")]);
    let error = engine.append(circular).unwrap_err();
    assert!(
        matches!(error, MutationError::InvalidGraph(report) if report.errors.iter().any(|e| matches!(e, GraphError::Cycle { .. })))
    );
    assert_eq!(engine, before);
}
