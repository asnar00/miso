# build-and-deploy
*complete workflow to build and deploy Android/e/OS apps to connected device*

This document describes the complete process to build and deploy an Android/e/OS app to a USB-connected device.

## Prerequisites

- Android device connected via USB
- USB debugging enabled on device
- Device authorized for debugging
- Java (OpenJDK) installed via Homebrew
- ADB (Android Debug Bridge) installed

## Critical: Set JAVA_HOME

**This is mandatory before any Gradle commands:**

```bash
export JAVA_HOME="/opt/homebrew/opt/openjdk"
```

Find your Java installation:
```bash
ls -la /opt/homebrew/opt/ | grep java
```

Without JAVA_HOME set, you'll get: `Unable to locate a Java Runtime`

## Steps

### 1. Check Connected Device

```bash
adb devices
```

Should show:
```
List of devices attached
DEVICE_ID    device
```

If device shows as "unauthorized", accept the prompt on the device.

### 2. Build Debug APK

```bash
cd /path/to/project
export JAVA_HOME="/opt/homebrew/opt/openjdk"
./gradlew assembleDebug
```

Output APK location:
```
app/build/outputs/apk/debug/app-debug.apk
```

### 3. Install to Device

```bash
adb install -r app/build/outputs/apk/debug/app-debug.apk
```

The `-r` flag replaces existing installation.

### 4. Launch App

```bash
adb shell am start -n com.package.name/.MainActivity
```

Replace `com.package.name` with your app's package name.

### 5. Verify Installation

The app should appear in the device's app launcher and launch successfully.

## Complete Example Script

For the Firefly Android client at `apps/firefly/product/client/imp/eos/`:

```bash
#!/bin/bash

cd /Users/asnaroo/Desktop/experiments/miso/apps/firefly/product/client/imp/eos

echo "📱 Checking for connected Android device..."

DEVICE_ID=$(adb devices | grep "device$" | awk '{print $1}' | head -1)

if [ -z "$DEVICE_ID" ]; then
    echo "❌ No Android device connected"
    echo "   Enable USB debugging and connect device"
    exit 1
fi

echo "✅ Found device: $DEVICE_ID"
echo "🔨 Building APK..."

export JAVA_HOME="/opt/homebrew/opt/openjdk"
./gradlew assembleDebug -q

if [ $? -ne 0 ]; then
    echo "❌ Build failed"
    exit 1
fi

echo "✅ Build complete"
echo "📲 Installing to device..."

adb install -r app/build/outputs/apk/debug/app-debug.apk

if [ $? -ne 0 ]; then
    echo "❌ Installation failed"
    exit 1
fi

echo "🚀 Launching app..."

adb shell am start -n com.miso.noobtest/.MainActivity

echo "✅ Deployment complete!"
```

## Troubleshooting

**"Unable to locate a Java Runtime"**
- Set JAVA_HOME: `export JAVA_HOME="/opt/homebrew/opt/openjdk"`
- Verify: `echo $JAVA_HOME && java -version`

**"device unauthorized"**
- Check device screen for authorization prompt
- Accept "Allow USB debugging"
- Try: `adb kill-server && adb start-server`

**"no devices found"**
- Check USB cable supports data (not just charging)
- Enable USB debugging in Developer options
- Try different USB port

**"INSTALL_FAILED_UPDATE_INCOMPATIBLE"**
- Uninstall existing app: `adb uninstall com.miso.noobtest`
- Try installation again

**Build succeeds but APK not found**
- Check path: `ls app/build/outputs/apk/debug/`
- Ensure you ran `assembleDebug` not just `build`

## Typical Build Time

- First build: ~15-20 seconds (downloads dependencies)
- Incremental builds: ~1-2 seconds
- Installation: ~1-2 seconds
- Launch: <1 second

Total deployment time: **~2-5 seconds** (after first build)

## Environment Setup

For permanent setup, add to `~/.zshrc`:

```bash
export JAVA_HOME="/opt/homebrew/opt/openjdk"
export PATH="$JAVA_HOME/bin:$PATH"
```

Then reload: `source ~/.zshrc`

## Build Variants

**Debug build** (for development):
```bash
./gradlew assembleDebug
```

**Release build** (for distribution):
```bash
./gradlew assembleRelease
```

Debug builds are signed with debug keystore automatically. Release builds require signing configuration.
