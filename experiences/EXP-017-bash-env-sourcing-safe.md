---
id: EXP-017
project: global
worker: generic
category: shell
tags: [bash, env, sourcing, special-characters]
outcome: failure
date: 2026-02-01
---

## Problem
`source .env` fails with syntax errors. `.env` contains values with hyphens (e.g., `MODEL_ID=gpt-4-turbo`).

## Root Cause
`.env` is application config format, not bash script. Hyphens and special chars valid in .env but invalid in bash.

## Solution / Pattern
```bash
# Safe sourcing — suppress errors, valid vars still load
source .env 2>/dev/null

# Use variables with proper quoting
curl -u "${JIRA_EMAIL}:${JIRA_API_TOKEN}" \
  -H "Content-Type: application/json" \
  "$API_URL/endpoint"
```

## Prevention
Rule to add to BRIEFING.md:
```
- Always: source .env 2>/dev/null (suppress errors, continue).
- Variables: use ${VAR} with double quotes.
- Debug: bash -x script.sh to trace variable expansion.
```
