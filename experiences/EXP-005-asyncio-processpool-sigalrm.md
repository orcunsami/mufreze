---
id: EXP-005
project: global
worker: generic
category: async
tags: [asyncio, subprocess, timeout, zombie-process, sigalrm]
outcome: failure
date: 2026-02-28
---

## Problem
ProcessPoolExecutor workers accumulate as zombie processes. `asyncio.wait_for(timeout=360)` cancels the Future but the OS subprocess keeps running.

## Root Cause
asyncio operates at Python level; cannot kill OS subprocesses blocked in C extensions (numpy, etc.).

## Solution / Pattern
Use `signal.SIGALRM` in the worker, set 30 seconds before asyncio timeout:

```python
import signal

_WORKER_TIMEOUT = max(30, ASYNCIO_TIMEOUT - 30)

def _alarm_handler(signum, frame):
    raise TimeoutError(f"Worker timeout after {_WORKER_TIMEOUT}s")

# In worker:
signal.signal(signal.SIGALRM, _alarm_handler)
signal.alarm(_WORKER_TIMEOUT)
# ... work ...
signal.alarm(0)  # cancel on success
```

## Prevention
Rule to add to BRIEFING.md:
```
- asyncio.wait_for() + ProcessPoolExecutor ALWAYS requires SIGALRM guard in worker.
- SIGALRM timeout = asyncio timeout - 30 seconds.
- Wrap in try/except for Windows (no SIGALRM support).
```
