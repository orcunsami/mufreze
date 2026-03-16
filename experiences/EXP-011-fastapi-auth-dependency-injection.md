---
id: EXP-011
project: global
worker: generic
category: backend
tags: [fastapi, auth, dependency-injection, jwt]
outcome: failure
date: 2026-02-28
---

## Problem
Certain FastAPI endpoints return 401 with valid JWT. Some routers use `request.state.user_id`, others use `Depends(get_current_user)`.

## Root Cause
Different auth patterns across routers. `request.state` is never populated if no middleware sets it.

## Solution / Pattern
Single canonical `Depends(get_current_user)` for all endpoints:

```python
async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(HTTPBearer())
) -> dict:
    payload = jwt.decode(credentials.credentials, SECRET_KEY, algorithms=[ALGORITHM])
    user = await db.users.find_one({"_id": ObjectId(payload["sub"])})
    if not user: raise HTTPException(status_code=401)
    return user

@router.get("/data")
async def get_data(current_user: dict = Depends(get_current_user)):
    ...
```

## Prevention
Rule to add to BRIEFING.md:
```
- FastAPI auth = Depends(get_current_user) ONLY, never request.state.user_id.
- Single get_current_user in app/core/security.py (one entry point).
- Flag any request.state usage in route handlers as blocker.
```
