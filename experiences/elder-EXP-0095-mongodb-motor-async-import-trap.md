# EXP-0095: MongoDB Motor Async — Import Trap (db Stays None)

## Metadata
- **Date**: 2026-02-28
- **Project**: resmigazete (Resmi Gazete Bulten Platform)
- **Severity**: CRITICAL (causes silent NoneType errors at runtime)
- **Category**: MongoDB, FastAPI, Python Async
- **Status**: SOLVED

## Problem Statement
FastAPI app works fine at startup but crashes with `AttributeError: 'NoneType' object has no attribute 'find'` or `'NoneType' object has no attribute 'insert_one'` when trying to query MongoDB. The database object is None despite Motor being connected.

## Root Cause
Python module-level imports are executed immediately when the module is first imported — **before** the FastAPI lifespan startup event runs and before Motor connects to MongoDB.

```python
# BROKEN: This runs at import time, BEFORE Motor connects
from app.database import db   # db = None at this point!

async def get_users():
    return await db.users.find().to_list()  # AttributeError: NoneType
```

The `db` variable is captured as `None` at import time and never updated, even after Motor connects.

## Solution

```python
# CORRECT PATTERN: Import the module, not the variable
import app.database as database

async def get_users():
    return await database.db.users.find().to_list()
    # database.db is re-evaluated at call time, AFTER Motor connected
```

### Why This Works
When you write `database.db`, Python looks up `db` on the `database` module object at **call time**, not at import time. By then, the lifespan startup event has run and `database.db` points to the real Motor database instance.

### Full Pattern (database.py)
```python
# app/database.py
from motor.motor_asyncio import AsyncIOMotorClient

client: AsyncIOMotorClient = None
db = None  # Will be set in startup

async def connect_db():
    global client, db
    client = AsyncIOMotorClient(settings.MONGODB_URL)
    db = client[settings.DB_NAME]

async def close_db():
    if client:
        client.close()
```

```python
# app/main.py
from contextlib import asynccontextmanager
from fastapi import FastAPI
from app.database import connect_db, close_db

@asynccontextmanager
async def lifespan(app: FastAPI):
    await connect_db()   # db is now set
    yield
    await close_db()

app = FastAPI(lifespan=lifespan)
```

```python
# app/routers/content.py - CORRECT USAGE
import app.database as database   # module reference, not value

async def get_content(gazette_id: str):
    doc = await database.db.gazette_content.find_one({"_id": gazette_id})
    return doc
```

## Detection
```python
# If you see this, you have the import trap:
from app.database import db
print(type(db))  # <class 'NoneType'> at module load time

# This is correct:
import app.database as database
print(type(database.db))  # <class 'NoneType'> initially, but...
# After lifespan startup:
print(type(database.db))  # <class 'motor.motor_asyncio.AsyncIOMotorDatabase'>
```

## Applicable To
- ALL FastAPI + Motor (async MongoDB) projects
- Any Python project where a connection object is set in an async startup event
- SQLAlchemy async sessions have same trap with `get_db()` dependency injection

## Lessons Learned
1. **Never `from module import variable`** when the variable is set asynchronously after import
2. **Module reference (`import module as m`) is always safe** — it re-evaluates at call time
3. **Motor connects lazily** — even `AsyncIOMotorClient()` doesn't validate connection until first operation
4. **The error is silent at import time** — you only see it at runtime when querying
5. SQLAlchemy equivalent: use `get_db()` dependency, not module-level `db = SessionLocal()`

## Related Experiences
- EXP-0094: Resmi Gazete scraper selectors (same project)
- EXP-0096: Celery + AsyncIO event loop (same project)

## Tags
`mongodb` `motor` `fastapi` `async` `python` `import` `none` `bug` `silent-failure`
