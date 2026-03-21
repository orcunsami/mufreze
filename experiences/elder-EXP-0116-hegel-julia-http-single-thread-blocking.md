# Experience 0116: Julia HTTP.jl Single-Thread Blocking (v2.1.0 / 80-neuron)

**Date**: 2026-02-28
**Project**: Hegel
**Category**: Performance / Architecture
**Status**: Ongoing (workaround: auto-restart; root fix: async HTTP)
**Technologies**: Julia, HTTP.jl, DifferentialEquations.jl, ODE

## Problem Statement

slot-t-a (v2.1.0, 80-neuron, 90-dim ODE) HTTP yanıt süresi 27 saniyeye çıkıyor. Aynı sürede slot-o-a (v1.7.1, 40-neuron) <1s yanıt veriyor.

### Symptoms
- HTTP health check: curl exit 28 (timeout) veya 27 saniye bekleme
- Julia process çalışıyor (PID alive, CPU %100+)
- Port LISTEN durumunda (lsof'ta görünüyor)
- Slot restart sonrası geçici olarak düzeliyor, sonra tekrar bozuluyor
- Tekrar pattern: ~2 saatte bir crash/degradation

### Olay Kronolojisi (2026-02-28)
```
02:05 - slot-t-a HTTP OK
08:05 - HTTP 27 saniye (3. restart, CLOSE_WAIT socket)
09:05 - HTTP timeout (port dinlemiyor, process alive)
13:05 - Auto-restart başarılı, HTTP OK
14:05~16:05 - Fast check, sorun yok
19:05 - HTTP degraded
```

## Root Cause

Julia HTTP.jl single-threaded event loop. ODE integration (90-dim, 80 neurons) aynı thread'de çalışıyor. Checkpoint save veya evolution cycle sırasında HTTP handler bloklanıyor. v1.7.1 (40-neuron, 50-dim) daha hafif → bloklanma yok.

### Kanıt
- slot-o-a (40-neuron): hiç HTTP degradation yok, 10+ saat stable
- slot-t-a (80-neuron): her 2 saatte bir degradation
- Boyut farkı: 40 neuron → 90 saniye ODE vs 80 neuron → 27+ saniye ODE

### CLOSE_WAIT Etkisi
Degraded durumda `lsof` gösteriyor: `FD 17: localhost:8085→localhost:41346 CLOSE_WAIT`
Client socket kapandı, server hâlâ bekliyor → yeni bağlantıları reddediyor.

## Solution

### Geçici (Auto-restart)
```bash
bash versions/hegel-version.sh restart slot-t-a
# Restart sonrası ~15 dakika HTTP OK, sonra tekrar bozulabilir
```

### Gerçek Fix (Kod)
`web/api/server.jl` — HTTP server'ı ayrı thread'de çalıştır:
```julia
# Şu an (blocking):
HTTP.serve(router, "0.0.0.0", PORT)

# Fix (async):
@async HTTP.serve(router, "0.0.0.0", PORT)
# veya
Threads.@spawn HTTP.serve(router, "0.0.0.0", PORT)
```

Not: Threads.@spawn için slot config'de threads > 1 olmalı (varsayılan 4 threads mevcut).

## Prevention
- 80+ neuron slot'larda auto-restart threshold düşük tut (3 başarısız → restart)
- HTTP health check'e max-time 5s koy, 3 ardışık fail = restart
- Checkpoint save sırasında HTTP timeout beklenmeli (normal) → tek başarısızlık = alarm değil

## Related
- EXP-0115 (restart bug) ile birleşince çift process sorunu oluyor
- v2.1.0 genel instabilitesi → 80-neuron boyutu + single-thread HTTP sorusu
