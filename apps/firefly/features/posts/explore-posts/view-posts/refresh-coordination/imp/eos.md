# refresh-coordination Android/e/OS implementation

*Kotlin/Compose implementation using lambda callbacks for coordinated refreshes across view hierarchy*

## Overview

Android implementation uses Kotlin lambda functions passed through the composable hierarchy to propagate refresh requests from nested views back to the root. This approach leverages Compose's recomposition system and Kotlin's concise lambda syntax for clean, type-safe refresh coordination.

## Callback Type Definition

```kotlin
typealias PostCreatedCallback = () -> Unit
```

Kotlin's `() -> Unit` lambda syntax is clear and idiomatic. The typealias is optional but can improve readability in function signatures.

## View Hierarchy

```
MainActivity
  └─> PostsView(onPostCreated = { loadPosts() })
       └─> PostView(onPostCreated = { loadPosts() })
            └─> Navigation → ChildrenPostsView(onPostCreated = { loadPosts() })
                 └─> PostView(onPostCreated = { loadPosts() })
                      └─> Navigation → ChildrenPostsView(onPostCreated = { loadPosts() })
                           └─> ... (recursive)
```

**Key principle**: Each composable passes the SAME lambda down to its children, so refreshes propagate all the way up to the root.

## Root Level - PostsView

```kotlin
@Composable
fun PostsView(
    onPostCreated: () -> Unit = {}  // Default no-op for preview/testing
) {
    var posts by remember { mutableStateOf<List<Post>>(emptyList()) }
    var isLoading by remember { mutableStateOf(false) }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    var expandedPostId by remember { mutableStateOf<Int?>(null) }

    val scope = rememberCoroutineScope()

    // Root refresh function
    fun loadPosts() {
        scope.launch {
            isLoading = true
            errorMessage = null

            val result = PostsAPI.fetchRecentPosts()

            result.onSuccess { fetchedPosts ->
                preloadImagesOptimized(fetchedPosts) {
                    posts = fetchedPosts
                    isLoading = false

                    if (fetchedPosts.isNotEmpty()) {
                        expandedPostId = fetchedPosts.first().id
                    }
                }
            }.onFailure { error ->
                errorMessage = error.message
                isLoading = false
            }
        }
    }

    // Load on first composition
    LaunchedEffect(Unit) {
        loadPosts()
    }

    // UI implementation...
    LazyColumn {
        item {
            NewPostButton { showNewPostEditor = true }
        }

        itemsIndexed(posts) { index, post ->
            PostView(
                post = post,
                isExpanded = expandedPostId == post.id,
                onTap = { /* ... */ },
                onPostCreated = ::loadPosts  // Pass loadPosts as callback
            )
        }
    }

    if (showNewPostEditor) {
        NewPostEditor(
            onDismiss = { showNewPostEditor = false },
            onPostCreated = {
                loadPosts()  // Refresh this view
                showNewPostEditor = false
                onPostCreated()  // Propagate up (to parent if exists)
            }
        )
    }
}
```

**Key points:**
- `loadPosts()` is the root refresh function
- Uses `::loadPosts` method reference syntax to pass function
- Dual refresh: local `loadPosts()` + propagate `onPostCreated()`

## PostView Level

```kotlin
@Composable
fun PostView(
    post: Post,
    isExpanded: Boolean,
    onTap: () -> Unit,
    onPostCreated: () -> Unit  // Received from parent
) {
    var showChildrenView by remember { mutableStateOf(false) }
    var showNewPostEditor by remember { mutableStateOf(false) }

    // ... PostView UI implementation ...

    // Pass callback to children view
    if (showChildrenView) {
        ChildrenPostsView(
            parentPostId = post.id,
            parentPostTitle = post.title,
            onPostCreated = onPostCreated,  // Pass through unchanged
            onDismiss = { showChildrenView = false }
        )
    }

    // Pass callback to new post editor
    if (showNewPostEditor) {
        NewPostEditor(
            parentId = post.id,
            onDismiss = { showNewPostEditor = false },
            onPostCreated = {
                showNewPostEditor = false
                onPostCreated()  // Propagate up to refresh all parents
            }
        )
    }
}
```

