pub mod action;
pub mod agents;
pub mod app;
pub mod chat;
pub mod detect;
pub mod event;
pub mod mock;
pub mod pty_screen;
pub mod startup;
pub mod tui;
pub mod ui;

use std::io::Write;
use std::path::{Path, PathBuf};

use color_eyre::{eyre::WrapErr, Result};
use portable_pty::{MasterPty, PtySize};

use crate::action::Action;
use crate::agents::runner::{kill_child, spawn, RunnerMsg};
use crate::agents::{build_agent, test_agent};
use crate::app::{App, AgentState, PaneLayout, Phase, SpawnRequest};
use crate::event::EventHandler;
use crate::tui::init_terminal;
use crate::ui::layout;

/// Runtime configuration built from CLI arguments.
#[derive(Debug, Clone)]
pub struct Config {
    pub mock: bool,
    pub project: Option<String>,
    pub scheme: Option<String>,
    pub ai_provider: Option<String>,
    pub model: Option<String>,
    pub max_attempts: Option<u32>,
    pub simulator_name: Option<String>,
    pub stage: Option<String>,
    pub verbose: bool,
    pub dry_run: bool,
    pub agents_dir: PathBuf,
    pub artifacts_dir: Option<PathBuf>,
}

impl Config {
    pub fn build(args: CliArgs) -> Result<Self> {
        let cwd = std::env::current_dir().unwrap_or_else(|_| PathBuf::from("."));

        // Auto-detect agents directory if not provided.
        let agents_dir = if let Some(dir) = args.agents_dir {
            PathBuf::from(dir)
        } else {
            detect::find_agents_dir(&cwd)
        };
        if !agents_dir.exists() {
            return Err(color_eyre::eyre::eyre!(
                "agents-dir does not exist: {:?}",
                agents_dir
            ));
        }

        // Auto-detect Xcode project/workspace if not provided.
        let (project, scheme) = match (args.project, args.scheme) {
            (Some(p), Some(s)) => (Some(p), Some(s)),
            (Some(p), None) => {
                let is_ws = p.ends_with(".xcworkspace");
                let detected =
                    detect::detect_scheme(Path::new(&p), is_ws).unwrap_or(None);
                (Some(p), detected)
            }
            (None, Some(s)) => {
                // Scheme provided but no project — try to find project.
                if let Some((path, is_ws)) = detect::find_xcode_project(&cwd) {
                    let _ = detect::detect_scheme(&path, is_ws);
                    (Some(path.to_string_lossy().into_owned()), Some(s))
                } else {
                    (None, Some(s))
                }
            }
            (None, None) => {
                if let Some((path, is_ws)) = detect::find_xcode_project(&cwd) {
                    let detected =
                        detect::detect_scheme(&path, is_ws).unwrap_or(None);
                    let path_str = path.to_string_lossy().into_owned();
                    (Some(path_str), detected)
                } else {
                    (None, None)
                }
            }
        };

        let artifacts_dir = args.artifacts_dir.map(PathBuf::from);

        Ok(Self {
            mock: args.mock,
            project,
            scheme,
            ai_provider: args.ai_provider,
            model: args.model,
            max_attempts: args.max_attempts,
            simulator_name: args.simulator_name,
            stage: args.stage,
            verbose: args.verbose,
            dry_run: args.dry_run,
            agents_dir,
            artifacts_dir,
        })
    }
}

/// Clap-derived CLI arguments.
/// Kept in lib so tests can construct Config programmatically.
#[derive(Debug, Clone, clap::Parser)]
#[command(name = "orch")]
#[command(about = "Rust TUI orchestrator for Foundation build pipeline")]
pub struct CliArgs {
    /// Run in mock mode with synthetic output (no subprocesses).
    #[arg(long)]
    pub mock: bool,

    /// Xcode project path.
    #[arg(long)]
    pub project: Option<String>,

    /// Xcode scheme name.
    #[arg(long)]
    pub scheme: Option<String>,

    /// AI provider name.
    #[arg(long)]
    pub ai_provider: Option<String>,

    /// AI model name.
    #[arg(long)]
    pub model: Option<String>,

    /// Maximum build attempts.
    #[arg(long)]
    pub max_attempts: Option<u32>,

    /// iOS simulator name.
    #[arg(long)]
    pub simulator_name: Option<String>,

    /// Test stage name.
    #[arg(long)]
    pub stage: Option<String>,

    /// Verbose output.
    #[arg(long)]
    pub verbose: bool,

