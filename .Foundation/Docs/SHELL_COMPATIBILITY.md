# Shell Compatibility Guide

Comprehensive guide to bash requirements, compatibility features, and troubleshooting for the Foundation framework.

## Table of Contents

- [Overview](#overview)
- [Requirements](#requirements)
- [Why Bash?](#why-bash)
- [Bash vs Zsh](#bash-vs-zsh)
- [Version Compatibility](#version-compatibility)
- [BASH_SOURCE Behavior](#bash_source-behavior)
- [Common Pitfalls](#common-pitfalls)
- [Testing Procedures](#testing-procedures)
- [Troubleshooting](#troubleshooting)

---

## Overview

The Eocon Foundation framework is built entirely in bash and requires **bash 3.2 or later** to run. All agents and libraries use `#!/usr/bin/env bash` shebangs for maximum portability across different environments.

### Key Points

- ✅ **Minimum**: bash 3.2 (macOS default)
- 🎯 **Recommended**: bash 4.0 or later
- 🔧 **Shebang**: `#!/usr/bin/env bash` (portable)
- 🚫 **Not Compatible**: sh, zsh, dash (when running scripts directly)
- ✅ **Works From**: Any shell (zsh, sh, etc.) can invoke bash scripts

---

## Requirements

### Minimum Bash Version

| Version | Status | Notes |
|---------|--------|-------|
| bash 3.2 | ✅ Supported | macOS default, core features work with warnings |
| bash 4.0 | ✅ Recommended | Full feature support, associative arrays |
| bash 5.0+ | ✅ Ideal | Latest features, best performance |
| bash < 3.2 | ❌ Not Supported | Missing required features |

### Operating System Support

| OS | Default Bash | Status | Notes |
|----|--------------|--------|-------|
| macOS | 3.2.57 | ✅ Works | Upgrade recommended via Homebrew |
| Linux (Ubuntu/Debian) | 5.0+ | ✅ Full | Modern versions included |
| Linux (CentOS/RHEL) | 4.2+ | ✅ Full | Supported versions |
| BSD | Varies | ⚠️ Depends | May need bash installation |
| Windows (WSL) | 5.0+ | ✅ Full | WSL2 recommended |

---

## Why Bash?

### Bash-Specific Features Used

The Foundation framework relies on bash-specific features that are not available in POSIX sh or zsh:

#### 1. **BASH_SOURCE Array**

Used extensively for path resolution and library sourcing:

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
```

- **bash**: `BASH_SOURCE[0]` contains the script path
- **zsh**: Uses `$0` instead (different semantics)
- **sh**: Not available

#### 2. **BASH_VERSINFO Array**

Used for version detection and compatibility checks:

```bash
if [ "${BASH_VERSINFO[0]}" -ge 4 ]; then
    # Use bash 4.0+ features
fi
```

- **bash**: Built-in array with version info
- **zsh/sh**: Not available

#### 3. **Arrays**

Extensive use of indexed arrays throughout the codebase:

```bash
CONTEXT_PATHS=("Docs/" "Guidelines/" "Examples/")
for path in "${CONTEXT_PATHS[@]}"; do
    # Process each path
done
```

- **bash**: Full array support (bash 3.0+)
- **zsh**: Arrays work but with different syntax
- **sh**: No array support

#### 4. **Parameter Expansion**

Advanced parameter expansion patterns:

```bash
${var#pattern}      # Remove shortest match from beginning
${var##pattern}     # Remove longest match from beginning
${var%pattern}      # Remove shortest match from end
${var%%pattern}     # Remove longest match from end
${var/pattern/str}  # Replace first match
${var//pattern/str} # Replace all matches
${var:-default}     # Use default if unset
${var:=default}     # Set and use default if unset
```

- **bash**: All patterns supported (bash 2.0+)
- **zsh**: Similar support but different edge cases
- **sh**: Limited support (only `:-` and `:=`)

#### 5. **Process Substitution**

Used for piping data without temp files:

```bash
while IFS= read -r line; do
    process "$line"
done < <(command)
```

- **bash 4.0+**: Full support
- **bash 3.2**: Limited support (some contexts don't work)
- **zsh**: Supported
- **sh**: Not available

#### 6. **[[ Conditional Expressions ]]**

Modern conditional testing with regex support:

```bash
if [[ "$string" =~ ^[0-9]+$ ]]; then
    echo "Number detected"
fi
```

- **bash**: Full support (bash 3.0+)
- **zsh**: Supported with different regex syntax
- **sh**: Not available (use `[` or `test`)

---

## Bash vs Zsh

### Key Differences

| Feature | Bash | Zsh | Impact |
|---------|------|-----|--------|
| `BASH_SOURCE` | ✅ Available | ❌ Not available | Required for path detection |
| `$0` semantics | Script name | Script path (when sourced) | Different behavior |
| Array indexing | 0-based | 1-based (by default) | Index calculations differ |
| Parameter expansion | Bash-style | Zsh-style (extended) | Syntax differences |
| Word splitting | By default | Only in `"$@"` context | Quote handling differs |
| `set -e` behavior | Standard | Slightly different | Error handling nuances |

### Why Scripts Use `#!/usr/bin/env bash`

Even though macOS defaults to zsh (since 10.15 Catalina), our scripts explicitly use bash because:

1. **Explicit Requirements**: `#!/usr/bin/env bash` tells the system to run the script in bash
2. **Portability**: Works across systems where bash is in different locations
3. **Consistency**: Same behavior on macOS, Linux, BSD, WSL
4. **User Shell Independence**: Works regardless of user's default shell (zsh, fish, etc.)

### Running from Zsh

You **can** run bash scripts from a zsh shell:

```bash
# Your shell: zsh
# Script shebang: #!/usr/bin/env bash
# Result: Script runs in bash subprocess ✅

# From zsh prompt:
./BuildAgent.sh --plan plan.md

# Or explicitly:
bash BuildAgent.sh --plan plan.md

# Even from zsh script:
zsh -c "bash BuildAgent.sh --plan plan.md"
```

The shebang ensures the script executes in bash, regardless of the calling shell.

---

## Version Compatibility

### Bash 3.2 (macOS Default)

**Status**: ✅ Supported with warnings

**Works:**
- All core build/test/agent functionality
- Basic arrays and parameter expansion
- BASH_SOURCE path resolution
- `set -euo pipefail` error handling
- Most string manipulation

**Limitations:**
- ❌ Associative arrays (requires bash 4.0+)
- ❌ `readarray`/`mapfile` (requires bash 4.0+)
- ⚠️ Process substitution limited in some contexts
- ⚠️ Some `[[` regex patterns behave differently

**Recommendation**: Agents work but upgrade to bash 4.0+ recommended.

### Bash 4.0+

**Status**: ✅ Fully supported (recommended)

**Additional Features:**
- ✅ Associative arrays: `declare -A map; map[key]=value`
- ✅ `readarray`/`mapfile`: Read lines into array efficiently
- ✅ `**` globstar: Recursive directory matching
- ✅ Case modification: `${var^^}`, `${var,,}`
- ✅ Better process substitution support

### Bash 5.0+

**Status**: ✅ Ideal (latest features)

**Additional Features:**
- ✅ Negative array indices: `${array[-1]}`
- ✅ Nameref improvements
- ✅ Better error messages
- ✅ Performance improvements

---

## BASH_SOURCE Behavior

### What is BASH_SOURCE?

`BASH_SOURCE` is a bash-specific array that tracks the chain of source files:

```bash
${BASH_SOURCE[0]}  # Current script/file
${BASH_SOURCE[1]}  # Script that sourced current file
${BASH_SOURCE[2]}  # Script that sourced that file
# ... and so on
```

### Common Usage Pattern

All Foundation scripts use this pattern for path resolution:

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
```

**What this does:**
1. `${BASH_SOURCE[0]}` - Gets current script path
2. `dirname` - Extracts directory path
3. `cd ... && pwd` - Converts to absolute path

### Why This Works

With `#!/usr/bin/env bash` shebang:
- Script always runs in bash (even when called from zsh)
- `BASH_SOURCE` is always available
- Path resolution is consistent across environments

### Sourcing vs Executing

**Executing (our use case):**
```bash
# User runs:
./BuildAgent.sh --plan plan.md

# Shebang ensures:
# - Script runs in bash subprocess
# - BASH_SOURCE[0] = BuildAgent.sh path
# - Works from any parent shell
```

**Sourcing (not our use case):**
```bash
# If someone tried (don't do this):
source BuildAgent.sh --plan plan.md

# Problems:
# - Runs in current shell (might not be bash)
# - Different BASH_SOURCE behavior
# - Variables pollute current shell
```

**Important**: Our scripts are designed to be **executed**, not sourced.

---

## Common Pitfalls

### 1. Running in Wrong Shell

**Problem:**
```bash
# User has zsh as default shell
sh BuildAgent.sh --plan plan.md  # ❌ Wrong!
```

**Error:**
```
Error: This script requires bash but is running in a different shell.
Please run with: bash BuildAgent.sh
```

**Solution:**
```bash
bash BuildAgent.sh --plan plan.md  # ✅ Correct
# Or just:
./BuildAgent.sh --plan plan.md     # ✅ Shebang handles it
```

### 2. Old Bash Version

**Problem:**
```bash
# macOS with default bash 3.2
bash --version
# GNU bash, version 3.2.57(1)-release
```

**Warning:**
```
Warning: Running on bash 3.x (3.2.57). Some features may have limitations.
For full compatibility, install bash 4.0+ via Homebrew: brew install bash
```

**Solution:**
```bash
brew install bash
/usr/local/bin/bash --version
# GNU bash, version 5.2.15(1)-release ✅
```

### 3. Missing Execute Permissions

**Problem:**
```bash
./BuildAgent.sh --plan plan.md
# bash: ./BuildAgent.sh: Permission denied
```

**Solution:**
```bash
chmod +x BuildAgent.sh
./BuildAgent.sh --plan plan.md

# Or run with bash directly:
bash BuildAgent.sh --plan plan.md
```

### 4. Trying to Source Scripts

**Problem:**
```bash
source BuildAgent.sh --plan plan.md
# Variables pollute shell, unexpected behavior
```

**Solution:**
```bash
# Don't source! Execute instead:
./BuildAgent.sh --plan plan.md
```

### 5. Using Bash 4.0+ Features on macOS

**Problem:**
```bash
# Script uses associative array
declare -A mymap
mymap[key]=value

# On macOS bash 3.2:
# bash: declare: -A: invalid option
```

**Solution:**
```bash
# Install bash 4.0+
brew install bash

# Use new bash
/usr/local/bin/bash script.sh
```

---

## Testing Procedures

### For Contributors

Before submitting changes, run the shell compatibility test suite:

```bash
# Run all shell compatibility tests
.Foundation/tests/test-shell-compatibility.sh

# Test output shows:
# - Shebang format verification
# - BASH_SOURCE usage checks
# - Library sourcing tests
# - Execution tests (bash and from zsh)
# - Compatibility function tests
```

### Manual Testing

Test your changes across bash versions:

```bash
# Test on bash 3.2 (macOS default)
bash --version  # Verify 3.2
bash YourScript.sh --test

# Test on bash 4.0+ (if available)
/usr/local/bin/bash --version  # Verify 4.0+
/usr/local/bin/bash YourScript.sh --test

# Test execution from zsh
zsh -c "bash YourScript.sh --test"
```

### CI/CD Testing

Include shell compatibility tests in your CI pipeline:

```yaml
# Example GitHub Actions
jobs:
  test-bash-compatibility:
    strategy:
      matrix:
        bash-version: ['3.2', '4.0', '5.0']
    steps:
      - uses: actions/checkout@v2
      - name: Install bash ${{ matrix.bash-version }}
        run: |
          # Install specific bash version
      - name: Run compatibility tests
        run: bash .Foundation/tests/test-shell-compatibility.sh
```

---

## Troubleshooting

### Check Current Shell

```bash
# What shell am I using?
echo $SHELL

# What shell is this script running in?
echo $BASH_VERSION  # Shows version if bash, empty otherwise
ps -p $$ -o comm=   # Shows current process shell
```

### Check Bash Availability

```bash
# Is bash installed?
which bash
# /bin/bash

# What version?
bash --version
# GNU bash, version 5.2.15(1)-release

# Where is bash installed?
type -a bash
# bash is /usr/local/bin/bash
# bash is /bin/bash
```

### Fix Path Issues

```bash
# Script can't find bash?
# Add to PATH or use full path

# Option 1: Add to PATH
export PATH="/usr/local/bin:$PATH"

# Option 2: Use full path in shebang (not portable!)
#!/usr/local/bin/bash  # Don't do this

# Option 3: Use env (our approach - portable!)
#!/usr/bin/env bash    # ✅ Correct
```

### Verify Shebang

```bash
# Check shebang of script
head -1 BuildAgent.sh
# Should show: #!/usr/bin/env bash

# Not: #!/bin/bash (less portable)
# Not: #!/usr/bin/bash (wrong path on some systems)
```

### Debug BASH_SOURCE Issues

```bash
# Add debug output to script
echo "BASH_SOURCE[0]: ${BASH_SOURCE[0]}"
echo "Script dir: $(dirname "${BASH_SOURCE[0]}")"
echo "PWD: $PWD"
echo "Bash version: $BASH_VERSION"
```

### Test Compatibility Functions

```bash
# Test that compatibility check exists
bash -c '
source .Foundation/lib/helpers.sh
type check_shell_compatibility
check_shell_compatibility
'

# Test bash version detection
bash -c '
source .Foundation/lib/helpers.sh
echo "Detected version: $(check_bash_version)"
'
```

### Common Error Messages

| Error | Cause | Solution |
|-------|-------|----------|
| `This script requires bash` | Running in sh/zsh | Use `bash script.sh` |
| `BASH_SOURCE: unbound variable` | Not running in bash | Use `#!/usr/bin/env bash` shebang |
| `declare: -A: invalid option` | Bash < 4.0 | Upgrade bash or avoid associative arrays |
| `readarray: command not found` | Bash < 4.0 | Use `while read` loop instead |
| `Permission denied` | Missing execute bit | `chmod +x script.sh` |

---

## Best Practices

### For Script Writers

1. **Always use portable shebang:**
   ```bash
   #!/usr/bin/env bash
   ```

2. **Add bash version check to libraries:**
   ```bash
   if [ -z "${BASH_VERSION:-}" ]; then
       echo "Error: This library requires bash" >&2
       return 1 2>/dev/null || exit 1
   fi
   ```

3. **Check for bash 4.0+ features:**
   ```bash
   if [ "${BASH_VERSINFO[0]}" -ge 4 ]; then
       # Use associative arrays, readarray, etc.
   else
       # Fallback for bash 3.2
   fi
   ```

4. **Use BASH_SOURCE for path resolution:**
   ```bash
   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
   ```

5. **Enable strict error handling:**
   ```bash
   set -euo pipefail
   ```

### For Users

1. **Know your bash version:**
   ```bash
   bash --version
   ```

2. **Upgrade if on macOS:**
   ```bash
   brew install bash
   ```

3. **Execute scripts, don't source them:**
   ```bash
   ./script.sh      # ✅ Good
   bash script.sh   # ✅ Good
   source script.sh # ❌ Don't do this
   ```

4. **Use bash explicitly if in doubt:**
   ```bash
   bash BuildAgent.sh --plan plan.md
   ```

---

## Additional Resources

- [Official Bash Manual](https://www.gnu.org/software/bash/manual/)
- [Bash Guide for Beginners](https://tldp.org/LDP/Bash-Beginners-Guide/html/)
- [ShellCheck](https://www.shellcheck.net/) - Shell script linter
- [Bash FAQ](http://mywiki.wooledge.org/BashFAQ)
- [POSIX vs Bash](https://stackoverflow.com/questions/6787734/what-is-the-difference-between-posix-and-bash)

---

## Summary

✅ **Requirements**: bash 3.2+ (4.0+ recommended)
✅ **Shebang**: `#!/usr/bin/env bash` for portability
✅ **Compatibility**: Automatic checks in all agents
✅ **macOS**: Works with default bash 3.2, upgrade recommended
✅ **Testing**: Comprehensive test suite included
✅ **Support**: Clear error messages and troubleshooting guides

The Foundation framework is designed to work across all environments where bash is available, with graceful degradation on older bash versions and clear guidance for users.