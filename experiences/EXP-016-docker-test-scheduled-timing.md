---
id: EXP-016
project: global
worker: generic
category: testing
tags: [docker, testing, timing, scheduled-events]
outcome: failure
date: 2026-01-03
---

## Problem
Docker test waits 7-8 minutes for scheduled event. Test time set far from current time.

## Root Cause
Scheduled event time set to 08:55 but current time is 10:30 → 7 minute wait.

## Solution / Pattern
Set test event time = current time + 2-5 minutes MAX:

```bash
# Get current time in correct timezone
TZ='Pacific/Auckland' date '+%H:%M'  # → 10:30

# Set test config to: daily_time = "10:33"
# Max acceptable test wait: 5-8 minutes
```

## Prevention
Rule to add to BRIEFING.md:
```
- Test scheduled time = current time + 5 minutes MAX.
- Always check current time before setting test scheduled time.
- If wait > 10 min → time calculation error, restart.
```
