use ratatui::{
    layout::Rect,
    style::{Color, Modifier, Style},
    text::{Line, Span},
    widgets::{Block, Borders, Clear, Paragraph, Wrap},
};

use crate::app::{App, SLASH_COMMANDS};
use crate::ui::theme;

/// Render the command picker as a floating overlay.
pub fn render(frame: &mut ratatui::Frame, app: &App) {
    if !app.picker_open || app.picker_filtered.is_empty() {
        return;
    }

    let area = frame.area();

    // Compute picker size: up to 12 rows, width = min(50, area.width - 4)
    let item_count = app.picker_filtered.len().min(12);
    let picker_height = (item_count as u16 + 2).min(area.height.saturating_sub(4)).max(3);
    let picker_width = 50u16.min(area.width.saturating_sub(4)).max(20);

    // Center horizontally, place above the bottom bar
    let x = area.x + (area.width.saturating_sub(picker_width)) / 2;
    let y = area.y + area.height.saturating_sub(picker_height + 3);
    let picker_area = Rect::new(x, y, picker_width, picker_height);

    // Clear background behind picker
    frame.render_widget(Clear, picker_area);

    // Build list items
    let filter_text = app.input_buffer.strip_prefix('/').unwrap_or("");
    let items: Vec<Line> = app
        .picker_filtered
        .iter()
        .enumerate()
        .map(|(list_idx, &cmd_idx)| {
            let cmd = &SLASH_COMMANDS[cmd_idx];
            let is_selected = list_idx == app.picker_selected;

            let name_style = if is_selected {
                Style::default()
                    .fg(theme::ACCENT)
                    .add_modifier(Modifier::BOLD)
                    .bg(Color::DarkGray)
            } else {
                Style::default().fg(theme::ACCENT)
            };
            let desc_style = if is_selected {
                Style::default().fg(Color::Gray).bg(Color::DarkGray)
            } else {
                Style::default().fg(Color::DarkGray)
            };

            let name_span = Span::styled(cmd.name, name_style);
            let pad = " ".repeat((12usize).saturating_sub(cmd.name.len()));
            let desc_span = Span::styled(format!("{}{}", pad, cmd.description), desc_style);

            if is_selected {
                Line::from(vec![
                    Span::styled(" › ", Style::default().fg(theme::ACCENT).bg(Color::DarkGray)),
                    name_span,
                    desc_span,
                ])
            } else {
                Line::from(vec![
                    Span::styled("   ", Style::default()),
                    name_span,
                    desc_span,
                ])
            }
        })
        .collect();

    let title = if filter_text.is_empty() {
        " Commands ".to_string()
    } else {
        format!(" Commands matching '/{}' ", filter_text)
    };

    let paragraph = Paragraph::new(items)
        .block(
            Block::default()
                .title(title)
                .borders(Borders::ALL)
                .border_style(Style::default().fg(theme::ACCENT)),
        )
        .wrap(Wrap { trim: false });

    frame.render_widget(paragraph, picker_area);
}
