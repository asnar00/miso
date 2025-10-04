# iOS Connection Implementation
*SwiftUI implementation of server connection monitoring*

## Implementation Overview

The iOS implementation uses SwiftUI's state management and `Timer` for periodic connection checks.

## Key Components

### State Variables
```swift
@State private var isConnected = false
@State private var timer: Timer?
```

- `isConnected`: Reactive state that tracks connection status
- `timer`: Holds reference to the Timer for cleanup

### Lifecycle Management

```swift
.onAppear {
    startPeriodicCheck()
}
.onDisappear {
    timer?.invalidate()
}
```

**View appears**: Starts the periodic check timer  
**View disappears**: Stops and cleans up the timer

### Connection Checking

#### startPeriodicCheck()
```swift
func startPeriodicCheck() {
    // Check immediately on startup
    testConnection()
    
    // Schedule recurring checks every 1 second
    timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
        testConnection()
    }
}
```

Creates a repeating timer that fires every second, triggering connection tests.

#### testConnection()
```swift
func testConnection() {
    guard let url = URL(string: "http://185.96.221.52:8080/api/ping") else { return }

    URLSession.shared.dataTask(with: url) { data, response, error in
        DispatchQueue.main.async {
            if error == nil,
               let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200 {
                // Connection successful
                isConnected = true
            } else {
                // Connection failed
                isConnected = false
            }
        }
    }.resume()
}
```

**Steps**:
1. Create URL from server endpoint string
2. Create URLSession data task (runs on background thread automatically)
3. In completion handler, switch to main thread with `DispatchQueue.main.async`
4. Check response status code
5. Update isConnected state based on success/failure

### Thread Safety

- Network call runs on URLSession's background thread
- UI updates (`isConnected` changes) happen on main thread via `DispatchQueue.main.async`
- This prevents UI blocking and ensures thread-safe state updates

## Platform Configuration

### Info.plist - App Transport Security
```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

Allows HTTP connections (iOS blocks HTTP by default, requiring HTTPS).

## Files

- **ContentView.swift**: Main view with connection monitoring logic
- **Info.plist**: App Transport Security configuration

## Testing

Deploy to device and observe:
- Connection status updates when server becomes reachable/unreachable
- Status changes reflected in UI
- Test by enabling/disabling network connectivity
