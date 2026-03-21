# Experience 0115: hegel-version.sh Restart — Port Conflict Bug

**Date**: 2026-03-01
**Project**: Hegel
**Category**: Infrastructure / Process Management
**Status**: Resolved (manual fix; script fix pending)
**Technologies**: Julia, Bash, hegel-version.sh, HTTP.jl

## Problem Statement

`hegel-version.sh restart <slot>` komutu çağrıldığında veya auto-restart tetiklendiğinde, eski Julia process ölmeden yeni bir process başlatılıyor. Bu durum port çakışmasına yol açıyor (EADDRINUSE).

### Symptoms
- Auto-restart sonrası iki Julia process aynı anda çalışıyor
- Port dinlenmiyor (curl exit 7 / exit 200000)
- PID dosyası eski PID'yi tutuyor (process hâlâ alive)
- HTTP server asla başlamıyor — port zaten başka process tarafından tutuluyor
- Log: julia başladı ama HTTP listen yok

### Örnek Olay (2026-03-01 07:05)
```
07:05:40 - Otomatik restart → PID 3585863 başlatıldı
07:06:12 - İKİNCİ Julia process başlatıldı (PID 3586988) — port çakışması
07:07:xx - Manuel müdahale: eski process KILL edildi
07:07:28 - Temiz restart → PID 3588268
07:08:xx - HTTP server başarıyla başladı
```

## Root Cause

`hegel-version.sh` stop fonksiyonu SIGTERM gönderiyor ama process'in ölmesini beklemeden yeni process başlatıyor. Julia garbage collection veya checkpoint save sırasında SIGTERM'e yanıt gecikebilir → eski process hâlâ port tutuyor → yeni process port'u alamıyor.

## Solution

### Acil Düzeltme (Manuel)
```bash
# 1. Tüm slot Julia process'lerini bul
ps aux | grep julia | grep slot-t-a

# 2. Force kill eski process'leri
kill -9 <eski_pid>

# 3. Port temiz mi kontrol et
lsof -i :8085

# 4. Temiz start
bash versions/hegel-version.sh start slot-t-a
```

### Kalıcı Fix (hegel-version.sh)
`cmd_stop()` fonksiyonunda stop sonrası port serbest olana kadar bekle:
```bash
kill $pid && sleep 1
# Port boşalana kadar bekle (max 10s)
for i in $(seq 1 10); do
    lsof -i :$port 2>/dev/null || break
    sleep 1
done
```

## Prevention
- Auto-restart script'i stop'tan sonra `lsof -i :PORT` ile port serbest olana kadar beklemeli
- restart = stop (port temiz) + start
- Stale PID dosyası varsa ve process dead ise → doğrudan start yap

## Related
- Sık tekrar eden sorun: v2.1.0 HTTP degradation (EXP-0116) + bu bug birleşince iki restart üst üste geliyor
