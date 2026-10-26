use std::io::{self, Write};
use std::path::{Path, PathBuf};
use std::process::{Command, ExitCode};

use serde::Serialize;

use crate::detect;
use crate::kgpe::{save_graph_state, Edge, GraphEngine, GraphReport, Node, NodeState};
use crate::pipeline_engine::{graph_state_path, load_agent_graph, node_agent_cmd, SpawnTarget};
use crate::{CliArgs, GraphCommand, GraphFormat, OrchCommand};

pub const GATE_EXIT_CODE: u8 = 3;

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct ValidationOutput<'a> {
    valid: bool,
    nodes: &'a [Node],
    edges: &'a [Edge],
    report: &'a GraphReport,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct PipelineEvent<'a> {
    node: &'a str,
    state: NodeState,
    exit_code: i32,
}

pub fn run_command(args: CliArgs) -> ExitCode {
    match run_command_with_writer(args, &mut io::stdout()) {
        Ok(code) => ExitCode::from(code),
        Err(error) => {
            eprintln!("HeadlessCommandError: {error}");
            ExitCode::FAILURE
        }
    }
}

pub fn run_command_with_writer(args: CliArgs, out: &mut dyn Write) -> Result<u8, String> {
    let cwd = std::env::current_dir().map_err(|error| format!("CurrentDirectoryError: {error}"))?;
    let default_agents = args
        .agents_dir
        .as_deref()
        .map(PathBuf::from)
        .unwrap_or_else(|| detect::find_agents_dir(&cwd));
    let command = args
        .command
        .ok_or_else(|| "MissingHeadlessSubcommand: no headless command supplied".to_string())?;
    match command {
        OrchCommand::Graph(graph) => match graph.command {
            GraphCommand::Validate {
                project_dir: _,
                agents_dir,
                json,
            } => {
                let phases = normalize_phases_dir(agents_dir.as_deref().unwrap_or(&default_agents));
                match load_agent_graph(&phases) {
                    Ok(engine) => {
                        print_validation(out, &engine, json)?;
                        Ok(0)
                    }
                    Err(error) => Err(format!("GraphValidationError: {error}")),
                }
            }
            GraphCommand::Render {
                format,
                project_dir: _,
            } => {
                let phases = normalize_phases_dir(&default_agents);
                let engine = load_agent_graph(&phases)
                    .map_err(|error| format!("GraphValidationError: {error}"))?;
                write!(out, "{}", render_graph(&engine, format))
                    .map_err(|error| format!("OutputError: {error}"))?;
                Ok(0)
            }
        },
        OrchCommand::Pipeline(pipeline) => {
            let project_dir = pipeline.project_dir.unwrap_or(cwd);
            let phases = normalize_phases_dir(&default_agents);
            let mut engine = load_agent_graph(&phases)
                .map_err(|error| format!("GraphValidationError: {error}"))?;
            execute_pipeline(
                &mut engine,
                &phases,
                &project_dir,
                pipeline.auto_approve,
                pipeline.json,
                out,
            )
        }
    }
}

fn normalize_phases_dir(path: &Path) -> PathBuf {
    if path.join("phase0/node.json").is_file() {
        path.to_path_buf()
    } else if path.join("BuildAgent.sh").is_file() {
        path.parent().unwrap_or(path).to_path_buf()
    } else {
        path.to_path_buf()
    }
}

fn print_validation(out: &mut dyn Write, engine: &GraphEngine, json: bool) -> Result<(), String> {
    let value = ValidationOutput {
        valid: engine.report.is_valid(),
        nodes: &engine.nodes,
        edges: &engine.edges,
        report: &engine.report,
    };
    if json {
        serde_json::to_writer_pretty(&mut *out, &value)
            .map_err(|error| format!("SerializationError: {error}"))?;
        writeln!(out).map_err(|error| format!("OutputError: {error}"))
    } else {
        writeln!(out, "valid: {}", value.valid).map_err(output_error)?;
        writeln!(out, "nodes: {}", engine.nodes.len()).map_err(output_error)?;
        for node in &engine.nodes {
            writeln!(out, "  {}: {}", node.id, node.label).map_err(output_error)?;
        }
        writeln!(out, "edges: {}", engine.edges.len()).map_err(output_error)?;
        for edge in &engine.edges {
            writeln!(out, "  {} -> {}", edge.from, edge.to).map_err(output_error)?;
        }
        writeln!(out, "stages: {:?}", engine.report.stages).map_err(output_error)?;
        writeln!(out, "critical path: {:?}", engine.report.critical_path).map_err(output_error)?;
        writeln!(out, "errors: {:?}", engine.report.errors).map_err(output_error)?;
        writeln!(out, "warnings: {:?}", engine.report.warnings).map_err(output_error)
    }
}

fn output_error(error: io::Error) -> String {
    format!("OutputError: {error}")
}

