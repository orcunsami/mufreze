# EXP-0104: Mufreze — Kimi CLI Delegation Pattern (60-75% Token Savings)

## Metadata
- **Date**: 2026-02-28
- **Project**: All OST projects (Resmi Gazete, HocamClass, GrandBazaar, etc.)
- **Severity**: MEDIUM (workflow efficiency, cost savings)
- **Category**: AI Workflow, Token Optimization, Multi-Agent
- **Status**: ACTIVE PATTERN

## Overview
Mufreze is a workflow where Claude (expensive, smart) plans + verifies + wires, and Kimi (cheap, fast) generates new boilerplate files. Results in 60-75% token savings on file generation tasks.

## Division of Responsibility
```
Claude (Komutan/Orchestrator):
  YES - Analyzes requirements
  YES - Writes task specification (what file to create + exact API/structure)
  YES - Delegates to Kimi via bash command
  YES - Verifies output (TypeScript check, imports, logic review)
  YES - Wires files (adds to App.tsx routes, imports, i18n keys, API clients)
  NO  - Does NOT generate boilerplate files

Kimi (Worker):
  YES - Generates NEW files from scratch based on spec
  YES - Follows briefing doc conventions
  NO  - Does NOT modify existing files
  NO  - Does NOT wire/connect files
```

## The Command
```bash
# Basic Kimi call
kimi --yolo --print --final-message-only -w /path/to/project -p "TASK SPEC HERE"

# With briefing doc reference (ALWAYS include this)
kimi --yolo --print --final-message-only \
  -w /usr/local/main/resmigazete/frontend \
  -p "$(cat docs/KIMI-BRIEFING.md)

---
GOREV: Create src/pages/Dashboard.tsx SIFIRDAN.
Requirements: ..."
```

## KIMI-BRIEFING.md Structure (REQUIRED in every project)
```markdown
# Kimi Briefing — [Project Name]

## Tech Stack
- Frontend: React 19 + TypeScript + Vite 6 + Tailwind CSS v4
- Backend: FastAPI + MongoDB
- Router: React Router v7

## Conventions
- Tailwind v4: dark: prefix uses @media (prefers-color-scheme: dark)
- Colors: slate-* (NOT gray-*), blue-500 (NOT blue-600)
- No class-based dark mode (no class="dark")
- ASLA kullanma: bg-bg-dark, border-border-dark, text-primary, from-primary

## API Functions (from src/lib/api.ts)
- getMe(): Promise<User>
- login(email, password): Promise<{access_token}>
- chatbotAsk(message, sessionId?): Promise<ChatResponse>
[list all available api functions]

## File Structure
src/
|-- pages/        <- Kimi writes here
|-- components/   <- Shared components
|-- lib/api.ts    <- API functions (DO NOT MODIFY)
`-- App.tsx       <- Routes (DO NOT MODIFY)
```

## Prompting Best Practices

### Good Kimi Prompt
```
SIFIRDAN yaz: src/pages/Dashboard.tsx

Requirements:
1. Import: getMe(), logout() from '../lib/api'
2. Show user profile: email, full_name, profession
3. Logout button calls logout() then navigate('/')
4. Loading state while getMe() pending
5. Error state if getMe() fails

YASAK CSS CLASS'LAR: bg-bg-dark, border-border-dark, text-primary
Kullan: slate-* colors, Tailwind v4 utilities
```

### Bad Kimi Prompt
```
Dashboard sayfasi yaz  # Too vague
```

### Key Phrases
- `SIFIRDAN yaz` = Write from scratch (don't modify existing)
- Explicitly list BANNED CSS classes (Kimi tends to hallucinate wrong class names)
- Reference exact import paths and function signatures
- List state vars expected

## Parallel Execution (3+ tasks at once)
```bash
# Launch 3 Kimi tasks in parallel (each for different file)
kimi --yolo --print --final-message-only -w $DIR -p "Create Dashboard.tsx..." &
kimi --yolo --print --final-message-only -w $DIR -p "Create ArsivPage.tsx..." &
kimi --yolo --print --final-message-only -w $DIR -p "Create Soru.tsx..." &
wait  # Wait for all 3

# Then Claude verifies all 3
npm run build  # TypeScript check
```

## Verification After Kimi Output
```bash
# 1. TypeScript/syntax check
cd frontend && npx tsc --noEmit

# 2. Build check
npm run build

# 3. Logic review (Claude reads the output)
# Check: imports correct? API calls correct? State management correct?

# 4. Wire it (Claude does this, NOT Kimi)
# - Add to App.tsx routes
# - Add i18n keys to translation files
# - Add API endpoint registration
```

## Token Savings Calculation
- Claude generating 3 pages from scratch: ~15,000 tokens
- Claude writing specs + verifying Kimi output: ~4,000 tokens
- **Savings: ~73%**

## When NOT to Use Kimi
- Modifying existing files (Kimi makes conflicting edits)
- Cross-file changes (Kimi can't track dependencies)
- Complex business logic (Claude's understanding is better)
- Files with intricate state management

## Applicable To
- ALL OST projects with frontend boilerplate
- Backend route scaffolding
- Test file generation
- Documentation generation

## Lessons Learned
1. **KIMI-BRIEFING.md is mandatory** — without project context, Kimi hallucinates
2. **"SIFIRDAN yaz"** prevents Kimi from partially editing existing files
3. **Explicitly ban wrong CSS** — `YASAK: bg-bg-dark` in prompt prevents hallucinated classes
4. **Parallel works** — 3 Kimi tasks in parallel all succeeded, all passed build
5. **Claude wires, Kimi generates** — never ask Kimi to update App.tsx or add routes
6. **Verify with build** — `npm run build` catches 80% of Kimi errors immediately

## Related Experiences
- EXP-0073: TABUR multi-agent system (similar delegation concept)
- EXP-0093: Tailwind v4 cascade layer (verify Kimi doesn't add unlayered CSS)

## Tags
`mufreze` `kimi` `delegation` `token-optimization` `multi-agent` `workflow` `boilerplate`
