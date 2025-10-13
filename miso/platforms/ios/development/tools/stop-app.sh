#!/bin/bash
# Stop iOS app on connected iPhone
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

echo "🛑 Stopping ${APP_NAME} on device..."

# Find the process ID (pymobiledevice3 outputs to stderr, we need to capture it)
PID_LINE=$(pymobiledevice3 processes pgrep ${APP_NAME} 2>&1 | grep "INFO" | grep "${APP_NAME}" | head -1)

if [ -z "$PID_LINE" ]; then
    echo "⚠️  ${APP_NAME} is not running"
    exit 0
fi

# Extract PID from the output (format: "INFO 3526 AppName")
PID=$(echo "$PID_LINE" | awk '{print $(NF-1)}')

# Send SIGTERM to the process (graceful termination)
xcrun devicectl device process signal \
    --device "$DEVICE_ID" \
    --pid "$PID" \
    --signal SIGTERM

echo "✅ App stopped"
