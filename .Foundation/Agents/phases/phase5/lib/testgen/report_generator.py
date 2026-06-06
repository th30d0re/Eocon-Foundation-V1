#!/usr/bin/env python3
"""
report_generator.py — Generate a beautiful HTML report from test execution results.

Usage:
    python3 report_generator.py \
        --execution-json results.json \
        --analysis-json analysis.json \
        --screenshots-dir ./screens \
        --output report.html

Features:
    - Self-contained HTML (images embedded as base64)
    - Dark/light mode toggle
    - Summary dashboard with pass/fail stats
    - Code change impact visualization
    - Per-flow step breakdown with screenshots
    - Responsive design
"""

import argparse
import base64
import json
import mimetypes
import os
import sys
from datetime import datetime
from pathlib import Path
from typing import Optional


def encode_image(path: str) -> Optional[str]:
    """Encode an image file as base64 data URI."""
    if not os.path.exists(path):
        return None
    try:
        with open(path, "rb") as f:
            data = f.read()
        mime, _ = mimetypes.guess_type(path)
        mime = mime or "image/png"
        b64 = base64.b64encode(data).decode("utf-8")
        return f"data:{mime};base64,{b64}"
    except Exception:
        return None


def format_duration_ms(ms: int) -> str:
    """Format milliseconds into human-readable duration."""
    if ms < 1000:
        return f"{ms}ms"
    elif ms < 60000:
        return f"{ms / 1000:.1f}s"
    else:
        return f"{ms / 60000:.1f}m"


def truncate(text: str, length: int = 60) -> str:
    """Truncate text with ellipsis."""
    if len(text) <= length:
        return text
    return text[: length - 3] + "..."


