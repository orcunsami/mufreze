# EXP-0092: SenlikBuddy Full VPS Deployment - Domain, DB Migration, TestFlight

## Metadata
| Field | Value |
|-------|-------|
| **ID** | EXP-0092 |
| **Project** | SenlikBuddy |
| **Date** | 2026-02-08 |
| **Category** | Full Deployment/DevOps/Database Migration/Domain Setup |
| **Status** | SUCCESS |
| **Technologies** | React Native, Expo, Node.js, Express, MongoDB, nginx, Cloudflare, SSL/Let's Encrypt, EAS Build, EAS Submit, TestFlight, Socket.io, PM2 |
| **Duration** | ~3 hours across sessions |

## Summary
Complete end-to-end deployment cycle for SenlikBuddy mobile app covering MongoDB data migration between VPS servers, Cloudflare + nginx + SSL domain setup for mobile API, EAS Build version sync fixes, comprehensive old reference scanning, EAS Submit non-interactive configuration, and architectural decisions around separate API subdomains and MongoDB authentication on localhost.

---

## Problem 1: MongoDB Data Migration Between VPS Servers (CRITICAL!)

### Symptoms
- New VPS (173.249.18.183) had NO senlikbuddy/idate database
- Backend connected to MongoDB successfully but ALL operations failed
- Error: "Command find requires authentication"
- Users, matches, chats - everything returned empty or errored

### Root Cause
**TWO issues combined:**
1. **MongoDB authorization** was enabled on the new VPS but no user credentials were configured in `.env`
2. **Database simply did not exist** on the new VPS - it was never migrated from the old server

### Investigation
```bash
# On new VPS - check what databases exist
mongosh
show dbs
# Result: only admin, config, local - NO idate database!

# Check MongoDB config
cat /etc/mongod.conf
# security:
#   authorization: enabled    <-- Auth is ON
# net:
#   bindIp: 127.0.0.1        <-- Localhost only
```

### Solution

**Step 1: Migrate data using piped mongodump/mongorestore**
```bash
# Direct pipe from old VPS to new VPS (no intermediate file needed!)
ssh root@212.28.188.151 "mongodump --db=idate --archive" | \
  ssh root@173.249.18.183 "mongorestore --archive"
```

**Result**: 66,398 documents migrated across all collections, 0 failures.

**Step 2: Disable MongoDB auth (safe because localhost-only)**
```bash
# On new VPS
sudo nano /etc/mongod.conf
# Comment out:
# security:
#   authorization: enabled

sudo systemctl restart mongod
```

**Step 3: Fix DB_NAME in .env**
```bash
# .env had wrong database name
# WRONG:
DB_NAME=senlikbuddy

# CORRECT:
DB_NAME=idate
```

### Key Insight
The database was named `idate` (the original project codename) but the .env on the new VPS had `senlikbuddy`. This mismatch, combined with auth being enabled with no credentials, created a confusing double-failure scenario.

### Verification
```bash
# Verify migration
mongosh
use idate
db.users.countDocuments()  # 589 users
db.matches.countDocuments()  # 2,382 matches
```

### Prevention Protocol
```bash
# When migrating to a new VPS, ALWAYS:
# 1. Check if database exists: mongosh → show dbs
# 2. Verify DB_NAME in .env matches actual database name
# 3. Migrate data BEFORE starting the backend
# 4. Test with: curl http://localhost:PORT/health
```

---

## Problem 2: Cloudflare + nginx + SSL Setup for Mobile API (CRITICAL!)

### Symptoms
- Mobile app used raw IP address: `http://173.249.18.183:8580`
- Apple blocks plain HTTP in production apps (App Transport Security)
- Unprofessional URL for production mobile app
- Need HTTPS with proper domain

### Solution Architecture
```
Mobile App
    |
    v (HTTPS)
Cloudflare DNS (Proxied)
    |
    v (HTTPS - "Full" SSL mode)
nginx (port 443, SSL cert)
    |
    v (HTTP)
Node.js backend (port 8580)
```

### Step 1: Cloudflare DNS
```
Type: A
Name: mobile-api
Content: 173.249.18.183
Proxy: Proxied (orange cloud)
SSL/TLS: Full (not Flexible!)
```

### Step 2: SSL Certificate (Let's Encrypt)
```bash
# Install certbot
sudo apt install certbot python3-certbot-nginx

# Get certificate
sudo certbot certonly --nginx -d mobile-api.senlikbuddy.com
```

