#!/usr/bin/env bash
# Library: witty_phrases.sh
# Purpose: Witty loading phrases and helpful tips for terminal UI
# Dependencies: None
#
# Functions:
#   get_random_phrase()   - Return a random witty loading phrase
#   get_random_tip()      - Return a random helpful tip
#   cycle_phrases(sec)    - Background process cycling phrases
#   get_all_phrases()     - Return all phrases (for testing)
#   get_all_tips()        - Return all tips (for testing)
#
# Usage:
#   source witty_phrases.sh
#   phrase=$(get_random_phrase)
#   echo "Loading... $phrase"

set -euo pipefail

# Verify bash is running
if [ -z "${BASH_VERSION:-}" ]; then
    echo "Error: This library requires bash" >&2
    return 1 2>/dev/null || exit 1
fi

# ─────────────────────────────────────────────────────────────────────────────
# Witty Loading Phrases
# ─────────────────────────────────────────────────────────────────────────────

# Array of witty loading phrases
WITTY_PHRASES=(
    # Classic computing humor
    "Reticulating splines..."
    "Warming up the AI hamsters..."
    "Compiling brilliance..."
    "Negotiating with Xcode..."
    "Bribing the compiler..."
    "Consulting the Swift gods..."
    "Polishing the bits..."
    "Untangling the dependency graph..."

    # Build-related humor
    "Teaching SwiftUI new tricks..."
    "Convincing the linker to cooperate..."
    "Generating code that actually works..."
    "Optimizing your future..."
    "Brewing fresh binaries..."
    "Massaging the abstract syntax tree..."
    "Wrangling type inference..."
    "Summoning the build daemon..."

    # AI-themed humor
    "Asking Claude for advice..."
    "Consulting the neural oracle..."
    "Training the error-fixing model..."
    "Downloading more intelligence..."
    "Calibrating the sarcasm detector..."
    "Enhancing creativity subroutines..."
    "Synthesizing solutions..."
    "Generating plausible code..."

    # Developer life humor
    "Searching Stack Overflow..."
    "Blaming the previous developer..."
    "Pretending to understand generics..."
    "Copying from the documentation..."
    "Hoping for the best..."
    "Making it someone else's problem..."
    "Updating your resume (just kidding)..."
    "Questioning life choices..."

    # Swift/Apple specific
    "Waiting for Xcode to respond..."
    "Sacrificing to the notarization gods..."
    "Appeasing App Store Review..."
    "Counting optionals..."
    "Unwrapping safely..."
    "Fighting the borrow checker... wait, wrong language..."
    "Making Swift feel natural..."
    "Embracing protocol-oriented thinking..."

    # Meta humor
    "Writing witty loading messages..."
    "Procrastinating productively..."
    "Making loading screens entertaining..."
    "Pretending this is complicated..."
    "Building anticipation..."
    "Creating the illusion of progress..."
    "Almost there... probably..."
    "This is fine..."

    # Positive vibes
    "Crafting excellence..."
    "Manifesting success..."
    "Channeling good vibes..."
    "Believing in your code..."
    "Making magic happen..."
    "Turning coffee into code..."
    "Transforming ideas into reality..."
    "Building something awesome..."
)

# ─────────────────────────────────────────────────────────────────────────────
# Helpful Tips
# ─────────────────────────────────────────────────────────────────────────────

# Array of helpful tips
HELPFUL_TIPS=(
    # Automation tips
    "Tip: Use --yolo for fully automated builds with maximum retries"
    "Tip: Set BUILDAGENT_FANCY_UI=true for a more polished experience"
    "Tip: Incremental builds are enabled by default for 2-10x speedup"
    "Tip: Use --ai-provider claude for Anthropic Claude integration"
    "Tip: Use --stream to see AI output in real-time"

    # Workflow tips
    "Tip: Run without arguments for auto-detect mode - it just works!"
    "Tip: Session defaults remember your preferences after 3 uses"
    "Tip: Use --verbose for detailed output when debugging issues"
    "Tip: Add --skip-lint to speed up iteration during development"
    "Tip: Use --dry-run to preview what would happen"

    # Performance tips
    "Tip: Custom DerivedData path can speed up builds significantly"
    "Tip: Use --no-incremental if builds seem stale"
    "Tip: The Build/ folder in phase5 is auto-detected for faster builds"
    "Tip: Clean builds (--clean) can fix mysterious issues"
    "Tip: Use --clean-derived-data for a complete fresh start"

    # Integration tips
    "Tip: Set AI_PROVIDER env var to change default AI provider"
    "Tip: Letta provides stateful agents with persistent memory"
    "Tip: GitHub Copilot works great for quick fixes"
    "Tip: Multiple AI providers can be installed simultaneously"
    "Tip: The script auto-installs missing AI providers when possible"

    # Advanced tips
    "Tip: Use --context to add custom documentation to AI context"
    "Tip: Smart docs filtering reduces context size automatically"
    "Tip: Use --no-smart-docs to include all documentation"
    "Tip: Session files are at .foundation-session.json"
    "Tip: Build queue prevents conflicts between parallel agents"
)

# ─────────────────────────────────────────────────────────────────────────────
# Functions
# ─────────────────────────────────────────────────────────────────────────────

