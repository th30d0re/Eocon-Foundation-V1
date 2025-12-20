import SwiftUI

/// Reusable status badge component
struct StatusBadge: View {
    let status: SessionStatus
    
    var body: some View {
        Text(status.displayName)
            .font(.caption)
            .foregroundColor(statusColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.2))
            .cornerRadius(6)
    }
    
    private var statusColor: Color {
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
