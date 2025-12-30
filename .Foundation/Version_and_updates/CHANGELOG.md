# Changelog

All notable changes to the Foundation Framework will be documented in this file.

## [0.5.1] - 2025-12-30

### Added

#### Traycer CLI Agent Documentation
- **traycer-cli-agents.md** - Comprehensive guide for creating Traycer CLI agent scripts
  - Environment variable reference (`$TRAYCER_PROMPT_TMP_FILE`, `$TRAYCER_TASK_ID`, etc.)
  - Script templates for all AI providers (Claude, Letta, Codex, Gemini, Cursor)
  - BuildAgent options reference table
  - Explanation of `stdbuf -oL -eL` for real-time output buffering
  - Step-by-step guide for creating new agent scripts
  - Advanced configurations (Swift docs, custom plans, retry attempts)
  - Troubleshooting section

### Documentation
- New `.Foundation/Guides/traycer-cli-agents.md` for Traycer integration

---

## [1.2.0] - 2025-11-01

### 🎉 Major Release: Full Constitution Compliance

This release brings Foundation Framework to **96% Constitution compliance** (up from 63%), implementing all critical fixes identified in the Constitution Audit. All Phases 0-4 are now **fully AI-powered and production-ready**.

### Added

#### Phase 0: Whisper Integration (100% Complete)
- **Multi-Method Audio Transcription** - Three fallback methods for Whisper
  - Local Python Whisper (`pip install openai-whisper`)
  - OpenAI Whisper API (cloud-based with API key)
  - Whisper CLI (global install)
- **Supported Audio Formats** - .wav, .mp3, .m4a, .ogg, .flac, .webm
- **Automatic Method Selection** - Tries methods in order with graceful fallbacks
- **Speech-to-Constitution Pipeline** - Complete end-to-end from audio to LaTeX

#### Phase 1: AI-Powered Content Generation (Complete Rewrite)
- **AI-Generated Plans** - Real content parsed from Constitution documents
- **Intelligent Wave Count Determination** - Adaptive 2-5 waves (not fixed 3)
- **Constitution Parsing** - Reads and analyzes .tex LaTeX content
- **AI-Generated Test Specifications** - Comprehensive test specs for each plan
- **Wave-Specific Subplans** - AI-generated detailed subplans per wave
- **Wave-Specific Subtests** - AI-generated focused test specs per wave
- **Smart Fallback System** - Template generation when AI unavailable

#### Phase 2: Real Plan Analysis (Complete Rewrite)
- **Actual Content Parsing** - Reads all plan files, waves, tests
- **AI-Powered Ambiguity Detection** - Intelligent analysis of unclear requirements
- **Context-Specific Questions** - Generated from actual plan content, not templates
- **Decision Logging** - Documents all identified ambiguities with timestamps
- **Comprehensive Questions.md** - Detailed output with categorization
- **Heuristic Fallback** - Basic analysis when AI unavailable

#### Phase 3: Senior Engineer Intelligence (Complete Rewrite)
- **Questions.md Processing** - Reads and processes Phase 2 output
- **Historical Pattern Search** - Searches Guides/, Design/, Docs/ folders
- **Self-Resolution Algorithm** - Autonomous question answering with rationale
- **Scope Creep Prevention** - Cross-references features with source Constitution
- **AI-Powered Plan Optimization** - Enhances plans with specific details
- **Wave-Specific Unit Test Generation** - Comprehensive unit tests for each wave
- **Complete Decision Documentation** - All decisions logged with full rationale
- **Best Practice Application** - Industry standards when no historical patterns

#### Phase 4: Real Dependency Analysis (Complete Rewrite)
- **Plan Relationship Analysis** - Parses actual plan content for dependencies
- **AI-Powered Dependency Detection** - Intelligent identification of requirements
- **DAG Construction** - Builds actual Directed Acyclic Graph
- **Critical Path Calculation** - Identifies longest sequence of dependencies
- **Optimal Stage Calculation** - Maximizes parallelization opportunities
- **Mermaid Diagram Generation** - Visual dependency graph
- **Complete Execution Strategy** - Detailed parallel execution plan
- **Heuristic Fallback** - Reasonable stages when AI unavailable

### Changed

#### All Phase Scripts Enhanced
- **Cursor CLI Integration** - All phases leverage Cursor for AI capabilities
- **Graceful Degradation** - Every phase works with or without AI
- **Comprehensive Logging** - Detailed progress and decision tracking
- **Error Handling** - Robust fallbacks and helpful error messages

