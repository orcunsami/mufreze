# Experience 0027: Enterprise Chat System Implementation with WebSocket and MongoDB

## Date
June 29, 2025

## Category
Full-Stack Architecture, Real-time Systems, WebSocket, MongoDB

## Problem Statement
Implement a comprehensive enterprise chat system for 1200+ ODTU students with:
- 72 predefined rooms (generic, department, city-based)
- Real-time messaging via WebSocket
- Role-based access control
- MongoDB inconsistency issues with existing data
- WebSocket "Access denied" errors
- Database index conflicts

## Investigation Process

### Initial Requirements
1. 72 rooms total:
   - 12 generic rooms (0000-0011)
   - 40 department rooms (0100-0139)
   - 20 city rooms (0200-0219)
2. 4-tier role system: user, moderator, admin, chef_admin
3. Real-time messaging with Socket.IO
4. Ban system for moderation
5. DM system (future)

### Issues Encountered

1. **Database Index Error**:
   ```
   DuplicateKeyError: E11000 duplicate key error collection: odtuyenidonem_db.chat_rooms 
   index: room_type_1_room_identifier_1 dup key: { room_type: "generic", room_identifier: null }
   ```

2. **WebSocket Access Denied**:
   - REST API working (200 OK)
   - WebSocket join_room failing with "Access denied"

3. **Data Inconsistency**:
   - 160 rooms in database (should be 72)
   - Room type 'mixed' not in allowed types
   - Missing required fields: room_label, room_created_by_account_id

## Root Cause Analysis

1. **Index Conflict**: The unique index on `(room_type, room_identifier)` was failing because `room_identifier` field was not being set, resulting in multiple documents with null values.

2. **WebSocket Query Issues**:
   - Using `{"account_id": account_id}` instead of `{"account_id": account_id}` for account lookup
   - Inconsistent collection names: `db.rooms` vs `db.chat_rooms`

3. **Legacy Data**: Previous iterations created rooms with incompatible structure and 'mixed' type.

## Solution Implementation

### 1. Fixed Database Schema and Models

```python
# chat_models.py - Added room_identifier and mixed type
class RoomBase(BaseModel):
    room_label: Optional[str] = Field(None, pattern=r"^[0-2]\d{3}$")
    room_name: str = Field(..., min_length=3, max_length=100)
    room_type: Literal["generic", "department", "city", "mixed"]  # Added mixed
    room_identifier: Optional[str] = None  # Added field
```

### 2. Fixed Collection Name Consistency

Used Task tool to update all files from `db.rooms` to `db.chat_rooms`:
- init_rooms.py
- room_join_post.py
- room_get_by_id_get.py
- All other room-related files

### 3. Fixed WebSocket Authentication

```python
# connection_manager.py - Fixed account query
# Before:
user = await db.accounts.find_one({"account_id": account_id})

# After:
user = await db.accounts.find_one({"account_id": account_id})
```

### 4. Created Management Scripts

Created `/app/pages/chat/manage/` directory with:
- `create_rooms.py` - Manually create 72 predefined rooms
- `delete_all_rooms.py` - Delete all chat data with confirmation
- `list_rooms.py` - List all rooms with statistics
- `README.md` - Documentation

### 5. Made Room Creation Manual

```python
# main.py - Commented out automatic room creation
# Chat rooms are now managed manually via manage/create_rooms.py
# if settings.CHAT_SYSTEM_ENABLED:
#     from app.pages.chat.init_rooms import initialize_rooms
#     await initialize_rooms()
```

## Verification

1. **Cleaned Database**:
   ```bash
   python reset_chat_system.py  # Deleted 160 misconfigured rooms
   ```

2. **Server Restart**: Rooms no longer auto-created

3. **Manual Room Creation**:
   ```bash
   python manage/create_rooms.py  # Created 72 proper rooms
   ```

4. **WebSocket Test Results**:
   - ✅ Connection established
   - ✅ Room join successful
   - ✅ Messages sent/received
   - ✅ Typing indicators working

## Lessons Learned

1. **Database Indexes**: Always ensure unique index fields are properly populated. Use compound indexes carefully.

2. **Query Consistency**: MongoDB field names must match exactly. `_id` vs `account_id` caused silent failures.

3. **Collection Naming**: Establish naming conventions early and enforce consistency across all files.

4. **Data Migration**: When schema changes significantly, sometimes a clean reset is better than complex migrations.

5. **Manual vs Automatic**: For development environments, manual control over data initialization can be more flexible than automatic seeding.

6. **Modular Architecture**: The file-per-endpoint pattern made fixing issues easier - each endpoint was isolated.

## Related Code

### Key Files Modified:
- `/app/main.py` - Removed automatic room initialization
- `/app/pages/chat/connection_manager.py` - Fixed account queries
- `/app/pages/chat/chat_models.py` - Added room_identifier, mixed type
- `/app/pages/chat/init_rooms.py` - Added room_identifier generation
- `/app/pages/chat/room_list_get.py` - Added error handling for missing fields

### New Management Scripts:
- `/app/pages/chat/manage/create_rooms.py`
- `/app/pages/chat/manage/delete_all_rooms.py`
- `/app/pages/chat/manage/list_rooms.py`

### Test Scripts Created:
- `/app/pages/chat/test/test_websocket.py`
- `/app/pages/chat/test/test_ban_endpoints.py`
- `/app/pages/chat/test/reset_chat_system.py`
- `/app/pages/chat/test/migrate_rooms.py`

## Architecture Decisions

1. **Socket.IO Mounting**: Mounted dynamically during startup instead of creating sio_app upfront
2. **ID Format**: Maintained `{entity}--{uuid}` pattern (e.g., "room--uuid4")
3. **Room Identifiers**: Added unique identifiers like "generic_0001", "dept_0100"
4. **Manual Management**: Separated data initialization from server startup for better control

## Future Improvements

1. Add room creation/deletion API endpoints for admin panel
2. Implement automatic cleanup of old messages
3. Add room statistics dashboard
4. Implement the planned DM system
5. Add room member limits enforcement