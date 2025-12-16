#!/bin/bash
# Stop Android app on connected device
#
# CONFIGURATION: Set your app details below

set -e

# ============================================================================
# CONFIGURE THIS: Set your app package name
# ============================================================================
PACKAGE_NAME="com.miso.noobtest"  # Your app's package name

# Check for connected device
DEVICE_ID=$(adb devices | grep "device$" | awk '{print $1}' | head -1)

if [ -z "$DEVICE_ID" ]; then
    echo "❌ No Android device detected"
    exit 1
fi

echo "🛑 Stopping ${PACKAGE_NAME} on device..."

# Check if app is running
PID=$(adb shell pidof ${PACKAGE_NAME} 2>/dev/null || true)

if [ -z "$PID" ]; then
    echo "⚠️  ${PACKAGE_NAME} is not running"
    exit 0
fi

# Force stop the app
adb shell am force-stop ${PACKAGE_NAME}

echo "✅ App stopped"
