# EXP-0099: Bun + PM2 Interpreter Configuration for Next.js

| Field | Value |
|-------|-------|
| **ID** | EXP-0099 |
| **Date** | 2026-02-28 |
| **Project** | x-twitter (XT-33) |
| **Category** | Build Tools/DevOps/Deployment |
| **Status** | SUCCESS |
| **Technologies** | Next.js 14, bun v1.3.9, PM2, VPS, TypeScript |

## Problem Description

After migrating from npm to bun for a Next.js project, PM2 fails to start the app. `pm2 start npm --name app -- start` (common pattern) doesn't work with bun. `npm run start` fails because npm is no longer the package manager.

## Root Cause Analysis

PM2's default pattern uses npm or node as the executor. When bun is the package manager, `bun.lockb` exists instead of `package-lock.json`, and `node_modules/.bin/` is managed by bun. The `npm start` command is no longer available.

PM2 also does not inherit the user's `$PATH` in the same way an interactive shell does, meaning `bun` on its own (without a full path) is not found even if `which bun` works in a terminal session.

## Solution

**Option A — PM2 ecosystem.config.js (recommended):**
```javascript
// ecosystem.config.js - CORRECT bun configuration
module.exports = {
  apps: [{
    name: "xtwitter-frontend",
    script: "node_modules/.bin/next",
    args: "start",
    interpreter: "/root/.bun/bin/bun",  // KEY: use bun as interpreter
    cwd: "/usr/local/main/x-twitter/frontend",
    env: {
      NODE_ENV: "production",
      PORT: "3570"
    }
  }]
}
```

**Option B — Direct PM2 start command:**
```bash
# Find bun path
which bun  # → /root/.bun/bin/bun

# Start with bun interpreter
pm2 start node_modules/.bin/next \
  --name xtwitter-frontend \
  --interpreter /root/.bun/bin/bun \
  -- start --port 3570
```

**Build with bun:**
```bash
# Install dependencies
bun install
# (delete package-lock.json if switching from npm, bun.lockb will be created)

# Build
bun run build
# NOT: npm run build

# Check bun path
ls -la /root/.bun/bin/bun
bun --version  # Should show 1.3.x or later
```

## Detection Methods

When PM2 shows "Online" but app doesn't respond, check logs:
```bash
pm2 logs xtwitter-frontend --lines 20
# Error: Cannot find module 'next'  → interpreter issue
# "bun: command not found"          → PATH issue for PM2
```

Also verify:
```bash
pm2 show xtwitter-frontend | grep interpreter
# Should show: /root/.bun/bin/bun
```

## Prevention Checklist

- [ ] After switching to bun: delete `package-lock.json`, run `bun install` (creates `bun.lockb`)
- [ ] Commit `bun.lockb` to repo, not `package-lock.json`
- [ ] In PM2 config: always use FULL PATH for interpreter (`/root/.bun/bin/bun`)
- [ ] Never mix `bun install` + `npm run build` (or vice versa)
- [ ] After `pm2 restart`, always verify with `curl http://localhost:PORT` not just `pm2 status`

## Cross-Project Applicability

Any Next.js project on VPS using bun as package manager. The same pattern applies to any runtime that PM2 doesn't natively know about (e.g., deno). The core rule: PM2 needs full absolute paths for non-default interpreters.

## Keywords

bun, pm2, nextjs, interpreter, npm-migration, vps, deployment, ecosystem-config, package-manager, next-start, process-manager, bun-lockb

## Lessons Learned

1. PM2 needs the FULL PATH to bun (`/root/.bun/bin/bun`), not just `bun` (PATH may not be set in PM2 environment)
2. Always use `bun install` and `bun run build` after migration — never mix bun + npm
3. `bun.lockb` should be committed, `package-lock.json` should be deleted after migration
4. Verify with `pm2 logs` — "Online" status doesn't mean app is working; always do an actual HTTP request

## See Also

- EXP-0098-python-venv-mac-to-vps-portability.md (same theme: runtime environment portability on VPS)
- x-twitter by-project INDEX: `/claude-memory/experiences/by-project/x-twitter/INDEX.md`
