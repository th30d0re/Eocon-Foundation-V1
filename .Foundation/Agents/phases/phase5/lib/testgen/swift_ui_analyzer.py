#!/usr/bin/env python3
"""
SwiftUI Code Analyzer
Parses Swift source files to extract app structure, navigation graph,
user interactions, and accessibility labels for test flow generation.

Usage:
    python3 swift_ui_analyzer.py --project-dir ./AmmoScan --output app_structure.json
"""

import argparse
import json
import os
import re
import sys
from pathlib import Path
from typing import Any, Optional
from dataclasses import dataclass, field, asdict
from collections import defaultdict


@dataclass
class UIElement:
    """Represents a UI element discovered in SwiftUI code."""
    type: str
    label: str = ""
    identifier: str = ""
    action: str = ""
    destination: str = ""
    placeholder: str = ""
    bindings: list = field(default_factory=list)
    modifiers: list = field(default_factory=list)


@dataclass
class SwiftUIView:
    """Represents a SwiftUI View discovered in source code."""
    name: str
    file: str
    line: int
    elements: list = field(default_factory=list)
    tabs: list = field(default_factory=list)
    navigation_targets: list = field(default_factory=list)
    sheets: list = field(default_factory=list)
    alerts: list = field(default_factory=list)
    is_auth: bool = False
    is_onboarding: bool = False
    is_main: bool = False


@dataclass
class AppStructure:
    """Complete app structure extracted from Swift code."""
    views: list = field(default_factory=list)
    root_view: str = ""
    tab_structure: list = field(default_factory=list)
    navigation_graph: dict = field(default_factory=dict)
    forms: list = field(default_factory=list)
    user_flows: list = field(default_factory=list)


