# EXP-0001: Instagram Monitor - Posts API Paginated Response Spread Error

**Project**: Instagram Monitor & Analyzer
**Date**: 2026-02-27
**Category**: Bug Fix / API Integration
**Technologies**: Next.js 14, React Query, FastAPI
**Keywords**: paginated response, spread error, items array, TypeError, useQuery, API response mismatch

---

## Problem Statement
Posts ve Reels sayfalarında `TypeError: V is not iterable` hatası.
`const filteredPosts = [...posts]` spread operatörü çalışmıyordu.

## Root Cause
Backend `/api/posts` endpoint'i paginated response döndürüyor:
```json
{ "items": [...], "total": 61, "skip": 0, "limit": 100 }
```
Frontend ise `res.data` direkt array sanıp spread ediyordu.

## Solution
```typescript
// YANLIŞ:
return res.data;

// DOĞRU:
return res.data?.items || res.data?.posts || (Array.isArray(res.data) ? res.data : []);
```

## Lessons Learned
- FastAPI'de paginated endpoint'lerde response formatı her zaman kontrol et
- Backend'den gelen response'u `console.log(res.data)` ile doğrula
- `?.items` fallback zinciri kullan: `items → posts → direct array → []`
- useQuery queryFn'de `|| []` default değeri MUTLAKA ver

## Prevention Checklist
- [ ] Yeni API endpoint yazarken: response format dokümante et (paginated mi? flat array mı?)
- [ ] Frontend'de API çağrısı yapılırken: response'u aynı session'da console'da doğrula
- [ ] Array spread (`[...data]`) öncesi: `Array.isArray(data)` kontrolü
- [ ] Backend değişikliğinde: Frontend consumer'larını kontrol et
