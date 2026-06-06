#!/usr/bin/env python3
"""
flow_generator.py — Generate flows.json from code change impact analysis.

Usage:
    python3 flow_generator.py --impact-json analysis.json --project-root PATH --output flows.json

This generates test flows that:
1. Navigate to affected tabs/screens
2. Interact with changed UI elements
3. Take screenshots for visual regression
4. Test regression targets
"""

import argparse
import json
import os
import sys
from pathlib import Path


def load_impact_mapper() -> dict:
    """Load the view impact mapper JSON."""
    mapper_path = Path(__file__).parent / "view_impact_mapper.json"
    if mapper_path.exists():
        with open(mapper_path, "r") as f:
            return json.load(f)
    return {}


def generate_tab_navigation_steps(tab_key: str, tab_info: dict) -> list[dict]:
    """Generate steps to navigate to a specific tab."""
    steps = []
    coords = tab_info.get("tap_coords", {})

    steps.append({
        "action": "echo",
        "description": f"Navigate to {tab_info['name']} tab"
    })
    steps.append({
        "action": "tap",
        "element": tab_info["name"],
        "id": f"tab_{tab_key}",
        "description": f"Tap {tab_info['name']} tab"
    })
    steps.append({
        "action": "wait",
        "description": f"Wait for {tab_info['name']} to load"
    })
    return steps


def generate_view_test_steps(view_name: str, tab_info: dict, mapper: dict) -> list[dict]:
    """Generate test steps for a specific view based on its mapped elements."""
    steps = []
    view_map = mapper.get("view_map", {})
    basename = f"{view_name}.swift"

    if basename not in view_map:
        return steps

    vm = view_map[basename]
    elements = vm.get("key_elements", [])

    for element in elements:
        elem_type = element.get("type", "unknown")
        label = element.get("label", "")
        is_destructive = element.get("destructive", False)

        if elem_type == "button":
            steps.append({
                "action": "tap",
                "element": label,
                "id": f"btn_{label.lower().replace(' ', '_')}",
                "description": f"Tap '{label}' button"
            })
            # If it's a destructive button, we'd need a confirmation handling step
            # but for now just take a screenshot before tapping
            if is_destructive:
                steps.insert(len(steps) - 1, {
                    "action": "screenshot",
                    "description": f"Screenshot before destructive action: {label}"
                })

        elif elem_type == "toggle":
            steps.append({
                "action": "tap",
                "element": label,
                "id": f"toggle_{label.lower().replace(' ', '_')}",
                "description": f"Toggle '{label}'"
            })

        elif elem_type == "navigation_link":
            steps.append({
                "action": "tap",
                "element": label,
                "id": f"nav_{label.lower().replace(' ', '_')}",
                "description": f"Navigate to '{label}'"
            })
            steps.append({
                "action": "wait",
                "description": f"Wait for '{label}' to load"
            })
            steps.append({
                "action": "screenshot",
                "description": f"Screenshot of '{label}' screen"
            })
            # Navigate back
            steps.append({
                "action": "tap",
                "element": "Back",
                "id": "nav_back",
                "description": "Navigate back"
            })

        elif elem_type == "text_field":
            steps.append({
                "action": "tap",
                "element": label,
                "id": f"field_{label.lower().replace(' ', '_')}",
                "description": f"Focus '{label}' text field"
            })

        elif elem_type == "picker":
            steps.append({
                "action": "tap",
                "element": label,
                "id": f"picker_{label.lower().replace(' ', '_')}",
                "description": f"Open '{label}' picker"
            })

        elif elem_type == "search_field":
            steps.append({
                "action": "tap",
                "element": label,
                "id": f"search_{label.lower().replace(' ', '_')}",
                "description": f"Focus '{label}' search field"
            })

        elif elem_type == "toolbar_button":
            steps.append({
                "action": "tap",
                "element": label,
                "id": f"toolbar_{label.lower().replace(' ', '_')}",
                "description": f"Tap toolbar button: '{label}'"
            })
            # For Advanced Search specifically, add screenshot and cancel
            if "advanced search" in label.lower():
                steps.append({
                    "action": "wait",
                    "description": "Wait for Advanced Search sheet"
                })
                steps.append({
                    "action": "screenshot",
                    "description": f"Screenshot of {label} sheet"
                })
                steps.append({
                    "action": "tap",
                    "element": "Cancel",
                    "id": "btn_cancel",
                    "description": "Dismiss sheet"
                })

        elif elem_type == "sheet":
            # Sheets are typically triggered by buttons; we capture screenshots when opened
            pass

    # Always take a final screenshot of the view
    steps.append({
        "action": "screenshot",
        "description": f"Screenshot of {view_name}"
    })

    return steps


