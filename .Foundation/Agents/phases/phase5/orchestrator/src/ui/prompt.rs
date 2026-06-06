use ratatui::{
    layout::Alignment,
    style::{Color, Style},
    text::{Line, Span},
    widgets::Paragraph,
};

use crate::app::{AgentState, App, InfoView, Phase, FUN_STATUSES, SPINNER_COLORS, SPINNER_FRAMES};

const VERSION: &str = "v0.1.0";

/// Contracted info line LEFT — provider + model.
pub fn info_line_left(app: &App) -> Paragraph<'_> {
    let provider = app.current_provider.as_deref().unwrap_or("—");
    let model = app.current_model.as_deref().unwrap_or("—");

    if app.bottom_expanded {
        return Paragraph::new(Line::from(vec![
            Span::styled("Foundation Orchestrator ", Style::default().fg(Color::White)),
            Span::styled(VERSION, Style::default().fg(Color::DarkGray)),
        ]));
    }

    Paragraph::new(Line::from(vec![
        Span::styled("Foundation Orchestrator ", Style::default().fg(Color::White)),
        Span::styled(VERSION, Style::default().fg(Color::DarkGray)),
        Span::raw(" | "),
        Span::styled("Provider: ", Style::default().fg(Color::DarkGray)),
        Span::styled(provider, Style::default().fg(Color::Cyan)),
        Span::raw(" | "),
        Span::styled("Model: ", Style::default().fg(Color::DarkGray)),
        Span::styled(model, Style::default().fg(Color::Cyan)),
    ])).alignment(Alignment::Right)
}

/// Minimum width the right side of the info line needs (spinner + status + dots).
pub fn info_line_right_width(app: &App) -> u16 {
    if app.bottom_expanded || app.agent_state == AgentState::Idle {
        return 0;
    }
    let spinner_idx = (app.tick_count as usize) % SPINNER_FRAMES.len();
    let spinner = SPINNER_FRAMES[spinner_idx];
    let status_idx = ((app.tick_count / 300) as usize) % FUN_STATUSES.len();
    let status_text = FUN_STATUSES[status_idx];
    let text = format!("{} {}...", spinner, status_text);
    text.chars().count() as u16 + 2 // +2 padding
}

/// Contracted info line RIGHT — animated spinner + fun status.
/// Only visible when an agent is running (Acting) or the model is thinking.
pub fn info_line_right(app: &App) -> Paragraph<'_> {
    if app.bottom_expanded || app.agent_state == AgentState::Idle {
        return Paragraph::new("");
    }

    // Animated spinner
    let spinner_idx = (app.tick_count as usize) % SPINNER_FRAMES.len();
    let spinner = SPINNER_FRAMES[spinner_idx];

    // Fun status message changes every ~15 seconds (300 ticks @ 50ms)
    let status_idx = ((app.tick_count / 300) as usize) % FUN_STATUSES.len();
    let status_text = FUN_STATUSES[status_idx];

    // Animated ellipsis cycles every 36 ticks (~1.8s)
    let dot_count = ((app.tick_count / 36) as usize % 3) + 1;
    let dots = ".".repeat(dot_count);

    // Spinner color changes every 5 minutes (6000 ticks @ 50ms)
    let color_idx = ((app.tick_count / 6000) as usize) % SPINNER_COLORS.len();
    let spinner_color = SPINNER_COLORS[color_idx];

    let text = format!("{} {}{}", spinner, status_text, dots);

    Paragraph::new(Span::styled(text, Style::default().fg(spinner_color))).alignment(Alignment::Left)
}

