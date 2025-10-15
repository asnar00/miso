package com.miso.noobtest

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.launch
import java.text.SimpleDateFormat
import java.util.*

@Composable
fun PostsView() {
    var posts by remember { mutableStateOf<List<Post>>(emptyList()) }
    var isLoading by remember { mutableStateOf(false) }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    var expandedPostId by remember { mutableStateOf<Int?>(null) }
    val scope = rememberCoroutineScope()
    val listState = rememberLazyListState()

    // Load posts on first composition
    LaunchedEffect(Unit) {
        loadPosts(
            onLoading = { isLoading = true },
            onSuccess = { fetchedPosts ->
                posts = fetchedPosts
                isLoading = false
                // Expand first post by default
                if (fetchedPosts.isNotEmpty()) {
                    expandedPostId = fetchedPosts[0].id
                }
            },
            onError = { error ->
                errorMessage = error
                isLoading = false
            }
        )
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color(0xFF40E0D0)) // Turquoise background
    ) {
        when {
            isLoading -> {
                Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center
                ) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        CircularProgressIndicator(color = Color.Black)
                        Spacer(modifier = Modifier.height(8.dp))
                        Text("Loading posts...", color = Color.Black)
                    }
                }
            }
            errorMessage != null -> {
                Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center
                ) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Text("Error: $errorMessage", color = Color.Red)
                        Spacer(modifier = Modifier.height(8.dp))
                        Button(onClick = {
                            scope.launch {
                                loadPosts(
                                    onLoading = { isLoading = true; errorMessage = null },
                                    onSuccess = { posts = it; isLoading = false },
                                    onError = { errorMessage = it; isLoading = false }
                                )
                            }
                        }) {
                            Text("Retry")
                        }
                    }
                }
            }
            posts.isEmpty() -> {
                Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center
                ) {
                    Text("No posts yet", color = Color.Black)
                }
            }
            else -> {
                LazyColumn(
                    state = listState,
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(8.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    items(posts, key = { it.id }) { post ->
                        PostCardView(
                            post = post,
                            isExpanded = expandedPostId == post.id,
                            onExpandChange = { expanded ->
                                if (expanded) {
                                    val previousId = expandedPostId
                                    expandedPostId = post.id

                                    // Scroll to expanded post
                                    scope.launch {
                                        val index = posts.indexOfFirst { it.id == post.id }
                                        if (index >= 0) {
                                            listState.animateScrollToItem(index)
                                        }
                                    }
                                } else {
                                    expandedPostId = null
                                }
                            }
                        )
                    }
                }
            }
        }
    }
}

/**
 * Load posts with image preloading.
 * Loads first image immediately, then displays posts, then continues loading remaining images.
 */
private suspend fun loadPosts(
    onLoading: () -> Unit,
    onSuccess: (List<Post>) -> Unit,
    onError: (String) -> Unit
) {
    onLoading()

    val result = PostsAPI.shared.fetchRecentPosts()

    result.fold(
        onSuccess = { fetchedPosts ->
            // Preload images optimized: first image immediately, rest in background
            preloadImagesOptimized(fetchedPosts) {
                onSuccess(fetchedPosts)
            }
        },
        onFailure = { error ->
            onError(error.message ?: "Unknown error")
        }
    )
}

/**
 * Preload images with priority: first image immediately, rest in background.
 */
private suspend fun preloadImagesOptimized(posts: List<Post>, completion: () -> Unit) {
    val serverURL = "http://185.96.221.52:8080"
    val imageUrls = posts.mapNotNull { post ->
        post.imageUrl?.let { serverURL + it }
    }

    if (imageUrls.isEmpty()) {
        completion()
        return
    }

    // Load first image, then display
    val firstUrl = imageUrls[0]
    ImageCache.shared.preload(listOf(firstUrl)) {
        completion()

        // Continue loading remaining images in background
        if (imageUrls.size > 1) {
            kotlinx.coroutines.GlobalScope.launch {
                val remainingUrls = imageUrls.drop(1)
                ImageCache.shared.preload(remainingUrls) {
                    Logger.info("[PostsView] Background image loading complete")
                }
            }
        }
    }
}

@Composable
fun PostCardView(
    post: Post,
    isExpanded: Boolean,
    onExpandChange: (Boolean) -> Unit
) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .shadow(2.dp, RoundedCornerShape(12.dp)),
        onClick = {
            // Toggle expanded state
            onExpandChange(!isExpanded)
        },
        colors = CardDefaults.cardColors(
            containerColor = Color.White.copy(alpha = 0.9f)
        ),
        shape = RoundedCornerShape(12.dp)
    ) {
        Box(modifier = Modifier.padding(16.dp)) {
            if (isExpanded) {
                FullPostView(post = post)
            } else {
                CompactPostView(post = post)
            }
        }
    }
}

