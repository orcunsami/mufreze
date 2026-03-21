# Experience 0023: Events Module Backend API Error Resolution

**Date**: June 26, 2025  
**Project**: ODTÜ Connect (formerly HocamKariyer)  
**Category**: Backend/API Integration  
**Status**: ✅ Resolved  
**Technologies**: FastAPI, MongoDB, PyMongo, AsyncIO, Timezone Handling  

## Problem Statement

The events detail page at `/events/[id]` was displaying correctly as a frontend component but failing to load actual event data due to backend API errors. Two critical endpoints were returning 500 Internal Server Errors:

1. `/api/v1/events/{event_id}` - Event details endpoint
2. `/api/v1/events/{event_id}/interactions` - Event interactions statistics endpoint

The user requested creation of the events page, but the page already existed and was well-implemented - the issue was that the backend APIs were broken, preventing the page from functioning.

## Investigation Process

### 1. Frontend Analysis
- Confirmed the events detail page existed at `/frontend/src/app/events/[id]/page.tsx`
- Found a comprehensive implementation with event display, registration, interactions, and statistics
- Identified that the page was making API calls that were failing

### 2. Backend API Testing
```bash
curl http://localhost:8100/api/v1/events/event--b88edd9a-ce2b-48c3-9115-f268f0d913ef
# Returned: 500 Internal Server Error

curl http://localhost:8100/api/v1/events/event--b88edd9a-ce2b-48c3-9115-f268f0d913ef/interactions
# Returned: 500 Internal Server Error
```

### 3. Backend Error Analysis
- Examined FastAPI backend logs
- Identified two distinct error patterns in the events module

## Root Cause Analysis

### Error 1: MongoDB Async Aggregation Issue
**File**: `/backend/app/pages/events/event_interactions.py:420`

**Problem**: Incorrect async aggregation usage
```python
# BROKEN CODE
async for rating_doc in interactions_collection.aggregate(pipeline):
    # This doesn't work - aggregate() returns a cursor that needs await
```

**Error**: 
```
RuntimeWarning: coroutine 'AsyncCollection.aggregate' was never awaited
AttributeError: 'coroutine' object has no attribute 'to_list'
```

### Error 2: Timezone-aware vs Timezone-naive Datetime Comparison
**File**: `/backend/app/pages/events/event_common.py`

**Problem**: Comparing timezone-aware and timezone-naive datetime objects
```python
# BROKEN CODE - comparing mixed timezone types
if dt.tzinfo is None and now > dt:  # TypeError here
```

**Error**: 
```
TypeError: can't compare offset-naive and offset-aware datetimes
```

## Solution Implementation

### 1. Fixed MongoDB Async Aggregation (event_interactions.py)

**Replaced complex aggregation with simpler approach**:
```python
# NEW APPROACH - Simplified manual processing
rating_distribution = {}
total_ratings = 0
total_rating_sum = 0

# Get all ratings manually for now
rating_docs = interactions_collection.find({
    "event_id": event_id,
    "interaction_after_rating": {"$exists": True, "$ne": None}
})

async for doc in rating_docs:
    rating = doc.get("interaction_after_rating")
    if rating is not None:
        rating_str = str(rating)
        rating_distribution[rating_str] = rating_distribution.get(rating_str, 0) + 1
        total_ratings += 1
        total_rating_sum += rating

average_rating = total_rating_sum / total_ratings if total_ratings > 0 else 0.0
```

### 2. Fixed Timezone Comparison Issue (event_common.py)

**Added timezone-aware datetime helper function**:
```python
def ensure_timezone_aware(dt):
    if dt is None:
        return None
    if isinstance(dt, str):
        # Parse string to datetime
        try:
            dt = datetime.fromisoformat(dt.replace('Z', '+00:00'))
        except:
            return None
    if dt.tzinfo is None:
        # Assume UTC if no timezone info
        dt = dt.replace(tzinfo=timezone.utc)
    return dt

# UPDATED USAGE in validate_registration_timing()
reg_opens = ensure_timezone_aware(event_doc.get("event_registration_opens_at"))
reg_closes = ensure_timezone_aware(event_doc.get("event_registration_closes_at"))
event_start = ensure_timezone_aware(event_doc.get("event_start_at"))

# Now all comparisons are timezone-aware
if reg_opens and now < reg_opens:
    return {"valid": False, "reason": "Registration has not opened yet"}
```

## Verification

### 1. API Endpoint Testing
```bash
# Event details endpoint - SUCCESS
curl http://localhost:8100/api/v1/events/event--b88edd9a-ce2b-48c3-9115-f268f0d913ef
# Returns: 200 OK with full event data

# Event interactions endpoint - SUCCESS  
curl http://localhost:8100/api/v1/events/event--b88edd9a-ce2b-48c3-9115-f268f0d913ef/interactions
# Returns: 200 OK with interaction statistics
```

### 2. Frontend Page Verification
- Navigated to `http://localhost:3100/events/event--b88edd9a-ce2b-48c3-9115-f268f0d913ef`
- Page loads successfully with full event details
- All features working: event display, registration buttons, interaction statistics

### 3. Data Validation
- Event data displays correctly including timing, location, and description
- Interaction statistics show proper counts and rating distributions
- Registration timing validation works correctly

## Lessons Learned

### 1. MongoDB Async Patterns
- **Always await** MongoDB aggregation operations in async contexts
- Complex aggregations may need simplification for debugging
- Consider manual processing when aggregation pipelines become problematic

### 2. Timezone Handling Best Practices
- **Always ensure** datetime objects are timezone-aware before comparisons
- Create helper functions for consistent timezone handling
- UTC should be the default assumption for naive datetime objects

### 3. Debugging Strategy
- Test backend APIs independently of frontend first
- Use curl commands for quick API verification
- Error messages often point directly to the problematic code lines

### 4. Problem Analysis
- Don't assume missing pages - existing implementations may just be broken
- Backend API failures can make working frontend code appear non-functional
- Always verify both frontend and backend components separately

## Related Code Files

- `/backend/app/pages/events/event_interactions.py` - Fixed async aggregation
- `/backend/app/pages/events/event_common.py` - Fixed timezone handling
- `/backend/app/pages/events/event_get.py` - Event details endpoint
- `/frontend/src/app/events/[id]/page.tsx` - Frontend events page (was already working)

## Technical Impact

- **Fixed**: Two critical backend API endpoints for events module
- **Restored**: Full functionality of events detail pages
- **Enhanced**: Timezone handling across the events system
- **Simplified**: Complex MongoDB aggregation for better maintainability

## Future Considerations

1. **MongoDB Aggregation**: Consider implementing proper async aggregation patterns when complexity increases
2. **Timezone Strategy**: Implement consistent timezone handling across all modules
3. **Error Handling**: Add better error logging and user-friendly error messages
4. **Testing**: Implement automated tests for timezone edge cases and async operations

---

**Resolution Time**: ~45 minutes  
**Complexity**: Medium  
**Team Impact**: High (enables events functionality)