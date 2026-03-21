# Experience 0022: Pydantic v2 Field Validation Migration and Best Practices

**Date**: June 26, 2025  
**Project**: ODTÜ Connect (formerly HocamKariyer)  
**Category**: Backend/Dependencies  
**Status**: ✅ Resolved  
**Technologies**: Pydantic v2, FastAPI, Python, Field Validation, API Development  

## Problem Statement

During availability system implementation, encountered Pydantic v2 compatibility error when using deprecated `regex` parameter in field validation:

```
pydantic.errors.PydanticUserError: `regex` is removed. use `pattern` instead
```

This highlighted the need to understand Pydantic v2 migration patterns and ensure all field validation follows current best practices across the codebase.

### Specific Error
```python
# ❌ Old Pydantic v1 syntax causing error
available_period_start_time: str = Field(..., regex=r"^([01]\d|2[0-3]):([0-5]\d)$")

# FastAPI server failed to start with this error
```

## Investigation Process

### 1. Pydantic v2 Changes Analysis
- Reviewed Pydantic v2 migration documentation
- Identified key breaking changes affecting our codebase
- Analyzed FastAPI-MongoDB guide for current patterns

### 2. Field Validation Patterns
- `regex` parameter deprecated → `pattern` parameter
- `Config` class → `ConfigDict` model configuration  
- `@validator` decorator → `@field_validator` decorator
- `orm_mode` → `from_attributes` in ConfigDict

### 3. Codebase Impact Assessment
- Searched for potential `regex` usage in existing models
- Identified validation patterns that needed updating
- Checked for other deprecated Pydantic v1 patterns

## Root Cause Analysis

### Primary Issues
1. **Deprecated Parameter**: `regex` parameter removed in Pydantic v2
2. **Breaking Change**: No backward compatibility for `regex` parameter
3. **Documentation Gap**: Need clear patterns for field validation in codebase

### Why This Matters
- FastAPI fully integrated Pydantic v2 for 5-20x performance improvements
- Using deprecated patterns prevents application startup
- Inconsistent validation patterns across modules create maintenance issues

## Solution Implementation

### 1. Fixed Field Validation Pattern

```python
# ✅ Correct Pydantic v2 syntax
class AvailableCustomHours(BaseModel):
    available_period_start_time: str = Field(..., pattern=r"^([01]\d|2[0-3]):([0-5]\d)$")
    available_period_end_time: str = Field(..., pattern=r"^([01]\d|2[0-3]):([0-5]\d)$")
```

### 2. Complete Pydantic v2 Model Pattern

```python
from pydantic import BaseModel, Field, field_validator, ConfigDict
from typing import Optional, List
from datetime import datetime

class AvailabilityBase(BaseModel):
    model_config = ConfigDict(
        from_attributes=True,           # v1: orm_mode = True
        frozen=False,                   # v1: allow_mutation = False  
        json_schema_extra={
            "example": {
                "available_title": "Summer Internship",
                "available_description": "Available for summer work"
            }
        }
    )
    
    available_title: str = Field(..., min_length=1, max_length=200)
    available_email: Optional[str] = Field(None, pattern=r'^[\w\.-]+@[\w\.-]+\.\w+$')
    available_periods: List[AvailablePeriod] = Field(default_factory=list)
    
    @field_validator('available_title')        # v1: @validator
    @classmethod
    def validate_title(cls, v: str) -> str:
        if len(v.strip()) == 0:
            raise ValueError('Title cannot be empty')
        return v.strip().title()
```

### 3. Migration Checklist for Pydantic v2

```python
# ❌ Pydantic v1 Patterns to Avoid
class OldModel(BaseModel):
    class Config:                              # Use ConfigDict instead
        orm_mode = True                        # Use from_attributes = True
        allow_mutation = False                 # Use frozen = True
    
    field: str = Field(..., regex=r"pattern") # Use pattern= instead
    
    @validator('field')                        # Use @field_validator
    def validate_field(cls, v):
        return v

# ✅ Pydantic v2 Correct Patterns  
class NewModel(BaseModel):
    model_config = ConfigDict(
        from_attributes=True,
        frozen=False
    )
    
    field: str = Field(..., pattern=r"pattern")
    
    @field_validator('field')
    @classmethod
    def validate_field(cls, v: str) -> str:
        return v
```

### 4. Common Field Validation Patterns

