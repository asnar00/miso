#!/bin/bash
# Test a feature on the iOS app via USB

FEATURE_NAME="$1"

if [ -z "$FEATURE_NAME" ]; then
    echo "Usage: ./test-feature.sh <feature-name>"
    echo "Example: ./test-feature.sh ping"
    exit 1
fi

# Check if port forwarding is already running
if ! pgrep -f "pymobiledevice3 usbmux forward 8081" > /dev/null; then
    echo "⚠️  USB port forwarding not running. Please start it first:"
    echo "   pymobiledevice3 usbmux forward 8081 8081 &"
    exit 1
fi

# Send test request
echo "🧪 Testing feature: $FEATURE_NAME"
RESULT=$(curl -s http://localhost:8081/test/$FEATURE_NAME)

if [ "$RESULT" = "succeeded" ]; then
    echo "✅ Test $FEATURE_NAME: $RESULT"
    exit 0
else
    echo "❌ Test $FEATURE_NAME: $RESULT"
    exit 1
fi
