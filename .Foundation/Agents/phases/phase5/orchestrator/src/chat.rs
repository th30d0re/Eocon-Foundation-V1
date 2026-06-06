use std::io::{BufRead, BufReader, Read, Write};
use std::path::PathBuf;
use std::process::{Command, Stdio};
use std::sync::mpsc::{channel, Receiver};

#[derive(Debug, Clone)]
pub struct ChatMessage {
    pub role: String,
    pub content: String,
}

#[derive(Debug, Clone)]
pub struct ChatRequest {
    pub provider: String,
    pub model: String,
    pub messages: Vec<ChatMessage>,
}

/// Spawn a background thread that runs the provider's CLI and returns the
/// assistant's text via a channel.
pub fn spawn_chat_request(req: ChatRequest) -> Receiver<Result<String, String>> {
    let (tx, rx) = channel();
    std::thread::spawn(move || {
        let result = run_cli_chat(req);
        let _ = tx.send(result);
    });
    rx
}

fn run_cli_chat(req: ChatRequest) -> Result<String, String> {
    let cfg = build_cli_config(&req.provider, &req.model).ok_or_else(|| {
        format!(
            "No CLI tool found for provider '{}'. \
             Available mappings:\n\
               anthropic → claude\n\
               moonshot  → kimi\n\
               openai    → codex\n\
               codex     → codex\n\
               cursor    → cursor\n\
               ollama    → ollama\n\
               google    → gemini\n\
             Install the provider's CLI and ensure it's in your PATH.",
            req.provider
        )
    })?;

    let prompt = format_messages(&req.messages);

    let mut args = cfg.args.clone();
    if cfg.prompt_via_arg {
        args.push(prompt.clone());
    }

    let mut cmd = Command::new(&cfg.program);
    cmd.args(&args);
    cmd.stdin(Stdio::piped());
    cmd.stdout(Stdio::piped());
    cmd.stderr(Stdio::piped());

    let mut child = cmd
        .spawn()
        .map_err(|e| format!("Failed to spawn '{}': {}", cfg.program, e))?;

    // Some CLIs take the prompt as a CLI argument (codex);
    // others read it from stdin (claude, kimi, ollama, cursor).
    if cfg.prompt_via_arg {
        // Close stdin immediately so the child doesn't wait for input.
        if let Some(stdin) = child.stdin.take() {
            drop(stdin);
        }
    } else {
        // Write the formatted conversation to stdin, then close it (EOF).
        if let Some(mut stdin) = child.stdin.take() {
            let _ = stdin.write_all(prompt.as_bytes());
            let _ = stdin.flush();
        }
    }

    // Read stdout and stderr concurrently so pipe buffers never deadlock.
    let stdout = child
        .stdout
        .take()
        .ok_or("Failed to capture stdout")?;
    let stderr = child
        .stderr
        .take()
        .ok_or("Failed to capture stderr")?;

    let stdout_handle = std::thread::spawn(move || {
        let reader = BufReader::new(stdout);
        let mut out = String::new();
        for line in reader.lines() {
            if let Ok(l) = line {
                out.push_str(&strip_ansi(&l));
                out.push('\n');
            }
        }
        out
    });

    let stderr_handle = std::thread::spawn(move || {
        let mut reader = BufReader::new(stderr);
        let mut err = String::new();
        reader.read_to_string(&mut err).ok();
        err
    });

    let status = child
        .wait()
        .map_err(|e| format!("Failed to wait for '{}': {}", cfg.program, e))?;

    let mut output = stdout_handle.join().unwrap_or_default();
    let stderr_text = stderr_handle.join().unwrap_or_default();

    // If the CLI wrote its response to a file, read that instead of stdout.
    if let Some(ref path) = cfg.output_file {
        if path.exists() {
            match std::fs::read_to_string(path) {
                Ok(contents) => {
                    output = contents;
                }
                Err(e) => {
                    return Err(format!(
                        "Failed to read output file '{}': {}",
                        path.display(),
                        e
                    ));
                }
            }
            // Best-effort cleanup of the temp file.
            let _ = std::fs::remove_file(path);
        }
    }

    if !status.success() {
        let mut msg = format!("{} exited with status {:?}", cfg.program, status.code());
        let err_clean = strip_ansi(&stderr_text).trim().to_string();
        if !err_clean.is_empty() {
            msg.push_str("\n--- stderr ---\n");
            msg.push_str(&err_clean);
        }
        return Err(msg);
    }

    let result = output.trim_end().to_string();
    if result.is_empty() && !stderr_text.trim().is_empty() {
        return Ok(format!(
            "(no stdout)\n--- stderr ---\n{}",
            strip_ansi(&stderr_text).trim()
        ));
    }

    Ok(result)
}

/// Configuration for a CLI command invocation.
struct CliConfig {
    program: String,
    args: Vec<String>,
    /// If true, the prompt is appended as the last CLI arg.
    prompt_via_arg: bool,
    /// If set, the response is read from this file instead of stdout.
    output_file: Option<PathBuf>,
}

