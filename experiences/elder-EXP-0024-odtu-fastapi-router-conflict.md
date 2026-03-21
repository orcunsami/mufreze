# Experience 0024: FastAPI Router Prefix Conflict Resolution - FAQ System Implementation

**Date**: June 26, 2025  
**Project**: ODTÜ Connect (formerly HocamKariyer)  
**Category**: Backend/API Architecture  
**Status**: ✅ Resolved  
**Technologies**: FastAPI, Router Configuration, API Design, FAQ System  

## Problem Statement

During the implementation of a comprehensive FAQ system for the HocamKariyer platform, encountered a critical FastAPI routing error that prevented the backend from starting:

```
fastapi.exceptions.FastAPIError: Prefix and path cannot be both empty (path operation: list_faqs)
```

The error occurred when including the FAQ sub-routers in the main FAQ router, specifically with the FAQ list endpoint that used an empty path `""` while the parent router already had a `/faqs` prefix.

## Investigation Process

### 1. Error Analysis
The error indicated a fundamental FastAPI routing configuration issue:
- Main FAQ router: `prefix="/faqs"`
- Sub-router endpoint: `@router.get("")` (empty path)
- Combined result: `/faqs` + `""` = invalid route configuration

### 2. Code Structure Analysis
The FAQ module followed the established functional programming pattern:
```
/backend/app/pages/faqs/
├── faq_router.py           # Main router with /faqs prefix
├── faq_list.py            # List endpoint with empty path ""
├── faq_create_question.py # Create question endpoint
├── faq_create_answer.py   # Create answer endpoint
├── faq_manage.py          # Management endpoints
├── faq_models.py          # Pydantic models
├── faq_common.py          # Utility functions
└── __init__.py            # Package initialization
```

### 3. FastAPI Router Hierarchy
```python
# Main router (app/core/router.py)
api_router.include_router(faqs_router, tags=["faqs"])

# FAQ router (app/pages/faqs/faq_router.py)
router = APIRouter(prefix="/faqs", tags=["FAQ"])
router.include_router(list_router)  # Contains @router.get("")

# List router (app/pages/faqs/faq_list.py)
@router.get("", response_model=FAQListResponse)  # ❌ PROBLEM
```

## Root Cause Analysis

FastAPI strictly prevents router configurations where both the parent prefix and child path are empty or would result in an ambiguous route. The combination of:
- Parent router prefix: `/faqs`
- Child endpoint path: `""` (empty)

Creates an invalid route definition because FastAPI cannot determine the final endpoint path unambiguously.

## Solution Implementation

### 1. Fix Empty Path Route
**File**: `/backend/app/pages/faqs/faq_list.py`
```python
# ❌ Before (causes error)
@router.get("", response_model=FAQListResponse)

# ✅ After (working)
@router.get("/", response_model=FAQListResponse)
```

### 2. Update Frontend API Calls
**File**: `/frontend/src/components/FAQSection.tsx`
```typescript
// ❌ Before
const response = await apiClient.get(`/faqs?${params}`)

// ✅ After 
const response = await apiClient.get(`/faqs/?${params}`)
```

### 3. Ensure Package Structure
Created missing `__init__.py` to make FAQ module a proper Python package:
```python
# /backend/app/pages/faqs/__init__.py
"""FAQ module - Universal FAQ system for all content types"""
```

## Verification

### 1. Route Structure Validation
Final API endpoints structure:
```
GET  /api/v1/faqs/                    # List FAQs
POST /api/v1/faqs/questions           # Create question
POST /api/v1/faqs/questions/{id}/answer  # Create answer
GET  /api/v1/faqs/stats               # Get statistics
PUT  /api/v1/faqs/questions/{id}/visibility  # Toggle visibility
DELETE /api/v1/faqs/questions/{id}    # Delete question
GET  /api/v1/faqs/health              # Health check
```

### 2. Import Verification
Confirmed all FAQ module imports work correctly:
- Router includes all sub-routers without conflicts
- Common utilities properly imported across all FAQ modules
- Models and dependencies correctly structured

### 3. Integration Testing
- Backend starts successfully with FAQ routes
- FAQ endpoints properly registered in OpenAPI documentation
- Frontend component correctly calls FAQ API endpoints

## Lessons Learned

### 1. FastAPI Router Rules
- **Never use empty paths** with prefixed parent routers
- **Always use forward slash** `/` for root endpoints within prefixed routers
- **Test router configuration early** to catch routing conflicts

### 2. API Design Consistency
- **Consistent trailing slashes** in both backend routes and frontend calls
- **Clear endpoint hierarchy** with proper prefix organization
- **Router separation** should follow logical module boundaries

### 3. Module Structure Best Practices
- **Always include `__init__.py`** for Python package recognition
- **Validate imports** after creating new modules
- **Follow established patterns** from other modules in the codebase

### 4. Development Workflow
- **Test backend startup** immediately after router changes
- **Check for missing dependencies** when creating new modules
- **Verify API endpoint accessibility** before frontend integration

## Related Code

### Key Files Modified
- `/backend/app/pages/faqs/faq_list.py` - Fixed empty path route
- `/frontend/src/components/FAQSection.tsx` - Updated API call path
- `/backend/app/pages/faqs/__init__.py` - Created package file

### Architecture Context
This fix completes the universal FAQ system implementation that supports:
- Events, services, jobs, portfolios, projects
- Guest and authenticated user questions
- Owner-only answer management
- Public/private visibility controls
- Real-time FAQ statistics

### Related Experiences
- **experience_0019.md**: Functional programming architecture patterns
- **experience_0021.md**: Field naming conventions and module structure
- **experience_0022.md**: Pydantic v2 and FastAPI integration patterns

## Technical Impact

### Positive Outcomes
- ✅ FAQ system fully functional across all content types
- ✅ Clean API endpoint structure established  
- ✅ Proper module packaging for future extensibility
- ✅ Consistent routing patterns across the application

### Prevention Strategies
1. **Router Testing**: Always test backend startup after router modifications
2. **Path Validation**: Use `/` instead of `""` for root endpoints in prefixed routers
3. **Documentation**: Include endpoint examples in router health checks
4. **Code Review**: Verify router configuration in pull requests

---

**Resolution Time**: ~30 minutes  
**Complexity**: Low-Medium  
**Impact**: High (blocking deployment)  
**Reusability**: High (applies to all FastAPI router configurations)