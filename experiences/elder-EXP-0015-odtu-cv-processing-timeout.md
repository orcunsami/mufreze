# Experience 0015: Solving CV Processing 15-Minute Hangs

**Date**: June 25, 2025  
**Project**: ODTÜ Connect (formerly HocamKariyer)  
**Problem**: CV processing getting stuck for 15+ minutes with no response  
**Status**: ✅ RESOLVED  
**Impact**: Critical - Users experiencing complete processing failures  

## Problem Description

Users reported CV upload processing hanging for 15+ minutes with no progress or error messages. The system would show "processing" status indefinitely, leading to poor user experience and unusable CV analysis functionality.

### Initial Symptoms
- CV uploads accepted but processing never completed
- No error messages or feedback after 15+ minutes
- Frontend showing perpetual "processing" status
- Backend logs showing minimal information about stuck processes

## Root Cause Analysis

After comprehensive analysis of the entire CV processing pipeline, I identified **multiple blocking operations without proper timeout mechanisms**:

### 1. **OpenAI API Calls Without Timeouts**
```python
# PROBLEM: No timeout configuration
openai_client = AsyncOpenAI(api_key=settings.OPENAI_API_KEY)

# API calls could hang indefinitely
response = await openai_client.chat.completions.create(...)
```

### 2. **Fire-and-Forget Background Tasks Without Monitoring**
```python
# PROBLEM: No task monitoring or timeout
asyncio.create_task(process_cv_async(cv_id, storage_path, db))
# Task could run forever with no cleanup mechanism
```

### 3. **Uncontrolled PDF/OCR Processing**
```python
# PROBLEM: No resource limits or timeouts
images = convert_from_path(file_path)  # Could process 100+ pages
text = pytesseract.image_to_string(image)  # No timeout per page
```

### 4. **Database Operations Without Timeouts**
```python
# PROBLEM: MongoDB operations could hang
mongo_client = AsyncMongoClient(settings.MONGODB_URI)  # No timeouts
await collection.insert_one(document)  # Could hang indefinitely
```

## Solution Implementation

I implemented a **comprehensive timeout and monitoring system** with multiple layers of protection:

### 1. **OpenAI Client Timeout Configuration** ⏱️
```python
# SOLUTION: Added strict timeout configuration
openai_client = AsyncOpenAI(
    api_key=settings.OPENAI_API_KEY,
    timeout=httpx.Timeout(60.0)  # 60 second timeout for all requests
)

# Wrapped API calls with additional asyncio timeout
response = await asyncio.wait_for(
    openai_client.chat.completions.create(...),
    timeout=60.0
)
```

### 2. **Background Task Monitoring System** 📊
```python
# SOLUTION: Created CVTaskManager for comprehensive monitoring
class CVTaskManager:
    def __init__(self):
        self.running_tasks: Dict[str, TaskInfo] = {}
        self.max_concurrent_tasks = 10
        
    async def submit_cv_processing_task(self, cv_id, coroutine, timeout_seconds=300):
        # Monitors task execution
        # Automatically cancels expired tasks (5 minute default)
        # Prevents resource exhaustion with concurrent limits
```

**Key Features:**
- **5-minute task timeout** with automatic cancellation
- **Concurrent task limiting** (max 10 simultaneous CV processing)
- **Automatic cleanup** of expired and completed tasks
- **Real-time monitoring** of task status and runtime
- **Database status updates** when tasks fail or timeout

### 3. **Circuit Breaker Pattern for OpenAI API** 🔄
```python
# SOLUTION: Implemented circuit breaker for API resilience
class CircuitBreaker:
    # Opens circuit after 3 consecutive failures
    # 30-second recovery timeout before retrying
    # Prevents cascading failures
    
async def make_openai_request():
    return await openai_client.chat.completions.create(...)

response = await openai_circuit_breaker.call(make_openai_request)
```

**Benefits:**
- **Fail-fast behavior** when OpenAI API is down
- **Automatic recovery** testing after failures
- **Resource protection** by avoiding repeated failed requests
- **Clear error messages** about service availability

### 4. **OCR Processing Resource Limits** 🚧
```python
# SOLUTION: Added strict resource and time limits
images = convert_from_path(
    file_path, 
    first_page=1, 
    last_page=min(3, 5),  # Maximum 3 pages
    dpi=150,              # Reduced DPI for speed
    thread_count=1        # Limited threads
)

# Added timeout per OCR page
text = await asyncio.wait_for(
    asyncio.get_event_loop().run_in_executor(
        None, 
        lambda: pytesseract.image_to_string(image, lang='eng+tur')
    ),
    timeout=30.0  # 30 second timeout per page
)
```

