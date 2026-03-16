---
id: EXP-008
project: global
worker: generic
category: resilience
tags: [retry, backoff, circuit-breaker, api, production]
outcome: success
date: 2026-02-28
---

## Problem
System fails immediately on first API error. No retry, no circuit breaker.

## Root Cause
Missing resilience patterns. Transient errors need retry; persistent failures need circuit breaker.

## Solution / Pattern
```python
def with_retry(max_retries=3, initial_delay=0.5):
    def decorator(func):
        @wraps(func)
        async def wrapper(*args, **kwargs):
            delay = initial_delay
            for attempt in range(max_retries + 1):
                try:
                    return await func(*args, **kwargs)
                except APIError:
                    if attempt == max_retries: raise
                    actual_delay = delay + (random.random() * delay * 0.1)  # jitter
                    await asyncio.sleep(min(actual_delay, 30.0))
                    delay = min(delay * 2, 30.0)
        return wrapper
    return decorator
```

## Prevention
Rule to add to BRIEFING.md:
```
- All external API calls MUST have retry with exponential backoff + jitter.
- Jitter is REQUIRED (prevents thundering herd).
- Circuit breaker wraps retry for persistent failures.
```
