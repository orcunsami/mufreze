# EXP-0079: Anonymous Session Pattern (Vue.js + FastAPI + MongoDB)

## Metadata
| Field | Value |
|-------|-------|
| **Experience ID** | EXP-0079 |
| **Project** | HocamClass |
| **Task ID** | HCLASS-anonymous-session |
| **Date** | 2026-02-01 |
| **Category** | Architecture/Session Management |
| **Technologies** | Vue.js 3, FastAPI, MongoDB, localStorage |
| **Status** | SUCCESS |
| **Time Spent** | 45 minutes |

---

## Problem Description

Need to allow anonymous users to use certain features (e.g., saving notes, adding to cart) without requiring login, while:
1. Persisting their data across page refreshes
2. Automatically cleaning up old anonymous data
3. Allowing data transfer when they register/login

---

## Solution Architecture

### 1. Frontend: Session ID Generation (Vue.js)

```typescript
// composables/useAnonymousSession.ts
export function useAnonymousSession() {
  const SESSION_KEY = 'anonymous_session_id'

  function getOrCreateSessionId(): string {
    let sessionId = localStorage.getItem(SESSION_KEY)

    if (!sessionId) {
      // Generate 64-character hex string
      const array = new Uint8Array(32)
      crypto.getRandomValues(array)
      sessionId = Array.from(array)
        .map(b => b.toString(16).padStart(2, '0'))
        .join('')

      localStorage.setItem(SESSION_KEY, sessionId)
    }

    return sessionId
  }

  function clearSession(): void {
    localStorage.removeItem(SESSION_KEY)
  }

  return {
    getOrCreateSessionId,
    clearSession
  }
}
```

### 2. Backend: MongoDB Model with TTL Index (FastAPI)

```python
# models/anonymous_session.py
from datetime import datetime, timedelta
from pydantic import BaseModel, Field
from typing import Optional, List, Any

class AnonymousSession(BaseModel):
    session_id: str = Field(..., index=True)
    data: dict = Field(default_factory=dict)
    created_at: datetime = Field(default_factory=datetime.utcnow)
    expires_at: datetime = Field(
        default_factory=lambda: datetime.utcnow() + timedelta(days=7)
    )

    class Config:
        json_schema_extra = {
            "example": {
                "session_id": "a1b2c3d4...",
                "data": {"notes": [], "preferences": {}},
                "created_at": "2026-02-01T10:00:00Z",
                "expires_at": "2026-02-08T10:00:00Z"
            }
        }
```

### 3. MongoDB TTL Index Setup

```python
# database/indexes.py
async def create_indexes(db):
    # TTL index: automatically delete documents when expires_at is reached
    await db.anonymous_sessions.create_index(
        "expires_at",
        expireAfterSeconds=0  # Delete exactly at expires_at time
    )

    # Unique index on session_id for fast lookups
    await db.anonymous_sessions.create_index(
        "session_id",
        unique=True
    )
```

### 4. API Endpoints

```python
# routers/anonymous.py
from fastapi import APIRouter, HTTPException
from datetime import datetime, timedelta

router = APIRouter(prefix="/anonymous", tags=["anonymous"])

@router.post("/session")
async def create_or_update_session(session_id: str, data: dict):
    """Create or update anonymous session data"""
    result = await db.anonymous_sessions.update_one(
        {"session_id": session_id},
        {
            "$set": {
                "data": data,
                "expires_at": datetime.utcnow() + timedelta(days=7)
            },
            "$setOnInsert": {
                "session_id": session_id,
                "created_at": datetime.utcnow()
            }
        },
        upsert=True
    )
    return {"success": True}

@router.get("/session/{session_id}")
async def get_session(session_id: str):
    """Get anonymous session data"""
    session = await db.anonymous_sessions.find_one({"session_id": session_id})
    if not session:
        return {"data": {}}
    return {"data": session.get("data", {})}

@router.post("/claim")
async def claim_session(session_id: str, user_id: str):
    """Transfer anonymous session data to user account"""
    # 1. Get anonymous session
    session = await db.anonymous_sessions.find_one({"session_id": session_id})
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")

    # 2. Merge data into user profile
    await db.users.update_one(
        {"_id": user_id},
        {"$push": {"notes": {"$each": session.get("data", {}).get("notes", [])}}}
    )

    # 3. Delete anonymous session
    await db.anonymous_sessions.delete_one({"session_id": session_id})

    return {"success": True, "claimed_items": len(session.get("data", {}).get("notes", []))}
```

