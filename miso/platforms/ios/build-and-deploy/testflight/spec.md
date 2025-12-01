# testflight
*distributing iOS apps via Apple's TestFlight cloud service*

TestFlight allows distributing apps to testers without going through full App Store review. Processing takes 5-15 minutes after upload.

## Overview

The process has four steps:
1. **Archive** - Build a release version for iOS devices
2. **Export** - Package as IPA with proper signing
3. **Upload** - Send to App Store Connect
4. **Distribute** - Add testers in App Store Connect

## Step 1: Create App Record

Before first upload, create app in App Store Connect:

1. Go to https://appstoreconnect.apple.com
2. Click "My Apps" → "+" → "New App"
3. Fill in:
   - Platform: iOS
   - Name: Your app name
   - Bundle ID: Must match your app (e.g., `com.yourname.appname`)
   - SKU: Any unique identifier
4. Click "Create"

## Step 2: Archive

```bash
xcodebuild -project MyApp.xcodeproj \
    -scheme MyApp \
    -destination 'generic/platform=iOS' \
    -archivePath /tmp/MyApp.xcarchive \
    LD="clang" \
    -allowProvisioningUpdates \
    archive
```

This creates `/tmp/MyApp.xcarchive` containing:
- The compiled app
- Debug symbols (dSYMs)
- Metadata

## Step 3: Export

Create `ExportOptions.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store</string>
    <key>teamID</key>
    <string>YOUR_TEAM_ID</string>
    <key>uploadBitcode</key>
    <false/>
    <key>uploadSymbols</key>
    <true/>
    <key>signingStyle</key>
    <string>automatic</string>
</dict>
</plist>
```

Export the archive:

```bash
xcodebuild -exportArchive \
    -archivePath /tmp/MyApp.xcarchive \
    -exportPath /tmp/MyAppExport \
    -exportOptionsPlist ExportOptions.plist \
    -allowProvisioningUpdates
```

This creates `/tmp/MyAppExport/MyApp.ipa`

## Step 4: Upload

### Prerequisites
- App Store Connect API key (see `credentials.md`)
- API key `.p8` file in `~/.appstoreconnect/private_keys/`

### Upload Command

```bash
xcrun altool --upload-app \
    --type ios \
    --file /tmp/MyAppExport/MyApp.ipa \
    --apiKey YOUR_KEY_ID \
    --apiIssuer YOUR_ISSUER_ID
```

Success output:
```
UPLOAD SUCCEEDED with no errors
Delivery UUID: a219944c-289e-4361-995d-2023055b8dfd
```

## Step 5: Processing & Distribution

1. **Processing** (5-15 minutes): Apple processes the build
2. **Check Status**: App Store Connect → Your App → TestFlight → iOS Builds
3. **Add Testers**: TestFlight → Internal Testing → "+" to add yourself
4. **Install**:
   - Install TestFlight app from App Store on iPhone
   - Accept email invitation
   - Install build from TestFlight

## Automated Deployment Script

See `testflight/imp/deploy.sh` for complete automation that:
- Cleans previous builds
- Archives
- Exports
- Uploads (if API keys configured)
- Provides status and next steps

## Implementation

The `deploy.sh` script in `testflight/imp/` is copied from the working implementation in `apps/firefly/test/imp/ios/deploy.sh`.