# EXP-0102: Config Centralization — config.ini + VERSION Single Source of Truth

## Metadata
- **Date**: 2026-02-28
- **Project**: JARVIS Voice System (Jira MAC-89, MAC-90)
- **Severity**: MEDIUM (causes inconsistency and maintenance burden)
- **Category**: Configuration Management, DevOps
- **Status**: SOLVED

## Problem Statement
All tunable parameters hardcoded directly in Python files. Version number defined in 3+ files (config.py, setup.py, README.md) that diverge. No way to tune behavior without touching code.

## Solution

### config.ini — Centralized Tunable Parameters
```ini
# config.ini (at project root)

[audio]
SAMPLE_RATE = 16000
SILENCE_THRESHOLD = 1.5
SILENCE_DURATION = 1.0
LISTEN_MODE = always          ; always | push_to_talk | manual

[tts]
VOICE = Yelda                 ; Turkish TTS voice
SPEED = 1.0
LANGUAGE = tr-TR

[ai]
GEMINI_RATE_LIMIT = 4         ; seconds between calls (free tier)
MAX_RETRIES = 3
RETRY_INITIAL_DELAY = 0.5
RETRY_MAX_DELAY = 30.0

[tabur]
POLLING_INTERVAL = 0.5        ; seconds between status checks
TASK_TIMEOUT = 1800           ; 30 minutes max task time
HEALTH_CHECK_TIMEOUT = 5      ; seconds to wait for session response

[mongodb]
TTL_DAYS = 30                 ; event retention period
SYNC_RETRY_INTERVAL = 300     ; seconds between offline sync attempts
MAX_QUEUE_SIZE = 1000         ; in-memory queue max events

[services]
CLAUDE_GATEWAY_URL = http://127.0.0.1:3456
KOMUTAN_SESSION = tabur-serasker
NEFER_SESSIONS = nefer-backend,nefer-frontend,nefer-devops,nefer-tester
```

### Reading config.ini in Python
```python
import configparser
from pathlib import Path

def load_config():
    config = configparser.ConfigParser()
    config_path = Path(__file__).parent.parent / "config.ini"
    config.read(config_path)
    return config

# Module-level config object
CONFIG = load_config()

# Usage
SAMPLE_RATE = CONFIG.getint("audio", "SAMPLE_RATE", fallback=16000)
GEMINI_RATE_LIMIT = CONFIG.getfloat("ai", "GEMINI_RATE_LIMIT", fallback=4.0)
KOMUTAN_SESSION = CONFIG.get("services", "KOMUTAN_SESSION", fallback="tabur-serasker")
```

### VERSION File — Single Source of Truth
```bash
# VERSION (at project root — plain text, just the version)
7.0
```

```python
# version.py — reads from single file
from pathlib import Path

def get_version() -> str:
    version_file = Path(__file__).parent.parent / "VERSION"
    return version_file.read_text().strip()

VERSION = get_version()

# Usage in any file:
from version import VERSION
print(f"JARVIS v{VERSION}")
```

```bash
# Bump version (one command, one file)
echo "7.1" > VERSION

# In build scripts:
VERSION=$(cat VERSION)
docker build --build-arg VERSION=$VERSION .
```

### What Goes Where
| Type | Location | Example |
|------|----------|---------|
| Secrets (API keys, passwords) | `.env` (never commit) | `GEMINI_API_KEY=...` |
| Tunable parameters | `config.ini` | timeouts, thresholds |
| App version | `VERSION` | `7.0` |
| Fixed constants | Python constants | `MAX_MESSAGE_LENGTH = 4096` |

## Applicable To
- ALL production Python applications
- Any multi-file project where version divergence is possible
- Systems with behavior that needs tuning without code changes

## Lessons Learned
1. **config.ini > environment variables** for tunable parameters — human-readable, grouped
2. **VERSION file** is simpler than `__version__` in `__init__.py` — accessible from scripts too
3. **`fallback=` in getint/getfloat** — graceful defaults if config missing
4. **Never hardcode** what might need tuning (timeouts, thresholds, polling intervals)
5. **git-commit config.ini** (no secrets) so behavior is version-controlled

## Related Experiences
- EXP-0098: Backoff parameters come from config.ini
- EXP-0099: Health check timeout from config.ini

## Tags
`config` `configuration` `python` `version` `single-source-of-truth` `maintainability`
