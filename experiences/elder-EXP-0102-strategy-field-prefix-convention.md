# EXP-0102: Strategies Collection `strategy_` Field Prefix Convention

## Metadata
- **Proje**: Borsa Trading Team
- **Tarih**: 2026-02-28
- **Kategori**: MongoDB, Data Modeling, Field Naming
- **Durum**: DOCUMENTED ✅
- **JIRA**: -

## Problem

`db.strategies.find({"status": "paper_trading"})` → 0 sonuç. Strateji var, query yanlış.
CEO agent prompt'unda `created_at` ile sorgulama: 0 match. Silent failure.

## Root Cause

`strategies` collection'daki tüm field'lar `strategy_` prefix'i taşıyor:

```python
# YANLIŞ (0 match):
{"status": "paper_trading"}
{"indicator": "ema_cross"}
{"created_at": {"$gt": cutoff}}
{"pnl": {"$lt": -5}}

# DOĞRU:
{"strategy_status": "paper_trading"}
{"strategy_indicator": "ema_cross"}
{"strategy_created_at": {"$gt": cutoff}}
{"strategy_pnl": {"$lt": -5}}
```

## Tam Field Listesi

```
strategy_id           (ID)
strategy_status       (draft/paper_trading/retired)
strategy_indicator    (ema_cross, rsi_bb, sector_rotation, ...)
strategy_timeframe    (1m, 5m, 15m, 1h, 4h, 1d)
strategy_direction    (long, short, both)
strategy_market       (BTC/USDT, ETH/USDT, ...)
strategy_sharpe       (float)
strategy_profit_factor (float)
strategy_max_drawdown (float)
strategy_trade_count  (int)
strategy_pnl          (float)
strategy_status       (string)
strategy_created_at   (datetime)
strategy_updated_at   (datetime)
strategy_hash         (string, unique)
strategy_generation_source (rnd, marketplace, manual)
```

## Neden Bu Convention?

MongoDB'de multi-collection sistemlerde field çakışmalarını önler. Aggregation pipeline'da hangi collection'dan geldiği net olur.

Bu pattern EXP-0002 (ODTÜ field naming reference) ile tutarlı: `{collection_name}_{field}`.

## Tanı

Herhangi bir query 0 döndürürse → MongoDB Compass'ta sample doc bak:

```bash
# VPS'te:
mongo borsa_db --eval "db.strategies.findOne()"
```

## Etki Noktaları

Bu prefix'i bilmeden yanlış query yapılan yerler tespit edildi:
1. `rnd_engine.py` — backlog count sorguları (2 yer)
2. `allocator.py` — viable strateji sorgusu
3. `evaluator.py` — performance sorguları
4. CEO agent prompt — `created_at` yerine `strategy_created_at`
5. Supervisor — portfolio sorguları

## Ders

1. Yeni sorgu yazmadan önce collection'dan sample doc bak
2. "0 result, no error" → field name yanlış olabilir
3. Bu convention'ı CLAUDE.md'de dokümante et (production trap)
4. grep: `grep -r '"status"' app/services/ --include="*.py"` → prefix missing olanları bul

## İlgili Dosyalar

- Tüm `borsa-trading-team/backend/app/services/` sorguları
- `borsa-trading-team/borsa-trading-team/CLAUDE.md` (production trap olarak belgelenmiş)

## Anahtar Kelimeler

`strategy_`, `field prefix`, `naming convention`, `0 result`, `silent failure`, `MongoDB query`, `collection naming`
