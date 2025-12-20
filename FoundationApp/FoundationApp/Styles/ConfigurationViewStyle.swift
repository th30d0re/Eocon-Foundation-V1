import SwiftUI

/// Style module for ConfigurationView following MVVM-S pattern
struct ConfigurationViewStyle {
    // MARK: - Constants (HIG Compliant)
    static let standardPadding: CGFloat = 16
    static let sectionSpacing: CGFloat = 20
    static let fieldSpacing: CGFloat = 12
    static let labelSpacing: CGFloat = 4
    static let groupBoxPadding: CGFloat = 12
    static let textEditorHeight: CGFloat = 100
    static let labelWidth: CGFloat = 150
    static let stepperValueWidth: CGFloat = 30
    static let statusIndicatorSize: CGFloat = 8
    static let buttonMinHeight: CGFloat = 44 // HIG minimum
    
    // MARK: - Typography (Dynamic Type Support)
    static func labelFont() -> Font {
        .headline
    }
    
    static func bodyFont() -> Font {
        .body
    }
    
    static func captionFont() -> Font {
        .caption
    }
    
    // MARK: - Colors (Color Scheme Adaptive)
    static func authenticationStatusColor(isAuthenticated: Bool) -> Color {
        isAuthenticated ? .green : .red
    }
    
    static func primaryButtonColor() -> Color {
        .blue
    }
    
    static func secondaryButtonColor() -> Color {
        .gray
    }
    
    // MARK: - Button Styles
    static func primaryButtonStyle() -> some ButtonStyle {
        PrimaryButtonStyle()
    }
    
    static func secondaryButtonStyle() -> some ButtonStyle {
        SecondaryButtonStyle()
    }
}

// MARK: - Custom Button Styles
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, ConfigurationViewStyle.standardPadding)
            .padding(.vertical, ConfigurationViewStyle.standardPadding / 2)
            .background(ConfigurationViewStyle.primaryButtonColor())
            .foregroundColor(.white)
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .frame(minHeight: ConfigurationViewStyle.buttonMinHeight)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, ConfigurationViewStyle.standardPadding)
            .padding(.vertical, ConfigurationViewStyle.standardPadding / 2)
            .background(ConfigurationViewStyle.secondaryButtonColor())
            .foregroundColor(.white)
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .frame(minHeight: ConfigurationViewStyle.buttonMinHeight)
    }
}
