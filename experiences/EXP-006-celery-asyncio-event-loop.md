---
id: EXP-006
project: global
worker: generic
category: async
tags: [celery, asyncio, event-loop, fastapi]
outcome: failure
date: 2026-02-28
---

## Problem
Celery tasks calling async functions fail: `RuntimeError: no running event loop`.

## Root Cause
Celery workers are thread-based, not asyncio-based. `asyncio.run()` fails in Celery context.

## Solution / Pattern
Create fresh event loop per task:

```python
def _run_async(coro):
    loop = asyncio.new_event_loop()
    try:
        return loop.run_until_complete(coro)
    finally:
        loop.close()

@celery_app.task
def my_task():
    result = _run_async(my_async_function())
    return result
```

## Prevention
Rule to add to BRIEFING.md:
```
- Celery tasks: use asyncio.new_event_loop() + loop.run_until_complete(). Never asyncio.run() or asyncio.get_event_loop().
- Close loop in finally block.
```
