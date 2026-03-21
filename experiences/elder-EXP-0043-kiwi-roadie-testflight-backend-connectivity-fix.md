# EXP-0043: TestFlight Backend Connectivity Fix ✅ CRITICAL SUCCESS

**Project**: Kiwi Roadie  
**Date**: 2025-08-09  
**Category**: Mobile Deployment/TestFlight  
**Technologies**: React Native, Expo, ngrok, TestFlight, Xcode  
**Status**: ✅ CRITICAL SUCCESS - Fully resolved connectivity issue  

## Problem Statement

TestFlight builds (16-28) were unable to connect to backend API, consistently showing "Network request failed" errors. The app worked perfectly in development mode but failed when deployed through TestFlight.

### Key Challenge
- **Scope**: Critical deployment blocker preventing production testing
- **Impact**: Complete inability to test backend integration via TestFlight
- **Timeline**: Multiple builds (16-28) all failed connectivity
- **Environment**: TestFlight production vs development disparity

## Root Cause Analysis

**Core Issue**: TestFlight apps cannot access localhost or local network IP addresses
- TestFlight apps run in production environment restrictions
- Localhost (127.0.0.1) and local IPs (192.168.x.x) are blocked
- Backend running on `localhost:8710` was inaccessible from TestFlight
- Standard development setup incompatible with TestFlight constraints

**Contributing Factors**:
1. **Environment Detection Logic**: `NODE_ENV !== 'production'` was incorrect
2. **Configuration Access**: App wasn't properly reading config in production
3. **Build Caching**: Xcode cached build numbers causing confusion
4. **Script Sandbox**: Expo scripts blocked by Xcode sandbox restrictions

## Solution Implementation

### 1. ngrok Tunnel Setup
```bash
# Terminal command
ngrok http 8710
# Result: https://c999777d524b.ngrok-free.app
```

**Why ngrok Works**:
- Provides publicly accessible HTTPS URL
- Tunnels to local backend seamlessly  
- No backend code changes required
- Perfect for development/testing scenarios

### 2. app.config.js Fix
```javascript
// File: /Users/mac/Documents/freelance/nomadbuddy/mobile/app.config.js

// CRITICAL FIX: Changed environment detection
// OLD (WRONG): NODE_ENV !== 'production'  
// NEW (CORRECT): NODE_ENV === 'development'

const isDev = process.env.NODE_ENV === 'development';
const apiUrl = isDev 
  ? 'http://192.168.1.7:8710'  // Local development
  : 'https://c999777d524b.ngrok-free.app';  // TestFlight/Production

export default {
  expo: {
    // ... other config
    extra: {
      apiUrl: apiUrl,
    },
  },
};

// Added debug logging
console.log('Environment:', process.env.NODE_ENV);
console.log('Using API URL:', apiUrl);
```

### 3. App.tsx Configuration Reading
```typescript
// File: /Users/mac/Documents/freelance/nomadbuddy/mobile/App.tsx

import Constants from 'expo-constants';

// CRITICAL: Read from Constants.expoConfig.extra
const apiUrl = Constants.expoConfig?.extra?.apiUrl || 'https://c999777d524b.ngrok-free.app';

console.log('App.tsx - API URL:', apiUrl);

// Configure API client with correct URL
```

### 4. Xcode Build Fix
```bash
# File: /Users/mac/Documents/freelance/nomadbuddy/mobile/open-archive.sh

# CRITICAL: Disable user script sandboxing
xcodebuild \
  -workspace ios/KiwiRoadie.xcworkspace \
  -scheme KiwiRoadie \
  -configuration Release \
  -destination generic/platform=iOS \
  -archivePath ./build/KiwiRoadie.xcarchive \
  OTHER_CODE_SIGN_FLAGS="--keychain ~/Library/Keychains/login.keychain-db" \
  ENABLE_USER_SCRIPT_SANDBOXING=NO \  # THIS IS CRITICAL
  archive
```

## Technical Details

### Environment Detection Pattern
```javascript
// WRONG PATTERN (causes TestFlight issues)
const isDev = process.env.NODE_ENV !== 'production';

// CORRECT PATTERN (works with TestFlight)  
const isDev = process.env.NODE_ENV === 'development';
```

### Configuration Access Pattern
```typescript
// CORRECT: Read from expo constants
import Constants from 'expo-constants';
const apiUrl = Constants.expoConfig?.extra?.apiUrl;

// WRONG: Direct environment variable access in production
const apiUrl = process.env.EXPO_PUBLIC_API_URL;
```

### Build Script Pattern
```bash
# CRITICAL: Disable sandbox for Expo scripts
ENABLE_USER_SCRIPT_SANDBOXING=NO
```

## Results

