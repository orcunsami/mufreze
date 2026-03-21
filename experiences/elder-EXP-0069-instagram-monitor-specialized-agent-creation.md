# EXP-0069: Instagram Monitor - Specialized Agent Creation

**Project**: Instagram Monitor & Analyzer
**Date**: December 17, 2025
**Status**: ✅ SUCCESS
**Category**: Agent Development/API Testing/RapidAPI Integration
**Technologies**: FastAPI, Next.js 14, MongoDB, RapidAPI Instagram120, OpenAI GPT-4o, APScheduler, Telegram Bot API

---

## Context

Created a comprehensive specialized agent for the Instagram Monitor project and validated all API endpoints.

**Project Overview**:
- Monitor ~100 Instagram accounts
- Daily automated checks (APScheduler)
- Fetch last 5 posts + 5 reels per account
- Full GPT-4o analysis (text + vision)
- Reporting via Dashboard + Email + Telegram
- Personal use (no authentication)

**Stack**:
- Backend: FastAPI (port 8650)
- Frontend: Next.js 14 (port 3650)
- Database: MongoDB
- External APIs: RapidAPI Instagram120, OpenAI GPT-4o, SMTP, Telegram

---

## Problem

Needed a specialized agent to handle Instagram Monitor's unique requirements:
1. RapidAPI Instagram120 integration patterns
2. Instagram-specific CORS issues
3. Field naming conventions
4. ID patterns
5. Profile stats structure
6. Trap documentation

---

## Solution

### 1. Created Specialized Agent

**File**: `/Users/mac/.claude/agents/dev-instagram.md`

**Comprehensive Coverage**:
- Architecture patterns
- Field naming conventions (`{collection}_{field}`)
- ID patterns (`{entity}--{uuid}`)
- CORS handling
- RapidAPI Instagram120 specifics
- MongoDB patterns
- Frontend image handling
- 6 documented traps

### 2. Updated Agent Registry

**File**: `/Users/mac/.claude/agents/AGENT_REGISTRY.md`

Added dev-instagram to:
- Project-Specific Agents section
- Project Agent Matrix
- Capability index

### 3. API Endpoint Testing

Tested all 13 endpoints:

**Account Management** (4/4 passed):
- ✅ `GET /api/accounts` - List all accounts
- ✅ `POST /api/accounts` - Add account
- ✅ `GET /api/accounts/{account_id}` - Get single account
- ✅ `DELETE /api/accounts/{account_id}` - Delete account

**Content Fetching** (3/3 passed):
- ✅ `POST /api/instagram/fetch-posts/{account_id}` - Fetch posts
- ✅ `POST /api/instagram/fetch-reels/{account_id}` - Fetch reels
- ✅ `POST /api/instagram/refresh-profile/{account_id}` - Refresh profile

**Analytics** (3/3 passed):
- ✅ `GET /api/analytics/account/{account_id}` - Account analytics
- ✅ `POST /api/analytics/analyze-content/{content_id}` - Analyze content
- ✅ `GET /api/analytics/recent-analyses` - Recent analyses

**Scheduler** (1/1 passed):
- ✅ `POST /api/scheduler/trigger-daily` - Trigger daily check

**Reporting** (2/2 passed):
- ✅ `GET /api/reports/daily/{date}` - Daily report
- ✅ `POST /api/reports/send-telegram` - Send Telegram

---

## Key Learnings

### 1. Instagram-Specific CORS Handling

**Problem**: Instagram images blocked by browser CORS policy

**Solution**:
```typescript
<img
  src={account.account_profile_pic_url}
  crossOrigin="anonymous"
  referrerPolicy="no-referrer"
  alt={account.account_username}
/>
```

**Trap**: TRAP-IG-001

### 2. Profile Stats Structure

**Problem**: Profile stats can be null if API returns nested structure

**API Variations**:
```javascript
// Option 1: Direct fields
{
  "follower_count": 1234,
  "following_count": 567
}

// Option 2: Nested structure
{
  "edge_followed_by": { "count": 1234 },
  "edge_follow": { "count": 567 }
}
```

**Solution**: Handle both structures with fallback
```python
follower_count = (
    profile_data.get("follower_count") or
    profile_data.get("edge_followed_by", {}).get("count") or
    0
)
```

**Trap**: TRAP-IG-003

### 3. RapidAPI Data Structure

**Problem**: RapidAPI returns posts/reels in edges/nodes structure, not items array

**Actual Structure**:
```javascript
{
  "data": {
    "user": {
      "edge_owner_to_timeline_media": {
        "edges": [
          { "node": { /* post data */ } }
        ]
      }
    }
  }
}
```

**Trap**: TRAP-IG-006

### 4. Field Naming Convention

**Pattern**: Always prefix with collection name
- `account_username` (not just `username`)
- `post_caption` (not just `caption`)
- `reel_view_count` (not just `view_count`)

**Benefits**:
- No ambiguity in joins
- Clear ownership
- Easier grep searches
- Consistent across collections

### 5. ID Pattern

**Pattern**: Always use `{entity}--{uuid}`
- `account--550e8400-e29b-41d4-a716-446655440000`
- `post--550e8400-e29b-41d4-a716-446655440001`
- `reel--550e8400-e29b-41d4-a716-446655440002`