### Step 3: nginx Configuration
```nginx
# /etc/nginx/sites-available/mobile-api.senlikbuddy.com

# HTTP -> HTTPS redirect
server {
    listen 80;
    server_name mobile-api.senlikbuddy.com;
    return 301 https://$host$request_uri;
}

# HTTPS server
server {
    listen 443 ssl;
    server_name mobile-api.senlikbuddy.com;

    ssl_certificate /etc/letsencrypt/live/mobile-api.senlikbuddy.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/mobile-api.senlikbuddy.com/privkey.pem;

    # API proxy
    location / {
        proxy_pass http://127.0.0.1:8580;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }

    # Socket.io - SEPARATE location block with upgrade headers
    location /socket.io/ {
        proxy_pass http://127.0.0.1:8580;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### CRITICAL GOTCHA: Cloudflare "Full" SSL Mode

**First attempt FAILED** - only had HTTP listener (port 80). Cloudflare returned **403 Forbidden** because:

> When Cloudflare SSL is set to "Full" mode, it connects to your origin server via **HTTPS**. If your origin only has HTTP (port 80), Cloudflare cannot establish a secure connection and returns an error.

**Fix**: nginx MUST listen on port 443 with valid SSL certificate. Cloudflare "Full" means end-to-end HTTPS.

```
Cloudflare SSL Modes:
- Flexible: CF→Origin via HTTP (insecure, not recommended)
- Full: CF→Origin via HTTPS (cert can be self-signed)
- Full (Strict): CF→Origin via HTTPS (cert must be valid CA)
```

### Step 4: Enable and Test
```bash
sudo ln -s /etc/nginx/sites-available/mobile-api.senlikbuddy.com /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx

# Test
curl https://mobile-api.senlikbuddy.com/health
```

---

## Problem 3: EAS Build Version Sync (THREE files!)

### Symptoms
- TestFlight showed version 1.1.116 but app.json had 1.1.124
- Version bump in app.json alone did not propagate

### Root Cause
When `ios/` directory exists (prebuild/bare workflow), EAS Build reads the native `Info.plist` version, NOT `app.json`.

### Solution: Sync THREE Files
```bash
# 1. app.json
{
  "expo": {
    "version": "1.1.124"
  }
}

# 2. ios/senlikbuddy/Info.plist
<key>CFBundleShortVersionString</key>
<string>1.1.124</string>

# 3. package.json (for consistency)
{
  "version": "1.1.124"
}
```

### Automated Check Before Build
```bash
#!/bin/bash
# version-check.sh - Run before every EAS build

