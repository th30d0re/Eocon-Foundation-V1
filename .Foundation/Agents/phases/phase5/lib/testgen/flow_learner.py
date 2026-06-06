#!/usr/bin/env python3
"""
Flow Learner — Self-healing assertion discovery for Maestro flows.

Runs Maestro flows, observes which assertions actually pass, and builds
a knowledge base of "reliable" assertions per view. Future flow generations
use only proven assertions, eliminating false positives from static analysis.

Usage:
    # Learn from a Maestro test run
    python3 flow_learner.py --learn-from ./Artifacts/test_xxx/maestro/ \
        --app-structure app_structure.json \
        --output-knowledge learned_assertions.json

    # Regenerate flows using learned knowledge
    python3 flow_learner.py --regenerate \
        --knowledge learned_assertions.json \
        --output-dir .maestro/
"""

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path
from typing import Any


def extract_accessible_texts_from_hierarchy(node: dict, texts: set):
    """Recursively extract all accessibilityText values from hierarchy."""
    attrs = node.get("attributes", {})
    text = attrs.get("accessibilityText", "")
    if text and len(text) > 1 and text not in ["true", "false"]:
        texts.add(text)
    # Also capture regular text attribute
    text_attr = attrs.get("text", "")
    if text_attr and len(text_attr) > 1:
        texts.add(text_attr)
    for child in node.get("children", []):
        extract_accessible_texts_from_hierarchy(child, texts)


def parse_maestro_commands(commands_json: Path) -> dict:
    """Parse a Maestro commands JSON to extract assertion results."""
    data = json.loads(commands_json.read_text(encoding="utf-8"))
    results = {
        "flow_name": "",
        "assertions": [],
        "taps": [],
        "screenshots": [],
        "accessible_texts": set(),
    }

    for cmd in data:
        cmd_type = list(cmd.get("command", {}).keys())[0] if cmd.get("command") else ""
        metadata = cmd.get("metadata", {})
        status = metadata.get("status", "UNKNOWN")
        duration = metadata.get("duration", 0)

        if cmd_type == "assertConditionCommand":
            cond = cmd.get("command", {}).get("assertConditionCommand", {})
            condition = cond.get("condition", {})
            visible = condition.get("visible", {})
            label = visible.get("text", "")
            if not label:
                label = visible.get("textRegex", "")
            if not label and isinstance(visible, dict):
                label = visible.get("text", visible.get("id", visible.get("textRegex", "")))
            results["assertions"].append({
                "text": label,
                "status": status,
                "duration_ms": duration,
            })
            # If failed, extract actual accessible texts from hierarchy
            if status == "FAILED":
                error = metadata.get("error", {})
                hierarchy = error.get("hierarchyRoot", {})
                if hierarchy:
                    extract_accessible_texts_from_hierarchy(hierarchy, results["accessible_texts"])
        elif cmd_type == "tapOnElement":
            tap = cmd.get("command", {}).get("tapOnElement", {})
            selector = tap.get("selector", {})
            label = selector.get("text", selector.get("textRegex", selector.get("id", "")))
            results["taps"].append({
                "text": label,
                "status": status,
                "duration_ms": duration,
            })
        elif cmd_type == "takeScreenshotCommand":
            screenshot = cmd.get("command", {}).get("takeScreenshotCommand", {})
            results["screenshots"].append({
                "name": screenshot.get("path", ""),
                "status": status,
            })

    # Extract flow name from filename
    fname = commands_json.stem
    match = re.search(r'commands-\(([^)]+)\)', fname)
    if match:
        results["flow_name"] = match.group(1)

    return results


