# EXP-0004: Instagram Monitor - MongoDB Global Unique Index During Account Transfer

**Project**: Instagram Monitor & Analyzer
**Date**: 2026-02-27
**Category**: Bug Fix / Database
**Technologies**: MongoDB, Motor (async), Python
**Keywords**: DuplicateKeyError, unique index, account transfer, MongoDB, motor, script

---

## Problem Statement
`DuplicateKeyError: account_username` — Bir Instagram hesabını farklı kullanıcıya transfer etmeye çalışırken hata.
`account_username` alanında **global unique index** vardı, oysa aynı kullanıcı adı farklı organizasyonlarda olabilmeli.

## Root Cause
Index yanlış tasarlanmıştı: `account_username` globally unique, ama compound unique olmalıydı: `(account_username, org_id)`.

## Solution

### Geçici Fix: Motor Script ile Transfer
```python
# /tmp/mongo_fix.py
import asyncio
from motor.motor_asyncio import AsyncIOMotorClient

async def fix():
    client = AsyncIOMotorClient("mongodb://localhost:27017")
    db = client["instagram_monitor"]
    col = db["accounts"]

    result = await col.update_one(
        {"account_username": "target_account"},
        {"$set": {"account_owner_id": "new_user_id"}}
    )
    print(f"Modified: {result.modified_count}")

asyncio.run(fix())
```

### Kalıcı Fix: Index Yeniden Oluştur
```javascript
// MongoDB shell
db.accounts.dropIndex("account_username_1");
db.accounts.createIndex(
  { "account_username": 1, "org_id": 1 },
  { unique: true }
);
```

### Shell Heredoc Tuzağı
MongoDB shell'e script göndermek için `cat << 'EOF'` (single quote!) kullan:
```bash
# YANLIŞ - $set shell variable olarak yorumlanır:
cat << EOF
db.col.update({}, { $set: { field: "value" } })
EOF

# DOĞRU - single quote:
cat << 'EOF'
db.col.update({}, { $set: { field: "value" } })
EOF
```

## Lessons Learned
- MongoDB unique index tasarımında: "globally unique mi, compound unique mi?" sorusunu SOR
- `account_username` + `org_id` compound unique genellikle daha doğru
- Shell heredoc içinde `$` olan MongoDB operatörleri (`$set`, `$push`) için `<< 'EOF'` kullan
- Transfer işlemi için Motor async script en temiz yaklaşım

## Prevention Checklist
- [ ] Yeni MongoDB collection tasarlarken: unique index alanlarını belgele
- [ ] `$set`, `$push` içeren heredoc'larda: `<< 'EOF'` (quoted) kullan
- [ ] Multi-tenant sistemde: global unique yerine `(alan, org_id)` compound unique tercih et
- [ ] Index migration: prod'da önce test et, rollback planı yap
