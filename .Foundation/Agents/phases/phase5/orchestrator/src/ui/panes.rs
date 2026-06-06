use ratatui::{
    style::{Color, Style},
    text::{Line, Span},
    widgets::{Block, Borders, Paragraph, Wrap},
};

use crate::app::{App, FocusedPane};
use crate::ui::theme::Voice;

/// Approximate number of messages to keep visible in the interaction pane.
pub const VISIBLE_MESSAGE_WINDOW: usize = 200;

/// Render the interaction pane with color-coded messages and scroll support.
pub fn interaction(app: &App) -> Paragraph<'_> {
    // Slice the message list based on scroll offset so the user can review history.
    let scroll = app.interaction_scroll as usize;
    let end = app.interaction.len().saturating_sub(scroll);
    let start = end.saturating_sub(VISIBLE_MESSAGE_WINDOW);
    let visible = &app.interaction[start..end];

    let lines: Vec<Line> = visible
        .iter()
        .flat_map(|msg| {
            let prefix = match msg.voice {
                Voice::User => "[USER] ",
                Voice::Agent => "[AGENT] ",
                Voice::Shell => "[SHELL] ",
                Voice::Error => "[ERROR] ",
                Voice::Warning => "[WARN] ",
            };
            let prefix_style = msg.voice.style().add_modifier(ratatui::style::Modifier::BOLD);
            // Message text is neutral; only the prefix is voice-colored.
            let text_style = Style::default().fg(Color::White);

            // Split on newlines so multi-line messages render as separate lines.
            let text_lines: Vec<&str> = msg.text.split('\n').collect();

            text_lines.into_iter().enumerate().map(move |(idx, line)| {
                let is_first = idx == 0;
                if is_first {
                    render_line_with_prefix(prefix, prefix_style, line, text_style)
                } else {
                    // Continuation lines are indented to align with the text.
                    Line::from(vec![
                        Span::raw("       "), // 7 spaces to align past "[XXX] "
                        Span::styled(line, text_style),
                    ])
                }
            })
        })
        .collect();

    let border_style = if app.focused_pane == FocusedPane::Interaction {
        Style::default().fg(Color::Cyan)
    } else {
        Style::default().fg(Color::DarkGray)
    };

    Paragraph::new(lines)
        .block(Block::default().title("Interaction").borders(Borders::ALL).border_style(border_style))
        .wrap(Wrap { trim: true })
        .style(Style::default())
}

/// Render a line that may contain markdown inline code.
/// Text wrapped in backticks gets a subtle dark-gray background.
fn render_line_with_prefix<'a>(
    prefix: &'a str,
    prefix_style: Style,
    text: &'a str,
    text_style: Style,
) -> Line<'a> {
    let code_bg = Style::default().fg(Color::White).bg(Color::Rgb(30, 30, 30));

    // Simple inline code detection: text wrapped in backticks gets code style.
    if text.contains('`') {
        let mut spans = vec![Span::styled(prefix, prefix_style)];
        let mut in_code = false;
        let mut current = String::new();

        for ch in text.chars() {
            if ch == '`' {
                if !current.is_empty() {
                    spans.push(Span::styled(
                        current.clone(),
                        if in_code { code_bg } else { text_style },
                    ));
                    current.clear();
                }
                in_code = !in_code;
            } else {
                current.push(ch);
            }
        }
        if !current.is_empty() {
            spans.push(Span::styled(current, if in_code { code_bg } else { text_style }));
        }
        return Line::from(spans);
    }

    Line::from(vec![
        Span::styled(prefix, prefix_style),
        Span::styled(text, text_style),
    ])
}

/// Render the output pane (PTY screen) with scroll support.
pub fn output(app: &App) -> Paragraph<'_> {
    let text = app.screen.as_text();
    let border_style = if app.focused_pane == FocusedPane::Output {
        Style::default().fg(Color::Cyan)
    } else {
        Style::default().fg(Color::DarkGray)
    };

    Paragraph::new(text)
        .block(Block::default().title("Output").borders(Borders::ALL).border_style(border_style))
        .style(Style::default())
}
