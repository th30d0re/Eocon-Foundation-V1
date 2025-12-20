import SwiftUI

/// View for displaying past BuildAgent sessions with filtering and search
struct SessionHistoryView: View {
    @EnvironmentObject var buildAgentViewModel: BuildAgentViewModel
    @State private var searchText = ""
    @State private var selectedStatus: SessionStatus? = nil
    
    private var filteredSessions: [BuildSession] {
        var sessions = buildAgentViewModel.sessions
        
        // Filter by search text
        if !searchText.isEmpty {
            sessions = sessions.filter { session in
                session.id.localizedCaseInsensitiveContains(searchText) ||
                session.config.scheme?.localizedCaseInsensitiveContains(searchText) ?? false
            }
        }
        
        // Filter by status
        if let status = selectedStatus {
            sessions = sessions.filter { $0.status == status }
        }
        
        return sessions.sorted { $0.startTime > $1.startTime }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            toolbar
            
            // Sessions Table
            Table(filteredSessions) {
                TableColumn("Date") { session in
                    Text(session.startTime, style: .date)
                        .font(SessionHistoryViewStyle.tableCellFont())
                }
                .width(min: SessionHistoryViewStyle.dateColumnWidth)
                
                TableColumn("Time") { session in
                    Text(session.startTime, style: .time)
                        .font(SessionHistoryViewStyle.tableCellFont())
                }
                .width(min: SessionHistoryViewStyle.timeColumnWidth)
                
                TableColumn("Status") { session in
                    StatusBadge(status: session.status)
                }
                .width(min: SessionHistoryViewStyle.statusColumnWidth)
                
                TableColumn("Attempts") { session in
                    Text("\(session.attempts)")
                        .font(SessionHistoryViewStyle.tableCellFont())
                }
                .width(min: SessionHistoryViewStyle.attemptsColumnWidth)
                
                TableColumn("Duration") { session in
                    Text(formattedDuration(for: session))
                        .font(SessionHistoryViewStyle.tableCellFont())
                }
                .width(min: SessionHistoryViewStyle.durationColumnWidth)
                
                TableColumn("Actions") { session in
                    HStack(spacing: SessionHistoryViewStyle.actionButtonSpacing) {
                        Button("View Logs") {
                            viewLogs(for: session)
                        }
                        .buttonStyle(SessionHistoryViewStyle.actionButtonStyle())
                        
                        Button("Open Artifacts") {
                            openArtifacts(for: session)
                        }
                        .buttonStyle(SessionHistoryViewStyle.actionButtonStyle())
                        
                        Button("Re-run") {
                            rerunSession(session)
                        }
                        .buttonStyle(SessionHistoryViewStyle.actionButtonStyle())
                    }
                }
            }
        }
        .navigationTitle("Session History")
        .onAppear {
            buildAgentViewModel.loadSessions()
        }
    }
    
    // MARK: - Toolbar
    private var toolbar: some View {
        HStack(spacing: SessionHistoryViewStyle.toolbarSpacing) {
            // Search Field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search sessions...", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, SessionHistoryViewStyle.searchFieldPadding)
            .padding(.vertical, SessionHistoryViewStyle.searchFieldPadding / 2)
            .background(SessionHistoryViewStyle.searchFieldBackground())
            .cornerRadius(SessionHistoryViewStyle.searchFieldCornerRadius)
            .frame(maxWidth: SessionHistoryViewStyle.searchFieldMaxWidth)
            
            // Status Filter
            Picker("Status", selection: $selectedStatus) {
                Text("All").tag(SessionStatus?.none)
                ForEach(SessionStatus.allCases, id: \.self) { status in
                    Text(status.displayName).tag(SessionStatus?.some(status))
                }
            }
            .pickerStyle(.menu)
            .frame(width: SessionHistoryViewStyle.pickerWidth)
            
            Spacer()
            
            Text("\(filteredSessions.count) sessions")
                .font(SessionHistoryViewStyle.countFont())
                .foregroundColor(.secondary)
        }
        .padding(SessionHistoryViewStyle.toolbarPadding)
        .background(SessionHistoryViewStyle.toolbarBackground())
    }
    
    // MARK: - Helper Functions
    private func formattedDuration(for session: BuildSession) -> String {
        guard let endTime = session.endTime else {
            return "In progress"
        }
        let duration = endTime.timeIntervalSince(session.startTime)
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? "Unknown"
    }
    
    private func viewLogs(for session: BuildSession) {
        buildAgentViewModel.loadSession(session)
        // Navigate to logs view - this would be handled by the parent view
    }
    
    private func openArtifacts(for session: BuildSession) {
        NSWorkspace.shared.selectFile(session.logsDir.path, inFileViewerRootedAtPath: "")
    }
    
    private func rerunSession(_ session: BuildSession) {
        buildAgentViewModel.config = session.config
        buildAgentViewModel.startBuild()
    }
}