def learn_from_run(maestro_dir: Path, app_structure: dict) -> dict:
    """Learn reliable assertions from a Maestro test run."""
    knowledge = {
        "version": 1,
        "learned_from": str(maestro_dir),
        "views": {},
        "global_reliable": set(),
    }

    # Map flow names to target views
    flow_to_view = {}
    for flow in app_structure.get("user_flows", []):
        views = flow.get("views", [])
        if views:
            flow_to_view[flow["name"]] = views[-1]  # Last view in flow is target

    # Also map smoke test names
    for tab in app_structure.get("tab_structure", []):
        flow_name = f"smoke_tab_{tab['label'].lower().replace(' ', '_')}"
        flow_to_view[flow_name] = tab.get("view", "")

    # Parse all commands JSON files
    for cmd_json in sorted(maestro_dir.glob("commands-*.json")):
        results = parse_maestro_commands(cmd_json)
        flow_name = results["flow_name"]
        target_view = flow_to_view.get(flow_name, "")

        if not target_view:
            continue

        if target_view not in knowledge["views"]:
            knowledge["views"][target_view] = {
                "reliable_assertions": [],
                "unreliable_assertions": [],
                "tap_targets": [],
            }

        for assertion in results["assertions"]:
            text = assertion["text"]
            if not text:
                continue
            if assertion["status"] == "COMPLETED":
                if text not in knowledge["views"][target_view]["reliable_assertions"]:
                    knowledge["views"][target_view]["reliable_assertions"].append(text)
            else:
                if text not in knowledge["views"][target_view]["unreliable_assertions"]:
                    knowledge["views"][target_view]["unreliable_assertions"].append(text)

        for tap in results["taps"]:
            text = tap["text"]
            if text and text not in knowledge["views"][target_view]["tap_targets"]:
                knowledge["views"][target_view]["tap_targets"].append(text)

    # Convert sets to lists for JSON serialization
    knowledge["global_reliable"] = list(knowledge["global_reliable"])

    return knowledge


def run_smoke_tests_and_learn(project_dir: Path, bundle_id: str) -> dict:
    """Run smoke tests through Maestro and learn from results."""
    smoke_dir = project_dir / ".maestro" / "smoke"
    if not smoke_dir.exists():
        print("No smoke tests found. Run discovery first.")
        return {}

    learn_dir = project_dir / ".maestro" / ".learn"
    learn_dir.mkdir(exist_ok=True)

    print("Running smoke tests to learn reliable assertions...")

    # Run all smoke tests
    result = subprocess.run(
        ["maestro", "test", str(smoke_dir),
         "--debug-output", str(learn_dir),
         "--flatten-debug-output"],
        capture_output=True,
        text=True,
    )

    print(f"Maestro exit code: {result.returncode}")
    if result.stdout:
        print(result.stdout[-500:])  # Last 500 chars

    # Parse results
    knowledge = {"version": 1, "views": {}}

    for cmd_json in sorted(learn_dir.glob("commands-*.json")):
        results = parse_maestro_commands(cmd_json)
        flow_name = results["flow_name"]

        # Determine target view from flow name
        target_view = ""
        if flow_name == "smoke_launch_app":
            target_view = "ContentView"
        elif flow_name.startswith("smoke_tab_"):
            tab_name = flow_name.replace("smoke_tab_", "")
            tab_to_view = {
                "dashboard": "DashboardView",
                "new_transaction": "TransactionEntryView",
                "records": "RecordsListView",
                "settings": "SettingsView",
            }
            target_view = tab_to_view.get(tab_name, "")
        elif flow_name.startswith("smoke_nav_"):
            nav_name = flow_name.replace("smoke_nav_", "")
            target_view = nav_name.replace("_", " ").title().replace(" ", "") + "View"

        if not target_view:
            continue

        if target_view not in knowledge["views"]:
            knowledge["views"][target_view] = {
                "reliable_assertions": [],
                "unreliable_assertions": [],
                "accessible_texts": [],
            }

        # Record assertion results
        for assertion in results["assertions"]:
            text = assertion["text"]
            if not text:
                continue
            if assertion["status"] == "COMPLETED":
                if text not in knowledge["views"][target_view]["reliable_assertions"]:
                    knowledge["views"][target_view]["reliable_assertions"].append(text)
            else:
                if text not in knowledge["views"][target_view]["unreliable_assertions"]:
                    knowledge["views"][target_view]["unreliable_assertions"].append(text)

        # Record actual accessible texts from hierarchy (ground truth!)
        for text in results.get("accessible_texts", set()):
            if text and len(text) > 1 and text not in knowledge["views"][target_view]["accessible_texts"]:
                knowledge["views"][target_view]["accessible_texts"].append(text)

    # Build recommended assertions: accessible texts that are short and meaningful
    for view, data in knowledge["views"].items():
        recommended = []
        for text in data.get("accessible_texts", []):
            # Skip long sentences, keep labels/titles/buttons
            if 3 <= len(text) <= 40 and text not in data.get("unreliable_assertions", []):
                # Skip dynamic content (numbers, dates)
                if not text.isdigit() and not re.match(r'^\d{1,2}/\d{1,2}/\d{2,4}', text):
                    recommended.append(text)
        data["recommended_assertions"] = recommended[:5]  # Top 5

    # Also add globally reliable assertions (appear in multiple views)
    all_reliable = []
    for view_data in knowledge["views"].values():
        all_reliable.extend(view_data["reliable_assertions"])

    from collections import Counter
    freq = Counter(all_reliable)
    knowledge["global_reliable"] = [text for text, count in freq.items() if count >= 2]

    return knowledge


