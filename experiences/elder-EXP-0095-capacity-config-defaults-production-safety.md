# EXP-0095: Capacity Config Code Defaults Must Equal Production Values

## Metadata
- **Proje**: Borsa Trading Team
- **Tarih**: 2026-02-28
- **Kategori**: Configuration, Infrastructure, Runtime Config
- **Durum**: SOLVED ✅
- **JIRA**: BORSA-181

## Problem

PM2 restart sonrası sistem yavaşlıyordu. Backtest batch 20'ye, daemon sayısı 400'e, sentiment interval 900s'ye düşüyordu. MongoDB `system_config` collection silindiğinde veya reset edildiğinde her şey kod içindeki dev-friendly değerlere dönüyordu.

İkinci problem: `detect_active_preset()` her zaman `None` dönüyordu çünkü kod içindeki default değerler `normal.md` preset'i ile eşleşmiyordu.

## Root Cause

`PARAM_DEFS` dict'indeki `"default"` değerleri geliştirme ortamı için muhafazakâr değerlerdi:

```python
# YANLIŞ (dev minimum değerleri):
PARAM_DEFS = {
    "rnd_backtest_batch": {"default": 20, ...},    # prod=30
    "trading_max_daemons": {"default": 400, ...},   # prod=800
    "rnd_backlog_throttle": {"default": 50000, ...}, # prod=40000
    "sentiment_cycle_interval": {"default": 900, ...},# prod=600
}
```

MongoDB doc sıfırlandığında sistem bu değerlere döndü. `initialize()` DB'den yükleyemeyince PARAM_DEFS default'larını kullandı.

## Fix

PARAM_DEFS `default` değerlerini tam production değerlerine güncelle. `normal.md` preset'ini de aynı değerlerle yaz → `detect_active_preset()` artık "normal" döner.

```python
# DOĞRU (production values as defaults):
PARAM_DEFS = {
    "rnd_generate_limit":          {"default": 1000, "min": 100, "max": 5000},
    "rnd_backtest_batch":          {"default": 30,   "min": 5,   "max": 100},
    "rnd_evaluate_batch":          {"default": 500,  "min": 50,  "max": 2000},
    "rnd_backlog_throttle":        {"default": 40000,"min": 5000,"max": 200000},
    "rnd_draft_ratio":             {"default": 15,   "min": 5,   "max": 50},
    "trading_max_daemons":         {"default": 800,  "min": 10,  "max": 2000},
    "trading_watcher_interval":    {"default": 180,  "min": 30,  "max": 600},
    "sentiment_cycle_interval":    {"default": 600,  "min": 60,  "max": 3600},
    "sentiment_llm_every":         {"default": 8,    "min": 1,   "max": 32},
    "optimization_cycle_interval": {"default": 180,  "min": 60,  "max": 1800},
}
```

## Genel Kural

**"Safe default" = geliştirme minimumu DEĞİL, production minimumu olmalı.**

Runtime config sistemlerinde:
- Geliştirici makinede → düşük değerler yeterli
- Production'da → MongoDB sıfırlanınca sistem production değerlerine dönmeli
- Test: `db.system_config.drop()` → PM2 restart → sistem hâlâ production hızında çalışıyor mu?

## Ders

1. Runtime config default'ları = production minimum değerleri
2. "Preset" sistemi varsa → code defaults ile preset değerleri senkronize tut
3. MongoDB sıfırlama senaryosunu her sprint'te test et
4. `detect_active_preset()` gibi preset detection fonksiyonları tutarsızlığı yakalar → monitor et

## İlgili Dosyalar

- `borsa-trading-team/backend/app/services/engines/capacity_config.py`
- `borsa-trading-team/backend/app/services/engines/presets/normal.md`

## Anahtar Kelimeler

`runtime config`, `PARAM_DEFS`, `defaults`, `preset`, `PM2 restart`, `MongoDB reset`, `production values`, `configuration drift`
