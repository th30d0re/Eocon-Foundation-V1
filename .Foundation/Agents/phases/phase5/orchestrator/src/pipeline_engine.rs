use std::path::{Path, PathBuf};

use serde::{Deserialize, Serialize};

use crate::agents::runner::AgentCmd;

/// The six Foundation pipeline phases.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum PipelinePhase {
    Constitution,
    Planner,
    Question,
    Optimization,
    Stages,
    Execution,
}

impl PipelinePhase {
    pub fn index(self) -> usize {
        match self {
            PipelinePhase::Constitution => 0,
            PipelinePhase::Planner => 1,
            PipelinePhase::Question => 2,
            PipelinePhase::Optimization => 3,
            PipelinePhase::Stages => 4,
            PipelinePhase::Execution => 5,
        }
    }

    pub fn from_index(idx: usize) -> Option<Self> {
        match idx {
            0 => Some(PipelinePhase::Constitution),
            1 => Some(PipelinePhase::Planner),
            2 => Some(PipelinePhase::Question),
            3 => Some(PipelinePhase::Optimization),
            4 => Some(PipelinePhase::Stages),
            5 => Some(PipelinePhase::Execution),
            _ => None,
        }
    }

    pub fn script_name(self) -> &'static str {
        match self {
            PipelinePhase::Constitution => "ConstitutionAgent.sh",
            PipelinePhase::Planner => "PlannerAgent.sh",
            PipelinePhase::Question => "QuestionAgent.sh",
            PipelinePhase::Optimization => "OptimizationAgent.sh",
            PipelinePhase::Stages => "StagesAgent.sh",
            PipelinePhase::Execution => "ExecutionAgent.sh", // not used; phase 5 is internal
        }
    }

    pub fn display_name(self) -> &'static str {
        match self {
            PipelinePhase::Constitution => "Constitution",
            PipelinePhase::Planner => "Planner",
            PipelinePhase::Question => "Question",
            PipelinePhase::Optimization => "Optimization",
            PipelinePhase::Stages => "Stages",
            PipelinePhase::Execution => "Execution",
        }
    }
}

/// Per-phase status in the Foundation pipeline.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, Default)]
#[serde(rename_all = "camelCase")]
pub enum PhaseStatus {
    #[default]
    Pending,
    Running,
    AwaitingApproval,
    Approved,
    Succeeded,
    Failed,
    HumanIntervention,
    Skipped,
}

impl PhaseStatus {
    /// Whether this status counts as satisfied for gating purposes.
    pub fn is_satisfied(self) -> bool {
        matches!(
            self,
            PhaseStatus::Succeeded | PhaseStatus::Approved | PhaseStatus::Skipped
        )
    }

    /// Whether the phase is in a terminal state.
    pub fn is_terminal(self) -> bool {
        matches!(
            self,
            PhaseStatus::Succeeded
                | PhaseStatus::Failed
                | PhaseStatus::HumanIntervention
                | PhaseStatus::Skipped
                | PhaseStatus::Approved
        )
    }
}

/// Persistent state for a single phase.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, Default)]
#[serde(rename_all = "camelCase")]
pub struct PhaseState {
    pub phase: u32,
    pub status: PhaseStatus,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub started_at: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub finished_at: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub approved_at: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub approved_by: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub result_path: Option<PathBuf>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub message: Option<String>,
}

/// Top-level persisted pipeline state.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PipelineRunState {
    pub schema_version: u32,
    pub phases: Vec<PhaseState>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub current_phase: Option<u32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub started_at: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub finished_at: Option<String>,
}

impl Default for PipelineRunState {
    fn default() -> Self {
        Self::new()
    }
}

impl PipelineRunState {
    pub fn new() -> Self {
        Self {
            schema_version: 1,
            phases: (0..=5)
                .map(|idx| PhaseState {
                    phase: idx,
                    status: PhaseStatus::Pending,
                    ..Default::default()
                })
                .collect(),
            current_phase: None,
            started_at: None,
            finished_at: None,
        }
    }