def generate_html(
    execution_data: dict,
    analysis_data: Optional[dict],
    screenshots_dir: str,
    project_name: str,
    bundle_id: str,
    simulator: str,
) -> str:
    """Generate the full HTML report."""

    flows = execution_data.get("flows", [])
    if not flows:
        # Single flow result from flow-execute
        flows = [execution_data]

    # Calculate summary stats
    total_flows = len(flows)
    passed_flows = sum(1 for f in flows if f.get("status") == "passed" or all(
        s.get("kind") == "tool" and s.get("tool") in ["gesture-tap", "launch-app", "screenshot"]
        for s in f.get("steps", [])
    ))
    failed_flows = total_flows - passed_flows
    total_steps = sum(len(f.get("steps", [])) for f in flows)
    screenshot_count = sum(
        1 for f in flows
        for s in f.get("steps", [])
        if s.get("kind") == "tool" and s.get("tool") == "screenshot"
    )

    # Collect all screenshots
    screenshot_paths = []
    if os.path.isdir(screenshots_dir):
        for ext in ["*.png", "*.jpg", "*.jpeg"]:
            screenshot_paths.extend(sorted(Path(screenshots_dir).glob(ext)))

    # Changed files from analysis
    impacts = analysis_data.get("impacts", []) if analysis_data else []
    affected_tabs = analysis_data.get("test_plan", {}).get("affected_tabs", []) if analysis_data else []
    regression_targets = analysis_data.get("test_plan", {}).get("regression_targets", []) if analysis_data else []

    now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    html = f'''<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Test Report — {project_name}</title>
    <style>
        :root {{
            --bg: #0d1117;
            --bg-secondary: #161b22;
            --bg-tertiary: #21262d;
            --text: #c9d1d9;
            --text-secondary: #8b949e;
            --border: #30363d;
            --accent: #58a6ff;
            --success: #3fb950;
            --warning: #d29922;
            --danger: #f85149;
            --info: #58a6ff;
        }}
        [data-theme="light"] {{
            --bg: #ffffff;
            --bg-secondary: #f6f8fa;
            --bg-tertiary: #eaeef2;
            --text: #24292f;
            --text-secondary: #57606a;
            --border: #d0d7de;
            --accent: #0969da;
            --success: #1a7f37;
            --warning: #9a6700;
            --danger: #cf222e;
            --info: #0969da;
        }}
        * {{ margin: 0; padding: 0; box-sizing: border-box; }}
        body {{
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
            background: var(--bg);
            color: var(--text);
            line-height: 1.6;
            transition: background 0.3s, color 0.3s;
        }}
        .container {{
            max-width: 1200px;
            margin: 0 auto;
            padding: 2rem;
        }}
        header {{
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 2rem;
            padding-bottom: 1rem;
            border-bottom: 1px solid var(--border);
        }}
        header h1 {{
            font-size: 1.75rem;
            font-weight: 700;
            display: flex;
            align-items: center;
            gap: 0.75rem;
        }}
        .badge {{
            display: inline-flex;
            align-items: center;
            gap: 0.35rem;
            padding: 0.25rem 0.75rem;
            border-radius: 999px;
            font-size: 0.8rem;
            font-weight: 600;
        }}
        .badge-success {{ background: rgba(63, 185, 80, 0.15); color: var(--success); }}
        .badge-danger {{ background: rgba(248, 81, 73, 0.15); color: var(--danger); }}
        .badge-warning {{ background: rgba(210, 153, 34, 0.15); color: var(--warning); }}
        .badge-info {{ background: rgba(88, 166, 255, 0.15); color: var(--info); }}
        .theme-toggle {{
            background: var(--bg-tertiary);
            border: 1px solid var(--border);
            color: var(--text);
            padding: 0.5rem 1rem;
            border-radius: 6px;
            cursor: pointer;
            font-size: 0.875rem;
        }}
        .theme-toggle:hover {{ background: var(--bg-secondary); }}

        /* Summary Cards */
        .summary-grid {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 1rem;
            margin-bottom: 2rem;
        }}
        .summary-card {{
            background: var(--bg-secondary);
            border: 1px solid var(--border);
            border-radius: 12px;
            padding: 1.25rem;
        }}
        .summary-card .label {{
            font-size: 0.8rem;
            color: var(--text-secondary);
            text-transform: uppercase;
            letter-spacing: 0.05em;
            margin-bottom: 0.5rem;
        }}
        .summary-card .value {{
            font-size: 2rem;
            font-weight: 700;
        }}
        .summary-card .value.success {{ color: var(--success); }}
        .summary-card .value.danger {{ color: var(--danger); }}
        .summary-card .value.warning {{ color: var(--warning); }}
        .summary-card .value.info {{ color: var(--info); }}

        /* Sections */
        .section {{
            background: var(--bg-secondary);
            border: 1px solid var(--border);
            border-radius: 12px;
            margin-bottom: 1.5rem;
            overflow: hidden;
        }}
        .section-header {{
            padding: 1rem 1.25rem;
            background: var(--bg-tertiary);
            border-bottom: 1px solid var(--border);
            display: flex;
            justify-content: space-between;
            align-items: center;
        }}
        .section-header h2 {{
            font-size: 1.1rem;
            font-weight: 600;
            display: flex;
            align-items: center;
            gap: 0.5rem;
        }}
        .section-body {{
            padding: 1.25rem;
        }}

        /* Code Changes */
        .file-list {{
            list-style: none;
        }}
        .file-item {{
            display: flex;
            align-items: center;
            gap: 0.75rem;
            padding: 0.6rem 0;
            border-bottom: 1px solid var(--border);
        }}
        .file-item:last-child {{ border-bottom: none; }}
        .file-icon {{
            width: 24px;
            text-align: center;
            font-size: 1rem;
        }}
        .file-name {{
            flex: 1;
            font-family: "SFMono-Regular", Consolas, monospace;
            font-size: 0.85rem;
        }}
        .file-stats {{
            font-size: 0.8rem;
            color: var(--text-secondary);
        }}
        .file-priority {{
            font-size: 0.7rem;
            text-transform: uppercase;
            font-weight: 700;
            padding: 0.15rem 0.5rem;
            border-radius: 4px;
        }}
        .priority-critical {{ background: rgba(248, 81, 73, 0.2); color: var(--danger); }}
        .priority-high {{ background: rgba(210, 153, 34, 0.2); color: var(--warning); }}
        .priority-medium {{ background: rgba(88, 166, 255, 0.2); color: var(--info); }}
        .priority-low {{ background: rgba(139, 148, 158, 0.2); color: var(--text-secondary); }}

        /* Tabs */
        .tab-list {{
            display: flex;
            flex-wrap: wrap;
            gap: 0.5rem;
        }}
        .tab-chip {{
            background: var(--bg-tertiary);
            border: 1px solid var(--border);
            padding: 0.4rem 0.8rem;
            border-radius: 6px;
            font-size: 0.85rem;
        }}

        /* Flows */
        .flow {{
            border: 1px solid var(--border);
            border-radius: 10px;
            margin-bottom: 1rem;
            overflow: hidden;
        }}
        .flow-header {{
            padding: 1rem 1.25rem;
            background: var(--bg-tertiary);
            display: flex;
            justify-content: space-between;
            align-items: center;
            cursor: pointer;
        }}
        .flow-header:hover {{ background: var(--bg-secondary); }}
        .flow-title {{
            font-weight: 600;
            font-size: 0.95rem;
        }}
        .flow-meta {{
            display: flex;
            gap: 0.75rem;
            align-items: center;
        }}
        .flow-body {{
            padding: 0;
            max-height: 2000px;
            overflow: hidden;
            transition: max-height 0.3s;
        }}
        .flow-body.collapsed {{ max-height: 0; }}

        /* Steps */
        .step {{
            display: flex;
            align-items: flex-start;
            gap: 0.75rem;
            padding: 0.75rem 1.25rem;
            border-bottom: 1px solid var(--border);
        }}
        .step:last-child {{ border-bottom: none; }}
        .step-icon {{
            width: 28px;
            height: 28px;
            border-radius: 6px;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 0.85rem;
            flex-shrink: 0;
        }}
        .step-icon.echo {{ background: var(--bg-tertiary); }}
        .step-icon.tap {{ background: rgba(88, 166, 255, 0.15); }}
        .step-icon.screenshot {{ background: rgba(63, 185, 80, 0.15); }}
        .step-icon.swipe {{ background: rgba(210, 153, 34, 0.15); }}
        .step-icon.launch {{ background: rgba(139, 148, 158, 0.15); }}
        .step-icon.unknown {{ background: var(--bg-tertiary); }}
        .step-content {{ flex: 1; }}
        .step-title {{
            font-size: 0.9rem;
            font-weight: 500;
        }}
        .step-detail {{
            font-size: 0.8rem;
            color: var(--text-secondary);
            margin-top: 0.15rem;
        }}
        .step-result {{
            font-size: 0.8rem;
            margin-top: 0.25rem;
        }}
        .step-result.success {{ color: var(--success); }}
        .step-result.error {{ color: var(--danger); }}

        /* Screenshots */
        .screenshot {{
            max-width: 280px;
            border-radius: 8px;
            border: 1px solid var(--border);
            cursor: pointer;
            transition: transform 0.2s;
        }}
        .screenshot:hover {{ transform: scale(1.02); }}
        .screenshot-modal {{
            display: none;
            position: fixed;
            top: 0; left: 0; right: 0; bottom: 0;
            background: rgba(0, 0, 0, 0.9);
            z-index: 1000;
            align-items: center;
            justify-content: center;
            cursor: zoom-out;
        }}
        .screenshot-modal.active {{ display: flex; }}
        .screenshot-modal img {{
            max-width: 90vw;
            max-height: 90vh;
            border-radius: 8px;
        }}
        .screenshot-grid {{
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
            gap: 1rem;
        }}
        .screenshot-item {{
            text-align: center;
        }}
        .screenshot-item img {{
            width: 100%;
            max-width: 280px;
            border-radius: 8px;
            border: 1px solid var(--border);
        }}
        .screenshot-label {{
            font-size: 0.75rem;
            color: var(--text-secondary);
            margin-top: 0.5rem;
        }}

        /* Metadata */
        .metadata {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 0.5rem;
            font-size: 0.85rem;
            color: var(--text-secondary);
        }}
        .metadata-item {{
            display: flex;
            gap: 0.5rem;
        }}
        .metadata-item strong {{
            color: var(--text);
            min-width: 100px;
        }}

        /* Footer */
        footer {{
            text-align: center;
            padding: 2rem;
            color: var(--text-secondary);
            font-size: 0.8rem;
            border-top: 1px solid var(--border);
            margin-top: 2rem;
        }}
    </style>
</head>
<body data-theme="dark">
    <div class="container">
        <header>
            <h1>
                <span>🧪</span>
                <div>
                    Test Report
                    <div style="font-size:0.85rem;font-weight:400;color:var(--text-secondary)">{project_name}</div>
                </div>
            </h1>
            <div style="display:flex;gap:0.75rem;align-items:center">
                <span class="badge {'badge-success' if failed_flows == 0 else 'badge-danger'}">
                    {'✅ All Passed' if failed_flows == 0 else f'❌ {failed_flows} Failed'}
                </span>
                <button class="theme-toggle" onclick="toggleTheme()">🌓</button>
            </div>
        </header>

        <!-- Summary Cards -->
        <div class="summary-grid">
            <div class="summary-card">
                <div class="label">Flows</div>
                <div class="value info">{total_flows}</div>
            </div>
            <div class="summary-card">
                <div class="label">Passed</div>
                <div class="value success">{passed_flows}</div>
            </div>
            <div class="summary-card">
                <div class="label">Failed</div>
                <div class="value {'success' if failed_flows == 0 else 'danger'}">{failed_flows}</div>
            </div>
            <div class="summary-card">
                <div class="label">Steps</div>
                <div class="value info">{total_steps}</div>
            </div>
            <div class="summary-card">
                <div class="label">Screenshots</div>
                <div class="value info">{screenshot_count}</div>
            </div>
            <div class="summary-card">
                <div class="label">Coverage</div>
                <div class="value warning">{len(affected_tabs)} tabs</div>
            </div>
        </div>
'''

    # Metadata section
    html += f'''
        <div class="section">
            <div class="section-header">
                <h2>📋 Run Metadata</h2>
            </div>
            <div class="section-body">
                <div class="metadata">
                    <div class="metadata-item"><strong>Generated:</strong> {now}</div>
                    <div class="metadata-item"><strong>Bundle ID:</strong> {bundle_id}</div>
                    <div class="metadata-item"><strong>Simulator:</strong> {simulator}</div>
                    <div class="metadata-item"><strong>Files Changed:</strong> {len(impacts)}</div>
                </div>
            </div>
        </div>
'''

    # Code Changes section
    if impacts:
        html += '''
        <div class="section">
            <div class="section-header">
                <h2>📝 Code Changes Detected</h2>
            </div>
            <div class="section-body">
                <ul class="file-list">
'''
        for impact in impacts:
            file_path = impact.get("file_path", "")
            change_type = impact.get("change_type", "modified")
            added = impact.get("lines_added", 0)
            deleted = impact.get("lines_deleted", 0)
            priority = impact.get("test_priority", "low")
            icon = {"added": "➕", "modified": "✏️", "deleted": "🗑️", "renamed": "📛"}.get(change_type, "📝")
            html += f'''
                    <li class="file-item">
                        <span class="file-icon">{icon}</span>
                        <span class="file-name">{file_path}</span>
                        <span class="file-stats">+{added}/-{deleted}</span>
                        <span class="file-priority priority-{priority}">{priority}</span>
                    </li>
'''
        html += '''
                </ul>
            </div>
        </div>
'''

    # Affected Tabs
    if affected_tabs:
        html += '''
        <div class="section">
            <div class="section-header">
                <h2>🎯 Affected Tabs</h2>
            </div>
            <div class="section-body">
                <div class="tab-list">
'''
        for tab in affected_tabs:
            html += f'<span class="tab-chip">{tab.title()}</span>'
        html += '''
                </div>
            </div>
        </div>
'''

    # Regression Targets
    if regression_targets:
        html += '''
        <div class="section">
            <div class="section-header">
                <h2>🔄 Regression Targets</h2>
            </div>
            <div class="section-body">
                <div class="tab-list">
'''
        for target in regression_targets:
            html += f'<span class="tab-chip">{target}</span>'
        html += '''
                </div>
            </div>
        </div>
'''

    # Flows section
    if flows:
        html += '''
        <div class="section">
            <div class="section-header">
                <h2>▶️ Test Flows</h2>
            </div>
            <div class="section-body">
'''
        for idx, flow in enumerate(flows):
            flow_name = flow.get("name", flow.get("flow", f"Flow {idx + 1}"))
            steps = flow.get("steps", [])
            step_count = len(steps)
            has_failures = any(
                s.get("kind") == "tool" and s.get("result", {}).get("error")
                for s in steps
            )

            html += f'''
                <div class="flow">
                    <div class="flow-header" onclick="toggleFlow(this)">
                        <div class="flow-title">{flow_name}</div>
                        <div class="flow-meta">
                            <span class="badge {'badge-danger' if has_failures else 'badge-success'}">
                                {'❌ Failed' if has_failures else '✅ Passed'}
                            </span>
                            <span style="color:var(--text-secondary);font-size:0.8rem">{step_count} steps</span>
                        </div>
                    </div>
                    <div class="flow-body">
'''
            for step in steps:
                kind = step.get("kind", "")
                tool = step.get("tool", "")
                message = step.get("message", "")
                result = step.get("result", {})
                output_hint = step.get("outputHint", "")

                if kind == "echo":
                    icon = "💬"
                    icon_class = "echo"
                    title = message or "Echo"
                    detail = ""
                    result_text = ""
                elif kind == "tool":
                    if tool == "launch-app":
                        icon = "🚀"
                        icon_class = "launch"
                        title = "Launch App"
                        detail = f"Bundle: {result.get('bundleId', bundle_id)}"
                        result_text = "Launched" if result.get("launched") else "Failed"
                    elif tool == "gesture-tap":
                        icon = "👆"
                        icon_class = "tap"
                        title = f"Tap at ({step.get('args', {}).get('x', '?')}, {step.get('args', {}).get('y', '?')})"
                        detail = ""
                        result_text = "Tapped" if result.get("tapped") else "Failed"
                    elif tool == "gesture-swipe":
                        icon = "👋"
                        icon_class = "swipe"
                        title = f"Swipe {step.get('args', {}).get('direction', '')}"
                        detail = ""
                        result_text = "Swiped" if result.get("swiped") else "Failed"
                    elif tool == "screenshot":
                        icon = "📸"
                        icon_class = "screenshot"
                        title = "Screenshot"
                        detail = ""
                        result_text = ""
                    elif tool == "keyboard":
                        icon = "⌨️"
                        icon_class = "tap"
                        title = f"Type: {step.get('args', {}).get('text', '')}"
                        detail = ""
                        result_text = "Typed" if result.get("typed") else "Failed"
                    else:
                        icon = "🔧"
                        icon_class = "unknown"
                        title = tool
                        detail = ""
                        result_text = ""
                else:
                    icon = "❓"
                    icon_class = "unknown"
                    title = kind
                    detail = ""
                    result_text = ""

                # Try to embed screenshot inline
                screenshot_html = ""
                if output_hint == "image" and result.get("path"):
                    img_data = encode_image(result["path"])
                    if img_data:
                        screenshot_html = f'''
                        <div style="margin-top:0.5rem">
                            <img src="{img_data}" class="screenshot" onclick="openModal(this.src)" alt="Screenshot">
                        </div>'''

                result_class = "success" if result_text and "Fail" not in result_text else "error" if result_text else ""

                html += f'''
                        <div class="step">
                            <div class="step-icon {icon_class}">{icon}</div>
                            <div class="step-content">
                                <div class="step-title">{title}</div>
                                {f'<div class="step-detail">{detail}</div>' if detail else ''}
                                {f'<div class="step-result {result_class}">{result_text}</div>' if result_text else ''}
                                {screenshot_html}
                            </div>
                        </div>
'''

            html += '''
                    </div>
                </div>
'''
        html += '''
            </div>
        </div>
'''

    # Screenshot Gallery
    if screenshot_paths:
        html += '''
        <div class="section">
            <div class="section-header">
                <h2>🖼️ Screenshot Gallery</h2>
            </div>
            <div class="section-body">
                <div class="screenshot-grid">
'''
        for path in screenshot_paths:
            img_data = encode_image(str(path))
            if img_data:
                label = path.stem.replace("_", " ").title()
                html += f'''
                    <div class="screenshot-item">
                        <img src="{img_data}" onclick="openModal(this.src)" alt="{label}">
                        <div class="screenshot-label">{label}</div>
                    </div>
'''
        html += '''
                </div>
            </div>
        </div>
'''

    # Close container and add scripts
    html += f'''
        <footer>
            Generated by AmmoScan Test Pipeline • {now}<br>
            <span style="opacity:0.6">Argent Runtime Agent — Stage 5b</span>
        </footer>
    </div>

    <div class="screenshot-modal" id="modal" onclick="closeModal()">
        <img src="" id="modal-img" alt="Full size">
    </div>

    <script>
        function toggleTheme() {{
            const body = document.body;
            const current = body.getAttribute('data-theme');
            body.setAttribute('data-theme', current === 'dark' ? 'light' : 'dark');
        }}
        function toggleFlow(header) {{
            const body = header.nextElementSibling;
            body.classList.toggle('collapsed');
        }}
        function openModal(src) {{
            document.getElementById('modal-img').src = src;
            document.getElementById('modal').classList.add('active');
        }}
        function closeModal() {{
            document.getElementById('modal').classList.remove('active');
        }}
        document.addEventListener('keydown', function(e) {{
            if (e.key === 'Escape') closeModal();
        }});
    </script>
</body>
</html>
'''

    return html


