# simulator
*running and controlling iOS simulators*

The iOS Simulator lets you test apps without a physical device.

## Listing Available Simulators

```bash
xcrun simctl list devices available
```

Shows all available simulators:
```
iPhone 17 Pro (C3EFC467-1302-49F1-89E9-CAD64634300F) (Shutdown)
iPad Air 11-inch (M3) (173CD802-338F-472A-853D-758B04F0BD5B) (Shutdown)
```

## Starting a Simulator

```bash
xcrun simctl boot "iPhone 17 Pro"
open -a Simulator
```

First command boots the simulator, second opens the Simulator app UI.

If already booted, the boot command returns an error (safe to ignore).

## Installing Apps

After building for simulator:
```bash
xcrun simctl install "iPhone 17 Pro" /path/to/MyApp.app
```

The app path is typically:
```
~/Library/Developer/Xcode/DerivedData/MyApp-*/Build/Products/Debug-iphonesimulator/MyApp.app
```

## Launching Apps

```bash
xcrun simctl launch "iPhone 17 Pro" com.yourname.appname
```

Returns the process ID:
```
com.yourname.appname: 12345
```

## Terminating Apps

```bash
xcrun simctl terminate "iPhone 17 Pro" com.yourname.appname
```

## Shutting Down Simulator

```bash
xcrun simctl shutdown "iPhone 17 Pro"
```

Or shutdown all:
```bash
xcrun simctl shutdown all
```

## Complete Workflow Example

```bash
# Boot simulator
xcrun simctl boot "iPhone 17 Pro" 2>/dev/null || true
open -a Simulator

# Build app
xcodebuild -project MyApp.xcodeproj \
    -scheme MyApp \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
    LD="clang" \
    build

# Install and launch
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData/MyApp-*/Build/Products/Debug-iphonesimulator/MyApp.app -type d | head -1)
xcrun simctl install "iPhone 17 Pro" "$APP_PATH"
xcrun simctl launch "iPhone 17 Pro" com.yourname.appname
```

## Implementation

See `simulator/imp/` for ready-to-use scripts.