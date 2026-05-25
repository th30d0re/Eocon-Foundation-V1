# Eocon Foundation Documentation Hub

Welcome to the Eocon Foundation Build System documentation. This guide helps you find the information you need quickly.

## 📚 Documentation by Audience

### For Developers

- **[Getting Started](../../Agents/phases/phase5/README.md)** - Quick start guide
- **[Agent Reference](AGENT_REFERENCE.md)** - Complete reference for all agents
- **[Flags Reference](FLAGS_REFERENCE.md)** - All available flags and options
- **[Workflow Examples](WORKFLOW_EXAMPLES.md)** - 10+ ready-to-use workflows
- **[UI Customization](UI_CUSTOMIZATION.md)** - Theming and visual customization
- **[Troubleshooting](TROUBLESHOOTING.md)** - Common issues and solutions

### For AI Models

- **[MCP Integration](../../../XcodeBuildMCP/docs/TOOLS.md)** - 71 MCP tools reference
- **[Workflow Examples](WORKFLOW_EXAMPLES.md)** - AI-driven development workflows
- **[Integration Tests](INTEGRATION_TESTS.md)** - Testing guidelines

### For Contributors

- **[Features Documentation](FEATURES.md)** - Architecture and features
- **[Integration Tests](INTEGRATION_TESTS.md)** - Test coverage and execution
- **[Migration Guide](MIGRATION_V2_TO_V3.md)** - Upgrade path from v2.2

## 🚀 Quick Start

### First Time Setup

```bash
# 1. Run setup script
cd .Foundation/Agents/phases/phase5
./setup.sh

# 2. Initialize session defaults
./BuildAgent.sh --save-session-defaults \
  --scheme YourScheme \
  --simulator-name "iPhone 15 Pro"

# 3. Try a simple build
./BuildAgent.sh
```

### Migration from v2.2

```bash
# Run migration script
./migrate-v2-to-v3.sh

# Review what's new
cat ../../../Docs/MIGRATION_V2_TO_V3.md
```

## 📖 Core Documentation

### Agents

