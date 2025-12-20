import Foundation

/// Build session model
struct BuildSession: Identifiable, Codable {
    let id: String
    let startTime: Date
    var endTime: Date?
    var status: SessionStatus
    var attempts: Int
    var config: BuildAgentConfig
    var logsDir: URL
    var statusDir: URL
    
    init(id: String = UUID().uuidString,
         startTime: Date = Date(),
         status: SessionStatus = .inProgress,
         attempts: Int = 0,
         config: BuildAgentConfig = BuildAgentConfig(),
         logsDir: URL = FileManager.default.temporaryDirectory,
         statusDir: URL = FileManager.default.temporaryDirectory) {
        self.id = id
        self.startTime = startTime
        self.status = status
        self.attempts = attempts
        self.config = config
        self.logsDir = logsDir
        self.statusDir = statusDir
    }
}
