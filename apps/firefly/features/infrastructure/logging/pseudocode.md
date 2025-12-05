# logging implementation
*platform-agnostic multi-level logging system*

## Overview

A three-tier logging system that supports local file logging, real-time connected logging (via USB), and remote server logging. Initially implements local logging, with hooks for future connected and remote capabilities.

## Logger Class

A singleton class that manages log output to multiple destinations.

### Properties

- `logFileURL`: Path to persistent log file in app's documents directory
- `logFileHandle`: Open file handle for efficient writing
- `backgroundQueue`: Serial queue for thread-safe file operations
- `dateFormatter`: Reusable formatter for timestamps

### Methods

**Logging methods (by severity):**
- `debug(message)`: Development diagnostics, verbose information
- `info(message)`: General informational messages
- `warning(message)`: Unexpected but handled situations
- `error(message)`: Error conditions that don't crash the app

**File management:**
- `getLogContents() → String`: Read entire log file contents
- `clearLog() → void`: Empty/truncate the log file

## Log Message Format

Each log entry follows this format:
```
[timestamp] [LEVEL] message
```

Where:
- `timestamp`: Date and time in format `YYYY-MM-DD HH:mm:ss.SSS`
- `LEVEL`: One of DEBUG, INFO, WARNING, ERROR
- `message`: The log message string

Example:
```
[2025-10-17 14:23:45.123] [INFO] User logged in successfully
[2025-10-17 14:23:46.456] [ERROR] Network request failed: timeout
```

## Initialization

On first access (singleton pattern):
1. Get application's documents directory path
2. Create or open log file at `<documents>/app.log`
3. Create serial dispatch queue for thread-safe writes
4. Write initialization message to log file

## Logging Flow

When a logging method is called:

1. **Get timestamp**: Generate current timestamp string
2. **Format message**: Combine timestamp, level, and message
3. **Write to file**: Asynchronously write to log file on background queue
4. **(Future) Write to connected**: Send to USB-connected Mac if available
5. **(Future) Write to remote**: Send to server if connection available

## Thread Safety

All file write operations must be serialized through a single background queue to prevent:
- Race conditions from concurrent writes
- File corruption
- Data loss

## Integration

The Logger is typically accessed as a singleton:
```
Logger.getInstance().info("Something happened")
```

Or using shorthand methods if provided by platform:
```
log.info("Something happened")
```

## Retrieving Local Logs

Methods to access log file:

1. **Command-line tool**: Script to download log file from device
2. **GUI tools**: Platform-specific device management tools
3. **Programmatic**: In-app UI to display/share log contents
4. **Direct access**: File system access on development builds

## Performance Considerations

- File writes are asynchronous (non-blocking)
- Date formatter is reused (lazy initialization)
- File handle remains open (no repeated open/close)
- Serial queue ensures thread safety without locks
- Minimal impact on app performance

## Future Enhancements

**Connected logging:**
- Output to platform's native logging system (e.g., OSLog, logcat)
- Stream in real-time to development machine via USB
- Filter by log level

## Remote Logging

Remote logging uploads the device's log file to the server periodically so developers can debug issues on devices they don't have physical access to.

### Client-Side (iOS/Android)

**RemoteLogUploader class:**

Properties:
- `uploadInterval`: Time between uploads (60 seconds)
- `serverURL`: Base URL for the server
- `timer`: Repeating timer for periodic uploads
- `deviceId`: Unique identifier for this device (persisted)

Methods:
- `startPeriodicUpload()`: Start the 60-second upload timer
- `stopPeriodicUpload()`: Stop the timer
- `uploadLogs()`: Perform a single log upload

**Upload Payload (JSON):**
```
{
  "deviceId": "unique-device-identifier",
  "deviceName": "iPhone 12 mini",
  "appVersion": "1.0",
  "buildNumber": "9",
  "logs": "full contents of app.log file",
  "tunables": { "button-colour": 0.5, "font-scale": 0.9, ... }
}
```

**Device ID Generation:**
- On first launch, generate a UUID and persist it
- Use the same ID for all subsequent uploads
- Store in UserDefaults/SharedPreferences

**Upload Flow:**
1. Timer fires every 60 seconds
2. Read local log file contents
3. Get device info (name, app version, build)
4. Get current tunable values
5. POST JSON payload to `/api/debug/logs`
6. Log success/failure (but don't fail loudly - this is background diagnostic)

### Server-Side (Python/Flask)

**Endpoint:** `POST /api/debug/logs`

Receives log uploads from devices. Stores the most recent upload per device, replacing any previous upload.

**Storage:**
- In-memory dictionary keyed by deviceId
- Each entry stores: deviceName, appVersion, buildNumber, logs, tunables, timestamp

**Endpoint:** `GET /api/debug/logs`

Returns list of all devices that have uploaded logs, with metadata (no log contents).

**Endpoint:** `GET /api/debug/logs/<deviceId>`

Returns full log data for a specific device including log contents and tunables.
