# EXP-0099: Pre-Flight Checks + Real Health Checks (Not Just "Is Session Open?")

## Metadata
- **Date**: 2026-02-28
- **Project**: JARVIS Voice System (Jira MAC-86, MAC-87)
- **Severity**: HIGH (system routes to dead services without this)
- **Category**: Resilience, Monitoring, DevOps
- **Status**: SOLVED

## Problem Statement
Two separate but related problems:
1. **Health checks that lie**: System reports services "healthy" by checking if tmux session exists — but a session that exists != a session that responds
2. **Routing without prerequisites**: System tries to route tasks to TABUR/KOMUTAN without first checking if Claude CLI, tmux, and all sessions are actually available and functional

## Problem 1: Health Checks Must Test Functionality

### Wrong Pattern (what we had)
```python
async def check_health():
    # WRONG: Only checks if tmux session exists
    result = subprocess.run(['tmux', 'has-session', '-t', 'tabur-serasker'], ...)
    return result.returncode == 0  # Session exists != session responds!
```

### Correct Pattern: Send Real Commands
```python
import asyncio
import subprocess

async def check_session_health(session_name: str, timeout: int = 5) -> bool:
    """Real health check: sends test command and verifies response."""
    marker = f"HEALTH_{int(time.time())}"

    # 1. Send a test command to the session
    subprocess.run([
        'tmux', 'send-keys', '-t', session_name,
        f'echo {marker}', 'Enter'
    ])

    # 2. Wait and capture output
    await asyncio.sleep(0.5)
    result = subprocess.run(
        ['tmux', 'capture-pane', '-pt', session_name],
        capture_output=True, text=True
    )

    # 3. Verify our marker appears in output
    return marker in result.stdout

# For Claude CLI specifically:
async def check_claude_healthy(session_name: str, timeout: int = 5) -> bool:
    """Verify Claude CLI is actually processing commands, not stuck."""
    marker = f"CLAUDE_PING_{int(time.time())}"
    subprocess.run(['tmux', 'send-keys', '-t', session_name, f'echo {marker}', 'Enter'])

    deadline = time.time() + timeout
    while time.time() < deadline:
        output = subprocess.run(['tmux', 'capture-pane', '-pt', session_name],
                               capture_output=True, text=True).stdout
        if marker in output:
            return True
        await asyncio.sleep(0.2)
    return False  # Timeout → unhealthy
```

## Problem 2: Pre-Flight Checks Before Routing

### The Pre-Flight Protocol (MAC-87)
```python
async def preflight_check_tabur() -> dict:
    """Verify all TABUR prerequisites before routing any task."""
    checks = {
        "claude_in_path": False,
        "tmux_available": False,
        "komutan_session": False,
        "nefer_backend": False,
        "nefer_frontend": False,
        "nefer_devops": False,
        "nefer_tester": False,
    }

    # 1. Check Claude CLI in PATH
    result = subprocess.run(['which', 'claude'], capture_output=True)
    checks["claude_in_path"] = result.returncode == 0

    # 2. Check tmux available
    result = subprocess.run(['which', 'tmux'], capture_output=True)
    checks["tmux_available"] = result.returncode == 0

    if not checks["tmux_available"]:
        return checks  # No point checking sessions without tmux

    # 3. Check each session exists AND responds
    sessions = ["tabur-serasker", "nefer-backend", "nefer-frontend",
                "nefer-devops", "nefer-tester"]

    for session in sessions:
        key = session.replace("tabur-", "komutan_").replace("nefer-", "nefer_").replace("-", "_")
        checks[key] = await check_session_health(session)

    return checks

async def route_to_tabur(task: dict):
    """Route task to TABUR only after verifying all prerequisites."""
    checks = await preflight_check_tabur()

    if not all(checks.values()):
        failed = [k for k, v in checks.items() if not v]
        logger.warning(f"Pre-flight failed: {failed}")

        # Graceful fallback
        if checks["claude_in_path"] and not checks["komutan_session"]:
            return await start_tabur_and_retry(task)
        else:
            return await handle_without_tabur(task)

    return await send_to_tabur(task)
```

## Health Check Levels
```
Level 1: Exists?         → tmux has-session (fast, unreliable)
Level 2: Responds?       → Send echo, check output (reliable, ~1s)
Level 3: Processes work? → Send real task, check output (slow, definitive)
```

Use Level 2 for routine checks, Level 3 for initial startup verification.

## Applicable To
- TABUR/JARVIS multi-agent systems
- Any system routing work to external processes
- Microservice health checks
- Database connection pool validation

## Lessons Learned
1. **"Session exists" != "session works"** — always send a real command and verify response
2. **Pre-flight before routing** — never assume dependencies are available
3. **Graceful fallback > hard failure** — if TABUR is down, degrade gracefully
4. **5-second health check timeout** — enough for slow systems, not too long for UX
5. **Log what failed** — `failed = [k for k, v in checks.items() if not v]` gives actionable info

## Related Experiences
- EXP-0098: Exponential backoff + circuit breaker (same project)
- EXP-0100: In-memory queue fallback (same project)

## Tags
`health-check` `preflight` `tmux` `tabur` `jarvis` `resilience` `monitoring` `python`
