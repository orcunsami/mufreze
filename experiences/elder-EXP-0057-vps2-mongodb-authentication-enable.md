# EXP-0057: VPS2 MongoDB Authentication Enable

**Status**: ✅ SUCCESS
**Date**: 2025-12-12
**Project**: Infrastructure (VPS2 - 45.138.74.119)
**Category**: Database Security / DevOps
**Technologies**: MongoDB 6.0.6, Ubuntu 22.04, systemd, PM2

---

## Problem

VPS2'de MongoDB authentication disabled durumda çalışıyordu. 3 production backend (hocamclass, hocamkariyer, odtu) authentication olmadan bağlanıyordu.

**Security Risk**: Herhangi bir network erişimi olan kişi database'e bağlanabilir.

---

## Discovery Process

1. **Auth Check**:
```bash
ssh ost@45.138.74.119
mongo --eval "db.runCommand({connectionStatus:1})" | grep authenticatedUsers
# → "authenticatedUsers" : [ ]  # Empty!
```

2. **mongod.conf Control**:
```yaml
security:
  # authorization: enabled  # COMMENTED OUT!
```

3. **User Kontrol**:
```javascript
use admin
db.getUsers()
// → admin user var
// → mainApplicationUser var

use hocamkariyer
db.getUsers()
// → hocamkariyer_app user var

use hocamclass
db.getUsers()
// → hocamclass_app user var

use odtuconnect
db.getUsers()
// → odtuconnect_app user var
```

**Finding**: Tüm user'lar zaten oluşturulmuş, sadece authorization disabled!

---

## Solution

### 1. mongod.conf Update
```bash
sudo nano /etc/mongod.conf
```

```yaml
security:
  authorization: enabled  # UNCOMMENTED
```

### 2. MongoDB Restart
```bash
sudo systemctl restart mongod
sudo systemctl status mongod
# → Active: active (running)
```

### 3. Backend .env Update (3 Backend)

**HocamClass** (`/home/ost/hocamclass/backend/.env`):
```bash
MONGODB_URI_PRODUCTION=mongodb://hocamclass_app:SONUC_PASSWORD@localhost:27017/hocamclass?authSource=hocamclass
```

**HocamKariyer** (`/home/ost/hocamkariyer/backend/.env`):
```bash
MONGODB_URI_PRODUCTION=mongodb://hocamkariyer_app:SONUC_PASSWORD@localhost:27017/hocamkariyer?authSource=hocamkariyer
```

**ODTÜ Connect** (`/home/ost/odtu/backend/.env`):
```bash
MONGODB_URI_PRODUCTION=mongodb://odtuconnect_app:SONUC_PASSWORD@localhost:27017/odtuconnect?authSource=odtuconnect
```

**Key Points**:
- `authSource={database}` - Her database kendi user'ını authenticate eder
- `localhost:27017` - Local connection (remote disabled)

### 4. Backend Restart
```bash
pm2 restart hocamclass-backend
pm2 restart hocamkariyer-backend
pm2 restart odtu-backend
```

### 5. Health Check
```bash
# HocamClass
curl https://api.hocamclass.com/health
# → {"status":"healthy",...}

# HocamKariyer
curl https://api.hocamkariyer.com/health
# → {"status":"healthy",...}

# ODTÜ Connect
curl https://api.odtu.yenizelanda.net/health
# → {"status":"healthy",...}
```

**Result**: Tüm backend'ler 200 döndü, authentication başarılı!

---

## Key Insights

### 1. User'lar Zaten Vardı
MongoDB user'ları production deployment sırasında oluşturulmuş ama `authorization: enabled` yapılmamış. Bu yaygın bir "unutulan güvenlik adımı".

### 2. authSource Kritik
```bash
# ❌ YANLIŞ
mongodb://user:pass@localhost:27017/hocamclass
# authSource belirtilmezse → admin database'de arar

# ✅ DOĞRU
mongodb://user:pass@localhost:27017/hocamclass?authSource=hocamclass
# Her database kendi user'ını authenticate eder
```

### 3. PM2 Restart Yeterli
Environment variable değişince PM2 restart yeterli, server restart gerekmez.

### 4. Health Check Endpoint
FastAPI health check endpoint sayesinde authentication'ın çalışıp çalışmadığını hızlıca test ettik.

---

## Reusable Patterns

### MongoDB Auth Enable Checklist (Production)
```bash
# 1. User'ları kontrol et
mongo -u admin -p --authenticationDatabase admin
use {database}
db.getUsers()

# 2. mongod.conf update
sudo nano /etc/mongod.conf
# security:
#   authorization: enabled

# 3. MongoDB restart
sudo systemctl restart mongod

# 4. Backend .env update
# MONGODB_URI_PRODUCTION=mongodb://{user}:{pass}@localhost:27017/{db}?authSource={db}

# 5. Backend restart
pm2 restart {app-name}

# 6. Health check
curl https://{api-domain}/health
```

### MongoDB Connection String Template
```bash
# Production (local MongoDB)
mongodb://{app_user}:{password}@localhost:27017/{database}?authSource={database}

# Development (local MongoDB, no auth)
mongodb://localhost:27017/{database}

# Remote MongoDB (Atlas)
mongodb+srv://{user}:{password}@{cluster}.mongodb.net/{database}?retryWrites=true&w=majority
```

---

## Cross-Project Application

### All FastAPI Projects with MongoDB
1. hocamclass ✅
2. hocamkariyer ✅
3. odtuconnect ✅
4. yenizelanda (VPS1) - Check auth status
5. Any new FastAPI project - Enable auth from day 1

### Standard Practice
**Day 1**: Create MongoDB users with `authorization: enabled`
**Never**: Deploy with `authorization: disabled` to production

---

## Prevention

### Infrastructure Checklist (New VPS)
```markdown
- [ ] MongoDB auth enabled (`authorization: enabled`)
- [ ] Users created per database (not shared admin user)
- [ ] Connection strings use `authSource` parameter
- [ ] Firewall blocks MongoDB port (27017) from external
- [ ] Health check endpoint tests DB connectivity
```

### Security Audit Script
```bash
#!/bin/bash
# check_mongodb_auth.sh

echo "Checking MongoDB authentication status..."
mongo --eval "db.runCommand({connectionStatus:1})" | grep authenticatedUsers

if [ -z "$AUTH_USERS" ]; then
  echo "⚠️ WARNING: MongoDB authentication might be disabled!"
fi

echo "Checking mongod.conf..."
grep "authorization" /etc/mongod.conf

echo "Checking external port exposure..."
netstat -tuln | grep 27017
```

---

## Related Experiences

- **EXP-0058**: VPS1 Disk Cleanup (MongoDB log management)
- **EXP-0059**: VPS OS Comparison (Ubuntu 22.04 vs 24.04)

---

## Lessons Learned

1. **User creation ≠ Auth enable**: User'lar olsa bile `authorization: disabled` ise kimse authentication yapmıyor
2. **authSource is mandatory**: Database-specific user'lar için mutlaka belirtilmeli
3. **Health checks are critical**: Auth değişikliği sonrası immediate test için hayati
4. **PM2 handles env changes**: .env update → PM2 restart → Yeni connection string alır

---

**Total Time**: 45 minutes (discovery + fix + test)
**Impact**: 3 production backends secured
**Reproducible**: Yes (any VPS with MongoDB)
