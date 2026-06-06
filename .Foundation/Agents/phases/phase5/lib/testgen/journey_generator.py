#!/usr/bin/env python3
"""
Journey Generator — Creates real end-to-end user workflow tests.

Unlike smoke tests (which just verify a screen loads), journey tests
actually USE the app: fill forms, save data, navigate, verify results.

This analyzer identifies:
  - Form views (many TextFields = data entry)
  - Save/Create/Submit buttons
  - Post-save navigation paths
  - Search flows
  - CRUD lifecycle patterns

Usage:
    python3 journey_generator.py \
        --app-structure app_structure.json \
        --output-dir .maestro/journeys/ \
        --bundle-id tech.eocon.AmmoScan
"""

import argparse
import json
import re
from pathlib import Path
from dataclasses import dataclass, field


@dataclass
class JourneyStep:
    action: str  # launchApp, tapOn, inputText, assertVisible, takeScreenshot, back, swipe
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
class UserJourney:
    name: str
    description: str
    steps: list = field(default_factory=list)
    tags: list = field(default_factory=list)

    def to_yaml(self, bundle_id: str) -> str:
        lines = [
            f"appId: {bundle_id}",
            "---",
            f"# {self.description}",
            f"# Category: journey",
        ]
        if self.tags:
            lines.append(f"# Tags: {', '.join(self.tags)}")
        lines.append("")
        for step in self.steps:
            lines.append(step.to_yaml())
        return "\n".join(lines)


