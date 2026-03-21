# Experience 0028: Next.js Internationalization Language Switching Fix

**Date**: July 22, 2025  
**Project**: ODTÜ Connect (formerly HocamKariyer)  
**Category**: Frontend/Internationalization  
**Status**: ✅ Resolved  
**Key Technologies**: Next.js 14 App Router, next-intl, TypeScript, React Hooks, i18n

---

## Problem Statement

The homepage language switching feature was not working properly in a Next.js 14 App Router application with next-intl internationalization. When users clicked the language toggle (EN/TR flags), the URL would change correctly (e.g., `/en` to `/tr`), but the actual content remained in the wrong language.

### Symptoms
1. **URL Changes Correctly**: `localhost:3700/en` → `localhost:3700/tr` ✅
2. **Flag Display Updates**: Language flag shows "🇹🇷 TR" correctly ✅  
3. **Content Language Stuck**: All main content still displayed in English instead of Turkish ❌
4. **Mixed Translation Behavior**: Hard-coded conditional text updated, but `t()` function calls didn't

### User Impact
- Users could not access Turkish language content
- Inconsistent language experience across different UI elements
- Poor user experience for Turkish-speaking users

---

## Investigation Process

### Step 1: Component Analysis
Examined the homepage component structure and found two different approaches to internationalization:

**Working Elements** (Updated immediately):
```tsx
// Hard-coded conditional logic
{locale === 'en' ? 'Sign In' : 'Giriş Yap'}
{locale === 'en' ? 'Join Community' : 'Topluluğa Katıl'}
```

**Broken Elements** (Not updating):
```tsx
// Translation system using t() function
{t('hero.title')}        // Still showing "METU 2025 Newcomers"
{t('hero.subtitle')}     // Still showing "Orientation Project"
{t('hero.description')}  // Still showing English description
```

### Step 2: Server-Side Investigation
Used `curl` to check server-side rendering:
```bash
curl -s http://localhost:3700/tr | grep -A 5 -B 5 "METU 2025"
```

**Key Finding**: Server-side HTML was sending English translations even when URL was `/tr`:
```javascript
// In server response for /tr URL
"landing":{"hero":{"title":"METU 2025 Newcomers"  // Should be "ODTÜ 2025 Girişliler"
```

### Step 3: Translation Loading Analysis
Inspected the layout component's message loading logic:

**Problematic Code**:
```tsx
// src/app/[locale]/layout.tsx
try {
  messages = await getMessages(); // ❌ No locale context
} catch (error) {
  // Fallback logic
}
```

**Root Cause Identified**: `getMessages()` was called without explicit locale parameter, causing it to default to English regardless of the URL locale.

---

## Root Cause Analysis

### Primary Issue: Incorrect Server-Side Translation Loading
The `getMessages()` function in the layout component was not receiving the locale context, causing it to always load English translations even when the user was on the `/tr` route.

### Secondary Issue: Mixed Translation Patterns
The codebase had inconsistent approaches to internationalization:
1. **Conditional Logic**: `{locale === 'en' ? 'English' : 'Turkish'}` (worked)
2. **Translation Keys**: `{t('key')}` (broken due to wrong messages loaded)

### Technical Details
- **Next.js App Router**: Uses server-side rendering by default
- **next-intl**: Requires explicit locale context for `getMessages()`
- **Translation Loading**: Server loads wrong message bundle, client receives incorrect translations

---

## Solution Implementation

### Step 1: Fix Server-Side Translation Loading
**File**: `/frontend/src/app/[locale]/layout.tsx`

**Before**:
```tsx
// Get messages from server-side
let messages;
try {
  messages = await getMessages(); // ❌ No locale context
} catch (error) {
  // Complex fallback logic...
}
```

**After**:
```tsx
// Get messages from server-side based on locale
const messages = await getMessages({locale}); // ✅ Explicit locale
```

### Step 2: Add Missing Translation Keys
Added proper translation keys to both language files:

**English** (`/frontend/src/messages/en.json`):
```json
{
  "landing": {
    "header": {
      "signIn": "Sign In",
      "getStarted": "Get Started"
    },
    "hero": {
      "joinCommunity": "Join Community",
      "learnMore": "Learn More"
    },
    "cta": {
      "explorePlatform": "Explore Platform"
    }
  }
}
```

**Turkish** (`/frontend/src/messages/tr.json`):
```json
{
  "landing": {
    "header": {
      "signIn": "Giriş Yap",
      "getStarted": "Başla"
    },
    "hero": {
      "joinCommunity": "Topluluğa Katıl",
      "learnMore": "Daha Fazla Bilgi"
    },
    "cta": {
      "explorePlatform": "Platformu Keşfet"
    }
  }
}
```

### Step 3: Replace Hard-Coded Text with Translation Keys
**File**: `/frontend/src/app/[locale]/page.tsx`

