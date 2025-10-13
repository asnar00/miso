# development
*tools and workflows for iOS app development and debugging*

This section covers the tools and workflows that make iOS development productive: logging, monitoring, remote control, and visual debugging.

## Topics

### [logging](development/logging.md)
Using OSLog/Logger for structured logging, viewing logs in Console.app, streaming real-time logs from USB-connected devices with `pymobiledevice3`, and filtering app-specific messages.

### [tools](development/tools/)
Ready-to-use development scripts:
- `install-device.sh` - Fast USB build and deploy
- `watch-logs.py` - Real-time log streaming to file
- `restart-app.sh` - Remote app restart
- `stop-app.sh` - Remote app termination

### [screen-capture](development/screen-capture.md)
iPhone screen mirroring app with integrated console window for viewing live logs alongside the device display.

## Typical Workflow

A productive iOS development session:

1. **Start screen capture app** to see device display + logs
2. **Deploy to device** with `./install-device.sh`
3. **Monitor in real-time** - logs appear in console window automatically
4. **Make changes** in code editor
5. **Quick rebuild** with `./install-device.sh` again (~8-10 seconds)
6. **Restart app** with `./restart-app.sh` if needed

## Key Features

**OSLog Integration**: Use `Logger` with `[APP]` prefix for filterable log messages that work with all tools.

**Real-Time Monitoring**: `watch-logs.py` streams device logs continuously to `device-logs.txt`, enabling both human viewing and Claude Code monitoring.

**Remote Control**: Start, stop, and restart apps on USB-connected devices without touching the phone.

**Visual Feedback**: Screen capture app shows device display with toggleable console window - all development state visible at once.

## Claude Code Integration

The development tools are designed to work with Claude Code:

```bash
# Claude can monitor app behavior by reading the log file
tail -20 device-logs.txt

# Or check if app is running
./stop-app.sh  # Shows "not running" if already stopped
```

This enables AI-assisted debugging where Claude can see real-time app behavior and suggest fixes.

## Setup

Copy tools to your iOS app directory:
```bash
cp development/tools/*.sh your-app-directory/
cp development/tools/*.py your-app-directory/
```

Edit configuration variables (APP_NAME, BUNDLE_ID) at the top of each file, then use them in your workflow.

See each subtopic for detailed documentation.
