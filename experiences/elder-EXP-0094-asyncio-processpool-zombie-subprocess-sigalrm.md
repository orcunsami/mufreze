# EXP-0094: asyncio.wait_for() Does NOT Kill OS Subprocess → SIGALRM Fix

## Metadata
- **Proje**: Borsa Trading Team
- **Tarih**: 2026-02-28
- **Kategori**: Performance, Async, Multiprocessing
- **Durum**: SOLVED ✅
- **JIRA**: BORSA-166

## Problem

`batch_backtester.py` her cycle'da 10-20 zombie process biriktiriyordu. CPU yükü giderek artıyor, backtest throughput sıfıra düşüyordu.

Symptom: `asyncio.wait_for(executor_task, timeout=360)` timeout hata fırlatıyor, ama `ps aux` incelenince aynı PID'li Python processler C extension içinde hâlâ çalışıyordu.

## Root Cause

`asyncio.wait_for()` sadece **Python Future**'ı iptal eder — **OS subprocess'ini** kill etmez.

`ProcessPoolExecutor` içinde çalışan worker fonksiyonu ayrı bir OS process (fork/spawn). Worker vectorbt/numpy gibi C extension'da takılıysa asyncio GIL'i geçemez ve cancel signal ulaşamaz. Sonuç: zombie process.

```
asyncio.wait_for(timeout=360)
    └── cancels: Python coroutine future
    ✗   does NOT kill: OS subprocess in ProcessPoolExecutor
                        └── worker stuck in C extension (numpy/vectorbt)
                            └── ZOMBIE — continues consuming CPU/RAM
```

## Fix

Worker fonksiyonunun **başında** `signal.SIGALRM` kur. SIGALRM asyncio'dan **30s önce** tetiklenir → worker kendini sonlandırır, asyncio tarafı temiz "failed" sonucu alır.

```python
# batch_backtester.py — _run_backtest_in_process() fonksiyonu içinde

import signal

_WORKER_TIMEOUT = max(30, PER_STRATEGY_TIMEOUT - 30)  # asyncio'dan 30s önce

def _alarm_handler(signum, frame):
    raise TimeoutError(f"Worker SIGALRM after {_WORKER_TIMEOUT}s")

# Worker başında:
try:
    signal.signal(signal.SIGALRM, _alarm_handler)
    signal.alarm(_WORKER_TIMEOUT)
except (OSError, AttributeError):
    pass  # Windows'ta SIGALRM yok, güvenli skip

# ... worker kodu ...

# Worker sonunda (return öncesi) alarm kapat:
try:
    signal.alarm(0)
except (OSError, AttributeError, NameError):
    pass
```

## Neden 30s Erken?

- **asyncio timeout**: 360s
- **SIGALRM**: 330s (30s önce)
- asyncio hâlâ "alive" coroutine'i var → raise'i düzgün handle eder
- Asyncio 360s'e geldiğinde process zaten ölmüş → temiz cancel

## Ders

1. `asyncio.wait_for()` + `ProcessPoolExecutor` kombinasyonu **zombie riski** taşır — her zaman SIGALRM ekle
2. C extension (numpy, pandas, vectorbt, ta-lib) kullanan worker'larda asyncio cancel çalışmaz
3. Windows'ta SIGALRM yok → `try/except (OSError, AttributeError)` ile platform-safe yap
4. POOL_WORKERS sayısı = CPU core × 0.5-0.75 (fazlası thrashing yapar)

## İlgili Dosyalar

- `borsa-trading-team/backend/app/services/strategies/batch_backtester.py`

## Anahtar Kelimeler

`asyncio`, `ProcessPoolExecutor`, `wait_for`, `SIGALRM`, `zombie`, `subprocess`, `timeout`, `vectorbt`, `C extension`, `multiprocessing`
