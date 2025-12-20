import Foundation

/// AI provider enum for BuildAgent
enum AIProvider: String, Codable, CaseIterable {
    case cursor = "cursor"
    case claude = "claude"
    case codex = "codex"
    case gemini = "gemini"
    case aider = "aider"
}
