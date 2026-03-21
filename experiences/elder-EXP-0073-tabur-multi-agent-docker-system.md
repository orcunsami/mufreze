# EXP-0073: TABUR Multi-Agent Docker Sistemi

**Tarih**: 2026-01-06
**Proje**: x-twitter (test case)
**Kategori**: Infrastructure, Multi-Agent, Docker

## Özet

TABUR sistemi, Serasker (komutan) ve Nefer (worker) olmak üzere iki ayrı Docker container'dan oluşan multi-agent mimari. Serasker emir yazar, Nefer işler ve rapor yazar.

## Mimari

```
Mac (Docker Host)
├── tabur-serasker (Claude Code)
│   └── /workspace/ → Projelere erişim
├── tabur-nefer (Claude Code)
│   └── /workspace/ → Aynı projeler
└── /iletisim/ (shared volume)
    ├── emirler/   → EMR-XXX.json
    ├── raporlar/  → RPR-XXX.json
    ├── islendi/   → Tamamlanan emirler
    ├── arsiv/     → Arşiv
    ├── state.json → Durum
    └── nefer.log  → Daemon logları
```

## Protokol

### Emir Yazma (Serasker)
```json
{
  "emir_id": "EMR-XXX-001",
  "timestamp": "ISO8601",
  "oncelik": "yuksek|orta|dusuk",
  "proje": "proje-adi",
  "proje_yolu": "/workspace/proje",
  "gorev": {
    "baslik": "Kısa açıklama",
    "detay": "Detaylı talimatlar",
    "komutlar": ["cmd1", "cmd2"]
  },
  "durum": "beklemede"
}
```

### Rapor Okuma (Serasker)
```bash
ls /iletisim/raporlar/RPR-*.json
cat /iletisim/raporlar/RPR-XXX.json
```

## Karşılaşılan Sorunlar ve Çözümler

### 1. Nefer İzin Sorunu
**Problem**: Nefer'deki Claude, Bash komutları için izin bekliyor
**Çözüm**: `~/.claude/settings.json` içinde:
```json
{
  "permissions": {
    "allow": ["Bash", "Read", "Write", "Edit"]
  }
}
```

### 2. Rapor Yazma İzni
**Problem**: Claude rapor dosyası yazamıyor
**Çözüm**: `nefer-daemon.sh`'de raporu daemon'ın kendisi yazıyor (permission bypass)

### 3. Takılma Tespiti
**Problem**: Nefer'in takılıp takılmadığı anlaşılamıyor
**Çözüm**:
```bash
stat /iletisim/nefer.log | grep Modify
# Timestamp eski ise → takılmış
docker restart tabur-nefer
```

### 4. pytest-asyncio Uyumsuzluğu
**Problem**: 0.23.x versiyonu `tests/__init__.py` ile uyumsuz
**Çözüm**: `pip install pytest-asyncio==0.21.1`

### 5. Celery Eksik
**Problem**: Task dosyaları var ama Celery requirements'ta yok
**Çözüm**: `requirements.txt`'e `celery==5.3.6` ekle

### 6. Import Yapısı
**Problem**: `app.tasks.twitter_tasks` patch edilemiyor
**Çözüm**:
- `app/__init__.py`'ye `from . import tasks` ekle
- `app/tasks/__init__.py`'ye submodule import ekle

## Serasker Kuralları

| YAPMA | YAP |
|-------|-----|
| ❌ Direkt kod yazma | ✅ Emir yaz |
| ❌ pytest çalıştırma | ✅ Nefer'e yaptır |
| ❌ Nefer yerine iş yapma | ✅ Rapor oku, özetle |

## Test Sonucu

x-twitter projesi için:
- 15 Celery testi yazıldı
- twitter_tasks.py: %0 → %88 coverage
- summary_tasks.py: %0 → %97 coverage
- Hedef %70+ → Başarılı

## İlgili Dosyalar

- `~/.claude/CLAUDE.md` → TABUR bölümü eklendi (v5.2)
- `~/.claude/tabur/` → Docker, scripts, profiles
- `/iletisim/` → Shared communication volume

## Tags

#multi-agent #docker #tabur #serasker #nefer #celery #pytest #coverage

## Update: MAC-80/81 — Komutan Response Detection + Task Polling

### Problem: Fragile "3 unchanged panes = done" Parsing (MAC-80)
Original Komutan response detection used "3 consecutive unchanged tmux pane captures = done" heuristic. This broke when output changed slowly or commands produced no visible output.

**Fix: Explicit completion markers**
```python
# Komutan writes explicit marker when done
COMPLETION_MARKER = "###KOMUTAN_DONE###"

# Instead of watching for pane stability:
def wait_for_completion(session, timeout=1800):
    deadline = time.time() + timeout
    while time.time() < deadline:
        pane_content = capture_pane(session)
        if COMPLETION_MARKER in pane_content:
            return extract_result(pane_content)
        time.sleep(0.5)
    raise TimeoutError("Komutan did not complete within timeout")
```

### Problem: TABUR Tasks Sent But Results Never Retrieved (MAC-81)
Tasks were sent to TABUR but the system never polled for completion. Results were lost.

**Fix: Background polling with notification**
```python
import asyncio

async def send_and_wait(task: dict, timeout: int = 1800) -> dict:
    """Send task to TABUR and poll for completion with notification."""
    task_id = await send_to_tabur(task)

    # Background polling
    deadline = asyncio.get_event_loop().time() + timeout
    while asyncio.get_event_loop().time() < deadline:
        status = await get_task_status(task_id)

        if status["done"]:
            await notify_user(f"Task complete: {task['baslik']}")
            return status["result"]

        await asyncio.sleep(0.5)  # 500ms polling interval

    await notify_user(f"Task TIMEOUT: {task['baslik']}")
    raise TimeoutError(f"Task {task_id} timed out after {timeout}s")
```

**Key Parameters:**
- Polling interval: 500ms (configurable via config.ini)
- Timeout: 30 minutes (1800 seconds)
- Notification on both completion AND timeout
