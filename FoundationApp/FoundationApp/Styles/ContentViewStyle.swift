import SwiftUI

/// Style module for ContentView following MVVM-S pattern
struct ContentViewStyle {
    // MARK: - Constants (HIG Compliant)
    static let sidebarMinWidth: CGFloat = 200
    static let windowMinWidth: CGFloat = 1000
    static let windowMinHeight: CGFloat = 600
    
    // MARK: - Icons
    static func icon(for section: ContentView.NavigationSection) -> String {
        switch section {
        case .configuration:
            return "gear"
        case .progress:
            return "chart.bar.fill"
        case .logs:
            return "doc.text.fill"
        case .artifacts:
            return "folder.fill"
        case .history:
            return "clock.fill"
        }
    }
}