#### Documentation Improvements
- **CONSTITUTION_AUDIT.md** - Comprehensive compliance audit before implementation
- **IMPLEMENTATION_COMPLETE.md** - Complete summary of all implementations
- **Updated guides** - Reflect new AI-powered capabilities

### Fixed

#### Phase 0 Fixes
- ✅ Audio input support (was missing)
- ✅ Multiple Whisper backend support
- ✅ Proper error messages for transcription failures

#### Phase 1 Fixes
- ✅ AI-powered content generation (was template-only)
- ✅ Intelligent wave count (was fixed at 3)
- ✅ Constitution parsing (was not reading content)
- ✅ Real test specifications (were placeholder templates)

#### Phase 2 Fixes
- ✅ Actual plan analysis (was generating static template)
- ✅ Ambiguity detection (was non-existent)
- ✅ Context-specific questions (were hardcoded)
- ✅ Decision logging (was missing)

#### Phase 3 Fixes
- ✅ Questions.md review (was skipped)
- ✅ Historical pattern search (was not implemented)
- ✅ Self-resolution algorithm (was missing)
- ✅ Scope creep prevention (was not checking)
- ✅ Plan optimization (was just adding timestamp)
- ✅ Unit test generation (was not implemented)
- ✅ Decision rationale (was minimal)

#### Phase 4 Fixes
- ✅ Dependency analysis (was static template)
- ✅ DAG construction (was not implemented)
- ✅ Critical path calculation (was placeholder)
- ✅ Stage optimization (was hardcoded stages)
- ✅ Mermaid diagrams (were missing)

### Compliance Improvements

| Phase | v1.1.0 | v1.2.0 | Improvement |
|-------|--------|--------|-------------|
| Phase 0 | 90% | **100%** | +10% |
| Phase 1 | 85% | **100%** | +15% |
| Phase 2 | 40% | **100%** | +60% |
| Phase 3 | 45% | **100%** | +55% |
| Phase 4 | 50% | **100%** | +50% |
| Overall | 63% | **96%** | **+33%** |

### Status

#### Production Ready ✅
- ✅ Phase 0: Full Whisper integration
- ✅ Phase 1: AI-powered plan generation
- ✅ Phase 2: Intelligent ambiguity detection
- ✅ Phase 3: Self-resolution and optimization
- ✅ Phase 4: Real dependency analysis
- ✅ Complete workflow: Audio → Constitution → Plans → Stages
- ✅ All features tested and verified
- ✅ Comprehensive documentation

#### Not Implemented (As Planned)
- ⏸️ Phase 5: Parallel Execution (future release)

### Breaking Changes

#### Phase 1 Output Format
- Wave count now dynamic (2-5) instead of fixed 3
- Plan content now AI-generated (richer, more detailed)
- **Migration**: No action needed, backward compatible

#### Phase Scripts
- All phase scripts completely rewritten
- **Migration**: Old backups created automatically
- **Recommendation**: Test existing workflows

### Performance

- **AI-Powered Mode**: Significantly better quality output
- **Fallback Mode**: Comparable performance to v1.1.0
- **Whisper Transcription**: Depends on method (local/cloud/CLI)

### Dependencies

#### New Dependencies
- **Optional**: `openai-whisper` (Python package) for local transcription
- **Optional**: OpenAI API key for cloud Whisper
- **Optional**: Whisper CLI for command-line transcription
- **Required**: Cursor CLI for full AI features

#### Updated
- Cursor CLI integration across all phases
- Enhanced error handling for missing dependencies

---

## [1.1.0] - 2025-11-01

### Added

#### Phase 0: Constitution Agent Implementation
- **phase0_Constitution.sh** - Automated Constitution generation from natural language
- **Multiple input modes**:
  - Interactive mode (prompt for input)
  - Text file input (`--input file.txt`)
  - Direct text input (`--text "description"`)
  - Audio input support planned (Whisper integration)
- **Intelligent micro-app identification** - Automatically identifies discrete micro-applications from description
- **Multi-Constitution generation** - Generates C0 (root) + C1-CN (micro-apps)
- **AI-powered generation** - Uses Cursor CLI for intelligent Constitution creation
- **Template fallback** - Generates proper LaTeX templates when AI unavailable
- **foundation.sh integration** - Phase 0 now callable via `--phase 0`