    /// Dry run (do not execute agents).
    #[arg(long)]
    pub dry_run: bool,

    /// Directory containing BuildAgent.sh and testAgent.sh.
    #[arg(long)]
    pub agents_dir: Option<String>,

    /// Artifacts output directory.
    #[arg(long)]
    pub artifacts_dir: Option<String>,
}

/// Build a `PtySize` from terminal dimensions and current pane layout.
/// All values are derived from the live terminal; nothing is hardcoded.
fn pty_size(term_cols: u16, term_rows: u16, pane_layout: PaneLayout, bottom_expanded: bool) -> PtySize {
    let (rows, cols) = layout::output_inner_size(term_cols, term_rows, pane_layout, bottom_expanded);
    PtySize {
        rows,
        cols,
        pixel_width: 0,
        pixel_height: 0,
    }
}

/// Resize the virtual screen and (if present) the live PTY to match the
/// output pane for the current terminal size and pane layout.
/// In mock mode the screen is NOT resized — clearing it would wipe content
/// that the mock generator repopulates too slowly.
fn sync_pty_size(
    app: &mut App,
    master: &Option<Box<dyn MasterPty + Send>>,
    term_cols: u16,
    term_rows: u16,
) {
    let size = pty_size(term_cols, term_rows, app.pane_layout, app.bottom_expanded);
    if app.mock_mode {
        // Mock mode: only resize the screen if the terminal itself grew, so
        // we don't lose content on pane-layout toggles.
        let (old_rows, old_cols) = app.screen.dims();
        let new_rows = size.rows as usize;
        let new_cols = size.cols as usize;
        if new_rows > old_rows || new_cols > old_cols {
            app.screen.resize(new_rows.max(old_rows), new_cols.max(old_cols));
        }
        return;
    }
    if app.screen.dims() != (size.rows as usize, size.cols as usize) {
        app.screen.resize(size.rows as usize, size.cols as usize);
        if let Some(m) = master {
            let _ = m.resize(size);
        }
    }
}

