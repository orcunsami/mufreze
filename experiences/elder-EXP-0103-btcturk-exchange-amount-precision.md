# EXP-0103: BTCTurk Quantity Precision — `exchange.amount_to_precision()` Zorunlu

## Metadata
- **Proje**: Borsa Trading Team
- **Tarih**: 2026-02-28
- **Kategori**: Real Trading, Exchange Integration, CCXT
- **Durum**: SOLVED ✅
- **JIRA**: -

## Problem

BTCTurk API order reject: `"InvalidOrder: Amount too precise"`. Manual hesaplanan quantity ile order gönderdik, exchange reddetti.

## Root Cause

Her exchange'in her symbol için kendi precision kuralı var:

```
BTCTurk BTC/TRY:  amount precision = 6 decimal places
BTCTurk ETH/TRY:  amount precision = 4 decimal places
BTCTurk ADA/TRY:  amount precision = 0 decimal places (integer!)
BTCTurk SHIB/TRY: amount precision = -5 (lots of 100000)
```

Manual hesap:
```python
# YANLIŞ — her exchange farklı kuralı var:
quantity = math.floor(raw_qty * 100) / 100   # BTCTurk ADA/TRY'de YANLIŞ
quantity = round(raw_qty, 6)                  # Bazı semboller için çalışmaz
```

## Fix

CCXT'nin built-in precision metodunu kullan:

```python
# DOĞRU (her exchange, her symbol için otomatik):
quantity = exchange.amount_to_precision(symbol, raw_qty)
price    = exchange.price_to_precision(symbol, price)

# Örnek kullanım:
async def place_order(self, symbol: str, side: str, amount: float, price: float):
    precise_amount = self.exchange.amount_to_precision(symbol, amount)
    precise_price  = self.exchange.price_to_precision(symbol, price)

    order = await self.exchange.create_order(
        symbol=symbol,
        type='limit',
        side=side,
        amount=float(precise_amount),
        price=float(precise_price)
    )
```

## Exchange Precision Nasıl Öğrenilir?

```python
# Markets yükle:
await exchange.load_markets()

# Symbol precision'ı gör:
market = exchange.markets["BTC/TRY"]
print(market['precision'])  # {'amount': 6, 'price': 2}
print(market['limits'])     # {'amount': {'min': 0.0001, 'max': 100}}
```

## Genel Kural

**Exchange işlemlerinde ASLA manual rounding kullanma. Her zaman:**
- `exchange.amount_to_precision(symbol, amount)`
- `exchange.price_to_precision(symbol, price)`

Bu metodlar exchange'in markets tablosundaki precision rules'u kullanır — her symbol için doğru.

## Ders

1. Exchange precision = exchange-specific, symbol-specific bilgi
2. CCXT `amount_to_precision()` = doğru yol, her zaman
3. "InvalidOrder: Amount too precise" = precision ihlali habercisi
4. `load_markets()` çağrılmadan precision metodları çalışmaz — startup'ta yükle

## İlgili Dosyalar

- `borsa-trading-team/backend/app/services/trading/real_trading.py`
- `borsa-trading-team/backend/app/services/market_data/ccxt_collector.py`

## Anahtar Kelimeler

`BTCTurk`, `CCXT`, `precision`, `amount_to_precision`, `price_to_precision`, `InvalidOrder`, `exchange`, `symbol precision`
