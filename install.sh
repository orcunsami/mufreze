#!/usr/bin/env bash
# MUFREZE — One-line Installer
# Usage: curl -fsSL https://raw.githubusercontent.com/orcunsami/mufreze/main/install.sh | bash
#
# What this does:
# 1. Clones mufreze to ~/.mufreze
# 2. Creates symlinks in ~/.claude/ (skills, commands, agents, hooks)
# 3. Adds mufreze to PATH in ~/.zshrc or ~/.bashrc
# 4. Checks worker availability

set -euo pipefail

REPO_URL="https://github.com/orcunsami/mufreze.git"
INSTALL_DIR="${MUFREZE_HOME:-$HOME/.mufreze}"
CLAUDE_DIR="${CLAUDE_HOME:-$HOME/.claude}"

echo ""
echo "🎖️  MUFREZE Installer"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# --- Step 1: Clone or update ---
if [[ -d "$INSTALL_DIR/.git" ]]; then
    echo "📦 Updating existing installation..."
    git -C "$INSTALL_DIR" pull --quiet
else
    echo "📦 Installing to $INSTALL_DIR ..."
    git clone --quiet "$REPO_URL" "$INSTALL_DIR"
fi

# --- Step 2: Symlink into ~/.claude/ ---
echo "🔗 Linking to Claude Code..."

# Skills
mkdir -p "$CLAUDE_DIR/skills"
for skill_dir in "$INSTALL_DIR/skills"/*/; do
    skill_name=$(basename "$skill_dir")
    target="$CLAUDE_DIR/skills/mufreze-$skill_name"
    [[ -L "$target" ]] && rm "$target"
    ln -sf "$skill_dir" "$target"
    echo "   ✅ skills/mufreze-$skill_name"
done

# Commands
mkdir -p "$CLAUDE_DIR/commands"
for cmd_file in "$INSTALL_DIR/commands"/*.md; do
    cmd_name=$(basename "$cmd_file")
    target="$CLAUDE_DIR/commands/$cmd_name"
    [[ -L "$target" ]] && rm "$target"
    ln -sf "$cmd_file" "$target"
    echo "   ✅ commands/$cmd_name"
done

# Agents
mkdir -p "$CLAUDE_DIR/agents"
for agent_file in "$INSTALL_DIR/agents"/*.md; do
    agent_name=$(basename "$agent_file")
    target="$CLAUDE_DIR/agents/$agent_name"
    [[ -L "$target" ]] && rm "$target"
    ln -sf "$agent_file" "$target"
    echo "   ✅ agents/$agent_name"
done

# Global experiences dir
mkdir -p "$INSTALL_DIR/experiences"
mkdir -p "$HOME/.mufreze/experiences"

# --- Step 3: Add to PATH ---
echo ""
echo "🛣️  Adding mufreze to PATH..."

SHELL_RC=""
if [[ "$SHELL" == *"zsh"* ]]; then
    SHELL_RC="$HOME/.zshrc"
elif [[ "$SHELL" == *"bash"* ]]; then
    SHELL_RC="$HOME/.bashrc"
fi

if [[ -n "$SHELL_RC" ]]; then
    MUFREZE_PATH_LINE="export PATH=\"\$HOME/.mufreze/bin:\$PATH\""
    MUFREZE_HOME_LINE="export MUFREZE_HOME=\"$INSTALL_DIR\""

    if ! grep -q "MUFREZE_HOME" "$SHELL_RC" 2>/dev/null; then
        echo "" >> "$SHELL_RC"
        echo "# MUFREZE" >> "$SHELL_RC"
        echo "$MUFREZE_HOME_LINE" >> "$SHELL_RC"
        echo "$MUFREZE_PATH_LINE" >> "$SHELL_RC"
        echo "   ✅ Added to $SHELL_RC"
    else
        echo "   ⏭️  Already in $SHELL_RC"
    fi
fi

# --- Step 4: Worker check ---
echo ""
echo "🔍 Checking workers..."
command -v kimi &>/dev/null && echo "   ✅ kimi found" || echo "   ⚠️  kimi not found (install: pip install kimi-dev or see docs)"
command -v codex &>/dev/null && echo "   ✅ codex found" || echo "   ⚠️  codex not found (install: npm install -g @openai/codex)"

# --- Done ---
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎖️  MUFREZE installed successfully!"
echo ""
echo "Next steps:"
echo "  1. Restart your terminal (or: source $SHELL_RC)"
echo "  2. In your project: mufreze new-project /path/to/project"
echo "  3. Fill in docs/MUFREZE-BRIEFING.md"
echo "  4. Start delegating: mufreze delegate kimi 'task' /path/to/project"
echo ""
echo "Docs: https://github.com/orcunsami/mufreze"
echo ""
