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

**Remote logging:**
- HTTP endpoint to receive log messages
- Batch uploads to reduce network traffic
- Queue logs when offline, send when connected
- Configurable log level for remote transmission
