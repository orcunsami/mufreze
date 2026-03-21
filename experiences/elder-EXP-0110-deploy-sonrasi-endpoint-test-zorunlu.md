# EXP-0110: Deploy Sonrası Endpoint Test Zorunluluğu

**Tarih**: 2026-02-28
**Proje**: Instagram Monitor (+ TÜM projeler)
**Kategori**: Workflow / Quality Assurance
**Önem**: KRİTİK — Orçun'un açık talebi

---

## Problem

Backend deploy/değişiklik sonrası endpoint'ler test edilmedi. Kullanıcı production'da sayfa açınca hataları bizzat keşfetti:

1. `GET /api/admin/dashboard/stats` → 500: `PyMongo Collection bool()` hatası (`if col` yerine `if col is not None`)
2. `GET /api/admin/users` → 500: MongoDB `ObjectId` JSON serialize edilemiyor
3. `GET /api/admin/users/{id}` → 500: Aynı ObjectId sorunu
4. `GET /api/admin/activity` → 500: Aynı ObjectId sorunu
5. `GET /api/admin/dashboard/recent-activity` → 500: ObjectId + $lookup
6. Frontend 404'ler: Sidebar ve dashboard'da var olmayan sayfalara linkler — Next.js prefetch ile hemen görünüyor

**Hata sayısı**: 6+ endpoint, 3 ayrı session gerekti.

---

## Kök Neden

- Kod yazıldı, deploy edildi ama **test edilmedi**
- Sadece değişen dosyaya bakıldı, bağlantılı tüm endpoint'ler taranmadı
- "Kod mantıklı görünüyor" = test edildi DEĞİL

---

## Çözümler

### 1. MongoDB ObjectId Serialize Pattern
```python
from bson import ObjectId
from datetime import datetime

def _s(obj):
    """Recursively convert ObjectId/datetime to JSON-safe types."""
    if isinstance(obj, list):
        return [_s(i) for i in obj]
    if isinstance(obj, dict):
        return {k: _s(v) for k, v in obj.items()}
    if isinstance(obj, ObjectId):
        return str(obj)
    if isinstance(obj, datetime):
        return obj.isoformat()
    return obj
```
Ham MongoDB doc döndürürken MUTLAKA `_s()` ile wrap et.

### 2. PyMongo Collection bool kontrolü
```python
# YANLIŞ:
result = await col.count_documents({}) if col else 0

# DOĞRU:
result = await col.count_documents({}) if col is not None else 0
```

### 3. Frontend Link 404 Kontrolü
Next.js Link hover'da prefetch yapar. Nav veya sayfada link eklerken sayfanın var olduğunu doğrula:
```bash
find frontend/src/app -name "page.tsx" | sed 's|.*/app||;s|/page.tsx||' | sort
```
Ardından nav/linklerle karşılaştır.

---

## ZORUNLU KURAL — Tüm Projelerde Geçerli

> **Bir şeyi kurduysan veya değiştirdiysen, TEST edersin. Kullanıcı test etmek zorunda DEĞİL.**

### Backend Değişikliği Sonrası Sistematik Test

```python
# test_admin_endpoints.py — her projede benzer script yaz
import urllib.request, urllib.error, json

def test_endpoints(base_url, token, endpoints):
    for path in endpoints:
        try:
            req = urllib.request.Request(
                f'{base_url}{path}',
                headers={'Authorization': f'Bearer {token}'}
            )
            res = urllib.request.urlopen(req)
            print(f'✓ 200  {path}')
        except urllib.error.HTTPError as e:
            body = e.read().decode()[:100]
            print(f'✗ {e.code}  {path}  → {body}')
```

### Kontrol Listesi (Her Deploy Sonrası)

1. **Backend restart** → `pm2 restart {service}`
2. **Health check** → `GET /health` veya `/api/health`
3. **Auth endpoint** → login çalışıyor mu?
4. **Değiştirilen tüm endpoint'ler** → 200 mu?
5. **Bağlantılı endpoint'ler** → aynı collection/service kullananlar
6. **Frontend build** → Next.js build hatası var mı?
7. **Frontend link'ler** → Eklenen linklerin sayfası var mı?

### Log İlk Kontrol
```bash
pm2 logs {service} --lines 30 --nostream | grep -E "(ERROR|Error|500)"
```

---

## Öğrenme

- "Çalışıyor gibi görünüyor" ≠ çalışıyor
- Tek dosya fix = diğer dosyalarda da aynı pattern var mı kontrol et (grep!)
- MongoDB doc döndüren HER endpoint → ObjectId var mı düşün
- Frontend'de link ekle → sayfa var mı doğrula
- **Proaktif ol**: Kullanıcının test etmesini bekleme

---

**Sonuç**: Bu tür "obvious" hatalar (serialize, null check, broken links) deploy anında test edilseydi hiç görünmezdi. Deploy = test zorunludur.
