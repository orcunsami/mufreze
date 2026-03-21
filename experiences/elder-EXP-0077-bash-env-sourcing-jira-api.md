# EXP-0077: Bash .env Sourcing and Jira API Authentication

## Metadata
| Field | Value |
|-------|-------|
| **Experience ID** | EXP-0077 |
| **Project** | HocamClass |
| **Task ID** | HCLASS-40 |
| **Date** | 2026-02-01 |
| **Category** | DevOps/Shell/API Integration |
| **Technologies** | Bash, .env files, Jira Cloud API |
| **Status** | SUCCESS |
| **Time Spent** | 15 minutes |

---

## Problem Description

When running shell scripts that need to source `.env` files for environment variables (like Jira credentials), the `source .env` command fails with syntax errors because `.env` files often contain values that are not bash-compatible.

### Error Message
```bash
source .env
# Error: bash: MODEL_1_ID=gpt-4-turbo: command not found
# (hyphens in values are interpreted as command options)
```

### Root Cause
`.env` files are designed for application configuration, not shell script sourcing. They often contain:
- Values with hyphens (e.g., `MODEL_1_ID=gpt-4-turbo`)
- Values with special characters
- Unquoted strings that bash interprets incorrectly

---

## Solution

### 1. Suppress Errors While Sourcing
```bash
# Suppress errors but still load valid variables
source .env 2>/dev/null
```

This approach:
- Loads all valid bash-compatible variables
- Suppresses errors for incompatible lines
- Continues script execution

### 2. Jira API Authentication
For Jira API curl commands, use proper variable interpolation:

```bash
# Load credentials
source .env 2>/dev/null

# Create Jira issue
curl -s -X POST \
  -u "${JIRA_EMAIL}:${JIRA_API_TOKEN}" \
  -H "Content-Type: application/json" \
  "https://orchun.atlassian.net/rest/api/3/issue" \
  -d '{
    "fields": {
      "project": {"key": "HCLASS"},
      "summary": "Issue title",
      "issuetype": {"name": "Task"}
    }
  }'
```

Key points:
- Use `${VARIABLE}` syntax for curl authentication
- Double quotes around the `-u` parameter value
- Curly braces ensure proper variable expansion

---

## Patterns Applied
- `bash-env-sourcing`: Error suppression for .env files
- `jira-api-authentication`: Proper credential interpolation

---

## Prevention Checklist
- [ ] When sourcing .env files in bash, always use `2>/dev/null`
- [ ] Use `${VAR}` syntax in curl commands for variable expansion
- [ ] Test scripts with `bash -x script.sh` to debug variable issues

---

## Related Experiences
- [EXP-0066](EXP-0066-jira-slack-integration-api-changes.md): Jira Cloud API v3 + Slack Integration
- [EXP-0055](EXP-0055-urunlu-api-url-prefix-standardization.md): Environment Configuration

---

## Tags
`bash`, `env-sourcing`, `jira-api`, `curl`, `authentication`, `shell-script`, `error-handling`, `variable-expansion`
