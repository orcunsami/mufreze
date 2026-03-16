---
id: EXP-020
project: global
worker: generic
category: configuration
tags: [config-ini, version, centralization, single-source-of-truth]
outcome: failure
date: 2026-02-28
---

## Problem
All parameters hardcoded. Version defined in 3+ files (config.py, setup.py, README.md) that diverge.

## Root Cause
No centralized config system. Each module defines its own constants.

## Solution / Pattern
```ini
# config.ini (project root, commit to git)
[api]
MAX_RETRIES = 3
TIMEOUT = 30

[db]
TTL_DAYS = 30
```

```python
# version.py — single source
from pathlib import Path
VERSION = (Path(__file__).parent / "VERSION").read_text().strip()
```

**What goes where:**
- Secrets (API keys) → `.env` (never commit)
- Tunable parameters → `config.ini` (commit)
- Version → `VERSION` file (single source)
- Fixed constants → Python code

## Prevention
Rule to add to BRIEFING.md:
```
- Tunable parameters → config.ini, NEVER hardcoded in Python.
- Version → single VERSION file, read by all modules.
- Secrets → .env only (gitignored).
- Never define version in multiple places.
```
