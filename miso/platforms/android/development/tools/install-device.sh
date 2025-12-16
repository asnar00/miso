#!/bin/bash
# Direct USB Device Installation Script for Android
# Use this for rapid development!
#
# CONFIGURATION: Set your app details below

set -e

# ============================================================================
# CONFIGURE THESE: Set your app/package details
# ============================================================================
PACKAGE_NAME="com.miso.noobtest"  # Your app's package name

echo "📱 Installing Android app directly to connected device..."

# Check for connected device
DEVICE_ID=$(adb devices | grep "device$" | awk '{print $1}' | head -1)

if [ -z "$DEVICE_ID" ]; then
    echo "❌ No Android device detected. Please:"
    echo "  1. Connect your device via USB"
    echo "  2. Enable USB debugging (Developer Options)"
    echo "  3. Accept authorization prompt on device"
    exit 1
fi

echo "✅ Found device: $DEVICE_ID"

# Set JAVA_HOME (required for Gradle)
export JAVA_HOME="/opt/homebrew/opt/openjdk"

# Build
echo "🔨 Building..."
./gradlew assembleDebug

echo "✅ Build complete"

# Install to device
echo "📲 Installing to device..."
adb install -r app/build/outputs/apk/debug/app-debug.apk

# Launch app
echo "🚀 Launching app..."
adb shell am start -n ${PACKAGE_NAME}/.MainActivity

echo ""
echo "🎉 Installation complete!"
echo "The app should now be running on your device."
