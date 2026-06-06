use std::sync::mpsc::Receiver;
use std::time::Duration;

use crossterm::event::{self, Event, KeyCode, KeyEvent, KeyModifiers};

use crate::action::Action;
use crate::agents::runner::RunnerMsg;

pub struct EventHandler {
    pub rx: Receiver<RunnerMsg>,
    tick_rate: Duration,
}

impl EventHandler {
    pub fn new(rx: Receiver<RunnerMsg>, tick_rate_ms: u64) -> Self {
        Self {
            rx,
            tick_rate: Duration::from_millis(tick_rate_ms),
        }
    }

    /// Replace the underlying receiver (e.g., when swapping from build to test agent).
    pub fn replace_rx(&mut self, rx: Receiver<RunnerMsg>) {
        self.rx = rx;
    }

    /// Poll for the next action. Blocks up to `tick_rate` waiting for
    /// crossterm events, then non-blockingly drains the agent channel.
    pub fn next(&self) -> Action {
        if event::poll(self.tick_rate).unwrap_or(false) {
            if let Ok(event) = event::read() {
                match event {
                    Event::Key(key) => return map_key(key),
                    Event::Resize(cols, rows) => return Action::Resize(cols, rows),
                    _ => {}
                }
            }
        }

        // Drain agent messages (non-blocking)
        match self.rx.try_recv() {
            Ok(RunnerMsg::Bytes(buf)) => Action::AgentBytes(buf),
            Ok(RunnerMsg::Error(msg)) => Action::AgentError(msg),
            Err(_) => Action::Tick,
        }
    }
}

fn map_key(key: KeyEvent) -> Action {
    match key.code {
        // Global shortcuts — never go to input bar
        KeyCode::Esc => Action::Quit,
        KeyCode::Tab => {
            if key.modifiers.contains(KeyModifiers::SHIFT) {
                Action::ShiftTab
            } else {
                Action::Tab
            }
        }
        KeyCode::BackTab => Action::ShiftTab,
        KeyCode::Char('c') if key.modifiers.contains(KeyModifiers::CONTROL) => Action::Abort,

        // Note: 'y' and 'n' are NOT global shortcuts — they are regular input
        // characters. Use /yes and /no slash-commands (or Enter) to respond.

        // Command picker navigation
        KeyCode::Up => Action::PickerUp,
        KeyCode::Down => Action::PickerDown,

        // Input bar editing
        KeyCode::Backspace => Action::InputBackspace,
        KeyCode::Enter => Action::InputSubmit,
        KeyCode::Left => {
            if key.modifiers.contains(KeyModifiers::SHIFT) {
                Action::FocusLeft
            } else {
                Action::InputCursorLeft
            }
        }
        KeyCode::Right => {
            if key.modifiers.contains(KeyModifiers::SHIFT) {
                Action::FocusRight
            } else {
                Action::InputCursorRight
            }
        }

        // Scrolling
        KeyCode::PageUp => {
            if key.modifiers.contains(KeyModifiers::SHIFT) {
                Action::OutputScrollUp
            } else {
                Action::ScrollUp
            }
        }
        KeyCode::PageDown => {
            if key.modifiers.contains(KeyModifiers::SHIFT) {
                Action::OutputScrollDown
            } else {
                Action::ScrollDown
            }
        }

        // Everything else goes to the input bar
        KeyCode::Char(c) => Action::InputChar(c),
        _ => Action::Tick,
    }
}
