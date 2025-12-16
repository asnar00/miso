#!/bin/bash

echo "📱 Checking for connected Android device..."

ADB_PATH="/opt/homebrew/share/android-commandlinetools/platform-tools/adb"

if ! $ADB_PATH devices | grep -q "device$"; then
    echo "❌ No device connected"
    echo "   Enable USB debugging and connect device"
    exit 1
fi

DEVICE_ID=$($ADB_PATH devices | grep "device$" | awk '{print $1}' | head -1)
echo "✅ Found device: $DEVICE_ID"
echo "🪞 Opening screen mirror..."

# Launch scrcpy with optimized settings
scrcpy --stay-awake --max-size 1920
