# EXP-0107: ProcessPoolExecutor Worker Count — CPU × 0.5-0.75 Kuralı

## Metadata
- **Proje**: Borsa Trading Team
- **Tarih**: 2026-02-28
- **Kategori**: Performance, Multiprocessing, Capacity Planning
- **Durum**: SOLVED ✅
- **JIRA**: BORSA-166 (ilişkili)

## Problem

Backtest cycle'ları giderek yavaşlıyordu. POOL_WORKERS = 6 iken 4-core VPS'te CPU %100'e çıkıyor, OS process thrashing yapıyor, tüm diğer servisler yavaşlıyor. Backtest throughput arttırıyorum diye 6 worker koydum ama tam tersi oldu.

## Root Cause

CPU-bound işlemler için `ProcessPoolExecutor` core sayısını aşınca thrashing başlar:

```
VPS: 4 CPU cores
POOL_WORKERS: 6

Durum:
- 6 backtest process paralel çalışıyor
- OS 6 process'i 4 core'a schedule etmek zorunda
- Context switch overhead = net throughput DÜŞER
- Diğer PM2 processler (backend, bot) yavaşlar
- asyncio event loop sıkışır
```

## Fix

```python
# batch_backtester.py

import os

# DOĞRU — CPU sayısına göre:
cpu_count = os.cpu_count() or 4
POOL_WORKERS = max(1, int(cpu_count * 0.5))  # CPU × 0.5

# 4 core VPS → 2 worker
# 8 core VPS → 4 worker
# 16 core VPS → 8 worker
```

Ek fix kombinasyonu (birlikte yapıldı):
- POOL_WORKERS: 6 → 2
- PER_STRATEGY_TIMEOUT: 180 → 360s (daha az worker = her birine daha fazla süre)
- Batch size: 50 → 20 (daha az paralel yük)

## Neden 0.5x?

Trading sistemi multi-tasking: PM2 aynı anda backend, Telegram bot, sentiment engine, optimization engine çalıştırıyor. CPU tamamen backtest'e vermek diğerlerini öldürür.

```
CPU allocation örneği (4-core, 0.5x rule):
├── backtester workers: 2 cores (max)
├── FastAPI + uvicorn:  1 core
├── diğer PM2 procs:    1 core
└── OS overhead:        margin
```

## CPU-Bound vs IO-Bound Karşılaştırma

```python
# IO-bound (network, disk) → thread pool, daha fazla worker:
ThreadPoolExecutor(max_workers=cpu_count * 4)

# CPU-bound (vectorbt, numpy) → process pool, az worker:
ProcessPoolExecutor(max_workers=int(cpu_count * 0.5))
```

## Ders

1. CPU-bound ProcessPoolExecutor = CPU count × 0.5-0.75 (shared server)
2. "Daha fazla worker = daha hızlı" sadece IO-bound için geçerli
3. Production VPS multi-tenant: backtest diğer servisleri boğmamalı
4. POOL_WORKERS arttırınca her zaman CPU/throughput'u monitor et

## İlgili Dosyalar

- `borsa-trading-team/backend/app/services/strategies/batch_backtester.py`
- `borsa-trading-team/backend/app/services/engines/capacity_config.py` (POOL_WORKERS config)

## Anahtar Kelimeler

`ProcessPoolExecutor`, `worker count`, `CPU`, `thrashing`, `context switch`, `backtest`, `throughput`, `multiprocessing`, `capacity planning`
