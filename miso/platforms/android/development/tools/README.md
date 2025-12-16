# Android/e/OS Development Tools

Reusable scripts for Android development workflow. Copy these to your Android app's directory and customize the configuration variables at the top of each file.

## Tools

### `install-device.sh`
**Fast USB deployment** (~2-5 seconds after initial build)

Builds and installs your app directly to a connected Android device via USB. Much faster than Play Store or manual installation.

**Configure:**
- `PACKAGE_NAME` - Your app's package name (e.g., "com.miso.noobtest")

**Usage:**
```bash
./install-device.sh
```

### `watch-logs.py`
**Real-time log streaming**

Streams logs from your Android device to console and writes them to `device-logs.txt` for monitoring. Filters to show only logs from your app package.

**Configure:**
- `PACKAGE_NAME` - Your app's package name

**Usage:**
```bash
./watch-logs.py
```

### `restart-app.sh`
**Remote app restart**

Stops and restarts your app on the connected Android device without rebuilding.

**Configure:**
- `PACKAGE_NAME` - Your app's package name

**Usage:**
```bash
./restart-app.sh
```

### `stop-app.sh`
**Remote app termination**

Stops your app using `adb shell am force-stop`. Safe to call repeatedly during debugging.

**Configure:**
- `PACKAGE_NAME` - Your app's package name

**Usage:**
```bash
./stop-app.sh
```

## Setup for a New Project

1. Copy the scripts you need to your Android app directory
2. Edit the configuration variables at the top of each script (PACKAGE_NAME)
3. Make sure scripts are executable: `chmod +x *.sh *.py`

## Typical Workflow

```bash
# Initial install
export JAVA_HOME="/opt/homebrew/opt/openjdk"
./install-device.sh

# Start log monitoring in one terminal
./watch-logs.py

# In another terminal, restart to test changes
./restart-app.sh

# Stop when done
./stop-app.sh
```

## Integration with Screen Capture

The `watch-logs.py` output (`device-logs.txt`) can be monitored by the screen capture app's console window for an integrated development view.

You can also launch the integrated screen capture + console app:
```bash
python3 android_screencap.py  # From screen-capture/imp/ directory
```

## Platform Requirements

- macOS (or Linux)
- Android SDK with ADB installed
- Java (OpenJDK) with JAVA_HOME set
- Android device with USB debugging enabled
- Device authorized for debugging

## ADB Quick Reference

```bash
# Check connected devices
adb devices

# View all logs
adb logcat

# View logs from specific package
adb logcat | grep "com.miso.noobtest"

# Clear log buffer
adb logcat -c

# Check if app is running
adb shell pidof com.miso.noobtest

# Force stop app
adb shell am force-stop com.miso.noobtest

# Start activity
adb shell am start -n com.miso.noobtest/.MainActivity
```

## Troubleshooting

**"no devices found"**
- Enable USB debugging in Developer Options
- Accept authorization prompt on device
- Try: `adb kill-server && adb start-server`

**"Unable to locate a Java Runtime"**
- Set JAVA_HOME: `export JAVA_HOME="/opt/homebrew/opt/openjdk"`

**"INSTALL_FAILED_UPDATE_INCOMPATIBLE"**
- Uninstall existing app: `adb uninstall com.miso.noobtest`
- Try installation again

See `troubleshooting.md` in the parent directory for more solutions.
