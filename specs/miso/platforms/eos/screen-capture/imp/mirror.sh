#!/bin/bash

echo "📱 Checking for connected Android device..."

if ! adb devices | grep -q "device$"; then
    echo "❌ No device connected"
    echo "   Enable USB debugging and connect device"
    exit 1
fi

DEVICE_ID=$(adb devices | grep "device$" | awk '{print $1}' | head -1)
echo "✅ Found device: $DEVICE_ID"
echo "🪞 Opening screen mirror..."

# Launch scrcpy with optimized settings
scrcpy --stay-awake --max-size 1920
