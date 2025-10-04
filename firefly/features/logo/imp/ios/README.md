# Logo - iOS Implementation
*SwiftUI implementation of the nøøb logo display*

## Implementation

```swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        Text("ᕦ(ツ)ᕤ")
            .font(.system(size: 72, weight: .bold))
            .foregroundColor(.black)
    }
}
```

## Integration

The logo text is placed in the main `ContentView` body. SwiftUI automatically centers it within the available space.

## Styling

- **Font**: System font
- **Size**: 72 points
- **Weight**: Bold
- **Color**: Black
- **Position**: Auto-centered by parent layout
