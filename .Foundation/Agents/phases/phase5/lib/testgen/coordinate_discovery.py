#!/usr/bin/env python3
"""
coordinate_discovery.py — Dynamically discover UI element coordinates at runtime.

Usage:
    python3 coordinate_discovery.py --udid UDID --bundle-id BUNDLE_ID --project-root PATH

This script:
1. Reads a flows.json
2. Launches the app and navigates to each screen
3. Uses Argent's native-describe-screen to find element coordinates
4. Updates flows.json with discovered coordinates
5. Caches coordinates for future runs

Output:
    Updated flows.json with real coordinates
    .argent/coordinate_cache.json for reuse
"""

import argparse
import json
import os
import subprocess
import sys
import time
from pathlib import Path


def argent_run(tool: str, args_dict: dict, project_root: str) -> dict:
    """Run an Argent tool and return the parsed JSON result."""
    cmd = ["argent", "run", tool]
    for key, value in args_dict.items():
        if isinstance(value, bool):
            if value:
                cmd.append(f"--{key}")
        else:
            cmd.extend([f"--{key}", str(value)])

    try:
        result = subprocess.run(
            cmd,
            cwd=project_root,
            capture_output=True,
            text=True,
            timeout=60,
        )
        if result.returncode != 0:
            print(f"  ⚠️  Tool {tool} failed: {result.stderr[:200]}", file=sys.stderr)
            return {}
        return json.loads(result.stdout)
    except subprocess.TimeoutExpired:
        print(f"  ⚠️  Tool {tool} timed out", file=sys.stderr)
        return {}
    except json.JSONDecodeError:
        print(f"  ⚠️  Could not parse JSON from {tool}", file=sys.stderr)
        return {}
    except Exception as e:
        print(f"  ⚠️  Error running {tool}: {e}", file=sys.stderr)
        return {}


def describe_screen(udid: str, bundle_id: str, project_root: str) -> list[dict]:
    """Get accessibility elements from the current screen."""
    result = argent_run("native-describe-screen", {
        "udid": udid,
        "bundleId": bundle_id,
    }, project_root)
    return result.get("elements", [])


def find_element_coords(elements: list[dict], label: str) -> tuple[float, float] | None:
    """Find element coordinates by accessibility label."""
    label_lower = label.lower()
    for element in elements:
        elem_label = element.get("label", "").lower()
        elem_id = element.get("identifier", "").lower()
        # Fuzzy match
        if label_lower in elem_label or label_lower in elem_id or elem_label in label_lower:
            tap_point = element.get("normalizedTapPoint", {})
            return tap_point.get("x"), tap_point.get("y")
    return None


def find_tab_coords(elements: list[dict], tab_name: str) -> tuple[float, float] | None:
    """Find tab bar item coordinates."""
    for element in elements:
        label = element.get("label", "").lower()
        if tab_name.lower() in label and "tab" in label:
            tap_point = element.get("normalizedTapPoint", {})
            return tap_point.get("x"), tap_point.get("y")
    return None


def load_cache(project_root: str) -> dict:
    """Load cached coordinates."""
    cache_path = Path(project_root) / ".argent" / "coordinate_cache.json"
    if cache_path.exists():
        with open(cache_path, "r") as f:
            return json.load(f)
    return {}


def save_cache(project_root: str, cache: dict):
    """Save coordinate cache."""
    cache_path = Path(project_root) / ".argent" / "coordinate_cache.json"
    cache_path.parent.mkdir(parents=True, exist_ok=True)
    with open(cache_path, "w") as f:
        json.dump(cache, f, indent=2)


