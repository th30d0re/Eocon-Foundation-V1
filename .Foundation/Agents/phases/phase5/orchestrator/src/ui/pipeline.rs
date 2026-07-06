use ratatui::{
    style::{Color, Modifier, Style},
    text::{Line, Span},
    widgets::{Block, Borders, Paragraph},
};

use crate::app::{App, Phase, StageStatus};
use crate::pipeline_engine::{PhaseStatus, PipelinePhase};

/// Render the pipeline stage tracker.
/// When bottom is expanded (Shift+Tab), shows the unified build+test pipeline.
/// Otherwise shows only the active agent's pipeline.
pub fn pipeline_tracker(app: &App) -> Paragraph<'_> {
    if app.pipeline_state.is_some() || app.pipeline_running {
        foundation_pipeline_tracker(app)
    } else if app.bottom_expanded {
        unified_pipeline_tracker(app)
    } else if app.phase == Phase::Build || has_active_build_stages(app) {
        build_pipeline_tracker(app)
    } else {
        test_pipeline_tracker(app)
    }
}

fn test_pipeline_tracker(app: &App) -> Paragraph<'_> {
    let mut spans: Vec<Span<'_>> = Vec::new();

    for (idx, stage) in app.pipeline_stages.iter().enumerate() {
        if idx > 0 {
            spans.push(Span::styled(" │ ", Style::default().fg(Color::DarkGray)));
        }
        let (icon, color) = stage_icon_color(stage.status, app.tick_count);
        let label = stage_label(stage);
        let style = Style::default().fg(color).add_modifier(Modifier::BOLD);
        spans.push(Span::styled(format!("{} ", icon), style));
        spans.push(Span::styled(label, style));
        if stage.coverage > 0 && stage.status == StageStatus::Completed {
            spans.push(Span::styled(
                format!(" {}%", stage.coverage),
                Style::default().fg(Color::Cyan),
            ));
        }
    }

    Paragraph::new(Line::from(spans))
        .block(
            Block::default()
                .title(" Phase 5 Pipeline ")
                .title_style(Style::default().fg(Color::Cyan).add_modifier(Modifier::BOLD))
                .borders(Borders::TOP)
                .border_style(Style::default().fg(Color::DarkGray)),
        )
}

fn build_pipeline_tracker(app: &App) -> Paragraph<'_> {
    let mut spans: Vec<Span<'_>> = Vec::new();

    for (idx, stage) in app.build_stages.iter().enumerate() {
        if idx > 0 {
            spans.push(Span::styled(" │ ", Style::default().fg(Color::DarkGray)));
        }
        let (icon, color) = stage_icon_color(stage.status, app.tick_count);
        let mut label = stage.label.to_string();
        if stage.key == "repair" && stage.coverage > 0 {
            label = format!("{}({}/?)", stage.label, stage.coverage);
        } else if stage.duration > 0 && stage.status != StageStatus::Pending {
            label = format!("{}({}s)", stage.label, stage.duration);
        }
        let style = Style::default().fg(color).add_modifier(Modifier::BOLD);
        spans.push(Span::styled(format!("{} ", icon), style));
        spans.push(Span::styled(label, style));
    }

    Paragraph::new(Line::from(spans))
        .block(
            Block::default()
                .title(" Build Pipeline ")
                .title_style(Style::default().fg(Color::Magenta).add_modifier(Modifier::BOLD))
                .borders(Borders::TOP)
                .border_style(Style::default().fg(Color::DarkGray)),
        )
}

fn unified_pipeline_tracker(app: &App) -> Paragraph<'_> {
    let mut spans: Vec<Span<'_>> = Vec::new();

    // Build stages first
    for (idx, stage) in app.build_stages.iter().enumerate() {
        if idx > 0 {
            spans.push(Span::styled(" │ ", Style::default().fg(Color::DarkGray)));
        }
        let (icon, color) = stage_icon_color(stage.status, app.tick_count);
        let mut label = stage.label.to_string();
        if stage.key == "repair" && stage.coverage > 0 {
            label = format!("{}({}/?)", stage.label, stage.coverage);
        } else if stage.duration > 0 && stage.status != StageStatus::Pending {
            label = format!("{}({}s)", stage.label, stage.duration);
        }
        let style = Style::default().fg(color).add_modifier(Modifier::BOLD);
        spans.push(Span::styled(format!("{} ", icon), style));
        spans.push(Span::styled(label, style));
    }

    // Separator between build and test
    spans.push(Span::styled(
        "  →  ",
        Style::default().fg(Color::White).add_modifier(Modifier::BOLD),
    ));

    // Test stages
    for (idx, stage) in app.pipeline_stages.iter().enumerate() {
        if idx > 0 {
            spans.push(Span::styled(" │ ", Style::default().fg(Color::DarkGray)));
        }
        let (icon, color) = stage_icon_color(stage.status, app.tick_count);
        let label = stage_label(stage);
        let style = Style::default().fg(color).add_modifier(Modifier::BOLD);
        spans.push(Span::styled(format!("{} ", icon), style));
        spans.push(Span::styled(label, style));
        if stage.coverage > 0 && stage.status == StageStatus::Completed {
            spans.push(Span::styled(
                format!(" {}%", stage.coverage),
                Style::default().fg(Color::Cyan),
            ));
        }
    }

    Paragraph::new(Line::from(spans))
        .block(
            Block::default()
                .title(" Foundation Pipeline ")
                .title_style(Style::default().fg(Color::White).add_modifier(Modifier::BOLD))
                .borders(Borders::TOP)
                .border_style(Style::default().fg(Color::DarkGray)),
        )
}

