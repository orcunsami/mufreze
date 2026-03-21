# EXP-0105: Real Trading SL/TP — TRY↔USDT Currency Mismatch

## Metadata
- **Proje**: Borsa Trading Team
- **Tarih**: 2026-02-28
- **Kategori**: Real Trading, BTCTurk, Currency
- **Durum**: SOLVED ✅
- **JIRA**: -

## Problem

BTCTurk'te açılan pozisyonlar beklenmedik anlarda kapanıyordu veya kapanması gerekirken kapanmıyordu. SL/TP trigger yanlış hesaplanıyordu.

## Root Cause

BTCTurk TRY bazlı işlem yapıyor. Ama SL/TP hesabı USDT proxy fiyatı üzerinden yapılıyordu:

```python
# YANLIŞ:
entry_price = trade.entry_price_usdt      # USDT bazlı
current_price = ccxt_close_try / usd_try  # USDT'ye çevirmeye çalışıyor
pnl_pct = (current_price - entry_price) / entry_price * 100

# Problem:
# 1. USD/TRY kuru anlık değişiyor
# 2. Çift dönüşüm hata biriktirir
# 3. SL/TP tetikleme zamanlaması kayıyor
```

## Fix

Aynı dövizde karşılaştır. Entry TRY → exit TRY:

```python
# DOĞRU:
entry_price_try = trade.entry_price_try     # TRY bazlı entry fiyatı
current_price_try = ohlcv_close_try         # TRY bazlı OHLCV close

pnl_pct = (current_price_try - entry_price_try) / entry_price_try * 100

# SL/TP:
STOP_LOSS_PCT = -2.0    # %2 kayıp
TAKE_PROFIT_PCT = 4.0   # %4 kar

if pnl_pct <= STOP_LOSS_PCT:
    await self._close_position(strategy, "stop_loss")
elif pnl_pct >= TAKE_PROFIT_PCT:
    await self._close_position(strategy, "take_profit")
```

## DB'de Sakla

```python
# Trade document'ında her iki dövizi de sakla:
trade_doc = {
    "entry_price_try": 2_345_000.0,    # BTCTurk'ten gelen TRY fiyatı
    "entry_price_usdt": 65_420.0,      # Kayıt için USDT (exchange rate anında)
    "sl_price_try": 2_298_100.0,       # SL trigger fiyatı TRY
    "tp_price_try": 2_438_800.0,       # TP trigger fiyatı TRY
    "currency": "TRY",                 # Açık belirtme
}
```

## Genel Kural

**Trading sisteminde: Entry ve exit fiyatları AYNI dövizde olmalı. Dönüşüm = hata.**

```
Kötü:  entry_usdt → compare → exit_try → convert → pnl_usdt
İyi:   entry_try  → compare → exit_try →           pnl_try (pct)
```

## Ders

1. Exchange bazlı işlemde o exchange'in native dövizini kullan
2. Currency conversion = ek hata kaynağı, mümkünse önle
3. Her fiyat field'ında dövizi açıkça belirt (`_try`, `_usdt` suffix)
4. SL/TP her zaman entry ile aynı dövizde hesapla

## İlgili Dosyalar

- `borsa-trading-team/backend/app/services/trading/real_trading.py`
- `borsa-trading-team/backend/app/services/engines/trader_daemon.py`

## Anahtar Kelimeler

`SL/TP`, `stop loss`, `take profit`, `TRY`, `USDT`, `currency mismatch`, `BTCTurk`, `real trading`, `price comparison`