    pub fn with_started_now() -> Self {
        let mut s = Self::new();
        s.started_at = Some(now_iso());
        s
    }

    pub fn phase(&self, idx: usize) -> Option<&PhaseState> {
        self.phases.get(idx)
    }

    pub fn phase_mut(&mut self, idx: usize) -> Option<&mut PhaseState> {
        self.phases.get_mut(idx)
    }
}

/// Result artifact produced by a phase agent (contract §4).
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PhaseResult {
    pub schema_version: u32,
    pub phase: u32,
    pub agent: String,
    pub status: String,
    pub started_at: String,
    pub finished_at: String,
    pub provider: String,
    #[serde(default)]
    pub outputs: Vec<String>,
    #[serde(default)]
    pub requires_approval: bool,
    #[serde(default)]
    pub human_intervention: Option<String>,
    #[serde(default)]
    pub errors: Vec<String>,
}

/// Outcome of interpreting an agent exit code.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum AgentExitStatus {
    Success,
    Failed,
    Misconfiguration,
    HumanIntervention,
    Unknown(i32),
}

impl AgentExitStatus {
    pub fn from_code(code: i32) -> Self {
        match code {
            0 => AgentExitStatus::Success,
            10 => AgentExitStatus::Failed,
            11 => AgentExitStatus::Misconfiguration,
            20 => AgentExitStatus::HumanIntervention,
            other => AgentExitStatus::Unknown(other),
        }
    }
}

/// What to spawn for a given phase.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum SpawnTarget {
    /// Spawn a shell script with the given AgentCmd.
    Script(AgentCmd),
    /// Phase 5 uses the existing BuildAgent + TestAgent flow.
    Phase5Existing,
    /// Agent script is missing.
    Missing(String),
}

/// Resolve the absolute path to a phase agent script.
pub fn phase_agent_path(phases_dir: &Path, phase: usize) -> PathBuf {
    let script = PipelinePhase::from_index(phase)
        .map(|p| p.script_name())
        .unwrap_or("UnknownAgent.sh");
    phases_dir.join(format!("phase{}/{}", phase, script))
}

/// Build an AgentCmd for phases 0-4. Returns Missing if the script does not exist.
/// Phase 5 returns Phase5Existing so the caller can reuse the existing build/test path.
pub fn phase_agent_cmd(
    phases_dir: &Path,
    project_dir: &Path,
    provider: Option<&str>,
    phase: usize,
    dry_run: bool,
) -> SpawnTarget {
    if phase == 5 {
        return SpawnTarget::Phase5Existing;
    }
    let path = phase_agent_path(phases_dir, phase);
    if !path.is_file() {
        return SpawnTarget::Missing(format!(
            "Phase {} agent not found: {}",
            phase,
            path.display()
        ));
    }

    let mut args = vec![
        "--project-dir".to_string(),
        project_dir.to_string_lossy().into_owned(),
        "--yolo".to_string(),
    ];
    if let Some(p) = provider {
        args.push("--ai-provider".to_string());
        args.push(p.to_string());
    }
    if dry_run {
        args.push("--dry-run".to_string());
        // Phase 0 requires input; supply a placeholder so the dry-run pipeline can
        // proceed end-to-end without a user-provided constitution prompt.
        if phase == 0 {
            args.push("--prompt".to_string());
            args.push("Foundation dry-run placeholder constitution prompt".to_string());
        }
    }

    SpawnTarget::Script(AgentCmd {
        program: path.to_string_lossy().into_owned(),
        args,
        env: vec![],
        cwd: Some(project_dir.to_string_lossy().into_owned()),
    })
}

