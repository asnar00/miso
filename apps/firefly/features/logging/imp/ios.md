# iOS Logging Implementation - Local Level

## Overview

iOS implementation provides local file logging for debugging past issues. Messages are written to a persistent file in the app's Documents directory.

## Logger Class

**File**: `apps/firefly/product/client/imp/ios/NoobTest/Logger.swift`

```swift
import Foundation

class Logger {
    static let shared = Logger()

    private let logFileURL: URL
    private let fileHandle: FileHandle?
    private let queue: DispatchQueue
}
```

### Initialization

1. Create/open log file in app's Documents directory at `Documents/app.log`
2. Create serial dispatch queue for thread-safe file writes
3. Write initialization message to log file

### Logging Methods

```swift
func debug(_ message: String)
func info(_ message: String)
func warning(_ message: String)
func error(_ message: String)
```

Each method:
1. Creates timestamp string (format: `yyyy-MM-dd HH:mm:ss.SSS`)
2. Formats message as: `[timestamp] [LEVEL] message\n`
3. Writes to file asynchronously on background queue

### File Management

```swift
func getLogContents() -> String?  // Read entire log file
func clearLog()                    // Truncate log file
```

### Thread Safety

All file writes happen on a dedicated serial queue to prevent race conditions.

## Integration with ContentView

Update `ContentView.swift` to use Logger:

```swift
import SwiftUI

struct ContentView: View {
    let logger = Logger.shared

    func testConnection() {
        logger.debug("Attempting connection to \(serverURL)")

        // ... network code ...

        if let error = error {
            logger.error("Connection failed: \(error.localizedDescription)")
            return
        }

        logger.info("Connection successful, status: \(statusCode)")
    }
}
```

## Retrieving Logs

### Command-Line Script (Recommended)

```bash
# From apps/firefly/product/client/imp/ios/
./get-logs.sh
```

This script:
1. Finds the connected iOS device
2. Downloads the app container
3. Extracts `app.log` to the current directory
4. Shows the last 20 lines

The log file will be saved as `app.log` in the ios directory.

### Alternative Methods

1. **Xcode**: Window → Devices and Simulators → Select device → Installed Apps → NoobTest → Download Container → Show Package Contents → AppData/Documents/app.log

2. **Programmatically**: Add UI in app to display/share log file contents using `Logger.shared.getLogContents()`

## Log Levels

- **debug**: Development diagnostics
- **info**: General information
- **warning**: Unexpected but handled situations
- **error**: Errors that occur but app continues

## Performance

- File writes are asynchronous on a background queue
- Date formatting is done once per Logger instance (lazy var)
- File handle stays open for efficiency
- Minimal impact on app performance

## Adding Logger to Xcode Project

The Logger.swift file must be added to the Xcode project. This can be done by:

1. Opening the project in Xcode and dragging the file into the project navigator
2. Editing project.pbxproj directly (see `miso/platforms/ios/project-editing.md`)

Required entries in project.pbxproj:
- PBXBuildFile section: link to sources
- PBXFileReference section: file metadata
- PBXGroup section: file in project navigator
- PBXSourcesBuildPhase section: compile in build

## Future Enhancements

When implementing connected and remote logging levels:
- Connected: Add OSLog output for USB streaming via `log stream --device`
- Remote: Add HTTP endpoint calls to send logs to server
