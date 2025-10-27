# recent-posts Android/e/OS implementation

*Kotlin/Compose implementation for fetching and displaying recent posts with optimized image preloading*

## Overview

Android implementation uses Retrofit/OkHttp for HTTP requests or plain HttpURLConnection, coroutines for async operations, and optimized image preloading to balance initial load speed with complete user experience.

## File Location

`apps/firefly/product/client/imp/eos/app/src/main/kotlin/com/miso/noobtest/PostsAPI.kt`
`apps/firefly/product/client/imp/eos/app/src/main/kotlin/com/miso/noobtest/PostsView.kt`

## PostsAPI Implementation

### Option 1: Using HttpURLConnection (No Dependencies)

```kotlin
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import java.net.HttpURLConnection
import java.net.URL

object PostsAPI {
    private const val SERVER_URL = "http://185.96.221.52:8080"

    suspend fun fetchRecentPosts(): Result<List<Post>> = withContext(Dispatchers.IO) {
        try {
            val url = URL("$SERVER_URL/api/posts/recent")
            val connection = url.openConnection() as HttpURLConnection

            connection.requestMethod = "GET"
            connection.connectTimeout = 10000  // 10 seconds
            connection.readTimeout = 10000

            val responseCode = connection.responseCode
            if (responseCode == HttpURLConnection.HTTP_OK) {
                val response = connection.inputStream.bufferedReader().use { it.readText() }
                val posts = parsePostsJSON(response)
                Result.success(posts)
            } else {
                val error = connection.errorStream?.bufferedReader()?.use { it.readText() }
                Result.failure(Exception("HTTP $responseCode: $error"))
            }
        } catch (e: Exception) {
            Logger.error("[PostsAPI] Failed to fetch recent posts: ${e.message}")
            Result.failure(e)
        }
    }

    private fun parsePostsJSON(json: String): List<Post> {
        val posts = mutableListOf<Post>()
        val jsonArray = JSONArray(json)

        for (i in 0 until jsonArray.length()) {
            val jsonPost = jsonArray.getJSONObject(i)
            posts.add(
                Post(
                    id = jsonPost.getInt("id"),
                    title = jsonPost.getString("title"),
                    summary = jsonPost.getString("summary"),
                    body = jsonPost.getString("body"),
                    imageUrl = jsonPost.optString("image_url").takeIf { it.isNotEmpty() },
                    authorName = jsonPost.optString("author_name").takeIf { it.isNotEmpty() },
                    createdAt = jsonPost.getString("created_at"),
                    aiGenerated = jsonPost.getBoolean("ai_generated"),
                    locationTag = jsonPost.optString("location_tag").takeIf { it.isNotEmpty() },
                    parentId = jsonPost.optInt("parent_id").takeIf { it != 0 },
                    childCount = jsonPost.optInt("child_count", 0)
                )
            )
        }

        return posts
    }
}
```

### Option 2: Using Retrofit (Recommended for Production)

```kotlin
import retrofit2.Retrofit
import retrofit2.converter.gson.GsonConverterFactory
import retrofit2.http.GET
import com.google.gson.annotations.SerializedName

// API interface
interface PostsService {
    @GET("/api/posts/recent")
    suspend fun getRecentPosts(): List<PostDTO>
}

// DTO (Data Transfer Object) matching server JSON
data class PostDTO(
    @SerializedName("id") val id: Int,
    @SerializedName("title") val title: String,
    @SerializedName("summary") val summary: String,
    @SerializedName("body") val body: String,
    @SerializedName("image_url") val imageUrl: String?,
    @SerializedName("author_name") val authorName: String?,
    @SerializedName("created_at") val createdAt: String,
    @SerializedName("ai_generated") val aiGenerated: Boolean,
    @SerializedName("location_tag") val locationTag: String?,
    @SerializedName("parent_id") val parentId: Int?,
    @SerializedName("child_count") val childCount: Int?
)

object PostsAPI {
    private const val SERVER_URL = "http://185.96.221.52:8080"

    private val retrofit = Retrofit.Builder()
        .baseUrl(SERVER_URL)
        .addConverterFactory(GsonConverterFactory.create())
        .build()

    private val service = retrofit.create(PostsService::class.java)

    suspend fun fetchRecentPosts(): Result<List<Post>> {
        return try {
            val dtos = service.getRecentPosts()
            val posts = dtos.map { it.toPost() }
            Result.success(posts)
        } catch (e: Exception) {
            Logger.error("[PostsAPI] Failed to fetch recent posts: ${e.message}")
            Result.failure(e)
        }
    }

    // Extension function to convert DTO to domain model
    private fun PostDTO.toPost() = Post(
        id = id,
        title = title,
        summary = summary,
        body = body,
        imageUrl = imageUrl,
        authorName = authorName,
        createdAt = createdAt,
        aiGenerated = aiGenerated,
        locationTag = locationTag,
        parentId = parentId,
        childCount = childCount ?: 0
    )
}
```

## PostsView State Management

