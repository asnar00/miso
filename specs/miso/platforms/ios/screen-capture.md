# screen-capture
*mirroring and recording the iPhone screen on macOS*

Screen capture allows you to mirror your iPhone's display to a macOS window in real-time, useful for development, debugging, and creating demonstrations.

## QuickTime Player Method

The simplest approach uses **QuickTime Player**, which is built into macOS:

1. Connect iPhone via USB
2. Open QuickTime Player
3. File → New Movie Recording
4. Click the dropdown arrow next to the record button
5. Select your iPhone from the camera list
6. The iPhone screen appears in a window

## Automated Script

The `mirror.sh` script automates this process:

```bash
#!/bin/bash
# Opens QuickTime Player with iPhone screen mirroring

DEVICE_ID=$(xcrun devicectl list devices | grep "available (paired)" | awk '{print $NF}' | tr -d '()')

if [ -z "$DEVICE_ID" ]; then
    echo "❌ No paired iPhone found"
    exit 1
fi

DEVICE_NAME=$(xcrun devicectl list devices | grep "available (paired)" | awk '{print $1}')
echo "📱 Found device: $DEVICE_NAME"
echo "🪞 Opening QuickTime Player for screen mirroring..."

open -a "QuickTime Player"
sleep 2

osascript <<EOF
tell application "QuickTime Player"
    activate
    new movie recording
end tell
EOF

echo "📺 QuickTime Player opened with Movie Recording"
echo "   Click the dropdown next to the record button"
echo "   Select: $DEVICE_NAME"
```

**Usage:**
```bash
cd ide/miso/platforms/ios/screen-capture/imp
./mirror.sh
```

**Note:** You still need to manually select your iPhone from the camera dropdown in QuickTime Player. This is a macOS limitation - the camera source cannot be automated via AppleScript.

## Alternative: Command-Line Screen Recording

For automated screen recording without GUI interaction, use `xcrun`:

```bash
# Start recording to a file
xcrun devicectl device screenshot --device <DEVICE_ID> screenshot.png

# For video recording (requires Xcode 15+)
xcrun xctrace record --device <DEVICE_ID> --template 'System Recording' --output recording.trace
```

However, **xcrun does not support live mirroring** - it only captures static screenshots or recordings to files.

## Limitations

- QuickTime mirroring requires manual camera source selection (cannot be fully automated)
- Command-line tools can capture/record but not mirror in real-time
- Third-party tools like Reflector or AirServer offer more automation but cost money

## Implementation

Working implementation in `screen-capture/imp/mirror.sh`