---

## Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    ANONYMOUS SESSION FLOW                    │
└─────────────────────────────────────────────────────────────┘

1. First Visit (No Session)
   ┌──────────┐     ┌────────────────┐     ┌──────────────┐
   │  User    │ --> │ Check Storage  │ --> │ Generate ID  │
   │  Opens   │     │ (empty)        │     │ (64-char)    │
   │  Page    │     └────────────────┘     └──────────────┘
                                                   │
                                                   v
                                           ┌──────────────┐
                                           │ Save to      │
                                           │ localStorage │
                                           └──────────────┘

2. Save Anonymous Data
   ┌──────────┐     ┌────────────────┐     ┌──────────────┐
   │  User    │ --> │ Get Session ID │ --> │ POST /api/   │
   │  Adds    │     │ from Storage   │     │ anonymous/   │
   │  Note    │     └────────────────┘     │ session      │
   └──────────┘                            └──────────────┘
                                                   │
                                                   v
                                           ┌──────────────┐
                                           │ MongoDB:     │
                                           │ upsert with  │
                                           │ TTL=7 days   │
                                           └──────────────┘

3. User Registers/Logs In
   ┌──────────┐     ┌────────────────┐     ┌──────────────┐
   │  User    │ --> │ POST /api/     │ --> │ Move data to │
   │  Login   │     │ anonymous/     │     │ user profile │
   │          │     │ claim          │     └──────────────┘
   └──────────┘     └────────────────┘             │
                                                   v
                                           ┌──────────────┐
                                           │ Delete       │
                                           │ anonymous    │
                                           │ session      │
                                           └──────────────┘

4. Auto Cleanup (No User Action)
   ┌──────────────┐     ┌────────────────┐
   │ MongoDB TTL  │ --> │ Delete expired │
   │ Background   │     │ sessions       │
   │ Task         │     │ (expires_at)   │
   └──────────────┘     └────────────────┘
```

---

## Key Implementation Details

### Session ID Security
- 64 characters (32 bytes) provides 256 bits of entropy
- Cryptographically secure random generation
- Practically impossible to guess/brute-force

### TTL Index Behavior
- `expireAfterSeconds: 0` means MongoDB uses the `expires_at` field value directly
- MongoDB's TTL monitor runs every 60 seconds
- Documents may persist slightly longer than `expires_at` due to cleanup interval

### Data Merge Strategy
When claiming session data:
1. **Append**: Add anonymous data to existing user data (`$push`)
2. **Merge**: Combine preferences with user preferences (`$set` with spread)
3. **Replace**: Overwrite user data with anonymous data (rare use case)

---

## Patterns Applied
- `anonymous-session-management`: Guest user data persistence
- `mongodb-ttl-index`: Automatic document expiration
- `localStorage-session-tracking`: Client-side session identification
- `data-claim-pattern`: Transfer anonymous data to authenticated users

---

## Prevention Checklist
- [ ] TTL index created on `expires_at` field
- [ ] Unique index on `session_id` for fast lookups
- [ ] Session ID generated with crypto.getRandomValues()
- [ ] Claim endpoint deletes anonymous session after transfer
- [ ] Handle case where user already has data (merge vs. replace)
- [ ] Clear localStorage after successful claim

---

## Related Experiences
- [EXP-0041](EXP-0041-kiwi-roadie-complete-profile-management-system.md): Profile Management System
- [EXP-0057](EXP-0057-vps2-mongodb-authentication-enable.md): MongoDB Configuration

---

## Tags
`anonymous-session`, `guest-user`, `mongodb-ttl`, `localStorage`, `session-management`, `data-claim`, `vue.js`, `fastapi`, `upsert`, `crypto-random`
