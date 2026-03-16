# MUFREZE — Developer Guide

## Architecture

MUFREZE is a Bash-first orchestration tool. No runtime dependencies beyond standard UNIX tools and your LLM CLIs.

```
bin/          Core CLI scripts (bash)
skills/       Claude Code skill definitions (markdown)
hooks/        Claude Code hook scripts
commands/     Claude Code command definitions (markdown)
agents/       Role definitions for the company system (markdown)
experiences/  Bundled EXP knowledge base (markdown)
templates/    Project scaffolding templates
config/       Default configuration (JSON)
```

## Building a New Feature

1. Write the shell script in `bin/`
2. Update `bin/mufreze.sh` router if adding a new subcommand
3. Add a corresponding `commands/*.md` if Claude should know about it
4. Test manually: `MUFREZE_HOME=$(pwd) bash bin/mufreze.sh <command>`

## Adding a Skill

Skills live in `skills/<name>/SKILL.md`. Format:
```markdown
---
name: mufreze-<name>
description: One-line trigger description
---

# Skill Title

## When to use
[triggers]

## Protocol
[steps]
```

## Adding to the EXP Library

EXPs in `experiences/` are bundled with MUFREZE and available to all users.

To add one, create `experiences/EXP-NNN-category-slug.md` following `templates/EXP.md`.

Only include EXPs that are:
- **Generic** (not project-specific)
- **Actionable** (has a clear Prevention rule)
- **Tested** (actually resolved a real issue)

## Testing

```bash
# Run mufreze help
MUFREZE_HOME=$(pwd) bash bin/mufreze.sh help

# Test new-project
MUFREZE_HOME=$(pwd) bash bin/mufreze.sh new-project /tmp/test-project

# Test status
MUFREZE_HOME=$(pwd) bash bin/mufreze.sh status /tmp/test-project
```

## Code Style

- `set -euo pipefail` at top of every script
- `UPPER_SNAKE_CASE` for env vars, `lower_snake_case` for locals
- All output prefixed with `🎖️ MUFREZE:`
- Exit codes: `0` = success, `1` = failure
- No hardcoded paths — everything via `MUFREZE_HOME` or arguments

## Submitting a PR

1. Fork the repo
2. Create a branch: `git checkout -b feat/your-feature`
3. Keep changes focused (one feature per PR)
4. Test manually before submitting
