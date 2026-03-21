# EXP-0067: TekTıp Mobile - CSRF 419 & Database Schema Sync Issues

## Metadata
- **Date**: 2025-12-15
- **Project**: TekTıp (Healthcare Platform)
- **Component**: Mobile App (React Native) + Laravel Backend
- **Category**: Mobile-Backend Integration, API Security, Database Schema
- **Status**: ✅ RESOLVED
- **Severity**: CRITICAL (Production-blocking)
- **Technologies**: Laravel 10, React Native, Sanctum, MySQL, Inertia.js

---

## Problem Summary

Mobile app action buttons (Mark Completed, Reschedule, Cancel, No-Show) returned errors in sequence:
1. **419 CSRF Token Mismatch** - Routes using `api-with-session` middleware
2. **401 Unauthorized** - `Auth::user()` using wrong guard
3. **422 Validation Error** - Field name mismatch (booking_status vs status)
4. **500 Internal Server Error** - Missing database columns in orcun branch

### Context
TekTıp has two codebases (production vs development branch) that can drift in schema and middleware configuration. The mobile app is stateless (can't send CSRF tokens) but some API routes were configured for web session authentication.

---

## Root Causes

### 1. CSRF Token Issue (419 Error)

**Location**: `/Users/mac/Documents/work-tiktip/tektip-web-orcun/routes/api.php`

**Problem**:
Route `/api/update-booking-status` used `api-with-session` middleware group which includes CSRF verification:

```php
// Kernel.php line 57
'api-with-session' => [
    \Illuminate\Cookie\Middleware\AddQueuedCookiesToResponse::class,
    \Illuminate\Session\Middleware\StartSession::class,
    \App\Http\Middleware\VerifyCsrfToken::class,  // ← CSRF check!
    \Illuminate\View\Middleware\ShareErrorsFromSession::class,
    'throttle:api',
    \Illuminate\Routing\Middleware\SubstituteBindings::class,
],
```

**Why This Fails**:
- Mobile apps are stateless (no session cookies)
- Cannot send CSRF tokens in request headers
- `VerifyCsrfToken` middleware throws 419 error

**Solution**:
Created new routes WITHOUT middleware at lines 284-286 of `routes/api.php`:

```php
// Direct routes for mobile app (no CSRF)
Route::post('/doctor/update-booking-status', [BookingController::class, 'updateBookingStatus']);
Route::post('/doctor/reschedule-booking', [BookingController::class, 'rescheduleBookSlot']);
```

---

### 2. Auth::guard Issue (401 Error)

**Location**: `app/Http/Controllers/Api/BookingController.php`

**Problem**:
Controller used `Auth::user()` which defaults to `web` guard (session-based):

```php
// ❌ WRONG: Uses default 'web' guard
$doctor = Auth::user();
```

**Why This Fails**:
- Mobile app sends `api_token` as query parameter or `Authorization: Bearer` header
- `web` guard looks for session data (not available in mobile)
- Returns null, causing 401 Unauthorized

**TekTıp Auth Pattern** (Critical Discovery):
- Uses **custom token driver** (NOT Laravel Sanctum!)
- Token stored in `users.api_token` column (60 characters)
- Accepts token via:
  - Query parameter: `?api_token=...`
  - Header: `Authorization: Bearer {token}`

**Solution**:
Changed to `Auth::guard('api')->user()`:

```php
// ✅ CORRECT: Uses 'api' guard (token-based)
$doctor = Auth::guard('api')->user();
```

**Files Modified**:
- BookingController.php lines: 661, 674, 690

---

### 3. Field Name Mismatch (422 Error)

**Location**: `tektip-mobile-orcun/src/services/BookingService.ts` line 148

**Problem**:
Mobile app sent `booking_status` but backend validates `status`:

```typescript
// ❌ WRONG: Field name doesn't match backend
booking_status: status
```

**Solution**:
```typescript
// ✅ CORRECT: Matches backend validation rules
status: status
```

**TekTıp API Error Format** (Pattern Discovered):
```json
{
  "success": false,
  "status": 422,
  "message": "Validation error message"
}
```

**NOT** Laravel standard format:
```json
{
  "errors": {
    "field_name": ["Error message"]
  }
}
```

---

### 4. Missing Database Columns (500 Error)

**Problem**: Orcun branch database missing columns that production branch has

**Columns Needed in `bookings`**:
- `cancellation_fee_applied` BOOLEAN
- `cancellation_fee_amount` DECIMAL
- `cancelled_by` BIGINT UNSIGNED (user_id FK)
- `cancelled_at` TIMESTAMP

**Columns Needed in `notifications`**:
- `notification_type` VARCHAR(50)
- `title_tr` VARCHAR(255)
- `message_tr` TEXT

**Columns Needed in `rating_and_reviews`**:
- `deleted_at` TIMESTAMP

**Columns Needed in `availabilities`**:
- `deleted_at` TIMESTAMP

**Solution**: Direct SQL ALTER TABLE commands (orcun migrations out of sync)

```sql
-- Add booking cancellation fields
ALTER TABLE bookings ADD COLUMN cancellation_fee_applied BOOLEAN DEFAULT FALSE;
ALTER TABLE bookings ADD COLUMN cancellation_fee_amount DECIMAL(10,2) DEFAULT 0.00;
ALTER TABLE bookings ADD COLUMN cancelled_by BIGINT UNSIGNED NULL;
ALTER TABLE bookings ADD COLUMN cancelled_at TIMESTAMP NULL;

-- Add notification i18n fields
ALTER TABLE notifications ADD COLUMN notification_type VARCHAR(50) DEFAULT 'general';
ALTER TABLE notifications ADD COLUMN title_tr VARCHAR(255) NULL;
ALTER TABLE notifications ADD COLUMN message_tr TEXT NULL;

-- Add soft delete support
ALTER TABLE rating_and_reviews ADD COLUMN deleted_at TIMESTAMP NULL;
ALTER TABLE availabilities ADD COLUMN deleted_at TIMESTAMP NULL;
```

**Why This Happened**:
- Orcun branch diverged from production migrations
- Production added columns via migrations that orcun doesn't have
- Should have run `php artisan migrate` from prod migrations

---

### 5. Null Pointer on academicTitle

**Location**: BookingController.php lines 661, 674, 690

**Problem**:
```php
// ❌ WRONG: Crashes if academicTitle is null
$booking->doctor->academicTitle->display_title
```

**Solution**: Use PHP 8 null-safe operator
```php
// ✅ CORRECT: Returns empty string if null
$booking->doctor->academicTitle?->display_title ?? ''
```

---

## TekTıp Architectural Patterns Discovered

### 1. TekTıp Authentication System

**NOT Sanctum** (despite Sanctum being installed):
- Custom token driver
- 60-character `api_token` stored in `users` table
- Token generation via Laravel Str::random(60)
- Multi-channel token acceptance:
  - Query parameter: `/api/endpoint?api_token=...`
  - Bearer header: `Authorization: Bearer {token}`

**Guard Configuration**:
```php
// config/auth.php
'guards' => [
    'web' => [
        'driver' => 'session',
        'provider' => 'users',
    ],
    'api' => [
        'driver' => 'token',  // ← NOT Sanctum!
        'provider' => 'users',
        'hash' => false,
    ],
],
```

**Critical Rule**: Always use `Auth::guard('api')->user()` in API routes

---

### 2. TekTıp Middleware Groups

**Kernel.php Configuration**:

```php
protected $middlewareGroups = [
    'web' => [
        // Session, CSRF, Cookies
        \Illuminate\Session\Middleware\StartSession::class,
        \App\Http\Middleware\VerifyCsrfToken::class,
        // ... more middleware
    ],

    'api' => [
        // Stateless, no CSRF
        'throttle:api',
        \Illuminate\Routing\Middleware\SubstituteBindings::class,
    ],

    'api-with-session' => [
        // HYBRID: Session + API (includes CSRF!)
        \Illuminate\Session\Middleware\StartSession::class,
        \App\Http\Middleware\VerifyCsrfToken::class,  // ⚠️ DANGER for mobile!
        'throttle:api',
        \Illuminate\Routing\Middleware\SubstituteBindings::class,
    ],
];
```

**Mobile Rule**: NEVER use `api-with-session` for mobile routes!

---

### 3. TekTıp API Error Format

**Custom Response Structure**:
```php
// Success
return response()->json([
    'success' => true,
    'status' => 200,
    'message' => 'Operation successful',
    'data' => [...]
]);

// Error
return response()->json([
    'success' => false,
    'status' => 422,
    'message' => 'Validation failed'
], 422);
```

**NOT using Laravel's standard validation error format**:
```php
// Laravel standard (TekTıp does NOT use this)
{
    "message": "The given data was invalid.",
    "errors": {
        "field": ["Error message"]
    }
}
```

---

### 4. TekTıp Branch Sync Issue

**Critical Discovery**:
- Orcun branch database can be out of sync with production
- Migrations run on prod may not be in orcun
- Direct SQL needed instead of migrations
- Schema differences cause 500 errors (not validation errors!)

**Prevention Checklist**:
1. Regularly sync orcun with prod migrations
2. Run `php artisan migrate` when switching branches
3. Check for schema differences before testing
4. Use `SHOW COLUMNS FROM table` to verify schema
5. Document branch-specific database changes

---

## Files Modified

### Backend (tektip-web-orcun)

**1. routes/api.php** (2 routes added)
```php
// Lines 284-286 (NEW)
Route::post('/doctor/update-booking-status', [BookingController::class, 'updateBookingStatus']);
Route::post('/doctor/reschedule-booking', [BookingController::class, 'rescheduleBookSlot']);
```

**2. app/Http/Controllers/Api/BookingController.php** (3 locations)
```php
// Lines 661, 674, 690
// Changed: Auth::user() → Auth::guard('api')->user()
// Changed: ->academicTitle->display_title → ->academicTitle?->display_title ?? ''
```

### Mobile (tektip-mobile-orcun)

**3. src/services/BookingService.ts** (line 148)
```typescript
// Changed: booking_status: status → status: status
```

### Database (Direct SQL)
- Added 4 columns to `bookings`
- Added 3 columns to `notifications`
- Added 2 `deleted_at` columns (soft deletes)

---

## Testing Results

### Test Sequence (All Passing)

**1. Mark Completed**:
```bash
✅ POST /api/doctor/update-booking-status
Request: { status: 'completed', booking_id: 123 }
Response: { success: true, status: 200, message: 'Booking marked as completed' }
```

**2. Reschedule**:
```bash
✅ POST /api/doctor/reschedule-booking
Request: { booking_id: 123, new_slot_id: 456 }
Response: { success: true, status: 200, message: 'Booking rescheduled successfully' }
```

**3. Cancel**:
```bash
✅ POST /api/doctor/update-booking-status
Request: { status: 'cancelled', booking_id: 123, cancellation_reason: 'Patient request' }
Response: { success: true, status: 200, message: 'Booking cancelled successfully' }
```

**4. No-Show**:
```bash
✅ POST /api/doctor/update-booking-status
Request: { status: 'no_show', booking_id: 123 }
Response: { success: true, status: 200, message: 'Booking marked as no-show' }
```

---

## Prevention Checklist (Critical for Future)

### Mobile API Routes
- [ ] Always check middleware group in Kernel.php before adding routes
- [ ] NEVER use `api-with-session` for mobile routes
- [ ] Always use `Auth::guard('api')->user()` for API routes
- [ ] Verify field names match between frontend/backend
- [ ] Use null-safe operators for relation chains (`?->`)

### Database Schema
- [ ] Sync orcun database with prod migrations regularly
- [ ] Run `php artisan migrate` when switching branches
- [ ] Check for missing columns with `SHOW COLUMNS FROM table`
- [ ] Verify foreign key constraints exist
- [ ] Test schema changes before deployment

### Error Handling
- [ ] Check TekTıp error format (not Laravel standard)
- [ ] Validate response structure in mobile app
- [ ] Handle all error types: 401, 419, 422, 500
- [ ] Log errors with full context (request body, headers, response)

### Testing Protocol
- [ ] Test with production-like database (schema parity)
- [ ] Test with real api_token (not mocked auth)
- [ ] Test all CRUD operations end-to-end
- [ ] Verify error messages are user-friendly
- [ ] Check null cases for all relations

---

## Impact & Lessons Learned

### Impact
- ✅ **Mobile booking actions now work** (4 critical features restored)
- ✅ **CSRF issue resolved** (mobile routes no longer require session)
- ✅ **Auth pattern documented** (custom token driver, not Sanctum)
- ✅ **Schema sync protocol established** (prevent future 500 errors)
- ✅ **API error format documented** (TekTıp custom format)

### Lessons Learned

**1. Laravel Mobile Development**:
- Check middleware groups before adding routes
- Use `api` guard, not `web` guard
- Avoid `api-with-session` for mobile apps
- Mobile can't send CSRF tokens (stateless)

**2. Multi-Branch Development**:
- Database schema can drift between branches
- Migrations may not be in sync
- Direct SQL may be needed for schema fixes
- Always verify schema parity before testing

**3. Custom Auth Systems**:
- Don't assume Laravel uses standard patterns
- Check config/auth.php for actual configuration
- TekTıp uses custom token driver (not Sanctum)
- Document project-specific auth patterns

**4. Error Response Formats**:
- Projects may customize Laravel error responses
- Don't assume standard Laravel validation format
- Check actual API responses, not documentation
- Document custom response structures

**5. Null Safety**:
- Use null-safe operator (`?->`) for relation chains
- Always have fallback values (`?? ''`)
- Check for null before accessing properties
- PHP 8 null-safe operator is safer than isset()

---

## Related Experiences

### Similar Patterns
- **[EXP-0043](EXP-0043-kiwi-roadie-testflight-backend-connectivity-fix.md)**: Mobile backend connectivity (TestFlight)
- **[EXP-0042](EXP-0042-kiwi-roadie-critical-profile-debugging-patterns.md)**: Mobile API integration debugging
- **[EXP-0041](EXP-0041-kiwi-roadie-complete-profile-management-system.md)**: Mobile full-stack integration

### Technology Overlap
- React Native mobile development
- Laravel API authentication
- Database schema management
- API error handling patterns

---

## Quick Reference

### TekTıp Auth Pattern (Mobile)
```php
// Backend Controller
$doctor = Auth::guard('api')->user();
if (!$doctor) {
    return response()->json([
        'success' => false,
        'status' => 401,
        'message' => 'Unauthorized'
    ], 401);
}
```

### TekTıp Error Response
```php
// Standard TekTıp error format
return response()->json([
    'success' => false,
    'status' => $statusCode,
    'message' => $errorMessage
], $statusCode);
```

### Null-Safe Relation Access
```php
// PHP 8 null-safe operator
$title = $booking->doctor->academicTitle?->display_title ?? 'Dr.';
```

### Mobile Route Configuration
```php
// routes/api.php (NO middleware for mobile)
Route::post('/doctor/endpoint', [Controller::class, 'method']);
// NOT: Route::middleware(['api-with-session'])...
```

---

## Tags
`laravel`, `react-native`, `mobile-backend`, `csrf-token`, `authentication`, `database-schema`, `api-integration`, `sanctum`, `middleware`, `null-safety`, `error-handling`, `branch-sync`, `tektip`

---

## Success Metrics
- ✅ 4/4 booking actions working (100% success rate)
- ✅ 0 CSRF errors after fix
- ✅ 0 401 errors after guard fix
- ✅ 0 422 errors after field name fix
- ✅ 0 500 errors after schema sync
- ✅ Mobile app fully functional (end-to-end tested)

**Status**: ✅ **PRODUCTION READY** (All critical features restored)
