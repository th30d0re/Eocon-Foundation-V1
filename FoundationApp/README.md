# FoundationApp - macOS BuildAgent UI

Native macOS SwiftUI application for the Phase 5 BuildAgent, providing a visual interface for configuring, monitoring, and managing AI-powered code generation workflows.

## Project Structure

```
FoundationApp/
├── FoundationApp/
│   ├── App/
│   │   ├── FoundationApp.swift          # @main entry point
│   │   └── FoundationAppStyle.swift      # App-level styles
│   ├── Models/
│   │   ├── AIProvider.swift
│   │   ├── BuildAgentConfig.swift
│   │   ├── BuildConfiguration.swift
│   │   ├── BuildPhase.swift
│   │   ├── BuildProgress.swift
│   │   ├── BuildSession.swift
│   │   ├── LogEntry.swift
│   │   ├── LogLevel.swift
│   │   └── SessionStatus.swift
│   ├── ViewModels/
│   │   └── BuildAgentViewModel.swift     # Main orchestrator
│   ├── Views/
│   │   ├── ContentView.swift             # Main container with sidebar
│   │   ├── ConfigurationView.swift       # BuildAgent config UI
│   │   ├── ProgressView.swift            # Real-time progress display
│   │   ├── LogsView.swift                # Log viewer
│   │   ├── ArtifactsView.swift           # Artifact browser
│   │   ├── SessionHistoryView.swift      # Past sessions
│   │   └── StatusBadge.swift            # Reusable status component
│   └── Styles/
│       ├── ContentViewStyle.swift
│       ├── ConfigurationViewStyle.swift
│       ├── ProgressViewStyle.swift
│       ├── LogsViewStyle.swift
│       ├── ArtifactsViewStyle.swift
│       └── SessionHistoryViewStyle.swift
```

## Features

### ContentView
- Sidebar navigation with 5 sections: Configuration, Progress, Logs, Artifacts, History
- Main content area that switches based on selection

### ConfigurationView
- Input Configuration: Plan file picker, prompt file picker, prompt string editor, context paths
- AI Provider Selection: Dropdown for provider (Cursor, Claude, Codex, Gemini, Aider), model selection, authentication status
- Build Configuration: Scheme, Target ID, Destination, Build Configuration (Debug/Release), Derived Data Path
- Execution Options: Max attempts stepper, Stream Output, YOLO Mode, Skip Lint, Verbose toggles
- Advanced Options: Artifacts directory, Swift docs path, Skip Chat ID Capture toggle
- Action buttons: Save Configuration, Load Configuration, Start Build

### ProgressView
- Current attempt indicator (e.g., "Attempt 2/3")
- Current phase display with spinner
- Progress bar showing attempt progress
- Elapsed time display
- Status badges (Success, Failed, In Progress, Human Intervention)

### LogsView
- Real-time log streaming with auto-scroll
- Color-coded log levels (Info, Success, Warning, Error, Debug)
- Filter by log level
- Search/filter functionality
- Copy to clipboard
- Export logs to file
- Timestamp and level badges for each entry

### ArtifactsView
- List of build sessions (by timestamp)
- File browser for each session showing:
  - Logs directory contents
  - Status directory contents
- File preview pane
- Open in Finder action
- Delete session functionality

### SessionHistoryView
- Table view of past sessions with columns:
  - Date
  - Time
  - Status
  - Attempts
  - Duration
  - Actions (View Logs, Open Artifacts, Re-run)
- Filter by status
- Search by session ID or scheme
- Session count display

## Architecture

Following MVVM-S pattern:
- **Model**: Data models (BuildAgentConfig, BuildSession, BuildProgress, etc.)
- **ViewModel**: BuildAgentViewModel (state management, Combine subscriptions)
- **View**: SwiftUI views (ContentView, ConfigurationView, etc.)
- **Style**: Separate Style modules for each view (MVVM-S pattern)

## Style Modules

All views follow the MVVM-S pattern with separate Style modules:
- Constants (HIG Compliant): Spacing, sizes, corner radius
- Typography (Dynamic Type Support): Font functions
- Colors (Color Scheme Adaptive): Color functions
- Materials: Background materials
- Animations: Animation constants

## Integration

Views are integrated with `BuildAgentViewModel` using `@EnvironmentObject`:
```swift
@EnvironmentObject var buildAgentViewModel: BuildAgentViewModel
```

## Next Steps

1. Create Xcode project file (FoundationApp.xcodeproj)
2. Implement BuildAgentService for actual script execution
3. Implement LogParserService for log parsing
4. Implement FileWatcherService for real-time log updates
5. Add configuration persistence (UserDefaults/JSON file)
6. Implement comprehensive error handling
7. Write unit tests for ViewModels and Services
8. Add UI tests for key flows

## Notes

- All views use mock ViewModels currently - replace with actual implementations
- File pickers use NSOpenPanel for macOS native file selection
- StatusBadge component is reusable across views
- All style values are extracted to Style modules following MVVM-S pattern
