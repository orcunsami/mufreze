---
name: mufreze-delegate
description: Delegate coding tasks to workers (kimi, codex, claude-sonnet, claude-opus) using the MUFREZE CLI. Use when asked to create files, implement features, build components, or write code.
---

# MUFREZE Task Delegation

Use this skill when you need to delegate coding tasks to specialized workers via the MUFREZE CLI.

## When to Use This Skill

**Triggers:** Use delegation when user asks to:
- "Create file" / "Create component" / "Create module"
- "Implement" / "Implement feature" / "Implement endpoint"
- "Build" / "Build app" / "Build service"
- "Write code" / "Write function" / "Write API"

## When NOT to Use (Do Directly)

Do NOT delegate - handle directly instead:
- Small edits (< 20 lines)
- Configuration changes (json, yaml, toml updates)
- Renaming variables or simple refactoring
- Adding comments or documentation
- Deleting unused code
- Import/dependency adjustments

## Atomic Task Rule

**1 task = 1 file ONLY**

- NEVER create cross-file tasks in a single delegation
- If multiple files needed → split into sequential delegations
- Each task spec should target exactly ONE file path

## Step-by-Step Delegation Protocol

### 1. Read Project Briefing

Always read the project briefing first:
```bash
# Check for MUFREZE briefing
cat docs/MUFREZE-BRIEFING.md 2>/dev/null || cat docs/KIMI-BRIEFING.md 2>/dev/null
```

This ensures the worker understands:
- Tech stack and conventions
- Coding standards (e.g., `set -euo pipefail` for bash)
- Project-specific rules

### 2. Write Atomic Task Spec

Create a focused task specification:

```
Create /src/utils/validators.py with a single function:

def validate_email(email: str) -> bool:
    '''Validate email format using regex.'''
    
Requirements:
- Use Python 3.9+ type hints
- Import re module
- Return True if valid, False otherwise
- Handle None/empty input gracefully
```

**Task Spec Guidelines:**
- Specify ONE file path explicitly
- Include complete function/class signature
- List all imports needed
- Provide example usage if helpful
- Keep under 100 lines

### 3. Call Delegate Command

```bash
mufreze delegate <worker> '<task_spec>' /project/path
```

**Workers Available:**
- `kimi` - Fast, cost-effective (default for most tasks)
- `codex` - Good for complex logic
- `claude-sonnet` - Review and refinement
- `claude-opus` - Escalation only

**Examples:**
```bash
# Basic delegation to kimi
mufreze delegate kimi 'Create users.py with FastAPI User model' ./myproject

# Delegation with specific worker
mufreze delegate codex 'Implement JWT authentication middleware' ./api

# Delegation with full task spec (quote properly)
mufreze delegate kimi 'Create /src/api/routes.py with:
- GET /health endpoint returning {"status": "ok"}
- Use FastAPI Router
- Include proper imports' ./myproject
```

### 4. Wait for Output

- Delegation runs asynchronously
- Worker will create/modify the target file
- Output shows success/failure with file paths

### 5. Verify the Result

**ALWAYS verify after delegation:**
```bash
mufreze verify /project/path
```

This checks:
- Syntax errors (Python: `py_compile`, JS: `node --check`, TS: `tsc`)
- Type errors (TypeScript)
- Import resolution

### 6. Handle Failures

If verification fails:

**Option A - Retry with Error Context:**
```bash
mufreze delegate kimi 'Fix syntax error in validators.py: unexpected indent at line 23' ./project
```

**Option B - Escalate to Stronger Worker:**
```bash
mufreze delegate claude-opus 'Implement complex recursive parser with proper error handling' ./project
```

**Option C - Fix Directly (if small):**
- Make minimal edits yourself
- Then re-verify

## Complete Example

```bash
# 1. Read briefing
cat docs/KIMI-BRIEFING.md

# 2. Delegate task
mufreze delegate kimi 'Create /src/auth/jwt.py with:
- import jwt from PyJWT
- create_token(user_id: str) -> str (HS256, 24h expiry)
- verify_token(token: str) -> dict | None
- Handle exceptions gracefully' ./myproject

# 3. Verify result
mufreze verify ./myproject

# 4. If failed, retry with context
mufreze delegate kimi 'Fix jwt.py: PyJWT import should be "import jwt" not "from jwt import jwt"' ./myproject
```

## Worker Escalation Chain

If a worker fails, MUFREZE auto-escalates:
```
kimi → codex → claude-sonnet → claude-opus
```

Manual escalation: Use stronger worker for complex tasks.
