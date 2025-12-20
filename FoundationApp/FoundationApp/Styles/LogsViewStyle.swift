import SwiftUI

/// Style module for LogsView following MVVM-S pattern
struct LogsViewStyle {
    // MARK: - Constants (HIG Compliant)
    static let toolbarPadding: CGFloat = 12
    static let toolbarSpacing: CGFloat = 12
    static let searchFieldPadding: CGFloat = 8
    static let searchFieldMaxWidth: CGFloat = 300
    static let searchFieldCornerRadius: CGFloat = 6
    static let pickerWidth: CGFloat = 120
    static let logPadding: CGFloat = 12
    static let logEntrySpacing: CGFloat = 4
    static let logEntryHorizontalSpacing: CGFloat = 8
    static let timestampWidth: CGFloat = 80
    static let levelBadgeWidth: CGFloat = 70
    static let levelBadgePadding: CGFloat = 4
    static let levelBadgeCornerRadius: CGFloat = 4
    
    // MARK: - Typography (Dynamic Type Support)
    static func timestampFont() -> Font {
        .system(.caption, design: .monospaced)
    }
    
    static func levelFont() -> Font {
        .system(.caption2, design: .monospaced)
    }
    
    static func logContentFont() -> Font {
        .system(.body, design: .monospaced)
    }
    
    // MARK: - Colors (Color Scheme Adaptive)
    static func toolbarBackground() -> Color {
        Color(NSColor.controlBackgroundColor)
    }
    
    static func searchFieldBackground() -> Color {
        Color(NSColor.textBackgroundColor)
    }
    
    static func logContentColor() -> Color {
        Color(NSColor.labelColor)
    }
    
    static func levelColor(for level: LogLevel) -> Color {
        switch level {
        case .error:
            return .red
        case .warning:
            return .orange
        case .success:
            return .green
        case .info:
            return .blue
        case .debug:
            return .gray
        }
    }
    
    static func levelBackgroundColor(for level: LogLevel) -> Color {
        levelColor(for: level).opacity(0.2)
    }
    
    // MARK: - Button Styles
    static func toolbarButtonStyle() -> some ButtonStyle {
        ToolbarButtonStyle()
    }
}

// MARK: - Custom Button Style
struct ToolbarButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(configuration.isPressed ? Color.gray.opacity(0.2) : Color.clear)
            .cornerRadius(4)
    }
}
