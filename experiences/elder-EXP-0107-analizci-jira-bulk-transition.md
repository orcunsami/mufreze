# EXP-0097: Jira Bulk Transition API Pattern

**Date**: 2026-02-28
**Project**: Analizci / AVIDO (Video Analysis Platform)
**Severity**: LOW
**Tags**: `jira`, `api`, `automation`, `curl`, `bulk`, `transition`, `avido`

## Problem

Need to programmatically transition many Jira tasks to "Done" without doing it manually in the UI.

## Key Information

### Token Location

```bash
source /root/.claude/.env
# Provides: JIRA_API_TOKEN, JIRA_EMAIL (or JIRA_USER)
echo $JIRA_API_TOKEN  # verify it loaded
```

### Auth Format

Jira REST API uses Basic Auth with email + API token:

```bash
-u "orcunst@gmail.com:$JIRA_API_TOKEN"
```

### Important: Analizci Auth Returns "token" Field (Not "access_token")

```bash
# Analizci local auth (NOT Jira — different API):
response=$(curl -s -X POST http://localhost:8200/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"pin": "1234"}')
TOKEN=$(echo $response | python3 -c "import sys,json; print(json.load(sys.stdin)['token'])")
# Field is "token", NOT "access_token"!
```

### Transition IDs (AVIDO Project)

```
11 = To Do
21 = In Progress
31 = Done
```

**Important**: Transition IDs are **project-specific**. Always check them first:

```bash
curl -s -u "$EMAIL:$JIRA_API_TOKEN" \
  "https://orchun.atlassian.net/rest/api/3/issue/AVIDO-1/transitions" \
  | python3 -m json.tool | grep -E '"id"|"name"'
```

## Bulk Transition Pattern

```bash
source /root/.claude/.env
EMAIL="orcunst@gmail.com"
BASE_URL="https://orchun.atlassian.net/rest/api/3"

# List of tasks to transition
TASKS=("AVIDO-3" "AVIDO-4" "AVIDO-5" "AVIDO-6" "AVIDO-7")

for KEY in "${TASKS[@]}"; do
  # Optional: check current status first
  STATUS=$(curl -s \
    -u "$EMAIL:$JIRA_API_TOKEN" \
    "$BASE_URL/issue/$KEY?fields=status" \
    | python3 -c "import sys,json; print(json.load(sys.stdin)['fields']['status']['name'])" 2>/dev/null)

  # Transition to Done (ID: 31)
  HTTP=$(curl -s -w "%{http_code}" -o /dev/null \
    -u "$EMAIL:$JIRA_API_TOKEN" \
    -X POST "$BASE_URL/issue/$KEY/transitions" \
    -H "Content-Type: application/json" \
    -d '{"transition": {"id": "31"}}')

  echo "$KEY ($STATUS) → HTTP $HTTP"
done
```

## Add Comment to Issue

```bash
curl -s \
  -u "$EMAIL:$JIRA_API_TOKEN" \
  -X POST "$BASE_URL/issue/$KEY/comment" \
  -H "Content-Type: application/json" \
  -d '{
    "body": {
      "type": "doc",
      "version": 1,
      "content": [{
        "type": "paragraph",
        "content": [{"type": "text", "text": "Your comment here"}]
      }]
    }
  }'
```

## Search Issues with JQL

```bash
# JQL must be URL-encoded (= → %3D, space → %20, etc.)
curl -s \
  -u "$EMAIL:$JIRA_API_TOKEN" \
  "https://orchun.atlassian.net/rest/api/3/search?jql=project%3DAVIDO+ORDER+BY+key" \
  | python3 -c "
import sys, json
data = json.load(sys.stdin)
for issue in data['issues']:
  print(issue['key'], '|', issue['fields']['status']['name'], '|', issue['fields']['summary'][:60])
"
```

## Common Response Codes

| Code | Meaning |
|------|---------|
| 204 | Success (transition worked) |
| 400 | Invalid transition ID for current status |
| 401 | Auth failed (check token) |
| 404 | Issue not found |
| 409 | Transition not valid from current status |

## Key Lessons

1. **Transition IDs are project-specific** — always verify before bulk operations
2. **`source /root/.claude/.env`** — token is in the env file
3. **JQL needs URL encoding** — spaces and `=` must be encoded
4. **HTTP 204 = success** for Jira transitions (not 200)
5. **Analizci's own auth uses `token` field** — don't confuse with Jira's `access_token`

## Related

- `EXP-0095`: Analizci deployment patterns (auth token field)
- AVIDO Jira project: 14 tasks bulk-transitioned Done in this session
