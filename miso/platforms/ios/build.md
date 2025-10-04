# build
*compiling iOS apps with xcodebuild*

Building iOS apps from the command line uses `xcodebuild`, but requires specific workarounds for common issues.

## Basic Build Command

```bash
xcodebuild -project MyApp.xcodeproj \
    -scheme MyApp \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
    build
```

## Critical Issue: Homebrew Linker Conflict

**Problem**: If Homebrew's linker (`/opt/homebrew/bin/ld`) is in PATH, builds fail with:
```
ld: unknown option: -platform_version
```

**Solution**: Force xcodebuild to use clang as the linker:
```bash
xcodebuild ... LD="clang" build
```

This overrides the linker and uses clang's built-in linking, avoiding the Homebrew conflict.

## Build Destinations

### Simulator
```bash
-destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

### Physical Device (USB)
```bash
-destination 'id=DEVICE_ID'
```
Get DEVICE_ID from: `xcodebuild -project MyApp.xcodeproj -scheme MyApp -showdestinations`

### Archive (for TestFlight)
```bash
-destination 'generic/platform=iOS' \
-archivePath /tmp/MyApp.xcarchive \
archive
```

## Provisioning

For physical devices and archives, add:
```bash
-allowProvisioningUpdates
```

This allows Xcode to automatically create/update provisioning profiles.

## Common Build Configurations

**Debug (default)**: Faster builds, includes debug symbols
**Release**: Optimized, for distribution

Specify with: `-configuration Release`

## Implementation

See `build/imp/` for:
- Example build scripts
- Helper functions for detecting devices
- Build and clean utilities