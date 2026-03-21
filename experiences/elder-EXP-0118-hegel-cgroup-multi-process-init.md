# Experience 0118: cgroup Multi-Process Init (Hegel Slots)

**Date**: 2026-02-28
**Project**: Hegel
**Category**: Infrastructure / Resource Control
**Status**: Resolved
**Technologies**: cgroups v2, Bash, resource-control.sh, systemd

## Problem Statement

cgroup resource control yalnızca ana production process'i kapsıyordu. Slot'lardaki Julia process'leri cgroup dışında kalıyor → CPU limit uygulanmıyor → sistem yavaşlıyor.

### Symptoms
- `/api/resources` endpoint: `in_cgroup: false`
- CPU limit ayarlanmış ama slot process'leri etkilenmiyor
- Slot başladıktan sonra cgroup membership kaybolabiliyor

## Root Cause

`resource-control.sh` yalnızca tek bir PID'yi (production Julia) cgroup'a ekliyordu. Slot process'leri `versions/hegel-version.sh start` ile ayrı başlatılıyor → cgroup'a otomatik eklenmiyorlar.

## Solution

`deploy/resource-control.sh` güncellendi (2026-02-28):
```bash
# Tüm Julia process'lerini cgroup'a ekle
for pid in $(pgrep -f "julia.*scripts/run_server"); do
    echo $pid > /sys/fs/cgroup/hegel/cgroup.procs
done

# Slot process'leri de
for slot in slot-o-a slot-o-b slot-t-a slot-t-b; do
    pid_file="/usr/local/main/hegel/versions/$slot/server.pid"
    if [ -f "$pid_file" ]; then
        pid=$(cat $pid_file)
        if kill -0 $pid 2>/dev/null; then
            echo $pid > /sys/fs/cgroup/hegel/cgroup.procs 2>/dev/null
        fi
    fi
done
```

### Verification
```bash
curl http://localhost:8082/api/resources | python3 -m json.tool
# in_cgroup: true için:
cat /sys/fs/cgroup/hegel/cgroup.procs
# PID listede görünmeli
```

## Prevention
- `hegel-version.sh start` sonunda yeni PID'yi cgroup'a ekle
- Hourly check: `in_cgroup` durumunu kontrol et, false ise auto-fix (resource-control.sh init)
- resource-api.py `/api/resources/init` endpoint'i tüm Julia process'lerini ekler (kullan)

## Related
- Monitoring check: `curl http://localhost:8082/api/resources | jq '.in_cgroup'`
- Fix endpoint: `curl -X POST http://localhost:8082/api/resources/init`
