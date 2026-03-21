# EXP-0097: Cloudflare + Nginx SPA — Cache Invalidation Debugging

## Metadata
- **Date**: 2026-02-28
- **Project**: resmigazete (Resmi Gazete Bulten Platform)
- **Severity**: MEDIUM (wastes hours of debugging time)
- **Category**: DevOps, Nginx, Cloudflare, SPA Deployment
- **Status**: SOLVED (with lessons learned)

## Problem Statement
After deploying new frontend build to VPS, live site still shows old version. Hard refresh (Cmd+Shift+R), clearing site data, different browsers — nothing works. Cloudflare "Purge Everything" done, Development Mode enabled — still same. Spent 3+ hours thinking content wasn't updating.

## What Actually Happened (The Real Problem)
The content WAS updating — View Source confirmed new HTML. The visual "same as before" was caused by a **different bug** (Tailwind CSS cascade layer issue) that made the page look broken/identical to before.

**Lesson: "Site looks the same" does not mean "content not deploying".**

## Diagnosis Protocol (Use This Order)

### Step 1: Verify Content Actually Changed (30 seconds)
```bash
# Check which JS hash is in the HTML served
curl -s https://your-domain.com/ | grep -o 'index-[a-zA-Z0-9_-]*.js'

# Check what's in dist/
ls frontend/dist/assets/ | grep 'index-'

# These should match. If they don't → nginx serving old dist
# If they match → content IS updated, bug is elsewhere
```

### Step 2: Check View Source in Browser
- Right-click → View Source (not DevTools)
- Look for new JS hash, new CSS hash, build markers
- If View Source shows new content → cache is NOT the problem

### Step 3: Check Nginx Config for SPA
```nginx
# /etc/nginx/sites-enabled/your-site.conf
location / {
    try_files $uri $uri/ /index.html;

    # CRITICAL: index.html must never be cached (SPA entry point)
    add_header Cache-Control "no-cache, no-store, must-revalidate";
    add_header Pragma "no-cache";
    add_header Expires "0";
}

# Assets CAN be cached aggressively (Vite adds content hash to filename)
location /assets/ {
    expires 1y;
    add_header Cache-Control "public, max-age=31536000, immutable";
}
```

### Step 4: Cloudflare Cache
```bash
# Check cf-cache-status header
curl -sI https://your-domain.com/ | grep 'cf-cache-status'
# DYNAMIC = Cloudflare not caching (good for HTML)
# HIT = Cloudflare caching (use Purge Cache or Development Mode)
```

## Why Vite Builds Self-Invalidate
Vite adds a **content hash** to every asset filename:
```
index-ulkSRvGK.js   → old build
index-BCw56JEa.js   → new build (different content = different hash)
```
When index.html changes to reference the new hash, browsers and Cloudflare automatically fetch new assets — no manual cache busting needed for JS/CSS. The ONLY file needing `no-cache` is `index.html` itself.

## Nginx SPA Config Quick Reference
```nginx
server {
    listen 443 ssl;
    server_name your-domain.com;
    root /path/to/frontend/dist;

    # SPA routing
    location / {
        try_files $uri $uri/ /index.html;
        add_header Cache-Control "no-cache, no-store, must-revalidate";
    }

    # Immutable assets (content-hashed by Vite)
    location /assets/ {
        add_header Cache-Control "public, max-age=31536000, immutable";
    }

    # API proxy
    location /api/ {
        proxy_pass http://localhost:8620;
        proxy_set_header Host $host;
    }
}
```

## Applicable To
- ALL SPA deployments (React, Vue, Svelte) behind Cloudflare + Nginx
- Any Vite/webpack project with content-hash filenames
- Debugging "site shows old version after deploy"

## Lessons Learned
1. **"Looks the same" != "not deploying"** — verify with View Source first
2. **Vite content hashes self-invalidate** — cache busting is automatic for assets
3. **Only index.html needs `no-cache`** — everything else can be `immutable`
4. **Check curl from server** — eliminates client-side variables entirely
5. **Add a build marker** to index.html (`<!-- BUILD 1234567 -->`) for easy verification
6. **Cloudflare "DYNAMIC"** for HTML is correct and expected
7. When stuck: `curl -s https://domain.com | grep 'index-'` tells you everything

## Red Herrings Encountered
- Cloudflare Development Mode (not needed if nginx is right)
- Multiple Cloudflare purges (not needed once nginx no-cache is set)
- Different browsers (not browser cache issue)
- `?v=2` query param (unnecessary with proper headers)

## Related Experiences
- EXP-0093: Tailwind CSS v4 cascade layer break (the REAL cause of "same as before")
- EXP-0092: SenlikBuddy full VPS deployment (Cloudflare Full SSL mode)

## Tags
`cloudflare` `nginx` `spa` `cache` `vite` `react` `deployment` `debugging`
