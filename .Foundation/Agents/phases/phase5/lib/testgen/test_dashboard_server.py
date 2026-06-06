#!/usr/bin/env python3
"""
Test Management Dashboard Server
Local web UI for viewing, managing, and running Maestro test flows.

Usage:
    python3 test_dashboard_server.py --project-dir ./AmmoScan --port 8080
"""

import argparse
import json
import os
import subprocess
import sys
import threading
import time
from datetime import datetime
from pathlib import Path
from typing import Optional

from fastapi import FastAPI, Request, HTTPException
from fastapi.responses import HTMLResponse, JSONResponse, FileResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
import uvicorn


app = FastAPI(title="BuildVerify Test Dashboard")

# Global state
PROJECT_DIR: Path = Path(".")
MAESTRO_DIR: Path = Path(".maestro")
ARTIFACTS_DIR: Path = Path("Artifacts")
BUNDLE_ID: str = ""

# Simple in-memory test database (SQLite would be better for production)
TEST_DB: dict = {}


def load_manifest() -> dict:
    """Load Maestro flow manifest."""
    manifest_path = PROJECT_DIR / ".maestro" / "manifest.json"
    if manifest_path.exists():
        return json.loads(manifest_path.read_text(encoding="utf-8"))
    return {"flows": [], "categories": {}}


def load_flows() -> list:
    """Load all Maestro flows from disk."""
    flows = []
    manifest = load_manifest()
    for flow_info in manifest.get("flows", []):
        flow_file = Path(flow_info["file"])
        if flow_file.exists():
            content = flow_file.read_text(encoding="utf-8")
            flows.append({
                **flow_info,
                "content": content,
                "content_preview": "\n".join(content.split("\n")[:15]),
            })
    return flows


def get_test_runs() -> list:
    """Get historical test runs from artifacts."""
    runs = []
    if not ARTIFACTS_DIR.exists():
        return runs
    for run_dir in sorted(ARTIFACTS_DIR.glob("test_*"), reverse=True)[:20]:
        summary_file = run_dir / "pipeline_summary.json"
        maestro_summary = run_dir / "maestro" / "summary.json"
        run_data = {
            "id": run_dir.name,
            "timestamp": run_dir.name.replace("test_", ""),
            "path": str(run_dir),
            "stages": {},
            "maestro": {},
        }
        if summary_file.exists():
            try:
                summary = json.loads(summary_file.read_text())
                run_data["stages"] = summary
            except Exception:
                pass
        if maestro_summary.exists():
            try:
                maestro = json.loads(maestro_summary.read_text())
                run_data["maestro"] = maestro
            except Exception:
                pass
        runs.append(run_data)
    return runs


def get_screenshots() -> list:
    """Get all screenshots from test runs."""
    screenshots = []
    if not ARTIFACTS_DIR.exists():
        return screenshots
    for run_dir in ARTIFACTS_DIR.glob("test_*"):
        maestro_screens = run_dir / "maestro" / "screenshots"
        if maestro_screens.exists():
            for img in sorted(maestro_screens.glob("*.png")):
                screenshots.append({
                    "path": str(img),
                    "name": img.name,
                    "run": run_dir.name,
                    "timestamp": run_dir.stat().st_mtime,
                })
    return sorted(screenshots, key=lambda x: x["timestamp"], reverse=True)[:50]


# ── HTML Routes ──