@Composable
fun CompactPostView(post: Post) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.Top
    ) {
        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            Text(
                text = post.title,
                fontSize = 20.sp,
                fontWeight = FontWeight.Bold,
                color = Color.Black
            )
            Text(
                text = post.summary,
                fontSize = 14.sp,
                fontStyle = FontStyle.Italic,
                color = Color.Black.copy(alpha = 0.8f)
            )
        }

        Spacer(modifier = Modifier.width(12.dp))

        // Image thumbnail
        post.imageUrl?.let { imageUrl ->
            val serverURL = "http://185.96.221.52:8080"
            val fullUrl = serverURL + imageUrl
            val cachedBitmap = ImageCache.shared.get(fullUrl)

            if (cachedBitmap != null) {
                Image(
                    bitmap = cachedBitmap.asImageBitmap(),
                    contentDescription = "Post thumbnail",
                    modifier = Modifier
                        .size(80.dp)
                        .clip(RoundedCornerShape(12.dp)),
                    contentScale = ContentScale.Crop
                )
            }
        }
    }
}

@Composable
fun FullPostView(post: Post) {
    Column(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        // Title
        Text(
            text = post.title,
            fontSize = 24.sp,
            fontWeight = FontWeight.Bold,
            color = Color.Black
        )

        // Summary
        Text(
            text = post.summary,
            fontSize = 14.sp,
            fontStyle = FontStyle.Italic,
            color = Color.Black.copy(alpha = 0.8f)
        )

        // Image
        post.imageUrl?.let { imageUrl ->
            val serverURL = "http://185.96.221.52:8080"
            val fullUrl = serverURL + imageUrl
            val cachedBitmap = ImageCache.shared.get(fullUrl)

            if (cachedBitmap != null) {
                Image(
                    bitmap = cachedBitmap.asImageBitmap(),
                    contentDescription = "Post image",
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 8.dp, bottom = 0.dp)
                        .clip(RoundedCornerShape(12.dp)),
                    contentScale = ContentScale.FillWidth
                )
            }
        }

        // Body text with markdown rendering
        Text(
            text = processBodyText(post.body),
            color = Color.Black,
            lineHeight = 20.sp
        )

        // Metadata
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            post.locationTag?.let { location ->
                Text(
                    text = "📍 $location",
                    fontSize = 12.sp,
                    color = Color.Black.copy(alpha = 0.6f)
                )
            }

            Spacer(modifier = Modifier.weight(1f))

            Text(
                text = formatDate(post.createdAt),
                fontSize = 12.sp,
                color = Color.Black.copy(alpha = 0.6f)
            )
        }

        if (post.aiGenerated) {
            Text(
                text = "✨ AI Generated",
                fontSize = 12.sp,
                color = Color(0xFF9C27B0) // Purple
            )
        }
    }
}

/**
 * Process markdown-style body text.
 * Removes image references, formats headings and bullet points.
 */
fun processBodyText(text: String): androidx.compose.ui.text.AnnotatedString {
    // Remove image markdown: ![alt](url)
    val imagePattern = """!\[.*?\]\(.*?\)""".toRegex()
    val cleaned = text.replace(imagePattern, "")

    return buildAnnotatedString {
        val lines = cleaned.split("\n")

        for ((index, line) in lines.withIndex()) {
            val trimmedLine = line.trim()

            when {
                trimmedLine.isEmpty() -> {
                    // Empty line - add spacing
                    if (index > 0) append("\n")
                }
                trimmedLine.startsWith("## ") -> {
                    // H2 heading - bold and larger
                    if (length > 0) append("\n")
                    withStyle(SpanStyle(fontSize = 18.sp, fontWeight = FontWeight.Bold)) {
                        append(trimmedLine.substring(3))
                    }
                    append("\n")
                }
                trimmedLine.startsWith("- ") -> {
                    // Bullet point
                    if (length > 0) append("\n")
                    append("• ${trimmedLine.substring(2)}")
                    append("\n")
                }
                else -> {
                    // Regular paragraph text
                    if (length > 0) append(" ")
                    append(trimmedLine)
                }
            }
        }
    }
}

/**
 * Format ISO date string to readable format.
 */
fun formatDate(dateString: String): String {
    return try {
        val inputFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US)
        inputFormat.timeZone = TimeZone.getTimeZone("UTC")
        val date = inputFormat.parse(dateString)

        val outputFormat = SimpleDateFormat("MMM d, yyyy h:mm a", Locale.US)
        outputFormat.format(date ?: Date())
    } catch (e: Exception) {
        dateString
    }
}
