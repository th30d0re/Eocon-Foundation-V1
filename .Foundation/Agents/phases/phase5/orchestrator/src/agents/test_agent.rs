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
    _model: Option<&str>,
    simulator_name: Option<&str>,
    stage: Option<&str>,
    resume_from: Option<&str>,
    verbose: bool,
    dry_run: bool,
    coverage: Option<u8>,
    strategy: Option<&str>,
    files: Option<&str>,
    happy_only: bool,
) -> AgentCmd {
    let mut args = vec![];

    if let Some(v) = ai_provider {
        args.push("--ai-provider".to_string());
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
    if let Some(v) = resume_from {
        args.push("--resume-from".to_string());
        args.push(v.to_string());
    }
    if let Some(v) = coverage {
        args.push("--coverage".to_string());
        args.push(v.to_string());
    }
    if let Some(v) = strategy {
        args.push("--strategy".to_string());
        args.push(v.to_string());
    }
    if let Some(v) = files {
        args.push("--files".to_string());
        args.push(v.to_string());
    }
    if happy_only {
        args.push("--happy-only".to_string());
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

    // Derive cwd from project path so artifacts, git, and auto-detection
    // happen in the project directory, not the orch launch directory.
    // .xcodeproj and .xcworkspace are directory bundles on macOS, so we
    // must use their parent as the cwd.
    let cwd = project.and_then(|p| {
        let path = std::path::Path::new(p);
        let ext = path.extension().and_then(|e| e.to_str()).unwrap_or("");
        if path.is_dir() && ext != "xcodeproj" && ext != "xcworkspace" {
            Some(path.to_string_lossy().into_owned())
        } else {
            path.parent().map(|d| d.to_string_lossy().into_owned())
        }
    });

    AgentCmd {
        program,
        args,
        env: vec![("SKIP_STAGE_PROMPT".to_string(), "true".to_string())],
        cwd,
    }
}