def main():
    parser = argparse.ArgumentParser(description="Generate HTML test report")
    parser.add_argument("--execution-json", required=True, help="Flow execution result JSON")
    parser.add_argument("--analysis-json", help="Code change analysis JSON")
    parser.add_argument("--screenshots-dir", default="./screenshots", help="Directory with screenshot files")
    parser.add_argument("--project-name", default="AmmoScan", help="Project name for report title")
    parser.add_argument("--bundle-id", default="", help="App bundle ID")
    parser.add_argument("--simulator", default="", help="Simulator name/UDID")
    parser.add_argument("--output", "-o", required=True, help="Output HTML file path")
    args = parser.parse_args()

    with open(args.execution_json, "r") as f:
        execution_data = json.load(f)

    analysis_data = None
    if args.analysis_json and os.path.exists(args.analysis_json):
        with open(args.analysis_json, "r") as f:
            analysis_data = json.load(f)

    html = generate_html(
        execution_data=execution_data,
        analysis_data=analysis_data,
        screenshots_dir=args.screenshots_dir,
        project_name=args.project_name,
        bundle_id=args.bundle_id,
        simulator=args.simulator,
    )

    os.makedirs(os.path.dirname(os.path.abspath(args.output)) or ".", exist_ok=True)
    with open(args.output, "w", encoding="utf-8") as f:
        f.write(html)

    print(f"✅ Report generated: {args.output}")
    print(f"   Flows: {len(execution_data.get('flows', [execution_data]))}")
    print(f"   Screenshots: {len([p for p in Path(args.screenshots_dir).glob('*') if p.suffix in ['.png', '.jpg', '.jpeg']]) if os.path.isdir(args.screenshots_dir) else 0}")


if __name__ == "__main__":
    main()
