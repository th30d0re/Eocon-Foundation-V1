import SwiftUI

@main
struct FoundationApp: App {
    @StateObject private var buildAgentViewModel = BuildAgentViewModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(buildAgentViewModel)
        }
        .windowStyle(.automatic)
        .defaultSize(width: 1200, height: 800)
    }
}
