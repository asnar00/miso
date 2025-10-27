# background - iOS Implementation
*Visual connection indicator using background color*

## Overview

The background feature provides visual feedback about server connectivity by changing the app's background color:
- **Grey (#808080)**: Connected to server
- **Dark Red (#8B0000)**: Disconnected from server

This feature depends on the `ping` feature to determine connection status.

## Implementation

### 1. Add State Variable to ContentView

```swift
@State private var backgroundColor = Color(red: 139/255, green: 0, blue: 0)
```

Initial state is dark red (disconnected) until first successful ping.

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
        backgroundColor = Color(red: 139/255, green: 0, blue: 0)  // Disconnected - dark red
        return
    }

    URLSession.shared.dataTask(with: url) { data, response, error in
        DispatchQueue.main.async {
            if let error = error {
                backgroundColor = Color(red: 139/255, green: 0, blue: 0)  // Disconnected - dark red
                return
            }

            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200 {
                // Connected - grey background
                backgroundColor = Color(red: 128/255, green: 128/255, blue: 128/255)
            } else {
                backgroundColor = Color(red: 139/255, green: 0, blue: 0)  // Disconnected - dark red
            }
        }
    }.resume()
}
```

## Product Integration

**Primary Target**: `apps/firefly/product/client/imp/ios/NoobTest/ContentView.swift`

Integrate with the ping feature implementation. The background color is updated automatically as part of the connection testing cycle.

**Additional Targets**: All views with background colors must be updated

The following files contain background colors that need to match the connection status color scheme:

1. **PostsView.swift** (line ~26):
   ```swift
   Color(red: 128/255, green: 128/255, blue: 128/255)  // Grey for connected
       .ignoresSafeArea()
   ```

2. **SignInView.swift** (line ~24):
   ```swift
   Color(red: 139/255, green: 0, blue: 0)  // Dark red for disconnected/login
       .ignoresSafeArea()
   ```

3. **NewUserView.swift** (line ~10):
   ```swift
   Color(red: 139/255, green: 0, blue: 0)  // Dark red for disconnected/registration
       .ignoresSafeArea()
   ```

4. **NewPostView.swift** (lines ~11, ~47):
   ```swift
   .foregroundColor(Color(red: 128/255, green: 128/255, blue: 128/255))  // Grey
   // and
   Color(red: 128/255, green: 128/255, blue: 128/255)  // Grey
   ```

5. **NoobTestApp.swift** (line ~49):
   ```swift
   Color(red: 139/255, green: 0, blue: 0)  // Dark red initial state
       .ignoresSafeArea()
   ```

**Important**: Views shown when connected (PostsView, NewPostView) should use grey (128, 128, 128). Views shown when disconnected or during authentication (SignInView, NewUserView, NoobTestApp initial) should use dark red (139, 0, 0).

## Behavior

- App starts with dark red background (disconnected state)
- As soon as first ping succeeds, background turns grey
- If server becomes unreachable, background turns dark red within 1 second
- When server comes back online, background returns to grey
- Color transition is smooth (handled by SwiftUI automatically)

## Visual States

**Disconnected State (Dark Red - RGB 139, 0, 0):**
- Server unreachable
- Network error
- Server returned non-200 status

**Connected State (Grey - RGB 128, 128, 128):**
- Server responded with 200 OK
- Successful ping within last second