def generate_screenshot_only_steps(view_name: str, tab_key: str, tab_info: dict) -> list[dict]:
    """Generate minimal steps for regression testing (screenshot only)."""
    steps = []
    steps.append({
        "action": "echo",
        "description": f"Regression test: {view_name}"
    })
    steps.append({
        "action": "screenshot",
        "description": f"Regression screenshot of {view_name}"
    })
    return steps


def generate_flows(analysis_json: dict, mapper: dict) -> dict:
    """Generate flows.json content from impact analysis."""
    flows = []
    tabs = mapper.get("tabs", {})
    impacts = analysis_json.get("impacts", [])
    test_plan = analysis_json.get("test_plan", {})
    affected_tabs = test_plan.get("affected_tabs", [])
    regression_targets = test_plan.get("regression_targets", [])

    # Group impacts by tab
    tab_to_views = {}
    for impact in impacts:
        tab = impact.get("affected_tab")
        if tab and tab != "all":
            if tab not in tab_to_views:
                tab_to_views[tab] = []
            view_name = os.path.basename(impact["file_path"]).replace(".swift", "")
            if view_name not in tab_to_views[tab]:
                tab_to_views[tab].append(view_name)

    # Group impacts by tab for "all" (root changes)
    all_views = []
    for impact in impacts:
        if impact.get("affected_tab") == "all":
            all_views.extend(impact.get("affected_views", []))

    # Flow 1: Primary impact flow — test all directly affected tabs
    if affected_tabs or all_views:
        primary_steps = []
        primary_steps.append({
            "action": "launch",
            "description": "Launch app (simulator bypass handles first-run setup)"
        })

        # Test each affected tab
        tabs_to_test = affected_tabs if affected_tabs else list(tabs.keys())
        for tab_key in tabs_to_test:
            if tab_key not in tabs:
                continue
            tab_info = tabs[tab_key]

            # Navigate to tab
            primary_steps.extend(generate_tab_navigation_steps(tab_key, tab_info))

            # Test views in this tab that were directly changed
            views_in_tab = tab_to_views.get(tab_key, [])
            for view_name in views_in_tab:
                view_steps = generate_view_test_steps(view_name, tab_info, mapper)
                primary_steps.extend(view_steps)

            # If it's Settings, do a scroll pass to capture all sections
            if tab_key == "settings":
                primary_steps.append({
                    "action": "scroll",
                    "direction": "down",
                    "description": "Scroll Settings to reveal all sections"
                })
                primary_steps.append({
                    "action": "screenshot",
                    "description": "Screenshot of Settings scrolled"
                })

            # If it's Records, open Advanced Search
            if tab_key == "records":
                # Check if AdvancedSearchView was changed
                has_advanced_search = any(
                    "AdvancedSearchView" in v for v in views_in_tab
                )
                if not has_advanced_search:
                    # Still do a quick regression tap on Advanced Search
                    primary_steps.append({
                        "action": "tap",
                        "element": "Advanced Search",
                        "id": "toolbar_advanced_search",
                        "description": "Open Advanced Search for regression"
                    })
                    primary_steps.append({
                        "action": "wait",
                        "description": "Wait for Advanced Search sheet"
                    })
                    primary_steps.append({
                        "action": "screenshot",
                        "description": "Screenshot of Advanced Search"
                    })
                    primary_steps.append({
                        "action": "tap",
                        "element": "Cancel",
                        "id": "btn_cancel",
                        "description": "Dismiss Advanced Search"
                    })

        flow_name = f"Primary Impact Test — {', '.join(tabs_to_test[:3])}"
        if len(tabs_to_test) > 3:
            flow_name += f" +{len(tabs_to_test) - 3} more"

        flows.append({
            "name": flow_name,
            "description": "Tests all screens directly affected by code changes",
            "steps": primary_steps,
        })

    # Flow 2: Regression flow — quick screenshot pass of related screens
    if regression_targets:
        regression_steps = []
        regression_steps.append({
            "action": "launch",
            "description": "Launch app for regression testing"
        })

        tested_tabs = set()
        for target_view in regression_targets:
            # Find which tab this view belongs to
            target_tab = None
            for tab_key, tab_info in tabs.items():
                if target_view in tab_info.get("primary_views", []) or target_view in tab_info.get("sheet_views", []):
                    target_tab = tab_key
                    break

            if target_tab and target_tab not in tested_tabs:
                tested_tabs.add(target_tab)
                tab_info = tabs[target_tab]
                regression_steps.extend(generate_tab_navigation_steps(target_tab, tab_info))
                regression_steps.extend(generate_screenshot_only_steps(target_view, target_tab, tab_info))

        if regression_steps:
            flows.append({
                "name": "Regression Screenshot Pass",
                "description": "Quick visual regression test of related screens",
                "steps": regression_steps,
            })

    # Flow 3: Visual regression — specific screenshots for color/style changes
    visual_changes = []
    for impact in impacts:
        for element in impact.get("key_elements_changed", []):
            if element.get("type") == "visual_change":
                visual_changes.append({
                    "file": impact["file_path"],
                    "tab": impact.get("affected_tab"),
                    "view": os.path.basename(impact["file_path"]).replace(".swift", ""),
                })

    if visual_changes:
        visual_steps = []
        visual_steps.append({
            "action": "launch",
            "description": "Launch app for visual regression testing"
        })

        tested_visual_tabs = set()
        for change in visual_changes:
            tab = change.get("tab")
            if tab and tab in tabs and tab not in tested_visual_tabs:
                tested_visual_tabs.add(tab)
                tab_info = tabs[tab]
                visual_steps.extend(generate_tab_navigation_steps(tab, tab_info))
                visual_steps.append({
                    "action": "screenshot",
                    "description": f"Visual regression: {change['view']} ({change['file']})"
                })

        if visual_steps:
            flows.append({
                "name": "Visual Regression Test",
                "description": "Screenshots of screens with color/style changes",
                "steps": visual_steps,
            })

    return {"flows": flows}


def main():
    parser = argparse.ArgumentParser(description="Generate test flows from impact analysis")
    parser.add_argument("--impact-json", required=True, help="Path to impact analysis JSON")
    parser.add_argument("--project-root", default=".", help="Project root directory")
    parser.add_argument("--output", "-o", required=True, help="Output flows.json path")
    args = parser.parse_args()

    with open(args.impact_json, "r") as f:
        analysis = json.load(f)

    mapper = load_impact_mapper()
    flows_data = generate_flows(analysis, mapper)

    # Ensure output directory exists
    os.makedirs(os.path.dirname(os.path.abspath(args.output)) or ".", exist_ok=True)

    with open(args.output, "w") as f:
        json.dump(flows_data, f, indent=2)

    print(f"Generated {len(flows_data['flows'])} flow(s) → {args.output}")
    for flow in flows_data["flows"]:
        print(f"  • {flow['name']} ({len(flow['steps'])} steps)")


if __name__ == "__main__":
    main()
