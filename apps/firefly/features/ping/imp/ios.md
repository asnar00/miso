# ping - iOS Implementation
*Swift/SwiftUI implementation of server ping feature*

## Overview

Implement periodic server connectivity checking in the iOS client app using URLSession to make HTTP requests to the server's `/api/ping` endpoint.

## Server Configuration

```swift
let serverURL = "http://192.168.1.76:8080"
```

## Implementation

### 1. Add State Variables to ContentView

```swift
@State private var backgroundColor = Color.gray
@State private var timer: Timer?
```

- `backgroundColor`: Changes based on server connectivity (turquoise = connected, gray = disconnected)
- `timer`: Periodic timer to check server status

### 2. Modify Body to Use Background Color

Replace the fixed turquoise background with the state variable:

```swift
var body: some View {
    ZStack {
        // Use state-driven background color
        backgroundColor
            .ignoresSafeArea()

        // Logo (unchanged)
        GeometryReader { geometry in
            Text("ᕦ(ツ)ᕤ")
                .font(.system(size: geometry.size.width * 0.75 * 0.25))
                .foregroundColor(.black)
                .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
    .onAppear { startPeriodicCheck() }
    .onDisappear { timer?.invalidate() }
}
```

### 3. Add Periodic Check Function

```swift
func startPeriodicCheck() {
    // Check immediately on startup
    testConnection()

    // Then check every 1 second
    timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
        testConnection()
    }
}
```

### 4. Add Connection Test Function

```swift
func testConnection() {
    guard let url = URL(string: "\(serverURL)/api/ping") else {
        backgroundColor = Color.gray
        return
    }

    URLSession.shared.dataTask(with: url) { data, response, error in
        DispatchQueue.main.async {
            if let error = error {
                // Connection failed
                backgroundColor = Color.gray
                return
            }

            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    // Connection successful - show turquoise
                    backgroundColor = Color(red: 64/255, green: 224/255, blue: 208/255)
                } else {
                    // Server returned error
                    backgroundColor = Color.gray
                }
            }
        }
    }.resume()
}
```

## Info.plist Configuration

iOS apps require permission to access non-HTTPS servers. Add to `Info.plist`:

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

Or for more security, allow only the specific server:

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSExceptionDomains</key>
    <dict>
        <key>192.168.1.76</key>
        <dict>
            <key>NSExceptionAllowsInsecureHTTPLoads</key>
            <true/>
        </dict>
    </dict>
</dict>
```

## Product Integration

**Target**: `apps/firefly/product/client/imp/ios/NoobTest/ContentView.swift`

Replace the entire ContentView struct with the implementation above.

**Target**: `apps/firefly/product/client/imp/ios/NoobTest/Info.plist`

Add the NSAppTransportSecurity configuration to allow HTTP connections to the local server.

## Behavior

- App starts with gray background
- When server is reachable, background becomes turquoise
- When server becomes unreachable, background becomes gray
- Checks connection every 1 second
- Logo remains visible at all times

## Testing

1. Start server: `ssh microserver@192.168.1.76 "cd ~/firefly-server && ./start.sh"`
2. Build and install iOS app
3. App should show turquoise background
4. Stop server: `curl -X POST http://192.168.1.76:8080/api/shutdown`
5. App background should turn gray within 1 second
6. Restart server
7. App background should turn turquoise again
