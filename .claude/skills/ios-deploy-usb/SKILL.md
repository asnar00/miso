---
name: ios-deploy-usb
description: Build and deploy iOS app to connected iPhone via USB. Fast deployment (~8-10 seconds) for development iteration. Use when deploying, installing, or building apps to physical iPhone.
delegate: true
---

# iOS USB Deploy

## Overview

Builds an iOS app using xcodebuild and installs it directly to a USB-connected iPhone. This is the fastest way to test on real hardware during development, taking only 8-10 seconds vs TestFlight's longer review process.

## When to Use

Invoke this skill when the user:
- Asks to "deploy to iPhone"
- Wants to "install the app on device"
- Says "build and deploy"
- Mentions testing on physical iPhone
- Wants to "push to device"

## Prerequisites

- iPhone connected via USB
- Device trusted (user tapped "Trust This Computer" on iPhone)
- Developer Mode enabled (Settings → Privacy & Security → Developer Mode)
- Valid code signing identity configured
- The project must be in an iOS app directory with .xcodeproj

## Instructions

1. Navigate to the iOS app directory (look for .xcodeproj file):
   ```bash
   cd path/to/ios/app
   ```

2. Run the install-device.sh script:
   ```bash
   ./install-device.sh
   ```

3. The script will:
   - Auto-detect the connected iPhone
   - Build the app with xcodebuild (using LD="clang" workaround)
   - Install the .app to the device
   - Report success

4. Inform the user:
   - The build typically takes 8-10 seconds
   - The app will appear on the iPhone home screen
   - If errors occur, check that iPhone is properly connected and trusted

## Expected Output

```
📱 Installing NoobTest directly to connected device...
✅ Found device: ashphone16
   Device ID: 00008140-0001684124A2201C
🔨 Building...
✅ Build complete
📲 Installing to device...
🎉 Installation complete!
The app should now be on your iPhone's home screen.
```

## Common Issues

**No device detected**:
- Check USB connection
- Ensure "Trust This Computer" was accepted on iPhone
- Enable Developer Mode in Settings
- Try disconnecting and reconnecting

**Build fails with linker error**:
- Script uses `LD="clang"` to avoid Homebrew linker conflicts
- This is automatically handled

**VPN interference**:
- Disable VPN if device shows "connecting" state indefinitely
- Restart iPhone after disabling VPN

## Implementation Details

The script:
- Uses `xcodebuild -showdestinations` to find the device ID
- Builds with `-allowProvisioningUpdates` for automatic code signing
- Finds the built .app in DerivedData by modification time
- Uses `xcrun devicectl device install app` to deploy

## Platform-Specific Notes

This is an iOS-specific skill. For Android/e/OS deployment, use a different approach.
