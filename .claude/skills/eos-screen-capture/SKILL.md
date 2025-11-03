---
name: eos-screen-capture
description: Start Android screen mirroring using scrcpy. Displays device screen in real-time on Mac with optional console logs. Use when viewing Android screen, mirroring device, or monitoring app with logs.
delegate: true
---

## ⚠️ DELEGATION REQUIRED

**This skill must be executed by the instruction-follower subagent.**

When you see this skill invoked, you MUST use the Task tool to delegate it:

```
Task(
    subagent_type="instruction-follower",
    description="[Brief 3-5 word description]",
    prompt="Follow the instructions in .claude/skills/eos-screen-capture/skill.md to [complete task description]."
)
```

**DO NOT execute the instructions below directly.** The subagent will read this file and execute autonomously, then report back the results.

---


# Android/e/OS Screen Capture

## Overview

Mirrors an Android/e/OS device screen on macOS using `scrcpy` (screen copy), an open-source screen mirroring tool. Provides real-time display with low latency and optional integrated log console.

## When to Use

Invoke this skill when the user:
- Asks to "start Android screen capture"
- Wants to "see their Android screen"
- Wants to "mirror their Android device"
- Mentions viewing or displaying their Android device
- Says "show me my Android phone"

## Prerequisites

- Android device connected via USB
- **USB debugging enabled** (Settings → System → Developer options → USB debugging)
- **Developer Mode enabled** (Settings → About Phone → tap Build number 7 times)
- Device authorized for debugging
- **scrcpy installed**: `brew install scrcpy`
- **ADB installed**: `brew install android-platform-tools`

## Instructions

### Option 1: Simple Screen Mirror

1. Navigate to screen capture directory:
   ```bash
   cd miso/platforms/eos/development/screen-capture/imp
   ```

2. Run scrcpy directly:
   ```bash
   scrcpy
   ```

OR use the wrapper script:
```bash
./mirror.sh
```

### Option 2: Screen Mirror + Live Logs Console (Recommended)

For development with integrated log monitoring:

1. Navigate to screen capture directory:
   ```bash
   cd miso/platforms/eos/development/screen-capture/imp
   ```

2. Run the integrated screen capture app:
   ```bash
   python3 android_screencap.py
   ```

3. This opens TWO windows:
   - **scrcpy window**: Device screen mirroring
   - **Console window**: Live filtered logs from your app

## What to Tell the User

**For simple mirroring**:
- The scrcpy window will appear showing the device screen
- Low latency real-time mirroring (35-70ms)
- Mouse and keyboard control the device
- Close window or Ctrl+C to stop

**For integrated logs**:
- Two windows appear: screen mirror + console
- Console shows only app logs with `[APP]` prefix
- Logs written to `device-logs.txt` for Claude monitoring
- Both windows positioned automatically
- Close either window to stop

## Features

**scrcpy Features**:
- Real-time mirroring with low latency
- High quality (up to native resolution)
- Mouse and keyboard control from desktop
- Clipboard sync between device and computer
- Built-in screen recording capability

**Keyboard Shortcuts** (in scrcpy window):
- **⌘+f**: Toggle fullscreen
- **⌘+r**: Rotate screen
- **⌘+g**: Resize to 1:1 (pixel-perfect)
- **⌘+c**: Copy device clipboard to computer
- **⌘+s**: Take screenshot

## How It Works

**Simple mirror**:
- Uses `scrcpy` to establish ADB connection
- Streams device screen over USB
- Renders in desktop window

**Integrated logs**:
- Launches scrcpy for screen mirroring
- Runs `adb logcat` filtered to app package
- Shows only logs with `[APP]` prefix
- Writes to `device-logs.txt`

## Common Options

```bash
# Lower resolution for better performance
scrcpy --max-size 1024

# Record screen to file
scrcpy --record=recording.mp4

# View only (no control)
scrcpy --no-control

# Keep screen on during mirroring
scrcpy --stay-awake
```

## Common Issues

**"Device not found"**:
- Check USB debugging enabled
- Accept authorization prompt on device
- Verify with: `adb devices`
- Try: `adb kill-server && adb start-server`

**"Server connection failed"**:
- Restart ADB: `adb kill-server && adb start-server`
- Reconnect USB cable
- Check device authorization prompt

**scrcpy not installed**:
- Install it: `brew install scrcpy`
- Verify: `scrcpy --version`

**Poor performance/lag**:
- Reduce resolution: `scrcpy --max-size 1024`
- Use USB 3.0 port
- Close other apps using device

**No logs in console window**:
- Ensure app is running on device
- Check that app uses `Log.d/i/w/e` with consistent tags
- Verify logs have `[APP]` prefix (if using custom Logger)

## Taking Screenshots

To capture just the device screen:
```bash
./screenshot.sh output_filename.png
```

This captures only the device display area, excluding window chrome.

## Integration with Claude Code

The integrated logs version writes to `device-logs.txt`, allowing Claude to:
```bash
tail -20 device-logs.txt  # View recent logs
```

This enables Claude to monitor app behavior in real-time.

## e/OS Compatibility

scrcpy works perfectly with e/OS devices using standard Android debugging protocols. No special configuration needed.

## Performance

- **Latency**: 35-70ms typical
- **Resolution**: Up to device native
- **Quality**: Lossless
- **Control**: Full mouse/keyboard support

## Notes

- scrcpy runs in foreground (blocks terminal)
- Device screen stays on during mirroring
- Clipboard automatically syncs
- Can record while mirroring
- Works over WiFi too (advanced setup)