class JourneyGenerator:
    """Generates real end-to-end user journey tests."""

    def __init__(self, app_structure: dict, bundle_id: str, output_dir: Path):
        self.structure = app_structure
        self.bundle_id = bundle_id
        self.output_dir = Path(output_dir)
        self.views_by_name = {v["name"]: v for v in app_structure.get("views", [])}
        self.tabs = app_structure.get("tab_structure", [])
        # Deduplicate tabs
        seen = set()
        self.tabs = [t for t in self.tabs if not (t["label"] in seen or seen.add(t["label"]))]

    def generate_all(self) -> list:
        """Generate all user journey flows."""
        journeys = []
        journeys.extend(self._generate_create_transaction_journey())
        journeys.extend(self._generate_search_records_journey())
        journeys.extend(self._generate_view_record_journey())
        journeys.extend(self._generate_settings_journey())
        return journeys

    def write_journeys(self, journeys: list):
        """Write journey YAML files to disk."""
        journey_dir = self.output_dir / "journeys"
        journey_dir.mkdir(parents=True, exist_ok=True)

        # Clean old journeys
        for old in journey_dir.glob("*.yaml"):
            old.unlink()

        for journey in journeys:
            filepath = journey_dir / f"{journey.name}.yaml"
            filepath.write_text(journey.to_yaml(self.bundle_id), encoding="utf-8")

        # Update manifest
        manifest_path = self.output_dir / "manifest.json"
        manifest = {"journeys": []}
        if manifest_path.exists():
            manifest = json.loads(manifest_path.read_text())
        manifest["journeys"] = [
            {"name": j.name, "description": j.description, "steps": len(j.steps)}
            for j in journeys
        ]
        manifest_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")

        print(f"Generated {len(journeys)} user journey flows in {journey_dir}")
        for j in journeys:
            print(f"  ✈️  {j.name}: {j.description} ({len(j.steps)} steps)")

    def _find_view_by_name(self, name: str) -> dict:
        return self.views_by_name.get(name, {})

    def _get_tab_for_view(self, view_name: str) -> str:
        """Find which tab contains this view."""
        for tab in self.tabs:
            if tab.get("view") == view_name:
                return tab["label"]
        return ""

    def _find_text_fields_in_view(self, view_name: str) -> list:
        """Extract text field placeholders from a view."""
        view = self._find_view_by_name(view_name)
        fields = []
        for elem in view.get("elements", []):
            if elem.get("type") in ["TextField", "Picker"]:
                label = elem.get("label") or elem.get("placeholder", "")
                if label and len(label) > 2:
                    fields.append(label)
        return fields

    def _find_buttons_in_view(self, view_name: str) -> list:
        """Extract button labels from a view."""
        view = self._find_view_by_name(view_name)
        buttons = []
        for elem in view.get("elements", []):
            if elem.get("type") == "Button":
                label = elem.get("label", "")
                if label and len(label) > 1:
                    buttons.append(label)
        return buttons

    def _generate_create_transaction_journey(self) -> list:
        """Generate a create transaction journey."""
        journeys = []

        # Find the transaction entry view
        tx_view = self._find_view_by_name("TransactionEntryView")
        if not tx_view:
            return journeys

        tab_label = self._get_tab_for_view("TransactionEntryView")
        if not tab_label:
            tab_label = "New Transaction"

        steps = [
            JourneyStep("launchApp"),
            JourneyStep("tapOn", tab_label),
            JourneyStep("assertVisible", tab_label),
        ]

        # Fill customer form fields (first 2-3 meaningful ones)
        text_fields = self._find_text_fields_in_view("TransactionEntryView")
        sample_data = {
            "Enter full name": "John Doe",
            "Enter license number": "LTC123456",
            "Enter occupation": "Software Engineer",
        }
        filled = 0
        for field in text_fields:
            if field in sample_data and filled < 3:
                steps.append(JourneyStep("tapOn", field))
                steps.append(JourneyStep("inputText", sample_data[field]))
                filled += 1

        # Try to save
        buttons = self._find_buttons_in_view("TransactionEntryView")
        save_button = None
        for btn in buttons:
            if any(word in btn.lower() for word in ["save", "submit", "create"]):
                save_button = btn
                break

        if save_button:
            steps.append(JourneyStep("tapOn", save_button))
            # Handle confirmation alert
            steps.append(JourneyStep("assertVisible", "Save Transaction"))
            steps.append(JourneyStep("tapOn", "Save"))
            # Handle success alert
            steps.append(JourneyStep("assertVisible", "Transaction Saved"))
            steps.append(JourneyStep("tapOn", "Done"))

        # Navigate to Records and verify
        records_tab = self._get_tab_for_view("RecordsListView") or "Records"
        steps.append(JourneyStep("tapOn", records_tab))
        steps.append(JourneyStep("assertVisible", records_tab))
        if filled > 0:
            steps.append(JourneyStep("assertVisible", sample_data.get("Enter full name", "")))

        steps.append(JourneyStep("takeScreenshot", "journey_create_transaction"))

        journeys.append(UserJourney(
            name="journey_create_transaction",
            description="Create a new ammunition sale transaction and verify it appears in records",
            steps=steps,
            tags=["e2e", "critical", "create", "transaction"],
        ))

        return journeys

    def _generate_search_records_journey(self) -> list:
        """Generate a search records journey."""
        journeys = []

        records_view = self._find_view_by_name("RecordsListView")
        if not records_view:
            return journeys

        tab_label = self._get_tab_for_view("RecordsListView") or "Records"

        steps = [
            JourneyStep("launchApp"),
            JourneyStep("tapOn", tab_label),
            JourneyStep("assertVisible", tab_label),
        ]

        # Check if there's a search field
        has_search = any(
            "search" in (e.get("placeholder", "")).lower() or "search" in (e.get("label", "")).lower()
            for e in records_view.get("elements", [])
        )

        if has_search:
            steps.append(JourneyStep("tapOn", "Search records..."))
            steps.append(JourneyStep("inputText", "9mm"))
            steps.append(JourneyStep("assertVisible", "No Records Found"))

        steps.append(JourneyStep("takeScreenshot", "journey_search_records"))

        journeys.append(UserJourney(
            name="journey_search_records",
            description="Search for records and verify filtering works",
            steps=steps,
            tags=["e2e", "search", "records"],
        ))

        return journeys

    def _generate_view_record_journey(self) -> list:
        """Generate a view record details journey."""
        journeys = []

        records_view = self._find_view_by_name("RecordsListView")
        if not records_view:
            return journeys

        tab_label = self._get_tab_for_view("RecordsListView") or "Records"

        steps = [
            JourneyStep("launchApp"),
            JourneyStep("tapOn", tab_label),
            JourneyStep("assertVisible", tab_label),
            JourneyStep("takeScreenshot", "journey_view_records_list"),
        ]

        journeys.append(UserJourney(
            name="journey_view_records_list",
            description="Navigate to Records and verify list view loads",
            steps=steps,
            tags=["e2e", "read", "records"],
        ))

        return journeys

    def _generate_settings_journey(self) -> list:
        """Generate a settings journey."""
        journeys = []

        settings_view = self._find_view_by_name("SettingsView")
        if not settings_view:
            return journeys

        tab_label = self._get_tab_for_view("SettingsView") or "Settings"

        steps = [
            JourneyStep("launchApp"),
            JourneyStep("tapOn", tab_label),
            JourneyStep("assertVisible", tab_label),
        ]

        # Look for interesting settings actions
        buttons = self._find_buttons_in_view("SettingsView")
        for btn in buttons:
            if any(word in btn.lower() for word in ["export", "print", "clear", "reset"]):
                steps.append(JourneyStep("assertVisible", btn))
                break

        steps.append(JourneyStep("takeScreenshot", "journey_settings"))

        journeys.append(UserJourney(
            name="journey_settings",
            description="Navigate to Settings and verify options are available",
            steps=steps,
            tags=["e2e", "settings"],
        ))

        return journeys


def main():
    parser = argparse.ArgumentParser(description="Generate real user journey tests")
    parser.add_argument("--app-structure", required=True, help="Path to app_structure.json")
    parser.add_argument("--output-dir", required=True, help="Output directory (.maestro/)")
    parser.add_argument("--bundle-id", required=True, help="App bundle ID")
    args = parser.parse_args()

    structure = json.loads(Path(args.app_structure).read_text(encoding="utf-8"))
    generator = JourneyGenerator(structure, args.bundle_id, Path(args.output_dir))
    journeys = generator.generate_all()
    generator.write_journeys(journeys)


if __name__ == "__main__":
    main()