def regenerate_flows_with_knowledge(project_dir: Path, knowledge: dict, bundle_id: str):
    """Regenerate Maestro flows using learned knowledge."""
    import shutil

    maestro_dir = project_dir / ".maestro"
    smoke_dir = maestro_dir / "smoke"
    regression_dir = maestro_dir / "regression"

    # Backup old flows
    backup_dir = maestro_dir / ".backup"
    backup_dir.mkdir(exist_ok=True)
    if smoke_dir.exists():
        shutil.copytree(smoke_dir, backup_dir / "smoke", dirs_exist_ok=True)
    if regression_dir.exists():
        shutil.copytree(regression_dir, backup_dir / "regression", dirs_exist_ok=True)

    # Regenerate smoke tests with learned assertions
    smoke_dir.mkdir(exist_ok=True)
    for old_flow in smoke_dir.glob("*.yaml"):
        old_flow.unlink()

    # Build learned flows
    views_with_knowledge = knowledge.get("views", {})

    # Flow 1: Launch app (always keep this simple)
    launch_flow = f"""appId: {bundle_id}
---
# Smoke: Launch app and verify main screen
# Category: smoke
# Tags: critical, launch

- launchApp
- waitForAnimationToEnd
- assertVisible: "Dashboard"
- takeScreenshot: smoke_launch
"""
    (smoke_dir / "smoke_launch_app.yaml").write_text(launch_flow, encoding="utf-8")

    # Tab flows with learned assertions
    tab_flows = {
        "dashboard": ("DashboardView", "Dashboard"),
        "new_transaction": ("TransactionEntryView", "New Transaction"),
        "records": ("RecordsListView", "Records"),
        "settings": ("SettingsView", "Settings"),
    }

    for tab_key, (view_name, tab_label) in tab_flows.items():
        learned = views_with_knowledge.get(view_name, {})
        # Use recommended assertions from ground-truth hierarchy
        recommended = learned.get("recommended_assertions", [])
        reliable = learned.get("reliable_assertions", [])

        # Combine reliable + recommended, preferring reliable
        proven = reliable + [r for r in recommended if r not in reliable]

        assertions = [f'- assertVisible: "{tab_label}"']
        for text in proven[:3]:  # Max 3 learned assertions
            if text != tab_label and len(text) > 2:
                assertions.append(f'- assertVisible: "{text}"')

        flow = f"""appId: {bundle_id}
---
# Smoke: Navigate to {tab_label} tab
# Category: smoke
# Tags: critical, tab

- launchApp
- tapOn: "{tab_label}"
{chr(10).join(assertions)}
- takeScreenshot: smoke_tab_{tab_key}
"""
        (smoke_dir / f"smoke_tab_{tab_key}.yaml").write_text(flow, encoding="utf-8")

    # Navigation flows
    nav_targets = [
        ("dashboard", "Dashboard", "DashboardView"),
        ("records", "Records", "RecordsListView"),
        ("new_transaction", "New Transaction", "TransactionEntryView"),
    ]

    for nav_key, nav_label, view_name in nav_targets:
        learned = views_with_knowledge.get(view_name, {})
        recommended = learned.get("recommended_assertions", [])
        reliable = learned.get("reliable_assertions", [])
        proven = reliable + [r for r in recommended if r not in reliable]

        assertions = [f'- assertVisible: "{nav_label}"']
        for text in proven[:2]:
            if text != nav_label and len(text) > 2:
                assertions.append(f'- assertVisible: "{text}"')

        flow = f"""appId: {bundle_id}
---
# Smoke: Navigate to {nav_label}
# Category: smoke
# Tags: critical, navigation

- launchApp
- tapOn: "{nav_label}"
{chr(10).join(assertions)}
- takeScreenshot: smoke_nav_{nav_key}
"""
        (smoke_dir / f"smoke_nav_{nav_key}.yaml").write_text(flow, encoding="utf-8")

    print(f"Regenerated {len(list(smoke_dir.glob('*.yaml')))} smoke flows with learned knowledge")