class SwiftUIAnalyzer:
    """Analyzes SwiftUI source files to extract app structure."""

    def __init__(self, project_dir: str):
        self.project_dir = Path(project_dir)
        self.structure = AppStructure()
        self.views_by_name: dict[str, SwiftUIView] = {}
        self._view_stack: list[str] = []

    def analyze(self) -> AppStructure:
        """Run complete analysis of the project."""
        swift_files = list(self.project_dir.rglob("*.swift"))
        swift_files = [f for f in swift_files if "Preview" not in str(f) and "Test" not in str(f)]

        # Phase 1: Extract all view definitions
        for swift_file in swift_files:
            self._extract_views_from_file(swift_file)

        # Phase 2: Extract navigation and interactions from each view
        for view in self.structure.views:
            self._extract_view_details(view)

        # Phase 3: Build navigation graph
        self._build_navigation_graph()

        # Phase 4: Identify root view and tabs
        self._identify_root_structure()

        # Phase 5: Discover user flows
        self._discover_user_flows()

        return self.structure

    def _extract_views_from_file(self, filepath: Path):
        """Extract struct ...View: View definitions from a file."""
        content = filepath.read_text(encoding="utf-8")
        lines = content.split("\n")

        # Pattern: struct NameView: View {
        view_pattern = re.compile(
            r"struct\s+(\w+View)\s*:\s*View\s*\{"
        )

        for i, line in enumerate(lines, 1):
            match = view_pattern.search(line)
            if match:
                view_name = match.group(1)
                is_auth = any(k in view_name.lower() for k in ["auth", "login", "pin", "passkey"])
                is_onboarding = any(k in view_name.lower() for k in ["onboard", "setup", "wizard", "first"])
                is_main = view_name in ["ContentView", "MainAppView", "RootView"]

                view = SwiftUIView(
                    name=view_name,
                    file=str(filepath.relative_to(self.project_dir)),
                    line=i,
                    is_auth=is_auth,
                    is_onboarding=is_onboarding,
                    is_main=is_main,
                )
                self.structure.views.append(view)
                self.views_by_name[view_name] = view

    def _extract_view_details(self, view: SwiftUIView):
        """Extract navigation, buttons, forms, etc. from a view's source."""
        filepath = self.project_dir / view.file
        if not filepath.exists():
            return

        content = filepath.read_text(encoding="utf-8")

        # ── NavigationLink patterns ──
        # Pattern: NavigationLink("Label") { DestinationView() }
        navlink_pattern1 = re.compile(
            r'NavigationLink\s*\(\s*"([^"]*)"\s*\)\s*\{\s*(\w+View)'
        )
        # Pattern: NavigationLink { DestinationView() } label: { Text("Label") }
        navlink_pattern2 = re.compile(
            r'NavigationLink\s*\{\s*(\w+View)\s*\(\s*\)\s*\}\s*label:\s*\{[^}]*Text\s*\(\s*"([^"]*)"\s*\)'
        )
        navlink_pattern2b = re.compile(
            r'NavigationLink\s*\{\s*(\w+View)\s*\}\s*label:\s*\{[^}]*Text\s*\(\s*"([^"]*)"\s*\)'
        )
        # Pattern: NavigationLink(destination: DestinationView()) { Text("Label") }
        navlink_pattern3 = re.compile(
            r'NavigationLink\s*\(\s*destination:\s*(\w+View)[^)]*\)\s*\{[^}]*Text\s*\(\s*"([^"]*)"\s*\)'
        )

        for m in navlink_pattern1.finditer(content):
            view.navigation_targets.append({
                "type": "NavigationLink",
                "destination": m.group(2),
                "label": m.group(1),
            })
        for m in navlink_pattern2.finditer(content):
            view.navigation_targets.append({
                "type": "NavigationLink",
                "destination": m.group(1),
                "label": m.group(2),
            })
        for m in navlink_pattern2b.finditer(content):
            view.navigation_targets.append({
                "type": "NavigationLink",
                "destination": m.group(1),
                "label": m.group(2),
            })
        for m in navlink_pattern3.finditer(content):
            view.navigation_targets.append({
                "type": "NavigationLink",
                "destination": m.group(1),
                "label": m.group(2),
            })

        # Extract .navigationDestination
        navdest_pattern = re.compile(
            r'\.navigationDestination\s*\(\s*for\s*:\s*\w+\.self\s*\)\s*\{\s*\w+\s+in\s+(\w+View)'
        )
        for m in navdest_pattern.finditer(content):
            view.navigation_targets.append({
                "type": "navigationDestination",
                "destination": m.group(1),
                "label": "",
            })

        # ── TabView tabs ──
        # Pattern: Tab("Label", systemImage: "icon", value: .case) { View() }
        tab_pattern = re.compile(
            r'Tab\s*\(\s*"([^"]*)"\s*,\s*systemImage:\s*"([^"]*)"\s*[^)]*\)\s*\{\s*(\w+View)'
        )
        for m in tab_pattern.finditer(content):
            view.tabs.append({
                "label": m.group(1),
                "icon": m.group(2),
                "view": m.group(3),
            })

        # ── Buttons ──
        button_pattern1 = re.compile(
            r'Button\s*\(\s*"([^"]*)"\s*\)'
        )
        button_pattern2 = re.compile(
            r'Button\s*\{[^}]*\}\s*label:\s*\{[^}]*Text\s*\(\s*"([^"]*)"\s*\)'
        )
        for m in button_pattern1.finditer(content):
            view.elements.append(UIElement(type="Button", label=m.group(1)))
        for m in button_pattern2.finditer(content):
            view.elements.append(UIElement(type="Button", label=m.group(1)))

        # ── TextFields ──
        tf_pattern = re.compile(
            r'TextField\s*\(\s*"([^"]*)"\s*,\s*text:\s*\$?(\w+)\s*\)'
        )
        for m in tf_pattern.finditer(content):
            view.elements.append(UIElement(
                type="TextField",
                placeholder=m.group(1),
                bindings=[m.group(2)],
            ))

        # ── Pickers ──
        picker_pattern = re.compile(
            r'Picker\s*\(\s*"([^"]*)"\s*,\s*selection:\s*\$?(\w+)\s*\)'
        )
        for m in picker_pattern.finditer(content):
            view.elements.append(UIElement(
                type="Picker",
                label=m.group(1),
                bindings=[m.group(2)],
            ))

        # ── Toggles ──
        toggle_pattern = re.compile(
            r'Toggle\s*\(\s*"([^"]*)"\s*,\s*isOn:\s*\$?(\w+)\s*\)'
        )
        for m in toggle_pattern.finditer(content):
            view.elements.append(UIElement(
                type="Toggle",
                label=m.group(1),
                bindings=[m.group(2)],
            ))

        # ── Sheets ──
        # Pattern: .sheet(isPresented: $var) { ViewName() }
        sheet_pattern = re.compile(
            r'\.sheet\s*\([^)]*\)\s*\{\s*(\w+View)'
        )
        for m in sheet_pattern.finditer(content):
            view.sheets.append({"type": "sheet", "destination": m.group(1)})

        # ── Alerts ──
        alert_pattern = re.compile(
            r'\.alert\s*\(\s*"([^"]*)"\s*,'
        )
        for m in alert_pattern.finditer(content):
            view.alerts.append({"title": m.group(1)})

        # ── List with Navigation ──
        list_pattern = re.compile(
            r'List\s*\{[^}]*NavigationLink\s*\{[^}]*Text\s*\(\s*"([^"]*)"\s*\)'
        )
        for m in list_pattern.finditer(content):
            view.elements.append(UIElement(
                type="ListItem",
                label=m.group(1),
                action="navigate",
            ))

    def _build_navigation_graph(self):
        """Build a directed graph of view navigation."""
        graph = defaultdict(list)
        for view in self.structure.views:
            for target in view.navigation_targets:
                dest = target["destination"]
                graph[view.name].append({
                    "to": dest,
                    "type": target["type"],
                    "label": target.get("label", ""),
                })
            for sheet in view.sheets:
                graph[view.name].append({
                    "to": sheet["destination"],
                    "type": "sheet",
                    "label": "",
                })
        self.structure.navigation_graph = dict(graph)

    def _identify_root_structure(self):
        """Identify the root view and tab structure."""
        for view in self.structure.views:
            if view.is_main:
                self.structure.root_view = view.name
            if view.tabs:
                self.structure.tab_structure.extend(view.tabs)

        # If no main view found, try ContentView or first view with tabs
        if not self.structure.root_view:
            for view in self.structure.views:
                if view.name == "ContentView":
                    self.structure.root_view = view.name
                    break
            if not self.structure.root_view and self.structure.views:
                self.structure.root_view = self.structure.views[0].name

    def _discover_user_flows(self):
        """Discover complete user flows through the app via DFS."""
        if not self.structure.root_view:
            return

        # Flow 1: Authentication flow (if auth views exist)
        auth_views = [v.name for v in self.structure.views if v.is_auth]
        if auth_views:
            self.structure.user_flows.append({
                "name": "auth_flow",
                "type": "auth",
                "views": auth_views,
                "description": "Authentication and login flow",
            })

        # Flow 2: Onboarding flow
        onboard_views = [v.name for v in self.structure.views if v.is_onboarding]
        if onboard_views:
            self.structure.user_flows.append({
                "name": "onboarding_flow",
                "type": "onboarding",
                "views": onboard_views,
                "description": "First-run onboarding flow",
            })

        # Flow 3: Tab-based flows
        if self.structure.tab_structure:
            for tab in self.structure.tab_structure:
                self.structure.user_flows.append({
                    "name": f"tab_{tab['label'].lower().replace(' ', '_')}",
                    "type": "tab",
                    "views": [self.structure.root_view],
                    "tab": tab["label"],
                    "description": f"Navigate to {tab['label']} tab",
                })

        # Flow 4: Navigation depth-first flows (max depth 3 to avoid explosion)
        visited = set()
        flows = []

        def dfs(view_name: str, path: list, depth: int):
            if depth > 3 or view_name in path:
                return
            path = path + [view_name]
            targets = self.structure.navigation_graph.get(view_name, [])
            if not targets:
                if len(path) > 1:
                    flows.append(path)
                return
            for target in targets:
                dfs(target["to"], path, depth + 1)
            # Also record intermediate paths
            if len(path) > 1:
                flows.append(path)

        dfs(self.structure.root_view, [], 0)

        # Deduplicate and name flows
        seen = set()
        for flow in flows:
            key = "->".join(flow)
            if key not in seen:
                seen.add(key)
                self.structure.user_flows.append({
                    "name": f"flow_{flow[-1].lower().replace('view', '')}",
                    "type": "navigation",
                    "views": flow,
                    "description": f"Navigate: {' -> '.join(flow)}",
                })

    def to_json(self) -> str:
        """Serialize structure to JSON."""
        return json.dumps(self._as_dict(), indent=2, default=str)

    def _as_dict(self) -> dict:
        """Convert to dict for JSON serialization."""
        return {
            "root_view": self.structure.root_view,
            "tab_structure": self.structure.tab_structure,
            "navigation_graph": self.structure.navigation_graph,
            "views": [
                {
                    "name": v.name,
                    "file": v.file,
                    "line": v.line,
                    "is_auth": v.is_auth,
                    "is_onboarding": v.is_onboarding,
                    "is_main": v.is_main,
                    "tabs": v.tabs,
                    "navigation_targets": v.navigation_targets,
                    "sheets": v.sheets,
                    "alerts": v.alerts,
                    "elements": [
                        {
                            "type": e.type,
                            "label": e.label,
                            "placeholder": e.placeholder,
                            "destination": e.destination,
                        }
                        for e in v.elements
                    ],
                }
                for v in self.structure.views
            ],
            "user_flows": self.structure.user_flows,
            "metadata": {
                "total_views": len(self.structure.views),
                "total_flows": len(self.structure.user_flows),
                "has_auth": any(v.is_auth for v in self.structure.views),
                "has_onboarding": any(v.is_onboarding for v in self.structure.views),
            },
        }


def main():
    parser = argparse.ArgumentParser(description="Analyze SwiftUI project structure")
    parser.add_argument("--project-dir", required=True, help="Path to Xcode project directory")
    parser.add_argument("--output", required=True, help="Output JSON file path")
    args = parser.parse_args()

    analyzer = SwiftUIAnalyzer(args.project_dir)
    analyzer.analyze()

    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(analyzer.to_json(), encoding="utf-8")

    stats = analyzer._as_dict()["metadata"]
    print(f"Analyzed {stats['total_views']} views, discovered {stats['total_flows']} flows")
    print(f"Output written to: {args.output}")


if __name__ == "__main__":
    main()
