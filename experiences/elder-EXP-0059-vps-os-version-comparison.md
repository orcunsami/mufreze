# EXP-0059: VPS OS Version Comparison

**Status**: 📊 DOCUMENTATION
**Date**: 2025-12-12
**Project**: Infrastructure (4 VPS)
**Category**: DevOps / System Architecture
**Technologies**: Ubuntu 22.04 LTS, Ubuntu 24.04 LTS, PM2, nginx, MongoDB

---

## Problem

VPS2'de MongoDB auth enable ederken farklı davranışlar gözlemlendi. Sistemler arası karşılaştırma yapılması gerekti.

**Question**: VPS'ler arasındaki OS ve software version farklılıkları neler?

---

## Discovery

### Full System Comparison

| Item | VPS1 (173.249.18.183) | VPS2 (45.138.74.119) | VPS3 (94.130.165.218) | VPS4 (94.130.180.53) |
|------|----------------------|---------------------|----------------------|---------------------|
| **OS** | Ubuntu 24.04.1 LTS | **Ubuntu 22.04.5 LTS** ⚠️ | Ubuntu 24.04.1 LTS | Ubuntu 24.04.1 LTS |
| **Kernel** | 6.8.0-49-generic | **5.15.0-126-generic** ⚠️ | 6.8.0-49-generic | 6.8.0-49-generic |
| **PM2** | 6.0.1 | **5.4.3** ⚠️ | 6.0.1 | 6.0.1 |
| **nginx** | 1.24.0 | **1.18.0** ⚠️ | 1.24.0 | 1.24.0 |
| **MongoDB** | 7.0.12 | 6.0.6 | 7.0.12 | 7.0.12 |
| **Node.js** | v20.18.1 | v20.18.1 | v20.18.1 | v20.18.1 |
| **Python** | 3.12.3 | 3.10.12 | 3.12.3 | 3.12.3 |
| **Deployed** | 2024-06 | **2024-03** ⚠️ | 2024-06 | 2024-06 |

---

## Key Differences

### 1. OS Version Gap
```bash
# VPS2 (Older)
Ubuntu 22.04.5 LTS (Jammy Jellyfish)
Released: April 2022
Support until: April 2027 (5 years)

# VPS1, VPS3, VPS4 (Newer)
Ubuntu 24.04.1 LTS (Noble Numbat)
Released: April 2024
Support until: April 2029 (5 years)
```

**Gap**: 2 years (22.04 → 24.04)

### 2. Kernel Version
```bash
# VPS2
5.15.0-126-generic (Ubuntu 22.04 default)

# VPS1, VPS3, VPS4
6.8.0-49-generic (Ubuntu 24.04 default)
```

**Kernel features**:
- 6.8: Better I/O performance, improved security
- 5.15: Stable, proven in production

### 3. PM2 Version
```bash
# VPS2
PM2 version 5.4.3
Released: ~2024-03

# VPS1, VPS3, VPS4
PM2 version 6.0.1
Released: ~2024-10
```

**PM2 6.x Changes**:
- Better memory management
- Improved cluster mode
- Enhanced process monitoring

### 4. nginx Version
```bash
# VPS2
nginx version: nginx/1.18.0 (Ubuntu)

# VPS1, VPS3, VPS4
nginx version: nginx/1.24.0 (Ubuntu)
```

**nginx 1.24 Improvements**:
- HTTP/3 (QUIC) support
- Better SSL/TLS handling
- Performance optimizations

### 5. MongoDB Version
```bash
# VPS2
MongoDB 6.0.6 (June 2023)

# VPS1, VPS3, VPS4
MongoDB 7.0.12 (July 2024)
```

**MongoDB 7.x Features**:
- Time series collections
- Better aggregation performance
- Enhanced security (SCRAM-SHA-256)

---

## Why VPS2 is Different

### Deployment Timeline
```
March 2024: VPS2 deployed with Ubuntu 22.04
June 2024:  VPS1, VPS3, VPS4 deployed with Ubuntu 24.04
```

**Reason**: VPS2 3 ay önce deploy edildi, o zaman Ubuntu 24.04 henüz LTS stable değildi.

### Current Projects

**VPS2** (Ubuntu 22.04):
- hocamclass (FastAPI + Vue.js)
- hocamkariyer (FastAPI + Next.js)
- odtuconnect (FastAPI + Next.js)

**VPS1** (Ubuntu 24.04):
- yenizelanda (FastAPI + Next.js)

**VPS3** (Ubuntu 24.04):
- TikTip (Laravel + React/Inertia)

**VPS4** (Ubuntu 24.04):
- Master VPS (Uptime Kuma, monitoring)

---

## Impact Analysis

### Compatibility Issues

#### 1. PM2 5.4.3 vs 6.0.1
**Risk**: Medium
- PM2 5.x stable, production-ready
- PM2 6.x has better features but different config

**Action**: No immediate upgrade needed

#### 2. nginx 1.18 vs 1.24
**Risk**: Low
- Both versions production-ready
- 1.24 has HTTP/3 but not critical

