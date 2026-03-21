# EXP-0097: OHLCV Cache Stale Data — Per-Timeframe TTL Zorunlu

## Metadata
- **Proje**: Borsa Trading Team
- **Tarih**: 2026-02-28
- **Kategori**: Trading Engine, Caching, Data Quality
- **Durum**: SOLVED ✅
- **JIRA**: BORSA-199

## Problem

Strateji sinyalleri yanlış üretiliyordu. Data quality endpoint'i %93 OHLCV stale gösteriyordu (60 cache entry'den 56'sı stale). Trading sistemi yanlış mum verileri ile BUY/SELL kararı veriyordu.

## Root Cause

`ohlcv_cache.py` tüm timeframe'ler için **global TTL** kullanıyordu. 5m candles de 1h candles de aynı TTL'ye tabi. 5m candles her 5 dakikada yeni mum üretir; eski global TTL henüz expire etmemiş → stale data devam etmiş.

```
Global TTL = 3600s (1 saat)

BTC/USDT 5m  → son mum 23 dakika önce  → cache "fresh" görünüyor ← YANLIŞ (stale)
BTC/USDT 1h  → son mum 40 dakika önce  → cache "fresh" görünüyor ✓ DOĞRU
BTC/USDT 4h  → son mum 3.5 saat önce  → cache "fresh" görünüyor ← YANLIŞ (stale)
```

## Fix

Her timeframe için bağımsız TTL:

```python
# ohlcv_cache.py

TIMEFRAME_TTL = {
    "1m":  60,      # 1 dakika
    "3m":  180,     # 3 dakika
    "5m":  300,     # 5 dakika
    "15m": 900,     # 15 dakika
    "30m": 1800,    # 30 dakika
    "1h":  3600,    # 1 saat
    "2h":  7200,    # 2 saat
    "4h":  14400,   # 4 saat
    "6h":  21600,   # 6 saat
    "8h":  28800,   # 8 saat
    "12h": 43200,   # 12 saat
    "1d":  86400,   # 1 gün
}

def get_ttl(timeframe: str) -> int:
    return TIMEFRAME_TTL.get(timeframe, 3600)  # default 1h

def is_stale(entry: dict) -> bool:
    timeframe = entry.get("timeframe", "1h")
    ttl = get_ttl(timeframe)
    age = time.time() - entry.get("fetched_at", 0)
    return age > ttl
```

## Etki Analizi

Trading sistemindeki %98 zero-trade probleminin %5 bileşeni OHLCV stale data idi. Yanlış sinyal → council rejection → trade yok.

## Genel Kural

**Time-series cache'i**: Her veri boyutunun kendi doğal güncelleme periyodu var. Cache TTL = veri periyodunun 1.0x–1.5x'i olmalı. Global TTL = en hızlı timeframe veya en yavaş timeframe'e göre ayarlanmak zorunda → ikisi de yanlış.

## Ders

1. OHLCV cache her zaman per-timeframe TTL kullanmalı
2. "Stale" tanımı: `age > timeframe_period × multiplier`
3. Data quality endpoint (health check) ile stale rate'i izle
4. Stale rate > %20 olduğunda alert üret

## İlgili Dosyalar

- `borsa-trading-team/backend/app/services/engines/ohlcv_cache.py`
- `borsa-trading-team/backend/app/routers/engine.py` (data-quality endpoint)

## Anahtar Kelimeler

`OHLCV`, `cache`, `TTL`, `stale`, `timeframe`, `per-timeframe`, `candles`, `trading signals`, `data quality`
