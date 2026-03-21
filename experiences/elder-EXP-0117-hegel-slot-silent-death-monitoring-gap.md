# Experience 0117: Slot Silent Death / Monitoring Gap

**Date**: 2026-02-28
**Project**: Hegel
**Category**: Monitoring / Operations
**Status**: Partially Fixed (hourly check updated; fast-check gap remains)
**Technologies**: Bash, cron, hegel-version.sh, registry.json

## Problem Statement

Bir slot ("running" durumunda registry.json'da kayıtlı) sessizce ölüyor ve auto-recovery tetiklenmiyor. Saatlerce fark edilmiyor.

### Symptoms
- Registry: slot-o-b = "running", PID kaydı var
- Gerçekte: process dead, port dinlemiyor
- Hourly check: sadece slot-t-a ve slot-o-a izliyor → slot-o-b gözden kaçıyor
- Fast check (bash): yalnızca registry'deki "running" slotları kontrol ediyor ama PID validation yok

### Olay (2026-02-28)
```
02:05 - slot-o-b PID 2002897 çalışıyor
08:05 - slot-o-b dead, registry hâlâ "deployed running"
       → 6 saat fark edilmedi
```

## Root Cause

Monitoring logic sadece "beklenen" slotları izliyor, tüm registry'yi taramıyor. PID dosyası var ama process dead → `kill -0 $pid` kontrolü yapılmıyor.

## Solution

### Registry-based Monitoring
```bash
# Tüm running slotları registry'den al
RUNNING_SLOTS=$(python3 -c "
import json
r = json.load(open('versions/registry.json'))
for slot, info in r['slots'].items():
    if info.get('status') == 'running':
        print(slot)
")

for slot in $RUNNING_SLOTS; do
    pid_file="versions/$slot/server.pid"
    if [ -f "$pid_file" ]; then
        pid=$(cat $pid_file)
        if ! kill -0 $pid 2>/dev/null; then
            echo "DEAD: $slot (PID $pid not running)"
            # Auto-restart
            bash versions/hegel-version.sh restart $slot
        fi
    fi
done
```

### Hourly Check Fix (uygulandı 2026-02-28)
`deploy/hegel-hourly-check.sh` güncellendi: cross-slot live data + tüm slotları kontrol eder.

## Prevention
- Fast-check script: registry'deki TÜM "running" slotları PID + HTTP ile kontrol et
- Registry inconsistency: process dead ama status "running" → status'ü "deployed" yap + notify
- Slot başlatılırken registry'ye PID yaz, ölünce sil (şu an bazen kalmıyor)

## Key Lesson
**Registry status ≠ actual running**. Her zaman `kill -0 $pid` ile process varlığını doğrula.