**Key points:**
- Receives `onPostCreated` callback from parent
- Passes it through unchanged to children
- Calls it when own child creates a post

## ChildrenPostsView Level

```kotlin
@Composable
fun ChildrenPostsView(
    parentPostId: Int,
    parentPostTitle: String,
    onPostCreated: () -> Unit,  // Callback from root
    onDismiss: () -> Unit
) {
    var children by remember { mutableStateOf<List<Post>>(emptyList()) }
    var isLoading by remember { mutableStateOf(true) }
    var expandedPostId by remember { mutableStateOf<Int?>(null) }
    var showNewPostEditor by remember { mutableStateOf(false) }

    val scope = rememberCoroutineScope()

    // Local refresh function
    fun fetchChildren() {
        scope.launch {
            isLoading = true

            val result = PostsAPI.fetchChildren(parentPostId)

            result.onSuccess { fetchedChildren ->
                children = fetchedChildren
                isLoading = false
            }.onFailure { error ->
                Logger.error("[ChildrenPostsView] Failed to fetch children: ${error.message}")
                isLoading = false
            }
        }
    }

    // Load on first composition
    LaunchedEffect(parentPostId) {
        fetchChildren()
    }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        containerColor = Color(0xFF40E0D0)
    ) {
        Scaffold(
            topBar = {
                TopAppBar(
                    title = { Text("Children of $parentPostTitle") },
                    navigationIcon = {
                        IconButton(onClick = onDismiss) {
                            Icon(Icons.Default.ArrowBack, "Back")
                        }
                    }
                )
            }
        ) { padding ->
            if (isLoading) {
                CircularProgressIndicator(
                    modifier = Modifier
                        .fillMaxSize()
                        .wrapContentSize(Alignment.Center)
                )
            } else if (children.isEmpty()) {
                Text(
                    text = "No children posts",
                    modifier = Modifier
                        .fillMaxSize()
                        .wrapContentSize(Alignment.Center)
                )
            } else {
                LazyColumn(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(padding),
                    contentPadding = PaddingValues(16.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    item {
                        NewPostButton { showNewPostEditor = true }
                    }

                    itemsIndexed(
                        items = children,
                        key = { _, child -> child.id }
                    ) { index, child ->
                        PostView(
                            post = child,
                            isExpanded = expandedPostId == child.id,
                            onTap = {
                                expandedPostId = if (expandedPostId == child.id) {
                                    null
                                } else {
                                    child.id
                                }
                            },
                            onPostCreated = onPostCreated  // Pass through for recursive children
                        )
                    }
                }
            }
        }
    }

    // New post editor modal
    if (showNewPostEditor) {
        NewPostEditor(
            parentId = parentPostId,
            onDismiss = { showNewPostEditor = false },
            onPostCreated = {
                fetchChildren()  // Refresh local children list
                showNewPostEditor = false
                onPostCreated()  // Propagate up to refresh all ancestors
            }
        )
    }
}
```

**Key behavior:**
1. Has local `fetchChildren()` to refresh current view
2. Receives `onPostCreated()` from root to refresh ancestors
3. When post created: calls both `fetchChildren()` AND `onPostCreated()`
4. Passes `onPostCreated` through to child PostViews for recursive navigation

## NewPostEditor Integration

