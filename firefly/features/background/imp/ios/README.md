# Status Background - iOS Implementation
*SwiftUI implementation of connection status background color*

## Implementation

```swift
import SwiftUI

struct ContentView: View {
    @State private var isConnected = false

    var body: some View {
        ZStack {
            backgroundColor
                .ignoresSafeArea()

            // Logo and other content here
        }
    }

    private var backgroundColor: Color {
        isConnected ? Color(red: 0.25, green: 0.88, blue: 0.82) : Color.gray
    }
}
```

## Integration

The `backgroundColor` computed property observes the `isConnected` state variable (updated by the connection feature) and returns the appropriate color. SwiftUI automatically re-renders the background when the state changes.

## Colors

- **Turquoise**: `Color(red: 0.25, green: 0.88, blue: 0.82)` - #40E0D0
- **Grey**: `Color.gray` - System grey

## Dependencies

Requires the `isConnected` state variable from the connection feature implementation.
