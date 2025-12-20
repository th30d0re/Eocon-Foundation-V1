import SwiftUI
import AppKit

/// View for browsing and managing BuildAgent artifacts
struct ArtifactsView: View {
    @EnvironmentObject var buildAgentViewModel: BuildAgentViewModel
    @State private var selectedSession: BuildSession? = nil
    @State private var selectedFile: URL? = nil
    
    var body: some View {
        HSplitView {
            // Session List
            sessionList
                .frame(minWidth: ArtifactsViewStyle.sessionListMinWidth)
            
            // File Browser
            if let session = selectedSession {
                fileBrowser(for: session)
            } else {
                emptyState
            }
        }
        .navigationTitle("Artifacts")
        .onAppear {
            buildAgentViewModel.loadSessions()
        }
    }
    
    // MARK: - Session List
    private var sessionList: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Build Sessions")
                .font(ArtifactsViewStyle.sectionTitleFont())
                .padding(ArtifactsViewStyle.sectionTitlePadding)
            
            List(buildAgentViewModel.sessions, selection: $selectedSession) { session in
                SessionRow(session: session)
                    .tag(session)
            }
            .listStyle(.sidebar)
        }
    }
    
    // MARK: - File Browser
    private func fileBrowser(for session: BuildSession) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Session Header
            sessionHeader(session: session)
            
            HSplitView {
                // File List
                fileList(for: session)
                    .frame(minWidth: ArtifactsViewStyle.fileListMinWidth)
                
                // File Preview
                if let file = selectedFile {
                    filePreview(url: file)
                } else {
                    Text("Select a file to preview")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }
    
    // MARK: - Session Header
    private func sessionHeader(session: BuildSession) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: ArtifactsViewStyle.headerSpacing) {
                Text("Session: \(session.id)")
                    .font(ArtifactsViewStyle.sessionTitleFont())
                Text("Started: \(session.startTime, style: .date)")
                    .font(ArtifactsViewStyle.sessionSubtitleFont())
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("Open in Finder") {
                openInFinder(url: session.logsDir)
            }
            .buttonStyle(ArtifactsViewStyle.actionButtonStyle())
            
            Button("Delete Session") {
                deleteSession(session)
            }
            .buttonStyle(ArtifactsViewStyle.destructiveButtonStyle())
        }
        .padding(ArtifactsViewStyle.headerPadding)
        .background(ArtifactsViewStyle.headerBackground())
    }
    
    // MARK: - File List
    private func fileList(for session: BuildSession) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Files")
                .font(ArtifactsViewStyle.sectionTitleFont())
                .padding(ArtifactsViewStyle.sectionTitlePadding)
            
            List(selection: $selectedFile) {
                // Logs Directory
                Section("Logs") {
                    ForEach(filesInDirectory(session.logsDir), id: \.self) { url in
                        FileRow(url: url)
                            .tag(url)
                    }
                }
                
                // Status Directory
                Section("Status") {
                    ForEach(filesInDirectory(session.statusDir), id: \.self) { url in
                        FileRow(url: url)
                            .tag(url)
                    }
                }
            }
            .listStyle(.sidebar)
        }
    }
    
    // MARK: - File Preview
    private func filePreview(url: URL) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ArtifactsViewStyle.previewSpacing) {
                Text(url.lastPathComponent)
                    .font(ArtifactsViewStyle.previewTitleFont())
                    .padding(ArtifactsViewStyle.previewPadding)
                
                if let content = try? String(contentsOf: url) {
                    Text(content)
                        .font(ArtifactsViewStyle.previewContentFont())
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(ArtifactsViewStyle.previewPadding)
                } else {
                    Text("Unable to preview file")
                        .foregroundColor(.secondary)
                        .padding(ArtifactsViewStyle.previewPadding)
                }
            }
        }
    }
    
    // MARK: - Empty State
    private var emptyState: some View {
        VStack {
            Image(systemName: "folder")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("No session selected")
                .font(ArtifactsViewStyle.emptyStateFont())
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Helper Functions
    private func filesInDirectory(_ url: URL) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        
        return enumerator.compactMap { $0 as? URL }
            .filter { (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true }
            .sorted { $0.path < $1.path }
    }
    
    private func openInFinder(url: URL) {
        NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: "")
    }
    
    private func deleteSession(_ session: BuildSession) {
        buildAgentViewModel.deleteSession(session)
        if selectedSession?.id == session.id {
            selectedSession = nil
        }
    }
}

// MARK: - Session Row
struct SessionRow: View {
    let session: BuildSession
    
    var body: some View {
        VStack(alignment: .leading, spacing: ArtifactsViewStyle.rowSpacing) {
            Text(session.id)
                .font(ArtifactsViewStyle.rowTitleFont())
            HStack {
                StatusBadge(status: session.status)
                Text(session.startTime, style: .relative)
                    .font(ArtifactsViewStyle.rowSubtitleFont())
                    .foregroundColor(.secondary)
            }
        }
        .padding(ArtifactsViewStyle.rowPadding)
    }
}

// MARK: - File Row
struct FileRow: View {
    let url: URL
    
    var body: some View {
        HStack {
            Image(systemName: fileIcon)
                .foregroundColor(.secondary)
            Text(url.lastPathComponent)
                .font(ArtifactsViewStyle.fileRowFont())
        }
    }
    
    private var fileIcon: String {
        switch url.pathExtension {
        case "log", "txt":
            return "doc.text"
        case "json":
            return "doc.badge.gearshape"
        default:
            return "doc"
        }
    }
}
