#!/bin/bash
# Restart NoobTest app on connected iPhone

set -e

BUNDLE_ID="com.miso.noobtest"

# Get device ID
DEVICE_ID=$(xcodebuild -project NoobTest.xcodeproj -scheme NoobTest -showdestinations 2>&1 | \
    grep "platform:iOS," | grep -v "Simulator" | grep -v "placeholder" | \
    sed -n 's/.*id:\([^,}]*\).*/\1/p' | head -1 | tr -d ' ')

if [ -z "$DEVICE_ID" ]; then
    echo "❌ No iPhone detected"
    exit 1
fi

echo "🔄 Restarting NoobTest on device..."

# Launch app, terminating existing instance first
xcrun devicectl device process launch \
    --device "$DEVICE_ID" \
    --terminate-existing \
    --activate \
    "$BUNDLE_ID"

echo "✅ App restarted"