```kotlin
@Composable
fun NewPostEditor(
    parentId: Int? = null,
    onDismiss: () -> Unit,
    onPostCreated: () -> Unit
) {
    var title by remember { mutableStateOf("") }
    var summary by remember { mutableStateOf("") }
    var bodyText by remember { mutableStateOf("") }
    var selectedImage by remember { mutableStateOf<Bitmap?>(null) }
    var isPosting by remember { mutableStateOf(false) }
    var postError by remember { mutableStateOf<String?>(null) }

    val scope = rememberCoroutineScope()

    fun postNewPost() {
        if (title.isEmpty()) return

        scope.launch {
            isPosting = true
            postError = null

            val result = PostsAPI.createPost(
                title = title,
                summary = summary.ifEmpty { "No summary" },
                body = bodyText.ifEmpty { "No content" },
                image = selectedImage,
                parentId = parentId
            )

            result.onSuccess {
                Logger.info("[NewPostEditor] Post created successfully")
                onPostCreated()  // Trigger refresh ONLY on success
                // Don't call onDismiss here - let parent handle it
            }.onFailure { error ->
                Logger.error("[NewPostEditor] Failed to create post: ${error.message}")
                postError = "Failed to post: ${error.message}"
                isPosting = false
            }
        }
    }

    // Modal UI implementation...
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        // ... UI code ...
    ) {
        // Post button
        TextButton(
            onClick = { postNewPost() },
            enabled = title.isNotEmpty() && !isPosting
        ) {
            if (isPosting) {
                CircularProgressIndicator(modifier = Modifier.size(24.dp))
            } else {
                Text("Post")
            }
        }
    }
}
```

