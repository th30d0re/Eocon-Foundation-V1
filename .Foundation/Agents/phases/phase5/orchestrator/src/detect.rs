use std::path::{Path, PathBuf};
use std::process::Command;

use color_eyre::eyre::Result;

/// Find the best Xcode workspace or project in `start_dir`.
///
/// Heuristic (mirrors BuildAgent.sh):
/// 1. Search for `.xcworkspace` (excluding nested `project.xcworkspace`) up to depth 5.
/// 2. Fallback to `.xcodeproj` up to depth 5.
/// 3. Prefer shortest path (closest to root).
///
/// Returns `Some((path, is_workspace))` or `None`.
pub fn find_xcode_project(start_dir: &Path) -> Option<(PathBuf, bool)> {
    let workspace = find_best(start_dir, "xcworkspace", 5);
    if let Some(ws) = workspace {
        // Exclude project.xcworkspace nested inside .xcodeproj
        if !ws
            .components()
            .any(|c| c.as_os_str().to_string_lossy().ends_with(".xcodeproj"))
        {
            return Some((ws, true));
        }
    }

    let project = find_best(start_dir, "xcodeproj", 5);
    project.map(|p| (p, false))
}

/// Search for files with the given extension, preferring shortest path.
fn find_best(start_dir: &Path, extension: &str, max_depth: usize) -> Option<PathBuf> {
    let mut best: Option<(usize, PathBuf)> = None;
    walk(start_dir, extension, max_depth, 0, &mut best);
    best.map(|(_, p)| p)
}

fn walk(dir: &Path, extension: &str, max_depth: usize, depth: usize, best: &mut Option<(usize, PathBuf)>) {
    if depth > max_depth {
        return;
    }
    let Ok(entries) = std::fs::read_dir(dir) else { return };
    for entry in entries.flatten() {
        let path = entry.path();
        let name = path.file_name().unwrap_or_default().to_string_lossy();

        if path.is_dir() {
            // Skip common non-project directories
            let skip = matches!(
                name.as_ref(),
                ".git"
                    | ".build"
                    | "Pods"
                    | "Carthage"
                    | "checkouts"
                    | "DerivedData"
                    | "Build"
                    | "Docs"
                    | "docs"
                    | "Reference"
                    | "Ref"
                    | "Examples"
                    | "Samples"
                    | "node_modules"
                    | ".foundation"
                    | "__Avenue"
                    | ".Foundation"
            );
            if !skip {
                walk(&path, extension, max_depth, depth + 1, best);
            }
        } else if name.ends_with(&format!(".{}", extension)) {
            let len = path.as_os_str().len();
            if best.as_ref().map_or(true, |(best_len, _)| len < *best_len) {
                *best = Some((len, path));
            }
        }
    }
}

/// Auto-detect the first scheme from a workspace or project using `xcodebuild -list`.
pub fn detect_scheme(project_path: &Path, is_workspace: bool) -> Result<Option<String>> {
    let mut cmd = Command::new("xcodebuild");
    if is_workspace {
        cmd.arg("-workspace").arg(project_path);
    } else {
        cmd.arg("-project").arg(project_path);
    }
    cmd.arg("-list");

    let output = cmd.output()?;
    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        return Err(color_eyre::eyre::eyre!(
            "xcodebuild -list failed: {}",
            stderr.trim()
        ));
    }

    let stdout = String::from_utf8_lossy(&output.stdout);
    let scheme = parse_first_scheme(&stdout);
    Ok(scheme)
}

/// Parse the first scheme from `xcodebuild -list` output.
fn parse_first_scheme(output: &str) -> Option<String> {
    let mut in_schemes = false;
    for line in output.lines() {
        if line.trim() == "Schemes:" {
            in_schemes = true;
            continue;
        }
        if in_schemes {
            let trimmed = line.trim();
            if trimmed.is_empty() {
                break;
            }
            // Stop if we hit another section header
            if trimmed.ends_with(':') {
                break;
            }
            return Some(trimmed.to_string());
        }
    }
    None
}

/// Auto-detect agents directory.
///
/// 1. If `BuildAgent.sh` exists in `start_dir`, use `start_dir`.
/// 2. Walk up from `start_dir` looking for `.Foundation/Agents/phases/phase5/BuildAgent.sh`.
/// 3. Walk up from the current executable looking for `BuildAgent.sh`
///    (handles `orch` being run from anywhere via symlink).
/// 4. Fall back to `start_dir`.
pub fn find_agents_dir(start_dir: &Path) -> PathBuf {
    // Case 1: BuildAgent.sh in current dir
    if start_dir.join("BuildAgent.sh").is_file() {
        return start_dir.to_path_buf();
    }

    // Case 2: Walk up looking for .Foundation/Agents/phases/phase5/BuildAgent.sh
    let mut current = start_dir;
    loop {
        let candidate = current
            .join(".Foundation")
            .join("Agents")
            .join("phases")
            .join("phase5")
            .join("BuildAgent.sh");
        if candidate.is_file() {
            return candidate.parent().unwrap_or(current).to_path_buf();
        }
        match current.parent() {
            Some(parent) => current = parent,
            None => break,
        }
    }

    // Case 3: Walk up from the executable path (supports global `orch` symlink).
    if let Ok(exe) = std::env::current_exe() {
        // Resolve symlinks so we walk from the real binary location.
        let exe = std::fs::canonicalize(&exe).unwrap_or(exe);
        let mut current = exe.as_path();
        while let Some(parent) = current.parent() {
            let candidate = parent.join("BuildAgent.sh");
            if candidate.is_file() {
                return parent.to_path_buf();
            }
            current = parent;
        }
    }

    // Case 4: default to start_dir
    start_dir.to_path_buf()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_first_scheme() {
        let output = r#"Information about project "MyApp":
    Targets:
        MyApp
        MyAppTests

    Build Configurations:
        Debug
        Release

    Schemes:
        MyApp
        MyAppTests
"#;
        assert_eq!(parse_first_scheme(output), Some("MyApp".to_string()));
    }

    #[test]
    fn test_parse_first_scheme_empty() {
        assert_eq!(parse_first_scheme("No schemes here"), None);
    }
}
