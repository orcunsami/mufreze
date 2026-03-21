# EXP-0096: Dual Viable Threshold Mismatch — Silent Zero Allocation

## Metadata
- **Proje**: Borsa Trading Team
- **Tarih**: 2026-02-28
- **Kategori**: Trading Engine, Strategy Allocation, Configuration
- **Durum**: SOLVED ✅
- **JIRA**: BORSA-178

## Problem

"viable=0" — hiç strateji paper trading'e geçemiyordu. Backtester "viable" işaretledi, logs "allocation cycle complete" dedi, ama paper_trading stratejisi hâlâ sıfır.

Debug trace:
1. `batch_backtester.py`: sharpe ≥ 0.4 → `is_viable = True` ✅
2. `allocator.py turbo_allocate()`: `min_sharpe=1.0` → tüm strateji reddedildi ✗

İki ayrı gating sistemi, farklı eşikler, sessiz çakışma.

## Root Cause

Pipeline'da iki ayrı viable check:

```
RnD Engine
    └── batch_backtester.py → is_viable(sharpe >= 0.4)   ← önceki session'da düzeltildi
            └── viable strategies → MongoDB

Allocator Cycle
    └── allocator.py → turbo_allocate(min_sharpe=1.0)    ← hâlâ eski değer
            └── 0 strategies passed → 0 paper_trading
```

Backtester 0.4 eşiğini geçen stratejiyi viable olarak işaretledi. Allocator 1.0 eşiğini geçmediği için reddetti. **İki sistem arasında sessiz uyumsuzluk**.

## Fix

```python
# allocator.py — turbo_allocate() parametrelerini backtester ile senkronize et

# ÖNCE (yanlış, çok kısıtlayıcı):
async def turbo_allocate(
    self,
    count: int = 500,
    min_sharpe: float = 1.0,    # ← çok yüksek, bear market'ta 0 allocation
    min_pf: float = 1.1,
    max_dd: float = 25.0,
    min_trades: int = 10,
    ...
):

# SONRA (backtester ile tutarlı):
async def turbo_allocate(
    self,
    count: int = 500,
    min_sharpe: float = 0.4,    # ← batch_backtester.py is_viable() ile aynı
    min_pf: float = 1.05,
    max_dd: float = 40.0,
    min_trades: int = 5,
    ...
):
```

## Genel Pattern

**Pipeline'da birden fazla filter/gate varsa → tümünü aynı anda güncelle veya tek config'den oku.**

```
Kötü:
    Gate A (backtester): sharpe >= 0.4 → viable=True
    Gate B (allocator):  sharpe >= 1.0 → rejected
    Sonuç: Sessiz 0-allocation. No error, no log.

İyi:
    VIABLE_SHARPE_MIN = 0.4  # Tek kaynak
    Gate A: sharpe >= VIABLE_SHARPE_MIN
    Gate B: sharpe >= VIABLE_SHARPE_MIN
    Sonuç: Tutarlı
```

## Tanı Sorusu

Allocation 0 döndüğünde ilk sorular:
1. `backtester.is_viable()` eşikleri neler?
2. `allocator.turbo_allocate()` eşikleri neler?
3. Bu iki set birbiriyle tutarlı mı?

## Ders

1. Çok aşamalı pipeline'da her gate'in eşiklerini belgele
2. Eşik değiştirince tüm gate'leri kontrol et
3. Mümkünse tüm gate'ler aynı config sabitinden oku (tek kaynak)
4. Silent zero-result her zaman multi-gate mismatch işareti olabilir

## İlgili Dosyalar

- `borsa-trading-team/backend/app/services/strategies/allocator.py`
- `borsa-trading-team/backend/app/services/strategies/batch_backtester.py`

## Anahtar Kelimeler

`allocation`, `viable`, `threshold`, `sharpe`, `pipeline gate`, `mismatch`, `silent failure`, `zero allocation`, `backtester`
