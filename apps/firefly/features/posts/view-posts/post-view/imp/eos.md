# post-view Android/e/OS implementation

*Jetpack Compose implementation for compact/expanded post display with smooth animation*

## File Location

`apps/firefly/product/client/imp/eos/app/src/main/kotlin/com/miso/noobtest/PostView.kt`

## State Variables

```kotlin
@Composable
fun PostView(
    post: Post,
    isExpanded: Boolean,
    onTap: () -> Unit,
    onPostCreated: () -> Unit
) {
    val density = LocalDensity.current  // CRITICAL: Needed for pixel-to-dp conversion

    var expansionFactor by remember { mutableFloatStateOf(if (isExpanded) 1f else 0f) }
    var imageAspectRatio by remember { mutableFloatStateOf(1f) }
    var bodyTextHeight by remember { mutableFloatStateOf(200f) }  // Stored in dp
    var titleSummaryHeight by remember { mutableFloatStateOf(60f) }  // Stored in dp
    var isMeasured by remember { mutableStateOf(false) }

    // Animate expansion factor
    val animatedExpansionFactor by animateFloatAsState(
        targetValue = if (isExpanded) 1f else 0f,
        animationSpec = tween(durationMillis = 300, easing = FastOutSlowInEasing),
        label = "expansion"
    )

    LaunchedEffect(isExpanded) {
        expansionFactor = if (isExpanded) 1f else 0f
    }
```

## Constants

```kotlin
val compactHeight = 100.dp
val availableWidth = 350.dp
val authorHeight = 15.dp
val serverURL = "http://185.96.221.52:8080"
```

## Height Calculation

```kotlin
val imageHeight = if (post.imageUrl != null) {
    availableWidth / imageAspectRatio
} else {
    0f
}

// Spacing: titleSummary + 8 + image + 16 + body + 24 + author + 8
val expandedHeight = titleSummaryHeight + 8f + imageHeight + 16f +
                     bodyTextHeight + 24f + authorHeight + 8f

val currentHeight = lerp(compactHeight.value, expandedHeight, animatedExpansionFactor)
```

**Spacing breakdown:**
- Title/summary to image: 8dp
- Image to body text: 16dp
- Body text to author: 24dp
- Author to bottom: 8dp (provided by Card padding)

## Image Position and Size Interpolation

```kotlin
// Compact state (thumbnail)
val compactWidth = 80.dp
val compactImageHeight = 80.dp
val compactX = availableWidth.value - 80f - 16f  // inset 16pt from right edge
val compactY = (100f - 80f) / 2f - 8f  // vertically centered, minus Box padding

// Expanded state (full image)
val expandedWidth = availableWidth
val expandedImageHeight = availableWidth / imageAspectRatio
val expandedX = 0f  // Aligned with Box content edge (Box already has 8dp padding)
val expandedY = titleSummaryHeight + 8f

// Interpolated values
val currentWidth = lerp(compactWidth.value, expandedWidth, animatedExpansionFactor)
val currentImageHeight = lerp(compactImageHeight.value, expandedImageHeight, animatedExpansionFactor)
val currentX = lerp(compactX, expandedX, animatedExpansionFactor)
val currentY = lerp(compactY, expandedY, animatedExpansionFactor)
```

## Complete Layout Structure

