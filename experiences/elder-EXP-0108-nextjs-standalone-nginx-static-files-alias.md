# EXP-0094: Next.js Standalone Mode + nginx: Static Files 404 (proxy_pass vs alias)

| Field | Value |
|-------|-------|
| **ID** | EXP-0094 |
| **Date** | 2026-02-28 |
| **Project** | x-twitter |
| **Category** | DevOps/nginx/Deployment |
| **Status** | SUCCESS |
| **Technologies** | Next.js 14, nginx, VPS, PM2 |

## Problem Description

After deploying a Next.js application in standalone mode on a VPS with nginx as the reverse proxy, all requests to `/_next/static/**` and `/public/**` returned HTTP 404. The application shell loaded (HTML was served), but without any CSS, JavaScript bundles, fonts, or static assets. API routes continued to function correctly.

This causes the app to appear completely unstyled and non-functional in the browser despite the Next.js server process running correctly under PM2.

## Root Cause Analysis

Next.js standalone mode produces a specific output directory structure that separates the server runtime from static assets:

```
.next/
  standalone/       <- Node.js server (this is what PM2 runs)
    server.js
    node_modules/
  static/           <- Static chunks/assets (NOT inside standalone/)
    chunks/
    css/
    media/
public/             <- Public folder assets
  images/
  fonts/
```

The critical detail: **the standalone server does NOT serve `/_next/static/` files**. In standalone mode, Next.js expects static files to be served by an external file server (nginx) or CDN.

When nginx routes ALL traffic — including `/_next/static/` — through `proxy_pass http://localhost:3570`, the Node.js standalone server has no handler for those paths and returns 404.

**Wrong nginx configuration (proxies static files to Node.js):**
```nginx
server {
    listen 443 ssl;
    server_name x.orcunsamitandogan.com;

    location / {
        proxy_pass http://localhost:3570;  # WRONG: static files also go to Node.js
        proxy_http_version 1.1;
        proxy_set_header Host $host;
    }
    # No location block for /_next/static/ → 404 for all JS/CSS
}
```

## Solution

Add dedicated nginx `location` blocks to serve static files directly from the filesystem using `alias`, bypassing the Node.js process entirely.

**Correct nginx configuration:**
```nginx
server {
    listen 443 ssl;
    server_name x.orcunsamitandogan.com;

    # Next.js static chunks (hashed filenames — safe to cache forever)
    location /_next/static/ {
        alias /usr/local/main/x-twitter/frontend/.next/static/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # Public folder assets (images, fonts, favicon, etc.)
    location /public/ {
        alias /usr/local/main/x-twitter/frontend/public/;
        expires 30d;
        add_header Cache-Control "public";
    }

    # Everything else -> Next.js server
    location / {
        proxy_pass http://localhost:3570;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
}
```

**Important nginx `alias` note:** When using `alias` with a `location` that ends in `/`, the alias path must also end in `/`. The path after the location prefix is appended directly to the alias value.

**Apply changes:**
```bash
nginx -t                    # Test configuration
systemctl reload nginx      # Apply without downtime
```

## Detection Methods

1. **Browser Network tab:** Open DevTools Network tab — look for `/_next/static/chunks/*.js` and `/_next/static/css/*.css` returning 404.
2. **curl test:**
```bash
# Test if static files are reachable through nginx
curl -I https://x.orcunsamitandogan.com/_next/static/chunks/main.js

# If 404 → nginx is not serving static files
# If 200 → correctly configured
```
3. **Check standalone output structure:**
```bash
ls /usr/local/main/x-twitter/frontend/.next/
# Should contain: standalone/ AND static/ as siblings
# If static/ only exists inside standalone/ → non-standard build
```
4. **Visual signal:** App loads with no styles, no JavaScript interactivity, browser console shows many 404 errors for `/_next/static/` paths.

## Prevention Checklist

| Check | Action |
|-------|--------|
| Next.js output mode | Verify `next.config.js` has `output: 'standalone'` if using standalone |
| nginx static location | Add `/_next/static/` location block with `alias` pointing to `.next/static/` |
| nginx public location | Add `/public/` or specific asset paths served from `public/` directory |
| Static files path | Confirm `.next/static/` exists at the aliased path after build |
| Cache headers | Add `expires 1y` + `Cache-Control: public, immutable` for `/_next/static/` |
| After each deployment | Re-run `bun run build` — `.next/static/` contents change with each build |
| Symlinks | If using symlinks, ensure nginx can follow them (`disable_symlinks off`) |

## Cross-Project Applicability

| Project | Stack | Applicability |
|---------|-------|---------------|
| Any Next.js standalone on VPS | Next.js + nginx | HIGH — identical configuration needed |
| Next.js on Docker | Next.js + nginx sidecar | HIGH — same issue inside containers |
| Nuxt.js standalone | Nuxt + nginx | MEDIUM — similar static asset separation |
| CRA / Vite (SPA) | React + nginx | LOW — SPAs typically use `root` directive, not `alias` |
| Next.js on Vercel/Netlify | Managed platform | NOT APPLICABLE — handled by platform |

## Keywords

`nextjs`, `standalone`, `nginx`, `static-files`, `alias`, `proxy_pass`, `404`, `vps`, `deployment`, `chunks`, `_next`, `pm2`, `reverse-proxy`, `cache-control`, `immutable`, `next.config.js`

## Lessons Learned

1. Next.js standalone mode intentionally separates the server (`standalone/`) from static assets (`static/`) — the server does not serve static files.
2. nginx `alias` directive (not `root`) is required for `/_next/static/` because the location prefix must be stripped from the filesystem path.
3. Static files in `/_next/static/` use content-hashed filenames — they can be cached with `expires 1y` and `Cache-Control: public, immutable` safely.
4. Serving static files via nginx (not Node.js) is also a performance best practice — nginx is significantly faster at serving static content.
5. Always test nginx config with `nginx -t` before reloading to catch alias path errors.
6. After every `bun run build` / `npm run build`, the `.next/static/` directory is regenerated — verify the alias path remains valid.

## See Also

- EXP-0080 (SenlikBuddy VPS deployment — similar nginx proxy setup patterns)
- EXP-0092 (SenlikBuddy full VPS deployment — nginx configuration reference)
- Next.js Standalone Mode docs: https://nextjs.org/docs/app/api-reference/config/next-config-js/output
- nginx `alias` directive: https://nginx.org/en/docs/http/ngx_http_core_module.html#alias
