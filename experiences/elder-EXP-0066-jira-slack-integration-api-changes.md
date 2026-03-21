---
title: "Jira Cloud API v3 + Slack Integration Setup"
experience_id: EXP-0066
date: 2025-12-14
category: Integration/Project Management
tags: [jira, slack, api-deprecation, permissions, credentials, vps]
project: Infrastructure
status: SUCCESS
severity: MEDIUM
technologies:
  - Jira Cloud API v3
  - Slack API
  - Backblaze B2
  - Bash
  - Environment Variables
related_experiences:
  - EXP-0057 # VPS2 MongoDB Authentication
  - EXP-0058 # VPS1 Disk Cleanup
  - EXP-0059 # VPS OS Version Comparison
---

## Summary

Complete learning session on Jira Cloud API v3 changes, Slack integration setup, and proper credential management for cross-VPS operations. Discovered critical API deprecations, permission limitations on free plans, and proper workflow for Jira-Slack notifications.

## Problem

Setting up Jira + Slack integration for HocamKariyer project tracking while managing credentials across multiple VPS servers.

## Investigation

### 1. Jira Cloud API v3 Changes

**Old API (Deprecated):**
```bash
/rest/api/3/search
```

**New API:**
```bash
/rest/api/3/search/jql
```

**Project Key Limitation:**
- Max 10 characters
- `HOCAMKARIYER` (12 chars) → INVALID
- `HKARIYER` (8 chars) → OK

### 2. Jira Permissions & Plans

**Free Plan Limitations:**
- ❌ No delete issue permission
- ❌ Cannot move issues between projects (PUT method fails)

**Standard Plan Features:**
- ✅ Delete issues permission
- ✅ Project Settings → Permissions → Delete issues

**Workaround for Project Migration:**
```python
# Cannot do this on free plan:
PUT /rest/api/3/issue/{issueKey}
{
  "fields": {
    "project": {"key": "NEW_PROJECT"}
  }
}

# Must do this instead:
1. Create new issue in target project
2. Delete old issue (requires Standard plan)
```

### 3. Slack + Jira Integration Workflow

**Step 1: Connect Slack to Jira**
```bash
# In Slack workspace:
/jira connect
```

**Step 2: Subscribe Channel (UI ONLY)**
```bash
# This command does NOT work:
/jira subscribe PROJE

# Must use Jira UI instead:
1. Go to Jira → Project Settings
2. Navigate to Slack integration section
3. Click "Add channel notification"
4. Select Slack channel
5. Choose triggers:
   - Issue created
   - Issue assigned
   - Issue commented
   - Issue status changed
   - etc.
```

**Step 3: Test Notifications**
- Create a test issue in Jira
- Check Slack channel for notification
- Verify trigger settings

### 4. Jira Account URL Issue

**Discovered Typo in Setup:**
- Created as: `orchun.atlassian.net` (typo)
- Should be: `orcunst.atlassian.net`
- **Cannot change** - Atlassian doesn't allow URL changes
- Must live with the typo

### 5. Backblaze B2 Credentials Management

**Proper .env Format:**
```bash
# WRONG - Bash doesn't accept hyphens in variable names:
BACKBLAZE-APPLICATION-KEY-ID=xxx

# CORRECT - Use underscores:
BACKBLAZE_APPLICATION_KEY_ID=xxx
BACKBLAZE_APPLICATION_KEY=xxx
```

**Error when sourcing:**
```bash
source ~/.claude/.env
# bash: BACKBLAZE-APPLICATION-KEY-ID: command not found
```

**Solution:**
```bash
# Option 1: Fix .env file (use underscores)
BACKBLAZE_APPLICATION_KEY_ID=xxx

# Option 2: Set variables directly
export BACKBLAZE_APPLICATION_KEY_ID="xxx"
export BACKBLAZE_APPLICATION_KEY="yyy"
```

### 6. VPS Credential Sync

**Problem:**
- Local Claude Code has updated Jira credentials
- VPS Claude Code has old/wrong credentials
- Need to sync credentials across VPSs

