import SwiftUI

/// Style module for ArtifactsView following MVVM-S pattern
struct ArtifactsViewStyle {
    // MARK: - Constants (HIG Compliant)
    static let sessionListMinWidth: CGFloat = 250
    static let fileListMinWidth: CGFloat = 200
    static let sectionTitlePadding: CGFloat = 12
    static let headerPadding: CGFloat = 16
    static let headerSpacing: CGFloat = 4
    static let rowPadding: CGFloat = 8
    static let rowSpacing: CGFloat = 4
    static let previewPadding: CGFloat = 16
    static let previewSpacing: CGFloat = 8
    
    // MARK: - Typography (Dynamic Type Support)
    static func sectionTitleFont() -> Font {
        .headline
    }
    
    static func sessionTitleFont() -> Font {
        .title3
    }
    
    static func sessionSubtitleFont() -> Font {
        .caption
    }
    
    static func rowTitleFont() -> Font {
        .body
    }
    
    static func rowSubtitleFont() -> Font {
        .caption
    }
    
    static func fileRowFont() -> Font {
        .body
    }
    
    static func previewTitleFont() -> Font {
        .headline
    }
    
    static func previewContentFont() -> Font {
        .system(.body, design: .monospaced)
    }
    
    static func emptyStateFont() -> Font {
        .title2
    }
    
    // MARK: - Colors (Color Scheme Adaptive)
    static func headerBackground() -> Color {
        Color(NSColor.controlBackgroundColor)
    }
    
    // MARK: - Button Styles
    static func actionButtonStyle() -> some ButtonStyle {
        ActionButtonStyle()
    }
    
    static func destructiveButtonStyle() -> some ButtonStyle {
        DestructiveButtonStyle()
    }
}

// MARK: - Custom Button Styles
struct ActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(6)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

struct DestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.red)
            .foregroundColor(.white)
            .cornerRadius(6)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}