def render_dashboard(flows, runs, total_flows, total_runs, total_screenshots) -> str:
    """Render the dashboard HTML."""
    flows_html = ""
    for flow in flows[:8]:
        flows_html += f'''
        <li class="flow-item" onclick="location.href='/flow/{flow['name']}'">
            <div>
                <strong>{flow['name']}</strong>
                <div style="font-size: 0.8rem; color: var(--text-muted);">{flow['steps']} steps</div>
            </div>
            <span class="badge badge-{flow['category']}">{flow['category']}</span>
        </li>'''

    more_flows = f'<p style="text-align: center; margin-top: 10px;"><a href="/flows">View all {len(flows)} flows →</a></p>' if len(flows) > 8 else ""

    runs_html = ""
    for run in runs[:5]:
        status = "pass" if run.get("maestro", {}).get("status") == "passed" else "fail" if run.get("maestro", {}).get("status") == "failed" else "skip"
        passed = run.get("maestro", {}).get("passed_flows", 0)
        total = run.get("maestro", {}).get("total_flows", 0)
        runs_html += f'''
        <div class="run-row">
            <div><span class="status-dot status-{status}"></span>{run['id']}</div>
            <div style="color: var(--text-muted); font-size: 0.85rem;">{passed}/{total} passed</div>
        </div>'''
    if not runs:
        runs_html = '<p style="color: var(--text-muted);">No test runs yet.</p>'

    return f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>BuildVerify Test Dashboard</title>
    <style>
        :root {{ --bg: #0f172a; --surface: #1e293b; --surface-hover: #334155; --text: #f1f5f9; --text-muted: #94a3b8; --accent: #3b82f6; --accent-hover: #2563eb; --success: #22c55e; --warning: #eab308; --danger: #ef4444; --border: #334155; }}
        * {{ margin: 0; padding: 0; box-sizing: border-box; }}
        body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: var(--bg); color: var(--text); line-height: 1.6; }}
        .container {{ max-width: 1400px; margin: 0 auto; padding: 20px; }}
        header {{ background: var(--surface); border-bottom: 1px solid var(--border); padding: 20px 0; margin-bottom: 30px; }}
        header h1 {{ font-size: 1.8rem; font-weight: 700; }}
        header p {{ color: var(--text-muted); }}
        .grid {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; }}
        .card {{ background: var(--surface); border: 1px solid var(--border); border-radius: 12px; padding: 20px; transition: transform 0.2s, border-color 0.2s; }}
        .card:hover {{ border-color: var(--accent); }}
        .card h2 {{ font-size: 1.1rem; margin-bottom: 15px; color: var(--accent); }}
        .stats {{ display: grid; grid-template-columns: repeat(3, 1fr); gap: 15px; margin-bottom: 30px; }}
        .stat {{ background: var(--surface); border: 1px solid var(--border); border-radius: 12px; padding: 20px; text-align: center; }}
        .stat-value {{ font-size: 2rem; font-weight: 700; }}
        .stat-label {{ color: var(--text-muted); font-size: 0.9rem; }}
        .stat.success .stat-value {{ color: var(--success); }}
        .stat.warning .stat-value {{ color: var(--warning); }}
        .flow-list {{ list-style: none; }}
        .flow-item {{ display: flex; justify-content: space-between; align-items: center; padding: 12px; border-bottom: 1px solid var(--border); cursor: pointer; }}
        .flow-item:hover {{ background: var(--surface-hover); }}
        .flow-item:last-child {{ border-bottom: none; }}
        .badge {{ display: inline-block; padding: 4px 10px; border-radius: 20px; font-size: 0.75rem; font-weight: 600; text-transform: uppercase; }}
        .badge-smoke {{ background: rgba(34, 197, 94, 0.2); color: var(--success); }}
        .badge-regression {{ background: rgba(234, 179, 8, 0.2); color: var(--warning); }}
        .badge-full {{ background: rgba(59, 130, 246, 0.2); color: var(--accent); }}
        .btn {{ display: inline-flex; align-items: center; gap: 8px; padding: 10px 20px; border: none; border-radius: 8px; background: var(--accent); color: white; font-size: 0.9rem; font-weight: 600; cursor: pointer; text-decoration: none; transition: background 0.2s; }}
        .btn:hover {{ background: var(--accent-hover); }}
        .run-row {{ display: flex; justify-content: space-between; padding: 12px; border-bottom: 1px solid var(--border); }}
        .status-dot {{ width: 10px; height: 10px; border-radius: 50%; display: inline-block; margin-right: 8px; }}
        .status-pass {{ background: var(--success); }}
        .status-fail {{ background: var(--danger); }}
        .status-skip {{ background: var(--text-muted); }}
        .nav {{ display: flex; gap: 10px; margin-bottom: 20px; }}
        .nav a {{ padding: 8px 16px; border-radius: 8px; color: var(--text); text-decoration: none; background: var(--surface); border: 1px solid var(--border); }}
        .nav a.active {{ background: var(--accent); border-color: var(--accent); }}
    </style>
