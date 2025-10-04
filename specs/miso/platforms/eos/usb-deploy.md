# usb-deploy
*installing apps on physical Android/e/OS devices*

USB deployment allows you to install APKs directly on a physical device during development for fast iteration.

## Prerequisites

1. **ADB (Android Debug Bridge)** installed
   - Part of Android SDK Platform Tools
   - On macOS: `brew install android-platform-tools`

2. **USB Debugging enabled on device**
   - Settings → About Phone → tap "Build number" 7 times to enable Developer Mode
   - Settings → System → Developer options → Enable "USB debugging"

3. **Device connected via USB**
   - First connection prompts to accept RSA key for debugging

## Basic Commands

**Check connected devices:**
```bash
adb devices
```

Output:
```
List of devices attached
ABC123XYZ    device
```

**Install APK:**
```bash
adb install path/to/app-debug.apk
```

**Install with replace (update existing app):**
```bash
adb install -r path/to/app-debug.apk
```

**Uninstall app:**
```bash
adb uninstall com.miso.noobtest
```

**Launch app:**
```bash
adb shell am start -n com.miso.noobtest/.MainActivity
```

## Build + Install Script

Complete workflow in one command:

```bash
#!/bin/bash

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="NoobTest"
PACKAGE_NAME="com.miso.noobtest"
APK_PATH="app/build/outputs/apk/debug/app-debug.apk"

echo "📱 Installing $APP_NAME to connected device..."

# Check if device is connected
if ! adb devices | grep -q "device$"; then
    echo "❌ No device connected"
    echo "   Enable USB debugging and connect device"
    exit 1
fi

DEVICE_ID=$(adb devices | grep "device$" | awk '{print $1}' | head -1)
echo "✅ Found device: $DEVICE_ID"

# Build
echo "🔨 Building..."
cd "$PROJECT_DIR"
./gradlew assembleDebug -q

if [ $? -ne 0 ]; then
    echo "❌ Build failed"
    exit 1
fi

echo "✅ Build complete"

# Install
echo "📲 Installing..."
adb install -r "$APK_PATH"

if [ $? -eq 0 ]; then
    echo "✅ Installation complete"

    # Launch app
    echo "🚀 Launching app..."
    adb shell am start -n "$PACKAGE_NAME/.MainActivity"

    echo "🎉 App installed and launched!"
else
    echo "❌ Installation failed"
    exit 1
fi
```

## Multiple Devices

If multiple devices are connected, specify the target:

```bash
# List devices with serials
adb devices

# Install to specific device
adb -s ABC123XYZ install app-debug.apk
```

## Troubleshooting

**"device unauthorized"**
- Check device screen for RSA key prompt
- Accept the authorization

**"no devices found"**
- Check USB cable (must support data, not just charging)
- Enable USB debugging in developer options
- Try different USB port

**"INSTALL_FAILED_UPDATE_INCOMPATIBLE"**
- App signatures don't match
- Uninstall existing app first: `adb uninstall com.miso.noobtest`

**"adb: command not found"**
- Install Android platform tools: `brew install android-platform-tools`

## e/OS Specific Notes

e/OS is fully compatible with standard Android ADB commands. No special configuration needed beyond standard USB debugging.

## Implementation

Working deployment script in `usb-deploy/imp/install-device.sh`
