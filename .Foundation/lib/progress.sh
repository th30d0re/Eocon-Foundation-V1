#!/usr/bin/env bash

# Progress Tracking Library for Foundation Framework
# Provides comprehensive progress tracking at multiple levels

# Verify bash is running
if [ -z "${BASH_VERSION:-}" ]; then
    echo "Error: This library requires bash" >&2
    return 1 2>/dev/null || exit 1
fi

# Detect project root
if [ -z "$PROJECT_ROOT" ]; then
    PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fi

PROGRESS_DIR="${PROJECT_ROOT}/.foundation/progress"
mkdir -p "$PROGRESS_DIR"

# Current session progress file
PROGRESS_FILE=""

# Initialize progress tracking for a new session
init_progress_tracking() {
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local session_id="${timestamp}_$$"

    PROGRESS_FILE="${PROGRESS_DIR}/${timestamp}.json"
    export PROGRESS_FILE

    # Create initial progress structure
    cat > "$PROGRESS_FILE" << EOF
{
  "session_id": "$session_id",
  "started_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "current_phase": "0",
  "phases": {
    "0": {
      "name": "Constitution",
      "status": "pending",
      "started_at": null,
      "completed_at": null,
      "progress_percent": 0,
      "subtasks": []
    },
    "1": {
      "name": "Planner",
      "status": "pending",
      "started_at": null,
      "completed_at": null,
      "progress_percent": 0,
      "subtasks": []
    },
    "2": {
      "name": "Question",
      "status": "pending",
      "started_at": null,
      "completed_at": null,
      "progress_percent": 0,
      "subtasks": []
    },
    "3": {
      "name": "Optimization",
      "status": "pending",
      "started_at": null,
      "completed_at": null,
      "progress_percent": 0,
      "subtasks": []
    },
    "4": {
      "name": "Stages",
      "status": "pending",
      "started_at": null,
      "completed_at": null,
      "progress_percent": 0,
      "subtasks": []
    },
    "5": {
      "name": "Execution",
      "status": "pending",
      "started_at": null,
      "completed_at": null,
      "progress_percent": 0,
      "stages": {}
    }
  },
  "overall_progress": 0,
  "estimated_completion": null
}
EOF

    echo "$PROGRESS_FILE"
}

# Update phase progress
# Usage: update_phase_progress <phase_num> <status> [progress_percent]
update_phase_progress() {
    local phase="$1"
    local status="$2"
    local progress="${3:-0}"

    if [ -z "$PROGRESS_FILE" ] || [ ! -f "$PROGRESS_FILE" ]; then
        return 1
    fi

    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Update phase status using python for JSON manipulation
    python3 -c "
import json
import sys

try:
    with open('$PROGRESS_FILE', 'r') as f:
        data = json.load(f)

    phase_key = str($phase)
    if phase_key in data['phases']:
        data['phases'][phase_key]['status'] = '$status'
        data['phases'][phase_key]['progress_percent'] = $progress
        data['current_phase'] = phase_key

        if '$status' == 'running' and data['phases'][phase_key]['started_at'] is None:
            data['phases'][phase_key]['started_at'] = '$timestamp'
        elif '$status' in ['completed', 'failed']:
            data['phases'][phase_key]['completed_at'] = '$timestamp'
            data['phases'][phase_key]['progress_percent'] = 100 if '$status' == 'completed' else $progress

        # Update overall progress (simple average of all phase progress)
        total_progress = sum(p['progress_percent'] for p in data['phases'].values())
        data['overall_progress'] = round(total_progress / len(data['phases']))

    with open('$PROGRESS_FILE', 'w') as f:
        json.dump(data, f, indent=2)

except Exception as e:
    print(f'Error updating progress: {e}', file=sys.stderr)
    sys.exit(1)
" 2>/dev/null || true
}

# Update wave progress (for Phase 5)
# Usage: update_wave_progress <plan> <stage> <wave> <status> [debug_attempts] [tests_passed] [tests_failed] [files_generated]
update_wave_progress() {
    local plan="$1"
    local stage="$2"
    local wave="$3"
    local status="$4"
    local debug_attempts="${5:-0}"
    local tests_passed="${6:-0}"
    local tests_failed="${7:-0}"
    local files_generated="${8:-0}"

    if [ -z "$PROGRESS_FILE" ] || [ ! -f "$PROGRESS_FILE" ]; then
        return 1
    fi

    # Update wave progress using python
    python3 -c "
import json
import sys

try:
    with open('$PROGRESS_FILE', 'r') as f:
        data = json.load(f)

    # Ensure Phase 5 stages structure exists
    if 'stages' not in data['phases']['5']:
        data['phases']['5']['stages'] = {}

    stage_key = 'stage_$stage'
    if stage_key not in data['phases']['5']['stages']:
        data['phases']['5']['stages'][stage_key] = {'waves': {}}

    wave_key = 'wave_$wave'
    data['phases']['5']['stages'][stage_key]['waves'][wave_key] = {
        'plan': '$plan',
        'status': '$status',
        'debug_attempts': $debug_attempts,
        'tests_passed': $tests_passed,
        'tests_failed': $tests_failed,
        'files_generated': $files_generated
    }

    # Update Phase 5 progress based on wave completion
    total_waves = 0
    completed_waves = 0
    for stage in data['phases']['5']['stages'].values():
        for wave in stage['waves'].values():
            total_waves += 1
            if wave['status'] == 'completed':
                completed_waves += 1

    if total_waves > 0:
        data['phases']['5']['progress_percent'] = round((completed_waves / total_waves) * 100)

    with open('$PROGRESS_FILE', 'w') as f:
        json.dump(data, f, indent=2)

except Exception as e:
    print(f'Error updating wave progress: {e}', file=sys.stderr)
    sys.exit(1)
" 2>/dev/null || true
}

