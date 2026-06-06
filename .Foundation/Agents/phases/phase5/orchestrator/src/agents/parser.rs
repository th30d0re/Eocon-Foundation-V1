use crate::pty_screen::PtyScreen;

#[derive(Debug, Clone, Default)]
pub struct Summary {
    pub errors: u32,
    pub warnings: u32,
    pub passes: u32,
    pub failures: u32,
}

/// Scan the PTY screen grid for error/warning counts and [PASS]/[FAIL] markers.
pub fn scan(screen: &PtyScreen) -> Summary {
    let text = screen.as_text();
    let mut summary = Summary::default();

    for line in text.lines.iter() {
        let line_str = line_to_string(line);
        let lower = line_str.to_lowercase();

        if lower.contains("error:") || lower.contains("[fail]") {
            summary.errors += 1;
        }
        if lower.contains("warning:") || lower.contains("[warn]") {
            summary.warnings += 1;
        }
        if lower.contains("[pass]") {
            summary.passes += 1;
        }
        if lower.contains("failed") || lower.contains("failure") {
            summary.failures += 1;
        }
    }

    summary
}

fn line_to_string(line: &ratatui::text::Line) -> String {
    line.spans.iter().map(|s| s.content.as_ref()).collect()
}
