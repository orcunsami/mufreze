#!/usr/bin/env bash
# MUFREZE
# Show project status, worker assignments, and pending tasks
# Usage: status.sh [work_dir]

set -euo pipefail

# ---------------------------------------------------------------------------
# Emoji setup
# ---------------------------------------------------------------------------
readonly E_SUCCESS="✅"
readonly E_FAILURE="❌"
readonly E_WARN="⚠️"
readonly E_MEDAL="🎖️"
readonly E_WORKER="👤"
readonly E_CONFIG="⚙️"
readonly E_TASK="📋"
readonly E_EXP="📚"

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
work_dir="${1:-${MUFREZE_PROJECT:-$(pwd)}}"
work_dir="$(cd "$work_dir" && pwd)"

# ---------------------------------------------------------------------------
# Environment setup
# ---------------------------------------------------------------------------
MUFREZE_HOME="${MUFREZE_HOME:-$HOME/.mufreze}"
MUFREZE_CONFIG="${work_dir}/.mufreze/mufreze.json"
EXP_DIR="${work_dir}/.mufreze/exp"
TASKS_DIR="${work_dir}/.mufreze/tasks"
VERSION_FILE="${MUFREZE_HOME}/VERSION"

# ---------------------------------------------------------------------------
# Helper functions
# ---------------------------------------------------------------------------
msg() {
    echo "${E_MEDAL} MUFREZE: $1"
}

print_row() {
    printf "  %-20s %s\n" "$1" "$2"
}

print_separator() {
    echo "  ─────────────────────────────────────────"
}

# Check if a command exists in PATH
check_command() {
    command -v "$1" &>/dev/null && echo "${E_SUCCESS} Available" || echo "${E_FAILURE} Not found"
}

# Count files in directory (0 if doesn't exist)
count_files() {
    local dir="$1"
    if [[ -d "$dir" ]]; then
        find "$dir" -type f 2>/dev/null | wc -l | tr -d ' '
    else
        echo "0"
    fi
}

# ---------------------------------------------------------------------------
# Config oku
# ---------------------------------------------------------------------------
read_config() {
    local key="$1"
    local default="${2:-}"
    
    if [[ -f "$MUFREZE_CONFIG" ]]; then
        if command -v jq &>/dev/null; then
            jq -r "$key // \"\$default\"" "$MUFREZE_CONFIG" 2>/dev/null || echo "$default"
        else
            # Basit grep/sed fallback
            grep -o "\"$key\":\"[^\"]*\"" "$MUFREZE_CONFIG" 2>/dev/null | cut -d'"' -f4 || echo "$default"
        fi
    else
        echo "$default"
    fi
}

# ---------------------------------------------------------------------------
# Version detection
# ---------------------------------------------------------------------------
get_version() {
    if [[ -f "$VERSION_FILE" ]]; then
        cat "$VERSION_FILE"
    else
        echo "dev"
    fi
}

# ---------------------------------------------------------------------------
# Main output
# ---------------------------------------------------------------------------
main() {
    local version
    version=$(get_version)
    
    echo ""
    msg "Status Report"
    print_separator
    
    # MUFREZE Version
    print_row "Version:" "$version"
    
    # Work Directory
    print_row "Work Dir:" "$work_dir"
    
    # Check if config exists
    if [[ -f "$MUFREZE_CONFIG" ]]; then
        local mode
        mode=$(read_config ".mode" "delegation")
        print_row "Config:" "${E_SUCCESS} Found"
        print_row "Mode:" "$mode"
        
        # Workers
        echo ""
        echo "  ${E_WORKER} Worker Assignments:"
        if command -v jq &>/dev/null; then
            local coder reviewer tester architect
            coder=$(jq -r '.workers.coder // "-"' "$MUFREZE_CONFIG" 2>/dev/null)
            reviewer=$(jq -r '.workers.reviewer // "-"' "$MUFREZE_CONFIG" 2>/dev/null)
            tester=$(jq -r '.workers.tester // "-"' "$MUFREZE_CONFIG" 2>/dev/null)
            architect=$(jq -r '.workers.architect // "-"' "$MUFREZE_CONFIG" 2>/dev/null)
            print_row "  Coder:" "$coder"
            print_row "  Reviewer:" "$reviewer"
            print_row "  Tester:" "$tester"
            print_row "  Architect:" "$architect"
        else
            print_row "  Config:" "${E_WARN} Install jq for details"
        fi
    else
        print_row "Config:" "${E_FAILURE} Not found"
        print_row "Mode:" "-"
    fi
    
    # Worker Availability
    echo ""
    echo "  ${E_WORKER} Worker Availability:"
    print_row "  kimi:" "$(check_command kimi)"
    print_row "  codex:" "$(check_command codex)"
    
    # Project EXP Count
    echo ""
    local exp_count
    exp_count=$(count_files "$EXP_DIR")
    if [[ "$exp_count" -gt 0 ]]; then
        echo "  ${E_EXP} Experiences: $exp_count records"
    else
        echo "  ${E_EXP} Experiences: ${E_WARN} None"
    fi
    
    # Pending Tasks
    echo ""
    local task_count
    task_count=$(count_files "$TASKS_DIR")
    if [[ "$task_count" -gt 0 ]]; then
        echo "  ${E_TASK} Pending Tasks: $task_count task(s)"
        if [[ -d "$TASKS_DIR" ]]; then
            for task in "$TASKS_DIR"/*; do
                if [[ -f "$task" ]]; then
                    local task_name
                    task_name=$(basename "$task")
                    print_row "  -" "$task_name"
                fi
            done
        fi
    else
        echo "  ${E_TASK} Pending Tasks: ${E_SUCCESS} None"
    fi
    
    print_separator
    echo ""
    
    exit 0
}

main "$@"
