use ratatui::{
    style::{Color, Style},
    text::{Line, Span},
    widgets::Paragraph,
};

use crate::app::{AgentState, App, Phase};

const SPINNER_FRAMES: &[&str] = &["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"];

pub fn render(app: &App) -> Paragraph<'_> {
    let spinner = if app.agent_state == AgentState::Acting {
        let idx = (app.tick_count as usize) % SPINNER_FRAMES.len();
        SPINNER_FRAMES[idx]
    } else {
        " "
    };

    let phase_str = match app.phase {
        Phase::Idle => "idle",
        Phase::Init => "init",
        Phase::Build => "build running",
        Phase::Test => "test running",
        Phase::Complete => "complete",
        Phase::Failed => "failed",
        Phase::Aborted => "aborted",
    };

    let agent_str = match app.agent_state {
        AgentState::Idle => "agent idle",
        AgentState::Thinking => "agent thinking",
        AgentState::Acting => "agent acting",
    };

    let elapsed = app.elapsed_secs();
    let mins = elapsed / 60;
    let secs = elapsed % 60;
    let time_str = format!("{:02}:{:02}", mins, secs);

    let line = Line::from(vec![
        Span::styled("Foundation Build Verify", Style::default().fg(Color::White)),
        Span::raw(" | "),
        Span::styled(phase_str, Style::default().fg(Color::Yellow)),
        Span::raw(" | "),
        Span::raw(format!("{} errors", app.error_count)),
        Span::raw(" | "),
        Span::styled(agent_str, Style::default().fg(Color::Cyan)),
        Span::raw(" "),
        Span::styled(spinner, Style::default().fg(Color::Green)),
        Span::raw(" | "),
        Span::styled(time_str, Style::default().fg(Color::DarkGray)),
    ]);

    Paragraph::new(line)
}
