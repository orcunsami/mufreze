# EXP-0096: Nginx + FastAPI: Double CORS Header Problem

| Field | Value |
|-------|-------|
| **ID** | EXP-0096 |
| **Date** | 2026-02-28 |
| **Project** | x-twitter (infrastructure) |
| **Category** | DevOps/CORS/API |
| **Status** | SUCCESS |
| **Technologies** | nginx, FastAPI, Python, CORSMiddleware |

## Problem Description

Browser throws: `The 'Access-Control-Allow-Origin' header contains multiple values 'http://x.orcunsamitandogan.com, *', but only one is allowed`. CORS preflight requests fail. Frontend cannot call backend despite both nginx and FastAPI appearing to be configured correctly for CORS.

## Root Cause Analysis

Both nginx AND FastAPI CORSMiddleware were adding CORS headers independently. When a request came in:

1. nginx added: `Access-Control-Allow-Origin: *`
2. FastAPI CORSMiddleware added: `Access-Control-Allow-Origin: http://x.orcunsamitandogan.com`

Result: Two values in the same header → browser rejects it with a hard CORS block.

**Wrong nginx config:**
```nginx
server {
    location /api/ {
        # WRONG: nginx adds its own CORS headers while FastAPI also adds them
        add_header 'Access-Control-Allow-Origin' '*' always;
        add_header 'Access-Control-Allow-Methods' 'GET, POST, PUT, DELETE, OPTIONS' always;
        add_header 'Access-Control-Allow-Headers' 'Content-Type, Authorization' always;

        proxy_pass http://localhost:8570;
    }
}
```

## Solution

**Rule:** Choose ONE layer to handle CORS. For FastAPI projects, let FastAPI handle it. nginx only needs to handle OPTIONS preflight for performance.

**Correct nginx config (no CORS headers — only OPTIONS handled):**
```nginx
server {
    location /api/ {
        # Handle OPTIONS preflight — return 204 before hitting proxy
        if ($request_method = 'OPTIONS') {
            add_header 'Access-Control-Allow-Origin' $http_origin;
            add_header 'Access-Control-Allow-Methods' 'GET, POST, PUT, DELETE, OPTIONS';
            add_header 'Access-Control-Allow-Headers' 'Content-Type, Authorization';
            add_header 'Access-Control-Max-Age' 86400;
            return 204;
        }

        # Real CORS headers → FastAPI CORSMiddleware handles these
        proxy_pass http://localhost:8570;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

**FastAPI CORSMiddleware (keep this, remove CORS from nginx):**
```python
from fastapi.middleware.cors import CORSMiddleware

app.add_middleware(
    CORSMiddleware,
    allow_origins=["https://x.orcunsamitandogan.com", "http://localhost:3570"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
```

## Detection Methods

```bash
# Check for double CORS header in response
curl -sv -H "Origin: http://localhost:3570" http://localhost:8570/api/health 2>&1 | grep -i "access-control"
# If you see two Access-Control-Allow-Origin lines → double header problem

# Check nginx config for CORS headers
grep -n "add_header.*Access-Control" /etc/nginx/sites-available/x-twitter

# Check browser DevTools → Network → failing request → Response Headers
# Look for duplicate Access-Control-Allow-Origin entries
```

## Prevention Checklist

- [ ] Never add `add_header 'Access-Control-Allow-Origin'` in nginx when FastAPI CORSMiddleware is active
- [ ] Choose ONE CORS layer: nginx OR application middleware, never both
- [ ] For FastAPI: use CORSMiddleware, handle OPTIONS in nginx only for performance
- [ ] After nginx config changes, always `nginx -t` then test with curl before frontend
- [ ] Test CORS with: `curl -sv -H "Origin: ..." URL 2>&1 | grep -i access-control`

## Cross-Project Applicability

| Project | Risk | Action |
|---------|------|--------|
| x-twitter | Fixed | Monitor on next nginx config change |
| Any FastAPI + nginx project | HIGH | Audit nginx for `add_header Access-Control` |
| HocamClass | Medium | Verify nginx config has no CORS duplication |
| Any Express.js + nginx | HIGH | Same pattern — use one layer only |

## Keywords

nginx, fastapi, cors, double-header, access-control-allow-origin, options, preflight, middleware, corsmiddleware, 502, 403, browser-error

## Lessons Learned

1. CORS should be handled by ONE layer only — never nginx AND application simultaneously
2. FastAPI CORSMiddleware is the correct place for FastAPI projects
3. nginx can handle OPTIONS preflight for performance gain (204 before proxy overhead) but should NOT duplicate CORS response headers
4. Always test with `curl -sv -H "Origin: ..."` to inspect actual response headers — browser DevTools can sometimes be misleading
5. The symptom (browser CORS error) does not always mean CORS is misconfigured — it can mean CORS is configured twice

## See Also

- EXP-0097: External API Key Unavailable → Graceful Degradation Pattern
- EXP-0098: Python Venv Mac → VPS Portability Issue
- FastAPI CORS docs: https://fastapi.tiangolo.com/tutorial/cors/
- nginx `add_header` docs: https://nginx.org/en/docs/http/ngx_http_headers_module.html