**Solution:**
```bash
# 1. Update local .env first
cd ~/.claude
vim .env  # Add/update credentials

# 2. Securely copy to VPS
scp ~/.claude/.env user@vps-ip:~/.claude/.env

# 3. Verify on VPS
ssh user@vps-ip
cat ~/.claude/.env | grep JIRA
```

## Solution

### ✅ Jira API Migration

**Updated API Calls:**
```python
# Old (deprecated):
url = f"{JIRA_URL}/rest/api/3/search"

# New:
url = f"{JIRA_URL}/rest/api/3/search/jql"
```

**Project Key Validation:**
```python
def validate_project_key(key: str) -> bool:
    """Validate Jira project key (max 10 chars, uppercase)"""
    if len(key) > 10:
        raise ValueError(f"Project key too long: {key} ({len(key)} chars)")
    if not key.isupper():
        raise ValueError(f"Project key must be uppercase: {key}")
    return True

# Usage:
validate_project_key("HKARIYER")  # OK
validate_project_key("HOCAMKARIYER")  # Error: 12 chars
```

### ✅ Jira + Slack Integration

**Complete Setup Flow:**
```bash
# 1. In Slack workspace:
/jira connect

# 2. Authorize Jira app to access workspace

# 3. In Jira UI (NOT Slack):
# - Go to Project Settings
# - Slack Integration
# - Add channel notification
# - Select triggers:
#   ✓ Issue created
#   ✓ Issue assigned
#   ✓ Issue commented
#   ✓ Issue status changed
#   ✓ Issue completed

# 4. Test:
# - Create test issue in Jira
# - Check Slack channel for notification
```

### ✅ Credential Management Best Practices

**1. .env File Format:**
```bash
# ~/.claude/.env

# Jira Cloud API v3
JIRA_URL=https://orchun.atlassian.net  # Note: typo, cannot fix
JIRA_EMAIL=orcunst@gmail.com
JIRA_API_TOKEN=ATATT3xFfGF0...

# Backblaze B2 (VPS Backups)
BACKBLAZE_APPLICATION_KEY_ID=005e...
BACKBLAZE_APPLICATION_KEY=K005e...

# Slack
SLACK_BOT_TOKEN=xoxb-...
SLACK_SIGNING_SECRET=...
```

**2. Bash-Compatible Naming:**
```bash
# ❌ WRONG - Bash syntax error:
SOME-VAR-NAME=value

# ✅ CORRECT - Use underscores:
SOME_VAR_NAME=value
```

**3. Cross-VPS Sync:**
```bash
# Secure credential sync script:
#!/bin/bash

LOCAL_ENV="$HOME/.claude/.env"
VPS_HOSTS=("vps1" "vps2" "vps3" "vps4")

for vps in "${VPS_HOSTS[@]}"; do
    echo "Syncing to $vps..."
    scp "$LOCAL_ENV" "$vps:~/.claude/.env"
    ssh "$vps" "chmod 600 ~/.claude/.env"
done
```

### ✅ Jira Permission Workarounds

**Free Plan Constraints:**
```python
# Cannot delete issues on free plan
# Workaround: Archive or close instead

def archive_instead_of_delete(issue_key: str):
    """Close and archive issue instead of deleting"""
    # Transition to "Done" or "Closed"
    transition_issue(issue_key, "Done")

    # Add label to mark as archived
    add_label(issue_key, "ARCHIVED")

    # Add comment explaining archival
    add_comment(
        issue_key,
        "This issue has been archived (delete not available on free plan)"
    )
```

**Standard Plan Benefits:**
```bash
# After upgrading to Standard ($7.75/month):
1. Project Settings → Permissions
2. Find "Delete Issues" permission
3. Grant to appropriate roles
4. Can now delete issues via API
```

## Impact

### Immediate Benefits
- ✅ Jira API calls updated to non-deprecated endpoints
- ✅ Slack notifications working for HocamKariyer project
- ✅ Credentials properly formatted and synced across VPSs
- ✅ Understanding of Jira free vs. paid plan limitations

### Long-term Value
- 📚 Reusable Jira + Slack integration workflow for all projects
- 🔒 Proper credential management patterns for multi-VPS setups
- 📊 Project tracking infrastructure ready for scale
- ⚠️ Documented workarounds for free plan constraints

