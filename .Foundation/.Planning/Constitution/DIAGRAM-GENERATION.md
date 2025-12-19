# Mermaid Diagram Conversion Guide

## Generating the Unified Framework Architecture Diagram

The Foundation Constitution includes a visual diagram of the unified framework architecture. To generate this diagram from the Mermaid source file:

### Option 1: Using mermaid-cli (Recommended)

1. **Install mermaid-cli:**
   ```bash
   # Using npm (recommended)
   npm install -g @mermaid-js/mermaid-cli
   
   # OR using Homebrew (macOS)
   brew install mermaid-cli
   
   # OR using Docker
   docker pull minlag/mermaid-cli
   ```

2. **Run the conversion script:**
   ```bash
   python tools/mermaid_to_image.py \
       .planning/Diagrams/unified-framework-architecture.mermaid \
       .planning/Constitution/unified-framework-architecture
   ```

   This will generate:
   - `unified-framework-architecture.png`
   - `unified-framework-architecture.pdf`

### Option 2: Manual Conversion (Online)

1. Open the Mermaid file:
   - File: `.planning/Diagrams/unified-framework-architecture.mermaid`

2. Copy the content and paste into [Mermaid Live Editor](https://mermaid.live/)

3. Export as PDF:
   - Click "Download"
   - Select "PDF" format
   - Save to: `.planning/Constitution/unified-framework-architecture.pdf`

### Option 3: Direct mermaid-cli Command

If you have mermaid-cli installed, you can run directly:

```bash
cd .planning/Constitution
mmdc -i ../Diagrams/unified-framework-architecture.mermaid \
     -o unified-framework-architecture.pdf \
     -w 2400 -H 1800 -b white -s 2
```

## LaTeX Inclusion

The diagram is automatically included in the LaTeX document using:

```latex
\includegraphics[width=\textwidth,height=0.8\textheight,keepaspectratio]
    {unified-framework-architecture.pdf}
```

The figure appears in Section 2.3 (The Unified Execution Pipeline) and is referenced as `Figure~\ref{fig:unified-framework}`.

## Troubleshooting

### "File not found" error in LaTeX
- Ensure the PDF file exists in `.planning/Constitution/`
- Run the conversion script or manually export the diagram
- Recompile the LaTeX document

### Diagram quality issues
- Increase resolution: Change `-w 2400 -H 1800` to higher values
- Use PDF format instead of PNG for better quality
- Adjust scale factor with `-s` parameter (default is 2)

### mermaid-cli not working
- Verify installation: `mmdc --version`
- Check Node.js is installed: `node --version`
- Try Docker version if npm install fails

## Diagram Updates

When updating the Mermaid diagram:
1. Edit `.planning/Diagrams/unified-framework-architecture.mermaid`
2. Regenerate the PDF using one of the methods above
3. Recompile the LaTeX document

The diagram will automatically update in the Constitution PDF.

