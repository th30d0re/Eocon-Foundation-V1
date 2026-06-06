#!/usr/bin/env python3
"""
Maestro Flow Generator
Generates Maestro YAML test flows from SwiftUI app structure analysis.

Categories:
    - smoke/      : Critical path tests (launch, tabs, basic navigation)
    - regression/ : Tests for changed code areas (from git diff)
    - full/       : Complete user journey tests (DFS through nav graph)

Usage:
    python3 maestro_flow_generator.py \
        --app-structure app_structure.json \
        --output-dir .maestro/ \
        --bundle-id tech.eocon.AmmoScan
"""

import argparse
import json
import os
import re
import sys
from pathlib import Path
from typing import Any, Optional
from dataclasses import dataclass, field


@dataclass
class MaestroStep:
    """Single Maestro flow step."""
    action: str
    target: str = ""
    params: dict = field(default_factory=dict)

    def to_yaml(self, indent: int = 2) -> str:
        spaces = " " * indent
        if self.action == "launchApp":
            return f"{spaces}- launchApp"
        elif self.action == "tapOn":
            if self.params.get("id"):
                return f'{spaces}- tapOn:\n{spaces}    id: "{self.params["id"]}"'
            return f'{spaces}- tapOn: "{self.target}"'
        elif self.action == "assertVisible":
            return f'{spaces}- assertVisible: "{self.target}"'
        elif self.action == "inputText":
            return f'{spaces}- inputText: "{self.target}"'
        elif self.action == "takeScreenshot":
            return f'{spaces}- takeScreenshot: {self.target}'
        elif self.action == "back":
            return f"{spaces}- back"
        elif self.action == "swipe":
            return f'{spaces}- swipe:\n{spaces}    direction: {self.params.get("direction", "DOWN")}'
        elif self.action == "waitForAnimationToEnd":
            return f"{spaces}- waitForAnimationToEnd"
        else:
            return f'{spaces}- {self.action}: "{self.target}"'


@dataclass
class MaestroFlow:
    """Complete Maestro flow file."""
    name: str
    category: str  # smoke, regression, full
    description: str
    steps: list = field(default_factory=list)
    tags: list = field(default_factory=list)

    def to_yaml(self) -> str:
        lines = [
            f"appId: {self.params.get('bundle_id', 'unknown.app')}",
            "---",
            f"# {self.description}",
            f"# Category: {self.category}",
        ]
        if self.tags:
            lines.append(f"# Tags: {', '.join(self.tags)}")
        lines.append("")
        for step in self.steps:
            lines.append(step.to_yaml())
        return "\n".join(lines)

    @property
    def params(self) -> dict:
        return getattr(self, '_params', {})

    @params.setter
    def params(self, value: dict):
        self._params = value


