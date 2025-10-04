# Logo - Android Implementation
*Jetpack Compose implementation of the nøøb logo display*

## Implementation

```kotlin
import androidx.compose.material3.Text
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp

@Composable
fun LogoDisplay() {
    Text(
        text = "ᕦ(ツ)ᕤ",
        fontSize = 72.sp,
        fontWeight = FontWeight.Bold,
        color = Color.Black
    )
}
```

## Integration

The `LogoDisplay` composable is placed in the main screen composition. Compose automatically centers it within the parent layout.

## Styling

- **Font Size**: 72sp (scale-independent pixels)
- **Font Weight**: Bold
- **Color**: Black
- **Position**: Auto-centered by parent Box/Column layout