**Benefits**:
- Human readable
- Entity type identification
- No MongoDB _id confusion
- URL-safe

**Trap**: TRAP-IG-005

### 6. MongoDB Async Operations

**Problem**: Missing `await` in MongoDB operations causes silent failures

**Solution**: Always use async/await
```python
# ❌ Wrong
result = collection.insert_one(data)

# ✅ Correct
result = await collection.insert_one(data)
```

**Trap**: TRAP-IG-004

---

## Documented Traps

### TRAP-IG-001: CORS Blocking Instagram Images
**Symptom**: Images fail to load, CORS errors in console
**Solution**: Add `crossOrigin="anonymous" referrerPolicy="no-referrer"`

### TRAP-IG-002: RapidAPI Rate Limits
**Symptom**: 429 errors, quota exceeded
**Solution**: Implement exponential backoff, cache profile data

### TRAP-IG-003: Null Profile Stats
**Symptom**: Follower/following counts missing
**Solution**: Handle nested structure (edge_followed_by.count)

### TRAP-IG-004: Missing Await in MongoDB
**Symptom**: Operations appear to succeed but data not saved
**Solution**: Always await Motor async operations

### TRAP-IG-005: Wrong ID Pattern
**Symptom**: Mixing MongoDB _id with custom IDs
**Solution**: Use {entity}--{uuid} pattern consistently

### TRAP-IG-006: RapidAPI Response Structure
**Symptom**: Cannot find posts/reels in response
**Solution**: Access via edges/nodes structure

---

## Agent Capabilities

### Core Features
1. **Account Management**: CRUD operations with validation
2. **Content Fetching**: RapidAPI Instagram120 integration
3. **GPT-4o Analysis**: Text + vision analysis
4. **Scheduling**: Daily automated checks
5. **Reporting**: Dashboard + Email + Telegram
6. **CORS Handling**: Instagram image loading
7. **Error Recovery**: Exponential backoff, retries

### Architecture Patterns
- Functional programming style
- Service layer separation
- MongoDB async operations
- Field naming: `{collection}_{field}`
- ID format: `{entity}--{uuid}`

### Tech Stack Expertise
- FastAPI backend patterns
- Next.js 14 App Router
- MongoDB with Motor
- RapidAPI integration
- OpenAI GPT-4o
- APScheduler
- Telegram Bot API

---

## Testing Results

**Total Endpoints**: 13
**Passed**: 13 (100%)
**Failed**: 0

**Categories Tested**:
- Account Management: 4/4 ✅
- Content Fetching: 3/3 ✅
- Analytics: 3/3 ✅
- Scheduler: 1/1 ✅
- Reporting: 2/2 ✅

---

## Impact

### HIGH Impact

**Benefits**:
1. **Specialized Knowledge**: Instagram-specific patterns documented
2. **Trap Prevention**: 6 common issues documented upfront
3. **Consistent Patterns**: Field naming, ID format, CORS handling
4. **API Validation**: All 13 endpoints tested and working
5. **Reusable Knowledge**: Patterns applicable to other social media APIs

**Cross-Project Value**:
- CORS handling for external images
- RapidAPI integration patterns
- Async MongoDB best practices
- Field naming conventions
- ID pattern standardization

---

## Related Experiences

- **[EXP-0041](EXP-0041-kiwi-roadie-complete-profile-management-system.md)**: Profile API patterns
- **[EXP-0042](EXP-0042-kiwi-roadie-critical-profile-debugging-patterns.md)**: Mobile debugging
- **[EXP-0066](EXP-0066-jira-slack-integration-api-changes.md)**: API integration patterns
- **[EXP-0023](EXP-0023-odtu-events-api-error.md)**: MongoDB async operations

---

## Tags

`agent-development`, `api-testing`, `rapidapi`, `instagram-api`, `fastapi`, `nextjs`, `mongodb`, `cors`, `field-naming`, `id-patterns`, `trap-documentation`, `social-media-api`, `gpt4o`, `apscheduler`, `telegram-bot`

---

## Prevention Protocol

### Before Creating New Agents
1. ✅ Document architecture patterns
2. ✅ Define field naming conventions
3. ✅ Establish ID patterns
4. ✅ Document common traps
5. ✅ Test all API endpoints
6. ✅ Update agent registry

### Before Using External APIs
1. ✅ Document response structure
2. ✅ Handle rate limits
3. ✅ Implement error recovery
4. ✅ Cache when possible
5. ✅ Document CORS requirements

### Before MongoDB Operations
1. ✅ Always use async/await
2. ✅ Use consistent ID patterns
3. ✅ Prefix fields with collection name
4. ✅ Handle null values gracefully

---

**Files Created**:
- `/Users/mac/.claude/agents/dev-instagram.md` - Specialized agent
- Updated: `/Users/mac/.claude/agents/AGENT_REGISTRY.md` - Agent registry

**Lines Changed**: ~850 lines of comprehensive documentation

**Time Invested**: 2 hours (agent creation + testing + documentation)

**Success Metric**: 100% API endpoint pass rate, 6 traps documented proactively