fn stage_icon_color(status: StageStatus, tick_count: u64) -> (&'static str, Color) {
    match status {
        StageStatus::Pending => ("○", Color::DarkGray),
        StageStatus::Running => {
            let frames = &["◐", "◓", "◑", "◒"];
            let frame = frames[tick_count as usize % frames.len()];
            (frame, Color::Yellow)
        }
        StageStatus::Completed => ("●", Color::Green),
        StageStatus::Failed => ("✕", Color::Red),
        StageStatus::Skipped => ("⊘", Color::Gray),
    }
}

fn stage_label(stage: &crate::app::PipelineStage) -> String {
    if stage.duration > 0 && stage.status != StageStatus::Pending {
        format!("{}({}s)", stage.label, stage.duration)
    } else {
        stage.label.to_string()
    }
}

fn foundation_pipeline_tracker(app: &App) -> Paragraph<'_> {
    let mut spans: Vec<Span<'_>> = Vec::new();

    for idx in 0..=5 {
        if idx > 0 {
            spans.push(Span::styled(" → ", Style::default().fg(Color::DarkGray)));
        }
        let (status, active) = app
            .pipeline_state
            .as_ref()
            .map(|s| {
                let st = s.phases.get(idx).map(|p| p.status).unwrap_or(PhaseStatus::Pending);
                let active = app.pipeline_running
                    && s.current_phase == Some(idx as u32)
                    && (st == PhaseStatus::Running || st == PhaseStatus::AwaitingApproval);
                (st, active)
            })
            .unwrap_or((PhaseStatus::Pending, false));

        let name = PipelinePhase::from_index(idx)
            .map(|p| p.display_name())
            .unwrap_or("?");
        let (icon, color) = phase_status_icon_color(status, app.tick_count);
        let style = if active || status == PhaseStatus::AwaitingApproval {
            Style::default()
                .fg(color)
                .add_modifier(Modifier::BOLD)
                .add_modifier(Modifier::UNDERLINED)
        } else {
            Style::default().fg(color)
        };
        spans.push(Span::styled(format!("{} {}", icon, name), style));
    }

    Paragraph::new(Line::from(spans))
        .block(
            Block::default()
                .title(" Foundation Pipeline ")
                .title_style(Style::default().fg(Color::White).add_modifier(Modifier::BOLD))
                .borders(Borders::TOP)
                .border_style(Style::default().fg(Color::DarkGray)),
        )
}

fn phase_status_icon_color(status: PhaseStatus, tick_count: u64) -> (&'static str, Color) {
    match status {
        PhaseStatus::Pending => ("○", Color::DarkGray),
        PhaseStatus::Running => {
            let frames = &["◐", "◓", "◑", "◒"];
            let frame = frames[tick_count as usize % frames.len()];
            (frame, Color::Yellow)
        }
        PhaseStatus::AwaitingApproval => ("⏸", Color::Magenta),
        PhaseStatus::Approved => ("✓", Color::Green),
        PhaseStatus::Succeeded => ("✓", Color::Green),
        PhaseStatus::Failed => ("✕", Color::Red),
        PhaseStatus::HumanIntervention => ("⚠", Color::Red),
        PhaseStatus::Skipped => ("⊘", Color::Gray),
    }
}

fn has_active_build_stages(app: &App) -> bool {
    app.build_stages.iter().any(|s| s.status != StageStatus::Pending)
}

/// Whether the pipeline tracker should be shown.
pub fn should_show(app: &App) -> bool {
    app.pipeline_state.is_some()
        || app.pipeline_running
        || app.phase == Phase::Build
        || app.phase == Phase::Test
        || has_active_build_stages(app)
        || app.pipeline_stages.iter().any(|s| s.status != StageStatus::Pending)
}
