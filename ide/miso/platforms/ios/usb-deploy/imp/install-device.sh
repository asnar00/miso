#!/bin/bash

# Direct USB Device Installation Script for NoobTest
# Use this for rapid development - no TestFlight wait!

set -e

echo "📱 Installing NoobTest directly to connected device..."

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_NAME="NoobTest"
SCHEME="NoobTest"

# Get the first connected physical device
DEVICE_LINE=$(xcodebuild -project "${PROJECT_DIR}/${PROJECT_NAME}.xcodeproj" -scheme "$SCHEME" -showdestinations 2>&1 | grep "platform:iOS," | grep -v "Simulator" | grep -v "placeholder" | head -1)
DEVICE_ID=$(echo "$DEVICE_LINE" | sed -n 's/.*id:\([^,}]*\).*/\1/p' | tr -d ' ')
DEVICE_NAME=$(echo "$DEVICE_LINE" | sed -n 's/.*name:\([^}]*\).*/\1/p' | tr -d ' ')

if [ -z "$DEVICE_ID" ]; then
    echo "❌ No iPhone detected. Please:"
    echo "  1. Connect your iPhone via USB"
    echo "  2. Trust this computer on your iPhone"
    echo "  3. Enable Developer Mode (Settings → Privacy & Security → Developer Mode)"
    exit 1
fi

echo "✅ Found device: $DEVICE_NAME"
echo "   Device ID: $DEVICE_ID"

# Build
echo "🔨 Building..."
xcodebuild -project "${PROJECT_DIR}/${PROJECT_NAME}.xcodeproj" \
    -scheme "$SCHEME" \
    -destination "id=$DEVICE_ID" \
    -allowProvisioningUpdates \
    LD="clang" \
    build

echo "✅ Build complete"

# Install to device
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData/NoobTest-*/Build/Products/Debug-iphoneos/NoobTest.app -type d | head -1)

if [ -z "$APP_PATH" ]; then
    echo "❌ Could not find built app"
    exit 1
fi

echo "📲 Installing to device..."
xcrun devicectl device install app --device "$DEVICE_ID" "$APP_PATH"

echo ""
echo "🎉 Installation complete!"
echo "The app should now be on your iPhone's home screen."