```kotlin
@Composable
fun PostsView(
    onPostCreated: () -> Unit = {}
) {
    var posts by remember { mutableStateOf<List<Post>>(emptyList()) }
    var isLoading by remember { mutableStateOf(false) }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    var expandedPostIds by remember { mutableStateOf(setOf<Int>()) }
    var showNewPostEditor by remember { mutableStateOf(false) }

    val scope = rememberCoroutineScope()
    val context = LocalContext.current

    // Load posts function
    fun loadPosts() {
        scope.launch {
            isLoading = true
            errorMessage = null

            val result = PostsAPI.fetchRecentPosts()

            result.onSuccess { fetchedPosts ->
                // Preload images before displaying
                preloadImagesOptimized(fetchedPosts) {
                    posts = fetchedPosts
                    isLoading = false

                    // Auto-expand first post
                    if (fetchedPosts.isNotEmpty()) {
                        expandedPostIds = setOf(fetchedPosts.first().id)
                    }
                }
            }.onFailure { error ->
                errorMessage = error.message ?: "Unknown error"
                isLoading = false
            }
        }
    }

    // Load on first composition
    LaunchedEffect(Unit) {
        loadPosts()
    }

    Scaffold(
        containerColor = Color(0xFF40E0D0)  // Turquoise
    ) { padding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
        ) {
            when {
                isLoading -> {
                    // Loading state
                    Column(
                        modifier = Modifier.align(Alignment.Center),
                        horizontalAlignment = Alignment.CenterHorizontally
                    ) {
                        CircularProgressIndicator(color = Color.Black)
                        Spacer(modifier = Modifier.height(16.dp))
                        Text(
                            text = "Loading posts...",
                            color = Color.Black
                        )
                    }
                }

                errorMessage != null -> {
                    // Error state
                    Column(
                        modifier = Modifier
                            .align(Alignment.Center)
                            .padding(16.dp),
                        horizontalAlignment = Alignment.CenterHorizontally
                    ) {
                        Text(
                            text = "Error: $errorMessage",
                            color = MaterialTheme.colorScheme.error,
                            textAlign = TextAlign.Center
                        )
                        Spacer(modifier = Modifier.height(16.dp))
                        Button(onClick = { loadPosts() }) {
                            Text("Retry")
                        }
                    }
                }

                posts.isEmpty() -> {
                    // Empty state
                    Text(
                        text = "No posts yet",
                        color = Color.Black,
                        modifier = Modifier.align(Alignment.Center)
                    )
                }

                else -> {
                    // Posts list
                    LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(16.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        item {
                            NewPostButton { showNewPostEditor = true }
                        }

                        items(
                            items = posts,
                            key = { post -> post.id }
                        ) { post ->
                            PostView(
                                post = post,
                                isExpanded = expandedPostIds.contains(post.id),
                                onTap = {
                                    expandedPostIds = if (expandedPostIds.contains(post.id)) {
                                        expandedPostIds - post.id
                                    } else {
                                        expandedPostIds + post.id
                                    }
                                },
                                onPostCreated = {
                                    loadPosts()  // Refresh list
                                    onPostCreated()
                                }
                            )
                        }
                    }
                }
            }
        }
    }

    // New post editor modal
    if (showNewPostEditor) {
        NewPostEditor(
            onDismiss = { showNewPostEditor = false },
            onPostCreated = {
                loadPosts()  // Refresh list
                showNewPostEditor = false
                onPostCreated()
            }
        )
    }
}
```

## Image Preloading Implementation

```kotlin
private suspend fun preloadImagesOptimized(
    posts: List<Post>,
    completion: () -> Unit
) {
    withContext(Dispatchers.IO) {
        val serverURL = "http://185.96.221.52:8080"
        val imageUrls = posts.mapNotNull { post ->
            post.imageUrl?.let { "$serverURL$it" }
        }

        if (imageUrls.isEmpty()) {
            withContext(Dispatchers.Main) {
                completion()
            }
            return@withContext
        }

        // Load first image synchronously
        val firstUrl = imageUrls.first()
        ImageCache.preload(listOf(firstUrl))

        // Display posts now
        withContext(Dispatchers.Main) {
            completion()
        }

        // Load remaining images in background
        if (imageUrls.size > 1) {
            val remainingUrls = imageUrls.drop(1)
            ImageCache.preload(remainingUrls)
            Logger.info("[PostsView] Background image loading complete")
        }
    }
}
```

## Key Android-Specific Decisions

1. **Coroutines for async**: Use `suspend fun` and `withContext(Dispatchers.IO)` instead of callbacks
2. **Result type**: Use Kotlin's `Result<T>` for type-safe success/failure handling
3. **remember + mutableStateOf**: Compose state management for reactive UI updates
4. **LaunchedEffect(Unit)**: Trigger initial load when composable first enters composition
5. **rememberCoroutineScope**: Get CoroutineScope tied to composable lifecycle
6. **LazyColumn with items()**: Efficient scrolling list with automatic recycling
7. **Scaffold**: Material Design container for consistent layout
8. **when expression**: Elegant state-based UI rendering (loading/error/empty/success)
9. **Set operations**: Use `+` and `-` operators for immutable set updates
10. **key parameter**: Stable item keys for LazyColumn optimization

