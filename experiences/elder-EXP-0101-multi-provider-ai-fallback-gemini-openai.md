# EXP-0101: Multi-Provider AI Fallback — Gemini 2.0 Flash → OpenAI GPT-4o-mini

## Metadata
- **Date**: 2026-02-28
- **Project**: JARVIS Voice System (Jira MAC-79)
- **Severity**: HIGH (single provider = single point of failure)
- **Category**: AI Integration, Resilience, Production
- **Status**: SOLVED

## Problem Statement
JARVIS used Gemini 1.5 Flash as sole AI router. When Gemini quota exceeded (free tier: 15 req/min), entire system failed. No fallback, no degradation — complete outage until quota reset.

## Solution: Primary + Fallback Provider Pattern

```python
import asyncio
from enum import Enum

class AIProvider(Enum):
    GEMINI = "gemini"
    OPENAI = "openai"

class MultiProviderAI:
    """AI client with automatic provider fallback."""

    # Free tier: Gemini allows ~15 req/min → 4 second interval
    GEMINI_RATE_LIMIT_INTERVAL = 4.0

    def __init__(self, gemini_key: str, openai_key: str):
        import google.generativeai as genai
        from openai import AsyncOpenAI

        genai.configure(api_key=gemini_key)
        self.gemini = genai.GenerativeModel("gemini-2.0-flash")
        self.openai = AsyncOpenAI(api_key=openai_key)

        self._last_gemini_call = 0.0
        self._active_provider = AIProvider.GEMINI

    async def generate(self, prompt: str, system: str = None) -> str:
        """Generate with automatic fallback: Gemini first, OpenAI if quota exceeded."""

        # Rate limiting for Gemini free tier
        await self._enforce_rate_limit()

        try:
            return await self._call_gemini(prompt, system)

        except Exception as e:
            error_str = str(e).lower()

            if "quota" in error_str or "rate" in error_str or "429" in error_str:
                # Quota exceeded → try OpenAI fallback
                print(f"Gemini quota exceeded, falling back to OpenAI")
                self._active_provider = AIProvider.OPENAI
                return await self._call_openai(prompt, system)
            else:
                raise  # Different error, don't hide it

    async def _enforce_rate_limit(self):
        """Enforce 4-second interval between Gemini calls (free tier)."""
        if self._active_provider == AIProvider.GEMINI:
            elapsed = asyncio.get_event_loop().time() - self._last_gemini_call
            if elapsed < self.GEMINI_RATE_LIMIT_INTERVAL:
                await asyncio.sleep(self.GEMINI_RATE_LIMIT_INTERVAL - elapsed)
            self._last_gemini_call = asyncio.get_event_loop().time()

    async def _call_gemini(self, prompt: str, system: str = None) -> str:
        full_prompt = f"{system}\n\n{prompt}" if system else prompt
        response = await asyncio.to_thread(self.gemini.generate_content, full_prompt)
        return response.text

    async def _call_openai(self, prompt: str, system: str = None) -> str:
        messages = []
        if system:
            messages.append({"role": "system", "content": system})
        messages.append({"role": "user", "content": prompt})

        response = await self.openai.chat.completions.create(
            model="gpt-4o-mini",  # Cheap + fast fallback
            messages=messages
        )
        return response.choices[0].message.content
```

## Why Gemini 2.0 Flash?
- 40% faster than Gemini 1.5 Flash
- Better instruction following
- Free tier: 15 requests/minute → 4-second interval
- Upgrade to Gemini 1.5 Pro for complex routing

## Provider Comparison
| Provider | Model | Cost | Speed | Quota |
|----------|-------|------|-------|-------|
| Gemini | 2.0 Flash | Free (15/min) | Fastest | Low |
| OpenAI | GPT-4o-mini | $0.15/1M tokens | Fast | High |
| Groq | llama-3.1-8b | Free (6000/min) | Fastest | Medium |

## Three-Provider Chain (Advanced)
```python
async def generate_with_chain(prompt):
    for provider in [call_gemini, call_groq, call_openai]:
        try:
            return await provider(prompt)
        except QuotaError:
            continue  # Try next
    raise AllProvidersFailedError()
```

## Applicable To
- Any system using AI APIs with quota limits
- Multi-model routing (smart + fast + cheap)
- Production AI systems requiring 99%+ uptime

## Lessons Learned
1. **Free tier rate limits are tight** — always implement rate limiting proactively
2. **Fallback != same model** — use cheaper/faster fallback (GPT-4o-mini, not GPT-4)
3. **Log provider switches** — operational visibility into quota issues
4. **4-second interval** is the safe floor for Gemini free tier
5. **Quota errors != hard errors** — distinguish 429/quota from real failures

## Related Experiences
- EXP-0098: Exponential backoff + circuit breaker (backoff for quota errors)
- EXP-0099: Pre-flight checks (provider availability)

## Tags
`ai` `gemini` `openai` `fallback` `quota` `rate-limit` `production` `multi-provider`
