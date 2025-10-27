# formatting Android/e/OS implementation

*Jetpack Compose text formatting and markdown processing*

## Text Styling Constants

```kotlin
object TextStyles {
    val Title = TextStyle(
        fontSize = 24.sp,
        fontWeight = FontWeight.Bold,
        color = Color.Black
    )

    val Summary = TextStyle(
        fontSize = 14.sp,
        fontStyle = FontStyle.Italic,
        color = Color.Black.copy(alpha = 0.8f)
    )

    val Body = MaterialTheme.typography.bodyMedium.copy(
        color = Color.Black
    )

    val Heading = TextStyle(
        fontSize = 18.sp,
        fontWeight = FontWeight.Bold,
        color = Color.Black
    )

    val Metadata = MaterialTheme.typography.bodySmall.copy(
        fontSize = 12.sp,
        color = Color.Black.copy(alpha = 0.6f)
    )
}
```

## Color Constants

```kotlin
object AppColors {
    val Background = Color(0xFF40E0D0)  // Turquoise
    val CardBackground = Color.White.copy(alpha = 0.9f)
    val TextPrimary = Color.Black
    val TextSecondary = Color.Black.copy(alpha = 0.8f)
    val TextTertiary = Color.Black.copy(alpha = 0.6f)
}
```

## Spacing and Border Constants

```kotlin
object Dimensions {
    val CardSpacing = 8.dp
    val ElementSpacing = 8.dp
    val ImagePaddingVertical = 8.dp
    val BodyBottomPadding = 8.dp
    val CardCornerRadius = 12.dp
    val ImageCornerRadius = 12.dp
    val CardElevation = 2.dp
}
```

## Markdown Text Processing

```kotlin
fun processBodyText(text: String): AnnotatedString {
    // Remove image markdown: ![alt](url)
    val pattern = "!\\[.*?\\]\\(.*?\\)".toRegex()
    val cleaned = pattern.replace(text, "")

    return buildAnnotatedString {
        val lines = cleaned.lines()

        for (line in lines) {
            val trimmed = line.trim()

            when {
                trimmed.isEmpty() -> {
                    // Empty line - add paragraph break only if we have content
                    if (length > 0) {
                        append("\n\n")
                    }
                }

                trimmed.startsWith("## ") -> {
                    // H2 heading - bold and larger
                    if (length > 0) {
                        append("\n")
                    }
                    val headingText = trimmed.substring(3)
                    withStyle(
                        style = SpanStyle(
                            fontSize = 18.sp,
                            fontWeight = FontWeight.Bold
                        )
                    ) {
                        append(headingText)
                    }
                    append("\n")
                }

                trimmed.startsWith("- ") -> {
                    // Bullet point
                    if (length > 0 && this[length - 1] != '\n') {
                        append("\n")
                    }
                    val bulletText = trimmed.substring(2)
                    append("• ")
                    append(bulletText)
                    append("\n")
                }

                else -> {
                    // Regular paragraph text
                    if (length > 0 && this[length - 1] != '\n') {
                        append(" ")  // Space-join continuation
                    }
                    append(trimmed)
                }
            }
        }
    }
}
```

## Usage in Post Views

### Title Display
```kotlin
Text(
    text = post.title,
    style = TextStyles.Title,
    maxLines = 1,
    overflow = TextOverflow.Ellipsis
)
```

### Summary Display
```kotlin
Text(
    text = post.summary,
    style = TextStyles.Summary,
    maxLines = 2,
    overflow = TextOverflow.Ellipsis
)
```

### Body Text Display
```kotlin
Text(
    text = processBodyText(post.body),
    style = TextStyles.Body
)
```

### Author/Metadata Display
```kotlin
if (post.aiGenerated) {
    Text(
        text = "👓 librarian",
        style = TextStyles.Metadata
    )
} else if (post.authorName != null) {
    Text(
        text = post.authorName,
        style = TextStyles.Metadata
    )
}
```

## Background and Card Styling

```kotlin
Scaffold(
    containerColor = AppColors.Background
) {
    LazyColumn(
        modifier = Modifier.padding(it),
        verticalArrangement = Arrangement.spacedBy(Dimensions.CardSpacing)
    ) {
        items(posts) { post ->
            Card(
                modifier = Modifier.fillMaxWidth(),
                colors = CardDefaults.cardColors(
                    containerColor = AppColors.CardBackground
                ),
                shape = RoundedCornerShape(Dimensions.CardCornerRadius),
                elevation = CardDefaults.cardElevation(
                    defaultElevation = Dimensions.CardElevation
                )
            ) {
                Column(
                    modifier = Modifier.padding(Dimensions.ElementSpacing),
                    verticalArrangement = Arrangement.spacedBy(Dimensions.ElementSpacing)
                ) {
                    // Post content
                }
            }
        }
    }
}
```

## Image Styling

```kotlin
AsyncImage(
    model = imageUrl,
    contentDescription = "Post image",
    contentScale = ContentScale.Crop,
    modifier = Modifier
        .fillMaxWidth()
        .padding(vertical = Dimensions.ImagePaddingVertical)
        .clip(RoundedCornerShape(Dimensions.ImageCornerRadius))
)
```

## Key Android-Specific Decisions

1. **Regex for markdown removal**: Use Kotlin's `.toRegex()` with escape sequences for markdown syntax
2. **AnnotatedString API**: Use `buildAnnotatedString {}` DSL for formatted text
3. **withStyle**: Apply SpanStyle for inline formatting (headings, bold)
4. **String processing**: Use `.lines()`, `.trim()`, `.startsWith()`, `.substring()`
5. **Material 3 Typography**: Leverage MaterialTheme.typography for consistent sizing
6. **Color.copy(alpha)**: Use alpha channel for opacity variations
7. **Arrangement.spacedBy**: Consistent spacing in LazyColumn
8. **CardDefaults**: Use Material 3 card styling conventions

## Required Imports

```kotlin
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.sp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.graphics.Color
import androidx.compose.material3.*
import androidx.compose.foundation.shape.RoundedCornerShape
```

## Performance Considerations

1. **Regex compilation**: Regex pattern is compiled once per function call (consider caching for frequent use)
2. **String operations**: Use efficient Kotlin string methods (`.lines()` is optimized)
3. **AnnotatedString building**: Single-pass construction avoids multiple string allocations
4. **Lazy rendering**: Text only formatted when actually displayed in view

This implementation provides identical visual results to iOS while using Android/Compose-native APIs.