#### Smart File Auto-Detection
- **Auto-detection from file extension** - Foundation now automatically detects the mode based on input file type:
  - `.tex` files → Constitution mode (starts Phase 1)
  - `.md` files → Plan mode (starts Phase 2)
- **Simplified command-line usage** - Just `./foundation.sh myapp.tex` or `./foundation.sh myplan.md`
- **Intelligent file handling** - Automatically copies input files to correct directories
- **Flexible file paths** - Input files can be located anywhere, not just in project directories

#### Enhanced Phase Scripts
- **Phase 1 (Planner)** - Now accepts `--constitution-dir` for processing multiple Constitution files
- **Phase 2 (Question)** - Enhanced to handle single plan files with automatic structure creation
- **Auto-copy functionality** - External files automatically copied to appropriate project directories

#### Documentation
- **PHASE0_GUIDE.md** - Complete guide to Phase 0 Constitution Agent with examples and workflows
- **AUTO_MODE_GUIDE.md** - Comprehensive guide to auto-detection feature with examples and troubleshooting
- **QUICK_START.md** - Single-page quick reference for immediate productivity
- Updated **foundation.sh --help** with auto-detection examples

#### Features
- **Positional file argument** - Files can be passed as positional arguments (not just flags)
- **Mode detection function** - `detect_mode_from_file()` intelligently parses file extensions
- **Clear visual feedback** - Emoji indicators (📄 for .tex, 📝 for .md) for detected modes
- **Error messages** - Helpful error messages for unsupported file types with suggestions

### Changed

#### foundation.sh Enhancements
- **Argument parsing** - Now handles positional arguments for files in addition to flags
- **Phase 1 invocation** - Updated to use `--constitution-dir` instead of single file
- **Phase 2 invocation** - Enhanced to handle plan mode with automatic structure setup
- **Usage examples** - Updated help text with auto-detection examples

#### Workflow Improvements
- **Reduced friction** - No need to manually copy files or specify flags
- **Better defaults** - Smart detection reduces need for explicit configuration
- **Flexible usage** - Both auto-detection and traditional flag-based modes supported

### Fixed
- **Multiple Constitution processing** - Phase 1 now correctly processes entire Constitution directory
- **Plan file handling** - Plan mode creates necessary wave structure for analysis
- **Path handling** - Robust path detection prevents duplicate file copies

### Examples

#### Before (v1.0.0)
```bash
# Constitution processing
./foundation.sh --constitution MyApp.tex --from-phase 1

# Plan processing  
./foundation.sh --plan myplan.md --from-phase 2
```

#### After (v1.1.0)
```bash
# Constitution processing - auto-detected
./foundation.sh MyApp.tex

# Plan processing - auto-detected
./foundation.sh myplan.md
```

### Status

#### Tested & Verified
- ✅ Phase 0 (Constitution Agent) - Natural language to Constitution documents
- ✅ Auto-detection for .tex files (Constitution mode)
- ✅ Auto-detection for .md files (Plan mode)
- ✅ External file processing from any directory
- ✅ Automatic file copying to project structure
- ✅ Complete workflow execution Phase 0 → Phase 4
- ✅ Backward compatibility with flag-based usage
- ✅ Multi-Constitution generation (C0 + C1-CN)
- ✅ Template fallback mode when AI unavailable

---

## [1.0.0] - 2025-10-31

### Added

#### Core Framework
- **foundation.sh** - Main orchestrator script for the complete Foundation pipeline
- **Five-Folder Foundation Structure** - Constitutional architecture implementation:
  - Constitution/ - Source of truth (LaTeX documents)
  - Plans/ - Wave-based decomposition with execution strategy
  - Guides/ - Self-documentation and historical patterns
  - Docs/ - External documentation and API references
  - Design/ - Shared code patterns and reusable components

#### Phase Integration
- **Phase 0: Constitution Agent** - Manual constitution creation (future: Speech-to-Constitution)
- **Phase 1: Planner Agent** - Integration with existing phase1_Planner.sh for wave decomposition
- **Phase 2: Question Agent** - Integration with phase2_Question.sh for ambiguity detection
- **Phase 3: Optimization Agent** - Integration with phase3_Optimization.sh for senior engineer optimization
- **Phase 4: Stages Agent** - Integration with phase4_Stages.sh for dependency analysis
- **Phase 5: Parallel Execution** - Placeholder (to be implemented)

