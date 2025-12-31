package com.miso.noobtest

import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.RectangleShape
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.launch
import java.text.SimpleDateFormat
import java.util.*

/**
 * Linear interpolation helper
 */
private fun lerp(start: Float, end: Float, fraction: Float): Float {
    return start + fraction * (end - start)
}

@Composable
fun PostView(
    post: Post,
    isExpanded: Boolean,
    onTap: () -> Unit,
    isEditing: Boolean = false,
    onStartEditing: (() -> Unit)? = null,
    onEndEditing: (() -> Unit)? = null,
    onPostUpdated: ((Post) -> Unit)? = null
) {
    val scope = rememberCoroutineScope()

    // Edit state - local copies for editing
    var editableTitle by remember(post.id) { mutableStateOf(post.title) }
    var editableSummary by remember(post.id) { mutableStateOf(post.summary) }
    var editableBody by remember(post.id) { mutableStateOf(post.body) }

    // Check if current user owns this post
    val currentUserEmail = remember { Storage.getLoginState().first }
    val isOwnPost = remember(post.authorEmail, currentUserEmail) {
        val own = currentUserEmail != null &&
                  post.authorEmail != null &&
                  post.authorEmail.lowercase() == currentUserEmail.lowercase()
        if (own) {
            Logger.info("[PostView] Own post detected: ${post.id}")
        }
        own
    }

    // Debug: Log recompositions with timestamp
    val composeTime = System.currentTimeMillis()
    Logger.info("[PostView] COMPOSE ${post.id} '${post.title.take(15)}' expanded=$isExpanded editing=$isEditing time=$composeTime")

    // Register UI automation for this post
    RegisterUIElement("post-${post.id}") {
        onTap()
    }

    val density = androidx.compose.ui.platform.LocalDensity.current

    // Observe tunables for reactivity
    val tunablesVersion = TunableConstants.version.value
    val fontScale = TunableConstants.getDouble("font-scale", 1.0).toFloat()
    val cornerRoundness = TunableConstants.getDouble("corner-roundness", 1.0).toFloat()
    val postBackgroundBrightness = TunableConstants.getDouble("post-background-brightness", 0.9).toFloat()
    val authorFontSize = TunableConstants.getDouble("author-font-size", 1.0).toFloat()
    val buttonColor = TunableConstants.buttonColor()

    val compactHeight = 110.dp  // Matches iOS
    val availableWidth = 350f
    val authorHeight = 15f
    val serverURL = "http://185.96.221.52:8080"

    var bodyTextHeight by remember { mutableFloatStateOf(200f) }
    var titleSummaryHeight by remember { mutableFloatStateOf(60f) }
    var isMeasured by remember { mutableStateOf(false) }

    // Fixed aspect ratio for placeholder rectangles
    val imageAspectRatio = 1.5f  // 3:2 aspect ratio

    // Image URL for this post
    val imageUrl = if (post.imageUrl != null) serverURL + post.imageUrl else null

    // Get observable thumbnail state from ImageCache
    val thumbnailState = remember(imageUrl) {
        if (imageUrl != null) ImageCache.getThumbnailState(imageUrl) else null
    }
    val thumbnail = thumbnailState?.value

    // Get observable full image state from ImageCache
    val fullImageState = remember(imageUrl) {
        if (imageUrl != null) ImageCache.getFullImageState(imageUrl) else null
    }
    val fullImage = fullImageState?.value

    // Load thumbnail immediately
    LaunchedEffect(imageUrl) {
        if (imageUrl != null) {
            Logger.info("[IMAGE_LOAD] Thumbnail START ${post.id} '${post.title.take(15)}'")
            ImageCache.preloadThumbnails(listOf(imageUrl))
            Logger.info("[IMAGE_LOAD] Thumbnail COMPLETE ${post.id}")
        }
    }

    // Load full image when expanded
    LaunchedEffect(imageUrl, isExpanded) {
        if (imageUrl != null && isExpanded) {
            Logger.info("[IMAGE_LOAD] Full image START ${post.id} '${post.title.take(15)}'")
            ImageCache.preloadFullImages(listOf(imageUrl))
            Logger.info("[IMAGE_LOAD] Full image COMPLETE ${post.id}")
        }
    }

    // Choose which image to display: full when expanded (if available), otherwise thumbnail
    val displayImage = if (isExpanded && fullImage != null) fullImage else thumbnail

    // Animate expansion factor
    val animatedExpansionFactor by animateFloatAsState(
        targetValue = if (isExpanded) 1f else 0f,
        animationSpec = tween(durationMillis = 300, easing = FastOutSlowInEasing),
        label = "expansion"
    )

    // Cache expensive text processing
    val processedBodyText = remember(post.body) { processBodyText(post.body) }
    val formattedDate = remember(post.createdAt) { formatDate(post.createdAt) }

    // Calculate heights
    val imageHeight = if (post.imageUrl != null) {
        availableWidth / imageAspectRatio
    } else {
        0f
    }

    val expandedHeight = titleSummaryHeight + 16f + imageHeight + 16f +
                         bodyTextHeight + 24f + authorHeight + 16f

    val currentHeight = lerp(compactHeight.value, expandedHeight, animatedExpansionFactor)

    // Image position interpolation
    val compactImageWidth = 80f
    val compactImageHeight = 80f
    val compactX = availableWidth - 80f - 8f  // inset 8pt from right edge (matches iOS thumbnailPadding)
    val compactY = (110f - 80f) / 2f - 8f  // vertically centered in 110dp height, minus Box padding

    val expandedWidth = availableWidth
    val expandedImageHeight = availableWidth / imageAspectRatio
    val expandedX = 10f  // 10dp indent (inside 8dp box padding = 18dp total, matches iOS)
    val expandedY = titleSummaryHeight + 16f

    val currentWidth = lerp(compactImageWidth, expandedWidth, animatedExpansionFactor)
    val currentImageHeight = lerp(compactImageHeight, expandedImageHeight, animatedExpansionFactor)
    val currentX = lerp(compactX, expandedX, animatedExpansionFactor)
    val currentY = lerp(compactY, expandedY, animatedExpansionFactor)

    Box {
        Card(
        modifier = Modifier
            .fillMaxWidth()
            .height(currentHeight.dp)
            .clickable(
                indication = null,
                interactionSource = remember { MutableInteractionSource() }
            ) { onTap() },
        colors = CardDefaults.cardColors(
            containerColor = Color.White.copy(alpha = postBackgroundBrightness)
        ),
        shape = RoundedCornerShape((12 * cornerRoundness).dp),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
    ) {
        Box(modifier = Modifier.fillMaxSize().padding(8.dp)) {
            // Title and Summary (always visible, leaves room for thumbnail in compact)
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(end = if (post.imageUrl != null && animatedExpansionFactor < 0.5f) 96.dp else 0.dp)
                    .onSizeChanged { size ->
                        with(density) {
                            titleSummaryHeight = size.height.toDp().value
                        }
                    }
            ) {
                if (isEditing) {
                    // Editable title
                    BasicTextField(
                        value = editableTitle,
                        onValueChange = { newValue ->
                            editableTitle = newValue
                            Logger.info("[PostView] Title changed: ${post.id}")
                        },
                        textStyle = TextStyle(
                            fontSize = 22.sp,
                            fontWeight = FontWeight.Bold,
                            color = Color.Black
                        ),
                        singleLine = true,
                        modifier = Modifier
                            .fillMaxWidth()
                            .background(
                                Color.Gray.copy(alpha = 0.2f),
                                RoundedCornerShape(8.dp)
                            )
                            .padding(8.dp)
                    )
                } else {
                    Text(
                        text = editableTitle,
                        fontSize = (22 * fontScale).sp,
                        fontWeight = FontWeight.Bold,
                        color = Color.Black,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                }

                Spacer(modifier = Modifier.height(4.dp))

                if (isEditing) {
                    // Editable summary
                    BasicTextField(
                        value = editableSummary,
                        onValueChange = { newValue ->
                            editableSummary = newValue
                            Logger.info("[PostView] Summary changed: ${post.id}")
                        },
                        textStyle = TextStyle(
                            fontSize = 15.sp,
                            fontStyle = FontStyle.Italic,
                            color = Color.Black.copy(alpha = 0.8f)
                        ),
                        singleLine = false,
                        maxLines = 3,
                        modifier = Modifier
                            .fillMaxWidth()
                            .background(
                                Color.Gray.copy(alpha = 0.2f),
                                RoundedCornerShape(8.dp)
                            )
                            .padding(8.dp)
                    )
                } else {
                    Text(
                        text = editableSummary,
                        fontSize = (15 * fontScale).sp,
                        fontStyle = FontStyle.Italic,
                        color = Color.Black.copy(alpha = 0.8f),
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis
                    )
                }
            }

            // Image (full res when expanded, thumbnail when compact, gray placeholder while loading)
            if (post.imageUrl != null) {
                Box(
                    modifier = Modifier
                        .offset(x = currentX.dp, y = currentY.dp)
                        .width(currentWidth.dp)
                        .height(currentImageHeight.dp)
                        .clip(RoundedCornerShape(12.dp))
                        .background(Color.LightGray)
                ) {
                    displayImage?.let { bitmap ->
                        Image(
                            bitmap = bitmap.asImageBitmap(),
                            contentDescription = null,
                            modifier = Modifier.fillMaxSize(),
                            contentScale = ContentScale.Crop
                        )
                    }
                }
            }

            // Body text (tracks image position, only when expanded)
            if (animatedExpansionFactor > 0.3f && isMeasured) {
                val bodyY = currentY + currentImageHeight + 16f
                val currentBodyHeight = lerp(0f, bodyTextHeight, animatedExpansionFactor)

                Box(
                    modifier = Modifier
                        .offset(x = 10.dp, y = bodyY.dp)  // 10dp indent (inside 8dp box padding = 18dp total)
                        .width((availableWidth - 20f).dp)  // Slightly narrower to account for indent
                        .graphicsLayer {
                            alpha = animatedExpansionFactor
                        }
                ) {
                    if (isEditing) {
                        // Editable body
                        BasicTextField(
                            value = editableBody,
                            onValueChange = { newValue ->
                                editableBody = newValue
                                Logger.info("[PostView] Body changed: ${post.id}")
                            },
                            textStyle = TextStyle(
                                fontSize = 15.sp,
                                lineHeight = 20.sp,
                                color = Color.Black
                            ),
                            modifier = Modifier
                                .fillMaxWidth()
                                .background(
                                    Color.Gray.copy(alpha = 0.2f),
                                    RoundedCornerShape(8.dp)
                                )
                                .padding(8.dp)
                        )
                    } else {
                        Text(
                            text = processedBodyText,
                            color = Color.Black,
                            fontSize = (15 * fontScale).sp,
                            lineHeight = (20 * fontScale).sp,
                            modifier = Modifier.fillMaxWidth()
                        )
                    }
                }
            }

            // Author metadata - always visible, interpolates position
            // In compact: below title/summary (~76dp)
            // In expanded: below body text
            val compactAuthorY = 76f  // Below title/summary area
            val expandedAuthorY = if (isMeasured) {
                currentY + currentImageHeight + 16f + bodyTextHeight + 24f
            } else {
                compactAuthorY + 200f  // Fallback before measurement
            }
            val authorY = lerp(compactAuthorY, expandedAuthorY, animatedExpansionFactor)

            Row(
                modifier = Modifier
                    .offset(x = 10.dp, y = authorY.dp)  // 10dp left indent (inside 8dp box padding = 18dp total)
                    .graphicsLayer { alpha = 1f },  // Always fully visible
                horizontalArrangement = Arrangement.spacedBy(8.dp)  // 8dp between author and date
            ) {
                val authorTextSize = (15 * fontScale * authorFontSize).sp

                if (post.aiGenerated) {
                    Text(
                        text = "👓 librarian",
                        fontSize = authorTextSize,
                        color = Color.Black.copy(alpha = 0.5f)
                    )
                } else if (post.authorName != null) {
                    // Author button only in expanded view (when not a profile post)
                    // TODO: Check if author has profile before making it a button
                    val isProfilePost = false  // TODO: Check post.template == "profile"

                    if (isExpanded && !isProfilePost) {
                        // Expanded: author as tappable button with background
                        Box(
                            modifier = Modifier
                                .background(
                                    buttonColor,
                                    RoundedCornerShape((6 * cornerRoundness).dp)
                                )
                                .clickable {
                                    Logger.info("[PostView] Author button tapped: ${post.authorName}")
                                    // TODO: Navigate to author profile
                                }
                                .padding(horizontal = 8.dp, vertical = 4.dp)
                        ) {
                            Text(
                                text = post.authorName,
                                fontSize = authorTextSize,
                                color = Color.Black
                            )
                        }
                    } else {
                        // Compact or profile post: plain text
                        Text(
                            text = post.authorName,
                            fontSize = authorTextSize,
                            color = Color.Black.copy(alpha = 0.5f)
                        )
                    }
                }

                Text(
                    text = formattedDate,
                    fontSize = authorTextSize,
                    color = Color.Black.copy(alpha = 0.5f),
                    modifier = Modifier.padding(start = 16.dp)  // Extra 16dp before date
                )
            }

            // Edit button overlay - pencil button (only for own posts, expanded, not editing)
            if (isOwnPost && isExpanded && !isEditing && animatedExpansionFactor > 0.5f && isMeasured) {
                // Position at same Y as author metadata (use expandedAuthorY since we're fully expanded)
                val editButtonY = expandedAuthorY

                // Register edit button for UI automation
                RegisterUIElement("edit-button-${post.id}") {
                    Logger.info("[PostView] Edit button tapped: ${post.id}")
                    onStartEditing?.invoke()
                    Logger.info("[PostView] Entered edit mode: ${post.id}")
                }

                Box(
                    modifier = Modifier
                        .offset(x = (availableWidth - 36f - 12f).dp, y = editButtonY.dp)
                        .size(36.dp)
                        .shadow(8.dp, CircleShape)
                        .background(buttonColor, CircleShape)
                        .clickable {
                            Logger.info("[PostView] Edit button tapped: ${post.id}")
                            onStartEditing?.invoke()
                            Logger.info("[PostView] Entered edit mode: ${post.id}")
                        },
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        imageVector = Icons.Default.Edit,
                        contentDescription = "Edit",
                        tint = Color.Black,
                        modifier = Modifier.size(18.dp)
                    )
                }
            }

            // Edit action buttons overlay - cancel and save (only when editing)
            if (isOwnPost && isExpanded && isEditing && isMeasured) {
                // Position at same Y as author metadata (use expandedAuthorY since we're fully expanded)
                val editButtonY = expandedAuthorY
                // Two 32dp buttons with 20dp spacing = 84dp total width
                val buttonsWidth = 32f + 20f + 32f
                val buttonsX = availableWidth - buttonsWidth - 12f

                // Register cancel and save buttons for UI automation
                RegisterUIElement("cancel-button-${post.id}") {
                    Logger.info("[PostView] Cancel tapped: ${post.id}")
                    editableTitle = post.title
                    editableSummary = post.summary
                    editableBody = post.body
                    Logger.info("[PostView] Changes reverted: ${post.id}")
                    onEndEditing?.invoke()
                    Logger.info("[PostView] Exited edit mode: ${post.id}")
                }

                RegisterUIElement("save-button-${post.id}") {
                    Logger.info("[PostView] Save tapped: ${post.id}")
                    Logger.info("[PostView] Saving to server: ${post.id}")
                    scope.launch {
                        val result = PostsAPI.shared.updatePost(
                            postId = post.id,
                            title = editableTitle,
                            summary = editableSummary,
                            body = editableBody
                        )
                        result.fold(
                            onSuccess = { updatedPost ->
                                Logger.info("[PostView] Save succeeded: ${post.id}")
                                onPostUpdated?.invoke(updatedPost)
                                onEndEditing?.invoke()
                                Logger.info("[PostView] Exited edit mode: ${post.id}")
                            },
                            onFailure = { error ->
                                Logger.error("[PostView] Save failed: ${post.id} - ${error.message}")
                            }
                        )
                    }
                }

                Row(
                    modifier = Modifier
                        .offset(x = buttonsX.dp, y = editButtonY.dp),
                    horizontalArrangement = Arrangement.spacedBy(20.dp)
                ) {
                    // Cancel button (undo arrow)
                    Box(
                        modifier = Modifier
                            .size(32.dp)
                            .shadow(8.dp, CircleShape)
                            .background(buttonColor, CircleShape)
                            .clickable {
                                Logger.info("[PostView] Cancel tapped: ${post.id}")
                                // Revert to saved values
                                editableTitle = post.title
                                editableSummary = post.summary
                                editableBody = post.body
                                Logger.info("[PostView] Changes reverted: ${post.id}")
                                onEndEditing?.invoke()
                                Logger.info("[PostView] Exited edit mode: ${post.id}")
                            },
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            text = "↩",
                            fontSize = 16.sp,
                            fontWeight = FontWeight.Bold,
                            color = Color.Black
                        )
                    }

                    // Save button (checkmark)
                    Box(
                        modifier = Modifier
                            .size(32.dp)
                            .shadow(8.dp, CircleShape)
                            .background(Color(0xFF80FF80), CircleShape)
                            .clickable {
                                Logger.info("[PostView] Save tapped: ${post.id}")
                                Logger.info("[PostView] Saving to server: ${post.id}")
                                scope.launch {
                                    val result = PostsAPI.shared.updatePost(
                                        postId = post.id,
                                        title = editableTitle,
                                        summary = editableSummary,
                                        body = editableBody
                                    )
                                    result.fold(
                                        onSuccess = { updatedPost ->
                                            Logger.info("[PostView] Save succeeded: ${post.id}")
                                            onPostUpdated?.invoke(updatedPost)
                                            onEndEditing?.invoke()
                                            Logger.info("[PostView] Exited edit mode: ${post.id}")
                                        },
                                        onFailure = { error ->
                                            Logger.error("[PostView] Save failed: ${post.id} - ${error.message}")
                                        }
                                    )
                                }
                            },
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(
                            imageVector = Icons.Default.Check,
                            contentDescription = "Save",
                            tint = Color.Black,
                            modifier = Modifier.size(18.dp)
                        )
                    }
                }
            }
        }
    }

        // Hidden measurement text (outside Card, unconstrained)
        if (isExpanded && !isMeasured) {
            Text(
                text = processedBodyText,
                color = Color.Black,
                fontSize = (15 * fontScale).sp,
                lineHeight = (20 * fontScale).sp,
                modifier = Modifier
                    .width(availableWidth.dp)
                    .onSizeChanged { size ->
                        with(density) {
                            bodyTextHeight = size.height.toDp().value
                        }
                        isMeasured = true
                        Logger.info("[PostView] Body text measured: ${bodyTextHeight}dp for ${post.title.take(20)}")
                    }
                    .alpha(0f)  // Hidden
            )
        }
    }
}

/**
 * Process markdown-style body text.
 * Removes image references, formats headings and bullet points.
 */
private fun processBodyText(text: String): androidx.compose.ui.text.AnnotatedString {
    // Remove image markdown: ![alt](url)
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

/**
 * Format date string to readable format: "d MMM yyyy" (e.g., "5 Nov 2025")
 * Handles server format: "Wed, 15 Oct 2025 14:37:09 GMT"
 */
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
