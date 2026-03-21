# EXP-0104: PM2 Altında `print()` Görünmez — `logging` Kullan

## Metadata
- **Proje**: Borsa Trading Team (ve tüm PM2 Python deployları)
- **Tarih**: 2026-02-28
- **Kategori**: DevOps, Debugging, PM2, Python Logging
- **Durum**: DOCUMENTED ✅
- **JIRA**: -

## Problem

Production'da debug yapılamıyordu. `print(f"Council decision: {decision}")` ile eklenen debug mesajları `pm2 logs borsa-backend` çıktısında hiç görünmüyordu. Sistemi anlayamadan kör debug.

## Root Cause

PM2 Python processlerinde stdout'u yakalıyor ama Python `print()` buffered stdout kullanıyor. PM2'nin log mekanizması ile uyumsuz veya buffer flush olmadan process sonlanıyor.

FastAPI + uvicorn kombinasyonunda `print()` bazı durumlarda PM2 log sistemine hiç ulaşmıyor.

## Fix

Her Python modülünde `logging` kullan:

```python
# YANLIŞ (PM2'de görünmeyebilir):
print(f"Strategy {strategy_id} generated")
print(f"Debug: {value}")

# DOĞRU:
import logging
logger = logging.getLogger(__name__)

logger.info(f"Strategy {strategy_id} generated")
logger.debug(f"Debug: {value}")
logger.warning(f"Threshold exceeded: {value}")
logger.error(f"Failed to process: {error}")
```

## Logging Konfigürasyonu (main.py)

```python
import logging

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(name)s] %(levelname)s: %(message)s",
    handlers=[logging.StreamHandler()]  # stdout'a yaz, PM2 yakalar
)
```

## PM2 Log Komutları

```bash
# Tüm loglar
pm2 logs borsa-backend

# Sadece error
pm2 logs borsa-backend --err

# Son N satır
pm2 logs borsa-backend --lines 100

# Canlı takip
pm2 logs borsa-backend -f
```

## Log Level Rehberi

| Level | Ne Zaman |
|-------|---------|
| `DEBUG` | Geliştirme debug'ı (production'da kapalı) |
| `INFO` | Normal işlem akışı (strategy generated, daemon started) |
| `WARNING` | Threshold aşımı, beklenmedik ama tolere edilebilir durum |
| `ERROR` | İşlem başarısız, takip gerekli |
| `CRITICAL` | Sistem durabilir seviyede hata |

## Ders

1. PM2 deploy → `print()` kullanma, `logging.getLogger(__name__)` kullan
2. Her modülde `logger = logging.getLogger(__name__)` en üstte tanımla
3. Level'ları doğru kullan: debug = development only, info = production flow
4. `pm2 logs --err` sadece error ve critical gösterir — quick check için

## İlgili Dosyalar

- `borsa-trading-team/backend/app/main.py` (logging config)
- Tüm `borsa-trading-team/backend/app/services/` modülleri

## Anahtar Kelimeler

`PM2`, `print`, `logging`, `invisible`, `stdout`, `buffer`, `debug`, `Python logging`, `getLogger`