# Get a random witty phrase
# Outputs: Random phrase to stdout
get_random_phrase() {
    local count=${#WITTY_PHRASES[@]}
    if [ "$count" -eq 0 ]; then
        echo "Loading..."
        return
    fi

    local index=$((RANDOM % count))
    echo "${WITTY_PHRASES[$index]}"
}

# Get a random helpful tip
# Outputs: Random tip to stdout
get_random_tip() {
    local count=${#HELPFUL_TIPS[@]}
    if [ "$count" -eq 0 ]; then
        echo "Tip: Read the documentation!"
        return
    fi

    local index=$((RANDOM % count))
    echo "${HELPFUL_TIPS[$index]}"
}

# Get a random tip with icon
# Outputs: Tip with lightbulb icon to stdout
get_random_tip_formatted() {
    local tip
    tip=$(get_random_tip)

    # Check if ui_themes is loaded for icons
    if type get_icon &>/dev/null; then
        local icon
        icon=$(get_icon "tip" 2>/dev/null || echo "*")
        echo "${icon} ${tip}"
    else
        echo "${tip}"
    fi
}

# Get all phrases (for testing/display)
# Outputs: All phrases, one per line
get_all_phrases() {
    printf '%s\n' "${WITTY_PHRASES[@]}"
}

# Get all tips (for testing/display)
# Outputs: All tips, one per line
get_all_tips() {
    printf '%s\n' "${HELPFUL_TIPS[@]}"
}

# Cycle phrases in the background
# Arguments:
#   $1 - interval in seconds (default: 5)
# Returns: PID of background process
cycle_phrases() {
    local interval="${1:-5}"

    (
        while true; do
            get_random_phrase
            sleep "$interval"
        done
    ) &

    echo $!
}

# Get phrase count
get_phrase_count() {
    echo "${#WITTY_PHRASES[@]}"
}

# Get tip count
get_tip_count() {
    echo "${#HELPFUL_TIPS[@]}"
}

# Add a custom phrase (for extensibility)
# Arguments:
#   $1 - phrase to add
add_phrase() {
    local phrase="$1"
    WITTY_PHRASES+=("$phrase")
}

# Add a custom tip (for extensibility)
# Arguments:
#   $1 - tip to add
add_tip() {
    local tip="$1"
    HELPFUL_TIPS+=("$tip")
}

# Get phrase by index (for deterministic testing)
# Arguments:
#   $1 - index (0-based)
# Outputs: Phrase at index, or empty if out of bounds
get_phrase_at() {
    local index="$1"
    local count=${#WITTY_PHRASES[@]}

    if [ "$index" -ge 0 ] && [ "$index" -lt "$count" ]; then
        echo "${WITTY_PHRASES[$index]}"
    fi
}

# Get tip by index (for deterministic testing)
# Arguments:
#   $1 - index (0-based)
# Outputs: Tip at index, or empty if out of bounds
get_tip_at() {
    local index="$1"
    local count=${#HELPFUL_TIPS[@]}

    if [ "$index" -ge 0 ] && [ "$index" -lt "$count" ]; then
        echo "${HELPFUL_TIPS[$index]}"
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Build Phase Specific Phrases
# ─────────────────────────────────────────────────────────────────────────────

# Phrases for specific build phases
declare -A PHASE_PHRASES=(
    [gathering_context]="Gathering the sacred texts..."
    [generating_code]="Channeling the AI muse..."
    [building]="Forging your app in the fires of compilation..."
    [testing]="Interrogating your code..."
    [linting]="Nitpicking with SwiftLint..."
    [linking]="Connecting the dots..."
    [signing]="Applying the royal seal..."
    [archiving]="Wrapping it up nicely..."
)

# Get phrase for a specific build phase
# Arguments:
#   $1 - phase name
# Outputs: Phase-specific phrase or generic phrase
get_phase_phrase() {
    local phase="$1"

    if [ -n "${PHASE_PHRASES[$phase]:-}" ]; then
        echo "${PHASE_PHRASES[$phase]}"
    else
        get_random_phrase
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Completion Messages
# ─────────────────────────────────────────────────────────────────────────────

# Success messages
SUCCESS_MESSAGES=(
    "Build complete! Ship it!"
    "All systems go!"
    "Nailed it!"
    "Clean as a whistle!"
    "Ready for launch!"
    "You're a coding wizard!"
    "Victory is yours!"
    "Perfection achieved!"
)

# Failure messages (sympathetic)
FAILURE_MESSAGES=(
    "Don't worry, we'll get 'em next time!"
    "Rome wasn't built in one compile..."
    "Every expert was once a beginner..."
    "Bugs are just undocumented features..."
    "Have you tried turning it off and on again?"
    "Coffee break, then retry?"
    "This calls for rubber duck debugging..."
    "Let's break this down..."
)

# Get random success message
get_success_message() {
    local count=${#SUCCESS_MESSAGES[@]}
    local index=$((RANDOM % count))
    echo "${SUCCESS_MESSAGES[$index]}"
}

# Get random failure message
get_failure_message() {
    local count=${#FAILURE_MESSAGES[@]}
    local index=$((RANDOM % count))
    echo "${FAILURE_MESSAGES[$index]}"
}