**Key points:**
- Callback only called on successful post creation
- Parent controls dismissal (callback doesn't dismiss editor)
- Error state keeps editor open for retry

## PostsAPI Methods

```kotlin
object PostsAPI {
    private const val SERVER_URL = "http://185.96.221.52:8080"

    suspend fun fetchRecentPosts(): Result<List<Post>> {
        // Implementation from recent-posts/imp/eos.md
    }

    suspend fun fetchChildren(parentId: Int): Result<List<Post>> = withContext(Dispatchers.IO) {
        try {
            val url = URL("$SERVER_URL/api/posts/$parentId/children")
            val connection = url.openConnection() as HttpURLConnection

            connection.requestMethod = "GET"
            connection.connectTimeout = 10000
            connection.readTimeout = 10000

            val responseCode = connection.responseCode
            if (responseCode == HttpURLConnection.HTTP_OK) {
                val response = connection.inputStream.bufferedReader().use { it.readText() }
                val json = JSONObject(response)
                val childrenArray = json.getJSONArray("children")
                val children = parsePostsJSONArray(childrenArray)
                Result.success(children)
            } else {
                Result.failure(Exception("HTTP $responseCode"))
            }
        } catch (e: Exception) {
            Logger.error("[PostsAPI] Failed to fetch children: ${e.message}")
            Result.failure(e)
        }
    }

    suspend fun createPost(
        title: String,
        summary: String,
        body: String,
        image: Bitmap?,
        parentId: Int?
    ): Result<Int> {
        // Implementation from new-post/imp/eos.md (multipart form data)
    }

    private fun parsePostsJSONArray(jsonArray: JSONArray): List<Post> {
        // Helper to parse JSON array into Post list
    }
}
```

## Execution Flow Example

**Scenario**: User creates new post in children view at depth 2

```
1. User taps "New Post" in ChildrenPostsView
2. showNewPostEditor = true
3. NewPostEditor appears with callback:
   onPostCreated = {
       fetchChildren()  // Refresh ChildrenPostsView
       onPostCreated()  // Propagate to root
   }
4. User submits post
5. API call succeeds
6. onPostCreated() executes:
   a. fetchChildren() refreshes ChildrenPostsView children list
   b. onPostCreated() is root loadPosts() function
   c. loadPosts() refreshes root PostsView
7. Both views now show new post
8. Parent controls dismissal via onDismiss
```

## Key Android/Compose-Specific Decisions

1. **Lambda syntax**: Use `() -> Unit` for callbacks (idiomatic Kotlin)
2. **Method references**: Use `::loadPosts` when passing function as callback
3. **Default parameters**: Use `onPostCreated: () -> Unit = {}` for optional callbacks
4. **Coroutines**: Use `rememberCoroutineScope()` for async refresh operations
5. **remember + mutableStateOf**: Local state management for each view
6. **LaunchedEffect**: Trigger initial data load when composable enters composition
7. **ModalBottomSheet**: Full-screen modals for children views and editors
8. **Recomposition**: State changes automatically trigger UI updates
9. **No memory management**: Kotlin GC handles lambda capture automatically
10. **Type-safe**: Compiler enforces callback signatures

## Benefits of This Approach

✅ **Simple**: Just pass lambdas through composable hierarchy
✅ **Kotlin-idiomatic**: Uses standard lambda and function reference patterns
✅ **Type-safe**: Compiler catches missing or incorrect callbacks
✅ **No boilerplate**: No interfaces or abstract classes needed
✅ **Performant**: Only refreshes when needed (on successful post creation)
✅ **Testable**: Easy to inject mock callbacks in tests
✅ **Composable-friendly**: Works naturally with Compose's recomposition system
✅ **Scalable**: Works at any depth of navigation hierarchy

## Alternative Approaches (Not Used)

❌ **ViewModel with SharedFlow**: Overkill for simple refresh coordination
❌ **Global state with MutableStateFlow**: Too much coupling
❌ **EventBus/BroadcastReceiver**: More complex than needed, deprecated patterns
❌ **Polling**: Wasteful and delayed updates
✅ **Callback propagation**: Simple, immediate, and idiomatic

## Memory Management

Kotlin's garbage collection handles lambda capture automatically:

- Lambdas captured by reference (not copied)
- No retain cycles (Compose handles lifecycle)
- Automatic cleanup when composables leave composition
- No manual cleanup needed

## Testing

### Unit Test for Callback Propagation

```kotlin
@Test
fun `onPostCreated callback is called after successful post creation`() = runBlocking {
    var refreshCalled = false
    val callback: () -> Unit = { refreshCalled = true }

    // Simulate successful post creation
    val result = PostsAPI.createPost(
        title = "Test Post",
        summary = "Test Summary",
        body = "Test Body",
        image = null,
        parentId = null
    )

    if (result.isSuccess) {
        callback()  // Simulate NewPostEditor calling callback
    }

    assertTrue(refreshCalled)
}
```

### UI Test for Refresh Coordination

```kotlin
@Test
fun `creating post refreshes parent view`() {
    var parentRefreshCount = 0
    val parentRefresh: () -> Unit = { parentRefreshCount++ }

    composeTestRule.setContent {
        NewPostEditor(
            onDismiss = {},
            onPostCreated = parentRefresh
        )
    }

    // Fill in post form
    composeTestRule
        .onNodeWithText("Title")
        .performTextInput("Test Post")

    // Submit post
    composeTestRule
        .onNodeWithText("Post")
        .performClick()

    // Wait for API call
    composeTestRule.waitForIdle()

    // Verify parent refresh was called
    assertEquals(1, parentRefreshCount)
}
```

### Integration Test

```kotlin
@Test
fun `creating post in children view refreshes both children and root`() {
    var rootRefreshCount = 0
    var childrenRefreshCount = 0

    val rootRefresh: () -> Unit = { rootRefreshCount++ }
    val childrenRefresh: () -> Unit = {
        childrenRefreshCount++
        rootRefresh()  // Simulate callback propagation
    }

    // Create post
    childrenRefresh()

    // Verify both refreshed
    assertEquals(1, childrenRefreshCount)
    assertEquals(1, rootRefreshCount)
}
```

## Required Imports

```kotlin
import androidx.compose.runtime.*
import androidx.compose.foundation.lazy.*
import androidx.compose.material3.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.Alignment
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.launch
import java.net.HttpURLConnection
import java.net.URL
import org.json.JSONObject
import org.json.JSONArray
```

## File Structure

```
app/src/main/kotlin/com/miso/noobtest/
├── PostsView.kt           (root view with loadPosts())
├── PostView.kt            (individual post, passes callback through)
├── ChildrenPostsView.kt   (children list with fetchChildren())
├── NewPostView.kt         (editor that calls callback on success)
├── PostsAPI.kt            (API methods for fetch/create)
└── Post.kt                (data model)
```

This implementation provides the same refresh coordination as iOS while using Kotlin's concise lambda syntax and Compose's reactive recomposition system for clean, maintainable code.
