#!/usr/bin/env python3
"""
code_change_analyzer.py — Analyze git changes and map them to test areas.

Usage:
    python3 code_change_analyzer.py [--base-ref BASE] [--head-ref HEAD] [--project-root PATH]

Defaults:
    --base-ref     HEAD~1  (previous commit)
    --head-ref     HEAD    (current commit)
    --project-root current working directory

Output:
    JSON with changed files, categorized impacts, and recommended test areas.
"""

import argparse
import json
import os
import re
import subprocess
import sys
from dataclasses import dataclass, field, asdict
from pathlib import Path
from typing import Optional


@dataclass
class ChangeImpact:
    file_path: str
    change_type: str  # "added", "modified", "deleted", "renamed"
    lines_added: int = 0
    lines_deleted: int = 0
    category: str = "unknown"  # "view", "manager", "viewmodel", "model", "utility", "config"
    affected_tab: Optional[str] = None
    affected_views: list = field(default_factory=list)
    test_priority: str = "low"
    regression_targets: list = field(default_factory=list)
    key_elements_changed: list = field(default_factory=list)


def run_git_command(cmd: list[str], cwd: str) -> str:
    """Run a git command and return stdout."""
    result = subprocess.run(
        cmd, cwd=cwd, capture_output=True, text=True, check=True
    )
    return result.stdout.strip()


def get_changed_files(project_root: str, base_ref: str, head_ref: str) -> list[dict]:
    """Get list of changed files between two git refs, or working tree if refs are equal."""
    files = []

    if base_ref == head_ref:
        # Compare working tree + staged changes against the ref
        # Unstaged changes
        diff_output = run_git_command(
            ["git", "diff", "--name-status", base_ref],
            project_root,
        )
        # Staged changes
        staged_output = run_git_command(
            ["git", "diff", "--name-status", "--cached", base_ref],
            project_root,
        )
        diff_output = diff_output + "\n" + staged_output
    else:
        diff_output = run_git_command(
            ["git", "diff", "--name-status", base_ref, head_ref],
            project_root,
        )

    for line in diff_output.splitlines():
        if not line.strip():
            continue
        parts = line.split("\t")
        status = parts[0][0]  # First char: A, M, D, R

        change_type = {
            "A": "added",
            "M": "modified",
            "D": "deleted",
            "R": "renamed",
        }.get(status, "modified")

        if change_type == "renamed" and len(parts) >= 3:
            old_path, new_path = parts[1], parts[2]
            files.append({"path": new_path, "old_path": old_path, "type": change_type})
        else:
            files.append({"path": parts[-1], "type": change_type})

    return files


def get_diff_stats(project_root: str, base_ref: str, head_ref: str, file_path: str) -> tuple[int, int]:
    """Get line counts for a specific file's diff."""
    try:
        if base_ref == head_ref:
            # Working tree diff
            diff_output = run_git_command(
                ["git", "diff", "--stat", base_ref, "--", file_path],
                project_root,
            )
        else:
            diff_output = run_git_command(
                ["git", "diff", "--stat", base_ref, head_ref, "--", file_path],
                project_root,
            )
        # Parse "1 file changed, 10 insertions(+), 5 deletions(-)"
        insertions = re.search(r"(\d+) insertion", diff_output)
        deletions = re.search(r"(\d+) deletion", diff_output)
        return (
            int(insertions.group(1)) if insertions else 0,
            int(deletions.group(1)) if deletions else 0,
        )
    except subprocess.CalledProcessError:
        return 0, 0


def categorize_file(file_path: str) -> str:
    """Categorize a file by its path."""
    path_lower = file_path.lower()

    if "/views/" in path_lower:
        return "view"
    elif "/managers/" in path_lower:
        return "manager"
    elif "/viewmodels/" in path_lower:
        return "viewmodel"
    elif "/models/" in path_lower:
        return "model"
    elif "/utilities/" in path_lower or "/extensions/" in path_lower:
        return "utility"
    elif ".xcassets" in path_lower or ".plist" in path_lower or "info.plist" in path_lower:
        return "config"
    elif "contentview.swift" in path_lower or "ammoscanapp.swift" in path_lower:
        return "root"
    else:
        return "other"


