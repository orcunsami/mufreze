# EXP-0098: Draft Backlog Hard Cap + Purge Guard Bug — Generation Blocked

## Metadata
- **Proje**: Borsa Trading Team
- **Tarih**: 2026-02-28
- **Kategori**: Trading Engine, RnD Engine, Strategy Generation
- **Durum**: SOLVED ✅
- **JIRA**: BORSA-198

## Problem

Strateji generation tamamen durmuştu. Logs: "Draft backlog at 25,000 (limit: 25,000) — skipping generation". Ama draft cleanup da çalışmıyor, eski draft'lar temizlenmiyor → sonsuz blokaj.

## Root Cause — İki Ayrı Bug

### Bug 1: Hard Cap Değeri Çok Düşük
`rnd_backlog_throttle = 30000` ama production 40K'da olmalıydı. 30K'da throttle tetiklenip generation durdu.

### Bug 2: Purge Guard Paradoksu
```python
# YANLIŞ — Mantıksal hata:
async def cleanup_drafts(self):
    draft_count = await db.strategies.count({"strategy_status": "draft"})
    if draft_count <= self.backlog_limit:   # ← Eğer doluysa cleanup ÇALIŞMIYOR!
        return
    # cleanup kodu...
```

Guard şunu söylüyor: "Backlog dolmamışsa cleanup'a gerek yok." Ama backlog dolu olduğunda guard `draft_count <= limit` = False → `return` → cleanup çalışmıyor. **Tam tersine çalışıyor.**

Ayrıca: Stale draft'lar (48h+ güncellenmemiş) hiç temizlenmiyordu.

## Fix

```python
# DOĞRU — Guard kaldırıldı, backlog dolunca daha agresif:
async def cleanup_drafts(self):
    draft_count = await db.strategies.count({"strategy_status": "draft"})

    # Hard cap varsa agresif temizle
    if draft_count >= self.backlog_limit:
        logger.warning(f"Backlog at cap ({draft_count}), aggressive purge")
        # En eski 5000 draft'ı sil
        await _purge_oldest_drafts(5000)

    # Her zaman: 48h stale draft'ları temizle
    stale_cutoff = datetime.utcnow() - timedelta(hours=48)
    await db.strategies.delete_many({
        "strategy_status": "draft",
        "created_at": {"$lt": stale_cutoff}
    })
```

Ek fix: `rnd_backlog_throttle` default: 30K → 40K.

## Genel Kural

**Cleanup/purge logic, "dolunca çalışma" değil, "dolunca daha agresif çalış" olmalı.**

```
Kötü: "backlog < limit ise cleanup skip"
İyi:  "her zaman stale olanları temizle, backlog dolu ise ekstra agresif purge"
```

## Ders

1. Cleanup guard'ını iki kez oku: "dolu iken de çalışıyor mu?"
2. Hard cap = production max × 1.5-2.0 (tam production değeri değil)
3. Stale entry purge'ı backlog doluluk durumundan bağımsız çalışmalı
4. Backlog dolu → alarm + agresif cleanup, DUR + blokaj değil

## İlgili Dosyalar

- `borsa-trading-team/backend/app/services/engines/rnd_engine.py`
- `borsa-trading-team/backend/app/services/strategies/batch_backtester.py`

## Anahtar Kelimeler

`draft backlog`, `purge`, `cleanup`, `guard`, `backlog throttle`, `generation blocked`, `stale draft`, `hard cap`, `paradox`
