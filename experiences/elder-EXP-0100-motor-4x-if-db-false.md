# EXP-0100: Motor 4.x AsyncIOMotorDatabase — `if db:` Her Zaman False Döner

## Metadata
- **Proje**: Borsa Trading Team (ve tüm FastAPI + Motor projeleri)
- **Tarih**: 2026-02-28
- **Kategori**: Bug, FastAPI, MongoDB, Motor
- **Durum**: SOLVED ✅
- **JIRA**: -

## Problem

Sistem başlatma sırasında capacity config DB'den yüklenemiyor. Log: hiçbir şey. Hata yok, DB connection çalışıyor, ama tüm işlemler skip ediliyor. `initialize(db)` sonrası tüm parametreler default değerde.

## Root Cause

Motor 4.x `AsyncIOMotorDatabase` nesnesi, **truthy check'te `False` döner**.

```python
# Motor 4.x davranışı:
db = client["borsa_db"]   # Motor Database nesnesi
bool(db)                   # → False  ⚠️

# Bu yüzden:
if db:
    await db["system_config"].find_one(...)  # ← HİÇ ÇALIŞMIYOR
```

Bu Python'un `__bool__` protokolü nedeniyle. Motor Database nesnesi `__bool__` implement etmemiş veya False döndürecek şekilde implement etmiş.

## Fix

```python
# YANLIŞ (Motor 4.x'te çalışmaz):
async def initialize(self, db):
    if db:
        config = await db["system_config"].find_one({})
        ...

# DOĞRU:
async def initialize(self, db):
    if db is not None:
        config = await db["system_config"].find_one({})
        ...
```

## Kapsamlı Düzeltme

Bu pattern tüm `services/` klasöründeki `initialize(self, db)` metodlarını etkiler:

```bash
# Tespit:
grep -r "if db:" borsa-trading-team/backend/app/services/ --include="*.py"

# Her birini kontrol et ve değiştir:
# if db: → if db is not None:
```

## Etki

Silent failure — hata yok, log yok. Sadece "config yüklenmiyor" gibi semptom. Özellikle startup sırasında tehlikeli: sistem default değerlerle başlıyor, production'da yavaşlıyor.

## Genel Kural

**Motor (ve benzeri async ORM) nesnelerini truthiness test için kullanma. Her zaman `is not None` kullan.**

```python
# Kötü:
if db:, if collection:, if client:

# İyi:
if db is not None:
if collection is not None:
if client is not None:
```

## Ders

1. Motor 4.x: `if db:` = `False` → `if db is not None:` kullan
2. Startup initialization'da silent skip en tehlikeli bug tipidir (sistem çalışıyor gibi görünür)
3. Tüm `initialize(db)` metodlarını grep ile tara ve düzelt
4. Motor nesneleri için truthiness check hiçbir zaman kullanma

## İlgili Dosyalar

- `borsa-trading-team/backend/app/services/engines/capacity_config.py`
- `borsa-trading-team/backend/app/services/` (tüm initialize metodları)

## Anahtar Kelimeler

`Motor`, `AsyncIOMotorDatabase`, `if db`, `truthiness`, `False`, `is not None`, `silent failure`, `startup`, `Motor 4.x`
