#!/usr/bin/env bash
# MUFREZE — Parallel Task Execution
# Runs multiple atomic tasks simultaneously via background processes
# Usage: parallel.sh <tasks_file> <work_dir> [max_concurrent]
#
# tasks_file format (one task per line):
#   worker|prompt
#   kimi|Create users.py with FastAPI router
#   codex|Create tests/test_users.py with pytest

set -euo pipefail

readonly E_SUCCESS="✅"
readonly E_FAILURE="❌"
readonly E_WARN="⚠️"
readonly E_MEDAL="🎖️"

# ---------------------------------------------------------------------------
# Arguments
# ---------------------------------------------------------------------------
tasks_file="${1:-}"
work_dir="${2:-}"
max_concurrent="${3:-4}"

if [[ -z "$tasks_file" || -z "$work_dir" ]]; then
    echo "${E_FAILURE} Usage: $0 <tasks_file> <work_dir> [max_concurrent]" >&2
    echo "" >&2
    echo "tasks_file format (pipe-separated, one per line):" >&2
    echo "  worker|task prompt" >&2
    echo "  kimi|Create users.py with FastAPI router" >&2
    echo "  codex|Create tests/test_users.py with pytest" >&2
    exit 1
fi

if [[ ! -f "$tasks_file" ]]; then
    echo "${E_FAILURE} Tasks file not found: $tasks_file" >&2
    exit 1
fi

work_dir="$(cd "$work_dir" && pwd)"
MUFREZE_HOME="${MUFREZE_HOME:-$HOME/.mufreze}"
_SELF="${BASH_SOURCE[0]}"
while [[ -L "$_SELF" ]]; do _SELF="$(readlink "$_SELF")"; done
SCRIPT_DIR="$(cd "$(dirname "$_SELF")" && pwd)"

# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------
results_dir=$(mktemp -d)
trap "rm -rf '$results_dir'" EXIT

total_tasks=0
completed=0
failed=0
running=0
pids=()
task_names=()

# ---------------------------------------------------------------------------
# Read tasks
# ---------------------------------------------------------------------------
tasks=()
while IFS= read -r line || [[ -n "$line" ]]; do
    # Skip empty lines and comments
    [[ -z "$line" || "$line" == \#* ]] && continue
    tasks+=("$line")
    total_tasks=$((total_tasks + 1))
done < "$tasks_file"

if [[ $total_tasks -eq 0 ]]; then
    echo "${E_WARN} No tasks found in $tasks_file" >&2
    exit 0
fi

echo "${E_MEDAL} MUFREZE Parallel: $total_tasks tasks, max $max_concurrent concurrent" >&2
echo "" >&2

# ---------------------------------------------------------------------------
# Run tasks in parallel with concurrency limit
# ---------------------------------------------------------------------------
task_idx=0

run_task() {
    local idx="$1"
    local line="${tasks[$idx]}"
    local worker="${line%%|*}"
    local prompt="${line#*|}"
    local result_file="$results_dir/task-${idx}.result"

    echo "${E_MEDAL} [Task $((idx+1))/$total_tasks] Starting: $worker → ${prompt:0:60}..." >&2

    (
        if "$SCRIPT_DIR/delegate.sh" "$worker" "$prompt" "$work_dir" 2>"$results_dir/task-${idx}.err"; then
            echo "success" > "$result_file"
        else
            echo "failure" > "$result_file"
        fi
    ) &

    pids+=($!)
    task_names+=("$worker: ${prompt:0:50}")
}

# Launch initial batch
while [[ $task_idx -lt $total_tasks && $running -lt $max_concurrent ]]; do
    run_task "$task_idx"
    task_idx=$((task_idx + 1))
    running=$((running + 1))
done

# Wait for completions and launch more
while [[ $completed -lt $total_tasks ]]; do
    for i in "${!pids[@]}"; do
        pid="${pids[$i]}"
        if ! kill -0 "$pid" 2>/dev/null; then
            wait "$pid" 2>/dev/null || true
            result_file="$results_dir/task-${i}.result"

            if [[ -f "$result_file" && "$(cat "$result_file")" == "success" ]]; then
                echo "${E_SUCCESS} [Task $((i+1))] Done: ${task_names[$i]}" >&2
                completed=$((completed + 1))
            else
                echo "${E_FAILURE} [Task $((i+1))] Failed: ${task_names[$i]}" >&2
                completed=$((completed + 1))
                failed=$((failed + 1))
            fi

            running=$((running - 1))
            unset 'pids[i]'

            # Launch next task if available
            if [[ $task_idx -lt $total_tasks && $running -lt $max_concurrent ]]; then
                run_task "$task_idx"
                task_idx=$((task_idx + 1))
                running=$((running + 1))
            fi
        fi
    done
    sleep 0.5
done

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo "" >&2
echo "${E_MEDAL} MUFREZE Parallel: Complete" >&2
echo "  Total:   $total_tasks" >&2
echo "  Success: $((total_tasks - failed))" >&2
echo "  Failed:  $failed" >&2

if [[ $failed -gt 0 ]]; then
    echo "" >&2
    echo "  Failed task errors:" >&2
    for f in "$results_dir"/task-*.err; do
        [[ -f "$f" ]] || continue
        idx=$(basename "$f" | sed 's/task-//;s/.err//')
        if [[ -f "$results_dir/task-${idx}.result" && "$(cat "$results_dir/task-${idx}.result")" == "failure" ]]; then
            echo "  --- Task $((idx+1)) ---" >&2
            tail -5 "$f" >&2
        fi
    done
    exit 1
fi

exit 0
