# EXP-0100: FastAPI Router Double Prefix Anti-Pattern (/api/api/...)

| Field | Value |
|-------|-------|
| **ID** | EXP-0100 |
| **Date** | 2026-02-28 |
| **Project** | x-twitter (infrastructure, also HocamClass EXP-0076) |
| **Category** | Backend/API Configuration |
| **Status** | SUCCESS |
| **Technologies** | FastAPI, Python, APIRouter |

## Problem Description

API endpoints return 404. Backend logs show requests hitting `/api/api/users/` or `/api/v1/api/v1/...`. The URL has a duplicated prefix segment. Frontend fetch calls that previously worked after copy-pasting from another project suddenly fail.

## Root Cause Analysis

`APIRouter` prefix is defined in TWO places simultaneously:
1. In the router file itself: `router = APIRouter(prefix="/api/users")`
2. In `main.py` when including: `app.include_router(users.router, prefix="/api")`

FastAPI concatenates these: `/api` + `/api/users/` = `/api/api/users/`

This is a recurring anti-pattern when teams copy router files between projects that use different conventions (one project has prefix in router, another has prefix in `include_router`).

## Solution

**Wrong — double prefix pattern:**
```python
# routers/users.py
router = APIRouter(prefix="/api/users", tags=["users"])
# Already has /api

# main.py
app.include_router(users.router, prefix="/api")
# Adds /api AGAIN → /api/api/users/
```

**Correct — x-twitter convention (router owns full prefix):**
```python
# routers/users.py
router = APIRouter(prefix="/api/users", tags=["users"])  # Router has full prefix

# main.py
app.include_router(users.router)  # NO extra prefix in include_router
```

**Correct — alternative convention (main.py owns prefix):**
```python
# routers/users.py
router = APIRouter(tags=["users"])  # No prefix in router

@router.get("/{username}")  # relative path
async def get_user_profile(...): ...

# main.py
app.include_router(users.router, prefix="/api/users")  # Prefix here only
```

Pick ONE convention for the entire project and enforce it consistently.

## Detection Methods

```bash
# Check OpenAPI spec for double prefix
curl http://localhost:8570/openapi.json | python3 -c "
import json, sys
paths = json.load(sys.stdin)['paths']
for p in sorted(paths.keys()):
    parts = p.split('/')
    if parts.count('api') > 1:
        print('DOUBLE PREFIX DETECTED:', p)
"

# Quick visual scan of all routes
curl http://localhost:8570/openapi.json | python3 -c "
import json, sys
[print(p) for p in sorted(json.load(sys.stdin)['paths'])]
" | grep -E "^/api/api"
```

If any path appears like `/api/api/...` or `/api/v1/api/v1/...`, the double-prefix bug is present.

## Prevention Checklist

- [ ] Establish ONE convention at project start: either router-owned prefix OR include_router-owned prefix
- [ ] Document the chosen convention in CLAUDE.md or a contributing guide
- [ ] When copying router files from another project, immediately check its prefix vs. main.py
- [ ] Add an automated check to CI: scan openapi.json for duplicate path segments
- [ ] When a new router is added, test `GET /openapi.json` and visually verify the path

## Cross-Project Applicability

This bug has appeared in: x-twitter, HocamClass (EXP-0076), and likely any project where router files are reused across codebases. The fix is always the same: pick one location for the prefix and remove the duplicate.

## Keywords

fastapi, router, prefix, double-prefix, include_router, 404, url, api, apiRouter, python, anti-pattern, url-routing, path-duplication

## Lessons Learned

1. When copying routers between projects, always audit the prefix definition locations
2. FastAPI silently concatenates prefixes — there is no warning when this creates duplicates
3. The OpenAPI spec (`/openapi.json` or `/docs`) is the fastest way to see actual registered paths
4. x-twitter convention: **router defines its own full prefix**, `include_router()` has no prefix argument

## See Also

- EXP-0076-hocamclass-api-url-double-prefix-bug.md (same root cause, Vue frontend)
- EXP-0055-urunlu-api-url-prefix-standardization.md (API URL standardization pattern)
- x-twitter by-project INDEX: `/claude-memory/experiences/by-project/x-twitter/INDEX.md`
