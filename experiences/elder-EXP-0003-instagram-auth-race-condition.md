# EXP-0003: Instagram Monitor - Auth Race Condition (401 on Load)

**Project**: Instagram Monitor & Analyzer
**Date**: 2026-02-27
**Category**: Bug Fix / Authentication
**Technologies**: Next.js 14, React Query, JWT, Zustand
**Keywords**: 401, race condition, auth, login, hardcoded localhost, isAuthenticated, useQuery dependency

---

## Problem Statement
Login sonrası dashboard yüklendiğinde tüm API çağrıları 401 dönüyordu.
İlk yükleme çalışmıyor, sayfa refresh gerekiyordu.

## Root Cause
**İki eş zamanlı sorun:**
1. `localhost:8000` hardcoded URL — VPS'de çalışmaz (backend port 8650'de)
2. `useQuery` hook'ları, auth token hazır olmadan (Zustand state mount'lanmadan) fire ediyordu

## Solution

### Fix 1: API instance kullan, hardcode yazma
```typescript
// YANLIŞ:
const res = await axios.get('http://localhost:8000/api/dashboard');

// DOĞRU:
import { api } from '@/lib/api';
const res = await api.get('/dashboard');
// api.ts içinde baseURL environment'tan gelir
```

### Fix 2: isAuthenticated dependency
```typescript
const { data } = useQuery({
  queryKey: ['dashboard'],
  queryFn: fetchDashboard,
  enabled: isAuthenticated,  // Token hazır olmadan çağırma!
});
```

## Lessons Learned
- `localhost:8000` hardcode büyük kırmızı bayrak — her zaman API instance kullan
- React Query `enabled` flag'i auth-gated endpoint'ler için kritik
- Zustand hydration async olabilir — `isAuthenticated` state'i kontrol et
- 401 hatası her zaman token sorunu değil; timing sorunu olabilir

## Prevention Checklist
- [ ] Yeni API çağrısı yazmadan önce: `api` instance import var mı kontrol et
- [ ] `localhost` string'i ASLA doğrudan yazma
- [ ] Auth gerektiren useQuery'lerde: `enabled: isAuthenticated` ekle
- [ ] Login redirect sonrası: token Zustand'a yazılmadan sayfa mount olmamalı
