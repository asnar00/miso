# usb-deploy
*fast deployment to USB-connected iPhone for development*

USB deployment provides the fastest iteration cycle for testing on real hardware (~8-10 seconds).

## Prerequisites

1. **iPhone connected via USB**
2. **Trust this computer** (popup on iPhone)
3. **Developer Mode enabled** (Settings → Privacy & Security → Developer Mode)

## Finding Your Device

```bash
# Method 1: Using xcodebuild destinations
xcodebuild -project MyApp.xcodeproj -scheme MyApp -showdestinations 2>&1 | \
    grep "platform:iOS," | \
    grep -v "Simulator" | \
    grep -v "placeholder"
```

Example output:
```
{ platform:iOS, arch:arm64, id:00008140-0001684124A2201C, name:ashphone16 }
```

The `id` value is what you need.

## Building for Device

```bash
xcodebuild -project MyApp.xcodeproj \
    -scheme MyApp \
    -destination 'id=00008140-0001684124A2201C' \
    -allowProvisioningUpdates \
    LD="clang" \
    build
```

Key differences from simulator:
- `-destination 'id=DEVICE_ID'` instead of simulator name
- `-allowProvisioningUpdates` for automatic provisioning
- Still need `LD="clang"` for linker workaround

## Installing to Device

After building, install with `devicectl`:

```bash
xcrun devicectl device install app \
    --device 00008140-0001684124A2201C \
    /path/to/MyApp.app
```

The app path is typically:
```
~/Library/Developer/Xcode/DerivedData/MyApp-*/Build/Products/Debug-iphoneos/MyApp.app
```

## Complete Workflow

See `usb-deploy/imp/install-device.sh` for a complete, ready-to-use script that:
1. Auto-detects connected device
2. Builds for that device
3. Installs the app
4. Reports success

## Device ID Format Issue

**Important**: Different tools return different device ID formats:

- `xcrun devicectl list devices` returns format: `F05607F7-85A9-5482-9089-00E7AB8C0491` (doesn't work with xcodebuild)
- `xcodebuild -showdestinations` returns format: `00008140-0001684124A2201C` (correct for xcodebuild)

Always use `xcodebuild -showdestinations` to get the correct device ID.

## Implementation

See `usb-deploy/imp/install-device.sh` - copied from working implementation in `apps/firefly/test/imp/ios/install-device.sh`.

## Troubleshooting

### Device Shows "connecting" State

If `xcrun devicectl list devices` shows:
```
State: connecting
```

Instead of:
```
State: available (paired)
```

And builds fail with "Device is busy (Connecting to [device name])", the issue is often:

**VPN Interference**: VPN software on the Mac can interfere with USB device communication. Disable VPN and restart the iPhone to restore proper device pairing.

**Recovery Steps**:
1. Disable VPN on Mac
2. Restart iPhone
3. Reconnect USB cable
4. Trust computer when prompted on iPhone
5. Verify device shows `available (paired)` with `xcrun devicectl list devices`

The device may show "connecting" indefinitely if VPN is active during device pairing or build attempts.