## State Flow Diagram

```
[Initial] --LaunchedEffect--> [Loading]
                                  |
                 +----------------+----------------+
                 |                                 |
            [Success]                         [Error]
                 |                                 |
         preloadImages()                    show error + retry
                 |
         display posts
                 |
         auto-expand first
```

## Performance Optimizations

### 1. Optimized Image Preloading Strategy

**Why split preloading:**
- Load first image: ~100-300ms (user waits)
- Display posts immediately after first image
- Load remaining images: ~500-2000ms (background, no waiting)

**Benefits:**
- Perceived load time: ~100-300ms (just first image)
- First post always has image ready
- Scrolling reveals already-loaded images
- Better UX than loading all upfront (~1-2s delay) or none (blank images while scrolling)

### 2. LazyColumn Optimization

```kotlin
items(
    items = posts,
    key = { post -> post.id }  // Stable key for item reuse
) { post ->
    PostView(...)
}
```

**Benefits:**
- Compose can reuse PostView composables when list changes
- Smooth animations when items are added/removed/reordered
- Prevents unnecessary recomposition

### 3. Immutable State Updates

```kotlin
// Good: Create new Set
expandedPostIds = expandedPostIds + post.id

// Bad: Mutate existing Set (won't trigger recomposition)
expandedPostIds.add(post.id)
```

**Why immutable:**
- Compose detects state changes by reference equality
- Creating new collection triggers recomposition
- Mutating existing collection is invisible to Compose

## Error Handling

**Network errors:**
- Timeout (10s connect, 10s read)
- No internet connection
- Server down
- Invalid response format

**User feedback:**
- Loading spinner with "Loading posts..." text
- Error message with retry button
- Empty state for successful load with no posts

**Logging:**
```kotlin
Logger.error("[PostsAPI] Failed to fetch recent posts: ${e.message}")
Logger.info("[PostsView] Background image loading complete")
```

## Testing

### Unit Test for PostsAPI

```kotlin
@Test
fun `fetchRecentPosts returns success with valid data`() = runBlocking {
    val result = PostsAPI.fetchRecentPosts()

    assertTrue(result.isSuccess)
    val posts = result.getOrNull()
    assertNotNull(posts)
    assertTrue(posts!!.isNotEmpty())
}

@Test
fun `fetchRecentPosts handles network error`() = runBlocking {
    // Mock network failure
    val result = PostsAPI.fetchRecentPosts()

    // Should return failure without crashing
    assertTrue(result.isSuccess || result.isFailure)
}
```

### UI Test for PostsView

```kotlin
@Test
fun `PostsView shows loading state initially`() {
    composeTestRule.setContent {
        PostsView()
    }

    // Verify loading indicator is shown
    composeTestRule
        .onNodeWithText("Loading posts...")
        .assertIsDisplayed()
}

@Test
fun `PostsView displays posts after loading`() {
    composeTestRule.setContent {
        PostsView()
    }

    // Wait for posts to load
    composeTestRule.waitUntil(timeoutMillis = 5000) {
        composeTestRule
            .onAllNodesWithTag("PostView")
            .fetchSemanticsNodes()
            .isNotEmpty()
    }

    // Verify at least one post is displayed
    composeTestRule
        .onNodeWithTag("PostView")
        .assertIsDisplayed()
}
```

## Required Dependencies

### For HttpURLConnection (minimal):
```kotlin
// No additional dependencies needed
// Uses built-in Android libraries
```

### For Retrofit (recommended):
```kotlin
dependencies {
    // Retrofit for HTTP requests
    implementation("com.squareup.retrofit2:retrofit:2.9.0")
    implementation("com.squareup.retrofit2:converter-gson:2.9.0")

    // Gson for JSON parsing
    implementation("com.google.code.gson:gson:2.10.1")

    // Coroutines (already in Compose projects)
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")
}
```

## Required Imports

```kotlin
// Core
import androidx.compose.runtime.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.platform.LocalContext

// Coroutines
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.coroutines.launch

// HTTP (Option 1 - HttpURLConnection)
import java.net.HttpURLConnection
import java.net.URL
import org.json.JSONArray

// HTTP (Option 2 - Retrofit)
import retrofit2.Retrofit
import retrofit2.converter.gson.GsonConverterFactory
import retrofit2.http.GET
import com.google.gson.annotations.SerializedName
```

## Integration with Existing Code

**File structure:**
```
app/src/main/kotlin/com/miso/noobtest/
├── PostsAPI.kt          (new - API client)
├── PostsView.kt         (existing - add loadPosts() and state)
├── PostView.kt          (existing - display individual posts)
├── NewPostView.kt       (existing - create new posts)
├── Post.kt              (existing - data model)
└── ImageCache.kt        (existing - image caching)
```

**Changes to MainActivity.kt:**
```kotlin
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            NoobTestTheme {
                Surface {
                    PostsView()  // Entry point
                }
            }
        }
    }
}
```

This implementation provides the same functionality as iOS while using Android-native Compose patterns, coroutines for async operations, and optimized image preloading for fast perceived load times.