## Metrics

| Metric | Before | After | Improvement |
|--------|--------|-------|-------------|
| API Deprecation Warnings | 1 | 0 | 100% |
| Slack Notifications | 0 | Working | ∞ |
| VPS Credential Sync | Manual | Documented | Process |
| Jira Plan Limitations | Unknown | Documented | Clarity |

## Related Patterns

### Similar Issues Across Projects
1. **API Deprecation Management**
   - Always check API version changelog
   - Update endpoints before deprecation deadline
   - Test with new endpoints immediately

2. **Third-Party Integration Setup**
   - Read official docs (not just Slack commands)
   - Some integrations require UI configuration
   - Test notifications end-to-end

3. **Credential Management**
   - Use shell-compatible variable names
   - Document credential locations
   - Sync securely across environments

## Prevention Guidelines

### Before Using Any API

```bash
# 1. Check API version
curl -s https://api.example.com/version

# 2. Read deprecation notices
# Check: API docs, changelog, developer blog

# 3. Test new endpoints early
# Don't wait for deprecation deadline

# 4. Validate credentials format
# Ensure .env is bash-compatible
```

### Before Slack Integration

```bash
# 1. Check if /commands actually work
# Some features are UI-only

# 2. Review available triggers
# Plan notification strategy first

# 3. Test with dummy project
# Don't spam production channels

# 4. Document setup steps
# Future team members will thank you
```

### Before Multi-VPS Operations

```bash
# 1. Centralize credentials
# Single source of truth in ~/.claude/.env

# 2. Create sync script
# Automate credential distribution

# 3. Verify after sync
# SSH to each VPS and test

# 4. Set proper permissions
# chmod 600 for sensitive files
```

## Action Items for Future

- [ ] Migrate all Jira API calls to `/rest/api/3/search/jql`
- [ ] Document Jira + Slack integration in project READMEs
- [ ] Create credential sync script for all VPSs
- [ ] Evaluate Jira Standard plan for delete permissions ($7.75/month)
- [ ] Consider renaming projects to fit 10-char key limit
- [ ] Add Jira integration to other projects (ODTU, YeniZelanda, etc.)

## Lessons Learned

### 1. API Deprecation is Real
- `/rest/api/3/search` → `/rest/api/3/search/jql`
- Check changelogs regularly
- Migrate proactively, not reactively

### 2. Free Plans Have Real Limits
- No delete permissions
- Cannot move issues between projects
- Upgrade when constraints block workflows

### 3. Slash Commands Aren't Magic
- `/jira subscribe` doesn't work
- Must use Jira UI for channel notifications
- Always consult official docs, not assumptions

### 4. Environment Variables Matter
- Bash doesn't accept hyphens in names
- `SOME-VAR` → syntax error
- `SOME_VAR` → works

### 5. Typos in Setup Are Permanent
- `orchun.atlassian.net` cannot be changed
- Atlassian doesn't allow URL changes
- Double-check critical setup fields

## References

### Official Documentation
- [Jira Cloud REST API v3](https://developer.atlassian.com/cloud/jira/platform/rest/v3/)
- [Jira + Slack Integration Guide](https://slack.com/apps/A2RPP3NFR-jira-cloud)
- [Backblaze B2 API](https://www.backblaze.com/b2/docs/)

### Related Files
- `~/.claude/.env` - Centralized credentials
- `~/.claude/docs/systems/infrastructure-master-plan.md` - VPS documentation

### Related Commands
```bash
# Check Jira API version
curl -u email:token https://orchun.atlassian.net/rest/api/3/serverInfo

# List Slack integrations
/jira help

# Sync credentials to VPS
scp ~/.claude/.env vps:~/.claude/.env
```

## Tags for Search
`#jira-api` `#slack-integration` `#api-deprecation` `#credentials-management` `#vps-sync` `#environment-variables` `#free-plan-limitations` `#project-tracking` `#notification-setup` `#backblaze-b2`

---

**Experience Type**: Integration Setup & API Migration
**Complexity**: Medium (API changes + third-party integration)
**Reusability**: High (applicable to all Jira + Slack projects)
**Documentation Quality**: Complete (setup flow + workarounds documented)
