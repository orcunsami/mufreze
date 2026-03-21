# EXP-0098: Exponential Backoff + Circuit Breaker — Production Resilience

## Metadata
- **Date**: 2026-02-28
- **Project**: JARVIS Voice System (Jira MAC-84, MAC-85)
- **Severity**: HIGH (without this, single API failure crashes entire system)
- **Category**: Resilience, Error Handling, Production Patterns
- **Status**: SOLVED

## Problem Statement
Multi-service system (Gemini + Groq + OpenAI + Claude Code + TABUR) fails immediately on first error with no retry. Single quota exceeded or network hiccup causes complete system failure. Services that fail repeatedly keep getting called, wasting quota and time.

## Solution

### Exponential Backoff with Jitter (MAC-84)
```python
import asyncio
import random
from functools import wraps

def with_retry(max_retries=3, initial_delay=0.5, max_delay=30.0, jitter=True):
    """Decorator: exponential backoff with jitter for API calls."""
    def decorator(func):
        @wraps(func)
        async def wrapper(*args, **kwargs):
            delay = initial_delay
            for attempt in range(max_retries + 1):
                try:
                    return await func(*args, **kwargs)
                except (RateLimitError, APIError, NetworkError) as e:
                    if attempt == max_retries:
                        raise  # Final attempt failed

                    # Jitter prevents thundering herd
                    actual_delay = delay + (random.random() * delay * 0.1 if jitter else 0)
                    actual_delay = min(actual_delay, max_delay)

                    await asyncio.sleep(actual_delay)
                    delay = min(delay * 2, max_delay)  # Exponential growth
        return wrapper
    return decorator

# Usage
@with_retry(max_retries=3, initial_delay=0.5, max_delay=30.0)
async def call_gemini(prompt: str) -> str:
    return await gemini_client.generate(prompt)
```

### Circuit Breaker Pattern (MAC-85)
```python
from enum import Enum
from datetime import datetime, timedelta

class CircuitState(Enum):
    CLOSED = "closed"      # Normal operation
    OPEN = "open"          # Failing, reject all calls
    HALF_OPEN = "half_open"  # Testing if service recovered

class CircuitBreaker:
    def __init__(self, failure_threshold=5, recovery_timeout=60):
        self.state = CircuitState.CLOSED
        self.failure_count = 0
        self.failure_threshold = failure_threshold   # 5 consecutive failures → OPEN
        self.recovery_timeout = recovery_timeout     # 60 seconds before HALF_OPEN
        self.last_failure_time = None
        self.fallback = None  # Optional fallback function

    async def call(self, func, *args, **kwargs):
        if self.state == CircuitState.OPEN:
            # Check if recovery timeout has passed
            if datetime.now() - self.last_failure_time > timedelta(seconds=self.recovery_timeout):
                self.state = CircuitState.HALF_OPEN
            elif self.fallback:
                return await self.fallback(*args, **kwargs)
            else:
                raise ServiceUnavailableError("Circuit OPEN — service unavailable")

        try:
            result = await func(*args, **kwargs)
            # Success — reset if we were testing
            if self.state == CircuitState.HALF_OPEN:
                self.state = CircuitState.CLOSED
                self.failure_count = 0
            return result

        except Exception as e:
            self.failure_count += 1
            self.last_failure_time = datetime.now()

            if self.failure_count >= self.failure_threshold:
                self.state = CircuitState.OPEN

            raise

# Usage
gemini_breaker = CircuitBreaker(failure_threshold=5, recovery_timeout=60)
gemini_breaker.fallback = call_openai_fallback  # Auto-degrade to OpenAI

async def call_ai(prompt):
    return await gemini_breaker.call(call_gemini, prompt)
```

### Combined Usage (Retry + Circuit Breaker)
```python
# Order matters: Circuit Breaker WRAPS Retry
# Retry handles transient errors, Circuit Breaker handles persistent failures

async def call_with_resilience(prompt):
    try:
        # Circuit breaker checks state first
        return await gemini_breaker.call(
            call_gemini_with_retry,  # Retry handles transient
            prompt
        )
    except ServiceUnavailableError:
        # Circuit is open, use fallback
        return await call_openai_fallback(prompt)
```

## State Transitions
```
CLOSED ──(5 consecutive failures)──→ OPEN
  ↑                                    │
  └──(success in HALF_OPEN)──←────────┘
                              ↑
                    (60 seconds pass)
```

## Tuning Parameters
| Parameter | Default | Adjust When |
|-----------|---------|-------------|
| `initial_delay` | 0.5s | API has fast recovery → lower; slow API → higher |
| `max_delay` | 30s | Acceptable user wait → adjust UX requirements |
| `max_retries` | 3 | Low quota API → reduce; high quota → increase |
| `failure_threshold` | 5 | Hair-trigger failover → lower; tolerant → higher |
| `recovery_timeout` | 60s | Fast service recovery → lower |

## Applicable To
- ANY multi-service system with external API calls
- Gemini, OpenAI, Groq, Twitter API, Instagram API
- Database connections, Redis, MongoDB
- Internal microservice calls

## Lessons Learned
1. **Jitter is NOT optional** — without it, all retries hammer the API simultaneously (thundering herd)
2. **Circuit Breaker protects quota** — don't keep calling a failed service and burning rate limits
3. **Order matters**: CB wraps retry (CB checks state first, retry handles transient errors)
4. **HALF_OPEN is critical** — without it, circuit stays OPEN forever even after service recovers
5. **Always have a fallback** registered on circuit breaker for graceful degradation

## Related Experiences
- EXP-0099: Pre-flight checks + health checks (same project)
- EXP-0100: In-memory queue fallback (same project)
- EXP-0101: Multi-provider AI fallback (Gemini → OpenAI)

## Tags
`resilience` `retry` `circuit-breaker` `backoff` `production` `api` `python` `async`
