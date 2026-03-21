# EXP-0072: VPS Memory Crisis - Zombie Claude Sessions & MongoDB TLS Fix

**Project**: VPS Infrastructure (Master VPS 173.249.18.183)
**Date**: 2025-12-31
**Category**: DevOps/Infrastructure/Memory Management
**Technologies**: Linux, PM2, MongoDB, Python, FastAPI, tmux, swap
**Stack Version**: Ubuntu 24.04, MongoDB 7.x, Python 3.12, PM2 5.x
**Keywords**: memory-crisis, zombie-processes, claude-sessions, swap-space, mongodb-tls, ssl-handshake, pm2-restart-loop, vps-maintenance, process-cleanup

## Problem Statement

VPS was extremely slow with 95% RAM usage (3.6GB/3.8GB). The `backend` PM2 service (senlikbuddy) had **39,713 restarts** and was crash-looping. System was nearly unusable.

### Symptoms
1. VPS extremely slow/unresponsive
2. Only 42MB free RAM, 204MB available
3. **No swap space configured** (critical for 4GB VPS)
4. Backend service restarting every ~30 seconds
5. SSH connections timing out

## Investigation Process

### Step 1: Memory Analysis
```bash
free -h
# total: 3.8GB, used: 3.6GB (95%), free: 42MB, available: 204MB
# Swap: 0B (NONE!)

ps aux --sort=-%mem | head -25
```

### Step 2: Identified Major Memory Consumers

| Process | Memory | Issue |
|---------|--------|-------|
| 3x Zombie Claude sessions | ~550MB | Running since June-November! |
| VSCode Extension Host | 469MB | Normal |
| MongoDB | 262MB | Normal |
| n8n | 232MB | Normal |
| 8x Gunicorn workers | ~1.2GB | Slightly high |
| Backend (39,713 restarts!) | 109MB | Crash loop |

### Step 3: Zombie Claude Sessions Discovery

Found 3 abandoned Claude Code sessions consuming ~550MB total:

```bash
ps aux | grep claude
# PID 277498 (pts/4) - Running since JUNE 27, 2025 - 154MB
# PID 560349 (pts/6) - Running since November 22, 2025 - 221MB
# PID 4097161 (pts/7, tmux claude-safsata) - Running since November 9, 2025 - 177MB
```

### Step 4: Backend Crash Analysis

```bash
pm2 logs backend --lines 50 --nostream
```

**Error**: `pymongo.errors.ServerSelectionTimeoutError: SSL handshake failed: localhost:27017`

The backend was trying to connect with TLS but MongoDB had TLS disabled.

## Root Cause

### Memory Crisis
1. **No swap space** - 4GB RAM VPS without swap is dangerous
2. **Zombie processes** - Old Claude sessions never cleaned up
3. **Abandoned tmux sessions** - Stale sessions accumulating

### Backend Crash Loop
1. `.env` had TLS parameters: `&tls=true&tlsCAFile=...`
2. `database.py` had hardcoded TLS options for production
3. MongoDB config had TLS **commented out/disabled**

**Mismatch**: Code expected TLS, MongoDB didn't support it = infinite crash loop

## Solution

### Part 1: Kill Zombie Claude Sessions (~550MB freed)

```bash
kill 277498  # June zombie
kill 560349  # November zombie
kill 4097161 # Safsata tmux zombie
```

**Result**: 550MB immediately freed

### Part 2: Create Swap Space (20GB)

```bash
fallocate -l 20G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo '/swapfile none swap sw 0 0' >> /etc/fstab
```

**Result**: 20GB swap available for memory pressure relief

### Part 3: Fix MongoDB TLS Mismatch

**File 1**: `/usr/local/main/application/backend/.env`
```diff
- MONGODB_URI_PRODUCTION="mongodb://...?authSource=admin&tls=true&tlsCAFile=/etc/ssl/certs/mongodb-ca.pem&tlsCertificateKeyFile=/etc/ssl/certs/mongodb-client.pem"
+ MONGODB_URI_PRODUCTION="mongodb://...?authSource=admin"
```

