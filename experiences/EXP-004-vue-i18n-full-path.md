---
id: EXP-004
project: global
worker: generic
category: frontend
tags: [vue-i18n, i18n, translation, path-mismatch]
outcome: failure
date: 2026-02-01
---

## Problem
Translation keys not resolving in Vue components — renders as literal strings.

## What Happened
Component calls `t('quickUpload.title')` but translation file has `notes.quickUpload.title`. Missing prefix causes undefined key.

## Root Cause
Vue-i18n path resolution is exact and hierarchical. Must match complete path from JSON root.

## Solution / Pattern
```vue
<!-- CORRECT: use full hierarchical path -->
<h1>{{ t('notes.quickUpload.title') }}</h1>
```

## Prevention
Rule to add to BRIEFING.md:
```
- Vue-i18n: always use FULL path from JSON root (e.g., t('section.subsection.key'), never t('subsection.key')).
- Debug: console.log(t('key')) → if undefined, path is wrong.
```
