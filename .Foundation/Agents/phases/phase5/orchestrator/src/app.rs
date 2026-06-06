use std::path::PathBuf;
use std::sync::mpsc::Receiver;
use std::time::Instant;

use ratatui::style::Color;

use crate::action::Action;
use crate::chat::{build_system_prompt, ChatMessage, ChatRequest};
use crate::mock;
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

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum InfoView {
    Metrics,
    Artifacts,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SpawnRequest {
    Build,
    Test,
}

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
    SlashCommand { name: "/provider", description: "Switch AI provider", takes_arg: true, arg_hint: "<provider>" },
    SlashCommand { name: "/model", description: "Switch AI model", takes_arg: true, arg_hint: "<model>" },
    SlashCommand { name: "/skip", description: "Skip current phase", takes_arg: false, arg_hint: "" },
    SlashCommand { name: "/status", description: "Show current status", takes_arg: false, arg_hint: "" },
    SlashCommand { name: "/info", description: "Toggle info panel view", takes_arg: false, arg_hint: "" },
    SlashCommand { name: "/metrics", description: "Show metrics view", takes_arg: false, arg_hint: "" },
    SlashCommand { name: "/artifacts", description: "Show artifacts view", takes_arg: false, arg_hint: "" },
    SlashCommand { name: "/help", description: "Show available commands", takes_arg: false, arg_hint: "" },
    SlashCommand { name: "/quit", description: "Exit orchestrator", takes_arg: false, arg_hint: "" },
];

/// Available AI providers and their models.
pub const PROVIDERS: &[(&str, &[&str])] = &[
    ("moonshot", &["kimi-k2.6"]),
    ("openai", &["gpt-4o", "gpt-4o-mini", "gpt-4-turbo", "o1-preview", "o1-mini"]),
    ("codex", &["o3", "o4-mini", "gpt-5.5"]),
    ("cursor", &["cursor-small", "cursor-large"]),
    ("anthropic", &["claude-sonnet-4", "claude-opus-4", "claude-sonnet-3-5", "claude-haiku-3-5"]),
    ("google", &["gemini-2.5-pro", "gemini-2.5-flash", "gemini-2.0-flash"]),
    ("ollama", &["llama3", "llama3.1", "mistral", "codellama", "qwen2.5"]),
    ("openrouter", &["auto", "openai/gpt-4o", "anthropic/claude-sonnet-4", "google/gemini-2.5-pro"]),
];

pub struct App {
    pub phase: Phase,
    pub agent_state: AgentState,
    pub error_count: u32,
    pub started: Instant,
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
            current_model: Some("kimi-k2.6".to_string()),
            info_view: InfoView::Metrics,
            agents_dir: cwd.clone(),
            project: None,
            scheme: None,
            artifacts_dir: None,
            cwd,
            spawn_request: None,
            pending_chat: None,
            picker_open: false,
            picker_selected: 0,
            picker_filtered: Vec::new(),
            chat_messages: Vec::new(),
            chat_request: None,
            chat_rx: None,
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
                match self.phase {
                    Phase::Build => {
                        self.build_exit = Some(code);
                        self.agent_state = AgentState::Idle;
                        if code == 0 {
                            self.interaction.push(InteractionMessage {
                                voice: Voice::Agent,
                                text: "Build passed. Type /test to run tests.".to_string(),
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
            }
            Action::PickerUp => {
                if self.picker_open && self.picker_selected > 0 {
                    self.picker_selected -= 1;
                }
            }
            Action::PickerDown => {
                if self.picker_open && self.picker_selected + 1 < self.picker_filtered.len() {
                    self.picker_selected += 1;
                }
            }
        }
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

    fn handle_command(&mut self, cmd: &str) {
        self.interaction.push(InteractionMessage {
            voice: Voice::User,
            text: format!("> {}", cmd),
        });

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
            "/skip" => {
                self.interaction.push(InteractionMessage {
                    voice: Voice::Agent,
                    text: "Skipping current phase...".to_string(),
                });
                self.advance_phase_after_skip();
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
            "/help" => {
                self.interaction.push(InteractionMessage {
                    voice: Voice::Agent,
                    text: "Available commands:\n  /build          — start BuildAgent\n  /test           — start TestAgent\n  /provider <p>   — switch AI provider\n  /model <m>      — switch AI model\n  /skip           — skip current phase\n  /quit           — exit orchestrator\n  /yes            — confirm re-run\n  /no             — abort\n  --project <p>   — set project\n  --scheme <s>    — set scheme\n  --yolo          — enable yolo mode\n  --verbose       — toggle verbose\n  /help           — show this message\n  /status         — show current status\n\n  Providers: moonshot, openai, codex, cursor, anthropic, google, ollama, openrouter".to_string(),
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
                    self.spawn_request = Some(SpawnRequest::Build);
                    self.phase = Phase::Build;
                    self.agent_state = AgentState::Acting;
                    self.build_exit = None;
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
                    self.spawn_request = Some(SpawnRequest::Test);
                    self.phase = Phase::Test;
                    self.agent_state = AgentState::Acting;
                    self.test_exit = None;
                    self.interaction.push(InteractionMessage {
                        voice: Voice::Agent,
                        text: "Starting TestAgent...".to_string(),
                    });
                }
            }
            "/status" => {
                let phase = format!("{:?}", self.phase);
                self.interaction.push(InteractionMessage {
                    voice: Voice::Agent,
                    text: format!("Phase: {} | Errors: {} | Provider: {:?} | Model: {:?} | Layout: {:?}", phase, self.error_count, self.current_provider, self.current_model, self.pane_layout),
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

                self.chat_request = Some(ChatRequest {
                    provider,
                    model,
                    messages: self.chat_messages.clone(),
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
                    self.interaction.push(InteractionMessage {
                        voice: Voice::Agent,
                        text: format!("Stage set to: {}", val),
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
                self.interaction.push(InteractionMessage {
                    voice: Voice::Agent,
                    text: "Dry-run mode enabled".to_string(),
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
