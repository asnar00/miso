# Logging
*Debugging iOS apps with OSLog and Console*

iOS provides a unified logging system via OSLog that is low-overhead, privacy-aware, and integrates with system debugging tools.

## Modern iOS Logging (iOS 14+)

Apple's recommended approach uses the `Logger` API from the `OSLog` framework.

### Basic Setup

```swift
import OSLog

// Create a logger for your feature
private static let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier!,
    category: "networking"
)
```

**Subsystem**: Unique identifier for your app (typically bundle identifier)  
**Category**: Logical grouping within your app (e.g., "networking", "ui", "database")

### Adding Logs

```swift
import OSLog

class ContentView: View {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: "connection"
    )
    
    func testConnection() {
        Self.logger.debug("Attempting connection...")
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                Self.logger.error("Connection failed: \(error.localizedDescription)")
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                Self.logger.info("Response code: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 200 {
                    Self.logger.notice("Connection successful!")
                } else {
                    Self.logger.warning("Unexpected status code: \(httpResponse.statusCode)")
                }
            }
        }.resume()
    }
}
```

### Log Levels

OSLog provides five severity levels:

```swift
logger.debug("Detailed debugging information")      // Development only
logger.info("Helpful but not essential info")       // General information
logger.notice("Important information")              // Default level
logger.warning("Something might cause a failure")   // Potential issues
logger.error("Error occurred but app can recover")  // Errors
logger.fault("System-level error, unrecoverable")   // Critical failures
logger.critical("Critical error")                   // Same as fault
```

**Debug**: Only visible during development, stripped from release builds  
**Info/Notice**: Captured but may not persist  
**Warning/Error/Fault**: Always captured and persisted

## Viewing Logs

### In Xcode Console

When running from Xcode, logs appear in the debug console automatically:

```
2024-10-03 18:15:40.424 [connection] Attempting connection...
2024-10-03 18:15:40.653 [connection] Response code: 200
2024-10-03 18:15:40.653 [connection] Connection successful!
```

### Using Console.app

For deployed apps on physical devices:

1. Open **Console.app** on macOS
2. Connect your iOS device
3. Select the device in the sidebar
4. Filter by your app's subsystem or category

**Filter by subsystem**:
```
subsystem:com.miso.noobtest
```

**Filter by category**:
```
category:connection
```

**Filter by log level**:
```
subsystem:com.miso.noobtest level:error
```

### Command Line (for Simulator)

```bash
# Stream logs from simulator
xcrun simctl spawn booted log stream --predicate 'subsystem == "com.miso.noobtest"'

# Filter by category
xcrun simctl spawn booted log stream --predicate 'subsystem == "com.miso.noobtest" AND category == "connection"'

# Show only errors
xcrun simctl spawn booted log stream --predicate 'subsystem == "com.miso.noobtest" AND messageType == "error"'
```

### Command Line (for Physical Device) - Real-Time Streaming

**IMPORTANT**: macOS's built-in `log stream` does NOT support streaming from physical iOS devices. The `--device` flag does not exist. For real-time log streaming from USB-connected devices, use `pymobiledevice3`:

```bash
# Install pymobiledevice3 (newer, pure Python implementation)
pip3 install pymobiledevice3

# Stream all logs from device
pymobiledevice3 syslog live

# Filter for specific app (pipe to grep)
pymobiledevice3 syslog live | grep -i "NoobTest"

# Filter for specific messages
pymobiledevice3 syslog live | grep "ping"
```

**What logs are captured**:
- `NSLog()` messages - YES ✅
- `Logger` (OSLog) messages - PARTIAL (info/notice/warning/error/fault, but NOT debug)
- System messages about your app - YES ✅

**Why use NSLog over OSLog for streaming**:
- `NSLog()` reliably appears in `pymobiledevice3 syslog live`
- OSLog `.debug()` messages do NOT appear in syslog stream
- OSLog `.info()` and higher levels usually work
- For development/debugging, NSLog is more reliable for real-time viewing

