# EXP-0075: Azure Sentinel Logic App - Label labelType Required

## Metadata
- **ID**: EXP-0075
- **Date**: 2026-01-31
- **Project**: Azure Sentinel Integration
- **Category**: API Integration / Azure Logic Apps
- **Status**: SUCCESS
- **Technologies**: Azure Sentinel, Azure Logic Apps, REST API, ARM Templates

---

## Problem Description

When using Azure Logic Apps to add labels (tags) to Sentinel incidents via the PATCH API, the action fails with a **502 BadGateway** error.

### Error Details
- **Action**: Add_Synced_Tag (or similar label-adding action)
- **HTTP Status**: 502 BadGateway
- **Symptom**: Label addition silently fails or returns gateway error

---

## Root Cause

When adding a label to a Sentinel incident via the PATCH API, the **`labelType` field is REQUIRED**.

The API expects label objects with both `labelName` AND `labelType` fields. Sending only `labelName` causes the Azure Resource Manager (ARM) to reject the request with a 502 error.

### What Was Sent (WRONG)
```json
{
  "properties": {
    "labels": [
      {"labelName": "Synced"}
    ]
  }
}
```

### What Was Required (CORRECT)
```json
{
  "properties": {
    "labels": [
      {"labelName": "Synced", "labelType": "User"}
    ]
  }
}
```

---

## Solution

### Fix in Logic App JSON Expression

**WRONG:**
```json
"labels": "@union(coalesce(body('Get_Incident')?['properties']?['labels'], json('[]')), json('[{\"labelName\": \"Synced\"}]'))"
```

**CORRECT:**
```json
"labels": "@union(coalesce(body('Get_Incident')?['properties']?['labels'], json('[]')), json('[{\"labelName\": \"Synced\", \"labelType\": \"User\"}]'))"
```

### Valid labelType Values
| Value | Description |
|-------|-------------|
| `User` | Manually assigned by user or automation |
| `AutoAssigned` | Automatically assigned by Sentinel |

---

## Key Lessons

1. **Azure Sentinel Label Structure**: Labels MUST have both `labelName` AND `labelType` fields
2. **union() Function Compatibility**: When using `union()` to merge labels, the new label object must match the structure of existing labels
3. **502 BadGateway in Logic Apps**: Often indicates malformed request body rather than actual gateway issues
4. **ARM Template Validation**: Azure Resource Manager is strict about object schemas - missing fields cause cryptic errors

---

## Prevention Checklist

When working with Azure Sentinel incidents via API:

- [ ] Include `labelType` field when adding/modifying labels
- [ ] Use `"labelType": "User"` for automation-added labels
- [ ] Test label operations with complete object structures
- [ ] Check ARM template documentation for required fields

---

## Related Resources

- [Azure Sentinel Incident REST API](https://learn.microsoft.com/en-us/rest/api/securityinsights/incidents)
- [Logic Apps union() function](https://learn.microsoft.com/en-us/azure/logic-apps/workflow-definition-language-functions-reference#union)

---

## Tags
`azure`, `sentinel`, `logic-apps`, `labels`, `api-error`, `502`, `badgateway`, `labeltype`, `arm-templates`, `rest-api`

---

## Cross-References

- Project CLAUDE.md: `/Users/mac/Documents/work2/integrations/azure/CLAUDE.md`
- Related: v2.1 Sync Logic App with SOCRadar-Synced tag system