/// Find the newest `<project>/Artifacts/phase<N>_*/result.json`.
pub fn find_latest_result_json(project_dir: &Path, phase: usize) -> Option<PathBuf> {
    let artifacts_dir = project_dir.join("Artifacts");
    let prefix = format!("phase{}_", phase);
    let mut best: Option<(std::time::SystemTime, PathBuf)> = None;

    let entries = std::fs::read_dir(&artifacts_dir).ok()?;
    for entry in entries.flatten() {
        let name = entry.file_name();
        let name_str = name.to_string_lossy();
        if name_str.starts_with(&prefix) && entry.file_type().map(|t| t.is_dir()).unwrap_or(false) {
            let result_path = entry.path().join("result.json");
            if result_path.is_file() {
                let modified = std::fs::metadata(&result_path)
                    .and_then(|m| m.modified())
                    .unwrap_or(std::time::UNIX_EPOCH);
                if best.as_ref().map_or(true, |(t, _)| modified > *t) {
                    best = Some((modified, result_path));
                }
            }
        }
    }

    best.map(|(_, p)| p)
}

/// Parse a phase result.json artifact per contract §4.
pub fn parse_result_json(path: &Path) -> Result<PhaseResult, String> {
    let text = std::fs::read_to_string(path)
        .map_err(|e| format!("failed to read result.json {}: {}", path.display(), e))?;
    serde_json::from_str(&text).map_err(|e| format!("failed to parse result.json: {}", e))
}

/// Map an exit code to the orchestrator-facing status.
pub fn map_exit_code(code: i32) -> AgentExitStatus {
    AgentExitStatus::from_code(code)
}

/// Determine whether phase `idx` may legally start given the current state.
/// Phase 0 can always start. Later phases require all previous phases to be
/// Succeeded, Approved, or Skipped.
pub fn can_start_phase(state: &PipelineRunState, idx: usize) -> Result<(), String> {
    if idx >= state.phases.len() {
        return Err(format!("phase {} is out of range (0-{})", idx, state.phases.len() - 1));
    }
    for prev in 0..idx {
        let prev_status = state.phases[prev].status;
        if !prev_status.is_satisfied() {
            return Err(format!(
                "phase {} is {} — cannot start phase {} until previous phases are satisfied",
                prev, status_label(prev_status), idx
            ));
        }
    }
    Ok(())
}

/// Mark a phase as Running and record its start time.
pub fn start_phase(state: &mut PipelineRunState, idx: usize) -> Result<(), String> {
    can_start_phase(state, idx)?;
    let now = now_iso();
    let phase = state.phase_mut(idx).ok_or_else(|| "invalid phase".to_string())?;
    phase.status = PhaseStatus::Running;
    phase.started_at = Some(now);
    phase.finished_at = None;
    phase.message = None;
    state.current_phase = Some(idx as u32);
    Ok(())
}

