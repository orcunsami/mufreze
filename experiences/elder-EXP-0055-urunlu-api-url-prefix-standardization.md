# EXP-0055: API URL Prefix Standardization - FastAPI + Next.js Integration

**Project**: Ürünlü (Turkish Cultural Heritage Platform)
**Date**: 2025-12-12
**Status**: ✅ RESOLVED
**Impact**: HIGH - Critical for multi-file API integration
**Category**: API Integration, Configuration, Debugging
**Technologies**: FastAPI, Next.js 14, TypeScript, Environment Configuration

---

## Problem Statement

Inconsistent handling of the `/api` URL prefix across different frontend files caused 404 errors during development and affected login functionality.

### Symptoms
1. **Login 404 error**: User authentication failing with endpoint not found
2. **Public pages 404 error**: Content pages returning not found
3. **Double prefix issue**: Some requests hitting `/api/api/...` endpoints

### Root Cause Analysis

Three files had conflicting `/api` prefix handling:

#### 1. `src/context/AuthContext.tsx`
```typescript
// DEFAULT: WITH /api prefix
const DEFAULT_API_URL = 'http://localhost:8620/api';
```
- All fetch calls used this URL directly
- No additional prefix manipulation

#### 2. `src/utils/api.ts`
```typescript
// DEFAULT: WITHOUT /api prefix
const API_BASE_URL = 'http://localhost:8620';

// THEN adds /api in fetch calls
const url = `${API_BASE_URL}/api${endpoint}`;
```
- Two-step prefix construction
- Added `/api` during request execution
- Inconsistent with AuthContext

#### 3. `start_frontend.sh`
```bash
# DEFAULT: WITHOUT /api prefix
NEXT_PUBLIC_API_BASE_URL=http://localhost:8620
```
- Environment-level configuration without prefix
- No documentation on whether prefix should be added

### Impact Chain

When mixing these inconsistent defaults:
1. AuthContext with `/api` → Works for some endpoints
2. api.ts adds another `/api` → Creates double prefix `/api/api`
3. Environment variable inconsistency → Confusion in development flow

**Specific Failure Scenario:**
- Login endpoint in AuthContext: `http://localhost:8620/api/auth/login` ✅ Works
- Data fetch in api.ts: `http://localhost:8620/api/api/posts` ❌ Double prefix
- Fallback to env var: No prefix at all → `http://localhost:8620/posts` ❌ 404

---

## Solution Implemented

### Standardization Strategy

**RULE**: All default configurations INCLUDE the `/api` prefix. Fetch calls use the URL AS-IS without manipulation.

#### 1. Standardize `AuthContext.tsx`
```typescript
// AuthContext.tsx - INCLUDE /api in default
const DEFAULT_API_URL = process.env.NEXT_PUBLIC_API_BASE_URL || 'http://localhost:8620/api';

// No prefix manipulation in fetch calls
const response = await fetch(`${apiUrl}/auth/login`, { ... });
```

#### 2. Standardize `api.ts`
```typescript
// api.ts - INCLUDE /api in default
const API_BASE_URL = process.env.NEXT_PUBLIC_API_BASE_URL || 'http://localhost:8620/api';

// Fetch calls use URL directly - NO additional /api
const url = `${API_BASE_URL}${endpoint}`;
export const fetchPosts = async (page: number = 1) => {
  return fetch(`${API_BASE_URL}/posts?page=${page}`);
};
```

#### 3. Standardize `start_frontend.sh`
```bash
#!/bin/bash
# Frontend startup script with consistent API configuration

# INCLUDE /api prefix in environment variable
export NEXT_PUBLIC_API_BASE_URL=${API_BASE_URL:-http://localhost:8620/api}

npm run dev
```

#### 4. Update `.env.local` (Development)
```env
# .env.local - Include /api prefix
NEXT_PUBLIC_API_BASE_URL=http://localhost:8620/api
```

#### 5. Update `.env.production` (Production)
```env
# .env.production - Include /api prefix
NEXT_PUBLIC_API_BASE_URL=https://api.urunlu.dev/api
```

### Configuration Priority

The configuration hierarchy ensures consistency:

```
1. Environment Variable (highest priority)
   NEXT_PUBLIC_API_BASE_URL=... (includes /api)

2. .env.local / .env.production files
   NEXT_PUBLIC_API_BASE_URL=... (includes /api)

3. Hardcoded defaults (lowest priority)
   AuthContext: 'http://localhost:8620/api'
   api.ts: 'http://localhost:8620/api'
   (ALL include /api)
```

---

## Fetch Call Pattern

### Before (Broken)
```typescript
// api.ts - Double /api problem
const API_BASE_URL = 'http://localhost:8620'; // No /api
const endpoint = '/posts';
fetch(`${API_BASE_URL}/api${endpoint}`); // /api/posts → Works
fetch(`${API_BASE_URL}/api/api/data`); // /api/api/data → 404!
```

### After (Fixed)
```typescript
// api.ts - Clean single prefix
const API_BASE_URL = 'http://localhost:8620/api'; // Includes /api
const endpoint = '/posts';
fetch(`${API_BASE_URL}${endpoint}`); // /api/posts → Works consistently
```

---

## Implementation Checklist