| Agent | Purpose | Documentation |
|-------|---------|---------------|
| **BuildAgent.sh** | Primary build orchestration | [Agent Reference](AGENT_REFERENCE.md#buildagent) |
| **BuildLint.sh** | Build analysis and linting | [Agent Reference](AGENT_REFERENCE.md#buildlint) |
| **testRunner.sh** | Test execution | [Agent Reference](AGENT_REFERENCE.md#testrunner) |
| **uiTestAgent.sh** | UI test automation | [Agent Reference](AGENT_REFERENCE.md#uitestagent) |
| **accessibilityAgent.sh** | Accessibility auditing | [Agent Reference](AGENT_REFERENCE.md#accessibilityagent) |
| **flowAgent.sh** | Flow-based testing | [Agent Reference](AGENT_REFERENCE.md#flowagent) |

### Features

- **[Incremental Builds](FEATURES.md#incremental-builds)** - Faster rebuilds with xcodemake
- **[Multi-Platform Support](FEATURES.md#multi-platform)** - iOS, macOS, tvOS, watchOS, visionOS
- **[Session Management](FEATURES.md#session-management)** - Save and reuse configurations
- **[Log Streaming](FEATURES.md#log-streaming)** - Real-time log capture
- **[UI Automation](FEATURES.md#ui-automation)** - AXe integration
- **[Fancy UI](UI_CUSTOMIZATION.md)** - Beautiful terminal output

### Workflows

Common development workflows with step-by-step examples:

1. **[Fast Incremental Development](WORKFLOW_EXAMPLES.md#1-fast-incremental-development)**
2. **[Multi-Platform Testing](WORKFLOW_EXAMPLES.md#2-multi-platform-testing)**
3. **[UI Testing with AXe](WORKFLOW_EXAMPLES.md#3-ui-testing-with-axe)**
4. **[Accessibility Validation](WORKFLOW_EXAMPLES.md#4-accessibility-validation)**
5. **[Debug Failed Test](WORKFLOW_EXAMPLES.md#5-debug-failed-test)**
6. **[Swift Package Build](WORKFLOW_EXAMPLES.md#6-swift-package-build)**
7. **[AI-Driven Build Repair](WORKFLOW_EXAMPLES.md#7-ai-driven-build-repair)**
8. **[Multi-Platform CI Pipeline](WORKFLOW_EXAMPLES.md#8-multi-platform-ci-pipeline)**
9. **[UI Test Generation](WORKFLOW_EXAMPLES.md#9-ui-test-generation)**
10. **[Performance Testing](WORKFLOW_EXAMPLES.md#10-performance-testing)**

## 🔧 XcodeBuildMCP Integration

The Eocon Foundation integrates with XcodeBuildMCP, providing 71 MCP tools for AI-driven development.

### Tool Categories

- **[Build Tools](../../../XcodeBuildMCP/docs/TOOLS.md#build-tools)** - 15 tools for building
- **[Test Tools](../../../XcodeBuildMCP/docs/TOOLS.md#test-tools)** - 12 tools for testing
- **[Simulator Tools](../../../XcodeBuildMCP/docs/TOOLS.md#simulator-tools)** - 10 tools for simulators
- **[Device Tools](../../../XcodeBuildMCP/docs/TOOLS.md#device-tools)** - 8 tools for physical devices
- **[UI Testing Tools](../../../XcodeBuildMCP/docs/TOOLS.md#ui-testing-tools)** - 14 tools for UI automation
- **[Debugging Tools](../../../XcodeBuildMCP/docs/TOOLS.md#debugging-tools)** - 12 tools for debugging
- **[SPM Tools](../../../XcodeBuildMCP/docs/TOOLS.md#spm-tools)** - 8 tools for Swift Package Manager

### Workflow Guides

- **[Simulator Workflow](../../../XcodeBuildMCP/docs/guides/SIMULATOR_WORKFLOW.md)**
- **[Device Workflow](../../../XcodeBuildMCP/docs/guides/DEVICE_WORKFLOW.md)**
- **[UI Testing Workflow](../../../XcodeBuildMCP/docs/guides/UI_TESTING_WORKFLOW.md)**
- **[Debugging Workflow](../../../XcodeBuildMCP/docs/guides/DEBUGGING_WORKFLOW.md)**
- **[SPM Workflow](../../../XcodeBuildMCP/docs/guides/SPM_WORKFLOW.md)**

## 🎨 Customization

### UI Themes

Enable fancy UI with beautiful themes:

```bash
export BUILDAGENT_FANCY_UI=true
export BUILDAGENT_THEME=dark  # or 'light'
```

See **[UI Customization Guide](UI_CUSTOMIZATION.md)** for details.

### Session Defaults

Save common build configurations:

```bash
./BuildAgent.sh --save-session-defaults \
  --scheme MyApp \
  --simulator-name "iPhone 15 Pro" \
  --platform iOS \
  --enable-incremental
```

See **[Session Management](FEATURES.md#session-management)** for details.

## 🐛 Troubleshooting

Having issues? Check the troubleshooting guide:

- **[Common Issues](TROUBLESHOOTING.md#common-issues)**
- **[Build Failures](TROUBLESHOOTING.md#build-failures)**
- **[Simulator Issues](TROUBLESHOOTING.md#simulator-issues)**
- **[Log Capture Issues](TROUBLESHOOTING.md#log-capture-issues)**
- **[Session Issues](TROUBLESHOOTING.md#session-issues)**
- **[UI Issues](TROUBLESHOOTING.md#ui-issues)**
- **[MCP Integration Issues](TROUBLESHOOTING.md#mcp-integration-issues)**

Also see **[XcodeBuildMCP Troubleshooting](../../../XcodeBuildMCP/docs/TROUBLESHOOTING.md)**.

## 📦 What's New in v3.0

- ✨ **Incremental Builds** - Up to 10x faster rebuilds
- 🎨 **Enhanced UI** - Beautiful terminal output with themes
- 🌍 **Multi-Platform** - iOS, macOS, tvOS, watchOS, visionOS
- 💾 **Session Management** - Save and reuse configurations
- 📊 **Log Streaming** - Real-time log capture and analysis
- ♿ **UI Automation** - AXe integration for accessibility
- 🤖 **71 MCP Tools** - Comprehensive AI integration

See **[Migration Guide](MIGRATION_V2_TO_V3.md)** for upgrade instructions.

## 📝 Glossary

- **Agent** - A shell script that orchestrates build/test operations
- **MCP** - Model Context Protocol, enables AI tool usage
- **Session Defaults** - Saved build configuration
- **Incremental Build** - Only rebuild changed files
- **AXe** - Accessibility automation tool
- **xcodemake** - Incremental build tool for Xcode
- **Fancy UI** - Enhanced terminal output with themes

## 🔗 Related Documentation

### XcodeBuildMCP

- [Getting Started](../../../XcodeBuildMCP/docs/GETTING_STARTED.md)
- [Tools Reference](../../../XcodeBuildMCP/docs/TOOLS.md)
- [Configuration](../../../XcodeBuildMCP/docs/CONFIGURATION.md)
- [Troubleshooting](../../../XcodeBuildMCP/docs/TROUBLESHOOTING.md)

### External Resources

- [Xcode Documentation](https://developer.apple.com/documentation/xcode)
- [xcodemake GitHub](https://github.com/subdigital/xcodemake)
- [AXe Accessibility](https://github.com/cameroncooke/axe)

## 📧 Support

- **Issues**: [GitHub Issues](https://github.com/yourusername/eocon-foundation/issues)
- **Discussions**: [GitHub Discussions](https://github.com/yourusername/eocon-foundation/discussions)
- **Documentation**: This guide and linked resources

## 📄 License

See the main repository LICENSE file for details.

---

**Last Updated**: January 2026  
**Version**: 3.0  
**Maintained by**: Eocon Foundation Team