</head>
<body>
    <header><div class="container"><h1>🔧 BuildVerify Test Dashboard</h1><p>Maestro UI Flow Management & Test Results</p></div></header>
    <div class="container">
        <div class="nav">
            <a href="/" class="active">Overview</a>
            <a href="/flows">Flows</a>
            <a href="/runs">Test Runs</a>
            <a href="/screenshots">Screenshots</a>
        </div>
        <div class="stats">
            <div class="stat success"><div class="stat-value">{total_flows}</div><div class="stat-label">Total Flows</div></div>
            <div class="stat warning"><div class="stat-value">{total_runs}</div><div class="stat-label">Test Runs</div></div>
            <div class="stat"><div class="stat-value">{total_screenshots}</div><div class="stat-label">Screenshots</div></div>
        </div>
        <div class="grid">
            <div class="card">
                <h2>📋 Test Flows</h2>
                <ul class="flow-list">{flows_html}</ul>
                {more_flows}
            </div>
            <div class="card">
                <h2>🧪 Recent Test Runs</h2>
                {runs_html}
            </div>
            <div class="card">
                <h2>⚡ Quick Actions</h2>
                <div style="display: flex; flex-direction: column; gap: 10px;">
                    <a href="/api/run/smoke" class="btn">Run Smoke Tests</a>
                    <a href="/api/run/all" class="btn">Run All Tests</a>
                    <a href="/api/discover" class="btn" style="background: var(--surface-hover);">Rediscover Flows</a>
                </div>
            </div>
        </div>
    </div>
