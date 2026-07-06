#!/usr/bin/env bats
# ui.bats — characterization tests for ui.sh

load "test_helper"

setup() {
    export RED='' GREEN='' YELLOW='' BLUE='' CYAN='' MAGENTA='' NC=''
    load_build_lib ui
}

@test "ui: detect_unbuffer_method returns a valid method" {
    run detect_unbuffer_method
    [ "$status" -eq 0 ]
    # It should echo one of: stdbuf, unbuffer, script, none
    [[ "$output" =~ ^(stdbuf|unbuffer|script|none)$ ]]
}

@test "ui: show_config_box emits expected labels" {
    export BUILDAGENT_FANCY_UI="true"
    
    # We need to provide a minimal draw_box mock since it's not defined here
    draw_box() {
        echo "BOX_TITLE: $1"
        echo "BOX_CONTENT: $2"
    }
    
    export SCHEME="TestScheme"
    export BUILD_CONFIGURATION="Release"
    export AI_PROVIDER="test_provider"
    export MAX_REPAIR_ATTEMPTS="5"
    export DESTINATION="test_dest"
    export DETECTED_PLATFORMS=("iOS" "macOS")
    
    run show_config_box
    [ "$status" -eq 0 ]
    
    [[ "$output" == *"BOX_TITLE: Configuration"* ]]
    [[ "$output" == *"Scheme: TestScheme"* ]]
    [[ "$output" == *"Configuration: Release"* ]]
    [[ "$output" == *"AI Provider: test_provider"* ]]
    [[ "$output" == *"Max Attempts: 5"* ]]
    [[ "$output" == *"Destination: test_dest"* ]]
    [[ "$output" == *"Platforms: iOS macOS"* ]]
}

@test "ui: show_startup_ui emits labels when fancy UI is true" {
    export BUILDAGENT_FANCY_UI="true"
    export BUILDAGENT_SHOW_TIPS="true"
    
    show_logo() { echo "LOGO_MOCK: $1"; }
    show_banner() { echo "BANNER_MOCK: $1 - $2"; }
    get_random_tip_formatted() { echo "TIP_MOCK: A tip"; }
    
    run show_startup_ui
    [ "$status" -eq 0 ]
    
    [[ "$output" == *"LOGO_MOCK: auto"* ]]
    [[ "$output" == *"BANNER_MOCK: Foundation BuildAgent - AI-Powered Build Verification"* ]]
    [[ "$output" == *"TIP_MOCK: A tip"* ]]
}

@test "ui: start_spinner prints basic message when not a TTY" {
    # Bats run commands without a TTY, so it should hit the non-tty fallback
    run start_spinner "Testing spinner"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[WORKING] Testing spinner"* ]]
}
