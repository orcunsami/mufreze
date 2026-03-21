# EXP-0090: Quiz Thumbnail VPS Sync Issue

**Date**: 2026-02-02
**Project**: SenlikBuddy (idate)
**Severity**: Medium
**Tags**: `image-loading`, `vps-sync`, `silent-failure`, `react-native`, `expo`

## Problem

Quiz thumbnail images not displaying in the mobile app. UI shows blank space where thumbnails should be.

## Symptoms

1. Database has correct image paths (`/uploads/quiz-photos/xxx-thumbnail.webp`)
2. Backend endpoint returns HTTP 200
3. Frontend shows empty space (no error, no broken image icon)
4. React Native Image component fails silently

## Root Cause

Files uploaded via admin panel are saved **only to VPS**, not to local development machine.

The flow:
```
Admin uploads image → VPS saves file → Database stores path
                        ↓
Local development environment has NO file
                        ↓
Backend returns 200 (route exists) but 0 bytes content
                        ↓
Image component gets valid URL but empty response
                        ↓
Silent failure - shows blank space
```

## Diagnosis Steps

1. **Check database**: `mongosh idate --eval "db.quizzes.find({}, {quiz_thumbnail_url: 1})"`
   - Result: URLs correct (`/uploads/quiz-photos/xxx.webp`)

2. **Test backend**: `curl -s -o /dev/null -w "%{http_code}" "http://localhost:3031/uploads/quiz-photos/xxx.webp"`
   - Result: 200 (but 0 bytes)

3. **Check local files**: `ls ./public/uploads/quiz-photos/`
   - Result: Empty or missing

4. **Check VPS files**: `ssh root@VPS "ls /projects/idate-backend/public/uploads/quiz-photos/"`
   - Result: Files exist!

## Solution

### Immediate Fix

Download files from VPS to local:

```bash
scp -r root@212.28.188.151:/projects/idate-backend/public/uploads/quiz-photos/* \
    /Users/mac/Documents/freelance/senlikbuddy/senlikbuddy-mobile-backend/public/uploads/quiz-photos/
```

### Permanent Fix (Frontend)

Add Ionicons fallback for missing images:

```typescript
const [failedImages, setFailedImages] = useState<Set<string>>(new Set());

const showFallback = !thumbnailUrl || failedImages.has(item.id);

{showFallback ? (
  <View style={[styles.iconContainer, { backgroundColor: getIcon(item.name).color + '15' }]}>
    <Ionicons name={getIcon(item.name).name} size={24} color={getIcon(item.name).color} />
  </View>
) : (
  <Image
    source={{ uri: thumbnailUrl }}
    style={styles.thumbnail}
    onError={() => setFailedImages(prev => new Set(prev).add(item.id))}
  />
)}
```

## Prevention

1. After admin uploads, sync files: `scp -r root@VPS:/path/* ./local/path/`
2. Always add image fallback (Ionicons) for graceful degradation
3. Don't trust Image component to show errors - it fails silently

## Related Files

- `senlikbuddy-mobile-frontend/src/screens/quizzes/QuizStatusesScreen.tsx`
- `senlikbuddy-mobile-backend/public/uploads/quiz-photos/`
- VPS: `/projects/idate-backend/public/uploads/quiz-photos/`

## Key Lesson

**React Native Image fails silently!** Always implement:
1. `onError` handler to track failures
2. Fallback UI (Ionicons, placeholder, etc.)
3. State to prevent infinite re-renders on error
