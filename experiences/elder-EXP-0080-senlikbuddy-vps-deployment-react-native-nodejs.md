# EXP-0080: React Native + Node.js Backend VPS Deployment

## Status: SUCCESS

## Context
- **Project**: SenlikBuddy (ODTU Dating App)
- **Stack**: React Native (Expo) + Node.js/Express + MongoDB
- **VPS**: 173.249.18.183
- **Date**: 2026-02-03

## Problem
Deploying a React Native mobile app with Node.js backend to VPS with automated CI/CD through GitHub Actions, while managing multiple branches (development vs production).

## Key Learnings

### 1. GitHub Actions CI/CD Setup

**Required Secrets:**
- `VPS_HOST` - VPS IP address
- `VPS_USERNAME` - SSH username (usually root)
- `VPS_SSH_KEY` - Private SSH key for deployment
- `JIRA_USER_EMAIL` - For Jira integration (optional)
- `JIRA_API_TOKEN` - For Jira integration (optional)
- `SLACK_WEBHOOK_URL` - For Slack notifications (optional)

**SSH Key Management:**
- Use existing `github_actions_deploy` key from VPS `~/.ssh/`
- Add public key to `~/.ssh/authorized_keys` on VPS
- Store private key in GitHub Secrets (VPS_SSH_KEY)

**Workflow Configuration:**
```yaml
name: Deploy to VPS
on:
  push:
    branches: [main, master]
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Deploy via SSH
        uses: appleboy/ssh-action@v0.1.10
        with:
          host: ${{ secrets.VPS_HOST }}
          username: ${{ secrets.VPS_USERNAME }}
          key: ${{ secrets.VPS_SSH_KEY }}
          script: |
            cd /projects/project-name
            git pull
            npm install
            pm2 restart app-name
```

### 2. PM2 Deployment Gotchas

**Script Naming:**
- `npm start` script must exist in package.json
- Or use `npm run start:prod` with explicit script name
- PM2 requires exact script reference

**TypeScript Build Failures:**
- If `tsc` build fails, use ts-node as fallback:
```bash
pm2 start 'npx ts-node -r tsconfig-paths/register src/server.ts' --name app-name
```

**Essential PM2 Commands:**
```bash
pm2 start npm --name "app-name" -- start  # Start with npm
pm2 save                                   # Save process list
pm2 startup                               # Enable auto-restart on reboot
pm2 logs app-name                         # View logs
pm2 restart app-name                      # Restart after code changes
```

### 3. Branch Workflow Strategy

**Development Branch (e.g., `orcun`):**
- Active development happens here
- Feature branches merge into development
- Testing and debugging

**Production Branch (`master` preferred over `main`):**
- User preference: use `master` instead of `main`
- CI/CD triggers on push to this branch
- Only merge when ready for deployment

**Merge Process:**
```bash
# Commit all changes first
git add .
git commit -m "Feature complete"

# Switch and merge
git checkout master
git merge orcun
git push origin master  # Triggers CI/CD
```

**Warning:** Stash won't work if files have conflicts - must commit first.

### 4. Environment Setup

**Backend .env Required Variables:**
```env
PORT=3031              # Local port
NODE_ENV=production    # Environment
DB_HOST=localhost      # MongoDB host
DB_PORT=27017         # MongoDB port
DB_NAME=idate         # Database name
URL_BASE=http://localhost:3031  # API base URL
```

**Port Configuration:**
| Environment | Port |
|-------------|------|
| Local       | 3031 |
| VPS         | 8580 |

**Firebase Service Key:**
- `serviceKey.json` must be copied separately (gitignored)
- Location: `src/config/serviceKey.json`
- Contains Firebase admin credentials
- NEVER commit to repository

### 5. Common Errors & Solutions

| Error | Cause | Solution |
|-------|-------|----------|
| "Missing script start" | package.json scripts misconfigured | Use correct script name in PM2 |
| TypeScript build errors | Type issues or path resolution | Use ts-node as fallback |
| Network Error on mobile | Backend not running | Check `lsof -i :PORT`, start backend |
| SSH permission denied | Key not authorized | Add public key to authorized_keys |
| PM2 process not found | Process crashed | Check `pm2 logs`, restart with correct config |

### 6. Deployment Checklist

**Pre-deployment:**
- [ ] All changes committed
- [ ] Tests passing locally
- [ ] Environment variables configured on VPS
- [ ] Firebase serviceKey.json in place on VPS
- [ ] SSH key authorized

**Deployment:**
- [ ] Merge to master/main branch
- [ ] Push triggers GitHub Action
- [ ] Monitor GitHub Actions for success
- [ ] Check PM2 logs on VPS
- [ ] Verify health endpoint

**Post-deployment:**
- [ ] Test API endpoints
- [ ] Check mobile app connectivity
- [ ] Verify database connection
- [ ] Monitor error logs

## Files Modified
- `.github/workflows/ci-deploy.yml` (backend)
- `.github/workflows/ci.yml` (frontend)
- `.env` on VPS
- `package.json` (scripts section)

## Related Experiences
- [EXP-0043](EXP-0043-kiwi-roadie-testflight-backend-connectivity-fix.md) - TestFlight deployment patterns
- [EXP-0066](EXP-0066-jira-slack-integration-api-changes.md) - CI/CD credential management
- [EXP-0072](EXP-0072-vps-memory-crisis-zombie-sessions-mongodb-tls.md) - VPS debugging

## Tags
- deployment
- vps
- pm2
- github-actions
- react-native
- nodejs
- mongodb
- ci-cd
- typescript
- ssh
- environment-configuration

## Prevention
1. **Test locally first**: Always verify build/start commands before deployment
2. **Use health endpoints**: Implement `/health` for quick verification
3. **Document ports**: Keep port mapping documentation updated
4. **Separate secrets**: Never commit serviceKey.json or .env files
5. **PM2 save**: Always run `pm2 save` after configuration changes

## Success Metrics
- Automated deployment on git push
- Zero-downtime deployments with PM2
- Clear error logging and monitoring
- Reproducible environment setup

---
**Experience ID**: EXP-0080
**Created**: 2026-02-03
**Project**: SenlikBuddy
**Category**: DevOps/Deployment
