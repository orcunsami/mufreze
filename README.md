# 🎖️ MUFREZE — Multi-LLM Orchestration for Claude Code

> "Claude thinks, cheap LLMs build. Self-learning experience system included."

---

## What is MUFREZE?

MUFREZE is a Claude Code plugin and CLI orchestration tool that turns Claude into a "brain" while delegating bulk code generation to cheaper LLMs like Kimi and Codex. It includes a complete "company system" with defined roles (Architect, Coder, Reviewer, Tester) and a self-learning experience system that remembers past failures and successes.

Think of it as a smart project manager that knows when to delegate to fast/cheap workers and when to escalate to more capable (and expensive) ones.

---

## Why?

Building production code with Claude Opus is powerful but expensive. Most coding tasks don't need that level of reasoning.

| Model | Input/1M tokens | Output/1M tokens | Typical coding session* |
|-------|-----------------|------------------|------------------------|
| Claude 3 Opus | $15.00 | $75.00 | ~$6-12 |
| Kimi (unlimited) | ~$0.00 | ~$0.00 | ~$0.00 |
| Codex | ~$0.00 | ~$0.00 | ~$0.00 |

*Assuming ~50k input, ~20k output tokens for a feature implementation

**Typical savings: 70-90%** — Use Claude for architecture, code review, and complex decisions. Let Kimi/Codex handle the implementation grunt work.

---

## How It Works

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   You /     │────▶│   Claude    │────▶│  Architect  │
│  Product    │     │   (Brain)   │     │  (Breakdown)│
│   Owner     │◄────│             │◄────│             │
└─────────────┘     └──────┬──────┘     └─────────────┘
                           │
                    ┌──────┴──────┐
                    │   Delegate  │
                    └──────┬──────┘
                           ▼
            ┌──────────────────────────────┐
            │      Kimi / Codex            │
            │      (Cheap Workers)         │
            └──────────────┬───────────────┘
                           │
                           ▼
            ┌──────────────────────────────┐
            │      Verify / Review          │
            │      (Claude Sonnet)          │
            └──────────────┬───────────────┘
                           │
              ┌────────────┼────────────┐
              ▼            ▼            ▼
           Success      Retry       Escalate
              │         (x5)      (Codex→Sonnet)
              ▼                        ▼
         ✅ Commit                🧠 Claude Opus
              │                        │
              └────────────┬───────────┘
                           ▼
                    ┌─────────────┐
                    │  Learn (EXP)│
                    └─────────────┘
```

1. **You** describe a feature
2. **Claude (Architect)** breaks it into atomic tasks (1 task = 1 file)
3. **Delegate** to Kimi (default) or Codex
4. **Verify** with Claude Sonnet — syntax, conventions, security
5. **Retry** if needed (up to 5 times with exponential backoff)
6. **Escalate** through the chain if retries fail: Kimi → Codex → Claude Sonnet → Claude Opus
7. **Learn** — every failure/success becomes an EXP record so workers don't repeat mistakes

---

## Features

- **Multi-worker orchestration** — Kimi, Codex, Claude Sonnet, Claude Opus with automatic failover
- **Retry + Escalation** — 5 retries with exponential backoff, automatic escalation to stronger models
- **Self-learning EXP system** — Captures failures and patterns in YAML+Markdown format, promotes to global knowledge base after 3 hits
- **Full "Company" system** — Architect (breakdown), Coder (delegate), Reviewer (verify), Tester (test) roles
- **Dual mode** — Works as Claude Code plugin (agents, skills, commands) + standalone CLI (`mufreze` command)
- **Atomic tasks** — One task creates exactly one file, no wiring, no side effects
- **Zero vendor lock-in** — Pure bash, POSIX-compatible, JSON config, Markdown specs

---

## Install

### One-liner (Recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/orcunst/mufreze/main/install.sh | bash
```

### Manual Install

```bash
git clone https://github.com/orcunst/mufreze.git ~/.mufreze
export PATH="$HOME/.mufreze/bin:$PATH"
export MUFREZE_HOME="$HOME/.mufreze"
```

