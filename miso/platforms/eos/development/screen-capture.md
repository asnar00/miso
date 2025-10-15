# screen-capture
*mirroring Android/e/OS screen on macOS*

Screen mirroring for Android devices uses **scrcpy** (screen copy), an open-source tool that provides real-time mirroring and control over USB or WiFi.

## Installation

**Install via Homebrew:**
```bash
brew install scrcpy
```

**Install ADB if not already present:**
```bash
brew install android-platform-tools
```

## Prerequisites

1. **USB debugging enabled** on Android device
   - Settings → About Phone → tap "Build number" 7 times
   - Settings → System → Developer options → Enable "USB debugging"

2. **Device connected via USB** and authorized for debugging

## Basic Usage

**Mirror device screen:**
```bash
scrcpy
```

That's it! A window opens showing your Android device screen in real-time.

## Features

- **Low latency**: Typically 35-70ms
- **High quality**: Up to device native resolution
- **Audio support**: Audio forwarding (Android 11+)
- **Control**: Mouse and keyboard control from desktop
- **Clipboard**: Automatic clipboard sync between device and computer
- **Recording**: Built-in screen recording

## Useful Options

**Mirror at lower resolution (better performance):**
```bash
scrcpy --max-size 1024
```

**Record screen to file:**
```bash
scrcpy --record=recording.mp4
```

**Disable device control (view only):**
```bash
scrcpy --no-control
```

**Mirror and record simultaneously:**
```bash
scrcpy --record=recording.mp4
```

**Keep screen on during mirroring:**
```bash
scrcpy --stay-awake
```

## Mirror Script

Simple wrapper script:

```bash
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
scrcpy --stay-awake --turn-screen-off=false --max-size 1920
```

## Keyboard Shortcuts

While mirroring:
- **MOD+f**: Toggle fullscreen
- **MOD+r**: Rotate screen
- **MOD+g**: Resize window to 1:1 (pixel-perfect)
- **MOD+c**: Copy device clipboard to computer
- **MOD+v**: Paste computer clipboard to device
- **MOD+s**: Take screenshot

(MOD = ⌘ on macOS)

## Wireless Mirroring (Advanced)

After initial USB setup:

```bash
# Get device IP
adb shell ip route | awk '{print $9}'

# Enable TCP/IP mode
adb tcpip 5555

# Connect wirelessly (replace with device IP)
adb connect 192.168.1.123:5555

# Mirror wirelessly
scrcpy
```

## Troubleshooting

**"Device not found"**
- Check USB debugging is enabled
- Accept authorization prompt on device
- Try `adb devices` to verify connection

**"Server connection failed"**
- Restart adb: `adb kill-server && adb start-server`
- Reconnect USB cable
- Check for device authorization

**Poor performance/lag**
- Reduce resolution: `scrcpy --max-size 1024`
- Disable audio: `scrcpy --no-audio`
- Use USB 3.0 port

## e/OS Compatibility

scrcpy works perfectly with e/OS devices as it uses standard Android debugging protocols. No special configuration needed.

## Console Window with Live Logs

For development, use `android_screencap.py` which launches both scrcpy and a console window showing live filtered logs:

```bash
cd screen-capture/imp
python3 android_screencap.py
```

This provides:
- **scrcpy window**: Screen mirroring positioned at (100, 100)
- **Console window**: Live logs positioned at (800, 100) to the right
- **Log filtering**: Only shows `[APP]` prefixed logs from your app
- **File output**: Writes logs to `device-logs.txt` for Claude Code monitoring

The console window filters `adb logcat` to show only logs with `[APP]` prefix from your app's package, matching the iOS Logger behavior.

**Configuration**: Edit `PACKAGE_NAME` at the top of `android_screencap.py` to match your app.

## Screenshot Utility

Capture just the device screen from the scrcpy window:

```bash
cd screen-capture/imp
./screenshot.sh [output_filename]
```

This uses AppleScript to:
1. Find the scrcpy window
2. Bring it to front
3. Calculate the device display area (excluding title bar and chrome)
4. Capture just the device screen with `screencapture -R`

Default filename: `android_screenshot_YYYYMMDD_HHMMSS.png`

The script automatically handles window positioning and only captures the actual device display, not the window chrome.

## Implementation

Working scripts in `screen-capture/imp/`:
- `android_screencap.py` - Screen mirror + console with live logs
- `screenshot.sh` - Capture device screen from scrcpy window
- `mirror.sh` - Simple scrcpy wrapper