**Alternative: Console.app** (Recommended for OSLog):
1. Open Console.app on macOS
2. Connect device via USB
3. Select device in sidebar
4. Action menu → "Include Info Messages" and "Include Debug Messages"
5. Filter by process name: "NoobTest" in search box

**Collecting logs after the fact**:
```bash
# Collect archived logs from device (requires pairing)
log collect --device --output /path/to/output.logarchive
```

### Custom Real-Time Log Viewer (Recommended)

For development with Claude Code, use the included `watch-logs.py` script which filters to show only YOUR app's log messages and writes to a file that Claude can monitor.

**Setup**:
```bash
# From your iOS app directory (e.g., apps/firefly/product/client/imp/ios/)
./watch-logs.py
```

The script:
- Streams logs from iPhone via `pymobiledevice3 syslog live`
- Filters to show ONLY messages with `[APP]` prefix (your explicit log calls)
- Displays logs in terminal with timestamps
- Writes continuously to `device-logs.txt` in the same directory

**Claude Code Integration**:

Claude can monitor your app's behavior in real-time by reading the log file:
```bash
tail -20 device-logs.txt  # View last 20 log lines
```

This enables Claude to:
- See what your app is currently doing
- Debug issues by checking recent logs
- Verify that changes are working correctly

**Log Filtering with [APP] Prefix**:

To distinguish your app's explicit log calls from framework/system messages, prefix all logs with `[APP]`:

```swift
// In Logger.swift convenience methods
func info(_ message: String) {
    osLogger.info("[APP] \(message)")  // Prefix added automatically
    log(message, level: .info)
}
```

Only messages with `[APP]` will appear in `watch-logs.py` output, filtering out thousands of system/framework log lines.

**watch-logs.py Output Format**:
```
HH:MM:SS [LEVEL] message
```

Example:
```
18:31:45 [INFO] ------------ ping
18:31:45 [DEBUG] Connection successful - status 200
18:31:46 [INFO] ------------ ping
18:31:46 [DEBUG] Connection successful - status 200
```

## Privacy and String Interpolation

By default, dynamic content is **private** for user privacy:

```swift
let username = "john.doe"
logger.info("User logged in: \(username)")
// Output: "User logged in: <private>"
```

Make data public when debugging:

```swift
logger.info("User logged in: \(username, privacy: .public)")
// Output: "User logged in: john.doe"
```

**Privacy levels**:
- `.private` - Hidden (default for dynamic values)
- `.public` - Visible in logs
- `.auto` - System decides based on context

**Best practice**: Keep sensitive data private in production, use `.public` only for debugging.

## Organizing Loggers

Create a centralized logging structure:

```swift
// LoggerExtension.swift
extension Logger {
    private static var subsystem = Bundle.main.bundleIdentifier!
    
    static let networking = Logger(subsystem: subsystem, category: "networking")
    static let ui = Logger(subsystem: subsystem, category: "ui")
    static let database = Logger(subsystem: subsystem, category: "database")
}

// Usage
Logger.networking.debug("Fetching data...")
Logger.ui.info("Button tapped")
Logger.database.error("Failed to save: \(error)")
```

## Legacy Logging Methods

### print() - Quick Debug Only
```swift
print("Debug message")  // Unstructured, not persistent
```
- Simple, immediate output to Xcode console
- Not captured by system logging
- Use only for temporary debugging

### NSLog() - Deprecated
```swift
NSLog("Message")  // Objective-C era, avoid in Swift
```
- Slower than Logger
- Uses older logging infrastructure
- Use Logger instead

## Performance Considerations

- OSLog has minimal performance overhead
- Debug logs are automatically disabled in release builds
- Messages only formatted if actually displayed
- String interpolation is lazy-evaluated

## Example: Connection Monitoring with Logging

