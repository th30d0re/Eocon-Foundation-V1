import Foundation

/// Session status enum
enum SessionStatus: String, Codable, CaseIterable {
    case success = "success"
    case failed = "failed"
    case inProgress = "in_progress"
    case humanIntervention = "human_intervention"
    
    var displayName: String {
        switch self {
        case .success:
            return "Success"
        case .failed:
            return "Failed"
        case .inProgress:
            return "In Progress"
        case .humanIntervention:
            return "Human Intervention"
        }
    }
}