class MaestroFlowGenerator:
    """Generates Maestro test flows from app structure."""

    def __init__(self, app_structure: dict, bundle_id: str, output_dir: Path, changes_file: str = ""):
        self.structure = app_structure
        self.bundle_id = bundle_id
        self.output_dir = Path(output_dir)
        self.views_by_name = {v["name"]: v for v in app_structure.get("views", [])}
        self.nav_graph = app_structure.get("navigation_graph", {})
        self.tabs = app_structure.get("tab_structure", [])
        # Deduplicate tabs by label
        seen = set()
        self.tabs = [t for t in self.tabs if not (t["label"] in seen or seen.add(t["label"]))]
        self.root_view = app_structure.get("root_view", "")
        self._changes_file = changes_file

    def generate_all(self, categories: Optional[list] = None):
        """Generate all flow categories."""
        categories = categories or ["smoke", "regression", "full"]

        # Clean output dirs
        for cat in categories:
            cat_dir = self.output_dir / cat
            cat_dir.mkdir(parents=True, exist_ok=True)
            # Remove old flows
            for f in cat_dir.glob("*.yaml"):
                f.unlink()

        flows = []
        if "smoke" in categories:
            flows.extend(self._generate_smoke_flows())
        if "regression" in categories:
            flows.extend(self._generate_regression_flows())
        if "full" in categories:
            flows.extend(self._generate_full_flows())

        # Write flows
        for flow in flows:
            flow.params = {"bundle_id": self.bundle_id}
            cat_dir = self.output_dir / flow.category
            cat_dir.mkdir(parents=True, exist_ok=True)
            filepath = cat_dir / f"{flow.name}.yaml"
            filepath.write_text(flow.to_yaml(), encoding="utf-8")

        # Write manifest
        manifest = {
            "generated_at": str(Path.cwd()),
            "bundle_id": self.bundle_id,
            "total_flows": len(flows),
            "categories": {cat: len([f for f in flows if f.category == cat]) for cat in categories},
            "flows": [
                {
                    "name": f.name,
                    "category": f.category,
                    "description": f.description,
                    "file": str(self.output_dir / f.category / f"{f.name}.yaml"),
                    "steps": len(f.steps),
                }
                for f in flows
            ],
        }
        manifest_path = self.output_dir / "manifest.json"
        manifest_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")

        return flows

    def _generate_smoke_flows(self) -> list:
        """Generate smoke tests - critical paths only."""
        flows = []

        # Smoke 1: Launch app and verify main screen
        flow = MaestroFlow(
            name="smoke_launch_app",
            category="smoke",
            description="Launch app and verify main screen loads",
            tags=["critical", "launch"],
        )
        flow.steps = [
            MaestroStep("launchApp"),
            MaestroStep("waitForAnimationToEnd"),
        ]
        # Add assertion for root view if we can find a likely text
        root_view_obj = self.views_by_name.get(self.root_view)
        if root_view_obj and root_view_obj.get("tabs"):
            first_tab = root_view_obj["tabs"][0]
            flow.steps.append(MaestroStep("assertVisible", first_tab["label"]))
        elif self.tabs:
            flow.steps.append(MaestroStep("assertVisible", self.tabs[0]["label"]))
        else:
            flow.steps.append(MaestroStep("assertVisible", "Dashboard"))
        flow.steps.append(MaestroStep("takeScreenshot", "smoke_launch"))
        flows.append(flow)

        # Smoke 2: Tab navigation - visit each tab
        for tab in self.tabs:
            tab_label = tab["label"]
            tab_view = tab.get("view", "")
            flow = MaestroFlow(
                name=f"smoke_tab_{tab_label.lower().replace(' ', '_')}",
                category="smoke",
                description=f"Navigate to {tab_label} tab",
                tags=["critical", "tab", tab_label.lower().replace(" ", "_")],
            )
            flow.steps = [
                MaestroStep("launchApp"),
                MaestroStep("tapOn", tab_label),
                MaestroStep("assertVisible", tab_label),
            ]
            # Try to find a distinctive text in the target view
            view_obj = self.views_by_name.get(tab_view)
            if view_obj and view_obj.get("elements"):
                for elem in view_obj["elements"]:
                    if elem.get("label") and len(elem["label"]) > 3:
                        flow.steps.append(MaestroStep("assertVisible", elem["label"]))
                        break
            flow.steps.append(MaestroStep("takeScreenshot", f"tab_{tab_label.lower().replace(' ', '_')}"))
            flows.append(flow)

        # Smoke 3: Basic navigation - if there are obvious nav links from root
        root_navs = self.nav_graph.get(self.root_view, [])
        for nav in root_navs[:3]:  # Max 3 navigation smoke tests
            dest = nav["to"]
            label = nav.get("label", "")
            if not label:
                continue
            flow = MaestroFlow(
                name=f"smoke_nav_{label.lower().replace(' ', '_').replace('/', '_')[:30]}",
                category="smoke",
                description=f"Navigate from {self.root_view} to {dest} via {label}",
                tags=["critical", "navigation"],
            )
            flow.steps = [
                MaestroStep("launchApp"),
                MaestroStep("tapOn", label),
                MaestroStep("assertVisible", label),
                MaestroStep("takeScreenshot", f"nav_{label.lower().replace(' ', '_')[:20]}"),
            ]
            flows.append(flow)

        return flows

    def _generate_regression_flows(self) -> list:
        """Generate regression tests based on code changes from git diff."""
        flows = []

        # Load changes analysis if provided
        changes_analysis = {}
        changes_file = getattr(self, '_changes_file', None)
        if changes_file and Path(changes_file).exists():
            try:
                changes_analysis = json.loads(Path(changes_file).read_text(encoding="utf-8"))
            except Exception:
                pass

        # Extract affected views from changes analysis
        directly_tested = set()
        regression_targets = set()
        changed_files = []

        if changes_analysis:
            test_plan = changes_analysis.get("test_plan", {})
            directly_tested = set(test_plan.get("directly_tested_views", []))
            regression_targets = set(test_plan.get("regression_targets", []))

            # Also extract from individual impacts
            for impact in changes_analysis.get("impacts", []):
                file_path = impact.get("file_path", "")
                changed_files.append(file_path)
                for view in impact.get("affected_views", []):
                    directly_tested.add(view)
                for target in impact.get("regression_targets", []):
                    regression_targets.add(target)
                # If it's a view file not in the map, add it
                basename = Path(file_path).name
                if basename.endswith("View.swift") and "Preview" not in basename:
                    directly_tested.add(basename.replace(".swift", ""))

        # Combine all targets to test
        all_targets = directly_tested | regression_targets

        # If no changes detected, generate regression for main views
        if not all_targets:
            for v in self.structure.get("views", []):
                if v.get("is_main") or v.get("name") in ["DashboardView", "RecordsListView", "SettingsView", "TransactionEntryView"]:
                    all_targets.add(v.get("name", ""))

        # Generate one regression flow per affected view
        for view_name in sorted(all_targets):
            view = self.views_by_name.get(view_name)
            if not view:
                continue

            # Skip small/helper views
            if view_name.endswith("RowView") or view_name.endswith("Button") or view_name.endswith("Cell"):
                continue

            # Determine if this is directly changed or a regression target
            is_direct = view_name in directly_tested
            priority = "critical" if is_direct else "high"

            flow = MaestroFlow(
                name=f"regression_{view_name.lower().replace('view', '')}",
                category="regression",
                description=f"Regression test for {view_name} ({priority} — {'directly changed' if is_direct else 'dependency affected'})",
                tags=["regression", priority, view_name.lower()],
            )

            steps = [MaestroStep("launchApp")]

            # Navigate to the view via tab if possible
            tab_label = ""
            for tab in self.tabs:
                if tab.get("view") == view_name:
                    tab_label = tab["label"]
                    break

            if tab_label:
                steps.append(MaestroStep("tapOn", tab_label))
            else:
                # Try to find navigation path
                path = self._find_path_to_view(view_name)
                if path:
                    for step in path:
                        steps.append(step)

            # Build list of assertions, deduplicated
            assertions_to_add = []

            # Use learned knowledge if available
            learned_assertions = []
            learned_file = Path(self.output_dir) / "learned_assertions.json"
            if learned_file.exists():
                try:
                    learned = json.loads(learned_file.read_text())
                    view_data = learned.get("views", {}).get(view_name, {})
                    learned_assertions = view_data.get("reliable_assertions", [])
                except Exception:
                    pass

            if learned_assertions:
                # Use only proven assertions
                for text in learned_assertions[:3]:
                    if len(text) > 2 and text not in assertions_to_add:
                        assertions_to_add.append(text)
            else:
                # Fall back to static analysis (be very conservative)
                for elem in view.get("elements", [])[:2]:
                    label = elem.get("label") or elem.get("placeholder")
                    if label and len(label) > 2 and len(label) < 30 and label not in assertions_to_add:
                        assertions_to_add.append(label)

            # Add assertions to steps
            for text in assertions_to_add:
                steps.append(MaestroStep("assertVisible", text))

            steps.append(MaestroStep("takeScreenshot", f"regression_{view_name.lower()[:30]}"))
            flow.steps = steps
            flows.append(flow)

        return flows

    def _generate_full_flows(self) -> list:
        """Generate full end-to-end user journey tests."""
        flows = []
        user_flows = self.structure.get("user_flows", [])

        for uf in user_flows:
            views = uf.get("views", [])
            if len(views) < 2:
                continue

            flow_name = uf.get("name", "flow_unknown")
            # Sanitize name
            flow_name = re.sub(r'[^a-z0-9_]', '_', flow_name.lower())

            flow = MaestroFlow(
                name=flow_name,
                category="full",
                description=uf.get("description", "Full user journey"),
                tags=["e2e", "full"] + views,
            )

            steps = [MaestroStep("launchApp")]
            visited = set()

            for i, view_name in enumerate(views):
                if view_name in visited:
                    continue
                visited.add(view_name)

                view = self.views_by_name.get(view_name)
                if not view:
                    continue

                # If this view has tabs, tap the relevant one
                if i == 0 and view.get("tabs"):
                    # We're at root, already there after launch
                    pass
                elif view.get("tabs"):
                    # This is a tab container, tap appropriate tab
                    for tab in view["tabs"]:
                        if i + 1 < len(views) and views[i + 1] == tab.get("view"):
                            steps.append(MaestroStep("tapOn", tab["label"]))
                            break

                # Add assertions for key elements
                for elem in view.get("elements", [])[:3]:
                    label = elem.get("label") or elem.get("placeholder")
                    if label and len(label) > 2:
                        steps.append(MaestroStep("assertVisible", label))

                # Navigate to next view if there's a nav target
                if i + 1 < len(views):
                    next_view = views[i + 1]
                    nav_found = False
                    for nav in view.get("navigation_targets", []):
                        if nav["to"] == next_view:
                            label = nav.get("label", "")
                            if label:
                                steps.append(MaestroStep("tapOn", label))
                                nav_found = True
                                break
                    if not nav_found:
                        # Try to find any button that might navigate
                        for elem in view.get("elements", []):
                            if elem.get("type") == "Button" and elem.get("label"):
                                steps.append(MaestroStep("tapOn", elem["label"]))
                                break

            steps.append(MaestroStep("takeScreenshot", f"full_{flow_name[:30]}"))
            flow.steps = steps
            flows.append(flow)

        return flows

    def _find_path_to_view(self, target_view: str) -> list:
        """Find a navigation path from root to target view using BFS."""
        from collections import deque

        if target_view == self.root_view:
            return []

        queue = deque([(self.root_view, [])])
        visited = {self.root_view}

        while queue:
            current, path = queue.popleft()
            targets = self.nav_graph.get(current, [])
            for nav in targets:
                dest = nav["to"]
                label = nav.get("label", "")
                if dest == target_view and label:
                    return path + [MaestroStep("tapOn", label)]
                if dest not in visited:
                    visited.add(dest)
                    if label:
                        queue.append((dest, path + [MaestroStep("tapOn", label)]))
                    else:
                        queue.append((dest, path))

        return []


def main():
    parser = argparse.ArgumentParser(description="Generate Maestro flows from app structure")
    parser.add_argument("--app-structure", required=True, help="Path to app_structure.json")
    parser.add_argument("--output-dir", required=True, help="Output directory for .maestro/")
    parser.add_argument("--bundle-id", required=True, help="App bundle ID")
    parser.add_argument("--categories", default="smoke,regression,full",
                        help="Comma-separated flow categories to generate")
    parser.add_argument("--changes-file", help="Optional code change analysis JSON (from code_change_analyzer)")
    args = parser.parse_args()

    structure = json.loads(Path(args.app_structure).read_text(encoding="utf-8"))
    categories = [c.strip() for c in args.categories.split(",")]

    generator = MaestroFlowGenerator(structure, args.bundle_id, Path(args.output_dir), changes_file=args.changes_file or "")
    flows = generator.generate_all(categories)

    print(f"Generated {len(flows)} Maestro flows:")
    for cat in categories:
        count = len([f for f in flows if f.category == cat])
        print(f"  {cat}/: {count} flows")
    print(f"Manifest: {args.output_dir}/manifest.json")


if __name__ == "__main__":
    main()
