# EXP-0101: Daemon Coverage Bottleneck — Strategy/Daemon Ratio

## Metadata
- **Proje**: Borsa Trading Team
- **Tarih**: 2026-02-28
- **Kategori**: Trading Engine, Capacity Planning, Daemon Management
- **Durum**: SOLVED (Partial) ✅
- **JIRA**: -

## Problem

%98 zero-trade problemi yaşanıyordu. Analiz yapılınca: 2700 aktif strateji, 400 daemon. Daemon coverage = %14.8. %85 strateji hiç daemon almadı → hiç trade yapmadı.

## Root Cause

`trading_max_daemons = 400` ama strateji sayısı organik olarak 2700'e büyüdü. Daemon-strateji assignment **rotasyonel değildi** — daemon alan strateji tutar, kuyrukta yeniler bekler. Yeni stratejiler aylarca daemon alamadı.

```
active_strategies:  2700
max_daemons:         400
coverage:           14.8%
zero_trade_rate:    98.0%  ← doğrudan ilişki
```

## Fix

1. `trading_max_daemons`: 400 → 800 (capacity_config.py default)
2. `tenant_scheduler.py`: Single-org sistemde (ORG-SYSTEM) oransal pay hesabı yerine global_max'ı tam ver:

```python
# tenant_scheduler.py
async def get_org_daemon_quota(self, org_id: str) -> int:
    if org_id == "ORG-SYSTEM" and self.single_tenant_mode:
        return self.global_max_daemons  # Tüm kapasiteyi ver
    # Multi-tenant: oransal hesap
    ...
```

## Sağlık Metrikleri

```python
# trading_engine.py — status endpoint'inde raporla
daemon_coverage_pct = (active_daemons / max(active_strategies, 1)) * 100

# Değerlendirme:
# >90%: Sağlıklı
# 50-90%: Uyarı — daemon kapasitesini artır
# <50%: Kritik — önemli strateji grubu daemon alamıyor
```

## Genel Kural

**Daemon kapasitesi = en az aktif strateji sayısı. 1:1 veya üzeri hedef.**

Trading sisteminde: daemon_count << strategy_count olduğunda systemic zero-trade kaçınılmaz. Her cycle yeni strateji eklenince daemon-per-strategy oranı düşer.

## Rotasyon Önerisi

Daemon sonsuz tutma yerine, performanssız stratejilerin daemon'ını rotasyona al:

```python
# Her 4h: 0-trade stratejilerden daemon al, yeni stratejilere ver
async def rotate_idle_daemons(self):
    idle = await db.strategies.find(
        {"strategy_status": "paper_trading", "last_trade_at": {"$lt": cutoff}},
        limit=50
    )
    for strategy in idle:
        await self._release_daemon(strategy)
    await self._allocate_daemons_to_queue(50)
```

## Ders

1. Strateji üretimi ile daemon kapasitesini birlikte scale et
2. Daemon coverage = core KPI, her report'a ekle
3. Single-org sistemde oransal hesap gereksiz — tüm kapasiteyi ver
4. Idle daemon rotation: 0-trade stratejilerden daemon al, yenilere ver

## İlgili Dosyalar

- `borsa-trading-team/backend/app/services/engines/capacity_config.py`
- `borsa-trading-team/backend/app/services/engines/tenant_scheduler.py`
- `borsa-trading-team/backend/app/services/engines/trading_engine.py`

## Anahtar Kelimeler

`daemon`, `coverage`, `strategy count`, `zero trade`, `capacity`, `bottleneck`, `trading engine`, `tenant scheduler`, `rotation`
