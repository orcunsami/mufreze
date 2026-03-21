# EXP-0080: Frontend API URL, Multipart ve Renk Hataları

## Tarih
2026-02-02

## Proje
HocamClass - Transcript Analyzer

## Kategori
Frontend / API Integration / CSS

## Öğrenilen Dersler

### 1. VITE_API_URL Çift Yazım Hatası

**YANLIŞ:**
```typescript
const apiUrl = import.meta.env.VITE_API_URL || 'http://localhost:8009'
// .env: VITE_API_URL=http://localhost:8009/api/v1

// Bu çift /api/v1 yaratır!
const response = await axios.post(`${apiUrl}/api/v1/transcript/analyze`)
// Sonuç: http://localhost:8009/api/v1/api/v1/transcript/analyze ❌
```

**DOĞRU:**
```typescript
// .env içeriğini ÖNCE kontrol et!
// Eğer VITE_API_URL zaten /api/v1 içeriyorsa:
const response = await axios.post(`${apiUrl}/transcript/analyze`)
// Sonuç: http://localhost:8009/api/v1/transcript/analyze ✅
```

**Kontrol Listesi:**
- [ ] `.env` dosyasındaki `VITE_API_URL` değerini oku
- [ ] Prefix içeriyor mu kontrol et (`/api/v1`, `/api`, vs.)
- [ ] Kod yazarken buna göre path belirle

---

### 2. Axios Multipart Content-Type Hatası

**YANLIŞ:**
```typescript
const headers: Record<string, string> = {
  'Content-Type': 'multipart/form-data'  // ❌ ASLA manuel ayarlama!
}
const response = await axios.post(url, formData, { headers })
```

**DOĞRU:**
```typescript
// Axios FormData için Content-Type'ı OTOMATİK ayarlar
// Manuel ayarlamak boundary'yi bozar!
const headers: Record<string, string> = {}
if (authStore.accessToken) {
  headers['Authorization'] = `Bearer ${authStore.accessToken}`
}
const response = await axios.post(url, formData, {
  headers: Object.keys(headers).length > 0 ? headers : undefined
})
```

**Neden:**
- Axios, FormData gönderirken otomatik olarak `Content-Type: multipart/form-data; boundary=----WebKitFormBoundary...` ekler
- Manuel `Content-Type: multipart/form-data` yazınca boundary eksik kalır
- Sunucu dosyayı parse edemez, 422 veya boş data döner

---

### 3. Proje Renk Paletine Uymayan Fallback

**YANLIŞ:**
```css
.btn-primary:hover {
  background: var(--primary-dark, #2563eb);  /* ❌ Mavi - HocamClass'ta yeri yok */
}
```

**DOĞRU:**
```css
.btn-primary:hover {
  background: var(--primary-dark, #B82D30);  /* ✅ Koyu kırmızı - HocamClass primary */
}
```

**Proje Renkleri (HocamClass):**
| Değişken | Değer | Kullanım |
|----------|-------|----------|
| `--primary` | #D93538 | Ana kırmızı |
| `--primary-dark` | #B82D30 veya #CC2D30 | Hover state |

**Kontrol Listesi:**
- [ ] Projenin `main.css` veya `CLAUDE.md` dosyasında renk paletini kontrol et
- [ ] Fallback değerleri projeye uygun seç
- [ ] Mavi (#2563eb, #3B82F6) gibi genel renkler KULLANMA

---

## Özet Kurallar

1. **API URL**: `.env` dosyasını ÖNCE oku, prefix kontrolü yap
2. **Multipart**: `Content-Type: multipart/form-data` ASLA manuel yazma
3. **Renkler**: Fallback değerlerini proje paletinden seç, genel renkler kullanma

## İlgili Dosyalar
- `frontend/.env` - VITE_API_URL tanımı
- `frontend/src/pages/features/transcript/transcriptApiInterface.ts`
- `frontend/src/pages/features/transcript/TranscriptAnalyzer.vue`
- `hocamclass-web/CLAUDE.md` - CSS değişkenleri tablosu

## Tags
#frontend #api #axios #multipart #css #colors #gotcha #hocamclass