**Prerequisites:**
- [Kimi CLI](https://github.com/kimi-ai/kimi-cli) — `pip install kimi-dev`
- [Codex CLI](https://github.com/openai/codex) — `npm install -g @openai/codex`

---

## Quick Start

### 1. Initialize a new project

```bash
mufreze new-project /path/to/my-project
cd /path/to/my-project
```

This creates:
```
.mufreze/
├── mufreze.json      # Config: workers, retry rules, EXP paths
├── exp/              # Project-specific experience records
└── tasks/            # Task queue
docs/
└── MUFREZE-BRIEFING.md   # Project conventions (fill this!)
```

### 2. Fill in your briefing

Edit `docs/MUFREZE-BRIEFING.md` with your project's tech stack, directory structure, naming conventions, and rules. This is the "source of truth" for all workers.

### 3. Delegate your first task

```bash
mufreze delegate kimi 'Create users.py with FastAPI router. 
  Requirements:
  - GET /users and POST /users endpoints
  - Use async def
  - Reference: routers/auth.py' /path/to/my-project
```

### 4. Verify and iterate

```bash
mufreze verify /path/to/my-project
```

---

## Company System

MUFREZE organizes work into four agent roles:

| Role | Default Worker | Responsibility |
|------|---------------|----------------|
| **Architect** | Claude Opus | Breaks features into atomic tasks, defines dependencies and execution order |
| **Coder** | Kimi | Executes atomic implementation tasks, creates exactly one file per task |
| **Reviewer** | Claude Sonnet | Verifies output quality, checks conventions, security, syntax |
| **Tester** | Codex | Writes and runs tests, reports results |

All roles are defined in `agents/*.md` and can be customized per project.

---

## EXP System

EXP (Experience) is MUFREZE's self-learning mechanism. Every failure and success pattern is captured and reused.

**Structure:**
- Stored as YAML frontmatter + Markdown
- Project-specific: `.mufreze/exp/EXP-XXX-*.md`
- Global (promoted): `~/.mufreze/experiences/`

**Bundled EXPs (20 global patterns):**

| ID | Topic |
|----|-------|
| EXP-001 | Shell heredoc MongoDB dollar escaping |
| EXP-002 | MongoDB compound index multitenant |
| EXP-003 | Pydantic v2 migration patterns |
| EXP-004 | Vue i18n full path references |
| EXP-005 | Asyncio ProcessPool SIGALRM handling |
| EXP-006 | Celery asyncio event loop |
| EXP-007 | Config defaults vs production values |
| EXP-008 | Retry + circuit breaker pattern |
| EXP-009 | Offline queue MongoDB fallback |
| EXP-010 | MUFREZE delegation pattern |
| EXP-011 | FastAPI auth dependency injection |
| EXP-012 | Nginx FastAPI CORS double header |
| EXP-013 | Python venv not portable |
| EXP-014 | Bun PM2 interpreter setup |
| EXP-015 | Next.js parent route page.tsx |
| EXP-016 | Docker test scheduled timing |
| EXP-017 | Bash env sourcing safety |
| EXP-018 | Frontend API URL axios multipart |
| EXP-019 | Tailwind v4 cascade layers |
| EXP-020 | Config centralization single source |

**Create a new EXP:**
```bash
mufreze learn failure "brief description" /path/to/project
```

---

## Configuration

Project config lives in `.mufreze/mufreze.json`:

```json
{
  "mode": "delegation",
  "version": "1.0.0",
  "workers": {
    "coder": "kimi",
    "reviewer": "claude-sonnet-4-6",
    "tester": "codex",
    "architect": "claude-opus-4-6"
  },
  "retry": {
    "max_attempts": 5,
    "timeout_seconds": 180,
    "escalate_chain": ["kimi", "codex", "claude-sonnet-4-6", "claude-opus-4-6"]
  },
  "exp": {
    "project_path": ".mufreze/exp/",
    "global_path": "~/.mufreze/experiences/",
    "auto_save": true,
    "promote_threshold": 3
  },
  "verify": {
    "run_syntax_check": true,
    "run_type_check": true,
    "fail_on_error": true
  }
}
```

---

## CLI Reference

```bash
mufreze delegate <worker> <prompt> <path>   # Delegate task to worker
mufreze verify <path>                        # Verify completed task
mufreze status                               # Show project status
mufreze learn <outcome> <exp-id> <path>      # Record EXP from outcome
mufreze new-project <path>                   # Initialize new project
mufreze help                                 # Show help
```

---

## Contributing

Contributions are welcome! This is an early-stage open source project.

- **Issues:** Bug reports, feature requests, EXP pattern submissions
- **PRs:** Bug fixes, new EXP patterns, documentation improvements
- **EXPs:** If you discover a repeatable failure pattern, submit it as a new EXP

Please keep changes minimal and follow the existing bash style (`set -euo pipefail`, atomic functions, consistent exit codes).

---

## License

MIT — See [LICENSE](LICENSE) for details.
