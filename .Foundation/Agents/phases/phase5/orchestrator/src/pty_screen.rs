use ratatui::{
    style::{Color, Style},
    text::{Line, Span, Text},
};
use vte::{Params, Parser as VteParser, Perform};

/// A single cell in the virtual screen grid.
#[derive(Debug, Clone)]
struct Cell {
    ch: char,
    style: Style,
}

impl Default for Cell {
    fn default() -> Self {
        Self {
            ch: ' ',
            style: Style::default(),
        }
    }
}

/// A virtual screen that maintains a grid of styled cells,
/// fed by a VTE parser interpreting ANSI sequences from a PTY.
pub struct PtyScreen {
    parser: VteParser,
    grid: Vec<Vec<Cell>>,
    cursor_row: usize,
    cursor_col: usize,
    rows: usize,
    cols: usize,
    current_style: Style,
    fg: Option<Color>,
    bg: Option<Color>,
    bold: bool,
    /// Lines that have scrolled off the top of the visible grid.
    scrollback: Vec<Vec<Cell>>,
    /// How many lines back from the bottom the view is scrolled (0 = at bottom).
    scrollback_offset: usize,
}

impl PtyScreen {
    pub fn new(rows: usize, cols: usize) -> Self {
        let grid = vec![vec![Cell::default(); cols]; rows];
        Self {
            parser: VteParser::new(),
            grid,
            cursor_row: 0,
            cursor_col: 0,
            rows,
            cols,
            current_style: Style::default(),
            fg: None,
            bg: None,
            bold: false,
            scrollback: Vec::new(),
            scrollback_offset: 0,
        }
    }

    /// Current `(rows, cols)` of the virtual screen.
    pub fn dims(&self) -> (usize, usize) {
        (self.rows, self.cols)
    }

    /// Scroll the grid up by `count` rows, inserting blank rows at the bottom.
    /// Removed lines are saved to the scrollback buffer.
    fn scroll_up_lines(&mut self, count: usize) {
        let count = count.min(self.rows);
        for _ in 0..count {
            let line = self.grid.remove(0);
            self.scrollback.push(line);
            self.grid.push(vec![Cell::default(); self.cols]);
        }
    }

    /// Resize the virtual screen. When growing, content is preserved from the
    /// old grid; when shrinking, content is truncated to the new dimensions.
    pub fn resize(&mut self, rows: usize, cols: usize) {
        let mut new_grid = vec![vec![Cell::default(); cols]; rows];
        for r in 0..rows.min(self.rows) {
            for c in 0..cols.min(self.cols) {
                new_grid[r][c] = self.grid[r][c].clone();
            }
        }
        self.grid = new_grid;
        self.rows = rows;
        self.cols = cols;
        self.cursor_row = self.cursor_row.min(rows.saturating_sub(1));
        self.cursor_col = self.cursor_col.min(cols.saturating_sub(1));
    }

    /// Feed raw PTY bytes into the VTE parser.
    pub fn advance(&mut self, bytes: &[u8]) {
        // Move parser out temporarily to satisfy borrow checker.
        let mut parser = std::mem::take(&mut self.parser);
        parser.advance(self, bytes);
        self.parser = parser;
    }

    /// Convert the virtual screen grid into ratatui Text for rendering,
    /// accounting for scrollback offset.
    pub fn as_text(&self) -> Text<'_> {
        let total = self.scrollback.len() + self.rows;
        let offset = self.scrollback_offset.min(total.saturating_sub(self.rows));
        let start = total.saturating_sub(self.rows + offset);
        let end = total.saturating_sub(offset);

        let mut lines = Vec::new();
        for i in start..end {
            if i < self.scrollback.len() {
                lines.push(cells_to_line(&self.scrollback[i]));
            } else {
                lines.push(cells_to_line(&self.grid[i - self.scrollback.len()]));
            }
        }

        Text::from(lines)
    }

    /// Scroll the output view up by `count` lines (view older content).
    pub fn scroll_up(&mut self, count: usize) {
        let max = self.scrollback.len();
        self.scrollback_offset = (self.scrollback_offset + count).min(max);
    }

    /// Scroll the output view down by `count` lines (view newer content).
    pub fn scroll_down(&mut self, count: usize) {
        self.scrollback_offset = self.scrollback_offset.saturating_sub(count);
    }

    /// Scroll to the bottom of the output (most recent content).
    pub fn scroll_to_bottom(&mut self) {
        self.scrollback_offset = 0;
    }

    fn update_style(&mut self) {
        let mut style = Style::default();
        if let Some(fg) = self.fg {
            style = style.fg(fg);
        }
        if let Some(bg) = self.bg {
            style = style.bg(bg);
        }
        if self.bold {
            style = style.add_modifier(ratatui::style::Modifier::BOLD);
        }
        self.current_style = style;
    }

    fn set_sgr(&mut self, params: &Params) {
        for param in params.iter() {
            if param.is_empty() {
                continue;
            }
            match param[0] {
                0 => {
                    self.fg = None;
                    self.bg = None;
                    self.bold = false;
                }
                1 => self.bold = true,
                30 => self.fg = Some(Color::Black),
                31 => self.fg = Some(Color::Red),
                32 => self.fg = Some(Color::Green),
                33 => self.fg = Some(Color::Yellow),
                34 => self.fg = Some(Color::Blue),
                35 => self.fg = Some(Color::Magenta),
                36 => self.fg = Some(Color::Cyan),
                37 => self.fg = Some(Color::White),
                40 => self.bg = Some(Color::Black),
                41 => self.bg = Some(Color::Red),
                42 => self.bg = Some(Color::Green),
                43 => self.bg = Some(Color::Yellow),
                44 => self.bg = Some(Color::Blue),
                45 => self.bg = Some(Color::Magenta),
                46 => self.bg = Some(Color::Cyan),
                47 => self.bg = Some(Color::White),
                90 => self.fg = Some(Color::DarkGray),
                91 => self.fg = Some(Color::LightRed),
                92 => self.fg = Some(Color::LightGreen),
                93 => self.fg = Some(Color::LightYellow),
                94 => self.fg = Some(Color::LightBlue),
                95 => self.fg = Some(Color::LightMagenta),
                96 => self.fg = Some(Color::LightCyan),
                97 => self.fg = Some(Color::White),
                _ => {}
            }
        }
        self.update_style();
    }
}

