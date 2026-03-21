# EXP-0095: Analizci Deployment Patterns

**Date**: 2026-02-28
**Project**: Analizci (Video Analysis Platform)
**Severity**: MEDIUM
**Tags**: `docker`, `nextjs`, `mongodb`, `analizci`, `deployment`, `standalone`, `env-file`

## Problem

Analizci has several non-obvious deployment gotchas that cause confusion when making changes.

## Critical Facts

### 1. backend/.env is a DIRECTORY (not a file)

```bash
ls -la /usr/local/main/analizci/backend/.env
# drwxr-xr-x  2 root root 4096 ...  .env/
```

- `.env` is an **empty directory** in this project
- Actual env values come from `docker-compose.yml` → `environment:` section
- Do NOT try to source it or wonder why env vars seem missing

### 2. MongoDB DB Name is Hardcoded

```python
# backend/app/core/mongodb.py
DATABASE_NAME = "analiz_db"  # HARDCODED - not from MONGODB_URL
```

- `MONGODB_URL` env var only controls: host, port, auth credentials
- DB name is always `analiz_db` regardless of connection string
- When querying MongoDB directly, always use `analiz_db`

### 3. Docker MongoDB Port is 27018 (not standard 27017)

```bash
# docker-compose.yml
ports:
  - "27018:27017"  # host:container

# Connection from host machine:
mongosh "mongodb://admin:changeme@localhost:27018/analiz_db?authSource=admin"

# Connection from within Docker network (container-to-container):
mongosh "mongodb://admin:changeme@analizci-mongodb:27017/analiz_db?authSource=admin"
```

### 4. Analizci Auth Token Field

```bash
# Login endpoint returns:
{ "token": "eyJ..." }  # NOT "access_token"!

# Correct usage:
TOKEN=$(curl -s -X POST "http://localhost:8200/api/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"pin": "1234"}' | python3 -c "import sys,json; print(json.load(sys.stdin)['token'])")
```

## Backend Deployment (Code Change)

```bash
# Copy changed file into container + restart
docker cp /usr/local/main/analizci/backend/app/routers/analysis.py \
    analizci-backend:/app/app/routers/analysis.py

docker restart analizci-backend

# Verify it's running
docker logs analizci-backend --tail 20
```

## Frontend Deployment (Build + Restart)

```bash
cd /usr/local/main/analizci/frontend

# 1. Build
bun run build

# 2. Copy static assets (REQUIRED — standalone doesn't include these)
cp -r .next/static .next/standalone/.next/static
cp -r public .next/standalone/

# 3. Kill existing process
kill $(fuser 3200/tcp 2>/dev/null) 2>/dev/null || true

# 4. Start
PORT=3200 nohup node .next/standalone/server.js > /tmp/analizci-frontend.log 2>&1 &

# 5. Verify
sleep 2 && curl -s -o /dev/null -w "%{http_code}" http://localhost:3200/
```

## Docker Compose Management

```bash
cd /usr/local/main/analizci

# View all service statuses
docker-compose ps

# Restart a specific service
docker-compose restart backend

# View backend logs (follow)
docker-compose logs -f backend

# Full restart
docker-compose down && docker-compose up -d
```

## MongoDB Direct Access

```bash
# From host (using port 27018):
docker exec analizci-mongodb mongosh \
  "mongodb://admin:changeme@localhost:27017/analiz_db?authSource=admin" \
  --quiet --eval 'db.analyses.countDocuments()'

# Check all analysis statuses:
docker exec analizci-mongodb mongosh \
  "mongodb://admin:changeme@localhost:27017/analiz_db?authSource=admin" \
  --quiet --eval '
  db.analyses.find({}, {status:1, video_id:1, _id:1}).forEach(d =>
    print(d._id + " | " + d.video_id + " | " + d.status)
  )'
```

## Key Lessons

1. **Always check if `.env` is a file or directory** before debugging env issues
2. **DB name from code, not env** — don't look for it in MONGODB_URL
3. **Port mapping** — host vs container port distinction matters for direct DB access
4. **Token field name** — verify with `jq` or `python3 -c` what field the auth endpoint returns
5. **Static copy** — Next.js standalone builds always need manual static file copy