**Build 29**: ✅ COMPLETE SUCCESS
- Successfully uploaded to TestFlight
- App connects to backend via ngrok tunnel
- Shows "Success" message on backend connectivity
- All API calls working properly
- No more "Network request failed" errors

**Verification Steps**:
1. ✅ TestFlight app downloads successfully
2. ✅ App launches without crashes
3. ✅ Backend connectivity test shows "Success"
4. ✅ All API endpoints accessible
5. ✅ User authentication flows working

## Key Files Modified

### Primary Configuration
- `/Users/mac/Documents/freelance/nomadbuddy/mobile/app.config.js`
- `/Users/mac/Documents/freelance/nomadbuddy/mobile/App.tsx`

### Build Tools
- `/Users/mac/Documents/freelance/nomadbuddy/mobile/open-archive.sh`
- iOS project settings (ENABLE_USER_SCRIPT_SANDBOXING=NO)

### Supporting Files
- Xcode project configuration
- Info.plist (manual build number management)

## Lessons Learned

### Critical Insights
1. **TestFlight Environment**: TestFlight != development environment - needs public URLs
2. **ngrok for Testing**: Perfect solution for development backend + TestFlight testing
3. **Environment Detection**: Be explicit with environment checks in production builds
4. **Configuration Management**: Use Expo Constants for reliable config access
5. **Build Caching**: Xcode caches aggressively - manual Info.plist updates sometimes needed
6. **Sandbox Restrictions**: Expo scripts need sandbox disabled in Xcode

### Development Workflow
1. **Local Development**: Use local IP addresses
2. **TestFlight Testing**: Always use ngrok or deployed backend  
3. **Production**: Use actual production backend URL
4. **Environment Variables**: Handle all three scenarios explicitly

### Common Pitfalls
- ❌ Assuming TestFlight = production environment  
- ❌ Using localhost/local IPs in TestFlight
- ❌ Incorrect environment detection logic
- ❌ Not reading configuration properly in builds
- ❌ Forgetting to disable Xcode script sandboxing

## Reusable Patterns

### ngrok Integration Pattern
```bash
# Start ngrok tunnel
ngrok http [LOCAL_PORT]

# Use HTTPS URL in production config
# Always use ngrok for TestFlight testing
```

### Environment Detection Pattern
```javascript
// app.config.js
const isDev = process.env.NODE_ENV === 'development';
const isTestFlight = !isDev; // Simplified approach

const apiUrl = isDev 
  ? 'http://[LOCAL_IP]:[PORT]'
  : 'https://[NGROK_URL]';

export default {
  expo: {
    extra: { apiUrl }
  }
};
```

### Configuration Reading Pattern
```typescript
// App.tsx or API client
import Constants from 'expo-constants';

const apiUrl = Constants.expoConfig?.extra?.apiUrl || 'fallback-url';
// Always provide fallback for safety
```

### Build Script Pattern
```bash
# Archive command with sandbox disabled
xcodebuild \
  -workspace ios/[PROJECT].xcworkspace \
  -scheme [SCHEME] \
  -configuration Release \
  -destination generic/platform=iOS \
  -archivePath ./build/[PROJECT].xcarchive \
  ENABLE_USER_SCRIPT_SANDBOXING=NO \
  archive
```

## Cross-Project Applications

This pattern applies to:
- **Any React Native + Expo project** using TestFlight
- **Mobile apps with custom backends** during development
- **Local development + production testing** scenarios
- **Apps requiring API connectivity** in TestFlight

### Related Technologies
- React Native + Backend API integration
- Expo managed workflow projects
- TestFlight deployment processes
- Local development environment setup

## Success Metrics

- ✅ **Deployment Success**: Build 29 uploaded successfully
- ✅ **Connectivity Test**: Backend reachability confirmed  
- ✅ **User Experience**: No network errors in TestFlight
- ✅ **Development Workflow**: Seamless local-to-TestFlight process
- ✅ **Knowledge Transfer**: Documented for future projects

## Related Experiences

- **EXP-0041**: Complete Profile Management System (same project)
- **EXP-0042**: Critical Profile System Debugging (same project)  
- **EXP-0038**: React Native build issues (different project, similar platform)

## Future Considerations

1. **Production Deployment**: Replace ngrok with actual production backend
2. **Environment Management**: Consider more sophisticated environment detection
3. **Automated Workflows**: Integrate ngrok startup with development scripts
4. **Documentation**: Create deployment checklist for TestFlight
5. **Monitoring**: Add connectivity health checks in production builds

---

**Impact**: Critical success resolving major TestFlight deployment blocker
**Confidence**: 100% - verified working solution
**Reusability**: High - applies to all React Native + TestFlight projects
**Documentation Quality**: Complete implementation and troubleshooting guide