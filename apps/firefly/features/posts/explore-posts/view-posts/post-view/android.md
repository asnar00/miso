# post-view Android implementation

*Jetpack Compose implementation for compact/expanded post display with smooth animation and tunables*

## File Location

`apps/firefly/product/client/imp/android/app/src/main/kotlin/com/miso/noobtest/PostView.kt`

## Function Signature

```kotlin
@Composable
fun PostView(
    post: Post,
    isExpanded: Boolean,
    onTap: () -> Unit,
    isEditing: Boolean = false,
    onStartEditing: (() -> Unit)? = null,
    onEndEditing: (() -> Unit)? = null,
    onPostUpdated: ((Post) -> Unit)? = null
)
```

## Tunables Integration

```kotlin
// Observe tunables for reactivity
val tunablesVersion = TunableConstants.version.value
val fontScale = TunableConstants.getDouble("font-scale", 1.0).toFloat()
val cornerRoundness = TunableConstants.getDouble("corner-roundness", 1.0).toFloat()
val postBackgroundBrightness = TunableConstants.getDouble("post-background-brightness", 0.9).toFloat()
val authorFontSize = TunableConstants.getDouble("author-font-size", 1.0).toFloat()
val buttonColor = TunableConstants.buttonColor()
```

**Applied to:**
- Title: `fontSize = (22 * fontScale).sp`
- Summary: `fontSize = (15 * fontScale).sp`
- Body: `fontSize = (15 * fontScale).sp`, `lineHeight = (20 * fontScale).sp`
- Author/date: `fontSize = (15 * fontScale * authorFontSize).sp`
- Card corners: `RoundedCornerShape((12 * cornerRoundness).dp)`
- Card background: `Color.White.copy(alpha = postBackgroundBrightness)`
- Buttons: `background(buttonColor, ...)`

## Constants

```kotlin
val compactHeight = 110.dp  // Matches iOS
val availableWidth = 350f
val authorHeight = 15f
```

## Height Calculation

```kotlin
val expandedHeight = titleSummaryHeight + 16f + imageHeight + 16f +
                     bodyTextHeight + 24f + authorHeight + 16f
```

**Spacing breakdown (matching iOS):**
- Title/summary to image: **16dp**
- Image to body text: 16dp
- Body text to author: 24dp
- Author to bottom: **16dp**

## Image Position Interpolation

```kotlin
// Compact state (thumbnail)
val compactImageWidth = 80f
val compactImageHeight = 80f
val compactX = availableWidth - 80f - 8f  // inset 8pt from right edge (matches iOS)
val compactY = (110f - 80f) / 2f - 8f     // vertically centered in 110dp height

// Expanded state (full image)
val expandedWidth = availableWidth
val expandedImageHeight = availableWidth / imageAspectRatio
val expandedX = 10f   // 10dp indent (18dp total with box padding)
val expandedY = titleSummaryHeight + 16f

// Interpolated values using lerp()
val currentWidth = lerp(compactImageWidth, expandedWidth, animatedExpansionFactor)
val currentImageHeight = lerp(compactImageHeight, expandedImageHeight, animatedExpansionFactor)
val currentX = lerp(compactX, expandedX, animatedExpansionFactor)
val currentY = lerp(compactY, expandedY, animatedExpansionFactor)
```

## Author Bar - Always Visible with Position Interpolation

The author bar is **always visible** (not hidden in compact view), with its Y position interpolating from below title/summary to below body text:

```kotlin
// Author metadata - always visible, interpolates position
val compactAuthorY = 76f  // Below title/summary area
val expandedAuthorY = if (isMeasured) {
    currentY + currentImageHeight + 16f + bodyTextHeight + 24f
} else {
    compactAuthorY + 200f  // Fallback before measurement
}
val authorY = lerp(compactAuthorY, expandedAuthorY, animatedExpansionFactor)

Row(
    modifier = Modifier
        .offset(x = 10.dp, y = authorY.dp)
        .graphicsLayer { alpha = 1f },  // Always fully visible
    horizontalArrangement = Arrangement.spacedBy(8.dp)
) {
    val authorTextSize = (15 * fontScale * authorFontSize).sp

    if (post.aiGenerated) {
        Text(text = "librarian", fontSize = authorTextSize, ...)
    } else if (post.authorName != null) {
        // Author button only in expanded view
        if (isExpanded) {
            // Expanded: author as tappable button with background
            Box(
                modifier = Modifier
                    .background(buttonColor, RoundedCornerShape((6 * cornerRoundness).dp))
                    .clickable { Logger.info("[PostView] Author button tapped: ${post.authorName}") }
                    .padding(horizontal = 8.dp, vertical = 4.dp)
            ) {
                Text(text = post.authorName, fontSize = authorTextSize, color = Color.Black)
            }
        } else {
            // Compact: plain text
            Text(text = post.authorName, fontSize = authorTextSize, color = Color.Black.copy(alpha = 0.5f))
        }
    }

    Text(
        text = formattedDate,
        fontSize = authorTextSize,
        color = Color.Black.copy(alpha = 0.5f),
        modifier = Modifier.padding(start = 16.dp)  // Extra 16dp before date
    )
}
```

## Date Formatting