/// Apply an exit code + parsed result to the phase state. Returns user-facing
/// messages and whether the pipeline should stop (true = stop, false = continue).
pub fn apply_phase_outcome(
    state: &mut PipelineRunState,
    idx: usize,
    exit: AgentExitStatus,
    result: Option<&PhaseResult>,
    result_path: Option<&Path>,
) -> (Vec<String>, bool) {
    let mut messages = Vec::new();
    let now = now_iso();
    let phase = match state.phase_mut(idx) {
        Some(p) => p,
        None => {
            messages.push(format!("Internal error: invalid phase index {}", idx));
            return (messages, true);
        }
    };

    phase.finished_at = Some(now.clone());
    phase.result_path = result_path.map(|p| p.to_path_buf());

    let (status, stop) = match exit {
        AgentExitStatus::Success => {
            if let Some(r) = result {
                if r.requires_approval {
                    messages.push(format!(
                        "Phase {} ({}) completed and requires approval. Type /approve to continue or /reject to halt.",
                        idx,
                        PipelinePhase::from_index(idx).map(|p| p.display_name()).unwrap_or("?")
                    ));
                    (PhaseStatus::AwaitingApproval, true)
                } else {
                    messages.push(format!(
                        "Phase {} ({}) succeeded.",
                        idx,
                        PipelinePhase::from_index(idx).map(|p| p.display_name()).unwrap_or("?")
                    ));
                    (PhaseStatus::Succeeded, false)
                }
            } else if idx == 5 {
                // Phase 5 reuses the existing BuildAgent/TestAgent flow, which does
                // not produce a phase5_* result.json artifact.
                messages.push("Phase 5 (Execution) succeeded.".to_string());
                (PhaseStatus::Succeeded, false)
            } else {
                messages.push(format!(
                    "Phase {} succeeded but no result.json was found.",
                    idx
                ));
                (PhaseStatus::Failed, true)
            }
        }
        AgentExitStatus::Failed => {
            phase.message = Some("agent reported failure (exit 10)".to_string());
            messages.push(format!(
                "Phase {} ({}) failed.",
                idx,
                PipelinePhase::from_index(idx).map(|p| p.display_name()).unwrap_or("?")
            ));
            (PhaseStatus::Failed, true)
        }
        AgentExitStatus::Misconfiguration => {
            phase.message = Some("agent misconfiguration (exit 11)".to_string());
            messages.push(format!(
                "Phase {} ({}) misconfigured — check flags and environment.",
                idx,
                PipelinePhase::from_index(idx).map(|p| p.display_name()).unwrap_or("?")
            ));
            (PhaseStatus::Failed, true)
        }
        AgentExitStatus::HumanIntervention => {
            phase.message = Some("human intervention required (exit 20)".to_string());
            messages.push(format!(
                "Phase {} ({}) requires human intervention. See the agent report for details.",
                idx,
                PipelinePhase::from_index(idx).map(|p| p.display_name()).unwrap_or("?")
            ));
            (PhaseStatus::HumanIntervention, true)
        }
        AgentExitStatus::Unknown(code) => {
            phase.message = Some(format!("unexpected exit code {}", code));
            messages.push(format!(
                "Phase {} ({}) exited with unexpected code {}.",
                idx,
                PipelinePhase::from_index(idx).map(|p| p.display_name()).unwrap_or("?"),
                code
            ));
            (PhaseStatus::Failed, true)
        }
    };

    phase.status = status;
    if stop && status != PhaseStatus::AwaitingApproval {
        state.finished_at = Some(now);
    }
    (messages, stop)
}

/// Approve an AwaitingApproval gate. Returns Ok(message) or Err(message).
pub fn approve_phase(state: &mut PipelineRunState, idx: usize) -> Result<String, String> {
    let phase = state
        .phase_mut(idx)
        .ok_or_else(|| format!("invalid phase index {}", idx))?;
    if phase.status != PhaseStatus::AwaitingApproval {
        return Err(format!(
            "Phase {} is not awaiting approval (status: {:?}).",
            idx, phase.status
        ));
    }
    let now = now_iso();
    phase.status = PhaseStatus::Approved;
    phase.approved_at = Some(now);
    phase.approved_by = Some("human".to_string());
    Ok(format!(
        "Phase {} approved. Pipeline will continue.",
        idx
    ))
}

/// Reject an AwaitingApproval gate, marking the phase Failed and the run finished.
pub fn reject_phase(state: &mut PipelineRunState, idx: usize) -> Result<String, String> {
    let phase = state
        .phase_mut(idx)
        .ok_or_else(|| format!("invalid phase index {}", idx))?;
    if phase.status != PhaseStatus::AwaitingApproval {
        return Err(format!(
            "Phase {} is not awaiting approval (status: {:?}).",
            idx, phase.status
        ));
    }
    let now = now_iso();
    phase.status = PhaseStatus::Failed;
    phase.finished_at = Some(now.clone());
    phase.message = Some("rejected by human".to_string());
    state.finished_at = Some(now);
    Ok(format!("Phase {} rejected. Pipeline halted.", idx))
}

