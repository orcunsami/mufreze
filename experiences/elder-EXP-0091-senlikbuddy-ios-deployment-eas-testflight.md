# EXP-0091: SenlikBuddy iOS Deployment - EAS Build & TestFlight

## Metadata
| Field | Value |
|-------|-------|
| **ID** | EXP-0091 |
| **Project** | SenlikBuddy |
| **Date** | 2026-02-04 |
| **Category** | Mobile Deployment/iOS/TestFlight |
| **Status** | SUCCESS |
| **Technologies** | React Native, Expo, EAS Build, EAS Submit, TestFlight, GitHub Actions, TypeScript, Mongoose, PM2, node-cron |

## Summary
Complete iOS deployment workflow for SenlikBuddy using EAS Build and EAS Submit to TestFlight. Documented critical version mismatch issue when `ios/` directory exists, credential setup requirements, and various TypeScript/backend fixes encountered during deployment preparation.

---

## Problem 1: EAS Build Version Mismatch (CRITICAL!)

### Symptoms
- TestFlight showed version 1.1.116
- `app.json` had version 1.1.124
- Version bump in `app.json` did not reflect in TestFlight builds

### Root Cause
When the `ios/` directory exists (prebuild/bare workflow), EAS Build uses the **NATIVE version** from `ios/senlikbuddy/Info.plist`, NOT `app.json`.

### Solution
**Always sync both files when updating version:**

```json
// app.json
{
  "expo": {
    "version": "1.1.124"
  }
}
```

```xml
<!-- ios/senlikbuddy/Info.plist -->
<key>CFBundleShortVersionString</key>
<string>1.1.124</string>
```

### Prevention Protocol
```bash
# Before every EAS build, verify version sync:
grep -A1 '"version"' app.json
grep -A1 'CFBundleShortVersionString' ios/*/Info.plist

# If mismatch, sync Info.plist to app.json version
```

---

## Problem 2: EAS Credentials Setup

### Symptoms
- `npx eas build --profile production --platform ios --non-interactive` fails
- Error: "Credentials not configured"

### Root Cause
First-time EAS builds require interactive credential setup to configure Apple certificates and provisioning profiles.

### Solution
**First-time setup requires interactive mode:**
```bash
# Initial build (interactive)
npx eas build --profile production --platform ios

# Follow prompts to:
# 1. Log in to Apple Developer account
# 2. Select/create distribution certificate
# 3. Select/create provisioning profile

# After setup, non-interactive works:
npx eas build --profile production --platform ios --non-interactive
```

### Credentials to Save (.env.credentials)
```bash
# Save these for documentation/recovery:
APPLE_ID=your@email.com
APPLE_TEAM_ID=XXXXXXXXXX
BUNDLE_ID=com.yourcompany.appname
DIST_CERT_SERIAL=XXXXXXXXXXXXXXXXXX
PROV_PROFILE_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

---

## Problem 3: EAS Submit Process

### Workflow
```bash
# Upload latest build to App Store Connect
npx eas submit --platform ios --latest
```

### Timeline
1. EAS Submit uploads IPA to App Store Connect
2. Apple processes for 5-10 minutes
3. Build appears in TestFlight under "Processing"
4. After processing, available for internal testing

### App Store Connect URL
```
https://appstoreconnect.apple.com/apps/{APP_ID}/testflight/ios
```

---

## Problem 4: GitHub Actions CI/CD - Secret Names

### Symptoms
- GitHub Action failing with authentication errors
- Jira ticket creation not working
- SSH deploy failing

### Root Cause
Secret names must match EXACTLY in workflow files:
```yaml
# WRONG
env:
  JIRA_EMAIL: ${{ secrets.JIRA_EMAIL }}  # Wrong name

# CORRECT
env:
  JIRA_USER_EMAIL: ${{ secrets.JIRA_USER_EMAIL }}  # Exact match
```

### VPS Deploy Action
```yaml
- name: Deploy to VPS
  uses: appleboy/ssh-action@v1.0.3
  with:
    host: ${{ secrets.VPS_HOST }}
    username: ${{ secrets.VPS_USER }}
    key: ${{ secrets.VPS_SSH_KEY }}
    script: |
      cd /projects/senlikbuddy-mobile-backend
      git pull origin master
      npm install
      pm2 restart senlikbuddy-mobile-backend
