---
name: mufreze-new-project
description: Initialize MUFREZE in a new project — creates config, exp dir, and briefing template
---

# /mufreze-new-project — Initialize MUFREZE in Project

Run this once per project to set up MUFREZE infrastructure.

## Steps

1. **Run initialization**
   ```bash
   mufreze new-project /path/to/your/project
   ```
   This creates:
   - `.mufreze/mufreze.json` — worker config (gitignored)
   - `.mufreze/exp/` — project experience directory (gitignored)
   - `.mufreze/tasks/` — task queue directory (gitignored)
   - `docs/MUFREZE-BRIEFING.md` — briefing template to fill in

2. **Fill in the briefing**
   Open `docs/MUFREZE-BRIEFING.md` and fill in:
   - Tech stack
   - Directory structure
   - Backend/frontend conventions
   - Project-specific rules for workers

3. **Configure workers** (optional)
   Edit `.mufreze/mufreze.json` to customize:
   ```json
   {
     "mode": "delegation",
     "workers": {
       "coder": "kimi",
       "reviewer": "claude-sonnet-4-6"
     }
   }
   ```
   Or use solo mode (Claude only):
   ```json
   { "mode": "solo" }
   ```

4. **Verify setup**
   ```bash
   mufreze status
   ```

## What Gets Gitignored

The following are automatically added to `.gitignore`:
```
.mufreze/exp/
.mufreze/mufreze.json
```

Project EXPs stay local — they're personal learning, not shared code.
To share EXPs with your team, promote them to the global library manually.
