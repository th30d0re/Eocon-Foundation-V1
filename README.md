# Eocon Foundation V1

A comprehensive framework and knowledge base for building agentic applications using the Foundation methodology.

## Overview

This repository contains the **Foundation Framework** - a structured approach to building complex, agentic software systems through:

- **Constitution-driven development**: LaTeX documents that define what systems ARE and DO
- **Wave-based planning**: Decomposed execution plans for token-efficient processing
- **Autonomous agent orchestration**: Multi-agent systems that can build entire businesses
- **Constellation architecture**: Networks of specialized micro-apps working together

## Repository Structure

```
.Foundation/
├── Foundation-constitution/    # LaTeX constitution documents (source of truth)
├── .Planning/                  # Auto-generated plans and decision logs
│   ├── Constitution/           # Constitution source files
│   ├── scripts/                # Planning and decision tools
│   └── Notes/                  # Planning notes and documentation
├── Docs/                       # External documentation and API references
│   └── swiftDocs/              # Swift framework documentation
├── Agents/                     # Agent scripts and orchestration
│   └── phases/                 # Phase-specific agent implementations
├── lib/                        # Shared libraries and utilities
└── Version_and_updates/       # Version tracking and changelog
```

## The Five-Folder Foundation

Every Foundation project maintains this canonical structure:

1. **Constitution/**: LaTeX documents defining what the system IS and DOES
   - C0: Root Constitution (main application concept)
   - C1, C2...CN: Sub-Constitutions (individual micro-apps)

2. **Plans/**: Wave-based decomposition of execution plans
   - Main plan documents
   - Test specifications
   - Decision logs
   - Wave sub-plans for token efficiency

3. **Guides/**: Self-documentation created by LLMs
   - Implementation decisions explained
   - Historical patterns documented
   - Used by Optimization Agent for learning

4. **Docs/**: External documentation and API references
   - Auto-scraped resources
   - Library documentation
   - Used by agents for context

5. **Design/**: Shared code and reusable components
   - Sample applications
   - Code patterns
   - Best practices

## Key Concepts

### Constitution-Driven Development
The Constitution is the source of truth - a comprehensive LaTeX document (70-80 pages) that defines:
- What the system is
- What it does
- How it behaves
- Business rules and constraints

### Wave-Based Planning
Plans are broken into digestible "waves" for:
- Token efficiency in LLM processing
- Parallel execution where possible
- Clear dependency management

### Constellation Architecture
Businesses are built as networks of specialized micro-apps:
- Each micro-app is independent
- Apps are "entangled" through shared data/APIs
- Enables distributed, scalable systems

### Agent Orchestration
Multi-phase agent system:
- **Orchestrator**: Analyzes requirements, determines constellation
- **Planner**: Reads Constitution, generates execution plans
- **Build Agent**: Executes plans, generates code
- **Optimization Agent**: Learns from patterns, improves future builds

## Getting Started

### Prerequisites
- Git
- LaTeX (for Constitution documents)
- Python 3.x (for planning scripts)
- Shell access (for agent scripts)

### Setup

1. Clone the repository:
```bash
git clone https://github.com/nottinghillai/Eocon-Foundation-V1.git
cd Eocon-Foundation-V1
```

2. Review the Constitution:
```bash
# View the main constitution
open .Foundation/Foundation-constitution/Foundation-Constitution.pdf
```

3. Explore the planning structure:
```bash
cd .Foundation/.Planning
ls -la
```

## Related Repositories

- **[Eocon-Foundation-Swift](https://github.com/nottinghillai/Eocon-Foundation-Swift)**: The Swift application implementation (separate repository)

## Version

Current version: **0.1.0**

See [Version_and_updates/CHANGELOG.md](.Foundation/Version_and_updates/CHANGELOG.md) for detailed version history.

## Documentation

- **Constitution**: `.Foundation/Foundation-constitution/`
- **Planning Documents**: `.Foundation/.Planning/`
- **API Documentation**: `.Foundation/Docs/`
- **Agent Scripts**: `.Foundation/Agents/`

## Architecture

The Foundation Framework enables:

1. **Natural Language → Constitution**: Human expertise captured in LaTeX
2. **Constitution → Plans**: Automated plan generation with dependency analysis
3. **Plans → Code**: Distributed execution across compute nodes
4. **Code → Tests**: Auto-generated test suites
5. **Tests → Validation**: Automated quality gates
6. **Validation → Deployment**: Continuous integration and deployment

## Contributing

This is a private repository. For access or contributions, please contact the repository maintainers.

## License

Private - All rights reserved.

## Contact

For questions or support, please open an issue in this repository.

---

**Note**: The Swift application code has been moved to a separate repository ([Eocon-Foundation-Swift](https://github.com/nottinghillai/Eocon-Foundation-Swift)) to avoid conflicts and maintain clear separation of concerns.