```kotlin
@Composable
fun PostView(
    post: Post,
    isExpanded: Boolean,
    onTap: () -> Unit,
    onPostCreated: () -> Unit
) {
    val density = LocalDensity.current  // CRITICAL: Needed for pixel-to-dp conversion

    val compactHeight = 100.dp
    val availableWidth = 350.dp
    val authorHeight = 15.dp
    val serverURL = "http://185.96.221.52:8080"

    var expansionFactor by remember { mutableFloatStateOf(if (isExpanded) 1f else 0f) }
    var imageAspectRatio by remember { mutableFloatStateOf(1f) }
    var bodyTextHeight by remember { mutableFloatStateOf(200f) }  // Stored in dp
    var titleSummaryHeight by remember { mutableFloatStateOf(60f) }  // Stored in dp
    var isMeasured by remember { mutableStateOf(false) }

    val animatedExpansionFactor by animateFloatAsState(
        targetValue = if (isExpanded) 1f else 0f,
        animationSpec = tween(durationMillis = 300, easing = FastOutSlowInEasing),
        label = "expansion"
    )

    LaunchedEffect(isExpanded) {
        expansionFactor = if (isExpanded) 1f else 0f
    }

    val imageHeight = if (post.imageUrl != null) {
        availableWidth.value / imageAspectRatio
    } else {
        0f
    }

    val expandedHeight = titleSummaryHeight + 16f + imageHeight + 16f +
                         bodyTextHeight + 24f + authorHeight.value + 16f

    val currentHeight = lerp(compactHeight.value, expandedHeight, animatedExpansionFactor)

    Card(
        modifier = Modifier
            .fillMaxWidth()
            .height(currentHeight.dp)
            .clickable { onTap() },
        colors = CardDefaults.cardColors(
            containerColor = Color.White.copy(alpha = 0.9f)
        ),
        shape = RoundedCornerShape(12.dp),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
    ) {
        Box(modifier = Modifier.fillMaxSize()) {
            // Title and Summary (always visible)
            Column(
                modifier = Modifier
                    .padding(8.dp)
                    .fillMaxWidth()
                    .padding(end = if (post.imageUrl != null) 96.dp else 0.dp)
                    .onSizeChanged { size ->
                        with(density) {
                            titleSummaryHeight = size.height.toDp().value
                        }
                    }
            ) {
                Text(
                    text = post.title,
                    style = MaterialTheme.typography.titleLarge.copy(
                        fontSize = 22.sp,
                        fontWeight = FontWeight.Bold
                    ),
                    color = Color.Black,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )

                Spacer(modifier = Modifier.height(4.dp))

                Text(
                    text = post.summary,
                    style = MaterialTheme.typography.bodyMedium.copy(
                        fontSize = 15.sp,
                        fontStyle = FontStyle.Italic
                    ),
                    color = Color.Black.copy(alpha = 0.8f),
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis
                )
            }

            // Body text (tracks image position)
            if (isExpanded && isMeasured) {
                val compactImageHeight = 80f
                val compactImageY = (100f - 80f) / 2f - 8f
                val expandedImageY = titleSummaryHeight + 8f
                val expandedImageHeightVal = availableWidth.value / imageAspectRatio

                val currentImageY = lerp(compactImageY, expandedImageY, animatedExpansionFactor)
                val currentImageHeightVal = lerp(compactImageHeight, expandedImageHeightVal, animatedExpansionFactor)

                val bodyY = currentImageY + currentImageHeightVal + 16f
                val currentBodyHeight = lerp(0f, bodyTextHeight, animatedExpansionFactor)

                Box(
                    modifier = Modifier
                        .offset(x = 0.dp, y = bodyY.dp)
                        .width(availableWidth)
                        .height(bodyTextHeight.dp)
                        .graphicsLayer {
                            clip = true
                            shape = RectangleShape
                            scaleY = currentBodyHeight / bodyTextHeight
                            transformOrigin = TransformOrigin(0f, 0f)
                        }
                ) {
                    Text(
                        text = processBodyText(post.body),
                        color = Color.Black,
                        style = MaterialTheme.typography.bodyMedium,
                        modifier = Modifier
                            .fillMaxWidth()
                            .align(Alignment.TopStart)
                    )
                }
            }

            // Author metadata (tracks image + body position, fades in)
            if (isExpanded && isMeasured) {
                val compactImageHeight = 80f
                val compactImageY = (100f - 80f) / 2f - 8f
                val expandedImageY = titleSummaryHeight + 8f
                val expandedImageHeightVal = availableWidth.value / imageAspectRatio

                val currentImageY = lerp(compactImageY, expandedImageY, animatedExpansionFactor)
                val currentImageHeightVal = lerp(compactImageHeight, expandedImageHeightVal, animatedExpansionFactor)
                val authorY = currentImageY + currentImageHeightVal + 16f + bodyTextHeight + 24f

                Row(
                    modifier = Modifier
                        .offset(x = 0.dp, y = authorY.dp)
                        .fillMaxWidth()
                        .graphicsLayer { alpha = animatedExpansionFactor }
                ) {
                    if (post.aiGenerated) {
                        Text(
                            text = "👓 librarian",
                            style = MaterialTheme.typography.bodySmall,
                            color = Color.Black.copy(alpha = 0.5f)
                        )
                    } else if (post.authorName != null) {
                        Text(
                            text = post.authorName,
                            style = MaterialTheme.typography.bodySmall,
                            color = Color.Black.copy(alpha = 0.5f)
                        )
                    }
                }
            }

            // Animated image
            if (post.imageUrl != null) {
                val fullUrl = "$serverURL${post.imageUrl}"

                val compactImageWidth = 80.dp
                val compactImageHeight = 80.dp
                val compactX = availableWidth.value - 80f + 8f
                val compactY = (100f - 80f) / 2f + 8f

                val expandedWidth = availableWidth.value
                val expandedImageHeight = availableWidth.value / imageAspectRatio
                val expandedX = 0f  // Aligned with Box content edge
                val expandedY = titleSummaryHeight + 8f

                val currentWidth = lerp(compactImageWidth.value, expandedWidth, animatedExpansionFactor)
                val currentImageHeight = lerp(compactImageHeight.value, expandedImageHeight, animatedExpansionFactor)
                val currentX = lerp(compactX, expandedX, animatedExpansionFactor)
                val currentY = lerp(compactY, expandedY, animatedExpansionFactor)

                AsyncImage(
                    model = ImageRequest.Builder(LocalContext.current)
                        .data(fullUrl)
                        .crossfade(true)
                        .listener(
                            onSuccess = { _, result ->
                                if (imageAspectRatio == 1f) {
                                    val drawable = result.drawable
                                    imageAspectRatio = drawable.intrinsicWidth.toFloat() /
                                                      drawable.intrinsicHeight.toFloat()
                                }
                            }
                        )
                        .build(),
                    contentDescription = post.title,
                    contentScale = ContentScale.Crop,
                    modifier = Modifier
                        .offset(x = currentX.dp, y = currentY.dp)
                        .size(width = currentWidth.dp, height = currentImageHeight.dp)
                        .clip(RoundedCornerShape(12.dp)),
                    placeholder = painterResource(R.drawable.placeholder),
                    error = painterResource(R.drawable.placeholder)
                )
            }
        }
    }

    // Measure body text once on first expand
    if (isExpanded && !isMeasured) {
        Box(
            modifier = Modifier
                .width(availableWidth)
                .onSizeChanged { size ->
                    with(density) {
                        bodyTextHeight = size.height.toDp().value
                    }
                    isMeasured = true
                }
                .alpha(0f)  // Hidden but measured
        ) {
            Text(
                text = processBodyText(post.body),
                style = MaterialTheme.typography.bodyMedium
            )
        }
    }
}
```

