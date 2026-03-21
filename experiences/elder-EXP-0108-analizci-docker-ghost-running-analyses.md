# EXP-0094: Docker Restart → Ghost Running Analyses

**Date**: 2026-02-28
**Project**: Analizci (Video Analysis Platform)
**Severity**: HIGH
**Tags**: `docker`, `fastapi`, `threadpoolexecutor`, `mongodb`, `ghost-running`, `analizci`, `background-tasks`

## Problem

After Docker container restart, background analysis jobs appear to still be "running" in MongoDB but are actually dead. UI shows analyses stuck at partial progress (e.g., 25%) indefinitely with no error.

## Symptoms

1. Multiple analyses show status `"running"` in DB
2. UI shows progress stuck (25%, 40%, etc.) — never completes
3. No new progress updates in logs
4. Docker restart event happened before the stall

## Root Cause

```
Docker restart signal
        │
        ▼ SIGTERM sent to container
ThreadPoolExecutor threads KILLED immediately
        │
        ▼ No cleanup handler runs
MongoDB status stays as "running"
        │
        ▼ UI polls status → always "running"
        │
        ▼ User sees stuck progress forever
```

Key factor: `ThreadPoolExecutor(max_workers=1)` — only 1 analysis runs at a time, but when Docker restarts, the active thread is killed without updating MongoDB status.

## Detection

```bash
# Check for ghost analyses (running > 30 min = ghost)
docker exec analizci-mongodb mongosh \
  "mongodb://admin:changeme@localhost:27017/analiz_db?authSource=admin" \
  --quiet --eval '
  var cutoff = new Date(Date.now() - 30*60*1000);
  db.analyses.find({
    status: "running",
    updated_at: { $lt: cutoff }
  }, { _id: 1, created_at: 1, updated_at: 1 }).forEach(printjson);
  '

# Or check Docker logs for last update from a specific analysis
docker logs analizci-backend 2>&1 | grep "ANALYSIS_ID" | tail -5
```

## Fix (Immediate — MongoDB Direct Update)

```bash
docker exec analizci-mongodb mongosh \
  "mongodb://admin:changeme@localhost:27017/analiz_db?authSource=admin" \
  --quiet --eval '
  db.analyses.updateMany(
    { status: "running" },
    { $set: {
        status: "failed",
        error_message: "Backend yeniden başlatıldı - analiz yarıda kesildi",
        updated_at: new Date()
    }}
  );
  '
```

Then restart each analysis via API:
```bash
source /root/.claude/.env  # ANALIZCI_TOKEN
for ID in ANALYSIS_ID_1 ANALYSIS_ID_2; do
  curl -s -X POST "http://localhost:8200/api/analyses/$ID/restart" \
    -H "Authorization: Bearer $ANALIZCI_TOKEN"
done
```

## Fix (Permanent — App Startup Ghost Detection)

In `backend/app/main.py` startup event:

```python
@app.on_event("startup")
async def cleanup_ghost_analyses():
    """Kill analyses that were 'running' when backend restarted."""
    from datetime import datetime, timedelta
    cutoff = datetime.utcnow() - timedelta(minutes=30)
    result = await Analysis.find(
        Analysis.status == "running",
        Analysis.updated_at < cutoff
    ).update(
        Set({
            Analysis.status: "failed",
            Analysis.error_message: "Backend yeniden başlatıldı"
        })
    )
```

## Prevention

1. **Startup ghost detection**: On app start, mark any `status=running` + `updated_at > 30min ago` as `failed`
2. **Frontend "Yeniden Analiz Et" button**: Show restart button when status=`failed`, allows users to self-recover
3. **Graceful shutdown handler**: Listen for SIGTERM, update all running analyses to `interrupted` before exit
4. **ThreadPoolExecutor note**: `max_workers=1` means only 1 runs at a time, but ALL get killed on restart

## Related Files

- `analizci/backend/app/routers/analysis.py` — `_run_analysis_sync()`, `ThreadPoolExecutor`
- `analizci/frontend/src/app/analysis/[id]/page.tsx` — `handleRestart()`, "Yeniden Analiz Et" button

## Key Lesson

**Any background thread (ThreadPoolExecutor, asyncio.create_task, etc.) + Docker restart = potential ghost state.**

Always implement:
1. Startup cleanup (mark stale "running" as "failed")
2. User-facing restart button
3. Consider SIGTERM handler for graceful shutdown
