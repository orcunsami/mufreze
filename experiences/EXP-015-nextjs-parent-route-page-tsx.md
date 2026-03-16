---
id: EXP-015
project: global
worker: generic
category: frontend
tags: [nextjs, routing, app-router, page-tsx, 404]
outcome: failure
date: 2026-02-28
---

## Problem
`/admin` returns 404 but `/admin/dashboard` works. `layout.tsx` exists but `page.tsx` missing.

## Root Cause
Next.js App Router: `layout.tsx` = wrapper only. `page.tsx` = actual route. Parent route needs its own `page.tsx`.

## Solution / Pattern
```typescript
// app/admin/page.tsx — redirect to first child
import { redirect } from "next/navigation";

export default function AdminPage() {
  redirect("/admin/dashboard");
}
```

## Prevention
Rule to add to BRIEFING.md:
```
- Every accessible URL needs a page.tsx at that directory level.
- layout.tsx alone does NOT make a route accessible.
- Parent route without content: create page.tsx that redirects to first child.
- Detection: URL with _rsc= parameter → Next.js hitting undefined page.
```
