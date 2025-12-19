# Constitution Template Guide

## Overview

This guide explains how to use the **Constitution-Template.tex** file to create uniform constitutions for Foundation projects. The template is designed for use by the Planner Agent to ensure all project constitutions follow a standardized structure.

## Quick Start

1. Copy `Constitution-Template.tex` to your target location
2. Rename to `{ProjectName}-Constitution.tex`
3. Replace all `ALL-CAPS-WITH-DASHES` placeholder tokens with actual values
4. Remove sections not needed for your project
5. Compile with LaTeX (pdflatex or xelatex)

---

## Placeholder Format

**Important:** Placeholders use `ALL-CAPS-WITH-DASHES` format (NOT curly braces, which conflict with LaTeX).

Example placeholders:
- `PROJECT-NAME` → `Fleet Management System`
- `FR-DESCRIPTION-1` → `User can view real-time vehicle locations`
- `ENTITY-1-NAME` → `Vehicle`

---

## Placeholder Reference

### Metadata Placeholders

| Placeholder | Description | Example |
|-------------|-------------|---------|
| `PROJECT-NAME` | Name of the project/micro-app | `Fleet Management System` |
| `PROJECT-TYPE` | Type classification | `Micro-App`, `Constellation`, `Service`, `Library` |
| `VERSION` | Semantic version | `1.0.0` |
| `AUTHOR` | Primary author/owner | `Emmanuel Theodore` |
| `ABSTRACT-TEXT-HERE` | Executive summary (2-3 sentences) | See example below |
| `PURPOSE-STATEMENT` | Why this system exists | `Optimizing fleet operations through intelligent tracking` |
| `DOMAIN` | Business domain | `Logistics`, `Healthcare`, `Finance`, `E-Commerce` |
| `TARGET-STACK` | Technology stack | `Swift/SwiftUI`, `Next.js/React`, `Python/FastAPI` |
| `PARENT-CONSTITUTION` | Parent constitution ID (for sub-constitutions) | `C0-TruckingCompany` |

### Content Section Placeholders

See the full placeholder list in the template file comments.

---

## Template Structure

The template follows the Foundation standard with these articles:

```
Article I:    Purpose and Scope
Article II:   Requirements
Article III:  Architecture
Article IV:   User Experience
Article V:    Business Logic
Article VI:   Integration
Article VII:  Testing Requirements
Article VIII: Implementation Roadmap  ← NEW: MVP & Wave Planning
Article IX:   Deployment
Article X:    Maintenance
Appendices:   Glossary, References, Change Log
```

### Article VIII: Implementation Roadmap (Key for Planner Agent)

This section is **critical for the Planner Agent**. It defines:

| Section | Purpose | Used By |
|---------|---------|---------|
| MVP Definition | What ships first, what's deferred | Planner Agent |
| Wave Decomposition | Discrete build units for pipeline | Planner + Stages Agent |
| Iteration Phases | MVP → v1.0 → v2.0 roadmap | Planner Agent |
| Critical Path | Longest dependency chain | Stages Agent |
| Risk Assessment | Implementation risks | Optimization Agent |
| Planner Directives | Specific instructions for plan generation | Planner Agent |

---

## Usage Patterns

### Pattern 1: Root Constitution (C0)

For the main constellation definition:

```latex
% Use all sections
% PROJECT-TYPE = Constellation
% Include all micro-app references
% Define constellation-wide standards
```

**Required Sections:**
- All articles (I-IX)
- Full glossary
- Complete integration map

### Pattern 2: Micro-App Constitution (C1, C2, ... CN)

For individual micro-apps within a constellation:

```latex
% PROJECT-TYPE = Micro-App
% PARENT-CONSTITUTION = C0-ParentName
% Reference parent constellation
% Focus on specific micro-app scope
```

**Required Sections:**
- Articles I, II, III, VI, VII
- May omit detailed UX (Article IV) if inherited from parent
- Must include entanglement points (Article VI, Section 2)

