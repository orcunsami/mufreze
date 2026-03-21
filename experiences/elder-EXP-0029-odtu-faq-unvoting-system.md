# Experience 0029: FAQ Unvoting System Implementation with Department Integration

**Date**: July 22, 2025  
**Project**: ODTÜ Connect (formerly HocamKariyer)  
**Category**: Full-Stack Feature  
**Status**: ✅ Resolved  
**Technologies**: FastAPI, React, MongoDB, Dependency Injection, FAQ System, Department Integration  
**Impact**: High - Implemented complete FAQ unvoting functionality with department-specific FAQ sections

## Problem Statement

User reported that clicking the same star rating they already voted for was not working to unvote/remove their rating. The unvoting functionality was not working as expected in the FAQ system, and the user wanted to implement department-specific FAQ sections similar to the existing dormitory FAQ system.

### Specific Issues
1. **Unvoting Not Working**: Clicking the same star that user already rated didn't remove the rating
2. **Missing Department FAQ Integration**: No department-specific FAQ sections on individual department pages
3. **Backend API Error**: 500 Internal Server Error when attempting to unvote

### Error Details
```
TypeError: object AsyncDatabase can't be used in 'await' expression
```

## Investigation Process

### 1. Frontend Analysis
Checked the frontend unvoting logic in `/frontend/src/app/[locale]/faq/visit/[id]/page.tsx`:
- Logic was correct: detecting when `userCurrentRating === stars`
- API call to `faqApi.unstarFAQ(faqId)` was properly implemented
- UI visual indicators showing user's current rating worked correctly

### 2. Backend API Analysis
Examined the unstar endpoint `/backend/app/pages/faq/faq_star_delete.py`:
- Found critical **dependency injection error**
- Line 21: `db = await get_database()` was incorrect
- Other FAQ endpoints used `db=Depends(get_database)` pattern correctly

### 3. Department Integration Analysis
- Existing dormitory FAQ system worked well
- Needed similar functionality for departments using `faq_departments_want` field
- Required translation support and URL parameter handling

## Root Cause Analysis

### Primary Issue: Backend Dependency Injection Error
The unstar FAQ endpoint had incorrect database dependency injection:

**Incorrect Code:**
```python
@router.delete("/items/{faq_id}/star")
async def unstar_faq(
    faq_id: str,
    current_user = Depends(get_current_user)
):
    db = await get_database()  # ❌ WRONG - get_database() is not async
```

**Problem**: 
- `get_database()` is a FastAPI dependency injection function, not an async function
- Trying to `await` it caused TypeError
- All other FAQ endpoints used correct dependency injection pattern

### Secondary Issue: Missing Department FAQ System
- No component for displaying department-specific FAQs
- No URL parameter handling for department pre-selection in FAQ creation
- Missing translation keys for department FAQ functionality

## Solution Implementation

### 1. Fixed Backend Dependency Injection Error

**File**: `/backend/app/pages/faq/faq_star_delete.py`

**Before:**
```python
@router.delete("/items/{faq_id}/star")
async def unstar_faq(
    faq_id: str,
    current_user = Depends(get_current_user)
):
    db = await get_database()  # ❌ Incorrect
```

**After:**
```python
@router.delete("/items/{faq_id}/star")
async def unstar_faq(
    faq_id: str,
    db=Depends(get_database),  # ✅ Correct dependency injection
    current_user = Depends(get_current_user)
):
```

### 2. Created Department FAQ Component

**File**: `/frontend/src/shared/components/department/DepartmentFAQSection.tsx`

Key features:
- Filters FAQs using `faq_departments_want` field (more specific than dormitory tags)
- Red-based color scheme matching department branding
- Internationalization support with `departments.faq` translations
- Smart loading states and empty state handling
- Links to create new questions with department pre-selection

**Core Filtering Logic:**
```typescript
const departmentFAQs = response.items.filter(faq => 
  faq.faq_departments_want?.includes(departmentCode.toLowerCase()) || 
  faq.faq_departments_want?.includes(departmentCode.toUpperCase()) ||
  faq.faq_departments_want?.includes(departmentCode)
)
```

### 3. Added Translation Support

**Files**: `/frontend/src/messages/en.json`, `/frontend/src/messages/tr.json`

Added complete `departments.faq` section:
```json
"departments": {
  "faq": {
    "title": "Department FAQ",
    "askQuestion": "Ask Question",
    "viewAll": "View All",
    "noQuestionsTitle": "No questions yet",
    "noQuestionsDescription": "Be the first to ask a question about {departmentName}!",
    // ... time formatting and other keys
  }
}
```

### 4. Integrated Department FAQ into Pages

**File**: `/frontend/src/app/[locale]/departments/[code]/page.tsx`

Added FAQ section after main content:
```tsx
{/* Department FAQ Section */}
<div className="mt-8">
  <DepartmentFAQSection 
    departmentCode={departmentCode} 
    departmentName={department.department_name}
  />
</div>
```

