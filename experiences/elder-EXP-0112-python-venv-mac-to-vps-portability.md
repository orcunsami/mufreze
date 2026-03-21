# EXP-0098: Python Venv Mac → VPS: Portability Issue (Hardcoded Shebang Paths)

| Field | Value |
|-------|-------|
| **ID** | EXP-0098 |
| **Date** | 2026-02-28 |
| **Project** | x-twitter (cross-project applicable) |
| **Category** | DevOps/Python/Deployment |
| **Status** | SUCCESS |
| **Technologies** | Python, pip, venv, VPS, PM2, FastAPI, Linux, macOS |

## Problem Description

After `git push` from Mac and `git pull` on VPS, Python commands fail. Symptoms vary:
- `pip install` throws "interpreter not found" errors
- `uvicorn` is not found even though `requirements.txt` shows it installed
- Scripts fail with `/Users/mac/...` path errors
- PM2 process for FastAPI backend starts then immediately crashes

The venv was created on Mac with `python3 -m venv venv` and committed to git (or copied directly). The VPS is Linux — a different OS and architecture entirely.

## Root Cause Analysis

Python `venv` contains absolute paths hardcoded into its activation scripts and binary shebang lines. When created on Mac:

```bash
# Mac venv/bin/pip shebang (standard Mac Python):
#!/Users/mac/Documents/work/x-twitter/backend/venv/bin/python3

# Mac venv/bin/pip shebang (Homebrew Mac):
#!/opt/homebrew/opt/python@3.12/bin/python3.12

# Mac venv/bin/uvicorn shebang:
#!/Users/mac/Documents/work/x-twitter/backend/venv/bin/python3
```

These paths do not exist on the VPS (Linux). Every `pip`, `uvicorn`, or any other venv command tries to use the Mac Python path and fails immediately.

**Detection:**
```bash
# Quick check — if output contains /Users/ or /opt/homebrew/ → Mac venv
head -1 venv/bin/pip

# Or check uvicorn
head -1 venv/bin/uvicorn

# Check all scripts at once
grep -l "^#!/Users\|^#!/opt/homebrew" venv/bin/*
```

## Solution

**On VPS: destroy and rebuild the venv from scratch.**

```bash
cd /usr/local/main/x-twitter/backend

# 1. Remove the Mac venv completely
rm -rf venv

# 2. Create a fresh venv using the VPS Python
python3 -m venv venv

# 3. Activate and install all packages from requirements.txt
source venv/bin/activate
pip install -r requirements.txt

# 4. Verify shebang is now VPS path (not Mac)
head -1 venv/bin/pip
# Expected: #!/usr/local/main/x-twitter/backend/venv/bin/python3
```

**PM2 Deployment — always specify venv interpreter explicitly:**
```bash
# WRONG: System Python or ambiguous interpreter
pm2 start app/main.py --name xtwitter-backend

# CORRECT: Explicitly point to venv's Python binary
pm2 start app/main.py \
  --name xtwitter-backend \
  --interpreter /usr/local/main/x-twitter/backend/venv/bin/python \
  -- --host 0.0.0.0 --port 8570

# Or in ecosystem.config.js:
module.exports = {
  apps: [{
    name: "xtwitter-backend",
    script: "app/main.py",
    interpreter: "/usr/local/main/x-twitter/backend/venv/bin/python",
    args: "--host 0.0.0.0 --port 8570",
    cwd: "/usr/local/main/x-twitter/backend"
  }]
};
```

**Correct `.gitignore` — venv must NEVER be committed:**
```gitignore
# Python
venv/
.venv/
env/
__pycache__/
*.pyc
*.pyo
*.pyd
.Python
*.egg-info/
dist/
build/
```

## Detection Methods

```bash
# Method 1: Check shebang of pip binary
head -1 /path/to/project/backend/venv/bin/pip
# BAD:  #!/Users/mac/...  or  #!/opt/homebrew/...
# GOOD: #!/path/on/vps/venv/bin/python3

# Method 2: Check if venv is even in git (it shouldn't be)
git ls-files | grep "^venv/"
# Any output → venv is committed → problem

# Method 3: Try running pip and check for error
source venv/bin/activate && pip --version
# If error includes Mac path → rebuild venv

# Method 4: Check PM2 crash logs
pm2 logs xtwitter-backend --lines 50
# Look for "No such file or directory" with Mac paths
```

## Prevention Checklist

- [ ] `venv/` is in `.gitignore` — verify before first commit on any project
- [ ] `requirements.txt` is always up to date (`pip freeze > requirements.txt` after installs)
- [ ] On new server setup: always run `rm -rf venv && python3 -m venv venv && pip install -r requirements.txt`
- [ ] PM2 config: always use `--interpreter /absolute/path/to/venv/bin/python`
- [ ] Deployment script (`deploy.sh`) should include venv rebuild step
- [ ] Never `scp` or `rsync` a venv from one machine to another

**Deployment script template:**
```bash
#!/bin/bash
# deploy-backend.sh
set -e

PROJECT_DIR="/usr/local/main/x-twitter/backend"
cd "$PROJECT_DIR"

git pull origin master

# Always rebuild venv on deploy
rm -rf venv
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

pm2 restart xtwitter-backend
echo "Backend deployed successfully"
```

## Cross-Project Applicability

| Project | Risk | Action |
|---------|------|--------|
| x-twitter | Fixed (VPS rebuilt) | Include venv rebuild in deploy script |
| HocamClass (FastAPI) | HIGH if venv ever committed | Check .gitignore, verify on VPS |
| Any FastAPI project | HIGH on first VPS deploy | Always rebuild venv on server |
| Any Python project | HIGH | Universal rule: venv is not portable |

## Keywords

python, venv, pip, shebang, mac, vps, linux, portability, pm2, interpreter, requirements, fastapi, uvicorn, homebrew, deploy, gitignore

## Lessons Learned

1. `venv` is machine-specific — it belongs in `.gitignore`, never in git, never copied between machines
2. `requirements.txt` is the single source of truth — venv is always derived from it
3. Always detect stale venv with `head -1 venv/bin/pip` before assuming the venv is healthy after a server move
4. PM2 with Python: always specify `--interpreter` pointing to the absolute venv Python path — never rely on PATH
5. The deployment script should include `rm -rf venv && python3 -m venv venv && pip install -r requirements.txt` as a standard step, not optional

## See Also

- EXP-0096: Nginx + FastAPI Double CORS Header Problem
- EXP-0097: External API Key Unavailable → Graceful Degradation Pattern
- MEMORY.md: "Venv Mac'te oluşturulmuş, VPS'e taşınamaz" (Backend Sorunları bölümü)