def discover_coordinates(flows: dict, udid: str, bundle_id: str, project_root: str) -> dict:
    """Discover coordinates for all elements in flows."""
    cache = load_cache(project_root)
    updated_flows = {"flows": []}

    # First, launch the app
    print("🔹 Launching app...")
    argent_run("launch-app", {"udid": udid, "bundleId": bundle_id}, project_root)
    time.sleep(3)

    # Get initial screen to find tab bar coordinates
    print("🔹 Describing initial screen...")
    elements = describe_screen(udid, bundle_id, project_root)

    # Cache tab coordinates
    tab_coords = {
        "dashboard": find_tab_coords(elements, "Dashboard"),
        "new_transaction": find_tab_coords(elements, "New Transaction"),
        "records": find_tab_coords(elements, "Records"),
        "settings": find_tab_coords(elements, "Settings"),
    }
    for tab, coords in tab_coords.items():
        if coords:
            cache[f"tab_{tab}"] = {"x": coords[0], "y": coords[1]}

    for flow in flows.get("flows", []):
        print(f"\n🔹 Processing flow: {flow['name']}")
        updated_steps = []
        current_tab = None

        for step in flow.get("steps", []):
            action = step.get("action", "")
            element = step.get("element", "")
            step_id = step.get("id", "")
            description = step.get("description", "")

            if action == "launch":
                updated_steps.append(step)
                continue

            if action == "tap" and element:
                cache_key = f"{current_tab or 'global'}:{step_id or element.lower()}"

                # Check cache first
                if cache_key in cache:
                    coords = cache[cache_key]
                    updated_steps.append({
                        **step,
                        "x": coords["x"],
                        "y": coords["y"],
                    })
                    print(f"  ✅ Cached: {element} → ({coords['x']:.3f}, {coords['y']:.3f})")
                    continue

                # Check if this is a tab navigation
                if "tab" in step_id.lower():
                    tab_key = step_id.replace("tab_", "")
                    if tab_key in tab_coords and tab_coords[tab_key]:
                        coords = tab_coords[tab_key]
                        updated_steps.append({
                            **step,
                            "x": coords[0],
                            "y": coords[1],
                        })
                        cache[cache_key] = {"x": coords[0], "y": coords[1]}
                        current_tab = tab_key
                        print(f"  ✅ Tab: {element} → ({coords[0]:.3f}, {coords[1]:.3f})")
                        continue

                # Discover from current screen
                print(f"  🔍 Discovering: {element}...")
                elements = describe_screen(udid, bundle_id, project_root)
                coords = find_element_coords(elements, element)

                if coords:
                    updated_steps.append({
                        **step,
                        "x": coords[0],
                        "y": coords[1],
                    })
                    cache[cache_key] = {"x": coords[0], "y": coords[1]}
                    print(f"  ✅ Found: {element} → ({coords[0]:.3f}, {coords[1]:.3f})")
                else:
                    # Fallback to center of screen
                    print(f"  ⚠️  Not found: {element}, using center")
                    updated_steps.append({
                        **step,
                        "x": 0.5,
                        "y": 0.5,
                    })

                # If this was a tab tap, update current_tab
                if "tab" in description.lower():
                    for tab_key in tab_coords:
                        if tab_key.lower() in description.lower():
                            current_tab = tab_key
                            break

                # Small delay after tap
                if action == "tap":
                    time.sleep(1)

            elif action == "scroll":
                # Default scroll coordinates
                direction = step.get("direction", "down")
                if direction == "down":
                    updated_steps.append({
                        **step,
                        "x": 0.5,
                        "y": 0.7,
                        "toX": 0.5,
                        "toY": 0.3,
                    })
                elif direction == "up":
                    updated_steps.append({
                        **step,
                        "x": 0.5,
                        "y": 0.3,
                        "toX": 0.5,
                        "toY": 0.7,
                    })
                else:
                    updated_steps.append({
                        **step,
                        "x": 0.5,
                        "y": 0.5,
                        "toX": 0.5,
                        "toY": 0.5,
                    })

            elif action == "screenshot":
                updated_steps.append(step)

            elif action == "wait":
                updated_steps.append(step)

            elif action == "echo":
                updated_steps.append(step)

            else:
                updated_steps.append(step)

        updated_flows["flows"].append({
            **flow,
            "steps": updated_steps,
        })

    save_cache(project_root, cache)
    return updated_flows


def main():
    parser = argparse.ArgumentParser(description="Discover UI element coordinates")
    parser.add_argument("--flows", required=True, help="Input flows.json path")
    parser.add_argument("--udid", required=True, help="Simulator UDID")
    parser.add_argument("--bundle-id", required=True, help="App bundle ID")
    parser.add_argument("--project-root", default=".", help="Project root directory")
    parser.add_argument("--output", "-o", required=True, help="Output flows.json path")
    args = parser.parse_args()

    with open(args.flows, "r") as f:
        flows = json.load(f)

    updated = discover_coordinates(flows, args.udid, args.bundle_id, args.project_root)

    os.makedirs(os.path.dirname(os.path.abspath(args.output)) or ".", exist_ok=True)
    with open(args.output, "w") as f:
        json.dump(updated, f, indent=2)

    print(f"\n✅ Updated flows written to {args.output}")
    total_steps = sum(len(f["steps"]) for f in updated["flows"])
    print(f"   Total flows: {len(updated['flows'])}")
    print(f"   Total steps: {total_steps}")


if __name__ == "__main__":
    main()