pub fn render_graph(engine: &GraphEngine, format: GraphFormat) -> String {
    match format {
        GraphFormat::Mermaid => {
            let mut text = String::from("graph TD\n");
            for node in &engine.nodes {
                text.push_str(&format!(
                    "    {}[\"{}\"]\n",
                    mermaid_id(&node.id),
                    escape_label(&node.label)
                ));
            }
            for edge in &engine.edges {
                text.push_str(&format!(
                    "    {} --> {}\n",
                    mermaid_id(&edge.from),
                    mermaid_id(&edge.to)
                ));
            }
            text
        }
        GraphFormat::Dot => {
            let mut text = String::from("digraph agentGraph {\n");
            for node in &engine.nodes {
                text.push_str(&format!(
                    "    \"{}\" [label=\"{}\"];\n",
                    node.id,
                    escape_label(&node.label)
                ));
            }
            for edge in &engine.edges {
                text.push_str(&format!("    \"{}\" -> \"{}\";\n", edge.from, edge.to));
            }
            text.push_str("}\n");
            text
        }
    }
}

fn mermaid_id(id: &str) -> String {
    let mut result = String::new();
    let mut uppercase = false;
    for character in id.chars() {
        if character.is_ascii_alphanumeric() {
            if uppercase {
                result.push(character.to_ascii_uppercase());
                uppercase = false;
            } else {
                result.push(character);
            }
        } else {
            uppercase = true;
        }
    }
    result
}

fn escape_label(label: &str) -> String {
    label.replace('\\', "\\\\").replace('"', "\\\"")
}