/// Skip a phase. Skipped phases count as satisfied for gating.
pub fn skip_phase(state: &mut PipelineRunState, idx: usize) -> Result<String, String> {
    if idx >= state.phases.len() {
        return Err(format!("invalid phase index {}", idx));
    }
    let phase = state.phase_mut(idx).unwrap();
    if phase.status == PhaseStatus::Running || phase.status == PhaseStatus::AwaitingApproval {
        return Err(format!(
            "Cannot skip phase {} while it is {}.",
            idx, status_label(phase.status)
        ));
    }
    phase.status = PhaseStatus::Skipped;
    phase.finished_at = Some(now_iso());
    Ok(format!("Phase {} skipped.", idx))
}

/// Find the phase currently awaiting approval, if any.
pub fn awaiting_approval_phase(state: &PipelineRunState) -> Option<usize> {
    state
        .phases
        .iter()
        .position(|p| p.status == PhaseStatus::AwaitingApproval)
}

/// Find the first phase that is not yet Succeeded/Approved/Skipped.
pub fn resume_phase_index(state: &PipelineRunState) -> usize {
    state
        .phases
        .iter()
        .position(|p| !p.status.is_satisfied())
        .unwrap_or(state.phases.len())
}

/// Return a compact human-readable summary of the pipeline.
pub fn format_status_summary(state: &PipelineRunState) -> String {
    let mut lines = vec!["Foundation Pipeline:".to_string()];
    for (idx, phase) in state.phases.iter().enumerate() {
        let name = PipelinePhase::from_index(idx)
            .map(|p| p.display_name())
            .unwrap_or("?");
        lines.push(format!(
            "  Phase {} {:<13} {}",
            idx,
            name,
            status_glyph(phase.status)
        ));
    }
    lines.join("\n")
}

/// Persist pipeline state to disk.
pub fn save_pipeline_state(path: &Path, state: &PipelineRunState) -> Result<(), String> {
    let text = serde_json::to_string_pretty(state)
        .map_err(|e| format!("failed to serialize pipeline state: {}", e))?;
    std::fs::write(path, text).map_err(|e| format!("failed to write {}: {}", path.display(), e))
}

/// Load pipeline state from disk if it exists.
pub fn load_pipeline_state(path: &Path) -> Option<PipelineRunState> {
    let text = std::fs::read_to_string(path).ok()?;
    serde_json::from_str(&text).ok()
}

pub fn pipeline_state_path(project_dir: &Path) -> PathBuf {
    project_dir.join("Artifacts").join("pipeline_state.json")
}

/// Detect the Foundation project root upward from `start_dir`.
/// Looks for a directory containing `.Foundation`.
pub fn detect_project_dir(start_dir: &Path) -> PathBuf {
    let mut current = Some(start_dir);
    while let Some(dir) = current {
        if dir.join(".Foundation").is_dir() {
            return dir.to_path_buf();
        }
        current = dir.parent();
    }
    start_dir.to_path_buf()
}

fn status_label(status: PhaseStatus) -> &'static str {
    match status {
        PhaseStatus::Pending => "pending",
        PhaseStatus::Running => "running",
        PhaseStatus::AwaitingApproval => "awaiting approval",
        PhaseStatus::Approved => "approved",
        PhaseStatus::Succeeded => "succeeded",
        PhaseStatus::Failed => "failed",
        PhaseStatus::HumanIntervention => "human intervention",
        PhaseStatus::Skipped => "skipped",
    }
}

fn status_glyph(status: PhaseStatus) -> &'static str {
    match status {
        PhaseStatus::Pending => "○ pending",
        PhaseStatus::Running => "◐ running",
        PhaseStatus::AwaitingApproval => "⏸ awaiting approval",
        PhaseStatus::Approved => "✓ approved",
        PhaseStatus::Succeeded => "✓ succeeded",
        PhaseStatus::Failed => "✕ failed",
        PhaseStatus::HumanIntervention => "⚠ human intervention",
        PhaseStatus::Skipped => "⊘ skipped",
    }
}

pub fn now_iso() -> String {
    let now = std::time::SystemTime::now();
    let duration = now.duration_since(std::time::UNIX_EPOCH).unwrap_or_default();
    format_iso8601(duration.as_secs())
}

