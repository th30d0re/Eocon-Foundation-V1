# UI Customization Guide

Comprehensive guide to customizing the Eocon Foundation Build System's visual appearance.

## Table of Contents

- [Overview](#overview)
- [Enabling Fancy UI](#enabling-fancy-ui)
- [Themes](#themes)
- [Components](#components)
- [Environment Variables](#environment-variables)
- [Terminal Compatibility](#terminal-compatibility)
- [Customization Examples](#customization-examples)
- [Creating Custom Themes](#creating-custom-themes)

---

## Overview

The Eocon Foundation Build System features a **Fancy UI** system that transforms terminal output into a beautiful, informative experience with:

- 🎨 **Dark and Light Themes** - Catppuccin-inspired color palettes
- 📊 **Rich Components** - Progress bars, spinners, boxes, gradients
- ✨ **Smart Icons** - Unicode icons with ASCII fallback
- 🖥️ **Terminal Detection** - Automatic capability detection
- ♿ **Accessibility** - Respects NO_COLOR and CI environments

---

## Enabling Fancy UI

### Quick Start

```bash
# Enable fancy UI
export BUILDAGENT_FANCY_UI=true

# Run any agent
./BuildAgent.sh --scheme MyApp
```

### Persistent Enable

Add to your `~/.zshrc` or `~/.bashrc`:

```bash
# Eocon Foundation Fancy UI
export BUILDAGENT_FANCY_UI=true
export BUILDAGENT_THEME=dark  # or 'light'
export BUILDAGENT_SHOW_TIPS=true
```

Then reload:

```bash
source ~/.zshrc  # or ~/.bashrc
```

### Opt-Out

```bash
# Disable fancy UI
export BUILDAGENT_FANCY_UI=false

# Or use NO_COLOR standard
export NO_COLOR=1
```

---

## Themes

### Dark Theme (Default)

Inspired by Catppuccin Mocha, optimized for dark terminal backgrounds.

**Color Palette**:

```bash
# Base Colors
BG="#1e1e2e"      # Background
FG="#cdd6f4"      # Foreground
SUBTLE="#6c7086" # Subtle text

# Accent Colors
BLUE="#89b4fa"    # Primary
GREEN="#a6e3a1"   # Success
YELLOW="#f9e2af"  # Warning
RED="#f38ba8"     # Error
PINK="#f5c2e7"    # Highlight
MAUVE="#cba6f7"   # Secondary
LAVENDER="#b4befe" # Tertiary
```

**Preview**:

```
╭─────────────────────────────────────────────╮
│  🏗️  Eocon Foundation Build System v3.0   │
╰─────────────────────────────────────────────╯

 Building MyApp (iOS)
 ████████████████░░░░░░░░  75%
 ⠋ Compiling Swift files...

 ✓ Build succeeded in 45s
```

### Light Theme

Optimized for light terminal backgrounds.

**Color Palette**:

```bash
# Base Colors
BG="#eff1f5"      # Background
FG="#4c4f69"      # Foreground
SUBTLE="#9ca0b0"  # Subtle text

# Accent Colors (darker for light bg)
BLUE="#1e66f5"
GREEN="#40a02b"
YELLOW="#df8e1d"
RED="#d20f39"
PINK="#ea76cb"
MAUVE="#8839ef"
LAVENDER="#7287fd"
```

**Activate**:

```bash
export BUILDAGENT_THEME=light
```

---

## Components

### Logo Display

The build system displays a stylized logo at startup.

**Sizes**:

```bash
# Large (default for BuildAgent)
./BuildAgent.sh  # Shows large logo

# Medium (for test runners)
./testRunner.sh  # Shows medium logo

# Small (for utilities)
./BuildLint.sh  # Shows small logo

# None (quiet mode)
./BuildAgent.sh --quiet  # No logo
```

**Example Output**:

```
╔════════════════════════════════════════════════════╗
║                                                    ║
║     ███████╗ ██████╗  ██████╗ ██████╗ ███╗   ██╗  ║
║     ██╔════╝██╔═══██╗██╔════╝██╔═══██╗████╗  ██║  ║
║     █████╗  ██║   ██║██║     ██║   ██║██╔██╗ ██║  ║
║     ██╔══╝  ██║   ██║██║     ██║   ██║██║╚██╗██║  ║
║     ███████╗╚██████╔╝╚██████╗╚██████╔╝██║ ╚████║  ║
║     ╚══════╝ ╚═════╝  ╚═════╝ ╚═════╝ ╚═╝  ╚═══╝  ║
║                                                    ║
║            Foundation Build System v3.0            ║
║                                                    ║
╚════════════════════════════════════════════════════╝
```

### Box Drawing

Beautiful boxes with rounded corners.

**Usage in Agents**:

```bash
source lib/ui_components.sh

draw_box "Build Complete" "MyApp built successfully in 45 seconds"
```

**Output**:

```
╭─────────────────────────────────────────╮
│ Build Complete                          │
│ MyApp built successfully in 45 seconds  │
╰─────────────────────────────────────────╯
```

**Box Styles**:

```bash
# Rounded (default)
╭─────╮
│     │
╰─────╯

# Sharp (fallback)
┌─────┐
│     │
└─────┘

# ASCII (lowest common denominator)
+-----+
|     |
+-----+
```

### Progress Bars

Visual progress indication with percentage.

**Usage**:

```bash
source lib/ui_components.sh

show_progress 75  # 75% complete
```

**Output**:

```
 Building... ████████████████░░░░░░░░ 75%
```

**Features**:

- Filled portion in accent color
- Smooth animation
- Percentage display
- Custom width support

### Step Indicators

Show progress through multi-step processes.

**Usage**:

```bash
source lib/ui_components.sh

show_step 2 5 "Running Tests"
```

**Output**:

```
[2/5] Running Tests...
```

### Status Footer

Persistent status bar at bottom of output.

**Usage**:

```bash
source lib/ui_components.sh

show_footer "Building" "75%" "3m 15s"
```

**Output**:

```
─────────────────────────────────────────────────────
 Status: Building | Progress: 75% | Time: 3m 15s
─────────────────────────────────────────────────────
```

### Gradient Text

Text with gradient color effect.

**Usage**:

```bash
source lib/ui_components.sh

gradient_text "Build Succeeded!"
```

**Output**: (text fades from blue to green)

```
Build Succeeded!
```

### Enhanced Spinners

Animated spinners with cycling phrases.

**Styles**:

```bash
# Braille (default)
⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏

# Dots
⠁ ⠂ ⠄ ⡀ ⡈ ⡐ ⡠

# Arrows
← ↖ ↑ ↗ → ↘ ↓ ↙

# Classic
| / - \
```

**With Phrases**:

```bash
export BUILDAGENT_WITTY_PHRASES=true
```

Output cycles through:

```
⠋ Compiling Swift files...
⠙ Brewing some Swift magic...
⠹ Teaching the compiler patience...
⠸ Optimizing your code...
⠼ Almost there...
```

**Configure**:

```bash
export BUILDAGENT_SPINNER_STYLE=braille  # or dots, arrows, classic
export BUILDAGENT_WITTY_PHRASES=true     # Enable phrase cycling
```

---

## Environment Variables

### Core Variables

| Variable | Values | Default | Description |
|----------|--------|---------|-------------|
| `BUILDAGENT_FANCY_UI` | true/false | false | Enable fancy UI system |
| `BUILDAGENT_THEME` | dark/light | dark | Color theme |
| `NO_COLOR` | 1/0 | 0 | Disable all colors (standard) |

### UI Customization

| Variable | Values | Default | Description |
|----------|--------|---------|-------------|
| `BUILDAGENT_SPINNER_STYLE` | braille/dots/arrows/classic | braille | Spinner animation style |
| `BUILDAGENT_WITTY_PHRASES` | true/false | true | Cycle through witty phrases |
| `BUILDAGENT_SHOW_TIPS` | true/false | true | Show helpful tips |
| `BUILDAGENT_LOGO_SIZE` | large/medium/small/none | auto | Logo size |

### Terminal Behavior

| Variable | Values | Default | Description |
|----------|--------|---------|-------------|
| `TERM` | xterm-256color, etc. | auto | Terminal type (auto-detected) |
| `CI` | true/false | false | CI environment (disables fancy UI) |
| `COLUMNS` | number | auto | Terminal width |
| `LINES` | number | auto | Terminal height |

---

## Terminal Compatibility

The UI system automatically detects terminal capabilities.

### Capability Detection

```bash
# Check terminal support
if [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]] && [[ "${TERM:-}" != "dumb" ]]; then
  # Terminal supports colors
fi

# Check for 256 color support
if [[ "${TERM:-}" == *"256color"* ]]; then
  # Use extended color palette
fi

# Check for Unicode support
if [[ "${LANG:-}" == *"UTF-8"* ]]; then
  # Use Unicode box drawing characters
fi
```

### Recommended Terminals

**Excellent Support** (All features):
- iTerm2
- Terminal.app (macOS)
- Alacritty
- Kitty
- WezTerm

**Good Support** (Most features):
- VS Code integrated terminal
- Hyper
- Terminator

**Basic Support** (Fallback mode):
- xterm
- Linux console
- Windows Terminal (via WSL)

### Fallback Behavior

| Feature | Full Support | Fallback |
|---------|--------------|----------|
| Box Drawing | Unicode rounded | ASCII +- |
| Colors | 256 colors | 16 colors |
| Spinners | Braille | Classic \|/- |
| Icons | Unicode emoji | ASCII | |
| Gradients | Smooth | Single color |

---

## Customization Examples

### Example 1: Minimal Clean Look

```bash
export BUILDAGENT_FANCY_UI=true
export BUILDAGENT_THEME=light
export BUILDAGENT_LOGO_SIZE=small
export BUILDAGENT_SPINNER_STYLE=classic
export BUILDAGENT_WITTY_PHRASES=false
export BUILDAGENT_SHOW_TIPS=false
```

### Example 2: Maximum Visual Flair

```bash
export BUILDAGENT_FANCY_UI=true
export BUILDAGENT_THEME=dark
export BUILDAGENT_LOGO_SIZE=large
export BUILDAGENT_SPINNER_STYLE=braille
export BUILDAGENT_WITTY_PHRASES=true
export BUILDAGENT_SHOW_TIPS=true
```

### Example 3: CI/CD Mode

```bash
export BUILDAGENT_FANCY_UI=false
export NO_COLOR=1
# Or just set CI=true - auto-detected
```

### Example 4: Accessibility Mode

```bash
export NO_COLOR=1  # No colors
export BUILDAGENT_FANCY_UI=false  # Plain text only
```

---

## Creating Custom Themes

You can create custom themes by modifying `lib/ui_themes.sh`.

### Theme Structure

```bash
# lib/ui_themes.sh

theme_custom() {
  # Base colors
  export COLOR_BG="#your-bg-color"
  export COLOR_FG="#your-fg-color"
  
  # Accent colors
  export COLOR_PRIMARY="#your-primary"
  export COLOR_SUCCESS="#your-success"
  export COLOR_WARNING="#your-warning"
  export COLOR_ERROR="#your-error"
  
  # Text colors (ANSI)
  export TEXT_PRIMARY="\033[38;2;R;G;Bm"
  export TEXT_SUCCESS="\033[38;2;R;G;Bm"
  # ... etc
}
```

### Activate Custom Theme

```bash
# In your agent script or lib loading
source lib/ui_themes.sh

case "${BUILDAGENT_THEME:-dark}" in
  dark) theme_dark ;;
  light) theme_light ;;
  custom) theme_custom ;;
  *) theme_dark ;;
esac
```

### Example: Solarized Dark Theme

```bash
theme_solarized_dark() {
  # Base colors
  export COLOR_BG="#002b36"
  export COLOR_FG="#839496"
  
  # Accents
  export COLOR_PRIMARY="#268bd2"   # Blue
  export COLOR_SUCCESS="#859900"   # Green
  export COLOR_WARNING="#b58900"   # Yellow
  export COLOR_ERROR="#dc322f"     # Red
  
  # ANSI codes
  export TEXT_PRIMARY="\033[38;2;38;139;210m"
  export TEXT_SUCCESS="\033[38;2;133;153;0m"
  export TEXT_WARNING="\033[38;2;181;137;0m"
  export TEXT_ERROR="\033[38;2;220;50;47m"
  export TEXT_RESET="\033[0m"
}
```

---

## Configuration File

Persistent settings can be saved in `defaults.conf`:

```bash
# .Foundation/Agents/phases/phase5/defaults.conf

# UI Settings
BUILDAGENT_FANCY_UI=true
BUILDAGENT_THEME=dark
BUILDAGENT_SPINNER_STYLE=braille
BUILDAGENT_WITTY_PHRASES=true
BUILDAGENT_SHOW_TIPS=true
BUILDAGENT_LOGO_SIZE=large
```

---

## Tips and Best Practices

### Performance

- Fancy UI adds ~50-100ms overhead
- Disable in CI environments automatically
- Use `--quiet` for script automation

### Accessibility

- Always support NO_COLOR
- Provide ASCII fallbacks
- Don't rely solely on color for information

### Testing

```bash
# Test different terminals
TERM=dumb ./BuildAgent.sh
TERM=xterm ./BuildAgent.sh
TERM=xterm-256color ./BuildAgent.sh

# Test color settings
NO_COLOR=1 ./BuildAgent.sh
BUILDAGENT_THEME=light ./BuildAgent.sh
BUILDAGENT_FANCY_UI=false ./BuildAgent.sh
```

---

## See Also

- [Agent Reference](AGENT_REFERENCE.md) - Agent flags
- [Features](FEATURES.md) - Feature documentation
- [Workflow Examples](WORKFLOW_EXAMPLES.md) - Usage examples
- [Implementation](../Agents/phases/phase5/lib/ui_themes.sh) - Theme source code
- [Components](../Agents/phases/phase5/lib/ui_components.sh) - Component source code

---

**Last Updated**: January 2026  
**Version**: 3.0  
**Themes**: Dark, Light, Custom