def extract_swiftui_elements(file_path: str, project_root: str) -> list[dict]:
    """Parse a Swift file to extract UI elements that might have changed."""
    full_path = os.path.join(project_root, file_path)
    if not os.path.exists(full_path):
        return []

    try:
        with open(full_path, "r", encoding="utf-8") as f:
            content = f.read()
    except Exception:
        return []

    elements = []

    # Detect Button declarations
    button_pattern = re.compile(
        r'Button\s*\([^)]*\)\s*\{[^}]*\}\s*label:\s*\{[^}]*(?:Label\s*\(\s*"([^"]+)"|Text\s*\(\s*"([^"]+)"|Image\s*\(systemName:\s*"([^"]+)")',
        re.DOTALL,
    )
    for match in button_pattern.finditer(content):
        label = next((g for g in match.groups() if g), None)
        if label:
            elements.append({"type": "button", "label": label})

    # Detect simpler Button patterns
    simple_button = re.compile(
        r'Button\s*\(\s*action:\s*[^,]+\s*\)\s*\{[^}]*\}',
        re.DOTALL,
    )
    for _ in simple_button.finditer(content):
        # Extract accessibility label if present
        acc_label = re.search(r'\.accessibilityLabel\s*\(\s*"([^"]+)"\)', content)
        if acc_label:
            elements.append({"type": "button", "label": acc_label.group(1)})

    # Detect Toggle declarations
    toggle_pattern = re.compile(r'Toggle\s*\(\s*"([^"]+)"', re.DOTALL)
    for match in toggle_pattern.finditer(content):
        elements.append({"type": "toggle", "label": match.group(1)})

    # Detect NavigationLink
    navlink_pattern = re.compile(
        r'NavigationLink\s*\(\s*(?:destination:\s*[^,]+,\s*)?\s*(?:value:\s*[^,]+,\s*)?\s*\{[^}]*\}',
        re.DOTALL,
    )
    for _ in navlink_pattern.finditer(content):
        acc_label = re.search(r'\.accessibilityLabel\s*\(\s*"([^"]+)"\)', content)
        if acc_label:
            elements.append({"type": "navigation_link", "label": acc_label.group(1)})

    # Detect .sheet modifiers
    sheet_pattern = re.compile(r'\.sheet\s*\(\s*isPresented:\s*\$', re.DOTALL)
    if sheet_pattern.search(content):
        elements.append({"type": "sheet", "label": "sheet presentation"})

    # Detect .alert modifiers
    alert_pattern = re.compile(r'\.alert\s*\(', re.DOTALL)
    if alert_pattern.search(content):
        elements.append({"type": "alert", "label": "alert dialog"})

    # Detect color/tint changes
    color_pattern = re.compile(r'\.(?:foregroundColor|tint|background)\s*\(\s*\.(?:red|appWarning|destructive|error)')
    if color_pattern.search(content):
        elements.append({"type": "visual_change", "label": "color change"})

    return elements


def load_impact_mapper(project_root: str) -> dict:
    """Load the view impact mapper JSON."""
    mapper_path = Path(__file__).parent / "view_impact_mapper.json"
    if mapper_path.exists():
        with open(mapper_path, "r") as f:
            return json.load(f)
    return {}


def analyze_impact(
    file_path: str,
    change_type: str,
    lines_added: int,
    lines_deleted: int,
    mapper: dict,
    project_root: str,
) -> ChangeImpact:
    """Analyze the impact of a single file change."""
    category = categorize_file(file_path)
    basename = os.path.basename(file_path)

    impact = ChangeImpact(
        file_path=file_path,
        change_type=change_type,
        lines_added=lines_added,
        lines_deleted=lines_deleted,
        category=category,
    )

    view_map = mapper.get("view_map", {})
    manager_map = mapper.get("manager_map", {})
    viewmodel_map = mapper.get("viewmodel_map", {})
    model_map = mapper.get("model_map", {})
    tabs = mapper.get("tabs", {})

    # Check view map
    if basename in view_map:
        vm = view_map[basename]
        impact.affected_tab = vm.get("tab")
        impact.affected_views = [basename.replace(".swift", "")]
        impact.test_priority = vm.get("test_priority", "medium")
        impact.regression_targets = vm.get("regression_targets", [])

    # Auto-detect views not in the map
    elif basename.endswith("View.swift") and "Preview" not in basename:
        view_name = basename.replace(".swift", "")
        impact.affected_views = [view_name]
        impact.test_priority = "medium"
        # Try to infer tab from name
        for tab_name, tab_info in tabs.items():
            if tab_name.lower() in view_name.lower():
                impact.affected_tab = tab_name
                break

    # Check manager map
    elif basename in manager_map:
        mm = manager_map[basename]
        impact.affected_views = mm.get("views", [])
        impact.test_priority = "high" if mm.get("test_all") else "medium"
        impact.regression_targets = mm.get("views", [])
        # Managers affect all their views' tabs
        affected_tabs = set()
        for view_name in mm.get("views", []):
            for tab_key, tab_info in tabs.items():
                if view_name in tab_info.get("primary_views", []) or view_name in tab_info.get("sheet_views", []):
                    affected_tabs.add(tab_key)
        if affected_tabs:
            impact.affected_tab = list(affected_tabs)[0]

    # Check viewmodel map
    elif basename in viewmodel_map:
        vmm = viewmodel_map[basename]
        impact.affected_views = vmm.get("views", [])
        impact.test_priority = "medium"
        impact.regression_targets = vmm.get("regression_targets", [])
        for tab_key, tab_info in tabs.items():
            for view_name in vmm.get("views", []):
                if view_name in tab_info.get("primary_views", []):
                    impact.affected_tab = tab_key
                    break

    # Check model map
    elif basename in model_map:
        mm = model_map[basename]
        impact.test_priority = "medium"
        impact.affected_views = mm.get("features", [])
        affected_tabs = mm.get("test_tabs", [])
        if affected_tabs:
            impact.affected_tab = affected_tabs[0]

    # Root files always critical
    elif category == "root":
        impact.test_priority = "critical"
        impact.affected_tab = "all"
        impact.regression_targets = ["DashboardView", "RecordsListView", "SettingsView", "TransactionEntryView"]

    # Extract changed UI elements
    if category == "view":
        impact.key_elements_changed = extract_swiftui_elements(file_path, project_root)

    # Size-based priority boost
    total_lines = lines_added + lines_deleted
    if total_lines > 100 and impact.test_priority != "critical":
        impact.test_priority = "high"
    elif total_lines > 50 and impact.test_priority == "low":
        impact.test_priority = "medium"

    return impact


