use ratatui::{
    layout::{Alignment, Constraint, Direction, Layout, Rect},
    style::{Color, Modifier, Style},
    text::{Line, Span},
    widgets::{Block, Borders, Clear, Paragraph, Wrap},
};

use crate::app::{App, ApplyPhase};

/// Render a centered confirmation modal when there are pending AI-suggested changes.
pub fn render(frame: &mut ratatui::Frame, app: &App) {
    if app.apply_phase != ApplyPhase::Prompting || app.pending_changes.is_empty() {
        return;
    }

    let area = frame.area();

    // Compute modal size based on content.
    let min_width = 40u16.min(area.width.saturating_sub(4)).max(20);
    let content_height = app.pending_changes.len() as u16 + 6; // title + files + note + footer + padding
    let height = content_height.min(area.height.saturating_sub(4)).max(8);
    let width = min_width.max(60).min(area.width.saturating_sub(4));

    let x = area.x + (area.width.saturating_sub(width)) / 2;
    let y = area.y + (area.height.saturating_sub(height)) / 2;
    let modal_area = Rect::new(x, y, width, height);

    frame.render_widget(Clear, modal_area);

    let title = " Apply proposed changes? ";
    let inner = inner_rect(modal_area);

    // Build file list lines
    let mut lines: Vec<Line> = vec![
        Line::from(vec![
            Span::styled(
                format!("The AI proposed {} change(s):", app.pending_changes.len()),
                Style::default().fg(Color::White),
            ),
        ]),
        Line::raw(""),
    ];

    for change in &app.pending_changes {
        lines.push(Line::from(vec![
            Span::raw("  • "),
            Span::styled(
                change.path.display().to_string(),
                Style::default().fg(Color::Cyan),
            ),
        ]));
    }

    lines.push(Line::raw(""));

    // Check if any change is inside the TUI src/ tree.
    let any_tui = app
        .pending_changes
        .iter()
        .any(|c| c.path.starts_with(app.cwd.join("src")));

    if any_tui {
        lines.push(Line::from(vec![
            Span::styled(
                "These changes affect the TUI. Approving will rebuild and restart orch.",
                Style::default().fg(Color::Yellow),
            ),
        ]));
        lines.push(Line::raw(""));
    }

    lines.push(Line::from(vec![
        Span::styled("[", Style::default().fg(Color::White)),
        Span::styled("y", Style::default().fg(Color::Green).add_modifier(Modifier::BOLD)),
        Span::styled("] apply   [", Style::default().fg(Color::White)),
        Span::styled("n", Style::default().fg(Color::Red).add_modifier(Modifier::BOLD)),
        Span::styled("] discard", Style::default().fg(Color::White)),
    ]));

    let paragraph = Paragraph::new(lines)
        .block(
            Block::default()
                .title(title)
                .title_alignment(Alignment::Center)
                .borders(Borders::ALL)
                .border_style(Style::default().fg(Color::Yellow)),
        )
        .wrap(Wrap { trim: false });

    frame.render_widget(paragraph, inner);
}

/// Subtract the border cells from the modal area so content fits inside.
fn inner_rect(area: Rect) -> Rect {
    let layout = Layout::default()
        .direction(Direction::Vertical)
        .constraints([Constraint::Length(1), Constraint::Min(0), Constraint::Length(1)])
        .split(area);
    let middle = layout[1];
    let h_layout = Layout::default()
        .direction(Direction::Horizontal)
        .constraints([Constraint::Length(1), Constraint::Min(0), Constraint::Length(1)])
        .split(middle);
    h_layout[1]
}
