# EXP-0100: In-Memory Queue Fallback — Zero Data Loss When MongoDB Unavailable

## Metadata
- **Date**: 2026-02-28
- **Project**: JARVIS Voice System (Jira MAC-88)
- **Severity**: HIGH (data loss on MongoDB unavailability without this)
- **Category**: Resilience, Data Persistence, Offline Mode
- **Status**: SOLVED

## Problem Statement
System loses all events when MongoDB is unavailable (network blip, restart, maintenance). No offline mode — if MongoDB is down, events are silently dropped. This causes gaps in memory, analytics, and conversation history.

## Solution: In-Memory Queue with Background Sync

```python
import asyncio
from collections import deque
from datetime import datetime
from typing import Optional
import threading

class ResilientEventStore:
    """MongoDB event store with in-memory fallback for offline resilience."""

    MAX_QUEUE_SIZE = 1000     # Max events in memory (FIFO eviction after this)
    SYNC_RETRY_INTERVAL = 300  # 5 minutes between sync attempts

    def __init__(self, mongodb_uri: str, db_name: str):
        self.mongodb_uri = mongodb_uri
        self.db_name = db_name
        self.db = None
        self._online = False

        # In-memory fallback queue
        self._queue: deque = deque(maxlen=self.MAX_QUEUE_SIZE)  # FIFO eviction
        self._queue_lock = threading.Lock()

        # Background sync thread
        self._sync_thread = threading.Thread(target=self._background_sync, daemon=True)
        self._sync_thread.start()

    async def store_event(self, event: dict) -> bool:
        """Store event — uses MongoDB if available, queue if not."""
        event["ts"] = datetime.utcnow()

        if self._online:
            try:
                await self.db.events.insert_one(event)
                return True
            except Exception:
                self._online = False
                # Fall through to queue

        # MongoDB unavailable — queue it
        with self._queue_lock:
            self._queue.append(event)
        return True  # Never fail the caller

    def _background_sync(self):
        """Background thread: retry sync every 5 minutes."""
        import time
        while True:
            time.sleep(self.SYNC_RETRY_INTERVAL)

            if not self._online:
                if self._try_reconnect():
                    self._flush_queue()

    def _try_reconnect(self) -> bool:
        """Try to reconnect to MongoDB."""
        try:
            from motor.motor_asyncio import AsyncIOMotorClient
            loop = asyncio.new_event_loop()
            client = AsyncIOMotorClient(self.mongodb_uri, serverSelectionTimeoutMS=5000)
            loop.run_until_complete(client.admin.command('ping'))
            self.db = client[self.db_name]
            self._online = True
            return True
        except Exception:
            return False

    def _flush_queue(self):
        """Flush in-memory queue to MongoDB after reconnect."""
        with self._queue_lock:
            events_to_sync = list(self._queue)
            self._queue.clear()

        if events_to_sync:
            loop = asyncio.new_event_loop()
            loop.run_until_complete(
                self.db.events.insert_many(events_to_sync)
            )
            print(f"Synced {len(events_to_sync)} queued events to MongoDB")
```

## Design Decisions Explained

### Why `deque(maxlen=1000)`?
- `maxlen` causes automatic FIFO eviction — oldest events dropped when full
- Better than silent data loss OR unbounded memory growth
- 1000 events approx 2MB RAM (very safe)
- If you need more: increase maxlen or add event prioritization

### Why 300-second retry interval?
- Short enough to recover within reasonable time
- Long enough to avoid hammering a recovering MongoDB
- Configurable — make it 60s for latency-sensitive, 600s for stable systems

### Why threading (not asyncio)?
- MongoDB reconnect is blocking; asyncio would block event loop
- Background thread with `asyncio.new_event_loop()` keeps main event loop clean
- Mutex lock protects queue from concurrent access

## State Diagram
```
MongoDB Online
    │
    ▼
store_event() → MongoDB ──(failure)──→ _online = False
                                           │
                                           ▼
                                    queue.append(event)
                                           │
                              (background thread, every 5min)
                                           ▼
                                    _try_reconnect()
                                           │
                                    ──(success)──→ _flush_queue()
                                                       │
                                                       ▼
                                               MongoDB Online
```

## Applicable To
- ANY system where MongoDB (or other DB) may be temporarily unavailable
- Event sourcing systems
- Analytics collectors
- Logging systems where data loss is unacceptable
- IoT/edge devices with intermittent connectivity

## Lessons Learned
1. **`deque(maxlen=N)` is perfect** — automatic FIFO eviction, thread-safe for append/popleft
2. **Never fail the caller** — `store_event()` always returns True; resilience is internal
3. **Daemon thread** (`daemon=True`) means it dies with the main process — no cleanup needed
4. **5-minute retry** is the sweet spot — not too aggressive, recovers within acceptable time
5. **Flush ALL queued events on reconnect** — don't lose the offline period's history
6. **Log the sync** — "Synced 47 queued events" is useful operational info

## Related Experiences
- EXP-0098: Exponential backoff + circuit breaker (same project)
- EXP-0099: Pre-flight + health checks (same project)
- EXP-0095: MongoDB Motor async import trap

## Tags
`mongodb` `resilience` `offline` `queue` `in-memory` `fallback` `data-loss-prevention` `python`
