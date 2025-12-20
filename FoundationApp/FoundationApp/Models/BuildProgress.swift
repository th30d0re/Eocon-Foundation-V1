import Foundation

/// Build progress model
struct BuildProgress {
    var currentAttempt: Int
    var maxAttempts: Int
    var currentPhase: BuildPhase
    var elapsedTime: TimeInterval
    var message: String
    
    init(currentAttempt: Int = 0,
         maxAttempts: Int = 3,
         currentPhase: BuildPhase = .gatheringContext,
         elapsedTime: TimeInterval = 0,
         message: String = "") {
        self.currentAttempt = currentAttempt
        self.maxAttempts = maxAttempts
        self.currentPhase = currentPhase
        self.elapsedTime = elapsedTime
        self.message = message
    }
}
