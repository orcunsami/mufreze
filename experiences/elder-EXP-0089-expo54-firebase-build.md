# EXP-0089: Expo SDK 54 + React Native 0.81 + Firebase Build Fix

## Problem
EAS Build fails with error:
```
include of non-modular header inside framework module 'RNFBApp'
```

## Root Cause
- Expo SDK 54 + React Native 0.81 + @react-native-firebase v22.x incompatibility
- Firebase pods need special handling with static frameworks

## Solution
Add `forceStaticLinking` to `app.json`:

```json
{
  "plugins": [
    "@react-native-firebase/app",
    "@react-native-firebase/auth",
    [
      "expo-build-properties",
      {
        "ios": {
          "useFrameworks": "static",
          "forceStaticLinking": ["RNFBApp", "RNFBAuth"]
        }
      }
    ]
  ]
}
```

Then run:
```bash
npx expo prebuild --clean --platform ios
npx eas build --profile development --platform ios
```

## Related Issues
- npm peer dependency conflicts: Add `.npmrc` with `legacy-peer-deps=true`
- Worklets version mismatch in Expo Go: Downgrade `react-native-worklets` to match native version
- CocoaPods conflicts: Run `npx expo prebuild --clean` to regenerate ios folder

## Tags
expo, firebase, react-native, ios, build, eas, sdk54, rn081

## Date
2026-02-01
