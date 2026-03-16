---
name: mufreze-verify
description: Verify worker output before committing changes. Use after every delegate call to ensure code quality, syntax correctness, and type safety.
---

# MUFREZE Verification

Use this skill to verify worker output before committing changes to the codebase.

## When to Run Verify

**MANDATORY:** Run verify after EVERY `mufreze delegate` call:

```bash
# Pattern: delegate then verify
mufreze delegate kimi 'Create user model' ./project
mufreze verify ./project  # ← ALWAYS do this
```

**Also run verify when:**
- Any file is modified by a worker
- Before committing changes
- Before marking a task as complete

## How to Run Verify

```bash
mufreze verify <project_path>
```

**Example:**
```bash
mufreze verify /Users/me/projects/myapp
mufreze verify .  # current directory
mufreze verify "$MUFREZE_PROJECT"  # using env var
```

## What Verify Checks

Verify automatically detects project type and runs appropriate checks:

### Python Projects
- **Syntax:** `python -m py_compile <file>` for all `.py` files
- **Detection:** `pyproject.toml`, `requirements.txt`, `setup.py`, `setup.cfg`

### TypeScript Projects
- **Types:** `npx tsc --noEmit`
- **Detection:** `tsconfig.json`

### JavaScript Projects
- **Syntax:** `node --check <file>` for all `.js` files
- **Detection:** `package.json` (without `tsconfig.json`)

### Unknown Projects
- Warning shown, no verification performed
- Checks for: `requirements.txt/pyproject.toml`, `tsconfig.json`, `package.json`

## Reading Verify Output

### Success Output
```
🎖️ MUFREZE: Starting verification in /project/path
🔍 Detected Python project
📄 Checking: src/models.py
📄 Checking: src/routes.py
✅ All files verified
```

Exit code: `0`

### Failure Output
```
🎖️ MUFREZE: Starting verification in /project/path
🔍 Detected Python project
📄 Checking: src/models.py
❌ Syntax error in: src/models.py
  File "src/models.py", line 23
    def validate(self
                    ^
SyntaxError: unexpected EOF while parsing
❌ Verification failed
```

Exit code: `1`

### No Files to Check
```
🎖️ MUFREZE: Starting verification in /project/path
🔍 Detected Python project
⚠️ No Python files to verify
```

## On Verify Fail: Fix Strategy

When verification fails, choose ONE of these strategies:

### Strategy 1: Retry Delegate with Error Context (Recommended)

Pass the specific error to the worker:

```bash
mufreze delegate kimi 'Fix syntax error in src/models.py line 23: 
unexpected EOF while parsing in def validate(self' ./project
```

**Best for:** Syntax errors, import errors, type mismatches

### Strategy 2: Minimal Direct Fix

Make small fixes yourself if:
- Error is trivial (missing colon, indent issue)
- You can fix in < 5 lines
- The fix is obvious

```bash
# Edit file directly, then re-verify
mufreze verify ./project
```

**Best for:** Typos, missing brackets, obvious syntax issues

### Strategy 3: Escalate to Stronger Worker

If the task is complex and kimi/codex keeps failing:

```bash
mufreze delegate claude-opus 'Implement complex parser with proper error handling. Previous attempts had syntax issues.' ./project
```

**Best for:** Complex logic, algorithmic tasks, edge cases

## Commit Only After Verify Passes

**NEVER commit before verification passes.**

```bash
# ✅ CORRECT workflow:
mufreze delegate kimi 'Create API endpoint' ./project
mufreze verify ./project
# ↑ Only proceed if this returns 0
git add .
git commit -m "Add API endpoint"

# ❌ WRONG - never skip verify:
mufreze delegate kimi 'Create API endpoint' ./project
git add .  # Don't commit yet!
git commit -m "Add API endpoint"
```

## Complete Verification Workflow

```bash
# 1. Delegate task
mufreze delegate kimi 'Create auth middleware' ./myproject

# 2. Verify output
mufreze verify ./myproject

# 3. Handle result
if [ $? -eq 0 ]; then
    echo "✅ Ready to commit"
    git add .
    git commit -m "Add auth middleware"
else
    echo "❌ Fix required"
    mufreze delegate kimi 'Fix syntax in auth/middleware.py' ./myproject
    mufreze verify ./myproject
fi
```
