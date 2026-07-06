pub mod confirm;
pub mod layout;
pub mod panes;
pub mod picker;
pub mod pipeline;
pub mod prompt;
pub mod status_bar;
pub mod theme;

use ratatui::{
    style::{Color, Style},
    widgets::{Scrollbar, ScrollbarOrientation, ScrollbarState},
    Frame,
};

use crate::app::App;

/// Render the full UI in a single draw() call.
pub fn render(frame: &mut Frame, app: &App) {
    let show_pipeline = pipeline::should_show(app);
    let (pipeline, interaction, output, info_line, info_panel, info_extra, input) =
        layout::compute(frame.area(), app.pane_layout, app.bottom_expanded, show_pipeline);

    if let Some(rect) = pipeline {
        frame.render_widget(pipeline::pipeline_tracker(app), rect);
    }

    if app.pane_layout != crate::app::PaneLayout::OutputOnly {
        frame.render_widget(panes::interaction(app), interaction);
        // Scrollbar for interaction pane
        let total = app.interaction.len();
        let viewport = total.min(panes::VISIBLE_MESSAGE_WINDOW);
        let position = total.saturating_sub(viewport + app.interaction_scroll as usize);
        let mut state = ScrollbarState::new(total)
            .position(position)
            .viewport_content_length(viewport);
        frame.render_stateful_widget(
            Scrollbar::new(ScrollbarOrientation::VerticalRight)
                .style(Style::default().fg(Color::DarkGray)),
            interaction,
            &mut state,
        );
    }
    if app.pane_layout != crate::app::PaneLayout::InteractionOnly {
        frame.render_widget(panes::output(app), output);
        // Scrollbar for output pane
        let (rows, _cols) = app.screen.dims();
        let scrollback = app.screen.scrollback_len();
        let total = scrollback + rows;
        let offset = app.screen.scrollback_offset();
        let position = total.saturating_sub(rows + offset);
        let mut state = ScrollbarState::new(total)
            .position(position)
            .viewport_content_length(rows);
        frame.render_stateful_widget(
            Scrollbar::new(ScrollbarOrientation::VerticalRight)
                .style(Style::default().fg(Color::DarkGray)),
            output,
            &mut state,
        );
    }

    // Split info line into left (spinner + fun status) and right (app name + provider/model).
    // Left side gets exactly the width it needs when active; right side takes the remainder.
    let spinner_width = prompt::info_line_right_width(app).min(info_line.width.saturating_sub(20));
    let info_width = info_line.width.saturating_sub(spinner_width);
    let info_left = ratatui::layout::Rect::new(info_line.x, info_line.y, spinner_width, info_line.height);
    let info_right = ratatui::layout::Rect::new(
        info_line.x + spinner_width,
        info_line.y,
        info_width,
        info_line.height,
    );
    frame.render_widget(prompt::info_line_right(app), info_left);
    frame.render_widget(prompt::info_line_left(app), info_right);

    if let Some(panel_rect) = info_panel {
        frame.render_widget(prompt::info_panel(app), panel_rect);
    }
    if let Some(extra_rect) = info_extra {
        frame.render_widget(prompt::info_extra(app), extra_rect);
    }
    frame.render_widget(prompt::input_bar(app), input);

    // Render command picker overlay on top
    picker::render(frame, app);

    // Render pending-changes confirmation modal on top of everything
    confirm::render(frame, app);
}

#[cfg(test)]
mod tests {
    use ratatui::backend::TestBackend;
    use ratatui::Terminal;

    use super::*;

    #[test]
    fn pipeline_tracker_renders_during_test_phase() {
        let backend = TestBackend::new(80, 24);
        let mut terminal = Terminal::new(backend).unwrap();
        let mut app = App::new(false);
        app.phase = crate::app::Phase::Test;
        // Trigger the running heuristic by having first stage as pending.
        app.pipeline_stages[0].status = crate::app::StageStatus::Pending;

        terminal
            .draw(|frame| render(frame, &app))
            .unwrap();

        let buf = terminal.backend().buffer();
        // Pipeline tracker should be at rows 0-1 (2 rows with top border).
        let row0: String = (0..80)
            .map(|col| buf[(col, 0)].symbol().to_string())
            .collect();
        assert!(
            row0.contains("Pipeline"),
            "pipeline tracker title missing. got: {}",
            row0.trim()
        );

        // Row 1 should contain the first stage "Unit".
        let row1: String = (0..80)
            .map(|col| buf[(col, 1)].symbol().to_string())
            .collect();
        assert!(
            row1.contains("Unit"),
            "pipeline tracker content missing. got: {}",
            row1.trim()
        );
    }

