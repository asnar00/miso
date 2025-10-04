# Status Background - Android Implementation
*Jetpack Compose implementation of connection status background color*

## Implementation

```kotlin
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color

@Composable
fun MainScreen() {
    var isConnected by remember { mutableStateOf(false) }

    val backgroundColor = if (isConnected) {
        Color(0xFF40E0D0) // Turquoise
    } else {
        Color.Gray
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(backgroundColor)
    ) {
        // Logo and other content here
    }
}
```

## Integration

The background color is computed based on the `isConnected` state variable (updated by the connection feature). Compose automatically recomposes the UI when the state changes.

## Colors

- **Turquoise**: `Color(0xFF40E0D0)` - #40E0D0
- **Grey**: `Color.Gray` - Material grey

## Dependencies

Requires the `isConnected` state variable from the connection feature implementation.
