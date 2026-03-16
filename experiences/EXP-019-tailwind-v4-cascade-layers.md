---
id: EXP-019
project: global
worker: generic
category: frontend
tags: [tailwind, css, cascade-layers, v4]
outcome: failure
date: 2026-02-28
---

## Problem
ALL Tailwind utility classes stop working after adding CSS reset. Spacing, padding, margin — nothing applies.

## Root Cause
Unlayered CSS `* { margin: 0; padding: 0 }` overpowers `@layer utilities`. CSS Cascade Layers: unlayered > @layer utilities.

## Solution / Pattern
```css
/* WRONG - kills all utilities */
* { margin: 0; padding: 0; }

/* CORRECT - inside @layer base */
@layer base {
  * { margin: 0; padding: 0; }
}

/* BEST - remove entirely, Tailwind preflight handles it */
@import "tailwindcss";
```

## Prevention
Rule to add to BRIEFING.md:
```
- Tailwind v4 CSS resets MUST be inside @layer base, NEVER unlayered.
- Prefer Tailwind's built-in preflight (enabled by default).
- Detection: ALL utilities fail at once → suspect cascade layer issue.
- Debug: DevTools → inspect → if styling crossed out by * selector → fix @layer.
```