## Linear Interpolation Helper

```kotlin
fun lerp(start: Float, end: Float, t: Float): Float {
    return start + (end - start) * t
}
```

## Body Text Formatting

The `processBodyText()` function handles markdown processing with proper paragraph separation:

```kotlin
private fun processBodyText(text: String): androidx.compose.ui.text.AnnotatedString {
    val imagePattern = """!\[.*?\]\(.*?\)""".toRegex()
    val cleaned = text.replace(imagePattern, "")

    return buildAnnotatedString {
        val lines = cleaned.split("\n")
        var previousLineWasEmpty = false

        for ((index, line) in lines.withIndex()) {
            val trimmedLine = line.trim()

            when {
                trimmedLine.isEmpty() -> {
                    // Empty line - mark for paragraph break
                    previousLineWasEmpty = true
                }
                trimmedLine.startsWith("## ") -> {
                    // H2 heading - bold and larger
                    if (length > 0) append("\n\n")
                    withStyle(SpanStyle(fontSize = 18.sp, fontWeight = FontWeight.Bold)) {
                        append(trimmedLine.substring(3))
                    }
                    append("\n")
                    previousLineWasEmpty = false
                }
                trimmedLine.startsWith("- ") -> {
                    // Bullet point
                    if (length > 0) append("\n")
                    append("• ${trimmedLine.substring(2)}")
                    append("\n")
                    previousLineWasEmpty = false
                }
                else -> {
                    // Regular paragraph text
                    if (length > 0) {
                        if (previousLineWasEmpty) {
                            // New paragraph after empty line
                            append("\n\n")
                        } else {
                            // Continuation of same paragraph
                            append(" ")
                        }
                    }
                    append(trimmedLine)
                    previousLineWasEmpty = false
                }
            }
        }
    }
}
```

**Key features:**
- Tracks `previousLineWasEmpty` to distinguish between paragraph breaks and line continuations
- Empty lines trigger `previousLineWasEmpty = true`
- Next non-empty line after empty line gets `\n\n` (paragraph break)
- Consecutive non-empty lines get ` ` (word spacing within paragraph)
- Prevents paragraphs from running together with spurious spaces

See also `post-view/formatting/imp/eos.md` for additional details.

## Key Android-Specific Decisions

