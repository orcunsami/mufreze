# /mufreze-parallel

Run multiple atomic tasks in parallel via MUFREZE workers.

## Usage

```
/mufreze-parallel <tasks_file> <path> [max_concurrent]
```

## Tasks File Format

One task per line, pipe-separated: `worker|prompt`

```
kimi|Create routers/users.py with FastAPI CRUD endpoints
kimi|Create routers/products.py with FastAPI CRUD endpoints
codex|Create tests/test_users.py with pytest
codex|Create tests/test_products.py with pytest
```

## Protocol

1. Architect breaks feature into atomic tasks
2. Write tasks to a file (one per line)
3. Run `mufreze parallel tasks.txt /project/path 4`
4. Wait for all to complete
5. Run `mufreze verify /project/path` on results

## Example

```bash
mufreze parallel tasks.txt /path/to/project 4
```