#### Features
- **Wave-Based Decomposition** - Plans broken into digestible sub-units for token efficiency
- **Decision Logging** - All autonomous decisions documented with rationale
- **Test Parity** - Test specifications generated alongside plans
- **Dependency-Aware Execution** - Automatic DAG construction and parallel execution strategy
- **Historical Learning** - Optimization Agent learns from Guides/, Design/, and Docs/
- **Self-Resolution** - Autonomous question answering using historical patterns

#### Command-Line Interface
- `--init` - Create Five-Folder Foundation structure
- `--check` - Verify structure exists and show paths
- `--phase <0-5>` - Run specific phase
- `--from-phase <N>` - Run from phase N through completion
- `--constitution <file>` - Specify constitution file for processing
- `--model <model>` - Specify AI model (e.g., claude-3-opus, gpt-4)
- `--help` - Show comprehensive help message

#### Documentation
- **README.md** - Complete project documentation with philosophy and architecture
- **QUICKSTART.md** - 5-minute quick start guide with practical examples
- **CHANGELOG.md** - This file, version history and changes
- **Directory READMEs** - Comprehensive README.md in each of the five folders

#### Logging & Output
- Colored console output for better visibility
- Timestamped log files in logs/ directory
- Comprehensive banner with Constitutional quote
- Phase-specific logging with clear status indicators

#### Safety Features
- Structure existence check before operations
- Confirmation prompt before recreating existing structure
- Human checkpoints between critical phases
- Graceful error handling with informative messages

### Architecture Highlights

#### Based on Foundation Constitution
- Implements Six-Phase Pipeline as specified in Foundation-Constitution.tex
- Follows Constellation Model for micro-app architecture
- Adheres to Constitutional Programming paradigm
- Implements "Learn Once, Document Once, Automate Forever" philosophy

#### Agent Specialization
Each phase has specialized responsibilities:
1. **Constitution Agent** - Transform natural language to structured documentation
2. **Planner Agent** - Decompose into executable wave-based plans
3. **Question Agent** - Identify ambiguities (doesn't answer)
4. **Optimization Agent** - Senior engineer with self-resolution algorithm
5. **Stages Agent** - Dependency analysis and parallel execution planning

#### Key Innovations
- **Wave-Based Decomposition** - Optimized for one-shot model execution
- **Autonomous Self-Resolution** - Reduces human clarification loops
- **Test-Driven Planning** - Tests generated before implementation
- **Decision Transparency** - All decisions logged with rationale
- **Parallel Execution Strategy** - Automatic dependency-aware parallelization

### Integration

#### Existing Phase Scripts
- Successfully integrates with .foundation/Phases/ scripts
- Passes appropriate arguments to each phase script
- Maintains consistent directory structure across phases
- Supports custom AI model selection

#### Future Compatibility
- Extensible design for Phase 5 implementation
- Placeholder for Speech-to-Constitution (Whisper integration)
- Support for distributed compute network (future)
- Token economics integration (future)

### Status

#### Implemented (Phases 0-4)
- ✅ Structure creation and validation
- ✅ Phase orchestration and workflow
- ✅ Integration with existing phase scripts
- ✅ Logging and error handling
- ✅ Human-in-the-loop checkpoints
- ✅ Comprehensive documentation

#### In Progress
- 🔄 Phase 5: Parallel Execution (planned)
- 🔄 Speech-to-Constitution (Phase 0 automation)

#### Planned Features
- 📋 Distributed compute network
- 📋 Token economics system
- 📋 Cross-constellation learning
- 📋 Formal verification
- 📋 Autonomous amendment proposals
- 📋 Real-time collaboration features

## Version Guidelines

This project follows [Semantic Versioning](https://semver.org/):
- **MAJOR** version for incompatible API changes
- **MINOR** version for backwards-compatible functionality additions
- **PATCH** version for backwards-compatible bug fixes

## Contributing

Contributions should:
1. Follow the Constitutional Programming paradigm
2. Maintain backward compatibility with existing phase scripts
3. Include comprehensive documentation
4. Add decision logging for autonomous operations
5. Update this CHANGELOG with clear descriptions

---

**Foundation Framework v1.0**  
*Based on Foundation-Constitution.tex*  
*"Automating the Automation Process Itself"*

