---
id: EXP-007
project: global
worker: generic
category: configuration
tags: [runtime-config, defaults, production-values]
outcome: failure
date: 2026-02-28
---

## Problem
After PM2 restart, system reverts to development defaults. Batch size drops from 30 to 20, daemon count from 800 to 400.

## Root Cause
Code "default" values set to development minimums. On DB reset/restart, system falls back to these, not production values.

## Solution / Pattern
```python
# CORRECT: production values as defaults
PARAM_DEFS = {
    "rnd_backtest_batch": {"default": 30, "min": 5, "max": 100},
    "trading_max_daemons": {"default": 800, "min": 10, "max": 2000},
}
```

## Prevention
Rule to add to BRIEFING.md:
```
- "Default" value in code = production minimum, NOT development minimum.
- Test: drop config collection → restart → verify system at production capacity.
```
