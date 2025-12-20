import SwiftUI

/// Style module for ProgressView following MVVM-S pattern
struct ProgressViewStyle {
    // MARK: - Constants (HIG Compliant)
    static let standardPadding: CGFloat = 16
    static let sectionSpacing: CGFloat = 20
    static let labelSpacing: CGFloat = 8
    static let cardPadding: CGFloat = 16
    static let cornerRadius: CGFloat = 8
    static let progressBarHeight: CGFloat = 20
    static let progressBarCornerRadius: CGFloat = 10
    static let spinnerScale: CGFloat = 0.8
    static let badgeSpacing: CGFloat = 16
    static let badgePadding: CGFloat = 8
    static let badgeCornerRadius: CGFloat = 6
    static let badgeBackgroundOpacity: Double = 0.2
    
    // MARK: - Typography (Dynamic Type Support)
    static func labelFont() -> Font {
        .caption
    }
    
    static func attemptFont() -> Font {
        .system(size: 32, weight: .bold)
    }
    
    static func phaseFont() -> Font {
        .title2
    }
    
    static func timeFont() -> Font {
        .title3
    }
    
    static func badgeFont() -> Font {
        .headline
    }
    
    // MARK: - Colors (Color Scheme Adaptive)
    static func cardBackground() -> Color {
        Color(NSColor.controlBackgroundColor)
    }
    
    static func progressBarBackgroundColor() -> Color {
        Color(NSColor.controlBackgroundColor)
    }
    
    static func progressBarFillColor() -> Color {
        .blue
    }
    
    // MARK: - Animations
    static var progressAnimation: Animation {
        .easeInOut(duration: 0.3)
    }
}
