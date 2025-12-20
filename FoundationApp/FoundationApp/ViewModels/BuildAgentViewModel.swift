import Foundation
import Combine
import SwiftUI

/// Main ViewModel for BuildAgent orchestration
class BuildAgentViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var isRunning: Bool = false
    @Published var currentSession: BuildSession? = nil
    @Published var progress: BuildProgress = BuildProgress()
    @Published var logs: [LogEntry] = []
    @Published var config: BuildAgentConfig = BuildAgentConfig()
    @Published var error: BuildAgentError? = nil
    @Published var sessions: [BuildSession] = []
    @Published var isAuthenticated: Bool = false
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private var startTime: Date?
    
    // MARK: - Public Methods
    func startBuild() {
        guard !isRunning else { return }
        
        isRunning = true
        startTime = Date()
        currentSession = BuildSession(
            status: .inProgress,
            attempts: 0,
            config: config
        )
        progress = BuildProgress(
            currentAttempt: 1,
            maxAttempts: config.maxAttempts,
            currentPhase: .gatheringContext,
            elapsedTime: 0
        )
        logs.removeAll()
        
        // Mock implementation - would call BuildAgentService here
        simulateBuild()
    }
    
    func stopBuild() {
        isRunning = false
        currentSession?.status = .humanIntervention
        currentSession?.endTime = Date()
    }
    
    func loadSession(_ session: BuildSession) {
        currentSession = session
        config = session.config
        // Load logs from session.logsDir
    }
    
    func saveConfig() {
        // Mock implementation - would persist to UserDefaults or file
        UserDefaults.standard.set(try? JSONEncoder().encode(config), forKey: "buildAgentConfig")
    }
    
    func loadConfig() {
        // Mock implementation - would load from UserDefaults or file
        if let data = UserDefaults.standard.data(forKey: "buildAgentConfig"),
           let loadedConfig = try? JSONDecoder().decode(BuildAgentConfig.self, from: data) {
            config = loadedConfig
        }
    }
    
    func loadSessions() {
        // Mock implementation - would scan Artifacts directory
        sessions = [
            BuildSession(
                id: "session-1",
                startTime: Date().addingTimeInterval(-3600),
                endTime: Date().addingTimeInterval(-3000),
                status: .success,
                attempts: 2
            ),
            BuildSession(
                id: "session-2",
                startTime: Date().addingTimeInterval(-1800),
                endTime: Date().addingTimeInterval(-1200),
                status: .failed,
                attempts: 3
            )
        ]
    }
    
    func deleteSession(_ session: BuildSession) {
        sessions.removeAll { $0.id == session.id }
        // Would also delete files from disk
    }
    
    // MARK: - Private Methods
    private func simulateBuild() {
        // Mock build simulation
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self, self.isRunning else {
                timer.invalidate()
                return
            }
            
            // Update elapsed time
            if let start = self.startTime {
                self.progress.elapsedTime = Date().timeIntervalSince(start)
            }
            
            // Simulate progress
            self.logs.append(LogEntry(
                content: "Building... \(Int(self.progress.elapsedTime))s",
                level: .info
            ))
            
            // Simulate phase changes
            if Int(self.progress.elapsedTime) % 10 == 0 {
                switch self.progress.currentPhase {
                case .gatheringContext:
                    self.progress.currentPhase = .generatingCode
                case .generatingCode:
                    self.progress.currentPhase = .building
                case .building:
                    self.progress.currentPhase = .testing
                case .testing:
                    self.progress.currentPhase = .completed
                    self.isRunning = false
                    self.currentSession?.status = .success
                    self.currentSession?.endTime = Date()
                    timer.invalidate()
                default:
                    break
                }
            }
        }
    }
}

// MARK: - BuildAgentError
enum BuildAgentError: LocalizedError {
    case scriptNotFound(path: String)
    case executionFailed(exitCode: Int32, stderr: String)
    case authenticationRequired(provider: AIProvider)
    case invalidConfiguration(message: String)
    case permissionDenied(path: String)
    
    var errorDescription: String? {
        switch self {
        case .scriptNotFound(let path):
            return "BuildAgent.sh not found at: \(path)"
        case .executionFailed(let code, let stderr):
            return "Build failed with exit code \(code): \(stderr)"
        case .authenticationRequired(let provider):
            return "\(provider.rawValue) requires authentication. Please configure API key."
        case .invalidConfiguration(let message):
            return "Invalid configuration: \(message)"
        case .permissionDenied(let path):
            return "Permission denied accessing: \(path)"
        }
    }
}