    #[test]
    fn mock_render_shows_info_and_input() {
        let backend = TestBackend::new(80, 24);
        let mut terminal = Terminal::new(backend).unwrap();
        let app = App::new(true);

        terminal
            .draw(|frame| render(frame, &app))
            .unwrap();

        let buf = terminal.backend().buffer();

        // With 24 rows: top (22) + bottom (2). Info = row 22, input = row 23.
        let info_row = 22;
        let input_row = 23;

        let info_text: String = (0..80)
            .map(|col| buf[(col, info_row)].symbol().to_string())
            .collect();
        assert!(
            info_text.contains("Provider"),
            "info line missing provider. got: {}",
            info_text.trim()
        );

        let input_text: String = (0..80)
            .map(|col| buf[(col, input_row)].symbol().to_string())
            .collect();
        assert!(
            input_text.contains(">"),
            "input bar missing prompt. got: {}",
            input_text.trim()
        );
    }

    #[test]
    fn expanded_bottom_shows_info_panel() {
        let backend = TestBackend::new(80, 24);
        let mut terminal = Terminal::new(backend).unwrap();
        let mut app = App::new(true);
        app.bottom_expanded = true;
        app.current_provider = Some("anthropic".to_string());
        app.current_model = Some("claude-sonnet-4".to_string());

        terminal
            .draw(|frame| render(frame, &app))
            .unwrap();

        let buf = terminal.backend().buffer();
        // With expanded bottom (4 lines): info_line=row 20, panel=row 21, extra=row 22, input=row 23
        let panel_row = 21;
        let panel_text: String = (0..80)
            .map(|col| buf[(col, panel_row)].symbol().to_string())
            .collect();
        assert!(
            panel_text.contains("claude-sonnet-4"),
            "info panel missing model. got: {}",
            panel_text.trim()
        );
    }

    #[test]
    fn foundation_pipeline_tracker_renders_when_pipeline_active() {
        use crate::pipeline_engine::{PhaseState, PhaseStatus, PipelineRunState};

        let backend = TestBackend::new(120, 24);
        let mut terminal = Terminal::new(backend).unwrap();
        let mut app = App::new(false);
        app.pipeline_state = Some(PipelineRunState {
            schema_version: 1,
            current_phase: Some(2),
            started_at: None,
            finished_at: None,
            phases: (0..=5)
                .map(|idx| {
                    let status = if idx < 2 {
                        PhaseStatus::Succeeded
                    } else if idx == 2 {
                        PhaseStatus::AwaitingApproval
                    } else {
                        PhaseStatus::Pending
                    };
                    PhaseState {
                        phase: idx as u32,
                        status,
                        ..Default::default()
                    }
                })
                .collect(),
        });

        terminal.draw(|frame| render(frame, &app)).unwrap();

        let buf = terminal.backend().buffer();
        let row0: String = (0..120)
            .map(|col| buf[(col, 0)].symbol().to_string())
            .collect();
        assert!(row0.contains("Foundation Pipeline"), "title missing: {}", row0.trim());

        let row1: String = (0..120)
            .map(|col| buf[(col, 1)].symbol().to_string())
            .collect();
        assert!(row1.contains("Constitution"), "content missing: {}", row1.trim());
        assert!(row1.contains("Planner"), "content missing: {}", row1.trim());
        assert!(row1.contains("Question"), "content missing: {}", row1.trim());
    }

    #[test]
    fn typing_does_not_panic() {
        use crate::action::Action;

        let backend = TestBackend::new(80, 24);
        let mut terminal = Terminal::new(backend).unwrap();
        let mut app = App::new(false);

        // Simulate typing "/help"
        for c in "/help".chars() {
            app.update(Action::InputChar(c));
            terminal.draw(|frame| render(frame, &app)).unwrap();
        }
        app.update(Action::InputSubmit);
        terminal.draw(|frame| render(frame, &app)).unwrap();

        // Simulate typing "/provider openai"
        app = App::new(false);
        for c in "/provider openai".chars() {
            app.update(Action::InputChar(c));
            terminal.draw(|frame| render(frame, &app)).unwrap();
        }

        // Simulate typing regular text
        app = App::new(false);
        for c in "hello world".chars() {
            app.update(Action::InputChar(c));
            terminal.draw(|frame| render(frame, &app)).unwrap();
        }
    }

    #[test]
    fn multiline_message_renders_as_separate_lines() {
        use crate::app::InteractionMessage;
        use crate::ui::theme::Voice;

        let backend = TestBackend::new(80, 24);
        let mut terminal = Terminal::new(backend).unwrap();
        let mut app = App::new(false); // mock=false so no seed messages
        app.interaction.push(InteractionMessage {
            voice: Voice::Agent,
            text: "line one\nline two\nline three".to_string(),
        });

        terminal
            .draw(|frame| render(frame, &app))
            .unwrap();

        let buf = terminal.backend().buffer();
        // Interaction pane is the top-left area. With borders, content starts at row 1.
        let row1: String = (1..40).map(|col| buf[(col, 1)].symbol().to_string()).collect();
        let row2: String = (1..40).map(|col| buf[(col, 2)].symbol().to_string()).collect();
        let row3: String = (1..40).map(|col| buf[(col, 3)].symbol().to_string()).collect();

        assert!(row1.contains("line one"), "first line missing. got: {}", row1.trim());
        assert!(row2.contains("line two"), "second line missing. got: {}", row2.trim());
        assert!(row3.contains("line three"), "third line missing. got: {}", row3.trim());
    }
}
