# EXP-0096: Next.js Sub-Route 404 (Missing page.tsx)

**Date**: 2026-02-28
**Project**: Analizci (Video Analysis Platform)
**Severity**: LOW-MEDIUM
**Tags**: `nextjs`, `routing`, `404`, `app-router`, `page.tsx`

## Problem

`/admin` returns 404 (Not Found), but `/admin/dashboard` works perfectly. Browser console shows:

```
GET https://analiz.orcunsamitandogan.com/admin?_rsc=1y9xj 404 (Not Found)
```

## Root Cause

Next.js 15 App Router requires a `page.tsx` file at **every route level** that should be accessible.

```
app/
├── admin/
│   ├── layout.tsx    ← ✅ exists
│   ├── dashboard/
│   │   └── page.tsx  ← ✅ /admin/dashboard works
│   └── compare/
│       └── page.tsx  ← ✅ /admin/compare works
│
│   ← ❌ NO page.tsx → /admin → 404!
```

`layout.tsx` alone does NOT make a route accessible. It only wraps child routes.

## Fix

Create `/app/admin/page.tsx` with a redirect:

```typescript
import { redirect } from "next/navigation";

export default function AdminPage() {
  redirect("/admin/dashboard");
}
```

This is a **server component** redirect — no flash, no client-side navigation needed.

## When This Happens

- Parent route directory has `layout.tsx` but no `page.tsx`
- Sub-routes work but parent route gives 404
- `_rsc=` query parameter in the error URL (Next.js RSC request indicator)

## Prevention

When creating a new route directory with sub-routes:
1. Create `layout.tsx` for shared UI
2. **Also create `page.tsx`** at the parent level — even if just a redirect
3. Pattern: `redirect("/[parent]/[first-child]")`

## Other Contexts

- Same issue applies to any nested route structure
- Common when converting from Pages Router (where `index.tsx` was automatic)
- Middleware-based redirects can also solve this but are heavier

## Related Files

- `analizci/frontend/src/app/admin/page.tsx` — the redirect file created to fix this
