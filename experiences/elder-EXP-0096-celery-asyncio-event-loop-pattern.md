# EXP-0096: Celery + AsyncIO — Event Loop Pattern

## Metadata
- **Date**: 2026-02-28
- **Project**: resmigazete (Resmi Gazete Bulten Platform)
- **Severity**: HIGH (async tasks crash silently or raise RuntimeError)
- **Category**: Celery, AsyncIO, FastAPI, Python
- **Status**: SOLVED

## Problem Statement
Celery tasks that call async functions fail with:
```
RuntimeError: no running event loop
```
or:
```
RuntimeError: This event loop is already running
```
Standard `asyncio.get_event_loop()` and `asyncio.run()` don't work reliably inside Celery workers.

## Root Cause
Celery workers are synchronous by nature — they run tasks in a thread pool without an event loop. When a Celery task calls `asyncio.get_event_loop()`, there's no loop running in that thread. When `asyncio.run()` is used, it creates a new loop, but if the worker happens to have a loop already (from previous tasks), it raises "already running".

## Solution

### The `_run_async()` Helper Pattern
```python
# app/content/tasks.py
import asyncio

def _run_async(coro):
    """Run async coroutine from sync Celery task context."""
    loop = asyncio.new_event_loop()   # ALWAYS create fresh loop
    try:
        return loop.run_until_complete(coro)
    finally:
        loop.close()  # Always clean up

# Usage in Celery task
@celery_app.task(name="scrape_daily_gazette")
def scrape_daily_gazette_task():
    result = _run_async(scrape_daily_index(today_str))
    return result

@celery_app.task(name="send_bulletin_emails")
def send_bulletin_emails_task():
    result = _run_async(send_all_bulletins())
    return result
```

### Why `new_event_loop()` Instead of `get_event_loop()`
| Method | Problem |
|--------|---------|
| `asyncio.get_event_loop()` | Returns None or raises in non-main thread |
| `asyncio.run()` | Fails if loop already running in thread |
| `asyncio.new_event_loop()` | Always creates fresh, isolated loop |

### With Motor (MongoDB) — Important!
If your async functions use Motor (MongoDB), the Motor client must be created INSIDE the `_run_async()` call, or use a connection pool that works across loops:

```python
async def scrape_and_store():
    # Motor operations work fine inside the loop created by _run_async()
    async with AsyncIOMotorClient(MONGODB_URL) as client:
        db = client[DB_NAME]
        await db.gazette_content.insert_one(doc)
```

### Full Celery Setup (crontab, not float intervals)
```python
# app/scheduler/celery_app.py
from celery import Celery
from celery.schedules import crontab

celery_app = Celery("resmigazete")

celery_app.conf.beat_schedule = {
    "scrape-daily": {
        "task": "scrape_daily_gazette",
        "schedule": crontab(hour=6, minute=0, tz="Europe/Istanbul"),
    },
    "send-bulletins": {
        "task": "send_bulletin_emails",
        "schedule": crontab(hour=7, minute=0, tz="Europe/Istanbul"),
    },
}

# WRONG: float interval (runs every N seconds, not at specific time)
# "schedule": 86400.0   # DON'T USE THIS
```

## Verification
```bash
# Test task manually
celery -A app.scheduler.celery_app call scrape_daily_gazette

# Check worker logs
celery -A app.scheduler.celery_app worker --loglevel=info
```

## Applicable To
- ALL FastAPI + Celery projects that mix async and sync code
- Django + Celery with async views
- Any Python project using asyncio inside thread pool workers

## Lessons Learned
1. **`asyncio.new_event_loop()` is the safe choice** in Celery — always fresh, always clean
2. **`asyncio.get_event_loop()` is deprecated in Python 3.10+** for non-main threads
3. **Use `crontab()` not float intervals** for time-based scheduling
4. **Close the loop in `finally`** to prevent resource leaks
5. **Motor clients can be created per-task** — connection overhead is minimal

## Related Experiences
- EXP-0095: MongoDB Motor async import trap (same project)
- EXP-0072: VPS Memory Crisis (zombie Celery workers)

## Tags
`celery` `asyncio` `fastapi` `python` `event-loop` `motor` `mongodb` `scheduler`