def main():
    parser = argparse.ArgumentParser(description="Learn reliable assertions from Maestro runs")
    parser.add_argument("--project-dir", default=".", help="Project directory")
    parser.add_argument("--bundle-id", required=True, help="App bundle ID")
    parser.add_argument("--learn-from", help="Path to Maestro test output dir to learn from")
    parser.add_argument("--app-structure", help="Path to app_structure.json")
    parser.add_argument("--output-knowledge", default=".maestro/learned_assertions.json",
                        help="Output knowledge base JSON")
    parser.add_argument("--regenerate", action="store_true",
                        help="Regenerate flows using existing knowledge")
    parser.add_argument("--run-and-learn", action="store_true",
                        help="Run smoke tests and learn from results")
    args = parser.parse_args()

    project_dir = Path(args.project_dir).resolve()
    knowledge_path = project_dir / args.output_knowledge

    if args.run_and_learn:
        print("🎓 Running smoke tests and learning reliable assertions...")
        knowledge = run_smoke_tests_and_learn(project_dir, args.bundle_id)

        if knowledge and knowledge.get("views"):
            knowledge_path.write_text(json.dumps(knowledge, indent=2), encoding="utf-8")
            print(f"💾 Knowledge saved to: {knowledge_path}")

            # Print summary
            total_reliable = sum(len(v["reliable_assertions"]) for v in knowledge["views"].values())
            total_unreliable = sum(len(v["unreliable_assertions"]) for v in knowledge["views"].values())
            print(f"\n📊 Learning Summary:")
            print(f"   Views analyzed: {len(knowledge['views'])}")
            print(f"   Reliable assertions: {total_reliable}")
            print(f"   Unreliable assertions pruned: {total_unreliable}")
            for view, data in knowledge["views"].items():
                print(f"\n   {view}:")
                for a in data["reliable_assertions"]:
                    print(f"      ✅ {a}")
                for a in data["unreliable_assertions"]:
                    print(f"      ❌ {a} (pruned)")

            # Auto-regenerate
            print("\n🔄 Regenerating flows with learned knowledge...")
            regenerate_flows_with_knowledge(project_dir, knowledge, args.bundle_id)
        else:
            print("No knowledge gained — check Maestro output")

    elif args.learn_from:
        maestro_dir = Path(args.learn_from)
        structure_path = Path(args.app_structure) if args.app_structure else None
        app_structure = {}
        if structure_path and structure_path.exists():
            app_structure = json.loads(structure_path.read_text())

        knowledge = learn_from_run(maestro_dir, app_structure)
        knowledge_path.write_text(json.dumps(knowledge, indent=2), encoding="utf-8")
        print(f"Knowledge saved to: {knowledge_path}")

    elif args.regenerate:
        if not knowledge_path.exists():
            print(f"No knowledge file found: {knowledge_path}")
            print("Run with --run-and-learn first")
            sys.exit(1)
        knowledge = json.loads(knowledge_path.read_text())
        regenerate_flows_with_knowledge(project_dir, knowledge, args.bundle_id)

    else:
        parser.print_help()


if __name__ == "__main__":
    main()
