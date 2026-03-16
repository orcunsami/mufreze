---
id: EXP-012
project: global
worker: generic
category: devops
tags: [nginx, fastapi, cors, double-header]
outcome: failure
date: 2026-02-28
---

## Problem
Browser: `'Access-Control-Allow-Origin' header contains multiple values`. Both nginx AND FastAPI adding CORS headers.

## Root Cause
CORS handled by two layers independently. Browser rejects duplicate headers.

## Solution / Pattern
FastAPI CORSMiddleware handles all CORS. nginx only handles OPTIONS preflight:

```nginx
location /api/ {
    if ($request_method = 'OPTIONS') {
        add_header 'Access-Control-Allow-Origin' $http_origin;
        add_header 'Access-Control-Allow-Methods' 'GET, POST, PUT, DELETE, OPTIONS';
        return 204;
    }
    # NO CORS headers here — FastAPI handles them
    proxy_pass http://localhost:8570;
}
```

## Prevention
Rule to add to BRIEFING.md:
```
- CORS = ONE layer only (nginx OR application, never both).
- Detection: curl -sv -H "Origin: ..." URL | grep -i access-control → should see only 1 value.
- Audit: grep "add_header.*Access-Control" /etc/nginx/sites-available/*
```
