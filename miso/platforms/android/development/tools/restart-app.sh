#!/bin/bash
# Restart Android app on connected device
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

echo "🔄 Restarting ${PACKAGE_NAME} on device..."

# Force stop then start
adb shell am force-stop ${PACKAGE_NAME}
adb shell am start -n ${PACKAGE_NAME}/.MainActivity

echo "✅ App restarted"
