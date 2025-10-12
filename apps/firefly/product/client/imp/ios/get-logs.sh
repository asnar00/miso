#!/bin/bash
# Retrieve log file from iOS device via USB

set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_NAME="NoobTest"
SCHEME="NoobTest"
BUNDLE_ID="com.miso.noobtest"

echo "📱 Retrieving logs from iOS device..."

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

echo "📦 Downloading log file from device..."

# Copy log file from device
xcrun devicectl device copy from \
    --device "$DEVICE_ID" \
    --source "Documents/app.log" \
    --destination "$PROJECT_DIR/app.log" \
    --domain-type appDataContainer \
    --domain-identifier "$BUNDLE_ID"

if [ $? -ne 0 ]; then
    echo "❌ Failed to download log file"
    echo "   Make sure the app has been run at least once"
    exit 1
fi

echo "✅ Log file retrieved: $PROJECT_DIR/app.log"
echo ""
echo "📄 Last 20 lines:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
tail -20 "$PROJECT_DIR/app.log"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "View full log: cat $PROJECT_DIR/app.log"