**Action**: Consider upgrade for HTTP/3 support

#### 3. MongoDB 6.0 vs 7.0
**Risk**: Low-Medium
- Both versions production-ready
- 7.0 has better security (SCRAM-SHA-256)

**Action**: Test upgrade in staging first

#### 4. Python 3.10 vs 3.12
**Risk**: Low
- FastAPI works with both
- 3.12 has better performance

**Action**: No immediate upgrade needed

### Security Considerations

**VPS2 (Ubuntu 22.04)**:
- Kernel 5.15: Proven, stable
- Support until 2027
- Security updates aktif

**VPS1/3/4 (Ubuntu 24.04)**:
- Kernel 6.8: Latest security patches
- Support until 2029
- Better security features

**Recommendation**: VPS2 güvenli (2027'ye kadar support), acil upgrade gerekmez.

---

## Upgrade Path (Optional)

### Option 1: In-Place Upgrade (Risky)
```bash
# VPS2'yi 22.04 → 24.04 upgrade
sudo do-release-upgrade
```

**Pros**: Aynı VPS kullanılır
**Cons**: Downtime, risky (3 production app)

### Option 2: Fresh Deploy (Safer)
```bash
# Yeni VPS5 deploy et (Ubuntu 24.04)
# → hocamclass, hocamkariyer, odtuconnect migrate
# → VPS2'yi retire et
```

**Pros**: Zero downtime, safer
**Cons**: Migration effort

### Option 3: Keep As Is (Recommended)
**Reasoning**:
- Ubuntu 22.04 support 2027'ye kadar
- VPS2 stable, 3 production app çalışıyor
- OS farklılığı şu an sorun yaratmıyor

**Action**: Monitor ve 2026'da upgrade planla

---

## Standardization Recommendations

### For New VPS Deployments

```bash
# Standard Stack (2025)
OS:       Ubuntu 24.04 LTS
PM2:      Latest 6.x
nginx:    Latest 1.24+
MongoDB:  Latest 7.0+
Node.js:  v20 LTS (active until 2026)
Python:   3.12
```

### Current State (Acceptable)

**VPS1, VPS3, VPS4**: ✅ Standard stack
**VPS2**: ⚠️ Legacy stack (but stable)

**Decision**: VPS2'yi legacy olarak işaretle, yeni deployment'larda kullanma.

---

## Monitoring

### OS Version Alert
```bash
# /home/ost/scripts/os_version_check.sh

#!/bin/bash
echo "OS Version:"
lsb_release -a

echo -e "\nKernel:"
uname -r

echo -e "\nPM2:"
pm2 -v

echo -e "\nnginx:"
nginx -v

echo -e "\nMongoDB:"
mongod --version | head -1

echo -e "\nNode.js:"
node -v

echo -e "\nPython:"
python3 --version
```

**Cron** (weekly report):
```bash
0 0 * * 0 /home/ost/scripts/os_version_check.sh | mail -s "VPS Version Report" orcunst@gmail.com
```

---

## Cross-Project Impact

### Projects Affected by Version Differences

**None currently**. Tüm projeler her iki OS'da da çalışıyor.

**Future Considerations**:
- HTTP/3 kullanmak istersek → VPS2 nginx upgrade gerekir
- MongoDB 7.0 features kullanmak istersek → VPS2 MongoDB upgrade gerekir

---

## Lessons Learned

1. **LTS timing matters**: VPS deploy zamanı OS version'ı belirler
2. **Version drift is normal**: 3-6 ay arayla deploy edilen VPS'ler farklı versiyonlara sahip olabilir
3. **Legacy ≠ Broken**: Ubuntu 22.04 hala production-ready (2027'ye kadar)
4. **Document version differences**: Infrastructure documentation kritik
5. **Standardize new deployments**: Yeni VPS'lerde latest LTS kullan

---

## Related Experiences

- **EXP-0057**: VPS2 MongoDB Authentication Enable
- **EXP-0058**: VPS1 Disk Cleanup

---

## Tags

`devops`, `ubuntu`, `vps`, `version-management`, `infrastructure`, `pm2`, `nginx`, `mongodb`, `os-comparison`, `lts`

---

## Documentation

**Infrastructure Master Plan**: `/Users/mac/.claude/docs/systems/infrastructure-master-plan.md`

**VPS Version Matrix**:
```
VPS1: Ubuntu 24.04, MongoDB 7.0.12, PM2 6.0.1 (yenizelanda)
VPS2: Ubuntu 22.04, MongoDB 6.0.6,  PM2 5.4.3 (hocamclass, hocamkariyer, odtu) ⚠️ LEGACY
VPS3: Ubuntu 24.04, MongoDB 7.0.12, PM2 6.0.1 (TikTip)
VPS4: Ubuntu 24.04, MongoDB 7.0.12, PM2 6.0.1 (Master/Monitoring)
```

---

**Total Time**: 20 minutes (discovery + documentation)
**Action Required**: None (informational)
**Priority**: Low (monitoring)
