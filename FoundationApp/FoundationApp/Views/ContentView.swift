import SwiftUI

/// Main container view with sidebar navigation
struct ContentView: View {
    @EnvironmentObject var buildAgentViewModel: BuildAgentViewModel
    @State private var selectedSection: NavigationSection = .configuration
    
    enum NavigationSection: String, CaseIterable {
        case configuration = "Configuration"
        case progress = "Progress"
        case logs = "Logs"
        case artifacts = "Artifacts"
        case history = "History"
    }
    
    var body: some View {
        NavigationSplitView {
            // Sidebar
            List(selection: $selectedSection) {
                ForEach(NavigationSection.allCases, id: \.self) { section in
                    NavigationLink(value: section) {
                        Label(section.rawValue, systemImage: ContentViewStyle.icon(for: section))
                    }
                }
            }
            .navigationTitle("BuildAgent")
            .frame(minWidth: ContentViewStyle.sidebarMinWidth)
        } detail: {
            // Main content area
            Group {
                switch selectedSection {
                case .configuration:
                    ConfigurationView()
                case .progress:
                    ProgressView()
                case .logs:
                    LogsView()
                case .artifacts:
                    ArtifactsView()
                case .history:
                    SessionHistoryView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(
            minWidth: ContentViewStyle.windowMinWidth,
            minHeight: ContentViewStyle.windowMinHeight
        )
    }
}
