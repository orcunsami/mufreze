---
id: EXP-002
project: global
worker: generic
category: database
tags: [mongodb, unique-index, compound-key, multi-tenant]
outcome: failure
date: 2026-02-27
---

## Problem
`DuplicateKeyError` on account transfer. Global unique index on `account_username` prevents the same username from existing in different organizations.

## What Happened
Index defined as `account_username_1` (single field unique). Same username in different org_id → rejected.

## Root Cause
Index design didn't account for multi-tenancy. Should be compound unique on `(account_username, org_id)`.

## Solution / Pattern
```javascript
db.accounts.dropIndex("account_username_1");
db.accounts.createIndex(
  { "account_username": 1, "org_id": 1 },
  { unique: true }
);
```

## Prevention
Rule to add to BRIEFING.md:
```
- In multi-tenant systems, NEVER use globally unique indexes without tenant context (org_id).
- Design question: "Is this field unique per-tenant or globally?" — answer determines index structure.
```
