import Foundation

/// Build phase enum for progress tracking
enum BuildPhase: String, Codable {
    case gatheringContext = "gathering_context"
    case generatingCode = "generating_code"
    case building = "building"
    case testing = "testing"
    case completed = "completed"
    case failed = "failed"
    
    var displayName: String {
        switch self {
        case .gatheringContext:
            return "Gathering Context"
        case .generatingCode:
            return "Generating Code"
        case .building:
            return "Building"
        case .testing:
            return "Testing"
        case .completed:
            return "Completed"
        case .failed:
            return "Failed"
        }
    }
}
