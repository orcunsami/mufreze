# EXP-0095: FastAPI: Depends() vs request.state Auth Anti-Pattern

| Field | Value |
|-------|-------|
| **ID** | EXP-0095 |
| **Date** | 2026-02-28 |
| **Project** | x-twitter |
| **Category** | Authentication/Backend |
| **Status** | SUCCESS |
| **Technologies** | FastAPI, Python, JWT, MongoDB |

## Problem Description

Certain API endpoints (e.g., `organizations.py` router) returned HTTP 401 or a `None` user on every request, even when a valid JWT token was provided in the `Authorization` header. All other endpoints using the standard auth dependency worked correctly with the same token. The issue was inconsistent — some routers authenticated users fine, others always failed — making the root cause non-obvious.

## Root Cause Analysis

A custom `get_current_user_id()` helper function was reading authentication data from `request.state.user_id` directly. `request.state` is a Starlette mechanism for passing data between middleware and route handlers. It only contains values that have been explicitly set by middleware on each request.

If no middleware sets `request.state.user_id`, accessing that attribute either raises `AttributeError` or returns `None`, causing the auth check to fail with 401 even for valid tokens.

The project had no such middleware — the auth logic lived entirely in `app.core.security.get_current_user` as a FastAPI dependency — so `request.state.user_id` was always empty.

**Wrong code — reads unset `request.state` attribute:**
```python
# routers/organizations.py - WRONG
from fastapi import Request, HTTPException, Depends

async def get_current_user_id(request: Request) -> str:
    # request.state.user_id is NEVER set (no middleware does this)
    user_id = getattr(request.state, "user_id", None)
    if not user_id:
        raise HTTPException(status_code=401, detail="Not authenticated")
    return user_id

@router.get("/organizations")
async def list_organizations(user_id: str = Depends(get_current_user_id)):
    # Always raises 401 — user_id is always None
    ...
```

**Why this pattern exists (and why it's wrong):**
Some frameworks (e.g., Django middleware, Express.js `req.user`) attach the authenticated user to the request object in middleware before the route handler runs. Developers familiar with those frameworks may attempt the same pattern in FastAPI. However, FastAPI's idiomatic approach is pure dependency injection via `Depends()` — no middleware required for auth.

**Correct code — use FastAPI's standard `Depends()` injection:**
```python
# routers/organizations.py - CORRECT
from fastapi import Depends, HTTPException
from app.core.security import get_current_user

@router.get("/organizations")
async def list_organizations(
    current_user: dict = Depends(get_current_user)
):
    user_id = str(current_user["_id"])
    # user_id is now reliably populated from the JWT token
    ...
```

**The correct `get_current_user` dependency in `app/core/security.py`:**
```python
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from jose import jwt, JWTError

security = HTTPBearer()

async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db=Depends(get_database)
) -> dict:
    token = credentials.credentials
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id = payload.get("sub")
        if user_id is None:
            raise HTTPException(status_code=401, detail="Invalid token")
    except JWTError:
        raise HTTPException(status_code=401, detail="Invalid token")

    user = await db.users.find_one({"_id": ObjectId(user_id)})
    if not user:
        raise HTTPException(status_code=401, detail="User not found")
    return user
```

## Solution

Replace all `request.state`-based auth patterns in route handlers with `Depends(get_current_user)` from `app.core.security`.

**Migration pattern:**
```python
# Before (WRONG):
async def endpoint(user_id: str = Depends(get_current_user_id)):
    ...

# After (CORRECT):
async def endpoint(current_user: dict = Depends(get_current_user)):
    user_id = str(current_user["_id"])
    ...
```

**Find all affected routes:**
```bash
# Search for request.state usage in auth context
grep -rn "request\.state" /usr/local/main/x-twitter/backend/app/routers/

# Search for any non-standard auth dependencies
grep -rn "get_current_user_id\|state\.user" /usr/local/main/x-twitter/backend/app/routers/
```

## Detection Methods

1. **Symptom:** Endpoint always returns 401 even with a valid JWT token that works on other endpoints.
2. **Comparison test:** If `/api/auth/me` (using `Depends(get_current_user)`) works but `/api/organizations` returns 401 with the same token — auth pattern mismatch confirmed.
3. **Code search:**
```bash
# Find routes using request.state for auth
grep -n "request\.state" backend/app/routers/*.py

# These should use Depends(get_current_user) instead
```
4. **curl diagnostic:**
```bash
TOKEN="eyJ..."
# This should work:
curl -H "Authorization: Bearer $TOKEN" http://localhost:8570/api/auth/me

# If this 401s but the above works → auth pattern mismatch
curl -H "Authorization: Bearer $TOKEN" http://localhost:8570/api/organizations
```

## Prevention Checklist

| Check | Action |
|-------|--------|
| New router created? | Always use `Depends(get_current_user)` from `app.core.security` |
| Copy-pasted from another framework? | Remove any `request.state.user` patterns |
| Auth inconsistency across routers? | Run `grep -rn "request.state" app/routers/` and fix |
| Code review | Flag any `request.state` usage in route handlers as a review blocker |
| `get_current_user` imported correctly? | Verify import path: `from app.core.security import get_current_user` |
| Optional auth routes | Use `Optional[dict] = Depends(get_current_user_optional)` pattern |

## Cross-Project Applicability

| Project | Stack | Applicability |
|---------|-------|---------------|
| x-twitter | FastAPI + JWT + MongoDB | ORIGINAL — issue found here |
| HocamClass | FastAPI + Vue.js 3 | HIGH — same FastAPI pattern |
| Any OST project | FastAPI | HIGH — universal FastAPI rule |
| TikTip | Laravel | NOT APPLICABLE — Laravel uses middleware differently |
| Express.js projects | Node.js | LOW — `req.user` via middleware IS correct in Express |

## Keywords

`fastapi`, `auth`, `depends`, `dependency-injection`, `request-state`, `jwt`, `401`, `middleware`, `security`, `get_current_user`, `HTTPBearer`, `unauthorized`, `bearer-token`, `starlette`

## Lessons Learned

1. FastAPI's dependency injection (`Depends()`) is the canonical and only reliable pattern for route-level authentication — do not use `request.state` for auth.
2. `request.state` in Starlette/FastAPI is middleware territory — route handlers should not read auth data from it unless a dedicated auth middleware explicitly sets it on every request.
3. When HTTP 401 appears on some endpoints but not others with the same token, always compare the auth dependency being used across routers — the inconsistency is almost always a different auth pattern.
4. Developers coming from Django, Express.js, or Flask may instinctively reach for request-attached user objects — FastAPI's `Depends()` is the idiomatic replacement for that pattern.
5. A single canonical `get_current_user` dependency in `app.core.security` should be the only auth entry point — do not create alternative helpers that bypass it.
6. For optional authentication (public endpoints that behave differently for logged-in users), create a separate `get_current_user_optional` that returns `None` instead of raising 401.

## See Also

- EXP-0079 (Anonymous session pattern in FastAPI — related auth context management)
- FastAPI Security docs: https://fastapi.tiangolo.com/tutorial/security/
- FastAPI Dependencies: https://fastapi.tiangolo.com/tutorial/dependencies/
- Starlette `request.state` docs: https://www.starlette.io/requests/#other-state