def deduplicate_tabs(impacts: list[ChangeImpact]) -> list[str]:
    """Get unique affected tabs, sorted by priority."""
    tabs = {}
    for impact in impacts:
        if impact.affected_tab and impact.affected_tab != "all":
            current_priority = tabs.get(impact.affected_tab, "low")
            priority_order = {"critical": 4, "high": 3, "medium": 2, "low": 1}
            if priority_order.get(impact.test_priority, 0) > priority_order.get(current_priority, 0):
                tabs[impact.affected_tab] = impact.test_priority

    return sorted(tabs.keys(), key=lambda t: priority_order.get(tabs[t], 0), reverse=True)


def main():
    parser = argparse.ArgumentParser(description="Analyze code changes and map to test areas")
    parser.add_argument("--base-ref", default="HEAD~1", help="Base git ref (default: HEAD~1)")
    parser.add_argument("--head-ref", default="HEAD", help="Head git ref (default: HEAD)")
    parser.add_argument("--project-root", default=".", help="Project root directory")
    parser.add_argument("--output", "-o", help="Output JSON file (default: stdout)")
    parser.add_argument("--include-untracked", action="store_true", help="Include untracked files")
    args = parser.parse_args()

    project_root = os.path.abspath(args.project_root)

    # Verify this is inside a git repo (handles submodules / monorepos)
    try:
        subprocess.run(
            ["git", "rev-parse", "--git-dir"],
            cwd=project_root,
            capture_output=True,
            text=True,
            check=True,
        )
    except subprocess.CalledProcessError:
        print(f"Error: {project_root} is not inside a git repository", file=sys.stderr)
        sys.exit(1)

    mapper = load_impact_mapper(project_root)
    changed_files = get_changed_files(project_root, args.base_ref, args.head_ref)

    # Include untracked files if requested
    if args.include_untracked:
        try:
            untracked_output = run_git_command(
                ["git", "ls-files", "--others", "--exclude-standard"],
                project_root,
            )
            for line in untracked_output.splitlines():
                if line.strip().endswith(".swift"):
                    changed_files.append({"path": line.strip(), "type": "added"})
        except subprocess.CalledProcessError:
            pass

    impacts = []
    # Skip patterns that are build artifacts, derived data, or test files
    skip_patterns = [
        ".derived-data", "DerivedData/", "Build/Intermediates", "Build/Products",
        ".build/", "node_modules/", ".swiftpm/", ".xcassets",
        "Tests.swift", "Test.swift", "Tests/", "AmmoScanTests/", "AmmoScanUITests/",
    ]

    for f in changed_files:
        path = f["path"]
        if not path.endswith(".swift"):
            continue
        if any(pattern in path for pattern in skip_patterns):
            continue

        added, deleted = get_diff_stats(project_root, args.base_ref, args.head_ref, path)
        impact = analyze_impact(path, f["type"], added, deleted, mapper, project_root)
        impacts.append(impact)

    # Build output
    affected_tabs = deduplicate_tabs(impacts)
    all_regression_targets = set()
    for impact in impacts:
        for target in impact.regression_targets:
            all_regression_targets.add(target)

    # Remove targets that are already directly tested
    directly_tested = set()
    for impact in impacts:
        directly_tested.update(impact.affected_views)
    regression_only = all_regression_targets - directly_tested

    output = {
        "analysis": {
            "base_ref": args.base_ref,
            "head_ref": args.head_ref,
            "project_root": project_root,
            "total_swift_files_changed": len(impacts),
        },
        "impacts": [asdict(i) for i in impacts],
        "test_plan": {
            "affected_tabs": affected_tabs,
            "directly_tested_views": sorted(directly_tested),
            "regression_targets": sorted(regression_only),
            "recommended_screenshots": [],
        },
    }

    # Generate screenshot recommendations for visual changes
    for impact in impacts:
        for element in impact.key_elements_changed:
            if element.get("type") == "visual_change":
                if impact.affected_tab and impact.affected_tab != "all":
                    output["test_plan"]["recommended_screenshots"].append({
                        "reason": f"Color change in {impact.file_path}",
                        "tab": impact.affected_tab,
                        "view": os.path.basename(impact.file_path).replace(".swift", ""),
                    })

    if args.output:
        with open(args.output, "w") as f:
            json.dump(output, f, indent=2)
        print(f"Analysis written to {args.output}")
    else:
        print(json.dumps(output, indent=2))


if __name__ == "__main__":
    main()
