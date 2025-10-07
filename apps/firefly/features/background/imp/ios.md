# background - iOS Implementation
*Visual connection indicator using background color*

## Overview

The background feature provides visual feedback about server connectivity by changing the app's background color:
- **Turquoise (#40E0D0)**: Connected to server
- **Gray**: Disconnected from server

This feature depends on the `ping` feature to determine connection status.

## Implementation

### 1. Add State Variable to ContentView

```swift
@State private var backgroundColor = Color.gray
```

Initial state is gray (disconnected) until first successful ping.

### 2. Update Body to Use State Background

```swift
var body: some View {
    ZStack {
        // State-driven background color
        backgroundColor
            .ignoresSafeArea()

        // Logo and other content...
    }
}
```

### 3. Update Background Based on Ping Result

In the `testConnection()` function (from ping feature), update the background color:

```swift
func testConnection() {
    guard let url = URL(string: "\(serverURL)/api/ping") else {
        backgroundColor = Color.gray  // Disconnected
        return
    }

    URLSession.shared.dataTask(with: url) { data, response, error in
        DispatchQueue.main.async {
            if let error = error {
                backgroundColor = Color.gray  // Disconnected
                return
            }

            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200 {
                // Connected - turquoise background
                backgroundColor = Color(red: 64/255, green: 224/255, blue: 208/255)
            } else {
                backgroundColor = Color.gray  // Disconnected
            }
        }
    }.resume()
}
```

## Product Integration

**Target**: `apps/firefly/product/client/imp/ios/NoobTest/ContentView.swift`

Integrate with the ping feature implementation. The background color is updated automatically as part of the connection testing cycle.

## Behavior

- App starts with gray background (disconnected state)
- As soon as first ping succeeds, background turns turquoise
- If server becomes unreachable, background turns gray within 1 second
- When server comes back online, background returns to turquoise
- Color transition is smooth (handled by SwiftUI automatically)

## Visual States

**Disconnected State (Gray):**
- Server unreachable
- Network error
- Server returned non-200 status

**Connected State (Turquoise):**
- Server responded with 200 OK
- Successful ping within last second
