import SwiftUI

/// Style module for SessionHistoryView following MVVM-S pattern
struct SessionHistoryViewStyle {
    // MARK: - Constants (HIG Compliant)
    static let toolbarPadding: CGFloat = 12
    static let toolbarSpacing: CGFloat = 12
    static let searchFieldPadding: CGFloat = 8
    static let searchFieldMaxWidth: CGFloat = 300
    static let searchFieldCornerRadius: CGFloat = 6
    static let pickerWidth: CGFloat = 120
    static let dateColumnWidth: CGFloat = 120
    static let timeColumnWidth: CGFloat = 80
    static let statusColumnWidth: CGFloat = 100
    static let attemptsColumnWidth: CGFloat = 80
    static let durationColumnWidth: CGFloat = 100
    static let actionButtonSpacing: CGFloat = 8
    
    // MARK: - Typography (Dynamic Type Support)
    static func tableCellFont() -> Font {
        .body
    }
    
    static func countFont() -> Font {
        .caption
    }
    
    // MARK: - Colors (Color Scheme Adaptive)
    static func toolbarBackground() -> Color {
        Color(NSColor.controlBackgroundColor)
    }
    
    static func searchFieldBackground() -> Color {
        Color(NSColor.textBackgroundColor)
    }
    
    // MARK: - Button Styles
    static func actionButtonStyle() -> some ButtonStyle {
        ActionButtonStyle()
    }
}

// MARK: - Custom Button Style
struct ActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.blue.opacity(0.1))
            .foregroundColor(.blue)
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}
