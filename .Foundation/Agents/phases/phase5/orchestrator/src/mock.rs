use crate::app::{AgentState, App, InteractionMessage, Phase};
use crate::ui::theme::Voice;

/// Seed mock interaction messages.
pub fn seed_interaction(app: &mut App) {
    app.interaction.push(InteractionMessage {
        voice: Voice::Agent,
        text: "BuildVerify ready.".to_string(),
    });
    app.interaction.push(InteractionMessage {
        voice: Voice::User,
        text: "start build".to_string(),
    });
    app.interaction.push(InteractionMessage {
        voice: Voice::Agent,
        text: "Starting build phase...".to_string(),
    });
}

/// Generate a mock colored output chunk for the PTY screen.
pub fn mock_chunk(_tick: u64) -> Vec<u8> {
    // A simple ANSI-colored line that cycles through states.
    let lines = [
        "\x1b[32m[PASS]\x1b[0m compile_main.swift\r\n",
        "\x1b[33m[WARN]\x1b[0m deprecated API usage\r\n",
        "\x1b[31m[FAIL]\x1b[0m test_crash.swift:42\r\n",
        "\x1b[36m[INFO]\x1b[0m linking binary...\r\n",
        "\x1b[35m[DEBUG]\x1b[0m optimization pass 3\r\n",
    ];
    let idx = (_tick as usize) % lines.len();
    lines[idx].as_bytes().to_vec()
}

/// Advance the mock state machine.
pub fn update_mock(app: &mut App) {
    app.tick_count += 1;

    // Feed a mock output line every few ticks.
    if app.tick_count % 3 == 0 {
        let chunk = mock_chunk(app.tick_count);
        app.screen.advance(&chunk);
    }

    // Simulate phase progression after enough ticks.
    if app.tick_count == 60 {
        app.phase = Phase::Build;
        app.agent_state = AgentState::Acting;
    } else if app.tick_count == 120 {
        app.phase = Phase::Test;
        app.agent_state = AgentState::Acting;
    } else if app.tick_count == 180 {
        app.phase = Phase::Complete;
        app.agent_state = AgentState::Idle;
    }
}
