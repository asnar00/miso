#!/bin/bash
# Restart iOS app on connected iPhone
#
# CONFIGURATION: Set your app details below

set -e

# ============================================================================
# CONFIGURE THESE: Set your app name and bundle identifier
# ============================================================================
APP_NAME="NoobTest"                    # Your Xcode project/scheme name
BUNDLE_ID="com.miso.noobtest"          # Your app's bundle identifier

# Get device ID
DEVICE_ID=$(xcodebuild -project ${APP_NAME}.xcodeproj -scheme ${APP_NAME} -showdestinations 2>&1 | \
    grep "platform:iOS," | grep -v "Simulator" | grep -v "placeholder" | \
    sed -n 's/.*id:\([^,}]*\).*/\1/p' | head -1 | tr -d ' ')

if [ -z "$DEVICE_ID" ]; then
    echo "❌ No iPhone detected"
    exit 1
fi

echo "🔄 Restarting ${APP_NAME} on device..."

# Launch app, terminating existing instance first
xcrun devicectl device process launch \
    --device "$DEVICE_ID" \
    --terminate-existing \
    --activate \
    "$BUNDLE_ID"

echo "✅ App restarted"
