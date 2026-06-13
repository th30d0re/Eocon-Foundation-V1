use std::path::Path;

use crate::agents::runner::AgentCmd;

/// Build the AgentCmd for BuildAgent.sh with the verified argument contract.
///
/// Verified facts from BuildVerify.sh lines 806-824:
/// - args: --ai-provider, --max-attempts, --ai-model, --prompt-string, --plan,
///   --plans-dir, --project, --scheme, --artifacts-dir, --platform, --destination,
///   --yolo, --verbose, --dry-run, --no-swift-docs
/// - BuildVerify always passed --no-fancy-ui (line 824). The orchestrator does NOT.
/// - `--simulator-name` and `--stage` are NOT in BuildAgent's contract (they are
///   testAgent flags), so they are intentionally not forwarded here.
/// - Exit codes: 0 = ok, 10 = build failed, 11 = env/setup error.
pub fn build_agent_cmd(
    agents_dir: &Path,
    project: Option<&str>,
    scheme: Option<&str>,
    ai_provider: Option<&str>,
    model: Option<&str>,
    max_attempts: Option<u32>,
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
    if let Some(v) = max_attempts {
        args.push("--max-attempts".to_string());
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
    if verbose {
        args.push("--verbose".to_string());
    }
    if dry_run {
        args.push("--dry-run".to_string());
    }

    // If the agent script exists in agents_dir, use the absolute path.
    // Otherwise fall back to a bare name and let the shell resolve via PATH.
    let program = if agents_dir.join("BuildAgent.sh").is_file() {
        agents_dir.join("BuildAgent.sh").to_string_lossy().into_owned()
    } else if agents_dir.join("BuildAgent").is_file() {
        agents_dir.join("BuildAgent").to_string_lossy().into_owned()
    } else {
        "BuildAgent".to_string()
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
        env: vec![],
        cwd,
    }
}
