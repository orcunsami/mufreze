---
id: EXP-013
project: global
worker: generic
category: devops
tags: [python, venv, deployment, portability, pm2]
outcome: failure
date: 2026-02-28
---

## Problem
Python venv created on Mac doesn't work on VPS. Shebangs hardcoded to `/Users/mac/...` paths.

## Root Cause
Python venv contains absolute hardcoded paths. Different OS → paths invalid.

## Solution / Pattern
NEVER commit venv. Always rebuild on server:

```bash
# On VPS deploy
rm -rf venv
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# PM2 with explicit interpreter
pm2 start app/main.py \
  --interpreter /usr/local/main/myproject/backend/venv/bin/python \
  -- --host 0.0.0.0 --port 8000
```

## Prevention
Rule to add to BRIEFING.md:
```
- venv is NEVER portable. Always in .gitignore.
- requirements.txt is single source of truth.
- PM2: always --interpreter /full/path/to/venv/bin/python (never rely on PATH).
- Deploy script MUST: rm -rf venv && python3 -m venv venv && pip install -r requirements.txt
```
