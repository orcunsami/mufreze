---
id: EXP-001
project: global
worker: generic
category: shell
tags: [heredoc, mongodb, dollar-sign, variable-expansion, bash]
outcome: failure
date: 2026-02-27
---

## Problem
Shell heredoc (`<< EOF`) with MongoDB operators like `$set`, `$push` causes variables to be stripped. `{ $set: { field: "value" } }` becomes `{ : { field: "value" } }`.

## What Happened
Bash heredoc with unquoted EOF delimiter treats content as subject to variable expansion. MongoDB operators using `$` prefix are interpreted as shell variables and expanded to empty strings.

## Root Cause
`<< EOF` (unquoted) enables variable expansion inside heredoc. MongoDB operators (`$set`, `$push`, `$match`) starting with `$` are treated as shell variable references.

## Solution / Pattern
Use single-quoted EOF delimiter: `<< 'EOF'` instead of `<< EOF`.

```bash
# CORRECT
mongo localhost/mydb << 'EOF'
db.collection.update({ username: "test" }, { $set: { field: "value" } })
EOF
```

## Prevention
Rule to add to BRIEFING.md:
```
- Any heredoc containing MongoDB operators or JSON with $ prefixes MUST use << 'EOF' (quoted delimiter).
```
