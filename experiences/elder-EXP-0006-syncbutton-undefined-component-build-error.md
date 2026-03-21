# EXP-0006: Undefined Component Reference Build Crash (SyncButton)

**Project**: Instagram Monitor & Analyzer
**Date**: 2026-02-27
**Category**: Bug Fix / Frontend Build
**Technologies**: Next.js 14, TypeScript, React
**Keywords**: ReferenceError, component undefined, build error, SyncButton, JSX, declaration order

---

## Problem Statement
`next build` sırasında crash: `ReferenceError: Cannot access 'SyncButton' before initialization`
`accounts/page.tsx`'de `<SyncButton accountId={...} />` kullanılıyordu ama component tanımlanmamıştı.

## Root Cause
Başka bir refactoring sırasında SyncButton component'i silinmişti ama JSX'te referans kalmıştı.
TypeScript compile-time'da bunu yakalamıyor (JSX component dinamik olabilir).
Next.js build time'da yakalıyor.

## Solution
Component'i kullanmadan önce tanımla:

```typescript
// 1. Önce tanımla (export default fonksiyonun ÜSTÜNDE)
function SyncButton({ accountId }: { accountId: string }) {
  const queryClient = useQueryClient();
  const [synced, setSynced] = useState(false);

  const { mutate, isPending } = useMutation({
    mutationFn: () => api.post(`/accounts/${accountId}/fetch`),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['accounts'] });
      setSynced(true);
      setTimeout(() => setSynced(false), 3000);
    },
  });

  return (
    <button onClick={() => mutate()} disabled={isPending}>
      {isPending ? <Loader2 /> : synced ? <CheckCircle2 /> : <RefreshCw />}
      {isPending ? 'Syncing...' : synced ? 'Synced!' : 'Sync Account'}
    </button>
  );
}

// 2. Sonra ana component
export default function AccountsPage() {
  // ...
  return <SyncButton accountId={id} />;
}
```

## Lessons Learned
- React component'lerini kullanmadan önce tanımla (hoisting çalışmaz)
- `bun run build` veya `next build` build öncesi mutlaka çalıştır
- Büyük refactoring sonrası: tüm component referanslarını grep ile kontrol et
- TypeScript bu hatayı her zaman compile-time'da yakalamaz — build gerekli

## Prevention Checklist
- [ ] Yeni component kullanmadan önce: dosyada tanımlı mı kontrol et
- [ ] Refactoring sonrası: `grep -r "ComponentName" src/` ile referans ara
- [ ] Deploy öncesi: `bun run build` çalıştır (local build zorunlu)
- [ ] Component dosyaları bölünecekse: barrel export (index.ts) kullan
