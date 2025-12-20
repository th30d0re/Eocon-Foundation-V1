import Foundation

/// BuildAgent configuration model
struct BuildAgentConfig: Codable {
    // Input
    var planFile: String?
    var promptFile: String?
    var promptString: String?
    var contextPaths: [String]
    
    // AI Provider
    var aiProvider: AIProvider
    var aiModel: String?
    
    // Build
    var scheme: String?
    var targetID: String?
    var destination: String?
    var buildConfiguration: BuildConfiguration
    var derivedDataPath: String?
    
    // Execution
    var maxAttempts: Int
    var streamOutput: Bool
    var yoloMode: Bool
    var skipLint: Bool
    var verbose: Bool
    var skipChatIDCapture: Bool
    
    // Advanced
    var artifactsDir: String?
    var swiftDocsPath: String?
    
    init() {
        self.contextPaths = []
        self.aiProvider = .cursor
        self.buildConfiguration = .debug
        self.maxAttempts = 3
        self.streamOutput = false
        self.yoloMode = false
        self.skipLint = false
        self.verbose = false
        self.skipChatIDCapture = false
    }
}