### Pattern 3: Standalone Service

For independent services:

```latex
% PROJECT-TYPE = Service
% No parent constitution
% Self-contained requirements
```

**Required Sections:**
- All articles
- Emphasis on API contracts (Article VI)

---

## Customization Rules

### Mandatory Sections (NEVER REMOVE)

The following sections are mandatory for Foundation pipeline compatibility:

1. **Article I, Section 3: Success Criteria** - Required for validation
2. **Article II, Section 1: Functional Requirements** - Required for planning
3. **Article II, Section 2.3: Accessibility Requirements** - Foundation mandate
4. **Article VII: Testing Requirements** - Foundation mandate
5. **Appendix C: Change Log** - Required for versioning

### Optional Sections (CAN REMOVE)

These sections may be removed if not applicable:

- Article IV: User Experience (if backend-only service)
- Article VI, Section 2: Entanglement Points (if standalone)
- Appendix A: Glossary (if domain is well-known)
- Appendix B: References (if no external dependencies)

### Adding Custom Sections

To add custom sections:

1. Add new `\section{Article X: Custom Title}` after Article IX
2. Follow existing formatting patterns
3. Use appropriate tcolorbox environments
4. Update Table of Contents by recompiling

---

## Placeholder Examples

### Abstract Example

```latex
\begin{tcolorbox}[colback=gray!10,colframe=primaryblue,width=0.9\textwidth]
The Fleet Management System is a micro-app within the Trucking Company constellation 
that provides real-time vehicle tracking, maintenance scheduling, and driver assignment 
capabilities. It integrates with the Dispatch System and HR Management micro-apps to 
ensure optimal fleet utilization and regulatory compliance.
\end{tcolorbox}
```

### Functional Requirements Example

```latex
\begin{longtable}{|p{2cm}|p{4cm}|p{6cm}|p{2cm}|}
\hline
\textbf{ID} & \textbf{Requirement} & \textbf{Description} & \textbf{Priority} \\
\hline
FR-001 & Vehicle Tracking & Real-time GPS tracking of all fleet vehicles & Must Have \\
\hline
FR-002 & Maintenance Alerts & Automated alerts for scheduled maintenance & Must Have \\
\hline
FR-003 & Driver Assignment & Assign drivers to vehicles with availability check & Should Have \\
\hline
FR-004 & Fuel Tracking & Log and analyze fuel consumption per vehicle & Could Have \\
\hline
\end{longtable}
```

### Architecture Pattern Example

```latex
This Micro-App follows the \textbf{MVVM-S (Model-View-ViewModel-Style)} pattern.

\begin{tcolorbox}[colback=green!5,colframe=secondarygreen,title=Architecture Layers]
\begin{enumerate}
    \item \textbf{Model}: Core data structures (Vehicle, Driver, MaintenanceRecord)
    \item \textbf{View}: SwiftUI views with accessibility-first design
    \item \textbf{ViewModel}: State management and business logic
    \item \textbf{Style}: Separated styling layer (per MVVM-S pattern)
\end{enumerate}
\end{tcolorbox}
```

---

## Wave Decomposition Strategy

The Implementation Roadmap section enables the Planner Agent to create discrete, executable plans.

### Wave Sizing Guidelines

| Size | Lines of Code | Files | Context Window | Parallelizable |
|------|---------------|-------|----------------|----------------|
| **S** (Small) | <500 | 1-2 | Single pass | Yes |
| **M** (Medium) | 500-1500 | 3-5 | Single pass | Yes |
| **L** (Large) | 1500+ | 5+ | Consider splitting | Depends |

### Wave Dependency Notation

```
W1 → W2          # W2 depends on W1 (sequential)
W2 || W3         # W2 and W3 are independent (parallel)
W4 ← [W2, W3]    # W4 depends on both W2 and W3
```

### Example Wave Structure for a CRUD App