fn format_iso8601(unix_secs: u64) -> String {
    const DAYS_IN_MONTH: [u64; 12] = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    let mut days = unix_secs / 86400;
    let mut year = 1970u64;
    loop {
        let leap = year % 4 == 0 && (year % 100 != 0 || year % 400 == 0);
        let year_days = if leap { 366 } else { 365 };
        if days < year_days {
            break;
        }
        days -= year_days;
        year += 1;
    }
    let leap = year % 4 == 0 && (year % 100 != 0 || year % 400 == 0);
    let mut month = 0usize;
    while month < 12 {
        let dim = if month == 1 && leap {
            29
        } else {
            DAYS_IN_MONTH[month]
        };
        if days < dim {
            break;
        }
        days -= dim;
        month += 1;
    }
    let day = days + 1;
    let rem = unix_secs % 86400;
    let hour = rem / 3600;
    let min = (rem % 3600) / 60;
    let sec = rem % 60;
    format!("{:04}-{:02}-{:02}T{:02}:{:02}:{:02}Z", year, month + 1, day, hour, min, sec)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn phase_status_satisfied_terminal() {
        assert!(PhaseStatus::Succeeded.is_satisfied());
        assert!(PhaseStatus::Approved.is_satisfied());
        assert!(PhaseStatus::Skipped.is_satisfied());
        assert!(!PhaseStatus::Pending.is_satisfied());
        assert!(!PhaseStatus::Running.is_satisfied());
        assert!(!PhaseStatus::AwaitingApproval.is_satisfied());
        assert!(!PhaseStatus::Failed.is_satisfied());

        assert!(PhaseStatus::Succeeded.is_terminal());
        assert!(PhaseStatus::Failed.is_terminal());
        assert!(!PhaseStatus::Running.is_terminal());
    }

    #[test]
    fn can_start_phase_enforces_order() {
        let state = PipelineRunState::new();
        assert!(can_start_phase(&state, 0).is_ok());
        assert!(can_start_phase(&state, 1).is_err());
        assert!(can_start_phase(&state, 2).is_err());
    }

    #[test]
    fn cannot_start_phase_2_when_phase_1_pending_or_failed() {
        let mut state = PipelineRunState::new();
        state.phases[0].status = PhaseStatus::Succeeded;
        // phase 1 still pending
        assert!(can_start_phase(&state, 2).is_err());
        state.phases[1].status = PhaseStatus::Failed;
        assert!(can_start_phase(&state, 2).is_err());
        state.phases[1].status = PhaseStatus::Succeeded;
        assert!(can_start_phase(&state, 2).is_ok());
    }

    #[test]
    fn exit_20_becomes_human_intervention() {
        let mut state = PipelineRunState::new();
        state.phases[0].status = PhaseStatus::Succeeded;
        state.phases[1].status = PhaseStatus::Succeeded;
        start_phase(&mut state, 2).unwrap();
        let result = PhaseResult {
            schema_version: 1,
            phase: 2,
            agent: "QuestionAgent".to_string(),
            status: "human_intervention".to_string(),
            started_at: "2026-01-01T00:00:00Z".to_string(),
            finished_at: "2026-01-01T00:01:00Z".to_string(),
            provider: "claude".to_string(),
            outputs: vec![],
            requires_approval: false,
            human_intervention: Some("need human input".to_string()),
            errors: vec![],
        };
        let (_, stop) = apply_phase_outcome(
            &mut state,
            2,
            AgentExitStatus::HumanIntervention,
            Some(&result),
            None,
        );
        assert!(stop);
        assert_eq!(state.phases[2].status, PhaseStatus::HumanIntervention);
    }

    #[test]
    fn can_start_phase_with_skipped_and_approved() {
        let mut state = PipelineRunState::new();
        state.phases[0].status = PhaseStatus::Succeeded;
        state.phases[1].status = PhaseStatus::Approved;
        state.phases[2].status = PhaseStatus::Skipped;
        assert!(can_start_phase(&state, 3).is_ok());
        assert!(can_start_phase(&state, 4).is_err());
    }

    #[test]
    fn exit_code_mapping() {
        assert_eq!(map_exit_code(0), AgentExitStatus::Success);
        assert_eq!(map_exit_code(10), AgentExitStatus::Failed);
        assert_eq!(map_exit_code(11), AgentExitStatus::Misconfiguration);
        assert_eq!(map_exit_code(20), AgentExitStatus::HumanIntervention);
        assert_eq!(map_exit_code(42), AgentExitStatus::Unknown(42));
    }

    #[test]
    fn requires_approval_flow() {
        let mut state = PipelineRunState::new();
        start_phase(&mut state, 0).unwrap();
        let result = PhaseResult {
            schema_version: 1,
            phase: 0,
            agent: "ConstitutionAgent".to_string(),
            status: "success".to_string(),
            started_at: "2026-01-01T00:00:00Z".to_string(),
            finished_at: "2026-01-01T00:01:00Z".to_string(),
            provider: "claude".to_string(),
            outputs: vec!["Constitution/C0.tex".to_string()],
            requires_approval: true,
            human_intervention: None,
            errors: vec![],
        };
        let (msgs, stop) = apply_phase_outcome(
            &mut state,
            0,
            AgentExitStatus::Success,
            Some(&result),
            Some(std::path::Path::new("Artifacts/phase0_20260101_120000/result.json")),
        );
        assert!(stop);
        assert_eq!(state.phases[0].status, PhaseStatus::AwaitingApproval);
        assert!(msgs[0].contains("requires approval"));

        // Cannot start phase 1 while awaiting approval.
        assert!(can_start_phase(&state, 1).is_err());

        let approve_msg = approve_phase(&mut state, 0).unwrap();
        assert!(approve_msg.contains("approved"));
        assert_eq!(state.phases[0].status, PhaseStatus::Approved);
        assert!(can_start_phase(&state, 1).is_ok());
    }

    #[test]
    fn reject_marks_failed_and_halts() {
        let mut state = PipelineRunState::new();
        start_phase(&mut state, 0).unwrap();
        let result = PhaseResult {
            schema_version: 1,
            phase: 0,
            agent: "ConstitutionAgent".to_string(),
            status: "success".to_string(),
            started_at: "2026-01-01T00:00:00Z".to_string(),
            finished_at: "2026-01-01T00:01:00Z".to_string(),
            provider: "claude".to_string(),
            outputs: vec![],
            requires_approval: true,
            human_intervention: None,
            errors: vec![],
        };
        apply_phase_outcome(
            &mut state,
            0,
            AgentExitStatus::Success,
            Some(&result),
            None,
        );
        let msg = reject_phase(&mut state, 0).unwrap();
        assert!(msg.contains("rejected"));
        assert_eq!(state.phases[0].status, PhaseStatus::Failed);
        assert!(state.finished_at.is_some());
    }

    #[test]
    fn pipeline_state_round_trip() {
        let tmp = tempfile::tempdir().unwrap();
        let path = tmp.path().join("pipeline_state.json");

        let mut state = PipelineRunState::with_started_now();
        state.phases[0].status = PhaseStatus::Succeeded;
        state.phases[1].status = PhaseStatus::AwaitingApproval;
        state.current_phase = Some(1);
        save_pipeline_state(&path, &state).unwrap();

        let loaded = load_pipeline_state(&path).expect("load failed");
        assert_eq!(loaded.schema_version, 1);
        assert_eq!(loaded.phases[0].status, PhaseStatus::Succeeded);
        assert_eq!(loaded.phases[1].status, PhaseStatus::AwaitingApproval);
        assert_eq!(loaded.current_phase, Some(1));
        assert_eq!(resume_phase_index(&loaded), 1);
    }

    #[test]
    fn result_json_parsing_contract_fixture() {
        let tmp = tempfile::tempdir().unwrap();
        let path = tmp.path().join("result.json");
        std::fs::write(
            &path,
            r#"{
  "schemaVersion": 1,
  "phase": 1,
  "agent": "PlannerAgent",
  "status": "success",
  "startedAt": "2026-06-10T12:00:00Z",
  "finishedAt": "2026-06-10T12:05:00Z",
  "provider": "claude",
  "outputs": ["Plans/plan1/plan1.md", "Plans/plan1/test1.md"],
  "requiresApproval": false,
  "humanIntervention": null,
  "errors": []
}"#,
        )
        .unwrap();

        let result = parse_result_json(&path).unwrap();
        assert_eq!(result.schema_version, 1);
        assert_eq!(result.phase, 1);
        assert_eq!(result.agent, "PlannerAgent");
        assert_eq!(result.status, "success");
        assert!(!result.requires_approval);
        assert_eq!(result.outputs.len(), 2);
    }

    #[test]
    fn missing_agent_script_returns_failed_without_panic() {
        let tmp = tempfile::tempdir().unwrap();
        let phases_dir = tmp.path().join("phases");
        let project_dir = tmp.path().join("project");
        std::fs::create_dir_all(&project_dir).unwrap();

        match phase_agent_cmd(&phases_dir, &project_dir, Some("claude"), 0, false) {
            SpawnTarget::Missing(msg) => {
                assert!(msg.contains("Phase 0 agent not found"));
            }
            other => panic!("expected Missing, got {:?}", other),
        }
    }

    #[test]
    fn phase5_returns_existing_target() {
        let tmp = tempfile::tempdir().unwrap();
        match phase_agent_cmd(tmp.path(), tmp.path(), Some("claude"), 5, false) {
            SpawnTarget::Phase5Existing => {}
            other => panic!("expected Phase5Existing, got {:?}", other),
        }
    }

    #[test]
    fn phase_agent_cmd_includes_dry_run_flag() {
        let tmp = tempfile::tempdir().unwrap();
        let phases_dir = tmp.path().join("phases");
        let phase0_dir = phases_dir.join("phase0");
        std::fs::create_dir_all(&phase0_dir).unwrap();
        std::fs::write(phase0_dir.join("ConstitutionAgent.sh"), "#!/bin/bash\necho ok").unwrap();

        let project_dir = tmp.path().join("project");
        std::fs::create_dir_all(&project_dir).unwrap();

        match phase_agent_cmd(&phases_dir, &project_dir, Some("claude"), 0, true) {
            SpawnTarget::Script(cmd) => {
                assert!(cmd.args.contains(&"--dry-run".to_string()));
                assert!(cmd.args.contains(&"--prompt".to_string()));
            }
            other => panic!("expected Script, got {:?}", other),
        }
    }

    #[test]
    fn find_latest_result_json_prefers_newest() {
        let tmp = tempfile::tempdir().unwrap();
        let artifacts = tmp.path().join("Artifacts");
        let d1 = artifacts.join("phase1_20260101_120000");
        let d2 = artifacts.join("phase1_20260102_120000");
        std::fs::create_dir_all(&d1).unwrap();
        std::fs::create_dir_all(&d2).unwrap();
        std::fs::write(d1.join("result.json"), "{}").unwrap();
        std::fs::write(d2.join("result.json"), "{}").unwrap();

        let latest = find_latest_result_json(tmp.path(), 1).unwrap();
        assert!(latest.to_string_lossy().contains("phase1_20260102_120000"));
    }

    #[test]
    fn detect_project_dir_finds_foundation_root() {
        let tmp = tempfile::tempdir().unwrap();
        let root = tmp.path().join("repo");
        std::fs::create_dir_all(root.join(".Foundation")).unwrap();
        let detected = detect_project_dir(&root.join("sub"));
        assert_eq!(detected, root);
    }

    #[test]
    fn skip_phase_counts_as_satisfied() {
        let mut state = PipelineRunState::new();
        skip_phase(&mut state, 0).unwrap();
        assert_eq!(state.phases[0].status, PhaseStatus::Skipped);
        assert!(can_start_phase(&state, 1).is_ok());
    }
}
