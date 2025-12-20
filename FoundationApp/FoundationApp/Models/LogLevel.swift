import Foundation

/// Log level enum
enum LogLevel: String, Codable, CaseIterable {
    case debug = "debug"
    case info = "info"
    case success = "success"
    case warning = "warning"
    case error = "error"
    
    var displayName: String {
        rawValue.capitalized
    }
}
