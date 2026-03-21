# EXP-0073: SOCED Docker Test - Time Optimization

**Date:** 2026-01-03
**Project:** SOCED (soced-development)
**Category:** Testing Best Practices

## Problem

Docker simulation testlerinde Daily Brief zamanini 7-8 dakika sonrasina ayarlayarak gereksiz bekleme suresi yaratildi. Kullanici zaman kaybindan rahatsiz oldu.

## Root Cause

Test senaryolari icin settings.json'daki `daily_time` degerini uzak bir zamana (ornegin 08:55, 09:10) ayarladim. Bu, testin tamamlanmasi icin uzun bekleme sureleri gerektirdi.

## Solution

**Kural:** Test icin `daily_time` her zaman mevcut zamandan **1-2 dakika** sonrasina ayarlanmali.

```bash
# Dogru yaklasim
TZ='Pacific/Auckland' date '+%H:%M'  # Ornegin 10:30 dondurur
# settings.json'a "10:32" yaz (sadece 2 dk sonra)
```

## Test Checklist

1. `./clean_test.sh` ile temizle
2. `TZ='Pacific/Auckland' date '+%H:%M'` ile zamanı gor
3. `settings.json`'da `daily_time`'i mevcut zaman + 5-8 dk yap
4. `docker compose restart`
5. Test email'lerini hizla ekle
6. Periodic report'lari bekle
7. Daily Brief'i bekle (max 5-8 dk)

## Email Format Tutarliligi

Ayni session'da email formatlarinin tutarsiz oldugu tespit edildi:
- Eski: `[SOCED] Periodic Report - 2 emails processed`
- Eski: `[SOCED] MALICIOUS DETECTED - 2 emails`

Yeni tutarli format:
- `[SOCED] Periodic Report - Emails: X - Y Malicious`
- `[SOCED] Daily Report - Emails: X - Y Malicious`

## Files Created

- `simulation/vps-docker/clean_test.sh` - Test temizleme scripti
- `simulation/vps-docker/TEST_MANUAL.md` - Test proseduru

## Key Learnings

1. **Kullanici zamani degerli** - 8 dk beklemek yerine 2 dk'ya indir
2. **Format tutarliligi** - Periodic ve Daily ayni formatta olmali
3. **Dokumantasyon** - Test prosedurlerini yaz, clean script olustur
4. **soced.md guncel tutulmali** - Diyagramlar ve API degisiklikleri yansisin

## Tags

`soced`, `docker`, `testing`, `time-optimization`, `email-format`
