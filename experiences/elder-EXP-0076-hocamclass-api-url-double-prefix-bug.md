# EXP-0076: API URL Double Prefix Bug in Vue/FastAPI Projects

| Field | Value |
|-------|-------|
| **ID** | EXP-0076 |
| **Date** | 2026-01-31 |
| **Project** | HocamClass |
| **Category** | Frontend/API Integration |
| **Status** | SUCCESS |
| **Technologies** | Vue.js 3, TypeScript, Axios, FastAPI, Vite |

## Problem Description

Frontend API calls returned 404 errors because the URL contained a double `/api/v1` prefix:

- **Expected**: `http://localhost:8173/api/v1/dersler/courses/list`
- **Actual**: `http://localhost:8173/api/v1/api/v1/dersler/courses/list`

## Root Cause Analysis

The prefix was defined in two places:

1. **`api.ts`** - Axios baseURL configuration:
   ```typescript
   // .env file
   VITE_API_URL=http://localhost:8173/api/v1

   // api.ts
   const api = axios.create({
     baseURL: import.meta.env.VITE_API_URL
   })
   ```

2. **`useDerslerApi.ts`** - Feature-specific composable:
   ```typescript
   // WRONG - includes /api/v1 again
   const baseUrl = '/api/v1/dersler'
   ```

When axios concatenates `baseURL + requestPath`:
- `http://localhost:8173/api/v1` + `/api/v1/dersler/courses/list`
- Result: `http://localhost:8173/api/v1/api/v1/dersler/courses/list`

## Solution

In feature-specific API composables, use only the feature prefix without `/api/v1`:

```typescript
// WRONG
const baseUrl = '/api/v1/dersler'

// CORRECT
const baseUrl = '/dersler'
```

## Detection Methods

1. **Browser Console**: Look for 404 errors on API calls
2. **Network Tab**: Check the actual URL being requested
3. **Pattern Match**: Search for `/api/v1/api/v1/` in network requests - this is the double prefix signature

## Prevention Checklist

| Check | Action |
|-------|--------|
| New API composable | Check if `VITE_API_URL` already includes `/api/v1` |
| Existing pattern | Look at other composables for the correct pattern |
| URL construction | Ensure feature prefix starts directly with feature name (e.g., `/dersler`, not `/api/v1/dersler`) |
| Code review | Search for `/api/v1` in composable files - it should only appear in env config |

## Related Files (HocamClass)

```
frontend/
  src/
    services/
      api.ts              # axios baseURL config
    composables/
      useDerslerApi.ts    # feature-specific API (FIXED)
      useAuthApi.ts       # other composables to check
```

## Cross-Project Applicability

This pattern applies to all Vue.js + FastAPI projects with similar architecture:

| Project | Frontend | API Config | Risk |
|---------|----------|------------|------|
| HocamClass | Vue.js 3 | Vite env | HIGH |
| Grand | Vue.js 3 | Vite env | MEDIUM |
| Any Vue+axios | Vue.js | Vite/Webpack env | MEDIUM |

## Keywords

`frontend`, `api`, `vue`, `axios`, `baseurl`, `double-prefix`, `404`, `url-concatenation`, `vite`, `environment-variables`, `api-composable`, `fastapi`

## Lessons Learned

1. **Single Source of Truth**: API prefix should be defined in ONE place only
2. **Convention**: Feature composables should use relative paths from the API root
3. **Review**: When creating new API composables, always check the existing pattern
4. **Testing**: Always verify actual network requests, not just TypeScript compilation

## See Also

- [EXP-0055](EXP-0055-urunlu-api-url-prefix-standardization.md): API URL Prefix Standardization (similar issue in Next.js)
