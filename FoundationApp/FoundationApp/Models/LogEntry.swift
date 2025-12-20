import Foundation

/// Log entry model
struct LogEntry: Identifiable {
    let id: UUID
    let content: String
    let level: LogLevel
    let timestamp: Date
    
    init(content: String, level: LogLevel = .info, timestamp: Date = Date()) {
        self.id = UUID()
        self.content = content
        self.level = level
        self.timestamp = timestamp
    }
}
