import SwiftUI

/// View for displaying BuildAgent output logs with filtering and search
struct LogsView: View {
    @EnvironmentObject var buildAgentViewModel: BuildAgentViewModel
    @State private var searchText = ""
    @State private var selectedLogLevel: LogLevel? = nil
    @State private var autoScroll = true
    @State private var scrollProxy: ScrollViewReader?
    
    private var filteredLogs: [LogEntry] {
        var logs = buildAgentViewModel.logs
        
        // Filter by search text
        if !searchText.isEmpty {
            logs = logs.filter { $0.content.localizedCaseInsensitiveContains(searchText) }
        }
        
        // Filter by log level
        if let level = selectedLogLevel {
            logs = logs.filter { $0.level == level }
        }
        
        return logs
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            toolbar
            
            // Log Display
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: LogsViewStyle.logEntrySpacing) {
                        ForEach(Array(filteredLogs.enumerated()), id: \.element.id) { index, entry in
                            LogEntryView(entry: entry)
                                .id(index)
                        }
                    }
                    .padding(LogsViewStyle.logPadding)
                    .onChange(of: filteredLogs.count) { _ in
                        if autoScroll, let lastIndex = filteredLogs.indices.last {
                            withAnimation {
                                proxy.scrollTo(lastIndex, anchor: .bottom)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Logs")
    }
    
    // MARK: - Toolbar
    private var toolbar: some View {
        HStack(spacing: LogsViewStyle.toolbarSpacing) {
            // Search Field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search logs...", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, LogsViewStyle.searchFieldPadding)
            .padding(.vertical, LogsViewStyle.searchFieldPadding / 2)
            .background(LogsViewStyle.searchFieldBackground())
            .cornerRadius(LogsViewStyle.searchFieldCornerRadius)
            .frame(maxWidth: LogsViewStyle.searchFieldMaxWidth)
            
            // Log Level Filter
            Picker("Log Level", selection: $selectedLogLevel) {
                Text("All").tag(LogLevel?.none)
                ForEach(LogLevel.allCases, id: \.self) { level in
                    Text(level.displayName).tag(LogLevel?.some(level))
                }
            }
            .pickerStyle(.menu)
            .frame(width: LogsViewStyle.pickerWidth)
            
            // Auto-scroll Toggle
            Toggle("Auto-scroll", isOn: $autoScroll)
                .toggleStyle(.checkbox)
            
            Spacer()
            
            // Action Buttons
            Button(action: copyLogs) {
                Label("Copy", systemImage: "doc.on.doc")
            }
            .buttonStyle(LogsViewStyle.toolbarButtonStyle())
            
            Button(action: exportLogs) {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(LogsViewStyle.toolbarButtonStyle())
            
            Button(action: clearLogs) {
                Label("Clear", systemImage: "trash")
            }
            .buttonStyle(LogsViewStyle.toolbarButtonStyle())
        }
        .padding(LogsViewStyle.toolbarPadding)
        .background(LogsViewStyle.toolbarBackground())
    }
    
    // MARK: - Actions
    private func copyLogs() {
        let logText = filteredLogs.map { $0.content }.joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(logText, forType: .string)
    }
    
    private func exportLogs() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "buildagent-logs-\(Date().timeIntervalSince1970).txt"
        
        if panel.runModal() == .OK, let url = panel.url {
            let logText = filteredLogs.map { $0.content }.joined(separator: "\n")
            try? logText.write(to: url, atomically: true, encoding: .utf8)
        }
    }
    
    private func clearLogs() {
        buildAgentViewModel.logs.removeAll()
    }
}

// MARK: - Log Entry View
struct LogEntryView: View {
    let entry: LogEntry
    
    var body: some View {
        HStack(alignment: .top, spacing: LogsViewStyle.logEntryHorizontalSpacing) {
            // Timestamp
            Text(entry.timestamp, style: .time)
                .font(LogsViewStyle.timestampFont())
                .foregroundColor(.secondary)
                .frame(width: LogsViewStyle.timestampWidth, alignment: .trailing)
            
            // Log Level Badge
            Text(entry.level.displayName)
                .font(LogsViewStyle.levelFont())
                .foregroundColor(LogsViewStyle.levelColor(for: entry.level))
                .padding(.horizontal, LogsViewStyle.levelBadgePadding)
                .padding(.vertical, LogsViewStyle.levelBadgePadding / 2)
                .background(LogsViewStyle.levelBackgroundColor(for: entry.level))
                .cornerRadius(LogsViewStyle.levelBadgeCornerRadius)
                .frame(width: LogsViewStyle.levelBadgeWidth)
            
            // Log Content
            Text(entry.content)
                .font(LogsViewStyle.logContentFont())
                .foregroundColor(LogsViewStyle.logContentColor())
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