```latex
\begin{longtable}{|p{1.5cm}|p{3cm}|p{5cm}|p{2.5cm}|p{1.5cm}|}
\hline
\textbf{Wave} & \textbf{Name} & \textbf{Deliverables} & \textbf{Dependencies} & \textbf{Size} \\
\hline
W1 & Data Models & Entity structs, Codable, Equatable & None & S \\
\hline
W2 & Persistence & CoreData/SQLite layer, CRUD operations & W1 & M \\
\hline
W3 & ViewModels & State management, business logic & W1 & M \\
\hline
W4 & UI Views & SwiftUI views with accessibility & W3 & M \\
\hline
W5 & Integration & API clients, error handling & W2, W3 & M \\
\hline
W6 & Polish & Animations, edge cases, final tests & W4, W5 & S \\
\hline
\end{longtable}
```

### Parallel Execution Example

```
Stage 1: [W1]           # Foundation wave
Stage 2: [W2, W3]       # Can run in parallel (both depend only on W1)
Stage 3: [W4, W5]       # Can run in parallel (different dependency chains)
Stage 4: [W6]           # Final integration (depends on W4 and W5)
```

---

## Integration with Foundation Pipeline

### Phase 0: Constitution Agent Output

The Constitution Agent generates constitutions using this template:

```
Input:  Natural language requirements
Output: Multiple Constitution.tex files
        - C0-{ConstellationName}.tex (root)
        - C1-{MicroAppName}.tex
        - C2-{MicroAppName}.tex
        - ...
```

### Phase 1: Planner Agent Input

The Planner Agent parses constitutions to generate plans:

```
Input:  Constitution.tex files
Output: Plan folders with wave decomposition
        - Plans/plan1/
        - Plans/plan2/
        - Plans/stages.md
```

### Required Tags for Parsing

The Planner Agent looks for these specific sections:

| Section | Used For |
|---------|----------|
| `Article I: Purpose and Scope` | Project scope boundaries |
| `Article II: Requirements` | Task identification |
| `Article III: Architecture` | Component planning |
| `Article VI: Integration` | Dependency mapping |
| `Article VII: Testing` | Test generation |

---

## Validation Checklist

Before submitting a constitution to the pipeline:

- [ ] All `ALL-CAPS-WITH-DASHES` placeholder tokens replaced
- [ ] Version number set correctly
- [ ] Author information complete
- [ ] All mandatory sections present
- [ ] Functional requirements have IDs (FR-XXX)
- [ ] Business rules have IDs (BR-XXX)
- [ ] Accessibility requirements included
- [ ] Testing requirements defined
- [ ] Success criteria are measurable
- [ ] Integration points documented (if applicable)
- [ ] Change log initialized
- [ ] Document compiles without errors

---

## File Naming Convention

```
Constitution/
├── Foundation-Constitution.tex      # Meta-framework constitution
├── Constitution-Template.tex        # This template
├── CONSTITUTION_TEMPLATE_GUIDE.md   # This guide
└── Projects/
    └── {ConstellationName}/
        ├── C0-{ConstellationName}-Constitution.tex
        ├── C1-{MicroApp1}-Constitution.tex
        ├── C2-{MicroApp2}-Constitution.tex
        └── ...
```

---

## Common Issues

### Issue: LaTeX Compilation Error

**Cause:** Special characters in placeholders
**Solution:** Escape special characters: `_` → `\_`, `&` → `\&`, `#` → `\#`

### Issue: Table of Contents Not Updating

**Cause:** LaTeX needs multiple passes
**Solution:** Run `pdflatex` twice, or use `latexmk -pdf`

### Issue: Missing Section Numbers

**Cause:** Removed mandatory sections broke numbering
**Solution:** Use `\section*{Title}` for unnumbered sections, or renumber remaining sections

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-01-XX | Initial template release |

---

## Related Documents

- `Foundation-Constitution.tex` - The meta-framework constitution
- `.cursor/rules/swift.mdc` - Swift development rules
- `Docs/MVVM_S_PATTERN.md` - Architecture pattern documentation