```python
class ValidationExamples(BaseModel):
    # Email validation
    email: str = Field(..., pattern=r'^[\w\.-]+@[\w\.-]+\.\w+$')
    
    # Time format (HH:MM)
    time: str = Field(..., pattern=r"^([01]\d|2[0-3]):([0-5]\d)$")
    
    # UUID validation  
    uuid_field: str = Field(..., pattern=r'^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$')
    
    # Custom ID format (prefix--uuid)
    available_id: str = Field(..., pattern=r'^available--[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$')
    
    # Phone number (basic)
    phone: str = Field(..., pattern=r'^\+?1?\d{9,15}$')
    
    # Alphanumeric with length
    code: str = Field(..., pattern=r'^[A-Za-z0-9]{6,12}$')
```

## Verification

### 1. Server Startup Test
```bash
cd /backend && python -m uvicorn app.main:app --reload
# ✅ No Pydantic errors, server starts successfully
```

### 2. API Documentation
- FastAPI `/docs` generates correct field validation info
- Pattern constraints shown in OpenAPI schema
- Examples render properly in Swagger UI

### 3. Runtime Validation
```python
# Test pattern validation
try:
    hours = AvailableCustomHours(
        available_period_start_time="25:00",  # Invalid hour
        available_period_end_time="12:30"
    )
except ValidationError as e:
    # ✅ Properly catches validation error
    print(e.errors())
```

## Lessons Learned

### 1. Pydantic v2 Migration is Breaking
- **No backward compatibility** for deprecated parameters
- Must update all field validation patterns before upgrading
- FastAPI won't start with v1 patterns in v2 environment

### 2. Pattern vs Regex Parameter
```python
# v1 syntax (deprecated)
Field(..., regex=r"pattern")

# v2 syntax (correct)  
Field(..., pattern=r"pattern")
```

### 3. Configuration Migration
```python
# v1 Config class (deprecated)
class Config:
    orm_mode = True
    allow_mutation = False

# v2 ConfigDict (correct)
model_config = ConfigDict(
    from_attributes=True,
    frozen=True
)
```

### 4. Field Validator Migration
```python
# v1 validator (deprecated)
@validator('field')
def validate_field(cls, v):
    return v

# v2 field_validator (correct)
@field_validator('field')  
@classmethod
def validate_field(cls, v: type) -> type:
    return v
```

### 5. Performance Benefits
- Pydantic v2 provides 5-20x performance improvements
- Better memory usage and serialization speed
- Improved error messages and debugging

### 6. Best Practices for Field Validation
- Use specific patterns for common formats (email, phone, time)
- Include helpful error messages in validators
- Test validation patterns thoroughly
- Document regex patterns for maintainability

## Related Code

### Files Updated
- `/backend/app/pages/availability/availability_models.py` - Fixed `regex` → `pattern`

### Pattern Examples Used
```python
# Time format validation (24-hour HH:MM)
pattern=r"^([01]\d|2[0-3]):([0-5]\d)$"

# UUID format validation
pattern=r'^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$'

# Custom ID format (prefix--uuid)
pattern=r'^available--[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$'
```

### Configuration Pattern
```python
model_config = ConfigDict(
    from_attributes=True,        # Enables ORM object parsing
    frozen=False,                # Allows field mutation
    json_schema_extra={          # OpenAPI documentation
        "example": {...}
    }
)
```

## Future Considerations

### 1. Codebase Audit
- Search entire codebase for remaining Pydantic v1 patterns
- Update any remaining `@validator` usage to `@field_validator`  
- Standardize field validation patterns across modules

### 2. Validation Library
- Create common validation patterns as reusable constants
- Centralized email, phone, UUID validation patterns
- Consistent error messages across models

### 3. Testing Strategy
- Unit tests for all field validation patterns
- Edge case testing for regex patterns
- Performance testing for validation-heavy endpoints

### 4. Documentation
- Document common validation patterns in development guide
- Add examples of proper Pydantic v2 usage
- Migration checklist for future model updates

---

**Resolution**: Successfully migrated from deprecated Pydantic v1 `regex` parameter to v2 `pattern` parameter. Server now starts without errors and field validation works correctly.

**Impact**: Enables use of Pydantic v2 performance improvements while maintaining robust field validation throughout the application.

**Prevention**: Established clear patterns for Pydantic v2 usage and identified areas for future codebase modernization.