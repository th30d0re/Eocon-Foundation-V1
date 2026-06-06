use std::fs;
use std::path::{Path, PathBuf};

use color_eyre::Result;

/// A single file change proposed by the AI assistant.
#[derive(Debug, Clone)]
pub struct PendingChange {
    pub path: PathBuf,
    pub content: String,
}

/// Scan an assistant message for markdown code blocks and attempt to pair
/// each block with a file path. Returns all changes found.
pub fn parse_changes(text: &str, cwd: &Path) -> Vec<PendingChange> {
    let mut changes = Vec::new();
    let lines: Vec<&str> = text.lines().collect();
    let mut i = 0;

    while i < lines.len() {
        let line = lines[i];
        if line.trim_start().starts_with("```") {
            let fence_start = i;
            let lang = line.trim_start()[3..].trim();
            i += 1;

            // Find closing fence
            let mut content_lines = Vec::new();
            while i < lines.len() && !lines[i].trim_start().starts_with("```") {
                content_lines.push(lines[i]);
                i += 1;
            }
            let _fence_end = i;
            i += 1; // skip closing fence

            if content_lines.is_empty() {
                continue;
            }

            if let Some(path) = find_block_path(&lines, fence_start, &content_lines, lang) {
                let resolved = if path.is_absolute() {
                    path
                } else {
                    cwd.join(path)
                };
                let content = content_lines.join("\n");
                changes.push(PendingChange {
                    path: resolved,
                    content,
                });
            }
        } else {
            i += 1;
        }
    }

    changes
}

/// Try to determine the file path for a code block.
/// Priority:
/// 1. The non-empty line immediately before the opening fence (if it looks like a path)
/// 2. The first line inside the block if it is a `// path` or `# path` comment
fn find_block_path(
    all_lines: &[&str],
    fence_start: usize,
    content_lines: &[&str],
    _lang: &str,
) -> Option<PathBuf> {
    // Candidate 1: preceding line
    if fence_start > 0 {
        let prev = all_lines[fence_start - 1].trim();
        if looks_like_path(prev) {
            return Some(PathBuf::from(strip_trailing_colon(prev)));
        }
    }

    // Candidate 2: first content line as a comment path
    let first = content_lines.first()?.trim();
    if let Some(stripped) = first.strip_prefix("// ") {
        if looks_like_path(stripped) {
            return Some(PathBuf::from(strip_trailing_colon(stripped)));
        }
    }
    if let Some(stripped) = first.strip_prefix("# ") {
        if looks_like_path(stripped) {
            return Some(PathBuf::from(strip_trailing_colon(stripped)));
        }
    }

    None
}

fn looks_like_path(s: &str) -> bool {
    let s = s.trim();
    if s.is_empty() {
        return false;
    }
    // Must not contain obvious markdown or sentence punctuation
    if s.contains('`') || s.contains('"') || s.contains('\'') {
        return false;
    }
    // Should contain a slash or be a known absolute/relative filename
    if s.starts_with("src/")
        || s.starts_with("tests/")
        || s.starts_with("lib/")
        || s.starts_with("bin/")
        || s.starts_with('/')
        || s.contains('/')
    {
        return has_source_extension(s) || s.contains('/');
    }
    false
}

fn has_source_extension(s: &str) -> bool {
    let ext = Path::new(s).extension().and_then(|e| e.to_str());
    matches!(
        ext,
        Some("rs" | "swift" | "m" | "h" | "mm" | "cpp" | "c" | "py" | "js" | "ts" | "tsx" | "jsx" | "json" | "yml" | "yaml" | "toml" | "sh" | "md")
    )
}

fn strip_trailing_colon(s: &str) -> &str {
    s.strip_suffix(':').unwrap_or(s)
}

/// Write all pending changes to disk, creating parent directories as needed.
/// Returns the number of files written or the first error encountered.
pub fn apply_changes(changes: &[PendingChange]) -> Result<usize> {
    let mut written = 0;
    for change in changes {
        if let Some(parent) = change.path.parent() {
            fs::create_dir_all(parent)?;
        }
        fs::write(&change.path, &change.content)?;
        written += 1;
    }
    Ok(written)
}

/// True if any change path is inside the orchestrator's own source tree.
pub fn changes_affect_orchestrator(changes: &[PendingChange], orchestrator_dir: &Path) -> bool {
    let src_dir = orchestrator_dir.join("src");
    changes.iter().any(|c| c.path.starts_with(&src_dir))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parse_simple_rust_block() {
        let text = r#"Here is the fix:

src/app.rs
```rust
fn hello() {}
```
"#;
        let changes = parse_changes(text, Path::new("/project"));
        assert_eq!(changes.len(), 1);
        assert_eq!(changes[0].path, Path::new("/project/src/app.rs"));
        assert_eq!(changes[0].content, "fn hello() {}");
    }

    #[test]
    fn parse_block_with_comment_path() {
        let text = r#"```rust
// src/lib.rs
pub mod apply;
```
"#;
        let changes = parse_changes(text, Path::new("/project"));
        assert_eq!(changes.len(), 1);
        assert_eq!(changes[0].path, Path::new("/project/src/lib.rs"));
    }

    #[test]
    fn parse_multiple_blocks() {
        let text = r#"src/a.rs
```rust
fn a() {}
```

src/b.rs
```rust
fn b() {}
```
"#;
        let changes = parse_changes(text, Path::new("/project"));
        assert_eq!(changes.len(), 2);
    }

    #[test]
    fn ignores_blocks_without_path() {
        let text = r#"```rust
fn example() {}
```
"#;
        let changes = parse_changes(text, Path::new("/project"));
        assert!(changes.is_empty());
    }
}
