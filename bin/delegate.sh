#!/usr/bin/env bash
# MUFREZE
# Core task delegation engine with retry + escalation logic
# Usage: delegate.sh <worker> <task_prompt> <work_dir> [max_retries]

set -euo pipefail

# ---------------------------------------------------------------------------
# Emoji constants
# ---------------------------------------------------------------------------
readonly E_SUCCESS="✅"
readonly E_FAILURE="❌"
readonly E_WARN="⚠️"
readonly E_MEDAL="🎖️"

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
worker="${1:-}"
task_prompt="${2:-}"
work_dir="${3:-}"
max_retries="${4:-5}"

if [[ -z "$worker" || -z "$task_prompt" || -z "$work_dir" ]]; then
    echo "${E_FAILURE} Usage: $0 <worker> <task_prompt> <work_dir> [max_retries]" >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Config loading (optional)
# ---------------------------------------------------------------------------
config_file="${work_dir}/.mufreze/mufreze.json"
escalate_chain=("kimi" "codex" "claude-sonnet" "claude-opus")
timeout_seconds=180

if [[ -f "$config_file" ]]; then
    # Read escalate_chain and timeout from config (falls back to grep if jq not installed)
    if command -v jq &>/dev/null; then
        chain_from_config=$(jq -r '.retry.escalate_chain // empty' "$config_file" 2>/dev/null)
        if [[ -n "$chain_from_config" && "$chain_from_config" != "null" ]]; then
            # Convert JSON array to bash array
            readarray -t escalate_chain < <(echo "$chain_from_config" | jq -r '.[]')
        fi
        timeout_from_config=$(jq -r '.retry.timeout_seconds // empty' "$config_file" 2>/dev/null)
        if [[ -n "$timeout_from_config" && "$timeout_from_config" != "null" ]]; then
            timeout_seconds="$timeout_from_config"
        fi
        retry_from_config=$(jq -r '.retry.max_attempts // empty' "$config_file" 2>/dev/null)
        if [[ -n "$retry_from_config" && "$retry_from_config" != "null" ]]; then
            max_retries="$retry_from_config"
        fi
    fi
fi

# ---------------------------------------------------------------------------
# Worker execution function
# Returns: exit code from worker
# ---------------------------------------------------------------------------
run_worker() {
    local w="$1"
    local prompt="$2"
    local dir="$3"

    case "$w" in
        kimi)
            kimi --yolo --print --final-message-only -w "$dir" -p "$prompt"
            ;;
        codex)
            codex exec --full-auto -C "$dir" "$prompt"
            ;;
        claude-sonnet|claude-sonnet-4-6)
            local llm_script
            llm_script="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/llm-route.py"
            "${MUFREZE_HOME:-$HOME/.mufreze}/.venv/bin/python3" "$llm_script" \
                "anthropic/claude-sonnet-4-6" \
                "You are a senior developer. Work in directory: $dir. Task: $prompt"
            ;;
        claude-opus|claude-opus-4-6)
            local llm_script
            llm_script="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/llm-route.py"
            "${MUFREZE_HOME:-$HOME/.mufreze}/.venv/bin/python3" "$llm_script" \
                "anthropic/claude-opus-4-6" \
                "You are a senior architect. Work in directory: $dir. Task: $prompt"
            ;;
        *)
            echo "${E_FAILURE} Unknown worker: $w" >&2
            return 1
            ;;
    esac
}

# ---------------------------------------------------------------------------
# Find next worker in escalation chain
# ---------------------------------------------------------------------------
get_next_worker() {
    local current="$1"
    local found=0

    for w in "${escalate_chain[@]}"; do
        if [[ $found -eq 1 ]]; then
            echo "$w"
            return 0
        fi
        # Normalize worker isimleri (claude-sonnet-4-6 -> claude-sonnet)
        normalized_current="${current//-4-6/}"
        normalized_w="${w//-4-6/}"
        if [[ "$normalized_current" == "$normalized_w" ]]; then
            found=1
        fi
    done

    return 1  # No more workers in chain
}

# ---------------------------------------------------------------------------
# Temp file for attempt log
# ---------------------------------------------------------------------------
attempt_log=$(mktemp)
trap "rm -f '$attempt_log'" EXIT

# ---------------------------------------------------------------------------
# Main retry + escalation loop
# ---------------------------------------------------------------------------
current_worker="$worker"
attempt_num=0
escalation_count=0
max_escalations=${#escalate_chain[@]}

while [[ $escalation_count -lt $max_escalations ]]; do
    retry_count=0

    while [[ $retry_count -lt $max_retries ]]; do
        attempt_num=$((attempt_num + 1))
        retry_count=$((retry_count + 1))
        timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

        echo "${E_MEDAL} MUFREZE: Attempt $attempt_num - Worker: $current_worker (retry $retry_count/$max_retries)" >&2

        # Run worker with timeout
        exit_code=0
        worker_output=""

        if worker_output=$(run_worker "$current_worker" "$task_prompt" "$work_dir" 2>&1); then
            exit_code=0
        else
            exit_code=$?
        fi

        # Log'a kaydet
        echo "---" >> "$attempt_log"
        echo "attempt_num: $attempt_num" >> "$attempt_log"
        echo "worker: $current_worker" >> "$attempt_log"
        echo "exit_code: $exit_code" >> "$attempt_log"
        echo "timestamp: $timestamp" >> "$attempt_log"
        echo "output: |" >> "$attempt_log"
        echo "$worker_output" | sed 's/^/  /' >> "$attempt_log"

        if [[ $exit_code -eq 0 ]]; then
            # Success
            echo "${E_SUCCESS} MUFREZE: Success on attempt $attempt_num with $current_worker" >&2

            # Write attempt log to stderr
            cat "$attempt_log" >&2

            # Call learn.sh if available
            if [[ -x "${MUFREZE_HOME:-.}/bin/learn.sh" ]]; then
                "${MUFREZE_HOME:-.}/bin/learn.sh" success "$attempt_log" "$work_dir" >&2 || true
            fi

            # Write result to stdout
            echo "$worker_output"
            exit 0
        fi

        echo "${E_WARN} MUFREZE: Failed with exit code $exit_code" >&2

        # Wait between retries (exponential backoff)
        if [[ $retry_count -lt $max_retries ]]; then
            sleep_time=$((2 ** (retry_count - 1)))
            echo "${E_MEDAL} MUFREZE: Retrying in ${sleep_time}s..." >&2
            sleep "$sleep_time"
        fi
    done

    # Retries bitti, sonraki worker'a escalate et
    next_worker=$(get_next_worker "$current_worker") || {
        echo "${E_FAILURE} MUFREZE: No more workers in escalation chain" >&2
        break
    }

    if [[ -z "$next_worker" ]]; then
        echo "${E_FAILURE} MUFREZE: Escalation chain exhausted" >&2
        break
    fi

    escalation_count=$((escalation_count + 1))
    echo "${E_MEDAL} MUFREZE: Escalating from $current_worker → $next_worker (escalation $escalation_count/$max_escalations)" >&2
    current_worker="$next_worker"
done

# ---------------------------------------------------------------------------
# Total failure - all workers exhausted
# ---------------------------------------------------------------------------
echo "${E_FAILURE} MUFREZE: All workers exhausted after $attempt_num attempts" >&2

# Write log to stderr
cat "$attempt_log" >&2

# Call learn.sh if available
if [[ -x "${MUFREZE_HOME:-.}/bin/learn.sh" ]]; then
    "${MUFREZE_HOME:-.}/bin/learn.sh" failure "$attempt_log" "$work_dir" >&2 || true
fi

exit 1
