# /mufreze-verify

Verify the output of a delegated task. Run syntax checks, type checks, and wiring validation on recently changed files.

## Usage

```
/mufreze-verify [path]
```

- `path` — project directory to verify (default: current working directory)

## Protocol

1. Run `mufreze verify <path>` via Bash
2. Review the output — look for syntax errors, import failures, type errors
3. If issues found: fix them or re-delegate the specific file to Kimi
4. If clean: proceed with wiring (mount routes, import modules, etc.)

## Example

```bash
mufreze verify /path/to/project
```
