#!/bin/bash
# Stop NoobTest app on connected iPhone

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

echo "🛑 Stopping NoobTest on device..."

# Find the process ID (pymobiledevice3 outputs to stderr, we need to capture it)
PID_LINE=$(pymobiledevice3 processes pgrep NoobTest 2>&1 | grep "INFO" | grep "NoobTest" | head -1)

if [ -z "$PID_LINE" ]; then
    echo "⚠️  NoobTest is not running"
    exit 0
fi

# Extract PID from the output (format: "INFO 3526 NoobTest")
PID=$(echo "$PID_LINE" | awk '{print $(NF-1)}')

# Send SIGTERM to the process
xcrun devicectl device process signal \
    --device "$DEVICE_ID" \
    --pid "$PID" \
    --signal SIGTERM

echo "✅ App stopped"
