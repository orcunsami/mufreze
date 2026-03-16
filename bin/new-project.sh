#!/usr/bin/env bash
# MUFREZE
# Initialize a new MUFREZE project
# Usage: new-project.sh <work_dir>

set -euo pipefail

# ---------------------------------------------------------------------------
# Emoji setup
# ---------------------------------------------------------------------------
readonly E_SUCCESS="✅"
readonly E_FAILURE="❌"
readonly E_WARN="⚠️"
readonly E_MEDAL="🎖️"
readonly E_FOLDER="📁"
readonly E_FILE="📄"

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
work_dir="${1:-}"

if [[ -z "$work_dir" ]]; then
    echo "${E_FAILURE} Usage: $0 <work_dir>" >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Environment setup
# ---------------------------------------------------------------------------
MUFREZE_HOME="${MUFREZE_HOME:-$HOME/.mufreze}"
TEMPLATE_DIR="${MUFREZE_HOME}/templates"
CONFIG_DIR="${MUFREZE_HOME}/config"

DEFAULT_CONFIG="${CONFIG_DIR}/mufreze.default.json"
BRIEFING_TEMPLATE="${TEMPLATE_DIR}/BRIEFING.md"

# ---------------------------------------------------------------------------
# Helper functions
# ---------------------------------------------------------------------------
msg() {
    echo "${E_MEDAL} MUFREZE: $1"
}

ensure_dir() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir"
    fi
}

copy_file() {
    local src="$1"
    local dst="$2"
    if [[ -f "$src" ]]; then
        cp "$src" "$dst"
        return 0
    else
        return 1
    fi
}

# ---------------------------------------------------------------------------
# Main setup
# ---------------------------------------------------------------------------
main() {
    echo ""
    msg "Initializing new project..."
    echo ""
    
    # Work directory check
    if [[ ! -d "$work_dir" ]]; then
        msg "Creating work directory: $work_dir"
        mkdir -p "$work_dir"
    fi
    
    # Resolve to absolute path
    work_dir="$(cd "$work_dir" && pwd)"

    # MUFREZE_HOME check
    if [[ ! -d "$MUFREZE_HOME" ]]; then
        echo "${E_FAILURE} MUFREZE_HOME not found: $MUFREZE_HOME" >&2
        echo "       Please set MUFREZE_HOME environment variable or install MUFREZE." >&2
        exit 1
    fi
    
    local mufreze_dir="${work_dir}/.mufreze"
    local docs_dir="${work_dir}/docs"
    
    # .mufreze/ directory structure
    msg "Creating directory structure..."
    
    # Main .mufreze directory
    ensure_dir "$mufreze_dir"
    echo "  ${E_FOLDER} $mufreze_dir"
    
    # Create exp/ directory
    ensure_dir "${mufreze_dir}/exp"
    echo "  ${E_FOLDER} ${mufreze_dir}/exp/"
    
    # Create tasks/ directory
    ensure_dir "${mufreze_dir}/tasks"
    echo "  ${E_FOLDER} ${mufreze_dir}/tasks/"
    
    # Create docs/ directory
    ensure_dir "$docs_dir"
    
    echo ""
    msg "Copying configuration files..."
    
    # Copy mufreze.json config
    local config_dst="${mufreze_dir}/mufreze.json"
    if copy_file "$DEFAULT_CONFIG" "$config_dst"; then
        echo "  ${E_FILE} ${config_dst}"
    else
        echo "  ${E_WARN} Template not found: $DEFAULT_CONFIG"
        echo "  ${E_WARN} Creating empty config..."
        echo '{}' > "$config_dst"
        echo "  ${E_FILE} ${config_dst} (empty)"
    fi
    
    # Copy BRIEFING.md template
    local briefing_dst="${docs_dir}/MUFREZE-BRIEFING.md"
    if copy_file "$BRIEFING_TEMPLATE" "$briefing_dst"; then
        echo "  ${E_FILE} ${briefing_dst}"
    else
        echo "  ${E_WARN} Template not found: $BRIEFING_TEMPLATE"
    fi
    
    echo ""
    msg "Updating .gitignore..."
    
    # Update .gitignore
    local gitignore="${work_dir}/.gitignore"
    local gitignore_updated=false
    
    if [[ -f "$gitignore" ]]; then
        # Check if MUFREZE section already exists
        if ! grep -q "# MUFREZE" "$gitignore" 2>/dev/null; then
            echo "" >> "$gitignore"
            echo "# MUFREZE" >> "$gitignore"
            echo ".mufreze/exp/" >> "$gitignore"
            echo ".mufreze/mufreze.json" >> "$gitignore"
            gitignore_updated=true
        fi
    else
        echo "# MUFREZE" > "$gitignore"
        echo ".mufreze/exp/" >> "$gitignore"
        echo ".mufreze/mufreze.json" >> "$gitignore"
        gitignore_updated=true
    fi
    
    if [[ "$gitignore_updated" == true ]]; then
        echo "  ${E_FILE} ${gitignore}"
    else
        echo "  ${E_WARN} MUFREZE section already exists in .gitignore"
    fi
    
    # Setup summary
    echo ""
    msg "Setup Summary"
    echo "  ─────────────────────────────────────────"
    echo "  ${E_SUCCESS} Project initialized at: $work_dir"
    echo ""
    echo "  Created:"
    echo "    ${E_FOLDER} .mufreze/"
    echo "    ${E_FILE}   .mufreze/mufreze.json"
    echo "    ${E_FOLDER}   .mufreze/exp/"
    echo "    ${E_FOLDER}   .mufreze/tasks/"
    echo "    ${E_FILE}   docs/MUFREZE-BRIEFING.md"
    echo ""
    echo "  Next steps:"
    echo "    1. Edit docs/MUFREZE-BRIEFING.md with your project details"
    echo "    2. Run 'mufreze status' to verify setup"
    echo ""
    
    exit 0
}

main "$@"
