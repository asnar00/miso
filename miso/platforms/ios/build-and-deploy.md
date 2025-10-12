# build-and-deploy
*complete workflow to build and deploy iOS apps to connected iPhone*

This document describes the complete process to build and deploy an iOS app to a USB-connected iPhone.

## Prerequisites

- iPhone connected via USB
- Developer mode enabled on iPhone
- Xcode and command-line tools installed
- Trust established between Mac and iPhone

## Steps

### 1. Find Connected Device

```bash
xcodebuild -project YourApp.xcodeproj -scheme YourApp -showdestinations 2>&1 | \
    grep "platform:iOS," | \
    grep -v "Simulator" | \
    grep -v "placeholder"
```

Extract the device ID from output (format: `id=XXXXXXXX-XXXXXXXXXXXXXXXX`)

Example output:
```
{ platform:iOS, arch:arm64, id:00008140-0001684124A2201C, name:ashphone16 }
```

### 2. Build for Device

```bash
cd /path/to/project
xcodebuild -project YourApp.xcodeproj \
    -scheme YourApp \
    -destination 'id=DEVICE_ID' \
    -allowProvisioningUpdates \
    LD="clang" \
    build
```

**Critical**: Always include `LD="clang"` to avoid Homebrew linker conflicts.

### 3. Find Built App

The app is built to DerivedData:
```bash
~/Library/Developer/Xcode/DerivedData/YourApp-*/Build/Products/Debug-iphoneos/YourApp.app
```

Use wildcards to find the exact path (DerivedData includes a hash suffix).

### 4. Install to Device

```bash
xcrun devicectl device install app \
    --device DEVICE_ID \
    /path/to/YourApp.app
```

### 5. Verify Installation

Check the iPhone home screen - the app should appear with its icon.

## Complete Example Script

For the Firefly iOS client at `apps/firefly/product/client/imp/ios/`:

```bash
#!/bin/bash

cd /Users/asnaroo/Desktop/experiments/miso/apps/firefly/product/client/imp/ios

echo "📱 Finding connected iPhone..."
DEVICE_ID=$(xcodebuild -project NoobTest.xcodeproj -scheme NoobTest -showdestinations 2>&1 | \
    grep "platform:iOS," | \
    grep -v "Simulator" | \
    grep -v "placeholder" | \
    sed -n 's/.*id:\([^,]*\).*/\1/p' | \
    head -1)

if [ -z "$DEVICE_ID" ]; then
    echo "❌ No iPhone connected"
    exit 1
fi

echo "✅ Found device: $DEVICE_ID"
echo "🔨 Building app..."

xcodebuild -project NoobTest.xcodeproj \
    -scheme NoobTest \
    -destination "id=$DEVICE_ID" \
    -allowProvisioningUpdates \
    LD="clang" \
    build

if [ $? -ne 0 ]; then
    echo "❌ Build failed"
    exit 1
fi

echo "✅ Build complete"
echo "📲 Installing to device..."

APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData/NoobTest-*/Build/Products/Debug-iphoneos/NoobTest.app -type d | head -1)

xcrun devicectl device install app \
    --device "$DEVICE_ID" \
    "$APP_PATH"

if [ $? -eq 0 ]; then
    echo "✅ Deployment complete!"
else
    echo "❌ Installation failed"
    exit 1
fi
```

## Troubleshooting

**"Unable to locate a destination"**
- Ensure iPhone is connected and unlocked
- Check USB cable supports data transfer
- Verify device shows in Finder

**"ld: unknown option: -platform_version"**
- Add `LD="clang"` to xcodebuild command
- This forces use of Xcode's linker instead of Homebrew's

**"No provisioning profile found"**
- Add `-allowProvisioningUpdates` flag
- Xcode will automatically create development profile

**Build succeeds but app not found in DerivedData**
- Check the exact path with: `ls ~/Library/Developer/Xcode/DerivedData/`
- Use wildcards or `find` to locate the app

## Typical Build Time

- First build: ~5-10 seconds
- Incremental builds: ~1-2 seconds
- Installation: ~1-2 seconds

Total deployment time: **~8-10 seconds**

## Restarting App Remotely

You can restart an already-installed app from the Mac without rebuilding:

```bash
#!/bin/bash
# restart-app.sh

BUNDLE_ID="com.miso.noobtest"

# Get device ID
DEVICE_ID=$(xcodebuild -project NoobTest.xcodeproj -scheme NoobTest -showdestinations 2>&1 | \
    grep "platform:iOS," | grep -v "Simulator" | grep -v "placeholder" | \
    sed -n 's/.*id:\([^,}]*\).*/\1/p' | head -1 | tr -d ' ')

# Launch app, terminating existing instance first
xcrun devicectl device process launch \
    --device "$DEVICE_ID" \
    --terminate-existing \
    --activate \
    "$BUNDLE_ID"
```

**Useful for:**
- Testing after code changes were deployed
- Verifying app behavior on fresh launch
- Remote debugging without physically accessing the phone

**What it does:**
- Terminates any running instance of the app
- Launches the app in the foreground
- Returns immediately (doesn't wait for app to exit)

## Stopping App Remotely

You can stop a running app from the Mac without physically interacting with the phone:

```bash
#!/bin/bash
# stop-app.sh

BUNDLE_ID="com.miso.noobtest"

# Get device ID
DEVICE_ID=$(xcodebuild -project NoobTest.xcodeproj -scheme NoobTest -showdestinations 2>&1 | \
    grep "platform:iOS," | grep -v "Simulator" | grep -v "placeholder" | \
    sed -n 's/.*id:\([^,}]*\).*/\1/p' | head -1 | tr -d ' ')

# Find the process ID (pymobiledevice3 outputs to stderr)
PID_LINE=$(pymobiledevice3 processes pgrep NoobTest 2>&1 | grep "INFO" | grep "NoobTest" | head -1)

if [ -z "$PID_LINE" ]; then
    echo "⚠️  NoobTest is not running"
    exit 0
fi

# Extract PID from the output (format: "INFO 3526 NoobTest")
PID=$(echo "$PID_LINE" | awk '{print $(NF-1)}')

# Send SIGTERM to the process
xcrun devicectl device process signal \
    --device "$DEVICE_ID" \
    --pid "$PID" \
    --signal SIGTERM
```

**Useful for:**
- Stopping app to examine logs at a specific point
- Clearing app state between test runs
- Remote debugging without phone access

**What it does:**
- Finds the running process ID using `pymobiledevice3`
- Sends SIGTERM (graceful termination signal) to the process
- Allows app to clean up before exiting

**Safe for debugging:**
- SIGTERM is the standard Unix graceful termination signal
- Safe to call repeatedly during development
- Each app launch is isolated - no state corruption between runs
- iOS cleans up resources (memory, connections) after process terminates
