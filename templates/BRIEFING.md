# [PROJECT NAME] — MUFREZE Briefing

## Project Overview
[1-2 sentences: what this project does]

## Tech Stack
- **Backend**: FastAPI | Laravel | Express | ...
- **Frontend**: Next.js | Vue 3 | React Native | ...
- **Database**: MongoDB | MySQL | PostgreSQL | ...
- **Language**: Python | TypeScript | PHP | ...

## Directory Structure
```
project/
├── backend/
│   ├── routers/
│   ├── services/
│   └── main.py
├── frontend/
│   ├── components/
│   ├── pages/
│   └── app/
└── ...
```

## Backend Conventions
- Router files: `routers/{feature}.py` — only route definitions
- Service files: `services/{feature}.py` — business logic
- All endpoints async
- Auth: JWT via Bearer token header
- Response format: `{"success": true, "data": ...}` or `{"success": false, "error": "..."}`

## Frontend Conventions
- Components: PascalCase, one per file
- API calls: centralized in `lib/api.ts` or `services/api.js`
- State: [Zustand | Pinia | Redux] — describe pattern
- Styling: [Tailwind | CSS modules | styled-components]

## Rules — MUST Follow
1. Create ONLY the file specified in the task — no extra files
2. Do NOT mount routes in main.py (Claude handles wiring)
3. Do NOT import from files that don't exist yet
4. Follow existing naming conventions exactly
5. [Add project-specific rules here]

## Rules — MUST Do
1. Export the main object/function (router, component, etc.)
2. Use async/await throughout
3. Add error handling for external calls
4. [Add project-specific requirements here]

## Reference Files
- Similar existing file: `[path/to/similar.py]`
- Base component: `[path/to/BaseComponent.tsx]`

## Task Spec Format
When Claude gives you a task, it will follow this format:
```
Create [filename] with [description].
Requirements:
- [req 1]
- [req 2]
```
Create exactly that file. Nothing more, nothing less.
