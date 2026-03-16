---
id: EXP-018
project: global
worker: generic
category: frontend
tags: [api-url, axios, multipart, colors, css]
outcome: failure
date: 2026-02-02
---

## Problem
Three frontend gotchas: (1) Double API path `/api/v1/api/v1`, (2) Axios multipart error, (3) Wrong fallback color.

## Root Cause
(1) VITE_API_URL already has `/api/v1` but code adds it again.
(2) Manual `Content-Type: multipart/form-data` breaks Axios boundary.
(3) Generic fallback `#2563eb` (blue) doesn't match red project palette.

## Solution / Pattern
```typescript
// (1) Check .env before adding prefix
const apiUrl = import.meta.env.VITE_API_URL  // already has /api/v1

// (2) Let Axios handle Content-Type for FormData
const formData = new FormData()
formData.append('file', file)
axios.post(url, formData, {
  headers: { Authorization: `Bearer ${token}` }  // No Content-Type!
})

// (3) Use project palette for fallbacks
background: var(--primary-dark, #B82D30);  // project red
```

## Prevention
Rule to add to BRIEFING.md:
```
- Check .env for API URL prefix BEFORE writing endpoint paths.
- NEVER manually set Content-Type for FormData in axios.
- Fallback colors must match project palette.
- List banned/wrong colors in BRIEFING.md.
```
