#!/bin/bash
# Opens QuickTime Player with iPhone screen mirroring

# Get device UDID (the format QuickTime expects)
DEVICE_ID=$(xcrun devicectl list devices | grep -E "(available|connecting|connected)" | awk '{print $NF}' | tr -d '()')

if [ -z "$DEVICE_ID" ]; then
    echo "❌ No iPhone found"
    exit 1
fi

DEVICE_NAME=$(xcrun devicectl list devices | grep -E "(available|connecting|connected)" | awk '{print $1}')
echo "📱 Found device: $DEVICE_NAME"
echo "🪞 Opening QuickTime Player for screen mirroring..."

# Open QuickTime Player and trigger New Movie Recording
# User will need to click the dropdown next to record button and select the iPhone
open -a "QuickTime Player"

# Give QuickTime time to launch
sleep 2

# Try to trigger New Movie Recording via AppleScript
osascript <<EOF
tell application "QuickTime Player"
    activate
    new movie recording
end tell
EOF

echo ""
echo "📺 QuickTime Player opened with Movie Recording"
echo "   Click the dropdown arrow next to the record button"
echo "   Select: $DEVICE_NAME"
echo ""
echo "💡 Tip: The iPhone screen will appear in the QuickTime window"
