# EXP-0065: Grand Repo Merge - Nested Git to Single Repo

**Date**: 2025-12-13
**Project**: Grand Gayrimenkul Platform
**Type**: Git/Infrastructure

---

## Problem

Grand project had a nested git structure:
- `/grand/` - parent repo (github.com/OrcunSamiTandogan/grand)
- `/grand/grand-vue/` - nested git repo (github.com/OrcunSamiTandogan/grand-vue)

This caused confusion and sync issues between local and VPS.

## Solution

### Step 1: Remove Nested Git
```bash
cd /Users/mac/Documents/freelance/grand
rm -rf grand-vue/.git
```

### Step 2: Remove Another Nested Repo (if exists)
Found `iyzipay-python` embedded repo:
```bash
rm -rf grand-vue/maintenance/documentation/iyzipay-python/.git
```

### Step 3: Add All Files to Parent Repo
```bash
git rm --cached grand-vue  # Remove gitlink
git add -A
git commit -m "Merge grand-vue into single repository"
```

### Step 4: Flatten Structure
```bash
# Move contents to root
mv grand-vue/* .
mv grand-vue/.* .  # Hidden files
rmdir grand-vue

git add -A
git commit -m "Flatten structure"
```

### Step 5: Update VPS
```bash
ssh root@45.92.9.229 "cd /usr/local/main/grand && \
  git remote set-url origin git@github.com:OrcunSamiTandogan/grand.git && \
  git fetch origin && \
  git reset --hard origin/master"
```

### Step 6: Restart PM2
```bash
ssh root@45.92.9.229 "pm2 restart grand-api"
```

## Key Learnings

1. **Check for multiple nested repos** - `iyzipay-python` was also embedded
2. **Use SSH for push to private repos** - HTTPS failed with "repository not found"
3. **Flatten structure to match VPS** - Avoid path changes that break PM2
4. **`git rm --cached`** removes gitlink without deleting files

## Result

| Before | After |
|--------|-------|
| 2 separate git repos | 1 unified repo |
| Nested structure | Flat structure |
| Path mismatch with VPS | Identical to VPS |
| 2 GitHub repos | 1 GitHub repo |

## Tags
#git #nested-repo #infrastructure #grand #vps
