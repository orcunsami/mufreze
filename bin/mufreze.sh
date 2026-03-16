#!/usr/bin/env bash
# MUFREZE — Main CLI Router
# Routes subcommands to corresponding bin/ scripts

set -euo pipefail

# --- Environment Setup ---
MUFREZE_HOME="${MUFREZE_HOME:-$HOME/.mufreze}"
# Resolve symlink to find actual bin dir
_SELF="${BASH_SOURCE[0]}"
while [[ -L "$_SELF" ]]; do _SELF="$(readlink "$_SELF")"; done
SCRIPT_DIR="$(cd "$(dirname "$_SELF")" && pwd)"
VERSION_FILE="$MUFREZE_HOME/VERSION"

# --- Version Detection ---
get_version() {
    if [[ -f "$VERSION_FILE" ]]; then
        cat "$VERSION_FILE"
    else
        echo "dev"
    fi
}

VERSION=$(get_version)

# --- Output Helpers ---
msg() {
    echo "🎖️ MUFREZE: $1"
}

error() {
    echo "🎖️ MUFREZE: ❌ $1" >&2
}

# --- Usage Help ---
show_help() {
    cat << 'EOF'
🎖️ MUFREZE — Claude Code Plugin + CLI Orchestration Tool

USAGE:
    mufreze <subcommand> [args...]

SUBCOMMANDS:
    delegate <worker> <prompt> <path>
        Delegate a task to a worker (kimi, codex, claude-sonnet, claude-opus)
        Example: mufreze delegate kimi 'Create users.py with FastAPI router' /path/to/project

    verify <path>
        Verify a completed task in the specified project directory
        Example: mufreze verify /path/to/project

    status
        Show status of current project and pending tasks
        Example: mufreze status

    learn <outcome> <exp-id> <path>
        Learn from success or failure, create EXP record
        Example: mufreze learn success EXP-001 /path/to/project
        Example: mufreze learn failure EXP-002 /path/to/project

    new-project <path>
        Initialize a new MUFREZE project
        Example: mufreze new-project /path/to/project

    help
        Show this help message
        Example: mufreze help

ENVIRONMENT:
    MUFREZE_HOME    MUFREZE installation directory (default: ~/.mufreze)
    MUFREZE_PROJECT Current project directory

VERSION:
EOF
    echo "    $VERSION"
    echo ""
}

# --- Subcommand Router ---
route_subcommand() {
    local cmd="${1:-}"
    shift || true

    case "$cmd" in
        delegate)
            if [[ $# -lt 3 ]]; then
                error "Usage: mufreze delegate <worker> <prompt> <path>"
                exit 1
            fi
            exec "$SCRIPT_DIR/delegate.sh" "$@"
            ;;
        verify)
            if [[ $# -lt 1 ]]; then
                error "Usage: mufreze verify <path>"
                exit 1
            fi
            exec "$SCRIPT_DIR/verify.sh" "$@"
            ;;
        status)
            exec "$SCRIPT_DIR/status.sh" "$@"
            ;;
        learn)
            if [[ $# -lt 3 ]]; then
                error "Usage: mufreze learn <outcome> <exp-id> <path>"
                exit 1
            fi
            exec "$SCRIPT_DIR/learn.sh" "$@"
            ;;
        new-project)
            if [[ $# -lt 1 ]]; then
                error "Usage: mufreze new-project <path>"
                exit 1
            fi
            exec "$SCRIPT_DIR/new-project.sh" "$@"
            ;;
        help|--help|-h|"")
            show_help
            exit 0
            ;;
        *)
            error "Unknown subcommand: $cmd"
            msg "Run 'mufreze help' for usage information"
            exit 1
            ;;
    esac
}

# --- Main Entry ---
main() {
    route_subcommand "$@"
}

main "$@"
