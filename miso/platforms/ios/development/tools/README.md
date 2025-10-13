# iOS Development Tools

Reusable scripts for iOS development workflow. Copy these to your iOS app's directory and customize the configuration variables at the top of each file.

## Tools

### `install-device.sh`
**Fast USB deployment** (~8-10 seconds)

Builds and installs your app directly to a connected iPhone via USB. Much faster than TestFlight.

**Configure:**
- `APP_NAME` - Your Xcode project and scheme name

**Usage:**
```bash
./install-device.sh
```

### `watch-logs.py`
**Real-time log streaming**

Streams logs from your iPhone to console and writes them to `device-logs.txt` for monitoring. Only shows logs with the `[APP]` prefix (your explicit log calls).

**Requirements:**
- `pymobiledevice3` installed (`pip3 install pymobiledevice3`)

**Configure:**
- `APP_NAME` - Your Xcode project name

**Usage:**
```bash
./watch-logs.py
```

### `restart-app.sh`
**Remote app restart**

Stops and restarts your app on the connected iPhone without rebuilding.

**Configure:**
- `APP_NAME` - Your Xcode project/scheme name
- `BUNDLE_ID` - Your app's bundle identifier (e.g., "com.company.appname")

**Usage:**
```bash
./restart-app.sh
```

### `stop-app.sh`
**Remote app termination**

Stops your app cleanly using SIGTERM. Safe to call repeatedly during debugging.

**Configure:**
- `APP_NAME` - Your Xcode project/scheme name
- `BUNDLE_ID` - Your app's bundle identifier

**Usage:**
```bash
./stop-app.sh
```

## Setup for a New Project

1. Copy the scripts you need to your iOS app directory
2. Edit the configuration variables at the top of each script
3. Make sure scripts are executable: `chmod +x *.sh *.py`

## Typical Workflow

```bash
# Initial install
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

## Platform Requirements

- macOS with Xcode installed
- Python 3 with `pymobiledevice3`
- iPhone connected via USB with Developer Mode enabled
- Valid code signing identity
