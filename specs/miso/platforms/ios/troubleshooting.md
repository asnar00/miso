# troubleshooting
*common iOS development issues and solutions*

## Linker Errors

### Error: `ld: unknown option: -platform_version`

**Cause**: Homebrew's linker (`/opt/homebrew/bin/ld`) is being used instead of Apple's linker.

**Solution**: Add `LD="clang"` to xcodebuild command:
```bash
xcodebuild ... LD="clang" build
```

## Code Signing Issues

### Error: "No signing certificate found"

**Causes**:
1. Not logged into Xcode with Apple ID
2. Certificates not downloaded

**Solutions**:
1. Open Xcode → Settings → Accounts → Add Apple ID
2. Let Xcode download certificates automatically
3. Or use: `xcodebuild ... -allowProvisioningUpdates`

### Error: "No provisioning profile matching"

**Solution**: Add `-allowProvisioningUpdates` flag:
```bash
xcodebuild ... -allowProvisioningUpdates
```

This lets Xcode create profiles automatically.

## Network Connection Issues

### HTTP requests fail silently (app stays in error state)

**Cause**: iOS App Transport Security (ATS) blocks insecure HTTP connections by default.

**Symptoms**:
- URLSession requests to HTTP endpoints fail
- No error message visible to user
- Works fine from curl/browser on other devices

**Solution**: Add ATS exception to Info.plist:
```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

**Note**: For production apps, use more specific exceptions:
```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSExceptionDomains</key>
    <dict>
        <key>example.com</key>
        <dict>
            <key>NSExceptionAllowsInsecureHTTPLoads</key>
            <true/>
        </dict>
    </dict>
</dict>
```

## Device Connection Issues

### Device not showing up

**Check**:
1. iPhone connected via USB?
   ```bash
   system_profiler SPUSBDataType | grep iPhone
   ```
   Should show your iPhone.

2. Trusted this computer?
   - Popup appears on iPhone
   - Tap "Trust"

3. Developer Mode enabled?
   - Settings → Privacy & Security → Developer Mode
   - Toggle ON, restart iPhone if prompted

### Wrong device ID format

**Problem**: Different tools return different device ID formats:
- `xcrun devicectl list`: `F05607F7-85A9-5482-9089-00E7AB8C0491` ❌
- `xcodebuild -showdestinations`: `00008140-0001684124A2201C` ✅

**Solution**: Always get device ID from `xcodebuild -showdestinations`:
```bash
xcodebuild -project MyApp.xcodeproj -scheme MyApp -showdestinations 2>&1 | \
    grep "platform:iOS," | \
    grep -v "Simulator" | \
    grep -v "placeholder"
```

## Installation Issues

### Build succeeds but app doesn't appear on iPhone

**Cause**: `xcodebuild build` only compiles - doesn't install.

**Solution**: After building, explicitly install:
```bash
xcrun devicectl device install app \
    --device DEVICE_ID \
    /path/to/MyApp.app
```

## Icon Issues

### Icon shows as white instead of custom image

**Cause**: Assets.xcassets not included in project.pbxproj resources.

**Solution**: Ensure `Assets.xcassets` is:
1. Listed in PBXFileReference section
2. Added to PBXGroup (source files list)
3. Included in PBXResourcesBuildPhase

### Unicode characters render as boxes (□)

**Cause**: Image library doesn't support those Unicode characters.

**Solution**: Use Swift/AppKit for icon generation (see `icon-generation.md`).

## TestFlight Issues

### Error: "Cannot determine the Apple ID from Bundle ID"

**Cause**: App doesn't exist in App Store Connect yet.

**Solution**: Create app record first:
1. App Store Connect → My Apps → "+" → New App
2. Fill in Bundle ID, name, SKU
3. Then retry upload

### Error: "Failed to load AuthKey file"

**Cause**: API key `.p8` file not in expected location.

**Solution**: Move `.p8` file to:
```bash
~/.appstoreconnect/private_keys/AuthKey_*.p8
```

## Build Caching Issues

### Changes not appearing in build

**Solution**: Clean build:
```bash
xcodebuild -project MyApp.xcodeproj -scheme MyApp clean
```

Or delete DerivedData:
```bash
rm -rf ~/Library/Developer/Xcode/DerivedData/MyApp-*
```

## Simulator Issues

### Simulator won't boot

**Solution**:
```bash
# Shut down all simulators
xcrun simctl shutdown all

# Restart specific simulator
xcrun simctl boot "iPhone 17 Pro"
open -a Simulator
```

### App shows white screen in simulator

**Cause**: Usually a code issue, not simulator issue.

**Check**: Look for errors in Xcode console or run with verbose logging.