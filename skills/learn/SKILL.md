---
name: mufreze-learn
description: Learn from task outcomes using the EXP system. Use to understand patterns, avoid repeating mistakes, and improve delegation success rates.
---

# MUFREZE Learning System (EXP)

Use this skill to leverage the experience system for continuous improvement.

## What Are EXP Files

EXP (Experience) files are YAML frontmatter + markdown records that capture:
- Successful patterns that worked
- Failed attempts and their causes
- Context for future similar tasks

**Location:**
- Project-level: `.mufreze/exp/` (in each project)
- Global: `~/.mufreze/experiences/` (shared across projects)

**Format:**
```yaml
---
id: EXP-001
type: success|failure
worker: kimi|codex|claude-sonnet|claude-opus
timestamp: 2026-03-16T12:00:00Z
task_type: python|typescript|bash|...
file_path: src/example.py
---

## Task Description
Brief description of what was attempted.

## What Worked / What Failed
Details of the outcome.

## Pattern Notes
Key learnings for similar future tasks.
```

## When EXPs Are Auto-Created

The system **automatically creates EXP files** on task completion:

- **Success EXP:** Created when `mufreze delegate` succeeds
- **Failure EXP:** Created when all retry/escalation attempts exhaust

Auto-creation controlled by config:
```json
{
  "exp": {
    "auto_save": true,
    "project_path": ".mufreze/exp/",
    "global_path": "~/.mufreze/experiences/"
  }
}
```

## Manual EXP Creation

Manually trigger EXP creation to record learnings:

```bash
# Record successful pattern
mufreze learn success EXP-001 /project/path

# Record failure for analysis
mufreze learn failure EXP-002 /project/path
```

**Use cases for manual EXP:**
- Documenting a discovered pattern
- Recording why a specific approach was chosen
- Capturing edge cases that required special handling

## Reading EXP Files

**Pattern: Check similar EXPs before new tasks**

```bash
# List all project EXPs
ls -la .mufreze/exp/

# Read specific EXP
cat .mufreze/exp/EXP-001.md

# Search for relevant patterns
grep -l "FastAPI" .mufreze/exp/*.md
grep -l "failure" .mufreze/exp/*.md
```

### Pre-Task EXP Check

Before delegating a new task, check for similar past experiences:

```bash
# Look for similar task types
find .mufreze/exp -name "*.md" -exec grep -l "jwt\|auth" {} \;

# Look for failures to avoid
find .mufreze/exp -name "*.md" -exec grep -l "type: failure" {} \;

# Look for specific worker experiences
grep -l "worker: kimi" .mufreze/exp/*.md
```

## Using EXPs to Improve Delegation

### Example 1: Avoiding Known Failures

```bash
# Check for similar failures
cat .mufreze/exp/EXP-003.md
---
id: EXP-003
type: failure
worker: kimi
task_type: python
---
## Issue
kimi struggles with complex regex patterns in Python

## Solution
Use codex or claude-sonnet for regex-heavy tasks
```

**Action:** Delegate regex tasks to codex instead of kimi

### Example 2: Reusing Successful Patterns

```bash
cat .mufreze/exp/EXP-001.md
---
id: EXP-001
type: success
worker: kimi
task_type: python
---
## Pattern
FastAPI CRUD endpoints work best with explicit type hints and 
Pydantic models defined inline

## Template
Include: BaseModel, HTTPException, Depends in task spec
```

**Action:** Include these imports in future FastAPI task specs

### Example 3: Worker-Specific Learnings

```bash
# Find what works with each worker
grep -A5 "worker: kimi" .mufreze/exp/*.md | grep "Pattern"
```

## EXP Directory Structure

```
.mufreze/
├── mufreze.json          # Project config
└── exp/
    ├── EXP-001.md        # Success: FastAPI pattern
    ├── EXP-002.md        # Success: React component
    ├── EXP-003.md        # Failure: Complex regex
    └── EXP-004.md        # Success: SQLAlchemy model
```

## Global EXP Sharing

Experiences in `~/.mufreze/experiences/` apply to ALL projects:

```bash
# View global experiences
ls ~/.mufreze/experiences/

# Copy project EXP to global (promote pattern)
cp .mufreze/exp/EXP-001.md ~/.mufreze/experiences/
```

**Promote threshold:** Patterns that succeed 3+ times should be promoted to global.

## Learning Workflow

```bash
# 1. Before new task, check similar EXPs
grep -l "fastapi" .mufreze/exp/*.md 2>/dev/null || echo "No prior EXPs"

# 2. Delegate with learnings applied
mufreze delegate kimi 'Create FastAPI endpoint (remember to include HTTPException import)' ./project

# 3. Verify result
mufreze verify ./project

# 4. System auto-creates EXP record

# 5. Review EXPs periodically for patterns
ls -lt .mufreze/exp/ | head -5
```

## EXP Best Practices

1. **Read before delegating** - Check `.mufreze/exp/` for similar tasks
2. **Record failures** - Manual `mufreze learn failure` for edge cases
3. **Promote successes** - Copy working patterns to `~/.mufreze/experiences/`
4. **Review weekly** - Scan EXPs to identify worker strengths/weaknesses
5. **Update task specs** - Incorporate learnings into future task specifications