### 5. Enhanced FAQ Creation with Department Pre-selection

**File**: `/frontend/src/app/[locale]/faq/create/page.tsx`

Added URL parameter handling:
```typescript
// Check if department parameter is provided
const departmentParam = searchParams.get('department')
if (departmentParam) {
  const department = DEPARTMENTS.find(dept => 
    dept.department_code.toLowerCase() === departmentParam.toLowerCase()
  )
  if (department) {
    setDepartmentsWant([departmentParam.toUpperCase()])
    setShowWantDepartments(true)
  }
}
```

### 6. Added Frontend Debug Logging

Enhanced the `handleStar` function with comprehensive debugging:
```typescript
console.log('Unvoting Debug:', {
  userCurrentRating,
  clickedStars: stars,
  isUnvoting: userCurrentRating === stars,
  threadStarSummary: currentThread.star_summary
})
```

## Verification

### 1. Backend Unvoting Test
- ✅ DELETE endpoint now works without TypeError
- ✅ User ratings properly removed from all star arrays
- ✅ Updated statistics returned correctly
- ✅ Toast notifications show success message

### 2. Frontend Unvoting Test
- ✅ Clicking same star removes rating
- ✅ UI immediately updates to reflect removed rating
- ✅ Visual indicators (ring around current star) work correctly
- ✅ Tooltips show "Click to remove your rating" for user's current star

### 3. Department FAQ Integration Test
- ✅ Department pages show relevant FAQs
- ✅ URL parameters work: `/faq/create?department=CRP`
- ✅ Category auto-selection works for departments
- ✅ Translation keys render correctly in both languages
- ✅ Empty states show appropriate messages

## Lessons Learned

### 1. FastAPI Dependency Injection Patterns
**Key Learning**: Always use `Depends()` for dependency injection, never `await` dependency functions directly.

**Pattern to Follow**:
```python
# ✅ Correct
async def endpoint(db=Depends(get_database)):
    # Use db directly

# ❌ Wrong  
async def endpoint():
    db = await get_database()  # This fails
```

### 2. Component Reusability with Slight Variations
Successfully adapted the dormitory FAQ pattern for departments by:
- Using different filtering field (`faq_departments_want` vs `faq_tags`)
- Applying different color scheme (red vs blue)
- Creating separate translation namespace

### 3. URL Parameter Workflow Design
Implemented smooth user workflow:
1. User visits department page
2. Clicks "Ask Question" → redirects to `/faq/create?department=CRP`
3. Form automatically pre-populates department selection
4. Question gets properly categorized for that department

### 4. Debugging Strategy for Full-Stack Issues
**Effective approach**:
1. Add frontend console logging first
2. Check network tab for API calls
3. Examine backend logs for errors
4. Fix backend issue
5. Verify end-to-end functionality

### 5. TypeScript Error Messages Can Be Misleading
The "object AsyncDatabase can't be used in 'await' expression" error was confusing because:
- It seemed like a TypeScript type issue
- Actually was a FastAPI dependency injection pattern error
- Backend runtime error, not frontend type error

## Related Code

### Backend Files
- `/backend/app/pages/faq/faq_star_delete.py` - Fixed unstar endpoint
- `/backend/app/pages/faq/faq_router.py` - Router registration
- `/backend/app/core/database.py` - Database dependency function

### Frontend Files
- `/frontend/src/app/[locale]/faq/visit/[id]/page.tsx` - Unvoting logic and debug logging
- `/frontend/src/shared/components/department/DepartmentFAQSection.tsx` - New department FAQ component
- `/frontend/src/app/[locale]/departments/[code]/page.tsx` - Integration point
- `/frontend/src/app/[locale]/faq/create/page.tsx` - Department pre-selection
- `/frontend/src/features/faq/faqApi.ts` - Unstar API method

### Translation Files
- `/frontend/src/messages/en.json` - English translations
- `/frontend/src/messages/tr.json` - Turkish translations

## Follow-up Actions

1. **Remove Debug Logging**: Clean up console.log statements from production code
2. **Performance Monitoring**: Monitor department FAQ loading performance
3. **User Testing**: Gather feedback on department FAQ discoverability
4. **Documentation**: Update API documentation to include unstar endpoint

## Architecture Impact

### Positive Impacts
- ✅ Consistent FAQ pattern across dormitories and departments
- ✅ Proper dependency injection pattern reinforced
- ✅ Scalable translation structure for future entities
- ✅ Clean URL parameter handling for cross-page workflows

### Considerations
- 🔍 Client-side filtering may need server-side optimization for large FAQ lists
- 🔍 Consider caching department FAQ data for better performance
- 🔍 Monitor for similar dependency injection errors in other endpoints

---

**Resolution Confidence**: High ✅  
**User Satisfaction**: Confirmed working ✅  
**Code Quality**: Improved with proper patterns ✅  
**Documentation**: Complete ✅