### 5. **Database Operation Timeouts** 🗄️
```python
# SOLUTION: Comprehensive MongoDB timeout configuration
mongo_client = AsyncMongoClient(
    settings.MONGODB_URI,
    serverSelectionTimeoutMS=10000,  # 10 second server selection
    connectTimeoutMS=10000,          # 10 second connection
    socketTimeoutMS=30000,           # 30 second socket timeout
    waitQueueTimeoutMS=5000,         # 5 second wait queue
)

# Wrapper for database operations with timeout
async def with_db_timeout(coro, timeout: float = 30.0):
    try:
        return await asyncio.wait_for(coro, timeout=timeout)
    except asyncio.TimeoutError:
        raise RuntimeError(f"Database operation timed out after {timeout} seconds")
```

## Architecture Changes

### Before: Vulnerable to Infinite Hangs
```
CV Upload → Fire-and-forget processing → [HANGS INDEFINITELY]
- No timeouts
- No monitoring  
- No resource limits
- No error recovery
```

### After: Robust Timeout & Monitoring System
```
CV Upload → Task Manager → Monitored Processing → Guaranteed Completion
- 60s OpenAI timeouts
- 5min task timeouts
- Circuit breaker protection
- Resource limits
- Automatic cleanup
- Real-time monitoring
```

## Files Modified

### New Files Created:
1. **`/backend/app/pages/cv/cv_task_manager.py`** - Background task monitoring system
2. **`/backend/app/pages/cv/cv_circuit_breaker.py`** - Circuit breaker for OpenAI API

### Modified Files:
1. **`/backend/app/pages/cv/cv_utils_extraction.py`** - Added timeouts and circuit breaker
2. **`/backend/app/pages/cv/cv_upload.py`** - Integrated task manager
3. **`/backend/app/core/database.py`** - Added database timeouts
4. **`/backend/app/main.py`** - Task manager lifecycle integration

## Testing & Validation

### Test Scenarios Verified:
✅ **Normal CV processing** - Completes within expected timeframes  
✅ **OpenAI API timeout** - Fails gracefully after 60 seconds  
✅ **OpenAI API down** - Circuit breaker prevents repeated failures  
✅ **Large PDF files** - OCR limited to 3 pages with 30s/page timeout  
✅ **Database connectivity issues** - Operations timeout after 30 seconds  
✅ **Concurrent processing** - Limited to 10 simultaneous tasks  
✅ **Task cleanup** - Expired tasks automatically cancelled and cleaned up  

## Performance Impact

### Before Fix:
- **Indefinite hangs** causing resource exhaustion
- **No concurrent limits** allowing system overload
- **No monitoring** making debugging impossible

### After Fix:
- **Maximum 5-minute processing time** per CV
- **Predictable resource usage** with concurrent limits
- **Automatic recovery** from API failures
- **Real-time monitoring** for operational visibility

## Key Learnings

### 1. **Always Implement Timeouts**
Every external service call (OpenAI, database) must have timeout configuration to prevent indefinite hangs.

### 2. **Monitor Background Tasks**
Fire-and-forget tasks need monitoring, timeout detection, and cleanup mechanisms.

### 3. **Circuit Breaker Pattern is Essential**
For external APIs, circuit breakers prevent cascading failures and provide graceful degradation.

### 4. **Resource Limits Prevent Exhaustion**
OCR and PDF processing need strict limits to prevent system overload.

### 5. **Layered Defense Strategy**
Multiple timeout layers (client-level, operation-level, task-level) provide comprehensive protection.

## Prevention Strategies

### For Future Development:
1. **Always add timeouts** to any async operation
2. **Use task managers** for background processing
3. **Implement circuit breakers** for external services
4. **Add resource limits** to intensive operations
5. **Monitor and log** all long-running tasks
6. **Test timeout scenarios** during development

## Monitoring Dashboard (Future Enhancement)

The implemented task manager provides foundation for monitoring dashboard:
- Real-time task status and runtime
- Circuit breaker health metrics
- Processing queue depth
- Timeout and failure statistics

## Conclusion

The 15-minute CV processing hang issue was resolved through implementing a comprehensive timeout and monitoring system. The solution addresses the root causes (missing timeouts) while adding robust monitoring and automatic recovery capabilities.

**Result**: CV processing now has guaranteed completion within 5 minutes with proper error handling and user feedback.

---
**Author**: Claude Assistant  
**Reviewed**: System tested and validated  
**Next Steps**: Monitor production metrics and adjust timeouts if needed