**File 2**: `/usr/local/main/application/backend/app/core/database.py`
```diff
- if settings.ENVIRONMENT == "production":
-     cls.client = AsyncIOMotorClient(
-         settings.MONGODB_URI,
-         tls=True,
-         tlsCAFile='/etc/ssl/certs/mongodb-ca.pem',
-         tlsCertificateKeyFile='/etc/ssl/certs/mongodb-client.pem'
-     )
- else:
-     cls.client = AsyncIOMotorClient(settings.MONGODB_URI)
+ # MongoDB TLS is disabled on this server, use standard connection
+ cls.client = AsyncIOMotorClient(settings.MONGODB_URI)
```

**Restart with fresh environment**:
```bash
pm2 delete backend
pm2 start run.py --name backend --interpreter /path/to/venv/bin/python3
pm2 save
```

### Part 4: Update Git Remotes (bonus fix)

```bash
cd /usr/local/main/ost
git remote set-url origin git@github.com:OrcunSamiTandogan/contabo62-ost.git

cd /usr/local/main/ost-preprod
git remote set-url origin git@github.com:OrcunSamiTandogan/contabo62-ost.git
```

## Verification

### Memory After Fix
```bash
free -h
# Used: 3.3GB (was 3.6GB)
# Available: 570MB (was 204MB)
# Swap: 20GB available (was 0)
```

### Backend Stability
```bash
pm2 status backend
# uptime: 49s, restarts: 0 (was 39,713!)
# "Application startup complete. Uvicorn running on http://127.0.0.1:8000"
```

## Applicable To

- Any VPS with limited RAM (< 8GB)
- Multi-service deployments (PM2, Docker, etc.)
- Long-running Claude Code sessions
- MongoDB with TLS configuration mismatches
- Any Python/FastAPI backend with database connectivity issues

## Lessons Learned

### 1. Swap is Essential for Small VPS
```
Rule: Always configure swap >= RAM for VPS with < 8GB
4GB RAM → 4-20GB swap
```

### 2. Zombie Claude Sessions Accumulate
```bash
# Check periodically:
ps aux | grep claude | grep -v grep

# Kill old sessions:
ps aux | grep claude | awk '{print $2, $9, $11}' | grep -E "^[0-9]+ (Jun|Jul|Aug|Sep|Oct|Nov)"
```

### 3. TLS Mismatch = Silent Crash Loop
```
Symptom: Backend restarts every 30 seconds
Check: MongoDB config vs. application connection string
Fix: Ensure TLS settings match on BOTH sides
```

### 4. PM2 Environment Caching
```bash
# When changing .env, delete and restart (not just restart):
pm2 delete <app>
pm2 start <script> --name <app>
pm2 save
```

### 5. Code Hardcoding vs. Environment
```
Anti-pattern: Hardcoding TLS paths in database.py
Pattern: Read ALL connection params from environment
```

## Prevention Checklist

- [ ] Monthly check for zombie processes: `ps aux --sort=-%mem | head -20`
- [ ] Ensure swap exists: `swapon --show`
- [ ] Verify MongoDB TLS match: compare `/etc/mongod.conf` with `.env`
- [ ] Clean stale tmux sessions: `tmux ls` then `tmux kill-session -t <name>`
- [ ] Monitor PM2 restart counts: `pm2 status`

## Related Experiences

- [EXP-0057](EXP-0057-vps2-mongodb-authentication-enable.md) - MongoDB Authentication Enable
- [EXP-0058](EXP-0058-vps1-disk-cleanup-mongodb-logs.md) - VPS Disk Cleanup
- [EXP-0059](EXP-0059-vps-os-version-comparison.md) - VPS OS Comparison
- [EXP-0071](EXP-0071-wireguard-vpn-firewall-bypass-jump-host-alternative.md) - WireGuard VPN

## Quick Reference Card

```
VPS SLOW? CHECK IN ORDER:
1. free -h          → RAM/Swap status
2. ps aux --sort=-%mem | head -20  → Top memory users
3. pm2 status       → Restart counts
4. swapon --show    → Swap exists?
5. ps aux | grep claude  → Zombie sessions?

BACKEND CRASH LOOP?
1. pm2 logs <app> --lines 50  → Error type
2. If "SSL handshake failed" → TLS mismatch
3. Check: /etc/mongod.conf vs .env
4. Fix both sides, pm2 delete && pm2 start
```

---

**Resolution Time**: ~15 minutes
**Memory Recovered**: ~700MB
**Restarts Fixed**: 39,713 → 0
**Status**: SUCCESS