/// Map a provider name to the CLI program and arguments.
fn build_cli_config(provider: &str, _model: &str) -> Option<CliConfig> {
    match provider {
        "anthropic" => {
            let exe = find_exe("claude", &["/opt/homebrew/bin/claude"])?;
            Some(CliConfig {
                program: exe,
                args: vec!["-p".into()],
                prompt_via_arg: false,
                output_file: None,
            })
        }
        "moonshot" => {
            let exe = find_exe("kimi", &["/opt/homebrew/bin/kimi"])?;
            let empty_mcp = empty_mcp_config_path();
            Some(CliConfig {
                program: exe,
                args: vec![
                    "--quiet".into(),
                    "--mcp-config-file".into(),
                    empty_mcp,
                ],
                prompt_via_arg: false,
                output_file: None,
            })
        }
        "openai" | "codex" => {
            let exe = find_exe("codex", &[
                "/Users/emmanuel/.bun/bin/codex",
                "/opt/homebrew/bin/codex",
            ])?;
            let output_file = std::env::temp_dir()
                .join(format!("orch-codex-{}.txt", std::process::id()));
            Some(CliConfig {
                program: exe,
                args: vec![
                    "exec".into(),
                    "--skip-git-repo-check".into(),
                    "--color".into(),
                    "never".into(),
                    "--ephemeral".into(),
                    "--output-last-message".into(),
                    output_file.to_string_lossy().into_owned(),
                ],
                prompt_via_arg: true,
                output_file: Some(output_file),
            })
        }
        "cursor" => {
            let exe = find_exe("cursor", &["/Users/emmanuel/.local/bin/cursor"])?;
            Some(CliConfig {
                program: exe,
                args: vec!["agent".into()],
                prompt_via_arg: false,
                output_file: None,
            })
        }
        "ollama" => {
            let exe = find_exe("ollama", &[
                "/usr/local/bin/ollama",
                "/opt/homebrew/bin/ollama",
            ])?;
            Some(CliConfig {
                program: exe,
                args: vec!["run".into(), _model.into()],
                prompt_via_arg: false,
                output_file: None,
            })
        }
        "google" => {
            let exe = find_exe("gemini", &["/opt/homebrew/bin/gemini"])?;
            Some(CliConfig {
                program: exe,
                args: vec![],
                prompt_via_arg: false,
                output_file: None,
            })
        }
        _ => None,
    }
}

/// Search for an executable: first via `which`, then fallback paths.
fn find_exe(name: &str, fallbacks: &[&str]) -> Option<String> {
    if let Ok(output) = Command::new("which").arg(name).output() {
        if output.status.success() {
            let path = String::from_utf8_lossy(&output.stdout).trim().to_string();
            if !path.is_empty() {
                return Some(path);
            }
        }
    }
    for path in fallbacks {
        if std::path::Path::new(path).exists() {
            return Some(path.to_string());
        }
    }
    None
}

/// Return the path to an empty MCP config JSON file, creating it if needed.
fn empty_mcp_config_path() -> String {
    let path = std::env::temp_dir().join("orch-empty-mcp.json");
    if !path.exists() {
        let _ = std::fs::write(&path, r#"{"mcpServers": {}}"#);
    }
    path.to_string_lossy().into_owned()
}

/// Format conversation messages into a single prompt string.
fn format_messages(messages: &[ChatMessage]) -> String {
    let mut parts = Vec::new();
    for msg in messages {
        let label = match msg.role.as_str() {
            "system" => "System",
            "user" => "User",
            "assistant" => "Assistant",
            _ => &msg.role,
        };
        parts.push(format!("{}: {}", label, msg.content));
    }
    parts.join("\n\n")
}

/// Strip ANSI escape sequences from a string.
fn strip_ansi(s: &str) -> String {
    let mut result = String::with_capacity(s.len());
    let mut chars = s.chars();
    while let Some(c) = chars.next() {
        if c == '\x1b' {
            // ESC — skip the entire escape sequence.
            // Sequences end with a byte in the range 0x40-0x7E.
            for next in chars.by_ref() {
                if ('@'..='~').contains(&next) {
                    break;
                }
            }
        } else {
            result.push(c);
        }
    }
    result
}

/// Build the system prompt for the Foundation Orchestrator context.
pub fn build_system_prompt(
    provider: &str,
    model: &str,
    agents_dir: &std::path::Path,
    cwd: &std::path::Path,
) -> String {
    let agents = agents_dir.display().to_string();
    let cwd = cwd.display().to_string();

    format!(
        "You are the Foundation Orchestrator, an AI assistant embedded in a Rust TUI \
         application that manages iOS/macOS build and test pipelines.\n\n\
         Your purpose is to help the user understand, debug, and modify the Foundation \
         harness — a set of shell scripts and tools that automate building and testing \
         iOS/macOS apps using AI agents.\n\n\
         You can help with:\n\
         - Understanding the orchestrator and agent architecture\n\
         - Debugging build failures and test failures\n\
         - Suggesting code changes to the harness (the user applies them manually)\n\
         - Explaining available commands and workflows\n\n\
         Available orchestrator commands:\n\
         - /build — start the BuildAgent\n\
         - /test — start the TestAgent\n\
         - /provider <name> — switch AI provider\n\
         - /model <name> — switch AI model\n\
         - /help — show available commands\n\n\
         Current configuration:\n\
         - Provider: {}\n\
         - Model: {}\n\
         - Agents directory: {}\n\
         - Working directory: {}\n\n\
         Respond concisely and helpfully. If you suggest code changes, wrap them in \
         markdown code blocks with the file path.",
        provider, model, agents, cwd
    )
}
