use std::path::PathBuf;
use std::sync::mpsc::Receiver;
use std::time::Instant;

use ratatui::style::Color;

use crate::action::Action;
use crate::apply::{apply_changes, PendingChange};
use crate::chat::{build_system_prompt, ChatMessage, ChatRequest};
use crate::mock;
use crate::pipeline_engine::{
    approve_phase, apply_phase_outcome, awaiting_approval_phase, can_start_phase,
    find_latest_result_json, format_status_summary, map_exit_code, parse_result_json,
    pipeline_state_path, reject_phase, save_pipeline_state, skip_phase, start_phase,
    PipelineRunState,
};
use crate::pty_screen::PtyScreen;
use crate::ui::theme::Voice;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Phase {
    Idle,
    Init,
    Build,
    Test,
    Complete,
    Failed,
    Aborted,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum AgentState {
    Idle,
    Thinking,
    Acting,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PaneLayout {
    Split,
    OutputOnly,
    InteractionOnly,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub enum FocusedPane {
    #[default]
    Interaction,
    Output,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum InfoView {
    Metrics,
    Artifacts,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ApplyPhase {
    Idle,
    Prompting,
    Building,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SpawnRequest {
    Build,
    Test,
}

/// What kind of agent is currently running.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub enum ActiveAgentKind {
    #[default]
    None,
    Build,
    Test,
    PipelinePhase(usize),
}

/// Sub-step tracking for pipeline phase 5 (BuildAgent -> TestAgent).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Phase5Step {
    Build,
    Test,
}

/// Status of an individual pipeline stage for the visualizer.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub enum StageStatus {
    #[default]
    Pending,
    Running,
    Completed,
    Failed,
    Skipped,
}

/// A single stage in the Phase 5 test pipeline.
#[derive(Debug, Clone, Default)]
pub struct PipelineStage {
    pub key: &'static str,
    pub label: &'static str,
    pub status: StageStatus,
    pub duration: u64,
    pub coverage: u8,
}

/// Phase 5 TestAgent pipeline stages in execution order.
pub const PHASE5_STAGES: &[(&str, &str)] = &[
    ("unit", "Unit"),
    ("accessibility", "A11y"),
    ("flow", "Flow"),
    ("discover", "Discover"),
    ("ui", "UI"),
    ("run", "Run"),
    ("maestro", "Maestro"),
    ("argent", "Argent"),
];

/// BuildAgent pipeline stages in execution order.
pub const BUILD_STAGES: &[(&str, &str)] = &[
    ("context", "Context"),
    ("generate", "Generate"),
    ("build", "Build"),
    ("repair", "Repair"),
    ("complete", "Done"),
];

impl PaneLayout {
    pub fn next(self) -> Self {
        match self {
            PaneLayout::Split => PaneLayout::OutputOnly,
            PaneLayout::OutputOnly => PaneLayout::InteractionOnly,
            PaneLayout::InteractionOnly => PaneLayout::Split,
        }
    }
}

#[derive(Debug, Clone)]
pub struct InteractionMessage {
    pub voice: Voice,
    pub text: String,
}

/// A slash-command available in the picker.
#[derive(Debug, Clone)]
pub struct SlashCommand {
    pub name: &'static str,
    pub description: &'static str,
    pub takes_arg: bool,
    pub arg_hint: &'static str,
}

pub const SLASH_COMMANDS: &[SlashCommand] = &[
    SlashCommand { name: "/build", description: "Start BuildAgent", takes_arg: false, arg_hint: "" },
    SlashCommand { name: "/test", description: "Start TestAgent", takes_arg: false, arg_hint: "" },
    SlashCommand { name: "/test-from", description: "Start TestAgent from a specific stage", takes_arg: true, arg_hint: "<stage>" },
    SlashCommand { name: "/test-stage", description: "Run a single TestAgent stage", takes_arg: true, arg_hint: "<stage>" },
    SlashCommand { name: "/provider", description: "Switch AI provider", takes_arg: true, arg_hint: "<provider>" },
    SlashCommand { name: "/model", description: "Switch AI model", takes_arg: true, arg_hint: "<model>" },
    SlashCommand { name: "/coverage", description: "Set target test coverage %", takes_arg: true, arg_hint: "<percent>" },
    SlashCommand { name: "/strategy", description: "Set test strategy", takes_arg: true, arg_hint: "<priority|coverage|balanced|happy-only>" },
    SlashCommand { name: "/files", description: "Set test file scope pattern", takes_arg: true, arg_hint: "<pattern>" },
    SlashCommand { name: "/happy-only", description: "Toggle happy-path-only mode", takes_arg: false, arg_hint: "" },
    SlashCommand { name: "/skip", description: "Skip current phase", takes_arg: false, arg_hint: "" },
    SlashCommand { name: "/pipeline", description: "Run or inspect the full Foundation pipeline", takes_arg: true, arg_hint: "[status]" },
    SlashCommand { name: "/phase", description: "Run a single pipeline phase", takes_arg: true, arg_hint: "<n> [--force]" },
    SlashCommand { name: "/approve", description: "Approve an awaiting-approval gate", takes_arg: false, arg_hint: "" },
    SlashCommand { name: "/reject", description: "Reject an awaiting-approval gate", takes_arg: false, arg_hint: "" },
    SlashCommand { name: "/skip-phase", description: "Skip a pipeline phase", takes_arg: true, arg_hint: "<n>" },
    SlashCommand { name: "/status", description: "Show current status", takes_arg: false, arg_hint: "" },
    SlashCommand { name: "/info", description: "Toggle info panel view", takes_arg: false, arg_hint: "" },
    SlashCommand { name: "/metrics", description: "Show metrics view", takes_arg: false, arg_hint: "" },
    SlashCommand { name: "/artifacts", description: "Show artifacts view", takes_arg: false, arg_hint: "" },
    SlashCommand { name: "/help", description: "Show available commands", takes_arg: false, arg_hint: "" },
    SlashCommand { name: "/apply", description: "Apply pending AI-suggested changes", takes_arg: false, arg_hint: "" },
    SlashCommand { name: "/discard", description: "Discard pending AI-suggested changes", takes_arg: false, arg_hint: "" },
    SlashCommand { name: "/quit", description: "Exit orchestrator", takes_arg: false, arg_hint: "" },
];

/// Available AI providers and their models.
pub const PROVIDERS: &[(&str, &[&str])] = &[
    ("moonshot", &["kimi-k2.7", "kimi-k2.6"]),
    ("openai", &["gpt-4o", "gpt-4o-mini", "gpt-4-turbo", "o1-preview", "o1-mini"]),
    ("codex", &["o3", "o4-mini", "gpt-5.5"]),
    ("cursor", &["cursor-small", "cursor-large"]),
    ("anthropic", &["claude-fable-5", "claude-sonnet-4", "claude-opus-4", "claude-sonnet-3-5", "claude-haiku-3-5"]),
    ("google", &["gemini-2.5-pro", "gemini-2.5-flash", "gemini-2.0-flash"]),
    ("ollama", &["llama3", "llama3.1", "mistral", "codellama", "qwen2.5"]),
    ("openrouter", &["auto", "openai/gpt-4o", "anthropic/claude-sonnet-4", "google/gemini-2.5-pro"]),
];

pub struct App {
    pub phase: Phase,
    pub agent_state: AgentState,
    pub error_count: u32,
    pub started: Instant,
    /// When the current command (build/test) started, if any.
    pub command_started: Option<Instant>,
    pub build_exit: Option<i32>,
    pub test_exit: Option<i32>,
    pub interaction: Vec<InteractionMessage>,
    pub screen: PtyScreen,
    pub pane_layout: PaneLayout,
    pub bottom_expanded: bool,
    pub should_quit: bool,
    pub tick_count: u64,
    pub show_help: bool,
    pub mock_mode: bool,
    pub input_buffer: String,
    pub input_cursor: usize,
    pub current_provider: Option<String>,
    pub current_model: Option<String>,
    pub info_view: InfoView,
    // Paths for artifacts view
    pub agents_dir: PathBuf,
    pub project: Option<String>,
    pub scheme: Option<String>,
    pub artifacts_dir: Option<PathBuf>,
    pub cwd: PathBuf,
    /// Set by /build or /test; drained by the main loop to perform actual spawns.
    pub spawn_request: Option<SpawnRequest>,
    /// Override stage for the next TestAgent run (set by /test-stage).
    pub test_stage: Option<String>,
    /// Resume-from stage for the next TestAgent run (set by /test-from).
    pub test_resume_from: Option<String>,
    /// A chat message typed without a leading slash, waiting to be sent to the active agent.
    pub pending_chat: Option<String>,
    // Command picker state
    pub picker_open: bool,
    pub picker_selected: usize,
    pub picker_filtered: Vec<usize>,
    // AI chat state
    pub chat_messages: Vec<ChatMessage>,
    pub chat_request: Option<ChatRequest>,
    pub chat_rx: Option<Receiver<Result<String, String>>>,
    /// Lines scrolled up in the interaction pane (0 = at bottom).
    pub interaction_scroll: u16,
    // Pending AI-suggested code changes
    pub pending_changes: Vec<PendingChange>,
    pub apply_phase: ApplyPhase,
    pub apply_build_exit: Option<i32>,
    /// Which pane currently has focus for arrow-key scrolling.
    pub focused_pane: FocusedPane,
    /// Target test coverage percentage (e.g., 80).
    pub test_coverage: Option<u8>,
    /// Test generation strategy: priority, coverage, balanced, happy-only.
    pub test_strategy: Option<String>,
    /// File scope pattern for TestAgent (e.g., "Sources/Models/*.swift").
    pub test_files: Option<String>,
    /// Only run happy-path tests across all stages.
    pub test_happy_only: bool,
    /// Phase 5 TestAgent pipeline stage statuses for the visualizer.
    pub pipeline_stages: Vec<PipelineStage>,
    /// Directory of the current test run (where stages.json lives).
    pub pipeline_run_dir: Option<PathBuf>,
    /// BuildAgent pipeline stage statuses for the visualizer.
    pub build_stages: Vec<PipelineStage>,
    /// Directory of the current build run (where build_stages.json lives).
    pub build_run_dir: Option<PathBuf>,
    /// Foundation project root detected from cwd.
    pub project_dir: PathBuf,
    /// Currently running agent kind (for dispatching AgentExited).
    pub active_agent: ActiveAgentKind,
    /// Full 0-5 pipeline state.
    pub pipeline_state: Option<PipelineRunState>,
    /// Whether the full pipeline is currently auto-running.
    pub pipeline_running: bool,
    /// For phase 5, tracks whether we are running BuildAgent or TestAgent.
    pub pipeline_phase5_step: Option<Phase5Step>,
    /// Target phase for a single `/phase <n>` invocation.
    pub pipeline_single_phase_target: Option<usize>,
    /// Dry-run mode: when true, agents are invoked with `--dry-run` (no AI/network).
    pub dry_run: bool,
}

/// Fun status messages shown on the info line (Claude Code style).
pub const FUN_STATUSES: &[&str] = &[
    "Applying digital duct tape",
    "Consulting the oracle",
    "Thinking really hard",
    "Polishing pixels",
    "Herding cats",
    "Brewing coffee",
    "Aligning the stars",
    "Untangling spaghetti",
    "Calibrating chaos",
    "Feeding the hamsters",
    "Optimizing optimism",
    "Downloading more RAM",
    "Asking the magic 8-ball",
    "Warming up the flux capacitor",
    "Teaching rocks to think",
    "Counting to infinity",
    "Bribing the compiler",
    "Watering the code garden",
    "Rehearsing elevator pitch",
    "Searching for missing semicolons",
];

/// Spinner frames (braille patterns).
pub const SPINNER_FRAMES: &[&str] = &["◐", "◓", "◑", "◒"];

/// Spinner colors that rotate every 5 minutes.
pub const SPINNER_COLORS: &[Color] = &[
    Color::Cyan,
    Color::Green,
    Color::Yellow,
    Color::Magenta,
    Color::Red,
    Color::Blue,
];

impl App {
    pub fn new(mock_mode: bool) -> Self {
        let cwd = std::env::current_dir().unwrap_or_else(|_| PathBuf::from("."));
        let mut app = Self {
            phase: Phase::Idle,
            agent_state: AgentState::Idle,
            error_count: 0,
            started: Instant::now(),
            command_started: None,
            build_exit: None,
            test_exit: None,
            interaction: Vec::new(),
            screen: PtyScreen::new(40, 120),
            pane_layout: PaneLayout::Split,
            bottom_expanded: false,
            should_quit: false,
            tick_count: 0,
            show_help: false,
            mock_mode,
            input_buffer: String::new(),
            input_cursor: 0,
            current_provider: Some("moonshot".to_string()),
            current_model: Some("kimi-k2.7".to_string()),
            info_view: InfoView::Metrics,
            agents_dir: cwd.clone(),
            project: None,
            scheme: None,
            artifacts_dir: None,
            cwd: cwd.clone(),
            spawn_request: None,
            test_stage: None,
            test_resume_from: None,
            pending_chat: None,
            picker_open: false,
            picker_selected: 0,
            picker_filtered: Vec::new(),
            chat_messages: Vec::new(),
            chat_request: None,
            chat_rx: None,
            interaction_scroll: 0,
            focused_pane: FocusedPane::default(),
            pending_changes: Vec::new(),
            apply_phase: ApplyPhase::Idle,
            apply_build_exit: None,
            test_coverage: None,
            test_strategy: None,
            test_files: None,
            test_happy_only: false,
            pipeline_stages: PHASE5_STAGES.iter().map(|(k, l)| PipelineStage {
                key: k,
                label: l,
                status: StageStatus::Pending,
                duration: 0,
                coverage: 0,
            }).collect(),
            pipeline_run_dir: None,
            build_stages: BUILD_STAGES.iter().map(|(k, l)| PipelineStage {
                key: k,
                label: l,
                status: StageStatus::Pending,
                duration: 0,
                coverage: 0,
            }).collect(),
            build_run_dir: None,
            project_dir: cwd.clone(),
            active_agent: ActiveAgentKind::None,
            pipeline_state: None,
            pipeline_running: false,
            pipeline_phase5_step: None,
            pipeline_single_phase_target: None,
            dry_run: false,
        };

        if mock_mode {
            mock::seed_interaction(&mut app);
        }

        app
    }

    pub fn elapsed_secs(&self) -> u64 {
        self.started.elapsed().as_secs()
    }

    /// Recompute filtered commands based on current input buffer.
    fn refresh_picker(&mut self) {
        let filter = self.input_buffer.strip_prefix('/').unwrap_or("").to_lowercase();
        self.picker_filtered = SLASH_COMMANDS
            .iter()
            .enumerate()
            .filter(|(_, cmd)| {
                let name_lower = cmd.name.to_lowercase();
                let desc_lower = cmd.description.to_lowercase();
                name_lower.contains(&filter) || desc_lower.contains(&filter)
            })
            .map(|(i, _)| i)
            .collect();
        self.picker_selected = self.picker_selected.min(self.picker_filtered.len().saturating_sub(1));
    }

    /// Open the command picker if input starts with '/'.
    fn maybe_open_picker(&mut self) {
        if self.input_buffer.starts_with('/') && !self.input_buffer.contains(' ') {
            self.picker_open = true;
            self.refresh_picker();
        } else {
            self.picker_open = false;
        }
    }

    /// Accept the currently selected picker item.
    fn accept_picker(&mut self) {
        if let Some(&idx) = self.picker_filtered.get(self.picker_selected) {
            let cmd = &SLASH_COMMANDS[idx];
            if cmd.takes_arg {
                // Insert command with trailing space so user can type the argument
                self.input_buffer = format!("{} ", cmd.name);
                self.input_cursor = self.input_buffer.len();
                self.picker_open = false;
            } else {
                // Execute immediately
                let full_cmd = cmd.name.to_string();
                self.input_buffer.clear();
                self.input_cursor = 0;
                self.picker_open = false;
                self.handle_command(&full_cmd);
            }
        }
    }

    pub fn update(&mut self, action: Action) {
        match action {
            Action::Tick => {
                self.tick_count += 1;
                if self.mock_mode {
                    mock::update_mock(self);
                }
                match self.phase {
                    Phase::Build => self.refresh_build_pipeline_status(),
                    Phase::Test => self.refresh_pipeline_status(),
                    _ => {}
                }
            }
            Action::Tab => {
                if self.picker_open {
                    self.accept_picker();
                } else {
                    self.pane_layout = self.pane_layout.next();
                }
            }
            Action::ShiftTab => {
                self.bottom_expanded = !self.bottom_expanded;
            }
            Action::Skip => {
                self.interaction.push(InteractionMessage {
                    voice: Voice::User,
                    text: "Skip current phase".to_string(),
                });
                self.advance_phase_after_skip();
            }
            Action::Abort | Action::Quit => {
                self.should_quit = true;
                self.phase = Phase::Aborted;
            }
            Action::ToggleHelp => {
                self.show_help = !self.show_help;
            }
            Action::Confirm(true) => {
                if self.phase == Phase::Failed {
                    self.phase = Phase::Build;
                    self.build_exit = None;
                    self.agent_state = AgentState::Acting;
                    self.interaction.push(InteractionMessage {
                        voice: Voice::Agent,
                        text: "Re-running build...".to_string(),
                    });
                }
            }
            Action::Confirm(false) => {
                if self.phase == Phase::Failed {
                    self.should_quit = true;
                }
            }
            Action::ApplyChanges => {
                self.handle_apply_changes();
            }
            Action::DiscardChanges => {
                self.pending_changes.clear();
                self.apply_phase = ApplyPhase::Idle;
                self.interaction.push(InteractionMessage {
                    voice: Voice::Agent,
                    text: "Changes discarded.".to_string(),
                });
            }
            Action::Resize(cols, rows) => {
                let rows = rows as usize;
                let cols = cols as usize;
                if rows > 2 && cols > 10 {
                    let bottom_rows = if self.bottom_expanded { 4 } else { 2 };
                    let output_rows = rows.saturating_sub(bottom_rows);
                    let output_cols = match self.pane_layout {
                        PaneLayout::Split => cols / 2,
                        PaneLayout::OutputOnly => cols,
                        PaneLayout::InteractionOnly => cols,
                    };
                    self.screen.resize(output_rows.max(3), output_cols.max(10));
                }
            }
            Action::AgentBytes(bytes) => {
                self.screen.advance(&bytes);
                // Only show spinner if the agent is still running (hasn't exited yet).
                match self.phase {
                    Phase::Build if self.build_exit.is_none() => {
                        self.agent_state = AgentState::Acting;
                    }
                    Phase::Test if self.test_exit.is_none() => {
                        self.agent_state = AgentState::Acting;
                    }
                    _ => {}
                }
            }
            Action::AgentExited(code) => {
                match self.active_agent {
                    ActiveAgentKind::PipelinePhase(idx) => {
                        self.handle_pipeline_phase_exited(idx, code);
                        return;
                    }
                    ActiveAgentKind::Build if self.pipeline_phase5_step == Some(Phase5Step::Build) => {
                        self.handle_pipeline_build_exited(code);
                        return;
                    }
                    ActiveAgentKind::Test if self.pipeline_phase5_step == Some(Phase5Step::Test) => {
                        self.handle_pipeline_test_exited(code);
                        return;
                    }
                    _ => {}
                }
                self.active_agent = ActiveAgentKind::None;
                match self.phase {
                    Phase::Build => {
                        self.build_exit = Some(code);
                        self.agent_state = AgentState::Idle;
                        self.command_started = None;
                        self.refresh_build_pipeline_status();
                        if code == 0 {
                            let scope_msg = self.detect_build_scope();
                            self.interaction.push(InteractionMessage {
                                voice: Voice::Agent,
                                text: format!("Build passed. {}{}", scope_msg, " Type /test to run tests."),
                            });
                        } else if code == 10 {
                            self.phase = Phase::Failed;
                            self.error_count += 1;
                            self.interaction.push(InteractionMessage {
                                voice: Voice::Error,
                                text: format!("Build failed (exit {}). Type /build to retry.", code),
                            });
                        } else {
                            self.phase = Phase::Failed;
                            self.interaction.push(InteractionMessage {
                                voice: Voice::Error,
                                text: format!("Environment error (exit {}). Type /build to retry.", code),
                            });
                        }
                    }
                    Phase::Test => {
                        self.test_exit = Some(code);
                        self.agent_state = AgentState::Idle;
                        self.command_started = None;
                        self.refresh_pipeline_status();
                        if code == 0 {
                            self.phase = Phase::Complete;
                            self.interaction.push(InteractionMessage {
                                voice: Voice::Agent,
                                text: "All tests passed.".to_string(),
                            });
                        } else {
                            self.phase = Phase::Failed;
                            self.error_count += 1;
                            self.interaction.push(InteractionMessage {
                                voice: Voice::Error,
                                text: format!("Tests failed (exit {}). Type /test to retry.", code),
                            });
                        }
                    }
                    _ => {}
                }
            }
            Action::AgentError(msg) => {
                self.interaction.push(InteractionMessage {
                    voice: Voice::Error,
                    text: msg,
                });
            }
            Action::InputChar(c) => {
                self.input_buffer.insert(self.input_cursor, c);
                self.input_cursor += 1;
                self.maybe_open_picker();
            }
            Action::InputBackspace => {
                if self.input_cursor > 0 {
                    self.input_cursor -= 1;
                    self.input_buffer.remove(self.input_cursor);
                    self.maybe_open_picker();
                }
            }
            Action::InputCursorLeft => {
                if self.input_cursor > 0 {
                    self.input_cursor -= 1;
                }
            }
            Action::InputCursorRight => {
                if self.input_cursor < self.input_buffer.len() {
                    self.input_cursor += 1;
                }
            }
            Action::InputCancel => {
                self.input_buffer.clear();
                self.input_cursor = 0;
                self.picker_open = false;
            }
            Action::InputSubmit => {
                if self.picker_open {
                    self.accept_picker();
                } else {
                    let cmd = self.input_buffer.trim().to_string();
                    if !cmd.is_empty() {
                        self.handle_command(&cmd);
                    }
                    self.input_buffer.clear();
                    self.input_cursor = 0;
                }
                // Reset scroll when user submits input so they see the new content.
                self.interaction_scroll = 0;
            }
            Action::PickerUp => {
                if self.picker_open && self.picker_selected > 0 {
                    self.picker_selected -= 1;
                } else if !self.picker_open {
                    self.scroll_focused_pane(1);
                }
            }
            Action::PickerDown => {
                if self.picker_open && self.picker_selected + 1 < self.picker_filtered.len() {
                    self.picker_selected += 1;
                } else if !self.picker_open {
                    self.scroll_focused_pane(-1);
                }
            }
            Action::FocusLeft => {
                self.focused_pane = match self.pane_layout {
                    PaneLayout::Split => FocusedPane::Interaction,
                    PaneLayout::InteractionOnly => FocusedPane::Interaction,
                    PaneLayout::OutputOnly => FocusedPane::Output,
                };
            }
            Action::FocusRight => {
                self.focused_pane = match self.pane_layout {
                    PaneLayout::Split => FocusedPane::Output,
                    PaneLayout::InteractionOnly => FocusedPane::Interaction,
                    PaneLayout::OutputOnly => FocusedPane::Output,
                };
            }
            Action::ScrollUp => {
                self.interaction_scroll = self.interaction_scroll.saturating_sub(5);
            }
            Action::ScrollDown => {
                self.interaction_scroll += 5;
            }
            Action::OutputScrollUp => {
                self.screen.scroll_down(5);
            }
            Action::OutputScrollDown => {
                self.screen.scroll_up(5);
            }
        }
    }

    fn scroll_focused_pane(&mut self, delta: i16) {
        match self.focused_pane {
            FocusedPane::Interaction => {
                if delta > 0 {
                    self.interaction_scroll += delta as u16;
                } else {
                    self.interaction_scroll = self.interaction_scroll.saturating_sub((-delta) as u16);
                }
            }
            FocusedPane::Output => {
                if delta > 0 {
                    self.screen.scroll_up(delta as usize);
                } else {
                    self.screen.scroll_down((-delta) as usize);
                }
            }
        }
    }

    /// Detect files modified by the last build via `git diff` and write a
    /// `.build_scope.json` artifact. Returns a user-facing message.
    fn detect_build_scope(&mut self) -> String {
        let output = std::process::Command::new("git")
            .args(["diff", "--name-only", "HEAD"])
            .current_dir(&self.cwd)
            .output();

        match output {
            Ok(out) if out.status.success() => {
                let files: Vec<String> = String::from_utf8_lossy(&out.stdout)
                    .lines()
                    .map(|s| s.trim().to_string())
                    .filter(|s| {
                        !s.is_empty()
                        && !s.starts_with("Artifacts/")
                        && !s.starts_with(".git/")
                        && !s.starts_with("node_modules/")
                        && !s.starts_with("Pods/")
                        && !s.starts_with(".build/")
                        && !s.starts_with("DerivedData/")
                        && !s.contains(".DS_Store")
                        && !s.ends_with(".log")
                        && !s.ends_with(".tmp")
                        && !s.ends_with(".bak")
                    })
                    .collect();

                if files.is_empty() {
                    return "No modified files detected.".to_string();
                }

                // Write artifact for TestAgent to consume.
                let artifacts_dir = self.cwd.join("Artifacts");
                if let Ok(entries) = std::fs::read_dir(&artifacts_dir) {
                    // Find the most recent build_* directory.
                    let mut latest: Option<std::path::PathBuf> = None;
                    for entry in entries.flatten() {
                        let name = entry.file_name();
                        let name_str = name.to_string_lossy();
                        if name_str.starts_with("build_") && entry.file_type().map(|t| t.is_dir()).unwrap_or(false) {
                            latest = match latest {
                                None => Some(entry.path()),
                                Some(ref l) if entry.path() > *l => Some(entry.path()),
                                other => other,
                            };
                        }
                    }
                    if let Some(dir) = latest {
                        let scope_path = dir.join(".build_scope.json");
                        let json = format!(
                            "{{\"modified_files\":{:?},\"timestamp\":{}}}",
                            files,
                            std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap_or_default().as_secs()
                        );
                        let _ = std::fs::write(&scope_path, json);
                    }
                }

                // Auto-set file scope for next TestAgent run.
                let pattern = if files.len() == 1 {
                    files[0].clone()
                } else {
                    // Find longest common prefix across all files.
                    let mut prefix = files[0].clone();
                    for f in &files[1..] {
                        while !f.starts_with(&prefix) {
                            prefix.pop();
                            if prefix.is_empty() { break; }
                        }
                        if prefix.is_empty() { break; }
                    }
                    if let Some(idx) = prefix.rfind('/') {
                        format!("{}/*.swift", &prefix[..idx + 1])
                    } else {
                        files.join(",")
                    }
                };
                self.test_files = Some(pattern.clone());
                format!("Detected {} modified file(s). Scope auto-set to: {}", files.len(), pattern)
            }
            _ => "Could not detect modified files.".to_string(),
        }
    }

    /// Read the latest stages.json from the most recent test run and update
    /// the pipeline visualizer state.
    pub fn refresh_pipeline_status(&mut self) {
        use serde::Deserialize;

        #[derive(Deserialize, Default)]
        struct StageEntry {
            status: String,
            #[serde(default)]
            duration: u64,
            #[serde(default)]
            coverage: u8,
        }

        #[derive(Deserialize, Default)]
        struct StagesJson {
            #[serde(default)]
            stages: std::collections::HashMap<String, StageEntry>,
        }

        // Find the most recent test_* artifacts directory.
        let artifacts_dir = self.cwd.join("Artifacts");
        let latest = std::fs::read_dir(&artifacts_dir).ok().and_then(|entries| {
            entries
                .flatten()
                .filter(|e| {
                    e.file_name().to_string_lossy().starts_with("test_")
                        && e.file_type().map(|t| t.is_dir()).unwrap_or(false)
                })
                .max_by_key(|e| e.path())
                .map(|e| e.path())
        });

        let stages_file = latest.as_ref().map(|p| p.join("stages.json"));
        let json_str = stages_file.and_then(|p| std::fs::read_to_string(p).ok());

        let parsed: StagesJson = json_str
            .and_then(|s| serde_json::from_str(&s).ok())
            .unwrap_or_default();

        // First pass: apply statuses from parsed JSON.
        for stage in &mut self.pipeline_stages {
            if let Some(entry) = parsed.stages.get(stage.key) {
                stage.status = match entry.status.as_str() {
                    "running" => StageStatus::Running,
                    "completed" => StageStatus::Completed,
                    "failed" => StageStatus::Failed,
                    "skipped" => StageStatus::Skipped,
                    _ => StageStatus::Pending,
                };
                stage.duration = entry.duration;
                stage.coverage = entry.coverage;
            }
        }

        // Second pass: heuristic — if a stage is still Pending and all previous
        // stages are done, mark it Running.
        if self.phase == Phase::Test {
            for idx in 0..self.pipeline_stages.len() {
                if self.pipeline_stages[idx].status != StageStatus::Pending {
                    continue;
                }
                let prev_all_done = self.pipeline_stages[..idx].iter().all(|s| {
                    matches!(s.status, StageStatus::Completed | StageStatus::Skipped | StageStatus::Failed)
                });
                if prev_all_done {
                    self.pipeline_stages[idx].status = StageStatus::Running;
                }
            }
        }

        self.pipeline_run_dir = latest;
    }

    /// Reset all pipeline stages to Pending (called when a new test run starts).
    fn reset_pipeline_stages(&mut self) {
        for stage in &mut self.pipeline_stages {
            stage.status = StageStatus::Pending;
            stage.duration = 0;
            stage.coverage = 0;
        }
        self.pipeline_run_dir = None;
    }

    /// Read the latest build_stages.json from the most recent build run and update
    /// the build pipeline visualizer state.
    pub fn refresh_build_pipeline_status(&mut self) {
        use serde::Deserialize;

        #[derive(Deserialize, Default)]
        struct StageEntry {
            status: String,
            #[serde(default)]
            duration: u64,
            #[serde(default)]
            attempt: u8,
        }

        #[derive(Deserialize, Default)]
        struct StagesJson {
            #[serde(default)]
            stages: std::collections::HashMap<String, StageEntry>,
        }

        // Find the most recent build_* artifacts directory.
        let artifacts_dir = self.cwd.join("Artifacts");
        let latest = std::fs::read_dir(&artifacts_dir).ok().and_then(|entries| {
            entries
                .flatten()
                .filter(|e| {
                    e.file_name().to_string_lossy().starts_with("build_")
                        && e.file_type().map(|t| t.is_dir()).unwrap_or(false)
                })
                .max_by_key(|e| e.path())
                .map(|e| e.path())
        });

        let stages_file = latest.as_ref().map(|p| p.join("status").join("build_stages.json"));
        let json_str = stages_file.and_then(|p| std::fs::read_to_string(p).ok());

        let parsed: StagesJson = json_str
            .and_then(|s| serde_json::from_str(&s).ok())
            .unwrap_or_default();

        // Map of build stage order for heuristic completion.
        let _build_order: std::collections::HashMap<&str, usize> =
            BUILD_STAGES.iter().enumerate().map(|(i, (k, _))| (*k, i)).collect();

        for stage in &mut self.build_stages {
            if let Some(entry) = parsed.stages.get(stage.key) {
                stage.status = match entry.status.as_str() {
                    "running" => StageStatus::Running,
                    "completed" => StageStatus::Completed,
                    "failed" => StageStatus::Failed,
                    "skipped" => StageStatus::Skipped,
                    _ => StageStatus::Pending,
                };
                stage.duration = entry.duration;
                // Store attempt count in coverage field (repurposed for build).
                stage.coverage = entry.attempt;
            }
        }

        // Heuristic: if stage N is running/completed, all previous stages are completed.
        for idx in 0..self.build_stages.len() {
            if matches!(self.build_stages[idx].status, StageStatus::Running | StageStatus::Completed | StageStatus::Failed) {
                for prev in 0..idx {
                    if self.build_stages[prev].status == StageStatus::Pending {
                        self.build_stages[prev].status = StageStatus::Completed;
                    }
                }
            }
        }

        // Second heuristic: if we're in Build phase and the first stage is still
        // Pending, mark it Running (BuildAgent hasn't written the file yet).
        if self.phase == Phase::Build {
            for idx in 0..self.build_stages.len() {
                if self.build_stages[idx].status != StageStatus::Pending {
                    continue;
                }
                let prev_all_done = self.build_stages[..idx].iter().all(|s| {
                    matches!(s.status, StageStatus::Completed | StageStatus::Skipped | StageStatus::Failed)
                });
                if prev_all_done {
                    self.build_stages[idx].status = StageStatus::Running;
                }
            }
        }

        self.build_run_dir = latest;
    }

    /// Reset all build pipeline stages to Pending (called when a new build run starts).
    fn reset_build_stages(&mut self) {
        for stage in &mut self.build_stages {
            stage.status = StageStatus::Pending;
            stage.duration = 0;
            stage.coverage = 0;
        }
        self.build_run_dir = None;
    }

    fn advance_phase_after_skip(&mut self) {
        match self.phase {
            Phase::Build => {
                self.phase = Phase::Test;
                self.agent_state = AgentState::Thinking;
            }
            Phase::Test => {
                self.phase = Phase::Complete;
                self.agent_state = AgentState::Idle;
            }
            _ => {}
        }
    }

    fn handle_pipeline_phase_exited(&mut self, idx: usize, code: i32) {
        self.active_agent = ActiveAgentKind::None;
        self.agent_state = AgentState::Idle;
        self.command_started = None;

        let exit = map_exit_code(code);
        let result_path = find_latest_result_json(&self.project_dir, idx);
        let result = result_path
            .as_deref()
            .and_then(|p| parse_result_json(p).ok());

        if let Some(ref mut state) = self.pipeline_state {
            let (messages, stop) = apply_phase_outcome(
                state,
                idx,
                exit,
                result.as_ref(),
                result_path.as_deref(),
            );
            for msg in messages {
                self.interaction.push(InteractionMessage {
                    voice: if stop && exit != crate::pipeline_engine::AgentExitStatus::Success {
                        Voice::Error
                    } else {
                        Voice::Agent
                    },
                    text: msg,
                });
            }
            let _ = save_pipeline_state(&pipeline_state_path(&self.project_dir), state);
            if stop {
                self.pipeline_running = false;
            }
        }
    }

    fn handle_pipeline_build_exited(&mut self, code: i32) {
        self.agent_state = AgentState::Idle;
        self.command_started = None;
        if code == 0 {
            self.interaction.push(InteractionMessage {
                voice: Voice::Agent,
                text: "Pipeline phase 5: BuildAgent passed. Starting TestAgent...".to_string(),
            });
            self.pipeline_phase5_step = Some(Phase5Step::Test);
            self.active_agent = ActiveAgentKind::None;
            // Queue TestAgent spawn in the main loop, preserving pipeline context.
            self.spawn_request = Some(SpawnRequest::Test);
        } else {
            self.active_agent = ActiveAgentKind::None;
            self.pipeline_phase5_step = None;
            if let Some(ref mut state) = self.pipeline_state {
                let _ = apply_phase_outcome(
                    state,
                    5,
                    map_exit_code(code),
                    None,
                    None,
                );
                let _ = save_pipeline_state(&pipeline_state_path(&self.project_dir), state);
            }
            self.interaction.push(InteractionMessage {
                voice: Voice::Error,
                text: format!("Pipeline phase 5: BuildAgent failed (exit {}).", code),
            });
            self.pipeline_running = false;
        }
    }

    fn handle_pipeline_test_exited(&mut self, code: i32) {
        self.active_agent = ActiveAgentKind::None;
        self.agent_state = AgentState::Idle;
        self.command_started = None;
        self.pipeline_phase5_step = None;

        if let Some(ref mut state) = self.pipeline_state {
            let exit = map_exit_code(code);
            let result_path = find_latest_result_json(&self.project_dir, 5);
            let result = result_path
                .as_deref()
                .and_then(|p| parse_result_json(p).ok());
            let (messages, stop) = apply_phase_outcome(
                state,
                5,
                exit,
                result.as_ref(),
                result_path.as_deref(),
            );
            for msg in messages {
                self.interaction.push(InteractionMessage {
                    voice: if code != 0 { Voice::Error } else { Voice::Agent },
                    text: msg,
                });
            }
            let _ = save_pipeline_state(&pipeline_state_path(&self.project_dir), state);
            if stop {
                self.pipeline_running = false;
            }
        }
    }

    fn show_pipeline_status(&mut self) {
        if let Some(ref state) = self.pipeline_state {
            self.interaction.push(InteractionMessage {
                voice: Voice::Agent,
                text: format_status_summary(state),
            });
        } else {
            self.interaction.push(InteractionMessage {
                voice: Voice::Agent,
                text: "No pipeline state. Type /pipeline to start.".to_string(),
            });
        }
    }

    fn start_pipeline(&mut self) {
        if self.pipeline_running {
            self.interaction.push(InteractionMessage {
                voice: Voice::Warning,
                text: "Pipeline is already running.".to_string(),
            });
            return;
        }
        if self.active_agent != ActiveAgentKind::None {
            self.interaction.push(InteractionMessage {
                voice: Voice::Warning,
                text: "An agent is already running. Use /skip or wait for it to finish.".to_string(),
            });
            return;
        }
        if self.pipeline_state.is_none() {
            self.pipeline_state = Some(PipelineRunState::with_started_now());
        }
        self.pipeline_running = true;
        let state = self.pipeline_state.as_ref().unwrap();
        let resume = crate::pipeline_engine::resume_phase_index(state);
        self.interaction.push(InteractionMessage {
            voice: Voice::Agent,
            text: format!("Starting Foundation pipeline from phase {}...", resume),
        });
    }

    fn run_single_phase(&mut self, args: &[&str]) {
        if self.pipeline_running {
            self.interaction.push(InteractionMessage {
                voice: Voice::Warning,
                text: "Pipeline is running. Stop it first with /reject or wait for completion.".to_string(),
            });
            return;
        }
        if self.active_agent != ActiveAgentKind::None {
            self.interaction.push(InteractionMessage {
                voice: Voice::Warning,
                text: "An agent is already running.".to_string(),
            });
            return;
        }
        let (n_str, force) = match args {
            [n] => (*n, false),
            [n, "--force"] => (*n, true),
            _ => {
                self.interaction.push(InteractionMessage {
                    voice: Voice::Warning,
                    text: "Usage: /phase <n> [--force]".to_string(),
                });
                return;
            }
        };
        let Ok(n) = n_str.parse::<usize>() else {
            self.interaction.push(InteractionMessage {
                voice: Voice::Warning,
                text: format!("'{}' is not a valid phase number.", n_str),
            });
            return;
        };
        if n > 5 {
            self.interaction.push(InteractionMessage {
                voice: Voice::Warning,
                text: "Phase must be between 0 and 5.".to_string(),
            });
            return;
        }
        if self.pipeline_state.is_none() {
            self.pipeline_state = Some(PipelineRunState::with_started_now());
        }
        let state = self.pipeline_state.as_mut().unwrap();
        if !force {
            if let Err(e) = can_start_phase(state, n) {
                self.interaction.push(InteractionMessage {
                    voice: Voice::Warning,
                    text: e,
                });
                return;
            }
        }
        if let Err(e) = start_phase(state, n) {
            self.interaction.push(InteractionMessage {
                voice: Voice::Error,
                text: e,
            });
            return;
        }
        self.pipeline_single_phase_target = Some(n);
        self.interaction.push(InteractionMessage {
            voice: Voice::Agent,
            text: format!("Starting phase {}...", n),
        });
    }

    fn resolve_approval(&mut self, approve: bool) {
        let Some(ref mut state) = self.pipeline_state else {
            self.interaction.push(InteractionMessage {
                voice: Voice::Warning,
                text: "No pipeline is active.".to_string(),
            });
            return;
        };
        let Some(idx) = awaiting_approval_phase(state) else {
            self.interaction.push(InteractionMessage {
                voice: Voice::Warning,
                text: "No phase is awaiting approval.".to_string(),
            });
            return;
        };
        let result = if approve {
            approve_phase(state, idx)
        } else {
            reject_phase(state, idx)
        };
        match result {
            Ok(msg) => {
                let _ = save_pipeline_state(&pipeline_state_path(&self.project_dir), state);
                self.interaction.push(InteractionMessage {
                    voice: Voice::Agent,
                    text: msg,
                });
                if approve {
                    self.pipeline_running = true;
                }
            }
            Err(e) => {
                self.interaction.push(InteractionMessage {
                    voice: Voice::Warning,
                    text: e,
                });
            }
        }
    }

    fn skip_pipeline_phase(&mut self, n_str: &str) {
        let Ok(n) = n_str.parse::<usize>() else {
            self.interaction.push(InteractionMessage {
                voice: Voice::Warning,
                text: format!("'{}' is not a valid phase number.", n_str),
            });
            return;
        };
        if n > 5 {
            self.interaction.push(InteractionMessage {
                voice: Voice::Warning,
                text: "Phase must be between 0 and 5.".to_string(),
            });
            return;
        }
        if self.pipeline_state.is_none() {
            self.pipeline_state = Some(PipelineRunState::with_started_now());
        }
        let state = self.pipeline_state.as_mut().unwrap();
        match skip_phase(state, n) {
            Ok(msg) => {
                let _ = save_pipeline_state(&pipeline_state_path(&self.project_dir), state);
                self.interaction.push(InteractionMessage {
                    voice: Voice::Agent,
                    text: msg,
                });
            }
            Err(e) => {
                self.interaction.push(InteractionMessage {
                    voice: Voice::Warning,
                    text: e,
                });
            }
        }
    }

    fn handle_apply_changes(&mut self) {
        if self.pending_changes.is_empty() {
            self.apply_phase = ApplyPhase::Idle;
            return;
        }

        let paths: Vec<String> = self
            .pending_changes
            .iter()
            .map(|c| c.path.display().to_string())
            .collect();

        // Determine whether any applied file lives inside the orchestrator's own
        // src/ directory before we clear the pending list.
        let src_dir = self.cwd.join("src");
        let any_tui = self
            .pending_changes
            .iter()
            .any(|c| c.path.starts_with(&src_dir));

        match apply_changes(&self.pending_changes) {
            Ok(count) => {
                self.interaction.push(InteractionMessage {
                    voice: Voice::Agent,
                    text: format!("Applied {} change(s): {}", count, paths.join(", ")),
                });
                self.pending_changes.clear();

                if any_tui {
                    self.apply_phase = ApplyPhase::Building;
                    self.interaction.push(InteractionMessage {
                        voice: Voice::Agent,
                        text: "Changes affect the TUI. Building orch...".to_string(),
                    });
                } else {
                    self.apply_phase = ApplyPhase::Idle;
                }
            }
            Err(e) => {
                self.interaction.push(InteractionMessage {
                    voice: Voice::Error,
                    text: format!("Failed to apply changes: {}", e),
                });
                self.apply_phase = ApplyPhase::Idle;
                self.pending_changes.clear();
            }
        }
    }

    fn handle_command(&mut self, cmd: &str) {
        self.interaction.push(InteractionMessage {
            voice: Voice::User,
            text: format!("> {}", cmd),
        });

        // If we're prompting for change approval, only a few commands are valid.
        if self.apply_phase == ApplyPhase::Prompting {
            match cmd.trim().to_lowercase().as_str() {
                "y" | "yes" | "/yes" | "/y" | "/apply" => {
                    self.update(Action::ApplyChanges);
                    return;
                }
                "n" | "no" | "/no" | "/n" | "/discard" => {
                    self.update(Action::DiscardChanges);
                    return;
                }
                _ => {
                    self.interaction.push(InteractionMessage {
                        voice: Voice::Warning,
                        text: "Please respond with y/yes/apply or n/no/discard.".to_string(),
                    });
                    return;
                }
            }
        }

        // Parse as CLI-style flags first (--key value or --key=value)
        let mut parts = cmd.split_whitespace();
        let first = parts.next().unwrap_or("");

        if first.starts_with("--") {
            self.handle_cli_flag(first, &mut parts);
            return;
        }

        // Slash-commands for meta operations
        match first {
            "/provider" => {
                let provider = parts.next().unwrap_or("").to_string();
                if provider.is_empty() {
                    let current = self.current_provider.as_deref().unwrap_or("default");
                    let available: Vec<_> = PROVIDERS.iter().map(|(p, _)| *p).collect();
                    self.interaction.push(InteractionMessage {
                        voice: Voice::Agent,
                        text: format!("Current provider: {}. Available: {}", current, available.join(", ")),
                    });
                } else {
                    self.current_provider = Some(provider.clone());
                    // Set default model for the new provider.
                    self.current_model = PROVIDERS.iter()
                        .find(|(p, _)| p == &provider)
                        .and_then(|(_, models)| models.first().map(|m| m.to_string()));
                    let model_str = self.current_model.as_deref().unwrap_or("none");
                    self.interaction.push(InteractionMessage {
                        voice: Voice::Agent,
                        text: format!("Switched provider to: {} (model: {})", provider, model_str),
                    });
                }
            }
            "/model" => {
                let model = parts.next().unwrap_or("").to_string();
                if model.is_empty() {
                    let current = self.current_model.as_deref().unwrap_or("default");
                    let available = if let Some(ref prov) = self.current_provider {
                        PROVIDERS.iter()
                            .find(|(p, _)| p == prov)
                            .map(|(_, models)| models.join(", "))
                            .unwrap_or_else(|| "unknown provider".to_string())
                    } else {
                        let all: Vec<_> = PROVIDERS.iter()
                            .flat_map(|(_, models)| models.iter().map(|m| m.to_string()))
                            .collect();
                        all.join(", ")
                    };
                    self.interaction.push(InteractionMessage {
                        voice: Voice::Agent,
                        text: format!("Current model: {}. Available: {}", current, available),
                    });
                } else {
                    // Infer provider from model if possible.
                    let found_provider = PROVIDERS.iter().find_map(|(provider, models)| {
                        if models.contains(&model.as_str()) {
                            Some(*provider)
                        } else {
                            None
                        }
                    });
                    self.current_model = Some(model.clone());
                    if let Some(provider) = found_provider {
                        self.current_provider = Some(provider.to_string());
                        self.interaction.push(InteractionMessage {
                            voice: Voice::Agent,
                            text: format!("Switched model to: {} (provider: {})", model, provider),
                        });
                    } else {
                        self.interaction.push(InteractionMessage {
                            voice: Voice::Agent,
                            text: format!("Switched model to: {} (provider unchanged)", model),
                        });
                    }
                }
            }
            "/coverage" => {
                let val = parts.next().unwrap_or("");
                if val.is_empty() {
                    let current = self.test_coverage.map_or("auto".to_string(), |c| format!("{}%", c));
                    self.interaction.push(InteractionMessage {
                        voice: Voice::Agent,
                        text: format!("Current target coverage: {}. Usage: /coverage <percent>", current),
                    });
                } else if let Ok(n) = val.parse::<u8>() {
                    self.test_coverage = Some(n.min(100));
                    self.interaction.push(InteractionMessage {
                        voice: Voice::Agent,
                        text: format!("Target coverage set to {}%", n.min(100)),
                    });
                } else {
                    self.interaction.push(InteractionMessage {
                        voice: Voice::Warning,
                        text: "Invalid coverage value. Use: /coverage <percent>".to_string(),
                    });
                }
            }
            "/strategy" => {
                let val = parts.next().unwrap_or("").to_lowercase();
                if val.is_empty() {
                    let current = self.test_strategy.as_deref().unwrap_or("default");
                    self.interaction.push(InteractionMessage {
                        voice: Voice::Agent,
                        text: format!("Current strategy: {}. Options: priority, coverage, balanced, happy-only", current),
                    });
                } else if ["priority", "coverage", "balanced", "happy-only"].contains(&val.as_str()) {
                    self.test_strategy = Some(val.clone());
                    if val == "happy-only" {
                        self.test_happy_only = true;
                    } else {
                        self.test_happy_only = false;
                    }
                    self.interaction.push(InteractionMessage {
                        voice: Voice::Agent,
                        text: format!("Test strategy set to: {}", val),
                    });
                } else {
                    self.interaction.push(InteractionMessage {
                        voice: Voice::Warning,
                        text: "Invalid strategy. Options: priority, coverage, balanced, happy-only".to_string(),
                    });
                }
            }
            "/files" => {
                let val = parts.next().unwrap_or("").to_string();
                if val.is_empty() {
                    let current = self.test_files.as_deref().unwrap_or("all");
                    self.interaction.push(InteractionMessage {
                        voice: Voice::Agent,
                        text: format!("Current file scope: {}. Usage: /files <pattern>", current),
                    });
                } else {
                    self.test_files = Some(val.clone());
                    self.interaction.push(InteractionMessage {
                        voice: Voice::Agent,
                        text: format!("Test file scope set to: {}", val),
                    });
                }
            }
            "/happy-only" => {
                self.test_happy_only = !self.test_happy_only;
                if !self.test_happy_only && self.test_strategy.as_deref() == Some("happy-only") {
                    self.test_strategy = None;
                }
                let status = if self.test_happy_only { "enabled" } else { "disabled" };
                self.interaction.push(InteractionMessage {
                    voice: Voice::Agent,
                    text: format!("Happy-path-only mode {}", status),
                });
            }
            "/skip" => {
                self.interaction.push(InteractionMessage {
                    voice: Voice::Agent,
                    text: "Skipping current phase...".to_string(),
                });
                self.advance_phase_after_skip();
            }
            "/pipeline" => {
                let rest: Vec<&str> = parts.collect();
                if rest.first() == Some(&"status") {
                    self.show_pipeline_status();
                } else {
                    self.start_pipeline();
                }
            }
            "/phase" => {
                let rest: Vec<&str> = parts.collect();
                self.run_single_phase(&rest);
            }
            "/approve" => {
                self.resolve_approval(true);
            }
            "/reject" => {
                self.resolve_approval(false);
            }
            "/skip-phase" => {
                let n = parts.next().unwrap_or("");
                self.skip_pipeline_phase(n);
            }
            "/quit" | "/q" => {
                self.should_quit = true;
                self.phase = Phase::Aborted;
            }
            "/yes" | "/y" => {
                if self.phase == Phase::Failed {
                    self.phase = Phase::Build;
                    self.build_exit = None;
                    self.agent_state = AgentState::Acting;
                    self.interaction.push(InteractionMessage {
                        voice: Voice::Agent,
                        text: "Re-running build...".to_string(),
                    });
                }
            }
            "/no" | "/n" => {
                self.should_quit = true;
            }
            "/apply" => {
                if self.pending_changes.is_empty() {
                    self.interaction.push(InteractionMessage {
                        voice: Voice::Warning,
                        text: "No pending changes to apply.".to_string(),
                    });
                } else {
                    self.update(Action::ApplyChanges);
                }
            }
            "/discard" => {
                if self.pending_changes.is_empty() {
                    self.interaction.push(InteractionMessage {
                        voice: Voice::Warning,
                        text: "No pending changes to discard.".to_string(),
                    });
                } else {
                    self.update(Action::DiscardChanges);
                }
            }
            "/help" => {
                self.interaction.push(InteractionMessage {
                    voice: Voice::Agent,
                    text: "Available commands:\n  /build          — start BuildAgent\n  /test           — start TestAgent\n  /test-from <s>  — start TestAgent from stage\n  /test-stage <s> — run a single TestAgent stage\n  /pipeline       — run full Foundation pipeline 0→5\n  /pipeline status— show pipeline status\n  /phase <n>      — run a single pipeline phase (optionally --force)\n  /approve        — approve an awaiting-approval gate\n  /reject         — reject an awaiting-approval gate\n  /skip-phase <n> — skip a pipeline phase\n  /provider <p>   — switch AI provider\n  /model <m>      — switch AI model\n  /coverage <n>   — set target coverage %\n  /strategy <s>   — set test strategy (priority|coverage|balanced|happy-only)\n  /files <p>      — set test file scope pattern\n  /happy-only     — toggle happy-path-only mode\n  /skip           — skip current phase\n  /apply          — apply pending AI-suggested changes\n  /discard        — discard pending AI-suggested changes\n  /quit           — exit orchestrator\n  /yes            — confirm re-run\n  /no             — abort\n  --project <p>   — set project\n  --scheme <s>    — set scheme\n  --yolo          — enable yolo mode\n  --verbose       — toggle verbose\n  /help           — show this message\n  /status         — show current status\n\n  Providers: anthropic (default, Claude Fable 5), moonshot, openai, codex, cursor, google, ollama, openrouter".to_string(),
                });
            }
            "/artifacts" => {
                self.info_view = InfoView::Artifacts;
                if !self.bottom_expanded {
                    self.bottom_expanded = true;
                }
                self.interaction.push(InteractionMessage {
                    voice: Voice::Agent,
                    text: "Switched info panel to Artifacts view".to_string(),
                });
            }
            "/metrics" => {
                self.info_view = InfoView::Metrics;
                self.interaction.push(InteractionMessage {
                    voice: Voice::Agent,
                    text: "Switched info panel to Metrics view".to_string(),
                });
            }
            "/info" => {
                self.info_view = match self.info_view {
                    InfoView::Metrics => InfoView::Artifacts,
                    InfoView::Artifacts => InfoView::Metrics,
                };
                if !self.bottom_expanded {
                    self.bottom_expanded = true;
                }
                let view_name = format!("{:?}", self.info_view).to_lowercase();
                self.interaction.push(InteractionMessage {
                    voice: Voice::Agent,
                    text: format!("Switched info panel to {} view", view_name),
                });
            }
            "/build" => {
                if self.phase == Phase::Build || self.phase == Phase::Test {
                    self.interaction.push(InteractionMessage {
                        voice: Voice::Agent,
                        text: "Already running. Use /skip to cancel.".to_string(),
                    });
                } else {
                    self.reset_build_stages();
                    self.spawn_request = Some(SpawnRequest::Build);
                    self.phase = Phase::Build;
                    self.agent_state = AgentState::Acting;
                    self.build_exit = None;
                    self.command_started = Some(Instant::now());
                    self.interaction.push(InteractionMessage {
                        voice: Voice::Agent,
                        text: "Starting BuildAgent...".to_string(),
                    });
                }
            }
            "/test" => {
                if self.phase == Phase::Build || self.phase == Phase::Test {
                    self.interaction.push(InteractionMessage {
                        voice: Voice::Agent,
                        text: "Already running. Use /skip to cancel.".to_string(),
                    });
                } else {
                    self.reset_pipeline_stages();
                    self.test_stage = None;
                    self.test_resume_from = None;
                    self.spawn_request = Some(SpawnRequest::Test);
                    self.phase = Phase::Test;
                    self.agent_state = AgentState::Acting;
                    self.test_exit = None;
                    self.command_started = Some(Instant::now());
                    self.interaction.push(InteractionMessage {
                        voice: Voice::Agent,
                        text: "Starting TestAgent...".to_string(),
                    });
                }
            }
            "/test-from" => {
                let stage = parts.next().unwrap_or("").to_string();
                if stage.is_empty() {
                    self.interaction.push(InteractionMessage {
                        voice: Voice::Agent,
                        text: "Usage: /test-from <stage>".to_string(),
                    });
                } else if self.phase == Phase::Build || self.phase == Phase::Test {
                    self.interaction.push(InteractionMessage {
                        voice: Voice::Agent,
                        text: "Already running. Use /skip to cancel.".to_string(),
                    });
                } else {
                    self.reset_pipeline_stages();
                    self.test_stage = None;
                    self.test_resume_from = Some(stage.clone());
                    self.spawn_request = Some(SpawnRequest::Test);
                    self.phase = Phase::Test;
                    self.agent_state = AgentState::Acting;
                    self.test_exit = None;
                    self.interaction.push(InteractionMessage {
                        voice: Voice::Agent,
                        text: format!("Starting TestAgent from stage '{}'...", stage),
                    });
                }
            }
            "/test-stage" => {
                let stage = parts.next().unwrap_or("").to_string();
                if stage.is_empty() {
                    self.interaction.push(InteractionMessage {
                        voice: Voice::Agent,
                        text: "Usage: /test-stage <stage>".to_string(),
                    });
                } else if self.phase == Phase::Build || self.phase == Phase::Test {
                    self.interaction.push(InteractionMessage {
                        voice: Voice::Agent,
                        text: "Already running. Use /skip to cancel.".to_string(),
                    });
                } else {
                    self.reset_pipeline_stages();
                    self.test_stage = Some(stage.clone());
                    self.test_resume_from = None;
                    self.spawn_request = Some(SpawnRequest::Test);
                    self.phase = Phase::Test;
                    self.agent_state = AgentState::Acting;
                    self.test_exit = None;
                    self.interaction.push(InteractionMessage {
                        voice: Voice::Agent,
                        text: format!("Starting TestAgent stage '{}'...", stage),
                    });
                }
            }
            "/status" => {
                let phase = format!("{:?}", self.phase);
                let coverage = self.test_coverage.map_or("auto".to_string(), |c| format!("{}%", c));
                let strategy = self.test_strategy.as_deref().unwrap_or("default");
                let files = self.test_files.as_deref().unwrap_or("all");
                let happy = if self.test_happy_only { "yes" } else { "no" };
                self.interaction.push(InteractionMessage {
                    voice: Voice::Agent,
                    text: format!("Phase: {} | Errors: {} | Provider: {:?} | Model: {:?} | Layout: {:?}\nTest scope — Coverage: {} | Strategy: {} | Files: {} | Happy-only: {}", phase, self.error_count, self.current_provider, self.current_model, self.pane_layout, coverage, strategy, files, happy),
                });
            }
            "y" | "yes" => {
                if self.phase == Phase::Failed {
                    self.phase = Phase::Build;
                    self.build_exit = None;
                    self.agent_state = AgentState::Acting;
                    self.interaction.push(InteractionMessage {
                        voice: Voice::Agent,
                        text: "Re-running build...".to_string(),
                    });
                } else {
                    self.interaction.push(InteractionMessage {
                        voice: Voice::Agent,
                        text: "Type /help for available commands.".to_string(),
                    });
                }
            }
            "n" | "no" => {
                self.should_quit = true;
            }
            _ => {
                if cmd.starts_with('/') {
                    self.interaction.push(InteractionMessage {
                        voice: Voice::Agent,
                        text: format!("Unknown command: {}. Type /help for available commands.", cmd),
                    });
                    return;
                }

                // If a build/test agent is running, queue for PTY stdin
                if self.phase == Phase::Build || self.phase == Phase::Test {
                    self.pending_chat = Some(cmd.to_string());
                    self.interaction.push(InteractionMessage {
                        voice: Voice::Agent,
                        text: "Message queued for agent.".to_string(),
                    });
                    return;
                }

                // Otherwise route to the selected AI model
                let provider = self.current_provider.clone().unwrap_or_default();
                let model = self.current_model.clone().unwrap_or_default();

                if provider.is_empty() || model.is_empty() {
                    self.interaction.push(InteractionMessage {
                        voice: Voice::Error,
                        text: "No provider/model selected. Use /provider and /model first.".to_string(),
                    });
                    return;
                }

                // Seed system prompt on first chat message
                if self.chat_messages.is_empty() {
                    let system = build_system_prompt(
                        &provider,
                        &model,
                        &self.agents_dir,
                        &self.cwd,
                    );
                    self.chat_messages.push(ChatMessage {
                        role: "system".to_string(),
                        content: system,
                    });
                }

                self.chat_messages.push(ChatMessage {
                    role: "user".to_string(),
                    content: cmd.to_string(),
                });

                // Extract the system prompt for providers that support a dedicated flag.
                let system_prompt = self
                    .chat_messages
                    .iter()
                    .find(|m| m.role == "system")
                    .map(|m| m.content.clone());

                self.chat_request = Some(ChatRequest {
                    provider,
                    model,
                    messages: self.chat_messages.clone(),
                    system_prompt,
                });
                self.agent_state = AgentState::Thinking;
                self.interaction.push(InteractionMessage {
                    voice: Voice::Agent,
                    text: "Thinking...".to_string(),
                });
            }
        }
    }

    fn handle_cli_flag<'a>(&mut self, flag: &str, parts: &mut std::str::SplitWhitespace<'a>) {
        match flag {
            "--project" => {
                if let Some(val) = parts.next() {
                    self.interaction.push(InteractionMessage {
                        voice: Voice::Agent,
                        text: format!("Project set to: {}", val),
                    });
                }
            }
            "--scheme" => {
                if let Some(val) = parts.next() {
                    self.interaction.push(InteractionMessage {
                        voice: Voice::Agent,
                        text: format!("Scheme set to: {}", val),
                    });
                }
            }
            "--ai-provider" | "--provider" => {
                if let Some(val) = parts.next() {
                    self.current_provider = Some(val.to_string());
                    self.current_model = None;
                    self.interaction.push(InteractionMessage {
                        voice: Voice::Agent,
                        text: format!("Provider set to: {}", val),
                    });
                }
            }
            "--model" => {
                if let Some(val) = parts.next() {
                    self.current_model = Some(val.to_string());
                    self.interaction.push(InteractionMessage {
                        voice: Voice::Agent,
                        text: format!("Model set to: {}", val),
                    });
                }
            }
            "--simulator-name" => {
                if let Some(val) = parts.next() {
                    self.interaction.push(InteractionMessage {
                        voice: Voice::Agent,
                        text: format!("Simulator set to: {}", val),
                    });
                }
            }
            "--stage" => {
                if let Some(val) = parts.next() {
                    self.test_stage = Some(val.to_string());
                    self.test_resume_from = None;
                    self.interaction.push(InteractionMessage {
                        voice: Voice::Agent,
                        text: format!("Stage set to: {}", val),
                    });
                }
            }
            "--resume-from" => {
                if let Some(val) = parts.next() {
                    self.test_resume_from = Some(val.to_string());
                    self.test_stage = None;
                    self.interaction.push(InteractionMessage {
                        voice: Voice::Agent,
                        text: format!("Resume-from set to: {}", val),
                    });
                }
            }
            "--max-attempts" => {
                if let Some(val) = parts.next() {
                    self.interaction.push(InteractionMessage {
                        voice: Voice::Agent,
                        text: format!("Max attempts set to: {}", val),
                    });
                }
            }
            "--yolo" => {
                self.interaction.push(InteractionMessage {
                    voice: Voice::Agent,
                    text: "Yolo mode enabled".to_string(),
                });
            }
            "--verbose" => {
                self.interaction.push(InteractionMessage {
                    voice: Voice::Agent,
                    text: "Verbose mode toggled".to_string(),
                });
            }
            "--dry-run" => {
                self.dry_run = !self.dry_run;
                let status = if self.dry_run { "enabled" } else { "disabled" };
                self.interaction.push(InteractionMessage {
                    voice: Voice::Agent,
                    text: format!("Dry-run mode {}", status),
                });
            }
            _ => {
                self.interaction.push(InteractionMessage {
                    voice: Voice::Agent,
                    text: format!("Unknown flag: {}. Type /help for available commands.", flag),
                });
            }
        }
    }
}
