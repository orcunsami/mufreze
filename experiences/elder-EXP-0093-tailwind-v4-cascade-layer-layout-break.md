# EXP-0093: Tailwind CSS v4 Cascade Layer Layout Break

| Field | Value |
|-------|-------|
| **ID** | EXP-0093 |
| **Date** | 2026-02-28 |
| **Project** | x-twitter |
| **Category** | Frontend/CSS Architecture |
| **Status** | SUCCESS |
| **Technologies** | Next.js 14, Tailwind CSS v4, TypeScript, shadcn/ui |

## Problem Description

After adding a custom CSS reset in `index.css` or `globals.css` with `* { margin: 0; padding: 0; box-sizing: border-box; }` (unlayered), ALL Tailwind utility classes (`mb-6`, `py-20`, `px-4`, `gap-8`, etc.) stopped working. The entire layout completely broke — spacing, padding, and margin utilities had zero visual effect.

Approximately 3-4 hours were wasted investigating red herrings: Cloudflare cache invalidation, nginx config, dark mode class conflicts, and PostCSS configuration. None of these were the cause.

## Root Cause Analysis

The CSS Cascade Layers specification defines strict priority ordering. **Unlayered styles ALWAYS win over `@layer` rules** regardless of source order or specificity. Tailwind v4 places all utility classes inside `@layer utilities {}`. An unlayered `* { margin: 0 }` rule overrides `@layer utilities { .mb-6 { margin-bottom: 1.5rem } }` every single time, regardless of which appears later in the file.

**Cascade priority order (lowest to highest):**
```
@layer base < @layer components < @layer utilities < [unlayered styles]
```

**Wrong code — breaks ALL Tailwind utilities:**
```css
/* globals.css - WRONG */
* {
  margin: 0;
  padding: 0;
  box-sizing: border-box;
}
```

**Correct code — move reset into `@layer base`:**
```css
/* globals.css - CORRECT */
@layer base {
  * {
    margin: 0;
    padding: 0;
    box-sizing: border-box;
  }
}
```

**Even better — remove entirely:**
```css
/* globals.css - BEST */
/* No custom reset needed: Tailwind preflight already handles margin/padding reset */
@import "tailwindcss";
```

Tailwind's built-in preflight (enabled by default) already applies a comprehensive CSS reset within `@layer base`, making a custom reset redundant in most cases.

## Solution

1. Remove any unlayered `*`, `html`, or `body` selectors that reset `margin`, `padding`, or `box-sizing` from `globals.css` or `index.css`.
2. If a custom reset is truly needed, wrap it inside `@layer base {}`.
3. Prefer relying on Tailwind's built-in preflight instead of writing a custom reset.

**Verification after fix:**
```bash
# Rebuild and check that spacing utilities are applied
bun run build
# Open browser DevTools → inspect an element with mb-6 → margin-bottom should be 1.5rem
```

## Detection Methods

1. **Primary signal:** Tailwind spacing/padding/margin utilities have zero visual effect site-wide despite correct class names.
2. **DevTools check:** Inspect an element with a spacing class (e.g., `mb-6`). If the rule appears but is crossed out/overridden by a `*` selector — this is the issue.
3. **Search for unlayered resets:**
```bash
grep -n "margin: 0\|padding: 0\|box-sizing" frontend/src/app/globals.css
# If found and NOT inside @layer base { } → confirmed bug
```
4. **Rule of thumb:** If ALL Tailwind utilities fail at once (not just one), suspect a cascade layer conflict before investigating infrastructure.

## Prevention Checklist

| Check | Action |
|-------|--------|
| Custom CSS reset present? | Verify it is inside `@layer base {}` |
| Unlayered `*` selector in globals.css? | Move into `@layer base {}` or remove |
| Is Tailwind preflight enabled? | Check `tailwind.config.ts` — `preflight: false` disables it |
| New CSS file added? | Ensure any unlayered rules do not reset margin/padding |
| shadcn/ui added? | shadcn often injects base styles — verify they don't conflict |

## Cross-Project Applicability

| Project | Stack | Applicability |
|---------|-------|---------------|
| Any Next.js + Tailwind v4 | Next.js, Tailwind CSS v4 | HIGH — exact same issue |
| Any React + Tailwind v4 | CRA, Vite, Remix | HIGH — same root cause |
| Vue + Tailwind v4 | Vue 3, Nuxt | HIGH — same root cause |
| Tailwind v3 projects | Any | LOW — v3 uses PostCSS differently, less likely |
| Non-Tailwind CSS projects | Plain CSS, SCSS | NOT APPLICABLE |

## Keywords

`tailwind`, `css-cascade-layers`, `layout`, `margin`, `padding`, `utilities`, `nextjs`, `shadcn`, `v4`, `globals.css`, `layer`, `preflight`, `reset`, `unlayered`, `box-sizing`, `spacing`

## Lessons Learned

1. CSS Cascade Layers have a strict priority order — unlayered styles ALWAYS beat `@layer` rules, no exceptions.
2. Tailwind v4 uses `@layer utilities {}` for all utility classes, making this a critical constraint for any custom CSS.
3. Any CSS reset code must be placed inside `@layer base {}`, not at the top level of the stylesheet.
4. Tailwind's preflight already handles the standard CSS reset — a custom `* { margin: 0 }` is almost never necessary.
5. When ALL Tailwind utilities fail simultaneously, the root cause is almost always a cascade layer conflict, not infrastructure.
6. Do NOT chase Cloudflare cache, nginx, or PostCSS configs when Tailwind utilities stop working — check `globals.css` first.

## See Also

- EXP-0078 (Vue i18n path mismatch — another "works elsewhere, not here" CSS/styling red herring pattern)
- Tailwind CSS v4 migration guide: https://tailwindcss.com/docs/upgrade-guide
- MDN CSS Cascade Layers: https://developer.mozilla.org/en-US/docs/Learn/CSS/Building_blocks/Cascade_layers