</body>
</html>"""


@app.get("/", response_class=HTMLResponse)
def dashboard(request: Request):
    flows = load_flows()
    runs = get_test_runs()
    screenshots = get_screenshots()
    return HTMLResponse(content=render_dashboard(
        flows=flows,
        runs=runs,
        total_flows=len(flows),
        total_runs=len(runs),
        total_screenshots=len(screenshots),
    ))


@app.get("/flows", response_class=HTMLResponse)
def flows_page(request: Request):
    flows = load_flows()
    html = """
    <!DOCTYPE html>
    <html><head><style>
    :root { --bg: #0f172a; --surface: #1e293b; --text: #f1f5f9; --accent: #3b82f6; --border: #334155; }
    body { font-family: sans-serif; background: var(--bg); color: var(--text); padding: 20px; }
    .container { max-width: 1200px; margin: 0 auto; }
    .flow-card { background: var(--surface); border: 1px solid var(--border); border-radius: 8px; padding: 15px; margin-bottom: 10px; }
    .badge { padding: 4px 10px; border-radius: 20px; font-size: 0.75rem; }
    .badge-smoke { background: rgba(34,197,94,0.2); color: #22c55e; }
    .badge-regression { background: rgba(234,179,8,0.2); color: #eab308; }
    pre { background: #0f172a; padding: 10px; border-radius: 6px; overflow-x: auto; font-size: 0.8rem; }
    </style></head><body>
    <div class="container">
        <h1>📋 All Test Flows</h1>
        <p><a href="/">← Back to Dashboard</a></p>
    """
    for flow in flows:
        html += f"""
        <div class="flow-card">
            <div style="display:flex; justify-content:space-between; align-items:center;">
                <h3>{flow['name']}</h3>
                <span class="badge badge-{flow['category']}">{flow['category']}</span>
            </div>
            <p style="color:#94a3b8; font-size:0.9rem;">{flow['description']}</p>
            <p>{flow['steps']} steps</p>
            <pre>{flow['content_preview']}</pre>
            <p><a href="/api/run/{flow['category']}/{flow['name']}">▶ Run this flow</a></p>
        </div>
        """
    html += "</div></body></html>"
    return HTMLResponse(content=html)


@app.get("/api/status")
def api_status():
    """Get current dashboard status."""
    manifest = load_manifest()
    return {
        "project": str(PROJECT_DIR),
        "bundle_id": BUNDLE_ID,
        "total_flows": sum(manifest.get("categories", {}).values()),
        "categories": manifest.get("categories", {}),
        "recent_runs": len(get_test_runs()),
    }


@app.get("/api/flows")
def api_flows():
    """Get all flows as JSON."""
    return {"flows": load_flows()}


@app.post("/api/discover")
def api_discover():
    """Trigger flow discovery from code analysis."""
    try:
        # Run Swift analyzer
        structure_path = PROJECT_DIR / ".maestro" / "app_structure.json"
        result = subprocess.run(
            [sys.executable, "-m", "swift_ui_analyzer",
             "--project-dir", str(PROJECT_DIR),
             "--output", str(structure_path)],
            capture_output=True,
            text=True,
            cwd=str(Path(__file__).parent),
        )
        if result.returncode != 0:
            return {"status": "error", "message": result.stderr}

        # Run flow generator
        gen_result = subprocess.run(
            [sys.executable, "-m", "maestro_flow_generator",
             "--app-structure", str(structure_path),
             "--output-dir", str(PROJECT_DIR / ".maestro"),
             "--bundle-id", BUNDLE_ID],
            capture_output=True,
            text=True,
            cwd=str(Path(__file__).parent),
        )

        return {
            "status": "success",
            "analyzer_output": result.stdout,
            "generator_output": gen_result.stdout,
        }
    except Exception as e:
        return {"status": "error", "message": str(e)}


@app.get("/api/run/{category}/{flow_name}")
def api_run_flow(category: str, flow_name: str):
    """Run a specific Maestro flow."""
    flow_file = PROJECT_DIR / ".maestro" / category / f"{flow_name}.yaml"
    if not flow_file.exists():
        raise HTTPException(status_code=404, detail="Flow not found")

    try:
        result = subprocess.run(
            ["maestro", "test", str(flow_file)],
            capture_output=True,
            text=True,
            timeout=300,
        )
        return {
            "status": "success" if result.returncode == 0 else "failed",
            "returncode": result.returncode,
            "stdout": result.stdout,
            "stderr": result.stderr,
        }
    except Exception as e:
        return {"status": "error", "message": str(e)}


@app.get("/api/run/{category}")
def api_run_category(category: str):
    """Run all flows in a category."""
    cat_dir = PROJECT_DIR / ".maestro" / category
    if not cat_dir.exists():
        raise HTTPException(status_code=404, detail="Category not found")

    results = []
    for flow_file in sorted(cat_dir.glob("*.yaml")):
        try:
            result = subprocess.run(
                ["maestro", "test", str(flow_file)],
                capture_output=True,
                text=True,
                timeout=300,
            )
            results.append({
                "flow": flow_file.stem,
                "status": "passed" if result.returncode == 0 else "failed",
            })
        except Exception as e:
            results.append({"flow": flow_file.stem, "status": "error", "message": str(e)})

    return {"category": category, "results": results}


def main():
    parser = argparse.ArgumentParser(description="Test Management Dashboard")
    parser.add_argument("--project-dir", default=".", help="Project directory")
    parser.add_argument("--port", type=int, default=8080, help="Server port")
    parser.add_argument("--bundle-id", default="", help="App bundle ID")
    args = parser.parse_args()

    global PROJECT_DIR, MAESTRO_DIR, ARTIFACTS_DIR, BUNDLE_ID
    PROJECT_DIR = Path(args.project_dir).resolve()
    MAESTRO_DIR = PROJECT_DIR / ".maestro"
    ARTIFACTS_DIR = PROJECT_DIR / "Artifacts"
    BUNDLE_ID = args.bundle_id

    print(f"🚀 Test Dashboard starting on http://localhost:{args.port}")
    print(f"   Project: {PROJECT_DIR}")
    print(f"   Maestro: {MAESTRO_DIR}")

    uvicorn.run(app, host="0.0.0.0", port=args.port, log_level="warning")


if __name__ == "__main__":
    main()