```swift
import SwiftUI
import OSLog

struct ContentView: View {
    @State private var backgroundColor = Color.gray
    @State private var timer: Timer?
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: "connection"
    )
    
    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()
            Text("ᕦ(ツ)ᕤ").font(.system(size: 60))
        }
        .onAppear { startPeriodicCheck() }
        .onDisappear { timer?.invalidate() }
    }
    
    func startPeriodicCheck() {
        Self.logger.info("Starting periodic connection checks")
        testConnection()
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            testConnection()
        }
    }
    
    func testConnection() {
        guard let url = URL(string: "http://185.96.221.52:8080/api/ping") else {
            Self.logger.error("Invalid URL")
            return
        }
        
        Self.logger.debug("Attempting connection to \(url, privacy: .public)")
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    Self.logger.error("Connection failed: \(error.localizedDescription)")
                    backgroundColor = Color.gray
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    Self.logger.debug("Response code: \(httpResponse.statusCode)")
                    
                    if httpResponse.statusCode == 200 {
                        Self.logger.info("Connection successful")
                        backgroundColor = Color(red: 64/255, green: 224/255, blue: 208/255)
                    } else {
                        Self.logger.warning("Unexpected status: \(httpResponse.statusCode)")
                        backgroundColor = Color.gray
                    }
                }
            }
        }.resume()
    }
}
```

## Production Best Practices

- Use appropriate log levels (debug for development, error for production issues)
- Create one logger per feature/category for better filtering
- Keep sensitive data private by default
- Use structured logging with subsystems and categories
- Debug logs are automatically excluded from release builds
- Remove excessive logging that doesn't add diagnostic value

## Viewing Logs from Deployed Apps

For beta testers or production issues:

1. **TestFlight**: Logs visible in Console.app when device connected
2. **Device Logs**: Settings → Privacy → Analytics → Analytics Data
3. **Crash Logs**: Xcode → Window → Organizer → Crashes
4. **Third-party tools**: Consider services like Crashlytics or Sentry for remote logging

## Troubleshooting Real-Time Log Streaming

### idevicesyslog not showing logs (iOS 15+)

The older `idevicesyslog` from `libimobiledevice` only captures the legacy syslog API, which modern iOS apps rarely use:

```bash
# Install via Homebrew
brew install libimobiledevice

# Stream logs (old method, limited functionality)
idevicesyslog
```

**Problem**: Starting with iOS 13-15, even `NSLog()` goes through Unified Logging instead of the old syslog system. This means `idevicesyslog` shows system messages ABOUT your app, but not your app's actual log calls.

**Solution**: Use `pymobiledevice3` instead, which supports the modern Unified Logging system.

### No logs appearing in pymobiledevice3

If `pymobiledevice3 syslog live` shows nothing:

1. **Check device pairing**: Ensure your device is trusted
   ```bash
   pymobiledevice3 usbmux list
   ```

2. **Use NSLog instead of OSLog for debugging**: NSLog messages reliably appear in syslog streams
   ```swift
   NSLog("Debug message")  // Will appear in syslog
   Logger.debug("Debug")   // Will NOT appear in syslog
   Logger.info("Info")     // Should appear in syslog
   ```

3. **Verify app is running**: The app must be actively running on the device

4. **Check Console.app as alternative**: Console.app uses private Apple APIs and can see logs that command-line tools miss

### OSLog debug messages not visible

OSLog `.debug()` messages are intentionally:
- Not persisted to disk
- Not visible in release builds
- Not captured by syslog relay tools

Use `.info()` or higher levels for messages you need to see in deployed apps.

## Resources

- [Apple OSLog Documentation](https://developer.apple.com/documentation/os/logging)
- [WWDC 2020: Explore logging in Swift](https://developer.apple.com/videos/play/wwdc2020/10168/)
- [pymobiledevice3 GitHub](https://github.com/doronz88/pymobiledevice3)
- Console.app filtering syntax documentation