1. **animateFloatAsState**: Smooth animation of expansion factor with FastOutSlowInEasing
2. **Box layout with offset**: Absolute positioning using `Modifier.offset()` for interpolated positions
3. **onSizeChanged**: Measure dynamic heights (title/summary, body text) reactively
4. **AsyncImage with Coil**: Load images with automatic aspect ratio detection via listener
5. **graphicsLayer for clipping**: Use `scaleY` with clip for smooth body text reveal
6. **graphicsLayer for opacity**: Use `alpha` for smooth author fade-in
7. **ContentScale.Crop**: Maintain aspect ratio while filling frame
8. **Conditional rendering**: Author only rendered when `isExpanded && isMeasured`
9. **Hidden measurement**: Use `.alpha(0f)` for off-screen height measurement
10. **Reactive composition**: All interpolated values recompute automatically when `animatedExpansionFactor` changes

## Critical: Body Text Measurement Must Be Unconstrained

**THE TRAP**: The body text measurement cannot be constrained by the Card's height, or it will be clipped to that height.

**The problem:**
If the measurement Text is inside the Card, and the Card has `.height(currentHeight.dp)` which is calculated using the initial `bodyTextHeight = 200f`, the measurement will be constrained to that height and can't measure longer text properly.

**The solution:**
Move the measurement Text **outside the Card** as a sibling in a wrapping Box:

```kotlin
Box {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .height(currentHeight.dp)
            .clickable { onTap() },
        // ... Card content
    )

    // Hidden measurement text (outside Card, unconstrained)
    if (isExpanded && !isMeasured) {
        Text(
            text = processedBodyText,
            color = Color.Black,
            fontSize = 15.sp,
            lineHeight = 20.sp,
            modifier = Modifier
                .width(availableWidth.dp)
                .onSizeChanged { size ->
                    with(density) {
                        bodyTextHeight = size.height.toDp().value
                    }
                    isMeasured = true
                }
                .alpha(0f)  // Hidden
        )
    }
}
```

This allows the measurement Text to expand to its full height without being clipped by the Card's constraints.

## Removing Click Ripple Effect

To prevent the dark highlight/selection rectangle when clicking posts, disable the ripple indication:

```kotlin
.clickable(
    indication = null,
    interactionSource = remember { MutableInteractionSource() }
) { onTap() }
```

Requires import:
```kotlin
import androidx.compose.foundation.interaction.MutableInteractionSource
```

## Critical: Pixel-to-DP Conversion in onSizeChanged

**THE TRAP**: `onSizeChanged` returns dimensions in **pixels**, NOT dp. If you store these values and later use them with `.dp` modifiers, they will be converted to dp AGAIN, multiplying by screen density a second time.

**Example of the bug:**
```kotlin
// ❌ WRONG - Creates massive whitespace on high-density screens
.onSizeChanged { size ->
    titleSummaryHeight = size.height.toFloat()  // Gets 180 pixels
}

// Later used as:
.offset(y = titleSummaryHeight.dp)  // 180.dp becomes 540 pixels on 3x density screen!
```

**On a 3x density screen (like Fairphone):**
- Title/summary measures as 180 **pixels** (which is 60dp)
- Using `180.dp` in offset converts to 540 **pixels** (180 * 3)
- Result: Huge 360-pixel gap of whitespace

**The fix - Convert to dp immediately:**
```kotlin
// ✅ CORRECT - Get LocalDensity and convert pixels to dp
val density = LocalDensity.current

.onSizeChanged { size ->
    with(density) {
        titleSummaryHeight = size.height.toDp().value  // Converts pixels → dp
    }
}

// Later used as:
.offset(y = titleSummaryHeight.dp)  // Now correct: 60.dp = 180 pixels
```

**Why this matters:**
- On 1x density screens, the bug is invisible (1px = 1dp)
- On 2x/3x/4x screens, whitespace scales dramatically
- The bug only appears when testing on real high-density devices
- Emulators often use lower densities, hiding the issue

**Rule of thumb:**
- **onSizeChanged returns pixels** - always convert with `toDp()`
- **Modifiers like .dp, .offset(), .height() expect dp values** - never use raw pixels
- Store measurements in dp units to avoid confusion

## Required Dependencies

In `app/build.gradle.kts`:

```kotlin
dependencies {
    // Image loading
    implementation("io.coil-kt:coil-compose:2.5.0")

    // Animation
    implementation("androidx.compose.animation:animation:1.5.4")
}
```

## Performance Considerations

1. **Measure once**: Body text height measured only on first expand (`isMeasured` flag)
2. **Async aspect ratio**: Image dimensions loaded via Coil listener without blocking
3. **Efficient interpolation**: Simple linear interpolation is fast and smooth
4. **graphicsLayer optimization**: Hardware-accelerated transformations for smooth animation

This implementation creates a smooth, continuous animation that can be interrupted and reversed at any point without visual glitches, matching the iOS behavior.
