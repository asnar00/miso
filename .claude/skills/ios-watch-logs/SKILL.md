---
name: ios-watch-logs
description: Start real-time log streaming from connected iPhone to console and file. Shows only app's explicit log messages with [APP] prefix. Use when monitoring app behavior, debugging, or viewing logs.
---

# iOS Watch Logs

## Overview

Streams logs from a USB-connected iPhone in real-time, filtering to show only the app's explicit log messages (those with `[APP]` prefix). Logs are displayed in the console and written to `device-logs.txt` for monitoring and debugging.

## When to Use

Invoke this skill when the user:
- Asks to "watch logs"
- Wants to "see what the app is doing"
- Says "monitor the device"
- Asks to "stream logs from iPhone"
- Wants to debug or see real-time app behavior
- Says "show me the logs"

## Prerequisites

- iPhone connected via USB
- `pymobiledevice3` installed (`pip3 install pymobiledevice3`)
- Device must be trusted
- App must be running on the device to see logs

## Instructions

1. Navigate to the iOS app directory:
   ```bash
   cd path/to/ios/app
   ```

2. Run the watch-logs.py script:
   ```bash
   ./watch-logs.py
   ```

3. Inform the user:
   - The script will stream logs in real-time
   - Only messages with `[APP]` prefix are shown (filters out system noise)
   - Logs are written to `device-logs.txt` in the same directory
   - Press Ctrl+C to stop watching
   - The log file continues to grow while the script runs

## Expected Output

```
📱 Watching logs from NoobTest...
📝 Writing to: /path/to/device-logs.txt

Streaming logs (Ctrl+C to stop):

18:31:45 [INFO] ------------ ping
18:31:45 [DEBUG] Connection successful - status 200
18:31:46 [INFO] ------------ ping
18:31:46 [DEBUG] Connection successful - status 200
```

## Log Format

Each log line shows:
- **Timestamp**: HH:MM:SS (local time)
- **Level**: DEBUG, INFO, NOTICE, WARNING, ERROR, or FAULT
- **Message**: The actual log message

## How It Works

The script:
1. Runs `pymobiledevice3 syslog live` to stream device logs
2. Filters for lines matching the app name + `[APP]` prefix
3. Extracts timestamp, level, and message
4. Displays in console and writes to `device-logs.txt`

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
- Check that Logger.shared calls use the `[APP]` prefix
- Verify pymobiledevice3 is installed: `pip3 install pymobiledevice3`
- Device must be trusted and unlocked

**pymobiledevice3 not found**:
- Install it: `pip3 install pymobiledevice3`
- Check PATH includes Python bin directory

**Only system logs showing**:
- The app's Logger must prefix messages with `[APP]`
- This filters out thousands of framework/system messages
- Update Logger.swift to add the prefix if missing

## Stopping the Stream

Press Ctrl+C to stop watching logs. The script will terminate cleanly and `device-logs.txt` will remain with all captured logs.

## Notes

- This runs continuously in the foreground (blocks the terminal)
- Run in a separate terminal window if you need to work while monitoring
- The log file is overwritten each time the script starts
- Only OSLog messages at INFO level and above appear (DEBUG may not show)
