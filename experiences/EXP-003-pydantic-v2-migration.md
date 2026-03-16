---
id: EXP-003
project: global
worker: generic
category: backend
tags: [pydantic, fastapi, migration, v2]
outcome: failure
date: 2026-02-26
---

## Problem
FastAPI fails to start: `pydantic.errors.PydanticUserError: 'regex' is removed. use 'pattern' instead`.

## What Happened
Field validation used deprecated `regex` parameter. Pydantic v2 removed this entirely.

## Root Cause
Pydantic v2 is a breaking upgrade. `regex` → `pattern`, `Config` class → `ConfigDict`, `@validator` → `@field_validator`.

## Solution / Pattern
```python
# BEFORE (v1)
class Model(BaseModel):
    class Config:
        orm_mode = True
    field: str = Field(..., regex=r"pattern")

# AFTER (v2)
class Model(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    field: str = Field(..., pattern=r"pattern")
```

## Prevention
Rule to add to BRIEFING.md:
```
- Pydantic v2 has zero backward compatibility with v1. Search for regex=, @validator, class Config: before upgrading.
```