- [x] Update `AuthContext.tsx` to use environment variable with /api
- [x] Refactor `api.ts` to include /api in default, remove dual prefixing
- [x] Update `start_frontend.sh` with consistent prefix in env var
- [x] Create protocol documentation at `~/.claude/docs/protocols/api-url-standard.md`
- [x] Test login flow end-to-end
- [x] Test data fetching from public pages
- [x] Verify no double-prefix issues in network inspector

---

## Testing Verification

### Test Cases Executed

1. **Login Flow**
   - Request URL: `http://localhost:8620/api/auth/login`
   - Result: ✅ 200 OK

2. **Data Fetch (Posts)**
   - Request URL: `http://localhost:8620/api/posts?page=1`
   - Result: ✅ 200 OK

3. **Public Page Access**
   - Request URL: `http://localhost:8620/api/content/...`
   - Result: ✅ 200 OK

4. **Network Inspector Check**
   - No double-prefix patterns (`/api/api/...`)
   - All requests follow consistent pattern
   - Result: ✅ Confirmed

---

## Key Learnings

### Anti-Pattern: Dual Prefix Construction
```typescript
// ❌ AVOID THIS
const BASE = 'http://localhost:8620'; // No prefix
const url = `${BASE}/api${endpoint}`; // Add prefix in fetch
// Problem: Encourages inconsistent handling elsewhere
```

### Best Practice: Single Source of Truth
```typescript
// ✅ USE THIS
const BASE = 'http://localhost:8620/api'; // Include prefix
const url = `${BASE}${endpoint}`; // Use directly
// Benefit: Consistent across all files
```

### Configuration Validation
Always validate configuration at application startup:

```typescript
// In app initialization
if (!process.env.NEXT_PUBLIC_API_BASE_URL) {
  console.error('NEXT_PUBLIC_API_BASE_URL is not configured');
  process.exit(1);
}

if (!process.env.NEXT_PUBLIC_API_BASE_URL.includes('/api')) {
  console.warn('Warning: API_BASE_URL should include /api prefix');
}
```

---

## Protocol Documentation

Created comprehensive protocol at:
`/Users/mac/.claude/docs/protocols/api-url-standard.md`

This protocol provides:
1. Standard format for API URL configuration
2. Environment variable naming convention
3. Prefix inclusion rules
4. Fetch call pattern guidelines
5. Development vs production configurations
6. Testing checklist

---

## Cross-Project Applicability

This pattern is applicable to ALL FastAPI + Next.js projects:

### Projects That Should Use This Pattern
- Ürünlü (current)
- ODTÚ Connect (existing, verify alignment)
- HocamKariyer (should adopt)
- YeniZelanda (should adopt)
- All future FastAPI + Next.js stacks

### Similar Issues in Other Projects
- **EXP-0037** (ODTÚ Connect): Field mapping between API and frontend
- **EXP-0040** (HocamKariyer): Multi-layer data flow debugging
- **EXP-0045** (YeniZelanda): Mock data debugging

All these could benefit from consistent API URL standardization.

---

## Prevention Strategy

For future FastAPI + Next.js projects:

1. **Setup Template**
   - Create `.env.template` with API_BASE_URL format
   - Include clear documentation: "Include /api suffix in value"

2. **CI/CD Validation**
   - Check all fetch calls for double-prefix patterns
   - Lint rule: API_BASE_URL must end with `/api`
   - Test: Validate all endpoints before deployment

3. **Development Standards**
   - Single api.ts file with centralized configuration
   - No manual prefix construction in components
   - All environment variables documented in README

4. **Code Review**
   - Verify no new fetch calls add `/api` prefix
   - Check environment variable usage consistency
   - Validate against protocol during PR review

---

## Files Modified

| File | Change | Rationale |
|------|--------|-----------|
| `src/context/AuthContext.tsx` | Use env var with /api | Centralized config |
| `src/utils/api.ts` | Include /api in default | Single source of truth |
| `start_frontend.sh` | Add /api to env var | Consistent initialization |
| `.env.local` | Set complete URL with /api | Development convenience |
| `.env.production` | Set complete URL with /api | Production safety |

---

## Related Experiences

### Similar Problems
- **EXP-0037** (ODTÚ Connect): Field naming mismatches between API and frontend
- **EXP-0040** (HocamKariyer): Multi-layer authentication and API integration
- **EXP-0045** (YeniZelanda): Mock data causing misleading symptoms

### Similar Solutions
- **EXP-0028** (ODTÚ Connect): Configuration management in Next.js
- **EXP-0024** (ODTÚ Connect): API architecture and routing

---

## Impact Summary

| Metric | Before | After |
|--------|--------|-------|
| Configuration sources | 3 (conflicting) | 1 (unified) |
| Prefix handling methods | 2 different | 1 consistent |
| 404 errors | Yes (login/data) | None |
| Code maintenance | Difficult | Easy |
| Developer confusion | High | Low |

---

## Success Criteria

- [x] Login functionality restored
- [x] All data fetches return 200 OK
- [x] No double-prefix requests observed
- [x] Configuration documented in protocol
- [x] Environment variables properly configured
- [x] Development and production configs aligned
- [x] Team can reproduce and understand the solution

---

**Experience Created**: 2025-12-12
**Experience Status**: ✅ RESOLVED - Ready for Cross-Project Adoption
**Protocol Reference**: `/Users/mac/.claude/docs/protocols/api-url-standard.md`
**Reproducibility**: HIGH - Tested and documented pattern
