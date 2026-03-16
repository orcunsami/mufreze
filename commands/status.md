# /mufreze-status

Show the current MUFREZE project status — mode, worker assignments, availability, EXP count, and pending tasks.

## Usage

```
/mufreze-status [path]
```

- `path` — project directory (default: current working directory)

## Protocol

1. Run `mufreze status <path>` via Bash
2. Review worker availability — if kimi/codex missing, switch to solo mode
3. Check EXP count — load relevant experiences before delegating
4. Check pending tasks — resume any unfinished work

## Example

```bash
mufreze status /path/to/project
```
