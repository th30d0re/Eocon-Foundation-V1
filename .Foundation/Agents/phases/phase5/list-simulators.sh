#!/bin/bash
# list-simulators.sh - Helper to show available simulators and generate destination strings

set -e

echo "Available iOS Simulators:"
echo "========================="
echo ""

# Get all available iPhone simulators
xcrun simctl list devices available | grep -E "^\s+iPhone" | while IFS= read -r line; do
    # Extract device name and UUID
    device=$(echo "$line" | sed 's/^[[:space:]]*//' | sed 's/ ([A-F0-9-]*).*//')
    uuid=$(echo "$line" | grep -o '([A-F0-9-]*)' | head -1 | tr -d '()')
    
    # Generate destination string
    destination="platform=iOS Simulator,name=$device"
    
    echo "Device: $device"
    echo "Destination: $destination"
    echo "UUID: $uuid"
    echo "---"
done

echo ""
echo "Usage Examples:"
echo "==============="
echo ""
echo "# Use in BuildAgent:"
echo ".Foundation/Agents/phases/phase5/BuildAgent.sh --destination \"platform=iOS Simulator,name=iPhone 17 Pro\" --prompt \"...\""
echo ""
echo "# Use in BuildLint:"
echo ".Foundation/Agents/phases/phase5/BuildLint.sh --destination \"platform=iOS Simulator,name=iPhone 17 Pro\""
echo ""
echo "NOTE: Do NOT use 'OS:latest' or specific OS versions in the destination string."
echo "      Use 'platform=iOS Simulator,name=<device name>' format only."