/// Expanded info panel — shows detailed metrics or artifacts paths.
pub fn info_panel(app: &App) -> Paragraph<'_> {
    let line = match app.info_view {
        InfoView::Metrics => {
            let provider = app.current_provider.as_deref().unwrap_or("—");
            let model = app.current_model.as_deref().unwrap_or("—");
            let phase = format!("{:?}", app.phase);
            let errors = app.error_count;

            Line::from(vec![
                Span::styled(format!("{} / ", provider), Style::default().fg(Color::Cyan)),
                Span::styled(model, Style::default().fg(Color::Green)),
                Span::raw(" | "),
                Span::styled(phase, Style::default().fg(Color::Yellow)),
                Span::raw(" | "),
                Span::styled(format!("{} errors", errors), Style::default().fg(Color::Red)),
            ])
        }
        InfoView::Artifacts => {
            let agents = app.agents_dir.display().to_string();
            let artifacts = app
                .artifacts_dir
                .as_ref()
                .map(|p| p.display().to_string())
                .unwrap_or_else(|| "—".to_string());
            let cwd = app.cwd.display().to_string();

            Line::from(vec![
                Span::styled("agents: ", Style::default().fg(Color::DarkGray)),
                Span::styled(agents, Style::default().fg(Color::Cyan)),
                Span::raw(" | "),
                Span::styled("artifacts: ", Style::default().fg(Color::DarkGray)),
                Span::styled(artifacts, Style::default().fg(Color::Cyan)),
                Span::raw(" | "),
                Span::styled("cwd: ", Style::default().fg(Color::DarkGray)),
                Span::styled(cwd, Style::default().fg(Color::Cyan)),
            ])
        }
    };

    Paragraph::new(line)
}

/// Third line of expanded info — extra details per view.
pub fn info_extra(app: &App) -> Paragraph<'_> {
    let line = match app.info_view {
        InfoView::Metrics => {
            let elapsed = app.elapsed_secs();
            let mins = elapsed / 60;
            let secs = elapsed % 60;
            Line::from(vec![
                Span::styled("Elapsed: ", Style::default().fg(Color::DarkGray)),
                Span::styled(format!("{:02}:{:02}", mins, secs), Style::default().fg(Color::White)),
                Span::raw(" | "),
                Span::styled("Phase: ", Style::default().fg(Color::DarkGray)),
                Span::styled(format!("{:?}", app.phase), Style::default().fg(Color::Yellow)),
                Span::raw(" | "),
                Span::styled("Layout: ", Style::default().fg(Color::DarkGray)),
                Span::styled(format!("{:?}", app.pane_layout), Style::default().fg(Color::Green)),
            ])
        }
        InfoView::Artifacts => {
            Line::from(vec![
                Span::styled("project: ", Style::default().fg(Color::DarkGray)),
                Span::styled(app.project.as_deref().unwrap_or("—"), Style::default().fg(Color::Cyan)),
                Span::raw(" | "),
                Span::styled("scheme: ", Style::default().fg(Color::DarkGray)),
                Span::styled(app.scheme.as_deref().unwrap_or("—"), Style::default().fg(Color::Cyan)),
            ])
        }
    };

    Paragraph::new(line)
}

/// Text input bar — always present at the bottom.
pub fn input_bar(app: &App) -> Paragraph<'_> {
    let cursor_char = '▎';
    let before_cursor = &app.input_buffer[..app.input_cursor];
    let after_cursor = &app.input_buffer[app.input_cursor..];

    let line = Line::from(vec![
        Span::styled("> ", Style::default().fg(Color::Green)),
        Span::raw(before_cursor),
        Span::styled(cursor_char.to_string(), Style::default().fg(Color::White)),
        Span::raw(after_cursor),
    ]);

    Paragraph::new(line)
}

/// Legacy prompt widget — kept for compatibility, but the bottom bar now
/// uses `info_line` + `input_bar` directly.
pub fn render(app: &App) -> Paragraph<'_> {
    let text = if app.show_help {
        Line::from(vec![
            Span::styled("?", Style::default().fg(Color::Yellow)),
            Span::raw(" help  "),
            Span::styled("Tab", Style::default().fg(Color::Yellow)),
            Span::raw(" toggle pane  "),
            Span::styled("Shift+Tab", Style::default().fg(Color::Yellow)),
            Span::raw(" expand info  "),
            Span::styled("Enter", Style::default().fg(Color::Yellow)),
            Span::raw(" submit"),
        ])
    } else {
        match app.phase {
            Phase::Failed => Line::from(vec![
                Span::raw("Re-run build? ["),
                Span::styled("y", Style::default().fg(Color::Green)),
                Span::raw("/"),
                Span::styled("n", Style::default().fg(Color::Red)),
                Span::raw("]  or type /yes /no"),
            ]),
            _ => Line::from(vec![
                Span::styled("Tab", Style::default().fg(Color::Yellow)),
                Span::raw(" pane  "),
                Span::styled("Shift+Tab", Style::default().fg(Color::Yellow)),
                Span::raw(" info  "),
                Span::styled("Esc", Style::default().fg(Color::Yellow)),
                Span::raw(" quit"),
            ]),
        }
    };

    Paragraph::new(text)
}