**Before**:
```tsx
{locale === 'en' ? 'Sign In' : 'Giriş Yap'}
{locale === 'en' ? 'Join Community' : 'Topluluğa Katıl'}
```

**After**:
```tsx
{t('header.signIn')}
{t('hero.joinCommunity')}
```

### Step 4: Improve Language Switcher
Enhanced the language change handler to use `window.location.href` for forced page refresh:

```tsx
const handleLanguageChange = (langCode: string) => {
  const segments = pathname.split('/')
  const hasLocale = segments[1] === 'en' || segments[1] === 'tr'
  
  if (hasLocale) {
    segments.splice(1, 1)
  }
  
  const newPath = `/${langCode}${segments.join('/')}`
  
  // Use window.location for immediate redirect
  window.location.href = newPath // ✅ Forces full page refresh
  setShowLangMenu(false)
}
```

---

## Verification

### Test Scenarios
1. **URL Navigation**: Direct navigation to `/en` and `/tr` URLs
2. **Language Toggle**: Click EN/TR flags and verify content changes
3. **Server Response**: Verify server sends correct translations for each locale
4. **Client Hydration**: Ensure client-side matches server-side content

### Verification Results
- ✅ **Homepage `/en`**: All content displays in English
- ✅ **Homepage `/tr`**: All content displays in Turkish  
- ✅ **Language Toggle**: Switching between languages updates all content
- ✅ **Server-Side**: Correct translations loaded based on URL locale
- ✅ **Consistency**: No mixed language content

### Test Commands Used
```bash
# Test server-side rendering
curl -s http://localhost:3700/en | grep "METU 2025 Newcomers"
curl -s http://localhost:3700/tr | grep "ODTÜ 2025 Girişliler"

# Verify meta tags
curl -s http://localhost:3700/tr | grep "og:locale"
```

---

## Lessons Learned

### Key Takeaways

1. **Always Pass Locale Context**: When using `getMessages()` in Next.js App Router with next-intl, always pass the locale explicitly:
   ```tsx
   const messages = await getMessages({locale});
   ```

2. **Avoid Mixed Translation Patterns**: Stick to one approach throughout the application:
   - ✅ Use `{t('key')}` for all translatable text
   - ❌ Avoid `{locale === 'en' ? 'English' : 'Turkish'}` patterns

3. **Server-Side vs Client-Side**: Next.js App Router uses server-side rendering by default. Translation issues often stem from server-side configuration problems, not client-side logic.

4. **Debug with Server Response**: Use `curl` to check server-side HTML output when debugging i18n issues:
   ```bash
   curl -s http://localhost:3700/locale-path | grep "expected-content"
   ```

5. **Full Page Refresh for Route Changes**: Sometimes `router.push()` doesn't trigger proper re-rendering with i18n. Use `window.location.href` for guaranteed full page refresh.

### Best Practices Established

1. **Centralized Translation Keys**: All UI text should use translation keys from JSON files
2. **Explicit Locale Context**: Always pass locale to translation loading functions
3. **Consistent Naming**: Use hierarchical key names like `section.subsection.key`
4. **Server-First Debugging**: Check server-side rendering before debugging client-side issues

### Anti-Patterns to Avoid

1. **Implicit Locale Loading**: Never call `getMessages()` without locale context
2. **Mixed Translation Approaches**: Don't mix conditional logic with translation functions
3. **Client-Only Fixes**: Don't attempt to fix i18n issues only on the client side

---

## Related Code

### Files Modified
1. `/frontend/src/app/[locale]/layout.tsx` - Fixed server-side message loading
2. `/frontend/src/app/[locale]/page.tsx` - Replaced hard-coded text with translation keys
3. `/frontend/src/messages/en.json` - Added missing translation keys
4. `/frontend/src/messages/tr.json` - Added missing translation keys

### Key Functions
- `getMessages({locale})` - Server-side translation loading
- `handleLanguageChange()` - Client-side language switching
- `t('key')` - Translation function usage

### Dependencies Used
- `next-intl` v4.3.2 - Internationalization framework
- `next` v14.0.4 - Next.js App Router
- `react` v18.3.1 - Frontend framework

---

## Technical Specifications

### Environment
- **Next.js**: 14.0.4 (App Router)
- **next-intl**: 4.3.2
- **TypeScript**: 5.8.3
- **React**: 18.3.1

### Supported Locales
- `en` - English (default)
- `tr` - Turkish

### Translation Structure
```
messages/
├── en.json
└── tr.json

Each containing:
├── landing.header.*
├── landing.hero.*
├── landing.history.*
├── landing.services.*
├── landing.features.*
└── landing.cta.*
```

---

**Impact**: ✅ Complete internationalization fix enabling proper Turkish language support  
**Complexity**: Medium - Required understanding of Next.js App Router i18n architecture  
**Time to Resolution**: ~2 hours of debugging and implementation  
**Prevention**: Always test server-side rendering when implementing internationalization features