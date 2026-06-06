use ratatui::{
    style::Style,
    text::{Line, Span},
    widgets::{Block, Borders, Paragraph, Wrap},
};

use crate::app::App;
use crate::ui::theme::Voice;

pub fn interaction(app: &App) -> Paragraph<'_> {
    let lines: Vec<Line> = app
        .interaction
        .iter()
        .flat_map(|msg| {
            let prefix = match msg.voice {
                Voice::User => "[USER] ",
                Voice::Agent => "[AGENT] ",
                Voice::Shell => "[SHELL] ",
                Voice::Error => "[ERROR] ",
                Voice::Warning => "[WARN] ",
            };
            let prefix_style = msg.voice.style();
            let text_style = msg.voice.style();
            // Split on newlines so multi-line messages render as separate lines.
            let text_lines: Vec<&str> = msg.text.split('\n').collect();
            text_lines.into_iter().map(move |line| {
                Line::from(vec![
                    Span::styled(prefix, prefix_style),
                    Span::styled(line, text_style),
                ])
            })
        })
        .collect();

    Paragraph::new(lines)
        .block(Block::default().title("Interaction").borders(Borders::ALL))
        .wrap(Wrap { trim: true })
        .style(Style::default())
}

pub fn output(app: &App) -> Paragraph<'_> {
    let text = app.screen.as_text();
    Paragraph::new(text)
        .block(Block::default().title("Output").borders(Borders::ALL))
        .style(Style::default())
}
