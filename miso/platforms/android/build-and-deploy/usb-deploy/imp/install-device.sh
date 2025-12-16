#!/bin/bash

PROJECT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
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
