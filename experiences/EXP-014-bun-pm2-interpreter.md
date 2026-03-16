---
id: EXP-014
project: global
worker: generic
category: devops
tags: [bun, nextjs, pm2, package-manager, interpreter]
outcome: failure
date: 2026-02-28
---

## Problem
After migrating from npm to bun, PM2 shows "Online" but app doesn't respond.

## Root Cause
PM2 config still uses npm. Bun needs full path explicit interpreter.

## Solution / Pattern
```bash
# Find bun
which bun  # → /root/.bun/bin/bun

# PM2 with bun interpreter (FULL PATH required)
pm2 start node_modules/.bin/next \
  --name myapp \
  --interpreter /root/.bun/bin/bun \
  -- start --port 3000
```

**Migration checklist:**
```bash
bun install           # Create bun.lockb
rm package-lock.json  # Delete npm lock
bun run build         # Build with bun
pm2 restart myapp     # Test
curl http://localhost:3000  # Verify (Online ≠ working)
```

## Prevention
Rule to add to BRIEFING.md:
```
- After bun migration: delete package-lock.json, run bun install, commit bun.lockb.
- PM2 interpreter: ALWAYS use FULL PATH (/root/.bun/bin/bun), never just `bun`.
- pm2 status "Online" ≠ app working; always curl localhost:PORT.
```
