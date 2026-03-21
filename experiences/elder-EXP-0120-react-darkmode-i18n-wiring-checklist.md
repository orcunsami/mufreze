# EXP-0120: React Sayfa Oluşturma — Dark/Light Mode + i18n Wiring Checklist

**Tarih**: 2026-03-02
**Proje**: Borsa Trading Team (divan-borsa)
**Dosya**: `desktop/src/renderer/pages/VastTraining.tsx`
**Durum**: SOLVED ✅
**Kategori**: Frontend / React / Tailwind

---

## Problem

`VastTraining.tsx` sayfası `borsa.orcunsamitandogan.com/vast-training`'de "boş görünüyor" diye raporlandı.

**Gerçek sebep — 2 hata bir arada:**

### Hata 1: i18n namespace kayıtlı değil

```tsx
// VastTraining.tsx
const { t } = useTranslation('vastTraining')  // namespace kullanıldı
```

```ts
// i18n.ts — namespace YOKTU
// enVastTraining import edilmemişti
// resources objesine eklenmemişti
```

`t('title')` → key string döndürüyor (`"title"`), React hata atmıyor. Bu yüzden page kısmen render oluyor ama başlık yanlış.

### Hata 2: Hardcoded dark renkler, dark: prefix yok

```tsx
// YANLIŞ — light modda invisible
<h1 className="text-xl font-bold text-white">{t('title')}</h1>

// Kart dışı elementlerde text-white → bg-gray-50 üzerinde görünmez
// Kart içi elementlerde text-white → bg-[#1e1b2e] üzerinde görünür
// Sonuç: kart "boş kutu" gibi duruyor, heading yok
```

---

## Root Cause Analizi

**Neden yakalanmadı:**
- Yalnızca syntax check yapıldı (`python3 -B -c "import ast..."`)
- Visual/behavioral doğrulama yapılmadı
- "Sayfa route'a eklendi = bitti" varsayıldı

**Neden bu kadar kolay kaçıldı:**
- Tailwind `dark: class` modunda hata atmaz — light modda yanlış renkler sessizce render olur
- i18next bulunamayan namespace için fallback key döndürür, exception atmaz
- Her ikisi de silent failure — test edilmeden fark edilmez

---

## Fix

### i18n.ts
```ts
// import ekle
import enVastTraining from './en/vastTraining.json'
import trVastTraining from './tr/vastTraining.json'

// resources'a ekle
en: { ..., vastTraining: enVastTraining }
tr: { ..., vastTraining: trVastTraining }
```

### Tailwind dark/light pattern
```tsx
// DOĞRU pattern (bu projedeki convention):
<h1 className="text-gray-900 dark:text-white">         // heading
<p  className="text-gray-500 dark:text-gray-400">      // secondary text
<div className="bg-white dark:bg-[#1e1b2e]">           // card bg
<div className="border-gray-200 dark:border-[#2a2540]"> // border
<div className="bg-gray-50 dark:bg-[#13111a]">         // input bg
<div className="bg-gray-200 dark:bg-[#2a2540]">        // progress track
```

---

## Borsa Tailwind Config

```js
// tailwind.config.js
darkMode: 'class'  // <html class="dark"> ile toggle

// Custom renkler:
'bg-dark': '#0A0A0F'
'surface-dark': '#12121A'
'elevated-dark': '#1A1A25'
'input-dark': '#211934'
```

---

## Checklist — Yeni React Sayfası Yazarken (BORSA)

Sayfa tamamlandıktan sonra şu 5 adımı kontrol et:

```
[ ] 1. useTranslation('ns') varsa → i18n.ts'e import + resources'a ekle (en+tr)
[ ] 2. Card dışı text → text-gray-900 dark:text-white (ASLA sadece text-white değil)
[ ] 3. Card bg → bg-white dark:bg-[#1e1b2e]
[ ] 4. Border → border-gray-200 dark:border-[#2a2540]
[ ] 5. App.tsx route + Sidebar entry var mı?
```

---

## Meta-Lesson

Bu hata **tahmin edilebilirdi** — light mode desteği ve i18n wiring, yeni sayfa eklerken **her seferinde** yapılması gereken mekanik adımlar. Syntax check geçmesi ≠ sayfa doğru çalışıyor.

**Önleme yöntemi:** Deploy öncesi sayfayı light modda elle gözlemle veya checklist yürüt.

---

## İlgili Deneyimler

- [EXP-0093](EXP-0093-tailwind-v4-cascade-layer-layout-break.md) — Tailwind v4 cascade layer sorunu
- [EXP-0028](EXP-0028-odtu-nextjs-i18n-switching.md) — i18n switching pattern