```kotlin
private fun formatDate(dateString: String): String {
    return try {
        // Try server format first: "Wed, 15 Oct 2025 14:37:09 GMT"
        val serverFormat = SimpleDateFormat("EEE, dd MMM yyyy HH:mm:ss zzz", Locale.US)
        var date = try { serverFormat.parse(dateString) } catch (e: Exception) { null }

        // Fall back to ISO format if server format fails
        if (date == null) {
            val isoFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US)
            isoFormat.timeZone = TimeZone.getTimeZone("UTC")
            date = isoFormat.parse(dateString)
        }

        // Output format: "d MMM yyyy" (matches iOS)
        val outputFormat = SimpleDateFormat("d MMM yyyy", Locale.US)
        outputFormat.format(date ?: Date())
    } catch (e: Exception) {
        dateString
    }
}
```

## Edit Mode Support

```kotlin
// State for editable fields
var editableTitle by remember { mutableStateOf(post.title) }
var editableSummary by remember { mutableStateOf(post.summary) }
var editableBody by remember { mutableStateOf(post.body) }

// Check if current user owns this post
val (currentUserEmail, _) = Storage.getLoginState()
val isOwnPost = remember(post.authorEmail, currentUserEmail) {
    currentUserEmail != null && post.authorEmail != null &&
    post.authorEmail.lowercase() == currentUserEmail.lowercase()
}

// Edit button (pencil) - only for own posts, expanded, not editing
if (isOwnPost && isExpanded && !isEditing && animatedExpansionFactor > 0.5f && isMeasured) {
    Box(
        modifier = Modifier
            .offset(x = (availableWidth - 36f - 12f).dp, y = expandedAuthorY.dp)
            .size(36.dp)
            .shadow(8.dp, CircleShape)
            .background(buttonColor, CircleShape)
            .clickable { onStartEditing?.invoke() },
        contentAlignment = Alignment.Center
    ) {
        Text(text = "pencil", fontSize = 16.sp, color = Color.Black)
    }
}

// Cancel and Save buttons (when editing)
if (isOwnPost && isExpanded && isEditing && isMeasured) {
    Row(
        modifier = Modifier.offset(x = buttonsX.dp, y = expandedAuthorY.dp),
        horizontalArrangement = Arrangement.spacedBy(20.dp)
    ) {
        // Cancel button
        Box(modifier = Modifier.size(32.dp).background(buttonColor, CircleShape).clickable {
            editableTitle = post.title
            editableSummary = post.summary
            editableBody = post.body
            onEndEditing?.invoke()
        }) { /* undo icon */ }

        // Save button
        Box(modifier = Modifier.size(32.dp).background(buttonColor, CircleShape).clickable {
            scope.launch {
                val result = PostsAPI.shared.updatePost(post.id, editableTitle, editableSummary, editableBody)
                result.fold(
                    onSuccess = { updatedPost ->
                        onPostUpdated?.invoke(updatedPost)
                        onEndEditing?.invoke()
                    },
                    onFailure = { /* handle error */ }
                )
            }
        }) { /* checkmark icon */ }
    }
}
```

## UI Automation Registration

```kotlin
// Register post for tap automation
RegisterUIElement("post-${post.id}") { onTap() }

// Register edit button
RegisterUIElement("edit-button-${post.id}") {
    Logger.info("[PostView] Edit button tapped: ${post.id}")
    onStartEditing?.invoke()
}

// Register cancel/save buttons
RegisterUIElement("cancel-button-${post.id}") { /* cancel logic */ }
RegisterUIElement("save-button-${post.id}") { /* save logic */ }
```

## Card Layout

```kotlin
Card(
    modifier = Modifier
        .fillMaxWidth()
        .height(currentHeight.dp)
        .clickable(indication = null, interactionSource = remember { MutableInteractionSource() }) { onTap() },
    colors = CardDefaults.cardColors(
        containerColor = Color.White.copy(alpha = postBackgroundBrightness)
    ),
    shape = RoundedCornerShape((12 * cornerRoundness).dp),
    elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
) {
    Box(modifier = Modifier.fillMaxSize().padding(8.dp)) {
        // Title/Summary column
        // Image
        // Body text
        // Author bar
        // Edit buttons
    }
}

// Hidden measurement text (outside Card, unconstrained)
if (isExpanded && !isMeasured) {
    Text(
        text = processedBodyText,
        fontSize = (15 * fontScale).sp,
        lineHeight = (20 * fontScale).sp,
        modifier = Modifier
            .width(availableWidth.dp)
            .onSizeChanged { size ->
                with(density) { bodyTextHeight = size.height.toDp().value }
                isMeasured = true
            }
            .alpha(0f)
    )
}
```

## Linear Interpolation Helper

```kotlin
private fun lerp(start: Float, end: Float, t: Float): Float {
    return start + (end - start) * t
}
```

## Key Implementation Details

1. **Author bar always visible**: Position interpolates from compact (76dp) to expanded (below body text)
2. **Author button only when expanded**: Plain text in compact, tappable button in expanded
3. **Tunables throughout**: All sizes, colors, and radii read from TunableConstants
4. **Date format**: "d MMM yyyy" (e.g., "5 Nov 2025") matching iOS
5. **Edit support**: Pencil button for own posts, save/cancel in edit mode
6. **compactHeight = 110dp**: Matches iOS (was 100dp)
7. **Spacing = 16dp**: Title-to-image gap and bottom padding (was 8dp)
8. **Thumbnail padding = 8dp**: Inset from right edge (was 16dp)

## Required Imports

```kotlin
import androidx.compose.animation.core.*
import androidx.compose.foundation.*
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import java.text.SimpleDateFormat
import java.util.*
```