APP_JSON_VER=$(grep -A1 '"version"' app.json | tail -1 | tr -d ' ",' )
PLIST_VER=$(grep -A1 'CFBundleShortVersionString' ios/*/Info.plist | tail -1 | sed 's/.*<string>//' | sed 's/<\/string>//')
PKG_VER=$(grep '"version"' package.json | head -1 | sed 's/.*: "//;s/".*//')

echo "app.json:     $APP_JSON_VER"
echo "Info.plist:   $PLIST_VER"
echo "package.json: $PKG_VER"

if [ "$APP_JSON_VER" != "$PLIST_VER" ]; then
    echo "MISMATCH! app.json ($APP_JSON_VER) != Info.plist ($PLIST_VER)"
    exit 1
fi
```

### Alternative: Use expo prebuild
```bash
# After changing app.json version:
npx expo prebuild
# This regenerates ios/ directory with correct version from app.json
```

---

## Problem 4: Old References Scan (CRITICAL!)

### Symptoms
- After migrating domain from raw IP to `mobile-api.senlikbuddy.com`
- Some API calls still going to old URL
- Intermittent failures

### Found References (MISSED on first pass!)
```bash
# Scan results:
src/api/client.ts          → old production URL (http://173.249.18.183:8580)
src/hooks/useBaseUrl.ts    → old production URL (MISSED on first pass!)
ios/GoogleService-Info.plist → old bundle ID (com.landienzla → com.orcunst)
.env                       → old URL reference
```

### Prevention: Full Grep Scan Protocol
```bash
# ALWAYS run these scans when migrating URLs/domains/bundle IDs:

# Old URLs
grep -rn "173.249.18.183" --include="*.ts" --include="*.tsx" --include="*.js" --include="*.json" --include="*.plist" --include="*.env*" .

# Old domains
grep -rn "old-domain.com" --include="*.ts" --include="*.tsx" --include="*.js" --include="*.json" .

# Old bundle IDs
grep -rn "com.oldbundle" --include="*.plist" --include="*.json" --include="*.pbxproj" .

# Old project names
grep -rn "oldprojectname" --include="*.ts" --include="*.tsx" --include="*.json" .
```

### Key Lesson
**NEVER trust a single-pass scan.** After fixing the obvious files, run the scan AGAIN. The `useBaseUrl.ts` hook was missed because it was in a hooks directory that was not in the initial search scope.

### Checklist for URL/Domain Migration
1. `src/api/` - API client files
2. `src/hooks/` - Custom hooks (baseUrl, config hooks)
3. `src/config/` - Configuration files
4. `.env` / `.env.*` - Environment files
5. `app.json` / `app.config.js` - Expo config
6. `ios/*/Info.plist` - iOS native config
7. `ios/*/GoogleService-Info.plist` - Firebase config
8. `android/` - Android native config (if applicable)
9. `eas.json` - EAS build config
10. `package.json` - Homepage or repository URLs

---

## Problem 5: EAS Submit Non-Interactive Mode

### Symptoms
- `npx eas submit --non-interactive` fails
- Error about missing App Store Connect App ID

### Solution
Add `ascAppId` to `eas.json`:
```json
{
  "submit": {
    "production": {
      "ios": {
        "ascAppId": "6758661861"
      }
    }
  }
}
```

### Finding Your ascAppId
1. Go to App Store Connect: https://appstoreconnect.apple.com
2. Select your app
3. The number in the URL is your App ID: `/apps/6758661861/...`
4. Or check under "App Information" > "Apple ID"

### Full Non-Interactive Workflow
```bash
# Build (non-interactive, after initial credential setup)
npx eas build --profile production --platform ios --non-interactive

# Submit (non-interactive, with ascAppId in eas.json)
npx eas submit --platform ios --latest --non-interactive
```

---

## Problem 6: Separate API Subdomains Pattern

### Architecture
When a single VPS hosts multiple backends for the same project:

```
mobile-api.senlikbuddy.com → nginx → Node.js backend (port 8580)
api.senlikbuddy.com        → nginx → FastAPI web backend (port 8000)
senlikbuddy.com            → nginx → Next.js frontend (port 3000)
```

### nginx Configuration Pattern
```bash
# Each subdomain gets its own:
# 1. Cloudflare DNS A record (proxied)
# 2. SSL certificate (certbot)
# 3. nginx server block
# 4. Separate proxy_pass to different ports

# Generate certs
sudo certbot certonly --nginx -d mobile-api.senlikbuddy.com
sudo certbot certonly --nginx -d api.senlikbuddy.com

# Create configs
/etc/nginx/sites-available/mobile-api.senlikbuddy.com  # → port 8580
/etc/nginx/sites-available/api.senlikbuddy.com          # → port 8000
```

### Benefits
- Clear separation of concerns
- Independent SSL certificates
- Independent scaling
- Can point to different servers in the future
- Clean API documentation (`POST https://mobile-api.senlikbuddy.com/auth/login`)

---

## Problem 7: MongoDB Auth on Localhost - Trade-off Decision

### Context
New VPS had MongoDB auth enabled. Options:
1. Create a MongoDB user with proper credentials
2. Disable auth since MongoDB is localhost-only

### Decision: Disable Auth
```yaml
# /etc/mongod.conf
net:
  bindIp: 127.0.0.1  # ONLY localhost, not exposed to internet
# security:           # COMMENTED OUT
#   authorization: enabled
```

### Rationale
| Factor | Auth Enabled | Auth Disabled |
|--------|-------------|---------------|
| **Security** | User/pass required | Any local process can access |
| **Network Exposure** | N/A (localhost only) | N/A (localhost only) |
| **Complexity** | Connection string management | Simple `mongodb://localhost:27017/idate` |
| **Multi-app Risk** | Isolated per user | All apps see all DBs |
| **External Access** | Protected | Protected (bindIp: 127.0.0.1) |

### When Auth IS Required
- Multi-tenant VPS with untrusted applications
- MongoDB exposed to network (bindIp: 0.0.0.0)
- Compliance requirements (PCI-DSS, SOC2)
- Multiple teams accessing same server

### When Auth is Optional
- Single-tenant VPS with only your applications
- MongoDB bound to localhost (127.0.0.1)
- No compliance requirements
- Single developer/team

### Future Path
If auth is needed later:
```bash
# 1. Create user
mongosh
use idate
db.createUser({
  user: "senlikbuddy",
  pwd: "secure-password",
  roles: [{ role: "readWrite", db: "idate" }]
})

# 2. Enable auth in mongod.conf
# security:
#   authorization: enabled

# 3. Update .env
MONGODB_URI=mongodb://senlikbuddy:secure-password@localhost:27017/idate?authSource=idate

# 4. Restart
sudo systemctl restart mongod
pm2 restart senlikbuddy-mobile-backend
```

---

## Key Learnings Summary

### Deployment Checklist (Full Cycle)

#### Database Migration
- [ ] Verify database exists on target VPS (`mongosh` > `show dbs`)
- [ ] Verify DB_NAME in `.env` matches actual database name
- [ ] Migrate data: `ssh old "mongodump --db=X --archive" | ssh new "mongorestore --archive"`
- [ ] Verify document counts after migration
- [ ] Decide on MongoDB auth strategy (localhost-only = optional)

#### Domain & SSL Setup
- [ ] Create Cloudflare DNS A record (proxied)
- [ ] Set Cloudflare SSL to "Full" (not Flexible!)
- [ ] Install SSL cert with certbot
- [ ] Configure nginx with BOTH port 80 redirect AND port 443 SSL
- [ ] Add separate Socket.io location block if using WebSocket
- [ ] Test: `curl https://your-domain.com/health`

#### Mobile App URL Migration
- [ ] Update all API client files
- [ ] Update all hook files (useBaseUrl, useConfig, etc.)
- [ ] Update .env files
- [ ] Update app.json / app.config.js
- [ ] Update iOS native configs (Info.plist, GoogleService-Info.plist)
- [ ] Run full grep scan for old URLs
- [ ] Run grep scan AGAIN after first round of fixes

#### EAS Build & TestFlight
- [ ] Sync version across app.json + Info.plist + package.json
- [ ] Add `ascAppId` to eas.json for non-interactive submit
- [ ] Build: `npx eas build --profile production --platform ios`
- [ ] Submit: `npx eas submit --platform ios --latest`
- [ ] Wait 5-10 min for Apple processing
- [ ] Verify in TestFlight

---

## File Locations

### nginx Configs
- `/etc/nginx/sites-available/mobile-api.senlikbuddy.com`
- `/etc/nginx/sites-enabled/mobile-api.senlikbuddy.com` (symlink)

### SSL Certificates
- `/etc/letsencrypt/live/mobile-api.senlikbuddy.com/fullchain.pem`
- `/etc/letsencrypt/live/mobile-api.senlikbuddy.com/privkey.pem`

### MongoDB Config
- `/etc/mongod.conf`

### Backend Config
- `/usr/local/main/senlik/senlikbuddy-mobile-backend/.env`

### Frontend Config (URL references)
- `src/api/client.ts`
- `src/hooks/useBaseUrl.ts`
- `app.json`
- `.env`

---

## Related Experiences
- [EXP-0091](EXP-0091-senlikbuddy-ios-deployment-eas-testflight.md) - EAS Build & TestFlight (version sync, credentials)
- [EXP-0080](EXP-0080-senlikbuddy-vps-deployment-react-native-nodejs.md) - VPS deployment with CI/CD
- [EXP-0057](EXP-0057-vps2-mongodb-authentication-enable.md) - MongoDB authentication patterns
- [EXP-0072](EXP-0072-vps-memory-crisis-zombie-sessions-mongodb-tls.md) - MongoDB TLS issues
- [EXP-0043](EXP-0043-kiwi-roadie-testflight-backend-connectivity-fix.md) - TestFlight connectivity patterns
- [EXP-0058](EXP-0058-vps1-disk-cleanup-mongodb-logs.md) - MongoDB log management on VPS

## Tags
`mongodb-migration`, `nginx`, `cloudflare`, `ssl`, `lets-encrypt`, `eas-build`, `eas-submit`, `testflight`, `version-sync`, `domain-setup`, `vps-deployment`, `socket-io`, `reverse-proxy`, `url-migration`, `old-references`, `grep-scan`, `api-subdomain`, `mongodb-auth`, `localhost-security`, `senlikbuddy`, `react-native`, `expo`, `nodejs`, `express`, `pm2`

---

**Resolution Time**: ~3 hours across sessions
**Complexity**: High (7 distinct problems across infrastructure, database, and mobile deployment)
**Reusability**: Very High - patterns apply to ANY mobile app deployment with VPS + domain + TestFlight
**Last Updated**: 2026-02-08
