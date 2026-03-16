---
name: mufreze-delegate
description: Delegate a coding task to a worker (Kimi/Codex/Claude) via MUFREZE
---

# /mufreze-delegate — Delegate Task to Worker

Use this command when you need to implement a feature, create a file, or write code.

## Steps

1. **Check project briefing**
   Read `docs/MUFREZE-BRIEFING.md` or `docs/KIMI-BRIEFING.md` for project conventions.

2. **Write atomic task spec**
   Task must be for exactly ONE file. Example:
   ```
   Create routers/users.py with a FastAPI router for user CRUD operations.
   Requirements:
   - GET /users → list all users
   - POST /users → create user
   - Use UserService from services/user_service.py
   - Async endpoints, return standard response format
   ```

3. **Delegate to worker**
   ```bash
   mufreze delegate kimi "Create routers/users.py with..." /path/to/project
   ```
   Or specify worker explicitly:
   ```bash
   mufreze delegate codex "task spec" /path/to/project
   ```

4. **Verify output**
   ```bash
   mufreze verify /path/to/project
   ```

5. **Wire the output** (Claude does this)
   Mount the new router/import the new component in the appropriate entry point.

6. **Commit**
   ```bash
   git add routers/users.py && git commit -m "feat: add users router"
   ```

## Worker Selection Guide

| Task Type | Worker | Why |
|-----------|--------|-----|
| New file, bulk implementation | kimi | Fastest, unlimited |
| Tests, structured output | codex | Better at formatted output |
| Complex logic, review | claude-sonnet | Higher quality |
| Architecture, critical path | claude-opus | Highest quality |

## Atomic Task Rule

**NEVER** delegate cross-file tasks. Wrong:
```
❌ Create users.py, update main.py, and add UserService to services/
```

Right:
```
✅ Create routers/users.py with FastAPI user CRUD router
```
Then separately:
```
✅ Create services/user_service.py with UserService class
```
Claude handles wiring between files.
