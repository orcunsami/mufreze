# Field Naming Reference - HocamKariyer Modules

**Date**: June 25, 2025  
**Project**: ODTÜ Connect (formerly HocamKariyer)  
**Purpose**: Standardize field naming conventions across all modules

## ✅ Fixed Issues

### Projects Module Ownership Field
**Issue**: Frontend was looking for `project_created_by_account_id` but backend uses `project_creator_account_id`
**Status**: ✅ FIXED - Frontend updated to use correct field name

## 📋 Current Field Naming Patterns

### Ownership/Creator Fields by Module

| Module | Field Name | Pattern | Status |
|--------|------------|---------|--------|
| **Projects** | `project_creator_account_id` | `{module}_creator_account_id` | ✅ Consistent |
| **Services** | `service_created_by_account_id` | `{module}_created_by_account_id` | ✅ Consistent |
| **Jobs** | `job_created_by_account_id` | `{module}_created_by_account_id` | ✅ Consistent |
| **Applications** | `application_created_by_account_id` | `{module}_created_by_account_id` | ✅ Consistent |
| **Cover Letters** | `cover_created_by_account_id` | `{module}_created_by_account_id` | ✅ Consistent |

### ID Field Patterns

| Module | Primary ID | Pattern | Example |
|--------|------------|---------|---------|
| **Projects** | `project_id` | `{module}_id` | `project--uuid` |
| **Services** | `service_id` | `{module}_id` | `service--uuid` |
| **Price Tiers** | `price_id` | `{module}_id` | `price--uuid` |
| **Jobs** | `job_id` | `{module}_id` | `job--uuid` |
| **Applications** | `application_id` | `{module}_id` | `application--uuid` |
| **Accounts** | `account_id` | `{module}_id` | `account--uuid` |

## 🎯 Standardization Decision

### Current Approach: **Module-Consistent Patterns**
- Each module maintains internal consistency
- Both `creator_account_id` and `created_by_account_id` patterns are acceptable
- New modules should choose one pattern and stick to it

### Alternative: **Global Standardization** (Future Consideration)
- Could standardize all modules to use `{module}_created_by_account_id`
- Would require migration of existing data and API changes
- **Recommendation**: Not worth the effort for existing modules

## 🚨 Critical Validation Checklist

When creating new modules or updating existing ones:

### Backend/Frontend Alignment
- [ ] Field names match exactly between backend models and frontend interfaces
- [ ] API responses use consistent field names
- [ ] Database queries use correct field names

### Module Consistency  
- [ ] All fields within a module use the same prefix pattern
- [ ] Ownership fields follow the module's established pattern
- [ ] ID fields follow `{module}_id` pattern

### Cross-Module References
- [ ] Foreign key fields clearly indicate the referenced module
- [ ] Array references use `{module}_{reference}_ids` pattern
- [ ] Denormalized fields maintain clear source indication

## 📖 Best Practices

### 1. Field Naming Convention
```python
# ✅ CORRECT - Clear module prefix and purpose
"service_created_by_account_id"
"project_creator_account_id"  
"price_tier"
"price_value"

# ❌ WRONG - Missing or inconsistent prefixes
"created_by"
"creator"
"tier"
"value"
```

### 2. Validation Points
- **Before API deployment**: Verify frontend/backend field alignment
- **During testing**: Check ownership validation logic
- **Code reviews**: Ensure field naming consistency

### 3. Documentation Updates
- Update TypeScript interfaces when backend models change
- Keep CLAUDE.md field examples current
- Document any new patterns in this reference

## 🔄 Migration Guide (If Needed)

If global standardization is ever needed:

1. **Choose Standard Pattern**: `{module}_created_by_account_id`
2. **Update Backend Models**: Pydantic models and database queries
3. **Update Frontend Interfaces**: TypeScript types and API calls
4. **Database Migration**: Field renaming scripts
5. **API Versioning**: Maintain backward compatibility during transition

---

**Last Updated**: June 25, 2025  
**Next Review**: When adding new modules or major refactoring