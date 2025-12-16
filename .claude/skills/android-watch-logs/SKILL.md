---
name: eos-watch-logs
description: Start real-time log streaming from connected Android device using adb logcat. Shows only app's log messages. Use when monitoring app behavior, debugging, or viewing Android logs.
---

# Android/e/OS Watch Logs

## Overview

Streams logs from a USB-connected Android/e/OS device in real-time using `adb logcat`, filtering to show only the app's log messages. Logs are displayed in the console and written to `device-logs.txt` for monitoring and debugging.

## When to Use

Invoke this skill when the user:
- Asks to "watch Android logs"
- Wants to "see what the Android app is doing"
- Says "monitor the Android device"
- Asks to "stream logcat"
- Wants to debug or see real-time Android app behavior
- Says "show me the Android logs"

## Prerequisites

- Android device connected via USB
- USB debugging enabled
- ADB installed (`brew install android-platform-tools`)
- Device authorized for debugging
- App must be running on device to see logs

## Instructions

1. Navigate to the Android app directory:
   ```bash
   cd path/to/android/app
   ```

2. Run the watch-logs.py script:
   ```bash
   ./watch-logs.py
   ```

3. Inform the user:
   - The script will stream logs in real-time using `adb logcat`
   - Only messages from the app's package are shown (filters out system noise)
   - Logs are written to `device-logs.txt` in the same directory
   - Press Ctrl+C to stop watching
   - The log file continues to grow while the script runs

## Expected Output

```
📱 Watching logs from com.miso.noobtest...
📝 Writing to: /path/to/device-logs.txt

Streaming logs (Ctrl+C to stop):

14:23:15 [DEBUG] NoobTest: Attempting connection...
14:23:15 [DEBUG] NoobTest: Response code: 200
14:23:15 [DEBUG] NoobTest: Connection successful!
14:23:16 [DEBUG] NoobTest: Attempting connection...
```

## Log Format

Android logcat format with filtering:
- **Timestamp**: HH:MM:SS (extracted from logcat)
- **Level**: V/D/I/W/E (Verbose/Debug/Info/Warning/Error)
- **Tag**: App identifier (e.g., "NoobTest")
- **Message**: The actual log message

## How It Works

The script:
1. Runs `adb logcat` to stream all device logs
2. Filters for lines containing the app's package name
3. Extracts timestamp, level, tag, and message
4. Displays in console and writes to `device-logs.txt`

## Adding Logs in Code

Use Android's Log class in Kotlin:
```kotlin
import android.util.Log

Log.d("NoobTest", "Debug message")
Log.i("NoobTest", "Info message")
Log.w("NoobTest", "Warning message")
Log.e("NoobTest", "Error message")
```

## Integration with Claude Code

Claude can monitor your app by reading the log file:
```bash
tail -20 device-logs.txt  # View recent logs
```

This enables Claude to:
- See what the app is currently doing
- Debug issues by checking logs
- Verify that code changes are working

## Common Issues

**No logs appearing**:
- Ensure the app is running on the device
- Check that Log.d/i/w/e calls use consistent tag names
- Verify adb is working: `adb devices`
- Try clearing log buffer: `adb logcat -c` then restart app

**adb not found**:
- Install Android platform tools: `brew install android-platform-tools`
- Check PATH includes adb

**Too many logs (system noise)**:
- The script filters by package name automatically
- Adjust filter pattern in watch-logs.py if needed
- Use specific log tags for easier filtering

**Device unauthorized**:
- Check device screen for authorization prompt
- Accept RSA key on device
- Replug device and try again

## Stopping the Stream

Press Ctrl+C to stop watching logs. The script will terminate cleanly and `device-logs.txt` will remain with all captured logs.

## Alternative: Manual logcat

You can also view logs manually:
```bash
# All logs from app
adb logcat | grep "NoobTest"

# Only errors
adb logcat *:E

# Clear buffer first, then view
adb logcat -c && adb logcat | grep "NoobTest"
```

## Notes

- This runs continuously in the foreground (blocks the terminal)
- Run in a separate terminal window if you need to work while monitoring
- The log file is overwritten each time the script starts
- All Android log levels appear (unlike iOS where DEBUG is filtered)