impl Perform for PtyScreen {
    fn print(&mut self, c: char) {
        if self.cursor_row >= self.rows || self.cursor_col >= self.cols {
            return;
        }
        self.grid[self.cursor_row][self.cursor_col] = Cell {
            ch: c,
            style: self.current_style,
        };
        self.cursor_col += 1;
        if self.cursor_col >= self.cols {
            self.cursor_col = 0;
            self.cursor_row += 1;
            if self.cursor_row >= self.rows {
                self.scroll_up_lines(1);
                self.cursor_row = self.rows - 1;
            }
        }
    }

    fn execute(&mut self, byte: u8) {
        match byte {
            b'\n' => {
                self.cursor_row += 1;
                self.cursor_col = 0;
                if self.cursor_row >= self.rows {
                    self.scroll_up_lines(1);
                    self.cursor_row = self.rows - 1;
                }
            }
            b'\r' => {
                self.cursor_col = 0;
            }
            b'\t' => {
                let next_tab = (self.cursor_col + 8) & !7;
                self.cursor_col = next_tab.min(self.cols - 1);
            }
            0x08 => {
                // backspace
                if self.cursor_col > 0 {
                    self.cursor_col -= 1;
                }
            }
            _ => {}
        }
    }

    fn csi_dispatch(&mut self, params: &Params, intermediates: &[u8], _ignore: bool, c: char) {
        if intermediates.is_empty() {
            match c {
                'm' => self.set_sgr(params),
                'H' | 'f' => {
                    let mut iter = params.iter();
                    let row = iter.next().and_then(|p| p.first()).copied().unwrap_or(1) as usize;
                    let col = iter.next().and_then(|p| p.first()).copied().unwrap_or(1) as usize;
                    self.cursor_row = row.saturating_sub(1).min(self.rows.saturating_sub(1));
                    self.cursor_col = col.saturating_sub(1).min(self.cols.saturating_sub(1));
                }
                'J' => {
                    let mode = params.iter().next().and_then(|p| p.first()).copied().unwrap_or(0);
                    match mode {
                        0 => {
                            // clear from cursor to end
                            for c in self.cursor_col..self.cols {
                                self.grid[self.cursor_row][c] = Cell::default();
                            }
                            for r in (self.cursor_row + 1)..self.rows {
                                for c in 0..self.cols {
                                    self.grid[r][c] = Cell::default();
                                }
                            }
                        }
                        1 => {
                            // clear from start to cursor
                            for r in 0..self.cursor_row {
                                for c in 0..self.cols {
                                    self.grid[r][c] = Cell::default();
                                }
                            }
                            for c in 0..=self.cursor_col {
                                self.grid[self.cursor_row][c] = Cell::default();
                            }
                        }
                        2 | 3 => {
                            // clear entire screen
                            for r in 0..self.rows {
                                for c in 0..self.cols {
                                    self.grid[r][c] = Cell::default();
                                }
                            }
                        }
                        _ => {}
                    }
                }
                'K' => {
                    let mode = params.iter().next().and_then(|p| p.first()).copied().unwrap_or(0);
                    match mode {
                        0 => {
                            for c in self.cursor_col..self.cols {
                                self.grid[self.cursor_row][c] = Cell::default();
                            }
                        }
                        1 => {
                            for c in 0..=self.cursor_col {
                                self.grid[self.cursor_row][c] = Cell::default();
                            }
                        }
                        2 => {
                            for c in 0..self.cols {
                                self.grid[self.cursor_row][c] = Cell::default();
                            }
                        }
                        _ => {}
                    }
                }
                _ => {}
            }
        }
    }

    fn osc_dispatch(&mut self, _params: &[&[u8]], _bell_terminated: bool) {}
    fn esc_dispatch(&mut self, _intermediates: &[u8], _ignore: bool, _byte: u8) {}
    fn hook(&mut self, _params: &Params, _intermediates: &[u8], _ignore: bool, _c: char) {}
    fn put(&mut self, _byte: u8) {}
    fn unhook(&mut self) {}
}

fn cells_to_line(cells: &[Cell]) -> Line<'_> {
    let spans: Vec<Span> = cells
        .iter()
        .map(|cell| Span::styled(cell.ch.to_string(), cell.style))
        .collect();
    Line::from(spans)
}
