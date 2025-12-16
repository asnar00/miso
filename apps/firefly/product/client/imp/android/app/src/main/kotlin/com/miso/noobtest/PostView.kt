package com.miso.noobtest

import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.RectangleShape
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
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
    onTap: () -> Unit
) {
    // Debug: Log recompositions with timestamp
    val composeTime = System.currentTimeMillis()
    Logger.info("[PostView] COMPOSE ${post.id} '${post.title.take(15)}' expanded=$isExpanded time=$composeTime")

    val density = androidx.compose.ui.platform.LocalDensity.current

    val compactHeight = 100.dp
    val availableWidth = 350f
    val authorHeight = 15f
    val serverURL = "http://185.96.221.52:8080"

    var bodyTextHeight by remember { mutableFloatStateOf(200f) }
    var titleSummaryHeight by remember { mutableFloatStateOf(60f) }
    var isMeasured by remember { mutableStateOf(false) }

    // Fixed aspect ratio for placeholder rectangles
    val imageAspectRatio = 1.5f  // 3:2 aspect ratio

    // Background image loading with metrics (just measure, don't display)
    LaunchedEffect(post.imageUrl) {
        if (post.imageUrl != null) {
            val url = serverURL + post.imageUrl
            Logger.info("[IMAGE_LOAD] START ${post.id} '${post.title.take(15)}' url=$url")

            kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.IO) {
                val startTime = System.currentTimeMillis()
                try {
                    val urlConnection = java.net.URL(url).openConnection() as java.net.HttpURLConnection
                    urlConnection.connect()
                    val data = urlConnection.inputStream.readBytes()

                    val downloadTime = System.currentTimeMillis() - startTime
                    val sizeKB = data.size / 1024

                    // Decode to get dimensions
                    val bitmap = android.graphics.BitmapFactory.decodeByteArray(data, 0, data.size)
                    val resolution = if (bitmap != null) {
                        "${bitmap.width}x${bitmap.height}"
                    } else {
                        "unknown"
                    }
                    bitmap?.recycle()

                    Logger.info("[IMAGE_LOAD] COMPLETE ${post.id} '${post.title.take(15)}' size=${sizeKB}KB time=${downloadTime}ms resolution=$resolution")

                    // Throw away the data - we're just measuring
                } catch (e: Exception) {
                    val failTime = System.currentTimeMillis() - startTime
                    Logger.error("[IMAGE_LOAD] FAILED ${post.id} '${post.title.take(15)}' time=${failTime}ms error=${e.message}")
                }
            }
        }
    }

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

    val expandedHeight = titleSummaryHeight + 8f + imageHeight + 16f +
                         bodyTextHeight + 24f + authorHeight + 8f

    val currentHeight = lerp(compactHeight.value, expandedHeight, animatedExpansionFactor)

    // Image position interpolation
    val compactImageWidth = 80f
    val compactImageHeight = 80f
    val compactX = availableWidth - 80f - 16f  // inset 16pt from right edge
    val compactY = (100f - 80f) / 2f - 8f  // vertically centered, minus Box padding

    val expandedWidth = availableWidth
    val expandedImageHeight = availableWidth / imageAspectRatio
    val expandedX = 0f  // Aligned with Box content edge (Box already has 8dp padding)
    val expandedY = titleSummaryHeight + 8f

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
            containerColor = Color.White.copy(alpha = 0.9f)
        ),
        shape = RoundedCornerShape(12.dp),
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
                Text(
                    text = post.title,
                    fontSize = 22.sp,
                    fontWeight = FontWeight.Bold,
                    color = Color.Black,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )

                Spacer(modifier = Modifier.height(4.dp))

                Text(
                    text = post.summary,
                    fontSize = 15.sp,
                    fontStyle = FontStyle.Italic,
                    color = Color.Black.copy(alpha = 0.8f),
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis
                )
            }

            // Grey placeholder rectangle
            if (post.imageUrl != null) {
                Box(
                    modifier = Modifier
                        .offset(x = currentX.dp, y = currentY.dp)
                        .width(currentWidth.dp)
                        .height(currentImageHeight.dp)
                        .clip(RoundedCornerShape(12.dp))
                        .background(Color.LightGray)
                )
            }

            // Body text (tracks image position, only when expanded)
            if (animatedExpansionFactor > 0.3f && isMeasured) {
                val bodyY = currentY + currentImageHeight + 16f
                val currentBodyHeight = lerp(0f, bodyTextHeight, animatedExpansionFactor)

                Box(
                    modifier = Modifier
                        .offset(x = 0.dp, y = bodyY.dp)
                        .width(availableWidth.dp)
                        .graphicsLayer {
                            alpha = animatedExpansionFactor
                        }
                ) {
                    Text(
                        text = processedBodyText,
                        color = Color.Black,
                        fontSize = 15.sp,
                        lineHeight = 20.sp,
                        modifier = Modifier.fillMaxWidth()
                    )
                }
            }

            // Author metadata (tracks image + body position, fades in)
            if (animatedExpansionFactor > 0.3f && isMeasured) {
                val authorY = currentY + currentImageHeight + 16f + bodyTextHeight + 24f

                Row(
                    modifier = Modifier
                        .offset(x = 0.dp, y = authorY.dp)
                        .fillMaxWidth()
                        .graphicsLayer { alpha = animatedExpansionFactor },
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    if (post.aiGenerated) {
                        Text(
                            text = "👓 librarian",
                            fontSize = 12.sp,
                            color = Color.Black.copy(alpha = 0.5f)
                        )
                    } else if (post.authorName != null) {
                        Text(
                            text = post.authorName,
                            fontSize = 12.sp,
                            color = Color.Black.copy(alpha = 0.5f)
                        )
                    }

                    Text(
                        text = formattedDate,
                        fontSize = 12.sp,
                        color = Color.Black.copy(alpha = 0.5f)
                    )
                }
            }
        }
    }

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
 * Format ISO date string to readable format.
 */
private fun formatDate(dateString: String): String {
    return try {
        val inputFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US)
        inputFormat.timeZone = TimeZone.getTimeZone("UTC")
        val date = inputFormat.parse(dateString)

        val outputFormat = SimpleDateFormat("MMM d, yyyy", Locale.US)
        outputFormat.format(date ?: Date())
    } catch (e: Exception) {
        dateString
    }
}
