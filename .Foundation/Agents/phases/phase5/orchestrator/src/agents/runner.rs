use std::io::{BufRead, BufReader, Write};
use std::sync::mpsc::{channel, Receiver, Sender};
use std::thread;

use color_eyre::Result;
use portable_pty::{Child, CommandBuilder, MasterPty, NativePtySystem, PtySize, PtySystem};

/// Messages sent from the PTY reader thread to the UI thread.
///
/// Note: there is no `Exited` variant. EOF on the PTY only means the output
/// stream closed; the authoritative exit code is read separately via
/// `child.try_wait()` on the UI thread, avoiding a race where EOF would be
/// misreported as exit 0.
#[derive(Debug)]
pub enum RunnerMsg {
    Bytes(Vec<u8>),
    Error(String),
}

/// Specification for spawning an agent.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct AgentCmd {
    pub program: String,
    pub args: Vec<String>,
    pub env: Vec<(String, String)>,
    /// Working directory for the child (so agents resolve sibling scripts/libs).
    pub cwd: Option<String>,
}

/// Spawn an agent inside a PTY and return the child handle, the PTY master
/// (kept alive so the caller can resize it), a writer for sending input to
/// the child, and the message receiver.
pub fn spawn(
    cmd: AgentCmd,
    size: PtySize,
) -> Result<(
    Box<dyn Child + Send>,
    Box<dyn MasterPty + Send>,
    Box<dyn Write + Send>,
    Receiver<RunnerMsg>,
)> {
    let pty_system = NativePtySystem::default();
    let pair = pty_system
        .openpty(size)
        .map_err(|e| color_eyre::eyre::eyre!("openpty failed: {}", e))?;

    let mut cmd_builder = CommandBuilder::new(&cmd.program);
    for arg in &cmd.args {
        cmd_builder.arg(arg);
    }
    for (k, v) in &cmd.env {
        cmd_builder.env(k, v);
    }
    if let Some(ref dir) = cmd.cwd {
        cmd_builder.cwd(dir);
    }
    // Force color output even when under PTY (belt-and-suspenders).
    cmd_builder.env("CLICOLOR_FORCE", "1");
    cmd_builder.env("FORCE_COLOR", "1");

    let child = pair
        .slave
        .spawn_command(cmd_builder)
        .map_err(|e| color_eyre::eyre::eyre!("spawn_command failed: {}", e))?;
    drop(pair.slave);

    let writer = pair
        .master
        .take_writer()
        .map_err(|e| color_eyre::eyre::eyre!("take_writer failed: {}", e))?;

    let (tx, rx): (Sender<RunnerMsg>, Receiver<RunnerMsg>) = channel();

    let mut reader = pair
        .master
        .try_clone_reader()
        .map_err(|e| color_eyre::eyre::eyre!("clone reader failed: {}", e))?;
    thread::spawn(move || {
        let mut buf_reader = BufReader::new(&mut reader);
        let mut buf = Vec::new();
        loop {
            buf.clear();
            match buf_reader.read_until(b'\n', &mut buf) {
                Ok(0) => break, // EOF: stream closed; exit code comes from try_wait.
                Ok(n) => {
                    if tx.send(RunnerMsg::Bytes(buf[..n].to_vec())).is_err() {
                        break;
                    }
                }
                Err(e) => {
                    let _ = tx.send(RunnerMsg::Error(format!("PTY read error: {}", e)));
                    break;
                }
            }
        }
    });

    Ok((child, pair.master, writer, rx))
}

/// Wait for the child to exit and return its status code.
pub fn wait_child(child: &mut Box<dyn Child + Send>) -> Result<i32> {
    let status = child.wait()?;
    Ok(status.exit_code() as i32)
}

/// Kill a running child process.
pub fn kill_child(child: &mut Box<dyn Child + Send>) -> Result<()> {
    child.kill()?;
    Ok(())
}
