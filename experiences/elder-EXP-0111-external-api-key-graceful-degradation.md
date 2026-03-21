# EXP-0097: External API Key Unavailable → Graceful Degradation Pattern

| Field | Value |
|-------|-------|
| **ID** | EXP-0097 |
| **Date** | 2026-02-28 |
| **Project** | x-twitter (RapidAPI + Twitter) |
| **Category** | API Integration/UX Architecture |
| **Status** | SUCCESS |
| **Technologies** | FastAPI, Next.js, MongoDB, RapidAPI, React |

## Problem Description

`RAPIDAPI_KEY=placeholder` was set in `.env`. When the frontend loaded `/users/[username]`, it called `GET /api/users/{username}`, which tried to fetch a live Twitter profile → RapidAPI failed → backend returned 404 → frontend called `setError()` → the ENTIRE PAGE was blocked by an error card. No tweet analysis, no stored data, nothing was visible — even though the backend had relevant DB data.

## Root Cause Analysis

"All-or-nothing" failure mode caused by Happy Path Blindness. The profile fetch was treated as a critical dependency for the entire page. If profile load fails → page is unusable. The system was designed only for the scenario where the external API key exists and works.

**Wrong pattern (frontend):**
```typescript
async function loadData() {
  try {
    const profileData = await fetchUserProfile(username);
    setProfile(profileData);
  } catch (err) {
    // ❌ Single error state blocks ENTIRE page render
    setError(err instanceof Error ? err.message : "Failed to load user");
  } finally {
    setLoading(false);
  }
}

// In JSX — entire page replaced by error:
if (error) {
  return <ErrorCard>{error}</ErrorCard>;  // ❌ Nothing else shown
}
```

**Wrong pattern (backend):**
```python
@router.get("/{username}")
async def get_user_profile(username: str):
    result = await twitter_client.get_user_profile(username)
    if not result:
        # ❌ Hard 404 — no fallback to DB data
        raise HTTPException(status_code=404, detail=f"User {username} not found")
    return result
```

## Solution

**Pattern: Independent Section Loading.** Each page section handles its own failure silently. Only truly critical failures (e.g., user doesn't exist anywhere) block the page.

**Correct pattern (frontend):**
```typescript
async function loadData() {
  try {
    const profileData = await fetchUserProfile(username);
    setProfile(profileData);
  } catch {
    // ✅ Profile unavailable → continue without it. Page still works.
    setProfile(null);
  } finally {
    setLoading(false);
  }
}

// In JSX — each section is independent:
{profile?.user_result_by_screen_name?.result && (
  <TwitterProfileCard result={profile.user_result_by_screen_name.result} />
)}
{profile?._source === "tracked_accounts" && (
  <FallbackProfileCard username={profile.username} category={profile.category} />
)}
{/* Rest of page shows regardless of profile state */}
<TweetAnalysisSection tweets={storedTweets} />
<WordcloudSection tweets={storedTweets} />
```

**Correct pattern (backend — with DB fallback):**
```python
@router.get("/{username}")
async def get_user_profile(username: str):
    # Try live API first
    result = await twitter_client.get_user_profile(username)
    if result:
        return result

    # ✅ Fallback: return DB data instead of hard 404
    db = get_db()
    tracked = await db.tracked_accounts.find_one({"username": username.lower()})
    if tracked:
        return {
            "_source": "tracked_accounts",  # Frontend uses this to show fallback UI
            "username": tracked["username"],
            "category": tracked.get("category"),
            "added_at": str(tracked.get("added_at", "")),
        }

    # Only now: truly not found anywhere
    raise HTTPException(status_code=404, detail=f"User {username} not found")
```

**The pattern: Independent section loading**
```
Page Load
  ├── Profile section:  try API → fallback to DB → null (show placeholder card)
  ├── Tweets section:   try DB → null (show "no tweets yet" message)
  ├── Wordcloud:        try generate → null (section hidden, not error)
  └── Engagement:       try calculate → null (section hidden, not error)
```

## Detection Methods

```bash
# Test backend directly — does it return something useful without API key?
curl -s http://localhost:8570/api/users/elonmusk | python3 -m json.tool

# Check .env for placeholder keys
grep -E "(RAPIDAPI_KEY|API_KEY|SECRET)=placeholder" backend/.env

# Frontend: look for global error state that blocks entire page
grep -n "if (error)" frontend/src/app/**/*.tsx
```

## Prevention Checklist

- [ ] Ask "Ya API key yoksa?" for every external API integration at design time
- [ ] Each UI section should have its own independent try/catch with null fallback
- [ ] Backend should have DB fallback for all external API calls
- [ ] Never use a single global `error` state that blocks the entire page for non-critical data
- [ ] Use `_source` field in API responses to signal data quality/origin to frontend
- [ ] Design the "no data" empty state UI first, before the happy path UI
- [ ] Test with `RAPIDAPI_KEY=placeholder` before deploying to catch these failures early

## Cross-Project Applicability

| Project | External API | Risk | Action |
|---------|-------------|------|--------|
| x-twitter | RapidAPI (Twitter) | Fixed | Monitor after real key added |
| HocamClass | OpenAI | HIGH | Ensure AI fail doesn't block page |
| Any SaaS | Stripe, SendGrid, etc. | MEDIUM | Each section independent |
| CSC Platform | External threat APIs | HIGH | Fallback to cached data |

## Keywords

rapidapi, api-key, graceful-degradation, error-handling, null-state, ux, fastapi, nextjs, fallback, tracked-accounts, setError, happy-path, independent-sections, partial-failure, resilience

## Lessons Learned

1. Happy Path Blindness is a UX design smell — always design the "no data" / "API down" case before the happy path
2. `_source` field in responses helps frontend differentiate data quality (live vs cached vs fallback)
3. API key placeholder in `.env` is NORMAL in new projects — design for it from day one
4. Section-level null handling is always better than page-level error blocking
5. The test: "If I delete the API key from .env right now, does the page still load something useful?" — answer should always be yes

## See Also

- EXP-0096: Nginx + FastAPI Double CORS Header Problem
- EXP-0098: Python Venv Mac → VPS Portability Issue
- MEMORY.md: `/users/[username]` Sayfası — ÇÖZÜLDÜ (2026-02-28)
