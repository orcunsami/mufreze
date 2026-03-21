# EXP-0005: Shell Heredoc $variable Stripping (MongoDB $set Sorunu)

**Project**: Genel (Instagram Monitor'da yaşandı)
**Date**: 2026-02-27
**Category**: DevOps / Shell / Debugging
**Technologies**: Bash, MongoDB, Shell scripting
**Keywords**: heredoc, EOF, dollar sign, $set, variable expansion, shell stripping, cat << EOF

---

## Problem Statement
`cat << EOF ... EOF` ile MongoDB script çalıştırılıyordu.
`{ $set: { field: "value" } }` satırı shell'e ulaştığında `{ : { field: "value" } }` oluyordu.
`$set` shell variable olarak yorumlanıp boş string'e dönüşüyordu.

## Root Cause
Bash heredoc'ta `<< EOF` (unquoted) → içerik variable expansion'a tabi tutulur.
`$set`, `$push`, `$match` gibi MongoDB operatörleri shell variable sanılır ve boşalır.

## Solution

### Fix 1: Single-quoted EOF (En Kolay)
```bash
# $set shell'de expand edilmez
mongo localhost/mydb << 'EOF'
db.collection.update(
  { username: "test" },
  { $set: { field: "value" } }
)
EOF
```

### Fix 2: Escape Edilmiş Dollar Sign
```bash
mongo localhost/mydb << EOF
db.collection.update(
  { username: "test" },
  { \$set: { field: "value" } }
)
EOF
```

### Fix 3: Python Script Kullan (Tercihli)
```python
# Shell stripping riski yok
from motor.motor_asyncio import AsyncIOMotorClient
await col.update_one({"username": "test"}, {"$set": {"field": "value"}})
```

### Fix 4: SCP ile Dosya Transfer
```bash
# Script'i local'de yaz, SCP ile gönder, orada çalıştır
scp fix.py root@server:/tmp/
ssh root@server "python3 /tmp/fix.py"
```

## Yaygın Etkilenen Durumlar
| Bağlam | $variable Etkilenen |
|--------|-------------------|
| MongoDB shell heredoc | `$set`, `$push`, `$match`, `$lookup` |
| JSON heredoc | `$ref`, `$schema` |
| Kubernetes YAML | `$(variable)` |
| Docker ENV | `$VAR` |

## Lessons Learned
- Heredoc'ta MongoDB operatörleri kullanacaksan: MUTLAKA `<< 'EOF'`
- Debug: `echo` ile heredoc içeriğini önce print et
- Python Motor script > shell heredoc (daha güvenli, type-safe)

## Prevention Checklist
- [ ] Heredoc içinde `$` görüyorsan: `<< 'EOF'` kullanıyor musun kontrol et
- [ ] MongoDB shell script yazmadan önce: Python Motor tercih et
- [ ] CI/CD pipeline'da heredoc varsa: `$` escape'ini test et