pub fn execute_pipeline(
    engine: &mut GraphEngine,
    phases_dir: &Path,
    project_dir: &Path,
    auto_approve: bool,
    json: bool,
    out: &mut dyn Write,
) -> Result<u8, String> {
    loop {
        let ready = engine.ready_set();
        if ready.is_empty() {
            if engine
                .states
                .values()
                .all(|state| state.satisfies_dependency())
            {
                writeln!(out, "pipeline complete").map_err(output_error)?;
                return Ok(0);
            }
            return Err("SchedulerStalledError: no ready nodes and graph is incomplete".into());
        }
        for id in ready {
            engine
                .start(&id)
                .map_err(|error| format!("GraphStateError: {error}"))?;
            save_graph_state(&graph_state_path(project_dir), engine)
                .map_err(|error| format!("GraphPersistError: {error}"))?;
            let node = engine
                .nodes
                .iter()
                .find(|node| node.id == id)
                .cloned()
                .ok_or_else(|| format!("UnknownNodeError: {id}"))?;
            let SpawnTarget::Script(command) =
                node_agent_cmd(phases_dir, project_dir, None, None, &node, true)
            else {
                return Err(format!("NodeCommandError: cannot execute node '{id}'"));
            };
            let mut process = Command::new(&command.program);
            process.args(&command.args).envs(command.env);
            if let Some(directory) = command.cwd.as_deref() {
                process.current_dir(directory);
            } else {
                process.current_dir(project_dir);
            }
            let status = process
                .status()
                .map_err(|error| format!("NodeSpawnError: node '{id}': {error}"))?;
            let exit_code = status.code().unwrap_or(-1);
            let state = engine
                .apply_exit_code(&id, exit_code)
                .map_err(|error| format!("GraphStateError: {error}"))?;
            save_graph_state(&graph_state_path(project_dir), engine)
                .map_err(|error| format!("GraphPersistError: {error}"))?;
            if json {
                serde_json::to_writer(
                    &mut *out,
                    &PipelineEvent {
                        node: &id,
                        state,
                        exit_code,
                    },
                )
                .map_err(|error| format!("SerializationError: {error}"))?;
                writeln!(out).map_err(output_error)?;
            } else {
                writeln!(out, "node {id}: {state:?} (exit {exit_code})").map_err(output_error)?;
            }
            match state {
                NodeState::AwaitingApproval if auto_approve => {
                    engine
                        .approve(&id)
                        .map_err(|error| format!("GraphStateError: {error}"))?;
                    save_graph_state(&graph_state_path(project_dir), engine)
                        .map_err(|error| format!("GraphPersistError: {error}"))?;
                    writeln!(out, "node {id}: approved (--auto-approve)").map_err(output_error)?;
                }
                NodeState::AwaitingApproval => {
                    writeln!(out, "human gate: node {id} is AwaitingApproval; rerun with --auto-approve to proceed (exit {GATE_EXIT_CODE})").map_err(output_error)?;
                    return Ok(GATE_EXIT_CODE);
                }
                NodeState::Succeeded => {}
                NodeState::Failed => {
                    return Err(format!("NodeFailedError: node '{id}' exited {exit_code}"))
                }
                NodeState::HumanIntervention => {
                    return Err(format!("HumanInterventionError: node '{id}' exited 20"))
                }
                other => {
                    return Err(format!(
                        "UnexpectedNodeStateError: node '{id}' entered {other:?}"
                    ))
                }
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use std::fs;
    use std::os::unix::fs::PermissionsExt;

    use clap::Parser;

    use super::*;

    #[test]
    fn no_subcommand_selects_tui_path() {
        let args = CliArgs::try_parse_from(["orch"]).unwrap();
        assert!(args.command.is_none());
    }

    #[test]
    fn render_shapes_are_valid() {
        let phases = Path::new(env!("CARGO_MANIFEST_DIR")).join("../..");
        let engine = load_agent_graph(&phases).unwrap();
        let mermaid = render_graph(&engine, GraphFormat::Mermaid);
        assert!(mermaid.starts_with("graph TD\n"));
        assert!(mermaid.contains("phase0Constitution[\"Constitution Agent\"]"));
        assert!(!mermaid.contains("classDef"));
        assert!(!mermaid.contains("style "));
        let dot = render_graph(&engine, GraphFormat::Dot);
        assert!(dot.starts_with("digraph agentGraph {"));
        assert!(dot.contains("\"phase0.constitution\" -> \"phase1.planner\""));
    }

    #[test]
    fn validation_returns_named_error_for_invalid_manifest_set() {
        let temp = tempfile::tempdir().unwrap();
        let phases = temp.path().join("phases");
        make_fake_phases(&phases, true);
        fs::write(phases.join("phase0/node.json"), "not json").unwrap();
        let args = CliArgs::try_parse_from([
            "orch",
            "graph",
            "validate",
            "--agents-dir",
            phases.to_str().unwrap(),
        ])
        .unwrap();
        let error = run_command_with_writer(args, &mut Vec::new()).unwrap_err();
        assert!(error.starts_with("GraphValidationError:"));
        assert!(error.contains("phase0/node.json"));
    }

    #[test]
    fn pipeline_parks_at_gate_and_auto_approve_completes() {
        let temp = tempfile::tempdir().unwrap();
        let phases = temp.path().join("phases");
        let project = temp.path().join("project");
        fs::create_dir_all(&project).unwrap();
        make_fake_phases(&phases, false);
        let mut parked = load_agent_graph(&phases).unwrap();
        let mut output = Vec::new();
        let code =
            execute_pipeline(&mut parked, &phases, &project, false, false, &mut output).unwrap();
        assert_eq!(code, GATE_EXIT_CODE);
        assert_eq!(parked.states["phase0.root"], NodeState::AwaitingApproval);
        assert_eq!(parked.states["phase1.child"], NodeState::Pending);

        fs::remove_dir_all(project.join("Artifacts")).unwrap();
        let mut completed = load_agent_graph(&phases).unwrap();
        let code = execute_pipeline(
            &mut completed,
            &phases,
            &project,
            true,
            false,
            &mut Vec::new(),
        )
        .unwrap();
        assert_eq!(code, 0);
        assert!(completed
            .states
            .values()
            .all(|state| *state == NodeState::Succeeded));
    }

    fn make_fake_phases(phases: &Path, only_root: bool) {
        for phase in 0..=5 {
            fs::create_dir_all(phases.join(format!("phase{phase}"))).unwrap();
        }
        let script = phases.join("phase0/fake.sh");
        fs::write(&script, "#!/bin/sh\nexit 0\n").unwrap();
        let mut permissions = fs::metadata(&script).unwrap().permissions();
        permissions.set_mode(0o755);
        fs::set_permissions(&script, permissions).unwrap();
        let root = r#"{"schemaVersion":1,"id":"phase0.root","kind":"agent","label":"Root","exec":{"type":"script","path":"phase0/fake.sh","args":[]},"consumes":[],"produces":[{"type":"constitution.root"}],"gate":"human","retry":{"maxAttempts":1}}"#;
        let child = r#"{"schemaVersion":1,"id":"phase1.child","kind":"agent","label":"Child","exec":{"type":"script","path":"phase0/fake.sh","args":[]},"consumes":[{"type":"constitution.root"}],"produces":[],"gate":"none","retry":{"maxAttempts":1}}"#;
        fs::write(phases.join("phase0/node.json"), root).unwrap();
        fs::write(
            phases.join("phase1/node.json"),
            if only_root { "[]" } else { child },
        )
        .unwrap();
        for phase in 2..=4 {
            let leaf = child.replace("phase1.child", &format!("phase{phase}.leaf"));
            fs::write(phases.join(format!("phase{phase}/node.json")), leaf).unwrap();
        }
        let first = child.replace("phase1.child", "phase5.first");
        let second = child.replace("phase1.child", "phase5.second");
        fs::write(
            phases.join("phase5/node.json"),
            format!("[{first},{second}]"),
        )
        .unwrap();
    }
}
