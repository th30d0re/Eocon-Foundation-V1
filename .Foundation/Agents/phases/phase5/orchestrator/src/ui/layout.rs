use ratatui::layout::{Constraint, Direction, Layout, Rect};

use crate::app::PaneLayout;

/// Compute layout rectangles for the UI regions.
///
/// Top: horizontal split based on pane_layout
/// Bottom: info line (always) + [panel + extra when expanded] + input bar (always)
pub fn compute(
    area: Rect,
    pane_layout: PaneLayout,
    bottom_expanded: bool,
) -> (Rect, Rect, Rect, Option<Rect>, Option<Rect>, Rect) {
    let info_height = if bottom_expanded { 3 } else { 1 };
    let bottom_height = info_height + 1; // +1 for input bar

    let main_chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([Constraint::Min(3), Constraint::Length(bottom_height)])
        .split(area);

    let top = main_chunks[0];
    let bottom = main_chunks[1];

    let (left_width, right_width) = match pane_layout {
        PaneLayout::Split => (Constraint::Percentage(50), Constraint::Min(0)),
        PaneLayout::OutputOnly => (Constraint::Length(0), Constraint::Percentage(100)),
        PaneLayout::InteractionOnly => (Constraint::Percentage(100), Constraint::Length(0)),
    };

    let top_chunks = Layout::default()
        .direction(Direction::Horizontal)
        .constraints([left_width, right_width])
        .split(top);

    let interaction = top_chunks[0];
    let output = top_chunks[1];

    let bottom_constraints = if bottom_expanded {
        vec![
            Constraint::Length(1),
            Constraint::Length(1),
            Constraint::Length(1),
            Constraint::Length(1),
        ]
    } else {
        vec![Constraint::Length(1), Constraint::Length(1)]
    };

    let bottom_chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints(bottom_constraints)
        .split(bottom);

    let info_line = bottom_chunks[0];
    let input = *bottom_chunks.last().unwrap();

    let (info_panel, info_extra) = if bottom_expanded {
        (Some(bottom_chunks[1]), Some(bottom_chunks[2]))
    } else {
        (None, None)
    };

    (interaction, output, info_line, info_panel, info_extra, input)
}

/// Derive the inner (content) size of the output pane for a given terminal
/// size, accounting for the same splits `compute` uses plus the output pane's
/// 1-cell border on every side. Returns `(rows, cols)` for the PTY/virtual
/// screen. Never hardcodes dimensions; everything is derived from `term`.
pub fn output_inner_size(
    term_cols: u16,
    term_rows: u16,
    pane_layout: PaneLayout,
    bottom_expanded: bool,
) -> (u16, u16) {
    let area = Rect::new(0, 0, term_cols, term_rows);
    let (_interaction, output, _info_line, _info_panel, _info_extra, _input) =
        compute(area, pane_layout, bottom_expanded);
    // Subtract the borders (Borders::ALL => 1 cell each side).
    let rows = output.height.saturating_sub(2).max(1);
    let cols = output.width.saturating_sub(2).max(1);
    (rows, cols)
}
