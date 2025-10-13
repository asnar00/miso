# development
*tools and workflows for Android/e/OS app development and debugging*

This section covers the tools and workflows that make Android development productive: logging with Logcat, monitoring, remote control, and visual debugging.

## Topics

### [logging](development/logging.md)
Using Android's Logcat system for logging, filtering by package/tag, viewing logs in real-time, and integrating with development tools.

### [screen-capture](development/screen-capture.md)
Android device screen mirroring with integrated console window for viewing live logs alongside the device display.

### [tools](development/tools/)
Ready-to-use development scripts (to be created):
- `install-device.sh` - Fast USB build and deploy
- `watch-logs.py` - Real-time log streaming to file
- `restart-app.sh` - Remote app restart
- `stop-app.sh` - Remote app termination

## Typical Workflow

A productive Android development session:

1. **Start screen capture app** to see device display + logs
2. **Deploy to device** with `./install-device.sh`
3. **Monitor in real-time** - logs appear in console window automatically
4. **Make changes** in code editor
5. **Quick rebuild** with `./install-device.sh` again (~2-5 seconds)
6. **Restart app** with `./restart-app.sh` if needed

## Key Features

**Logcat Integration**: Use Android's `Log.d()`, `Log.i()`, etc. with custom tags for filterable log messages.

**Real-Time Monitoring**: `watch-logs.py` streams device logs via `adb logcat` filtered to your app package, writing continuously to `device-logs.txt`.

**Remote Control**: Start, stop, and restart apps on USB-connected devices without touching the phone using `adb shell am` commands.

**Visual Feedback**: Screen capture app shows device display with toggleable console window - all development state visible at once.

## Claude Code Integration

The development tools are designed to work with Claude Code:

```bash
# Claude can monitor app behavior by reading the log file
tail -20 device-logs.txt

# Or check if app is running
adb shell pidof com.miso.noobtest  # Returns PID if running
```

This enables AI-assisted debugging where Claude can see real-time app behavior and suggest fixes.

## Essential ADB Commands

```bash
# View logs from your app
adb logcat -s YourTag

# View logs by package
adb logcat | grep "com.miso.noobtest"

# Clear log buffer
adb logcat -c

# Check if app is running
adb shell pidof com.miso.noobtest

# Force stop app
adb shell am force-stop com.miso.noobtest

# Restart app
adb shell am start -n com.miso.noobtest/.MainActivity
```

## Setup

Development tools will be provided in the `tools/` subdirectory with scripts that can be copied to your Android app directory and customized with your package name.

See each subtopic for detailed documentation.
