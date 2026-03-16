---
id: EXP-009
project: global
worker: generic
category: resilience
tags: [offline, mongodb, queue, data-loss-prevention]
outcome: success
date: 2026-02-28
---

## Problem
System loses all events when MongoDB is temporarily unavailable. Events silently dropped.

## Root Cause
No resilience layer between application and database. Single point of failure.

## Solution / Pattern
In-memory deque queue with background sync thread:

```python
from collections import deque

class ResilientEventStore:
    def __init__(self):
        self._queue = deque(maxlen=1000)  # FIFO eviction
        self._online = False

    async def store_event(self, event: dict) -> bool:
        if self._online:
            try:
                await self.db.events.insert_one(event)
                return True
            except Exception:
                self._online = False
        self._queue.append(event)  # Never fail the caller
        return True
```

## Prevention
Rule to add to BRIEFING.md:
```
- Any persistent write operation needs a fallback queue.
- deque(maxlen=N) provides automatic FIFO eviction when full.
- Background thread retries DB reconnection every 5 minutes.
```
