import SwiftUI
import AppKit

/// View for configuring BuildAgent parameters
struct ConfigurationView: View {
    @EnvironmentObject var buildAgentViewModel: BuildAgentViewModel
    @State private var showingPlanFilePicker = false
    @State private var showingPromptFilePicker = false
    @State private var showingContextPathPicker = false
    @State private var showingDerivedDataPicker = false
    @State private var showingArtifactsDirPicker = false
    @State private var showingSwiftDocsPicker = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ConfigurationViewStyle.sectionSpacing) {
                // Input Configuration Section
                inputConfigurationSection
                
                // AI Provider Selection Section
                aiProviderSection
                
                // Build Configuration Section
                buildConfigurationSection
                
                // Execution Options Section
                executionOptionsSection
                
                // Advanced Options Section
                advancedOptionsSection
                
                // Action Buttons
                actionButtons
            }
            .padding(ConfigurationViewStyle.standardPadding)
        }
        .navigationTitle("Configuration")
        .onChange(of: showingPlanFilePicker) { isPresented in
            if isPresented {
                handleFilePicker(isDirectory: false) { url in
                    buildAgentViewModel.config.planFile = url.path
                }
                showingPlanFilePicker = false
            }
        }
        .onChange(of: showingPromptFilePicker) { isPresented in
            if isPresented {
                handleFilePicker(isDirectory: false) { url in
                    buildAgentViewModel.config.promptFile = url.path
                }
                showingPromptFilePicker = false
            }
        }
        .onChange(of: showingContextPathPicker) { isPresented in
            if isPresented {
                handleFilePicker(isDirectory: true) { url in
                    buildAgentViewModel.config.contextPaths.append(url.path)
                }
                showingContextPathPicker = false
            }
        }
        .onChange(of: showingDerivedDataPicker) { isPresented in
            if isPresented {
                handleFilePicker(isDirectory: true) { url in
                    buildAgentViewModel.config.derivedDataPath = url.path
                }
                showingDerivedDataPicker = false
            }
        }
        .onChange(of: showingArtifactsDirPicker) { isPresented in
            if isPresented {
                handleFilePicker(isDirectory: true) { url in
                    buildAgentViewModel.config.artifactsDir = url.path
                }
                showingArtifactsDirPicker = false
            }
        }
        .onChange(of: showingSwiftDocsPicker) { isPresented in
            if isPresented {
                handleFilePicker(isDirectory: true) { url in
                    buildAgentViewModel.config.swiftDocsPath = url.path
                }
                showingSwiftDocsPicker = false
            }
        }
    }
    
    // MARK: - Input Configuration Section
    private var inputConfigurationSection: some View {
        GroupBox("Input Configuration") {
            VStack(alignment: .leading, spacing: ConfigurationViewStyle.fieldSpacing) {
                // Plan File Picker
                filePickerRow(
                    label: "Plan File",
                    value: buildAgentViewModel.config.planFile ?? "Not selected",
                    action: { showingPlanFilePicker = true }
                )
                
                // Prompt File Picker
                filePickerRow(
                    label: "Prompt File",
                    value: buildAgentViewModel.config.promptFile ?? "Not selected",
                    action: { showingPromptFilePicker = true }
                )
                
                // Prompt String Editor
                VStack(alignment: .leading, spacing: ConfigurationViewStyle.labelSpacing) {
                    Text("Prompt String")
                        .font(ConfigurationViewStyle.labelFont())
                    TextEditor(text: Binding(
                        get: { buildAgentViewModel.config.promptString ?? "" },
                        set: { buildAgentViewModel.config.promptString = $0.isEmpty ? nil : $0 }
                    ))
                    .frame(height: ConfigurationViewStyle.textEditorHeight)
                    .font(ConfigurationViewStyle.bodyFont())
                }
                
                // Context Paths
                VStack(alignment: .leading, spacing: ConfigurationViewStyle.labelSpacing) {
                    Text("Context Paths")
                        .font(ConfigurationViewStyle.labelFont())
                    ForEach(Array(buildAgentViewModel.config.contextPaths.enumerated()), id: \.offset) { index, path in
                        HStack {
                            Text(path)
                                .font(ConfigurationViewStyle.bodyFont())
                            Spacer()
                            Button("Remove") {
                                buildAgentViewModel.config.contextPaths.remove(at: index)
                            }
                        }
                    }
                    Button("Add Context Path") {
                        showingContextPathPicker = true
                    }
                }
            }
            .padding(ConfigurationViewStyle.groupBoxPadding)
        }
    }
    
    // MARK: - AI Provider Section
    private var aiProviderSection: some View {
        GroupBox("AI Provider Selection") {
            VStack(alignment: .leading, spacing: ConfigurationViewStyle.fieldSpacing) {
                Picker("AI Provider", selection: $buildAgentViewModel.config.aiProvider) {
                    ForEach(AIProvider.allCases, id: \.self) { provider in
                        Text(provider.rawValue).tag(provider)
                    }
                }
                .pickerStyle(.menu)
                
                TextField("AI Model (optional)", text: Binding(
                    get: { buildAgentViewModel.config.aiModel ?? "" },
                    set: { buildAgentViewModel.config.aiModel = $0.isEmpty ? nil : $0 }
                ))
                
                HStack {
                    Circle()
                        .fill(ConfigurationViewStyle.authenticationStatusColor(
                            isAuthenticated: buildAgentViewModel.isAuthenticated
                        ))
                        .frame(width: ConfigurationViewStyle.statusIndicatorSize,
                               height: ConfigurationViewStyle.statusIndicatorSize)
                    Text(buildAgentViewModel.isAuthenticated ? "Authenticated" : "Not Authenticated")
                        .font(ConfigurationViewStyle.captionFont())
                }
            }
            .padding(ConfigurationViewStyle.groupBoxPadding)
        }
    }
    
    // MARK: - Build Configuration Section
    private var buildConfigurationSection: some View {
        GroupBox("Build Configuration") {
            VStack(alignment: .leading, spacing: ConfigurationViewStyle.fieldSpacing) {
                TextField("Scheme", text: Binding(
                    get: { buildAgentViewModel.config.scheme ?? "" },
                    set: { buildAgentViewModel.config.scheme = $0.isEmpty ? nil : $0 }
                ))
                
                TextField("Target ID", text: Binding(
                    get: { buildAgentViewModel.config.targetID ?? "" },
                    set: { buildAgentViewModel.config.targetID = $0.isEmpty ? nil : $0 }
                ))
                
                TextField("Destination", text: Binding(
                    get: { buildAgentViewModel.config.destination ?? "" },
                    set: { buildAgentViewModel.config.destination = $0.isEmpty ? nil : $0 }
                ))
                
                Picker("Build Configuration", selection: $buildAgentViewModel.config.buildConfiguration) {
                    Text("Debug").tag(BuildConfiguration.debug)
                    Text("Release").tag(BuildConfiguration.release)
                }
                .pickerStyle(.menu)
                
                filePickerRow(
                    label: "Derived Data Path",
                    value: buildAgentViewModel.config.derivedDataPath ?? "Default",
                    action: { showingDerivedDataPicker = true }
                )
            }
            .padding(ConfigurationViewStyle.groupBoxPadding)
        }
    }
    
    // MARK: - Execution Options Section
    private var executionOptionsSection: some View {
        GroupBox("Execution Options") {
            VStack(alignment: .leading, spacing: ConfigurationViewStyle.fieldSpacing) {
                HStack {
                    Text("Max Attempts")
                    Spacer()
                    Stepper("", value: $buildAgentViewModel.config.maxAttempts, in: 1...10)
                    Text("\(buildAgentViewModel.config.maxAttempts)")
                        .frame(width: ConfigurationViewStyle.stepperValueWidth)
                }
                
                Toggle("Stream Output", isOn: $buildAgentViewModel.config.streamOutput)
                Toggle("YOLO Mode", isOn: $buildAgentViewModel.config.yoloMode)
                Toggle("Skip Lint", isOn: $buildAgentViewModel.config.skipLint)
                Toggle("Verbose", isOn: $buildAgentViewModel.config.verbose)
            }
            .padding(ConfigurationViewStyle.groupBoxPadding)
        }
    }
    
    // MARK: - Advanced Options Section
    private var advancedOptionsSection: some View {
        GroupBox("Advanced Options") {
            VStack(alignment: .leading, spacing: ConfigurationViewStyle.fieldSpacing) {
                filePickerRow(
                    label: "Artifacts Directory",
                    value: buildAgentViewModel.config.artifactsDir ?? "Default",
                    action: { showingArtifactsDirPicker = true }
                )
                
                filePickerRow(
                    label: "Swift Docs Path",
                    value: buildAgentViewModel.config.swiftDocsPath ?? "Default",
                    action: { showingSwiftDocsPicker = true }
                )
                
                Toggle("Skip Chat ID Capture", isOn: $buildAgentViewModel.config.skipChatIDCapture)
            }
            .padding(ConfigurationViewStyle.groupBoxPadding)
        }
    }
    
    // MARK: - Action Buttons
    private var actionButtons: some View {
        HStack {
            Button("Save Configuration") {
                buildAgentViewModel.saveConfig()
            }
            .buttonStyle(ConfigurationViewStyle.primaryButtonStyle())
            
            Button("Load Configuration") {
                buildAgentViewModel.loadConfig()
            }
            .buttonStyle(ConfigurationViewStyle.secondaryButtonStyle())
            
            Spacer()
            
            Button("Start Build") {
                buildAgentViewModel.startBuild()
            }
            .buttonStyle(ConfigurationViewStyle.primaryButtonStyle())
            .disabled(buildAgentViewModel.isRunning)
        }
    }
    
    // MARK: - Helper Views
    private func filePickerRow(label: String, value: String, action: @escaping () -> Void) -> some View {
        HStack {
            Text(label)
                .font(ConfigurationViewStyle.labelFont())
                .frame(width: ConfigurationViewStyle.labelWidth, alignment: .leading)
            Text(value)
                .font(ConfigurationViewStyle.bodyFont())
                .foregroundColor(.secondary)
            Spacer()
            Button("Browse...") {
                action()
            }
        }
    }
    
    // MARK: - File Picker Handlers
    private func handleFilePicker(isDirectory: Bool, onSelect: @escaping (URL) -> Void) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = isDirectory
        panel.canChooseFiles = !isDirectory
        
        if panel.runModal() == .OK, let url = panel.url {
            onSelect(url)
        }
    }
}