# Update task progress (generic subtask tracking)
# Usage: update_task_progress <phase_num> <task_name> <status>
update_task_progress() {
    local phase="$1"
    local task_name="$2"
    local status="$3"

    if [ -z "$PROGRESS_FILE" ] || [ ! -f "$PROGRESS_FILE" ]; then
        return 1
    fi

    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Update task using python
    python3 -c "
import json
import sys

try:
    with open('$PROGRESS_FILE', 'r') as f:
        data = json.load(f)

    phase_key = str($phase)
    if phase_key in data['phases']:
        # Add or update task in subtasks list
        task_found = False
        for task in data['phases'][phase_key]['subtasks']:
            if task['name'] == '$task_name':
                task['status'] = '$status'
                task['updated_at'] = '$timestamp'
                task_found = True
                break

        if not task_found:
            data['phases'][phase_key]['subtasks'].append({
                'name': '$task_name',
                'status': '$status',
                'started_at': '$timestamp',
                'updated_at': '$timestamp'
            })

    with open('$PROGRESS_FILE', 'w') as f:
        json.dump(data, f, indent=2)

except Exception as e:
    print(f'Error updating task progress: {e}', file=sys.stderr)
    sys.exit(1)
" 2>/dev/null || true
}

# Get progress summary
get_progress_summary() {
    if [ -z "$PROGRESS_FILE" ] || [ ! -f "$PROGRESS_FILE" ]; then
        echo "No active progress tracking"
        return 1
    fi

    python3 -c "
import json
import sys

try:
    with open('$PROGRESS_FILE', 'r') as f:
        data = json.load(f)

    print(f\"Session: {data['session_id']}\")
    print(f\"Started: {data['started_at']}\")
    print(f\"Overall Progress: {data['overall_progress']}%\")
    print(f\"Current Phase: Phase {data['current_phase']}\")
    print()

    for phase_num in sorted(data['phases'].keys()):
        phase = data['phases'][phase_num]
        status_symbol = {
            'pending': '⏳',
            'running': '⚙️ ',
            'completed': '✅',
            'failed': '❌'
        }.get(phase['status'], '?')

        print(f\"{status_symbol} Phase {phase_num}: {phase['name']} - {phase['status']} ({phase['progress_percent']}%)\")

        # Show subtasks if any
        if phase.get('subtasks'):
            for task in phase['subtasks']:
                task_symbol = '✓' if task['status'] == 'completed' else '○'
                print(f\"   {task_symbol} {task['name']}\")

        # Show wave progress for Phase 5
        if phase_num == '5' and 'stages' in phase:
            for stage_key, stage in phase['stages'].items():
                print(f\"   Stage {stage_key}:\")
                for wave_key, wave in stage['waves'].items():
                    wave_symbol = {
                        'pending': '⏳',
                        'generating': '🔨',
                        'testing': '🧪',
                        'debugging': '🐛',
                        'completed': '✅',
                        'failed': '❌'
                    }.get(wave['status'], '?')
                    print(f\"      {wave_symbol} {wave_key} ({wave['plan']}) - Tests: {wave['tests_passed']}/{wave['tests_passed']+wave['tests_failed']}\")

except Exception as e:
    print(f'Error reading progress: {e}', file=sys.stderr)
    sys.exit(1)
" 2>/dev/null
}

# Calculate ETA based on current progress
calculate_eta() {
    if [ -z "$PROGRESS_FILE" ] || [ ! -f "$PROGRESS_FILE" ]; then
        echo "Unknown"
        return 1
    fi

    python3 -c "
import json
import sys
from datetime import datetime, timedelta

try:
    with open('$PROGRESS_FILE', 'r') as f:
        data = json.load(f)

    started_at = datetime.fromisoformat(data['started_at'].replace('Z', '+00:00'))
    now = datetime.utcnow().replace(tzinfo=started_at.tzinfo)
    elapsed = (now - started_at).total_seconds()

    progress = data['overall_progress']
    if progress > 0 and progress < 100:
        total_estimated = elapsed / (progress / 100.0)
        remaining = total_estimated - elapsed
        eta = now + timedelta(seconds=remaining)

        # Format remaining time
        hours = int(remaining // 3600)
        minutes = int((remaining % 3600) // 60)

        if hours > 0:
            print(f'ETA: {hours}h {minutes}m (at {eta.strftime(\"%H:%M\")})')
        else:
            print(f'ETA: {minutes}m (at {eta.strftime(\"%H:%M\")})')
    elif progress >= 100:
        print('Completed')
    else:
        print('Calculating...')

except Exception as e:
    print('Unknown', file=sys.stderr)
    sys.exit(1)
" 2>/dev/null || echo "Unknown"
}

# Load existing progress file (for resuming)
load_progress_file() {
    local progress_file="$1"

    if [ -f "$progress_file" ]; then
        PROGRESS_FILE="$progress_file"
        export PROGRESS_FILE
        echo "Loaded progress from: $progress_file"
        return 0
    else
        echo "Progress file not found: $progress_file" >&2
        return 1
    fi
}

# Get the most recent progress file
get_latest_progress_file() {
    if [ -d "$PROGRESS_DIR" ]; then
        ls -t "$PROGRESS_DIR"/*.json 2>/dev/null | head -1
    fi
}
