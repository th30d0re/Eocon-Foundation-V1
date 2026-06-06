use std::path::Path;

use crate::agents::runner::AgentCmd;

/// Build the AgentCmd for testAgent.sh with the verified argument contract.
///
/// Verified facts from BuildVerify.sh lines 892-909:
/// - args: --ai-provider, --project, --scheme, --artifacts-dir, --stage,
///   --yolo, --verbose, --dry-run, --simulator-name, --skip-argent, --happy-only
/// - testAgent.sh has NO --no-fancy-ui flag.
/// - It skips interactive stage prompts when SKIP_STAGE_PROMPT=1 or --yolo.
pub fn test_agent_cmd(
    agents_dir: &Path,
    project: Option<&str>,
    scheme: Option<&str>,
    ai_provider: Option<&str>,
    model: Option<&str>,
    simulator_name: Option<&str>,
    stage: Option<&str>,
    verbose: bool,
    dry_run: bool,
) -> AgentCmd {
    let mut args = vec!["--yolo".to_string()];

    if let Some(v) = ai_provider {
        args.push("--ai-provider".to_string());
        args.push(v.to_string());
    }
    if let Some(v) = model {
        args.push("--ai-model".to_string());
        args.push(v.to_string());
    }
    if let Some(v) = project {
        args.push("--project".to_string());
        args.push(v.to_string());
    }
    if let Some(v) = scheme {
        args.push("--scheme".to_string());
        args.push(v.to_string());
    }
    if let Some(v) = simulator_name {
        args.push("--simulator-name".to_string());
        args.push(v.to_string());
    }
    if let Some(v) = stage {
        args.push("--stage".to_string());
        args.push(v.to_string());
    }
    if verbose {
        args.push("--verbose".to_string());
    }
    if dry_run {
        args.push("--dry-run".to_string());
    }

    // If the agent script exists in agents_dir, use the absolute path.
    // Otherwise fall back to a bare name and let the shell resolve via PATH.
    let program = if agents_dir.join("testAgent.sh").is_file() {
        agents_dir.join("testAgent.sh").to_string_lossy().into_owned()
    } else if agents_dir.join("testAgent").is_file() {
        agents_dir.join("testAgent").to_string_lossy().into_owned()
    } else {
        "testAgent".to_string()
    };

    AgentCmd {
        program,
        args,
        env: vec![("SKIP_STAGE_PROMPT".to_string(), "1".to_string())],
        cwd: Some(agents_dir.to_string_lossy().into_owned()),
    }
}
