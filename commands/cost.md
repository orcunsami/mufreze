# /mufreze-cost

Show Claude Code cost and token usage analysis.

## Usage

```
/mufreze-cost [period]
```

- `period` — `daily` (default), `weekly`, `monthly`, `session`

## Protocol

1. Run `ccusage <period> --last 7` via Bash to show recent usage
2. Summarize: total cost, busiest day, dominant model
3. If cost is high, suggest optimization (use haiku for explore agents, compact more often)

## Example

```bash
ccusage daily --last 7
ccusage session --last 5
ccusage monthly
```
