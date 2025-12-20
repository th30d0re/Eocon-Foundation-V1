import SwiftUI

/// Real-time progress display during BuildAgent execution
struct ProgressView: View {
    @EnvironmentObject var buildAgentViewModel: BuildAgentViewModel
    
    var body: some View {
        VStack(spacing: ProgressViewStyle.sectionSpacing) {
            // Attempt Indicator
            attemptIndicator
            
            // Phase Display
            phaseDisplay
            
            // Progress Bar
            progressBar
            
            // Elapsed Time
            elapsedTime
            
            // Status Badges
            statusBadges
        }
        .padding(ProgressViewStyle.standardPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .navigationTitle("Progress")
    }
    
    // MARK: - Attempt Indicator
    private var attemptIndicator: some View {
        VStack(spacing: ProgressViewStyle.labelSpacing) {
            Text("Current Attempt")
                .font(ProgressViewStyle.labelFont())
                .foregroundColor(.secondary)
            Text("\(buildAgentViewModel.progress.currentAttempt) / \(buildAgentViewModel.progress.maxAttempts)")
                .font(ProgressViewStyle.attemptFont())
        }
        .frame(maxWidth: .infinity)
        .padding(ProgressViewStyle.cardPadding)
        .background(ProgressViewStyle.cardBackground())
        .cornerRadius(ProgressViewStyle.cornerRadius)
    }
    
    // MARK: - Phase Display
    private var phaseDisplay: some View {
        VStack(alignment: .leading, spacing: ProgressViewStyle.labelSpacing) {
            Text("Current Phase")
                .font(ProgressViewStyle.labelFont())
                .foregroundColor(.secondary)
            HStack {
                if buildAgentViewModel.isRunning {
                    ProgressView()
                        .scaleEffect(ProgressViewStyle.spinnerScale)
                }
                Text(buildAgentViewModel.progress.currentPhase.displayName)
                    .font(ProgressViewStyle.phaseFont())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(ProgressViewStyle.cardPadding)
        .background(ProgressViewStyle.cardBackground())
        .cornerRadius(ProgressViewStyle.cornerRadius)
    }
    
    // MARK: - Progress Bar
    private var progressBar: some View {
        VStack(alignment: .leading, spacing: ProgressViewStyle.labelSpacing) {
            Text("Progress")
                .font(ProgressViewStyle.labelFont())
                .foregroundColor(.secondary)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: ProgressViewStyle.progressBarCornerRadius)
                        .fill(ProgressViewStyle.progressBarBackgroundColor())
                    
                    // Progress fill
                    RoundedRectangle(cornerRadius: ProgressViewStyle.progressBarCornerRadius)
                        .fill(ProgressViewStyle.progressBarFillColor())
                        .frame(width: geometry.size.width * progressPercentage)
                        .animation(ProgressViewStyle.progressAnimation, value: progressPercentage)
                }
            }
            .frame(height: ProgressViewStyle.progressBarHeight)
        }
        .padding(ProgressViewStyle.cardPadding)
        .background(ProgressViewStyle.cardBackground())
        .cornerRadius(ProgressViewStyle.cornerRadius)
    }
    
    // MARK: - Elapsed Time
    private var elapsedTime: some View {
        VStack(spacing: ProgressViewStyle.labelSpacing) {
            Text("Elapsed Time")
                .font(ProgressViewStyle.labelFont())
                .foregroundColor(.secondary)
            Text(formattedElapsedTime)
                .font(ProgressViewStyle.timeFont())
        }
        .frame(maxWidth: .infinity)
        .padding(ProgressViewStyle.cardPadding)
        .background(ProgressViewStyle.cardBackground())
        .cornerRadius(ProgressViewStyle.cornerRadius)
    }
    
    // MARK: - Status Badges
    private var statusBadges: some View {
        HStack(spacing: ProgressViewStyle.badgeSpacing) {
            ProgressStatusBadge(
                title: "Status",
                value: buildAgentViewModel.currentSession?.status.displayName ?? "Not Started",
                color: statusColor
            )
            
            if let message = buildAgentViewModel.progress.message, !message.isEmpty {
                ProgressStatusBadge(
                    title: "Message",
                    value: message,
                    color: .blue
                )
            }
        }
    }
    
    // MARK: - Computed Properties
    private var progressPercentage: Double {
        guard buildAgentViewModel.progress.maxAttempts > 0 else { return 0 }
        return Double(buildAgentViewModel.progress.currentAttempt) / Double(buildAgentViewModel.progress.maxAttempts)
    }
    
    private var formattedElapsedTime: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: buildAgentViewModel.progress.elapsedTime) ?? "0s"
    }
    
    private var statusColor: Color {
        guard let status = buildAgentViewModel.currentSession?.status else {
            return .gray
        }
        switch status {
        case .success:
            return .green
        case .failed:
            return .red
        case .inProgress:
            return .blue
        case .humanIntervention:
            return .orange
        }
    }
}

// MARK: - Progress Status Badge Component
struct ProgressStatusBadge: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: ProgressViewStyle.labelSpacing) {
            Text(title)
                .font(ProgressViewStyle.labelFont())
                .foregroundColor(.secondary)
            Text(value)
                .font(ProgressViewStyle.badgeFont())
                .foregroundColor(color)
                .padding(.horizontal, ProgressViewStyle.badgePadding)
                .padding(.vertical, ProgressViewStyle.badgePadding / 2)
                .background(color.opacity(ProgressViewStyle.badgeBackgroundOpacity))
                .cornerRadius(ProgressViewStyle.badgeCornerRadius)
        }
    }
}
