# EXP-0106: MongoDB TTL Index Güncellenemez — Drop + Recreate Gerekli

## Metadata
- **Proje**: Borsa Trading Team (ve tüm Motor/MongoDB projeleri)
- **Tarih**: 2026-02-28
- **Kategori**: MongoDB, Indexing, Migration
- **Durum**: DOCUMENTED ✅
- **JIRA**: -

## Problem

`create_index(expireAfterSeconds=86400)` hata fırlattı:
```
pymongo.errors.OperationFailure: An existing index has the same name with different options
```

Bazı collection'larda TTL değeri değiştirilmek istendi (ör: 30 gün → 7 gün). Aynı field üzerinde farklı `expireAfterSeconds` ile `create_index` çağrısı yapıldı → MongoDB reddetti.

## Root Cause

MongoDB'de TTL index **değiştirilemez**. Drop + recreate gerekir. `create_index` idempotent gibi görünse de, farklı options ile aynı index adını değiştiremez.

```python
# YANLIŞ — Hata fırlatır:
await db.sessions.create_index("created_at", expireAfterSeconds=86400)   # Var olan
await db.sessions.create_index("created_at", expireAfterSeconds=604800)  # DEĞİŞTİREMEZ
```

## Fix

Drop + recreate:

```python
# DOĞRU:
async def update_ttl_index(db, collection_name: str, field: str, new_ttl_seconds: int):
    collection = db[collection_name]

    # Önce drop et (hata vermez yoksa)
    try:
        await collection.drop_index(f"{field}_1")
    except Exception:
        pass  # Index yoksa sorun değil

    # Yeni TTL ile recreate:
    await collection.create_index(
        field,
        expireAfterSeconds=new_ttl_seconds,
        background=True
    )
```

## Migration Script Pattern

```python
# Tüm TTL index'leri migration script'te listele:
TTL_INDEXES = [
    ("sessions",          "created_at",   7 * 86400),   # 7 gün
    ("chat_conversations","created_at",   7 * 86400),   # 7 gün
    ("notifications",     "created_at",  30 * 86400),   # 30 gün
    ("audit_logs",        "created_at",  90 * 86400),   # 90 gün
    ("alert_history",     "created_at",  30 * 86400),   # 30 gün
    ("team_invites",      "expires_at",   0),            # expires_at kullan
]

async def migrate_ttl_indexes(db):
    for collection_name, field, ttl in TTL_INDEXES:
        try:
            await db[collection_name].drop_index(f"{field}_1")
        except Exception:
            pass
        await db[collection_name].create_index(field, expireAfterSeconds=ttl, background=True)
        logger.info(f"TTL index recreated: {collection_name}.{field} → {ttl}s")
```

## expireAfterSeconds=0 Pattern

```python
# expires_at field kullanınca:
await collection.create_index("expires_at", expireAfterSeconds=0)
# → MongoDB belgeyi expires_at anında siler (field değeri = expiry time)
```

## Ders

1. MongoDB TTL index = immutable. Değiştirmek = drop + create
2. Migration script'te her TTL değişikliği için drop_index → create_index yaz
3. `create_index` tek başına idempotent değil (farklı options ile)
4. `expireAfterSeconds=0` + `expires_at` field = en esnek pattern (her doc farklı TTL)

## İlgili Dosyalar

- `borsa-trading-team/backend/app/main.py` (startup index creation)
- `borsa-trading-team/backend/app/services/` (collection initialization)

## Anahtar Kelimeler

`MongoDB`, `TTL index`, `expireAfterSeconds`, `drop_index`, `create_index`, `immutable`, `migration`, `OperationFailure`
