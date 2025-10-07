# Firefly iOS Client

*First implementation of the firefly client app for iOS*

## Implementation

This iOS client implements the following firefly features:
- **logo** - Displays the ᕦ(ツ)ᕤ logo in black, 75% screen width
- **icon** - Uses the same logo as the app icon (50% width)
- **ping** - Periodically checks server connectivity via HTTP requests to `/api/ping`
- **background** - Visual connection indicator (turquoise = connected, gray = disconnected)

## Structure

```
ios/
├── NoobTest.xcodeproj/     # Xcode project
├── NoobTest/
│   ├── NoobTestApp.swift   # App entry point
│   ├── ContentView.swift   # Main view with logo
│   └── Assets.xcassets/    # App icon assets
├── deploy.sh               # TestFlight deployment script
└── install-device.sh       # USB device installation script
```

## Development

### Build and Deploy to USB-Connected iPhone

```bash
# Auto-detect device, build, and install
./install-device.sh
```

Or manually:

```bash
# Find device
xcodebuild -project NoobTest.xcodeproj -scheme NoobTest -showdestinations | grep "platform:iOS,"

# Build for device
xcodebuild -project NoobTest.xcodeproj \
    -scheme NoobTest \
    -destination 'id=YOUR_DEVICE_ID' \
    -allowProvisioningUpdates \
    LD="clang" \
    build

# Install
xcrun devicectl device install app \
    --device YOUR_DEVICE_ID \
    ~/Library/Developer/Xcode/DerivedData/NoobTest-*/Build/Products/Debug-iphoneos/NoobTest.app
```

### Deploy to TestFlight

```bash
./deploy.sh
```

## Implementation Notes

- Built from iOS platform template at `miso/platforms/ios/template/`
- Implements logo feature spec from `apps/firefly/features/logo.md`
- Uses turquoise color (#40E0D0) as specified in icon feature
- Logo sized at 75% of screen width using GeometryReader
- Pings server at `http://192.168.1.76:8080/api/ping` every 1 second
- Background color changes automatically based on server connectivity
- HTTP connections enabled via NSAppTransportSecurity in Info.plist

## Deployed

Successfully deployed to **ashphone16** (00008140-0001684124A2201C) via USB.
Bundle ID: `com.miso.noobtest`