```

---

## Problem 5: TypeScript + Mongoose Static Methods

### Symptoms
- TypeScript errors: "Property 'findByEmail' does not exist on type 'Model<IUser>'"
- Static methods not recognized

### Root Cause
Mongoose models need separate interface for static methods.

### Solution
```typescript
// models/User.ts
import { Schema, model, Model, Document } from 'mongoose';

// Document interface
interface IUser {
  email: string;
  name: string;
}

// Document with methods
interface IUserDocument extends IUser, Document {
  // Instance methods
  comparePassword(password: string): Promise<boolean>;
}

// Model with statics
interface IUserModel extends Model<IUserDocument> {
  // Static methods
  findByEmail(email: string): Promise<IUserDocument | null>;
}

const userSchema = new Schema<IUserDocument>({
  email: { type: String, required: true },
  name: { type: String, required: true }
});

// Static method implementation
userSchema.statics.findByEmail = function(email: string) {
  return this.findOne({ email });
};

// Export with both interfaces
export const User = model<IUserDocument, IUserModel>('User', userSchema);
```

---

## Problem 6: PM2 + TypeScript

### Symptoms
- PM2 not running TypeScript properly
- Module resolution errors
- `ts-node` not found

### Solution
Use ts-node directly in PM2 command:
```bash
# Start with ts-node
pm2 start 'npx ts-node -r tsconfig-paths/register src/server.ts' --name app-name

# OR use ecosystem file
# ecosystem.config.js
module.exports = {
  apps: [{
    name: 'senlikbuddy-mobile-backend',
    script: 'npx',
    args: 'ts-node -r tsconfig-paths/register src/server.ts',
    cwd: '/projects/senlikbuddy-mobile-backend',
    env: {
      NODE_ENV: 'production'
    }
  }]
};
```

**Don't rely on package.json scripts in PM2** - they may not preserve environment correctly.

---

## Problem 7: node-cron v3+ API Changes

### Symptoms
- `scheduled: false` causing errors
- Cron jobs not starting as expected

### Root Cause
node-cron v3.0.0+ removed `scheduled` option from schedule() function.

### Solution
```typescript
// OLD (v2.x) - No longer works
const task = cron.schedule('0 * * * *', () => {
  // task
}, { scheduled: false });
task.start();

// NEW (v3.x) - Direct scheduling
const task = cron.schedule('0 * * * *', () => {
  // task
});
// Task starts automatically, use task.stop() if needed
```

---

## Key Learnings

### EAS Build/Submit Checklist
1. **Version Sync**: Check `app.json` and `ios/*/Info.plist` versions match
2. **First Build**: Use interactive mode for credential setup
3. **Subsequent Builds**: Can use `--non-interactive`
4. **Submit**: `npx eas submit --platform ios --latest`
5. **Wait**: Apple processes for 5-10 minutes before TestFlight shows build

### TypeScript Backend Checklist
1. **Mongoose Models**: Separate interfaces for document and statics
2. **PM2**: Use `ts-node` directly, not package.json scripts
3. **Dependencies**: Check for breaking changes in major versions (node-cron v3)

### GitHub Actions Checklist
1. **Secret Names**: Must match EXACTLY (case-sensitive)
2. **SSH Deploy**: Use `appleboy/ssh-action@v1.0.3`
3. **Branch Names**: Use project convention (`master` not `main`)

---

## File Locations

### Version Files
- `app.json` - Expo/JavaScript version
- `ios/senlikbuddy/Info.plist` - Native iOS version

### Build Profiles
- `eas.json` - EAS build profiles (development, preview, production)

### Credentials (DO NOT COMMIT)
- EAS stores credentials server-side
- Local reference in `.env.credentials` (gitignored)

---

## Related Experiences
- [EXP-0043](EXP-0043-kiwi-roadie-testflight-backend-connectivity-fix.md) - TestFlight connectivity
- [EXP-0080](EXP-0080-senlikbuddy-vps-deployment-react-native-nodejs.md) - VPS deployment with CI/CD

## Tags
`eas-build`, `eas-submit`, `testflight`, `ios-deployment`, `expo`, `typescript`, `mongoose`, `pm2`, `node-cron`, `github-actions`, `version-mismatch`, `credentials`, `ci-cd`, `senlikbuddy`

---

**Resolution Time**: Multiple deployment cycles
**Complexity**: Medium-High (multiple moving parts)
**Reusability**: High (applies to all Expo + EAS projects with ios/ directory)
**Last Updated**: 2026-02-04
