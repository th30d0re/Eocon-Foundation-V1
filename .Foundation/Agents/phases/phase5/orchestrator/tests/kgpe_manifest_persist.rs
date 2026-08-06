use orch::kgpe::{
    load_graph_state, load_manifest, load_manifests, save_graph_state, ArtifactRef, ArtifactType,
    ExecSpec, Gate, GraphEngine, ManifestError, Node, NodeKind, NodeState, RetrySpec,
};
use std::collections::HashMap;

fn node() -> Node {
    Node {
        schema_version: 1,
        id: "root".into(),
        kind: NodeKind::Agent,
        label: "Root".into(),
        exec: ExecSpec::Script {
            path: "phase0.sh".into(),
            args: vec![],
        },
        consumes: vec![],
        produces: vec![ArtifactRef::unnamed(ArtifactType::ConstitutionRoot)],
        gate: Gate::None,
        retry: RetrySpec { max_attempts: 2 },
    }
}

#[test]
fn unknown_artifact_type_is_hard_parse_error_and_missing_path_is_named() {
    let dir = tempfile::tempdir().unwrap();
    let missing = dir.path().join("node.json");
    assert!(
        matches!(load_manifest(&missing), Err(ManifestError::Missing { path }) if path == missing)
    );
    let path = dir.path().join("bad.json");
    std::fs::write(&path, r#"{"schemaVersion":1,"id":"x","kind":"agent","label":"x","exec":{"type":"script","path":"x","args":[]},"consumes":[],"produces":[{"type":"invented.type"}],"gate":"none","retry":{"maxAttempts":1}}"#).unwrap();
    assert!(matches!(
        load_manifest(&path),
        Err(ManifestError::Parse { .. })
    ));
}

#[test]
fn graph_state_round_trip_preserves_resume_position() {
    let dir = tempfile::tempdir().unwrap();
    let path = dir.path().join("graph_state.json");
    let mut engine = GraphEngine::new(vec![node()]).unwrap();
    engine.start("root").unwrap();
    engine.apply_exit_code("root", 10).unwrap();
    engine.retry("root").unwrap();
    save_graph_state(&path, &engine).unwrap();
    let loaded = load_graph_state(&path).unwrap();
    assert_eq!(loaded, engine);
    assert_eq!(loaded.ready_set(), vec!["root"]);
    let json: serde_json::Value =
        serde_json::from_str(&std::fs::read_to_string(path).unwrap()).unwrap();
    assert_eq!(json["schemaVersion"], 1);
}

#[test]
fn all_eight_states_serialize_with_camel_case_names() {
    let states = [
        NodeState::Pending,
        NodeState::Ready,
        NodeState::Running,
        NodeState::AwaitingApproval,
        NodeState::Succeeded,
        NodeState::Failed,
        NodeState::HumanIntervention,
        NodeState::Skipped,
    ];
    let map = states
        .into_iter()
        .enumerate()
        .map(|(index, state)| (index.to_string(), state))
        .collect::<HashMap<_, _>>();
    let json = serde_json::to_string(&map).unwrap();
    assert!(json.contains("awaitingApproval"));
    assert!(json.contains("humanIntervention"));
}

#[test]
fn wave_exec_uses_camel_case_plan_path() {
    let json = serde_json::to_value(ExecSpec::Wave {
        plan_path: "Plans/plan1/waves/wave1".into(),
    })
    .unwrap();
    assert_eq!(json["type"], "wave");
    assert_eq!(json["planPath"], "Plans/plan1/waves/wave1");
    assert!(json.get("plan_path").is_none());
}

fn manifest_json(id: &str) -> String {
    format!(
        r#"{{"schemaVersion":1,"id":"{id}","kind":"agent","label":"{id}","exec":{{"type":"script","path":"{id}.sh","args":[]}},"consumes":[],"produces":[],"gate":"none","retry":{{"maxAttempts":1}}}}"#
    )
}

#[test]
fn manifest_set_loader_accepts_single_object_and_array_files() {
    let dir = tempfile::tempdir().unwrap();
    let single = dir.path().join("single.json");
    let array = dir.path().join("array.json");
    std::fs::write(&single, manifest_json("single")).unwrap();
    std::fs::write(
        &array,
        format!("[{},{}]", manifest_json("array-a"), manifest_json("array-b")),
    )
    .unwrap();

    let nodes = load_manifests(&[single, array]).unwrap();
    assert_eq!(
        nodes.iter().map(|node| node.id.as_str()).collect::<Vec<_>>(),
        vec!["single", "array-a", "array-b"]
    );
}

#[test]
fn manifest_array_keeps_schema_and_duplicate_validation_strict() {
    let dir = tempfile::tempdir().unwrap();
    let unknown = dir.path().join("unknown.json");
    let malformed = dir.path().join("malformed.json");
    let duplicate = dir.path().join("duplicate.json");
    std::fs::write(
        &unknown,
        format!(
            "[{}]",
            manifest_json("unknown").replace("\"produces\":[]", "\"produces\":[{\"type\":\"invented.type\"}]")
        ),
    )
    .unwrap();
    std::fs::write(&malformed, format!("[{},{{}}]", manifest_json("valid"))).unwrap();
    std::fs::write(
        &duplicate,
        format!("[{},{}]", manifest_json("same"), manifest_json("same")),
    )
    .unwrap();

    assert!(matches!(
        load_manifests(std::slice::from_ref(&unknown)),
        Err(ManifestError::Parse { path, .. }) if path == unknown
    ));
    assert!(matches!(
        load_manifests(std::slice::from_ref(&malformed)),
        Err(ManifestError::Parse { path, .. }) if path == malformed
    ));
    assert!(matches!(
        load_manifests(std::slice::from_ref(&duplicate)),
        Err(ManifestError::DuplicateId { id, first, second })
            if id == "same" && first == duplicate && second == duplicate
    ));
}