/// Main entry point: owns the terminal lifecycle and event loop.
pub fn run(config: Config) -> Result<()> {
    let mut guard = init_terminal().wrap_err("failed to initialize terminal")?;

    // Run startup animation before entering the main loop.
    startup::run_startup(|draw_callback| {
        let _ = guard.terminal().draw(|frame| {
            draw_callback(frame);
        });
    });

    let mut app = App::new(config.mock);
    app.agents_dir = config.agents_dir.clone();
    app.project = config.project.clone();
    app.scheme = config.scheme.clone();
    if let Some(provider) = config.ai_provider.clone() {
        app.current_provider = Some(provider);
    }
    if let Some(model) = config.model.clone() {
        app.current_model = Some(model);
    }
    app.artifacts_dir = config.artifacts_dir.clone();

    if !config.mock {
        app.interaction.push(crate::app::InteractionMessage {
            voice: crate::ui::theme::Voice::Agent,
            text: "Welcome to Foundation Orchestrator!\nType /build to start a build, /test to run tests, or /help for more commands.".to_string(),
        });
    }

    let mut child_opt: Option<Box<dyn portable_pty::Child + Send>> = None;
    let mut master_opt: Option<Box<dyn MasterPty + Send>> = None;
    let mut writer_opt: Option<Box<dyn Write + Send>> = None;

    // Initial terminal size, kept in sync via Resize events.
    let (mut term_cols, mut term_rows) =
        crossterm::terminal::size().unwrap_or((80, 24));

    // Size the virtual screen to the real terminal before the first frame.
    sync_pty_size(&mut app, &master_opt, term_cols, term_rows);

    // Dummy channel for mock mode (closed, so try_recv always errs -> Tick).
    let (_, dummy_rx) = std::sync::mpsc::channel::<RunnerMsg>();
    let mut event_handler = EventHandler::new(dummy_rx, 50);

    while !app.should_quit {
        guard.terminal().draw(|frame| ui::render(frame, &app))?;

        let action = event_handler.next();

        // Track terminal size changes.
        if let Action::Resize(cols, rows) = action {
            term_cols = cols;
            term_rows = rows;
        }

        // Handle quit/abort by cleaning up child.
        if matches!(action, Action::Quit | Action::Abort) {
            if let Some(ref mut c) = child_opt {
                let _ = kill_child(c);
            }
        }

        // Handle skip by cleaning up child.
        if action == Action::Skip {
            if let Some(ref mut c) = child_opt {
                let _ = kill_child(c);
                child_opt = None;
                master_opt = None;
                writer_opt = None;
            }
        }

        app.update(action);

        // Keep the PTY + screen sized to the output pane (covers terminal
        // resizes and pane-visibility toggles).
        sync_pty_size(&mut app, &master_opt, term_cols, term_rows);

        // Handle spawn requests from slash-commands (/build, /test).
        if !config.mock && child_opt.is_none() {
            match app.spawn_request.take() {
                Some(SpawnRequest::Build) => {
                    let cmd = build_agent::build_agent_cmd(
                        &config.agents_dir,
                        app.project.as_deref(),
                        app.scheme.as_deref(),
                        app.current_provider.as_deref(),
                        app.current_model.as_deref(),
                        config.max_attempts,
                        config.verbose,
                        config.dry_run,
                    );
                    match spawn(cmd, pty_size(term_cols, term_rows, app.pane_layout, app.bottom_expanded)) {
                        Ok((c, m, w, rx)) => {
                            child_opt = Some(c);
                            master_opt = Some(m);
                            writer_opt = Some(w);
                            event_handler.replace_rx(rx);
                        }
                        Err(e) => {
                            app.interaction.push(crate::app::InteractionMessage {
                                voice: crate::ui::theme::Voice::Error,
                                text: format!("Failed to spawn BuildAgent: {}", e),
                            });
                            app.phase = Phase::Failed;
                            app.agent_state = AgentState::Idle;
                        }
                    }
                }
                Some(SpawnRequest::Test) => {
                    let cmd = test_agent::test_agent_cmd(
                        &config.agents_dir,
                        app.project.as_deref(),
                        app.scheme.as_deref(),
                        app.current_provider.as_deref(),
                        app.current_model.as_deref(),
                        config.simulator_name.as_deref(),
                        config.stage.as_deref(),
                        config.verbose,
                        config.dry_run,
                    );
                    match spawn(cmd, pty_size(term_cols, term_rows, app.pane_layout, app.bottom_expanded)) {
                        Ok((c, m, w, rx)) => {
                            child_opt = Some(c);
                            master_opt = Some(m);
                            writer_opt = Some(w);
                            event_handler.replace_rx(rx);
                        }
                        Err(e) => {
                            app.interaction.push(crate::app::InteractionMessage {
                                voice: crate::ui::theme::Voice::Error,
                                text: format!("Failed to spawn TestAgent: {}", e),
                            });
                            app.phase = Phase::Failed;
                            app.agent_state = AgentState::Idle;
                        }
                    }
                }
                None => {}
            }
        }

        // Spawn AI chat request in background thread.
        if let Some(req) = app.chat_request.take() {
            app.chat_rx = Some(crate::chat::spawn_chat_request(req));
        }

        // Drain AI chat response when it arrives.
        if let Some(ref rx) = app.chat_rx {
            match rx.try_recv() {
                Ok(Ok(response)) => {
                    app.chat_rx = None;
                    app.agent_state = AgentState::Idle;
                    app.chat_messages.push(crate::chat::ChatMessage {
                        role: "assistant".to_string(),
                        content: response.clone(),
                    });
                    app.interaction.push(crate::app::InteractionMessage {
                        voice: crate::ui::theme::Voice::Agent,
                        text: response,
                    });
                }
                Ok(Err(e)) => {
                    app.chat_rx = None;
                    app.agent_state = AgentState::Idle;
                    app.interaction.push(crate::app::InteractionMessage {
                        voice: crate::ui::theme::Voice::Error,
                        text: format!("Chat error: {}", e),
                    });
                }
                Err(_) => {}
            }
        }

        // Write user chat input to the running agent's PTY stdin.
        if let Some(ref mut writer) = writer_opt {
            if let Some(chat) = app.pending_chat.take() {
                let _ = writeln!(writer, "{}", chat);
                let _ = writer.flush();
            }
        }

        // Poll child exit if running. The exit code is authoritative here
        // (not derived from PTY EOF), which avoids the spurious-exit-0 race.
        if let Some(ref mut c) = child_opt {
            if let Ok(Some(code)) = c.try_wait() {
                let code = code.exit_code() as i32;
                child_opt = None;
                master_opt = None;
                writer_opt = None;
                app.update(Action::AgentExited(code));
            }
        }
    }
    // Terminal is restored by TerminalGuard drop.
    Ok(())
}
