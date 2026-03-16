#!/bin/bash
# MUFREZE
# Learn script - creates EXP file from attempt outcome
# Usage: learn.sh <success|failure> <attempt_log> <work_dir>
# Exit: always 0 (learning should never break the flow)

set -euo pipefail

outcome="${1:-}"
attempt_log="${2:-}"
work_dir="${3:-}"

# Validate arguments
if [[ -z "$outcome" ]] || [[ -z "$work_dir" ]]; then
    echo "⚠️ Usage: learn.sh <success|failure> <attempt_log> <work_dir>"
    exit 0
fi

if [[ "$outcome" != "success" && "$outcome" != "failure" ]]; then
    echo "⚠️ Outcome must be 'success' or 'failure', got: $outcome"
    exit 0
fi

if [[ ! -d "$work_dir" ]]; then
    echo "⚠️ Directory not found: $work_dir"
    exit 0
fi

# Setup exp directory
exp_dir="$work_dir/.mufreze/exp"
mkdir -p "$exp_dir"

# Generate next EXP number
generate_exp_id() {
    local count=0
    
    if [[ -d "$exp_dir" ]]; then
        count=$(find "$exp_dir" -maxdepth 1 -name "EXP-*.md" | wc -l | tr -d ' ')
    fi
    
    local next=$((count + 1))
    printf "%03d" "$next"
}

# Get today's date
get_date() {
    date +%Y-%m-%d
}

# Generate summary from attempt log
generate_summary() {
    local log="$1"
    
    # Take first 10 lines, remove empty lines, format as bullet points
    echo "$log" | head -n 10 | sed '/^[[:space:]]*$/d' | sed 's/^/- /'
}

# Determine root cause based on outcome
generate_root_cause() {
    local outcome="$1"
    
    if [[ "$outcome" == "success" ]]; then
        echo "The approach worked as expected. The task was completed successfully."
    else
        echo "The attempt encountered errors or did not produce the expected result."
    fi
}

# Generate solution based on outcome
generate_solution() {
    local outcome="$1"
    
    if [[ "$outcome" == "success" ]]; then
        echo "- The current approach is working and should be used as a pattern"
        echo "- Document this success for future reference"
    else
        echo "- Analyze the error messages carefully"
        echo "- Consider breaking the task into smaller steps"
        echo "- May need to escalate or try a different approach"
    fi
}

# Generate prevention rule
generate_prevention() {
    local outcome="$1"
    
    if [[ "$outcome" == "success" ]]; then
        echo "- Follow the successful pattern documented in this EXP"
    else
        echo "- Add validation steps before attempting similar tasks"
        echo "- Consider adding more detailed error handling"
    fi
}

# Main
main() {
    local exp_id
    exp_id=$(generate_exp_id)
    
    local today
    today=$(get_date)
    
    local filename="EXP-${exp_id}-${today}.md"
    local filepath="$exp_dir/$filename"
    
    # Get project name from directory
    local project_name
    project_name=$(basename "$work_dir")
    
    # Build EXP content
    cat > "$filepath" << EOF
---
id: EXP-${exp_id}
project: ${project_name}
worker: kimi
category: verify
tags: []
outcome: ${outcome}
attempts: 1
date: ${today}
---

## Problem
Task execution attempt with outcome: ${outcome}

## What Happened
$(generate_summary "$attempt_log")

## Root Cause
$(generate_root_cause "$outcome")

## Solution / Pattern
$(generate_solution "$outcome")

## Prevention
$(generate_prevention "$outcome")
EOF

    echo "📚 EXP saved: .mufreze/exp/$filename"
    exit 0
}

main
