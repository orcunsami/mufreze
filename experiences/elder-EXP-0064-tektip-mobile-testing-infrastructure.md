# EXP-0064: TekTıp Mobile Testing Infrastructure

## Metadata
- **Date**: 2025-12-15
- **Project**: TekTıp Mobile (tektip-mobile-orcun)
- **Category**: Testing, Mobile Development, React Native
- **Severity**: HIGH (Repeated same mistake multiple times)

## Problem Statement

When testing TekTıp mobile app on iOS Simulator, I repeatedly attempted to use:
1. `osascript` keyboard input (`keystroke "email@test.com"`)
2. `xcrun simctl io booted input text` (doesn't exist)
3. Manual AppleScript click coordinates

**Result**: None of these work reliably. Characters get garbled (e.g., "t'murœtekt'p" instead of "timur@tektip.health").

## Root Cause Analysis

1. **osascript limitations**: AppleScript `keystroke` command doesn't handle special characters correctly when targeting iOS Simulator
2. **xcrun simctl**: The `input text` subcommand doesn't exist - it's a common misconception
3. **Click coordinates**: Simulator window size and scale can vary, making coordinates unreliable

## Solution: Use Proper Testing Tools

### Already Available (Not Used!)

The project already has proper testing infrastructure that I failed to use:

| Tool | Location | npm Script |
|------|----------|------------|
| **Playwright** | `tests/e2e/` | `npm test` |
| **Maestro** | `tests/maestro/` | `npm run test:maestro` |

### Correct Approach

```bash
# Playwright (Expo Web mode) - Fast, reliable
npx expo start --web --port 19006 &
npm test

# Maestro (Native iOS/Android) - More realistic
npx expo start --ios &
maestro test tests/maestro/doctor-dashboard.yaml
```

### API-Based Login Workaround

For bypassing UI input issues entirely:

```typescript
// tests/e2e/helpers/login.helper.ts
export async function loginViaApi(page, email: string, password: string) {
  const response = await axios.post('http://172.20.10.2:8000/api/login', {
    email,
    password,
    device_type: 'ios',
    device_token: 'test-device-token',
    user_type: 2
  });

  await page.evaluate((t) => localStorage.setItem('auth_token', t), response.data.token);
  await page.reload();
}
```

## Anti-Patterns to Avoid (CRITICAL!)

```bash
# NEVER DO THESE:

# 1. osascript keyboard input
osascript -e 'tell application "System Events" to keystroke "test@email.com"'
# Result: "t'estŒmail.c"m" (garbled)

# 2. xcrun simctl input text (doesn't exist!)
xcrun simctl io booted input text "test@email.com"
# Result: Command not found

# 3. AppleScript click coordinates
osascript -e 'click at {370, 630}'
# Result: Unreliable, varies by window size/scale

# ALWAYS DO THIS INSTEAD:
npm test                                    # Playwright
maestro test tests/maestro/login-flow.yaml  # Maestro
```

## Files Modified

1. **package.json**: Added Maestro npm scripts
   ```json
   "test:maestro": "maestro test tests/maestro/",
   "test:maestro:doctor": "maestro test tests/maestro/doctor-dashboard.yaml"
   ```

2. **~/.claude/agents/dev-tiktip-testing.md**: Added 200+ lines of mobile testing documentation

## Lessons Learned

1. **Check existing tools first**: Before creating hacky solutions, look at what's already in the project
2. **Use established frameworks**: Playwright and Maestro exist for a reason - they handle edge cases
3. **API-based shortcuts**: When UI testing is unreliable, bypass with direct API calls
4. **Document anti-patterns**: Explicitly document what NOT to do to prevent recurrence

## Prevention Framework

When tasked with mobile testing:

1. **First**: Check for existing test infrastructure (`tests/`, `playwright.config.ts`, `*.yaml`)
2. **Second**: Verify npm scripts available (`npm run test:*`)
3. **Third**: If UI input needed, use API-based login helper
4. **NEVER**: Resort to osascript or xcrun simctl hacks

## Related Files

- `/Users/mac/Documents/work-tiktip/tektip-mobile-orcun/tests/e2e/` - Playwright tests
- `/Users/mac/Documents/work-tiktip/tektip-mobile-orcun/tests/maestro/` - Maestro tests
- `/Users/mac/Documents/work-tiktip/tektip-mobile-orcun/tests/e2e/helpers/login.helper.ts` - API-based login
- `~/.claude/agents/dev-tiktip-testing.md` - Testing agent documentation

---

## Endpoint Mapping Audit (2025-12-15 Evening)

### Issue Found
NotificationService.ts was using wrong endpoints:
- ❌ `/notifications` (doesn't exist)
- ✅ `/get-notifications` (correct Laravel route)

### Fix Applied
Updated `src/services/NotificationService.ts`:
```typescript
// BEFORE (WRONG):
api.get('/notifications')
api.post('/notifications/mark-all-read')
api.delete('/notifications/{id}')

// AFTER (CORRECT):
api.get('/get-notifications')                    // Line 54
api.post('/notifications/{id}/mark-as-read')     // Line 111
api.post('/notifications/mark-all-as-read')      // Line 129
api.post('/delete-notifications/{id}')           // Line 148
```

### Full Endpoint Audit Results

**Total Endpoints**: 35
**Working**: 31 (89%)
**Missing in Backend**: 3
**Needs Check**: 1

| Service | Total | OK | Missing |
|---------|-------|-----|---------|
| AuthService | 6 | 5 | 0 |
| BookingService | 6 | 6 | 0 |
| AvailabilityService | 7 | 5 | 2 |
| NotificationService | 4 | 4 | 0 |
| ProfileService | 1 | 1 | 0 |
| MetadataService | 6 | 6 | 0 |
| PaymentService | 3 | 2 | 1 |
| Other | 2 | 2 | 0 |

### Missing Backend Routes (Not Critical) - MARKED AS DEAD CODE
1. `/copy_week_schedule` - AvailabilityService.ts:235 → **@deprecated NOT_IMPLEMENTED**
2. `/block_date_range` - AvailabilityService.ts:253 → **@deprecated NOT_IMPLEMENTED**
3. `/booking/{id}/payment-url` - PaymentService.ts:180 → **@deprecated NOT_IMPLEMENTED**

**Action Taken (2025-12-15)**: All 3 methods marked as `@deprecated` with clear `NOT_IMPLEMENTED` comments.
They now throw/return immediately with Turkish error messages instead of making failing API calls.

### NEEDS_BACKEND_API
1. `/reset-password` - AuthService.ts:291 → **NEEDS_BACKEND_API**
   - Backend has WEB route only: `POST /doctor/reset-password` (returns redirect)
   - No API endpoint exists in `routes/api.php`
   - Mobile shows user-friendly error: "Şifre sıfırlama mobil uygulamada henüz desteklenmiyor"

**Action Taken (2025-12-15)**: Method documented with `@deprecated NEEDS_BACKEND_API` and helpful error message added.

### Key Lesson
**BEFORE writing mobile API calls, ALWAYS check Laravel routes first!**

Reference: `/Users/mac/Documents/work-tiktip/tektip-web-orcun/routes/api.php`

---

---

## Booking Status Code Mismatch Fix (2025-12-16)

### Issue Found
Mobile app (TekTıp Mobile - Doctor App) sent `status=4` for "Gelemedi" (no-show) marking, but backend only accepted `status in [0,1,2,3]`. This caused a 422 validation error.

### Root Cause
- Mobile `BookingStatus` enum: `{ PENDING=0, CONFIRMED=1, COMPLETED=2, CANCELLED=3, NO_SHOW=4 }`
- Backend validation: `'status' => 'required|in:0,1,2,3'`
- Status 4 was not accepted!

### Fix Applied (3 files modified)

**1. Migration: `2025_12_16_100000_add_is_no_show_to_bookings_table.php`**
```php
$table->boolean('is_no_show')->default(false);
$table->string('no_show_reason', 500)->nullable();
```

**2. BookingController.php (lines 595-650)**
```php
// Updated validation
'status' => 'required|in:0,1,2,3,4',
'reason' => 'nullable|string|max:500',

// Handle no-show
if ($request->status == 4) {
    $booking->is_no_show = true;
    $booking->no_show_reason = $request->reason ?? null;
    $booking->booking_status = 3; // Set to completed with no-show flag
}
```

**3. Booking.php model (fillable array)**
```php
'is_no_show',
'no_show_reason',
```

### Lesson Learned
**BEFORE implementing mobile features, verify backend validation rules match mobile's expected values!**

### Status Codes Reference
| Code | Backend | Mobile | Description |
|------|---------|--------|-------------|
| 0 | pending | PENDING | Beklemede |
| 1 | confirmed | CONFIRMED | Onaylandı |
| 2 | cancelled | COMPLETED | Mobile: Completed, Backend: Cancelled |
| 3 | completed | CANCELLED | Mobile: Cancelled, Backend: Completed |
| 4 | no-show | NO_SHOW | Gelemedi (with is_no_show=true) |

⚠️ **WARNING**: There's still a mismatch between mobile's COMPLETED=2/CANCELLED=3 vs backend's cancelled=2/completed=3. This needs fixing in future!

---

## Tags

`mobile-testing`, `ios-simulator`, `playwright`, `maestro`, `react-native`, `anti-pattern`, `tektip`, `endpoint-mapping`, `api-audit`, `booking-status`, `no-show`, `validation-error`
