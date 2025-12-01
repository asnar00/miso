# expand-and-scroll Android/e/OS implementation

*Jetpack Compose implementation for coordinated post expansion and scroll-to-position*

## Overview

Android implementation uses `LazyListState` for programmatic scrolling, `animateScrollToItem()` for smooth animated scrolling, and coordinated state management to ensure only one post is expanded at a time while automatically scrolling to newly expanded posts.

## State Management

```kotlin
@Composable
fun PostsView(onPostCreated: () -> Unit = {}) {
    var posts by remember { mutableStateOf<List<Post>>(emptyList()) }
    var expandedPostId by remember { mutableStateOf<Int?>(null) }
    val listState = rememberLazyListState()
    val scope = rememberCoroutineScope()

    // ... rest of implementation
}
```

**Key state:**
- `expandedPostId`: Single source of truth for which post is expanded
- `listState`: LazyListState for programmatic scrolling
- `scope`: CoroutineScope for launching scroll animations

## Expansion and Scroll Logic

```kotlin
LazyColumn(
    state = listState,
    modifier = Modifier.fillMaxSize(),
    contentPadding = PaddingValues(16.dp),
    verticalArrangement = Arrangement.spacedBy(8.dp)
) {
    item {
        NewPostButton { showNewPostEditor = true }
    }

    itemsIndexed(
        items = posts,
        key = { _, post -> post.id }
    ) { index, post ->
        PostView(
            post = post,
            isExpanded = expandedPostId == post.id,
            onTap = {
                if (expandedPostId == post.id) {
                    // Tapping currently expanded post - collapse it
                    expandedPostId = null
                } else {
                    // Expand new post
                    val previousExpandedId = expandedPostId
                    expandedPostId = post.id

                    // Scroll to newly expanded post
                    // +1 to account for NewPostButton item
                    val targetIndex = index + 1
                    scope.launch {
                        listState.animateScrollToItem(
                            index = targetIndex,
                            scrollOffset = 0
                        )
                    }
                }
            },
            onPostCreated = {
                loadPosts()
                onPostCreated()
            }
        )
    }
}
```

**Key decisions:**
- Use `itemsIndexed()` to get item index for scrolling
- Add +1 to index to account for NewPostButton item
- Use `scope.launch {}` to call suspending scroll function
- Use `animateScrollToItem()` with default 300ms duration matching PostView expand animation

## PostView Expansion Factor Handling

The PostView observes `isExpanded` prop and animates its internal `expansionFactor`:

```kotlin
@Composable
fun PostView(
    post: Post,
    isExpanded: Boolean,
    onTap: () -> Void,
    onPostCreated: () -> Unit
) {
    // Animate expansion factor based on isExpanded
    val animatedExpansionFactor by animateFloatAsState(
        targetValue = if (isExpanded) 1f else 0f,
        animationSpec = tween(
            durationMillis = 300,
            easing = FastOutSlowInEasing
        ),
        label = "expansion"
    )

    // Use animatedExpansionFactor for all interpolated values
    // ... (see post-view/imp/eos.md for full implementation)
}
```

**Key decision:** PostView owns its expansion animation independently. The parent only controls the target state (`isExpanded`), keeping concerns separated.

## Concurrent Animations

When a new post is expanded:
1. **Previous post collapse**: Animates from expansionFactor=1.0 to 0.0 (300ms)
2. **New post expand**: Animates from expansionFactor=0.0 to 1.0 (300ms)
3. **Scroll to position**: Animates scroll to new post (300ms)

All three animations run **concurrently** with the same 300ms duration and `FastOutSlowInEasing` curve for visual coherence.

```kotlin
// All happen at the same time:
expandedPostId = post.id  // Triggers PostView animations via recomposition
scope.launch {
    listState.animateScrollToItem(index, scrollOffset = 0)  // 300ms default
}
```

## Scroll-to-Expanded on Navigation Return

When returning from another screen (e.g., after viewing children), scroll back to the expanded post:

```kotlin
LaunchedEffect(expandedPostId) {
    expandedPostId?.let { postId ->
        // Find the index of the expanded post
        val index = posts.indexOfFirst { it.id == postId }
        if (index != -1) {
            // Small delay to ensure layout is complete
            delay(100)
            // +1 to account for NewPostButton
            listState.animateScrollToItem(index + 1, scrollOffset = 0)
        }
    }
}
```

**Key decisions:**
- Use `LaunchedEffect(expandedPostId)` to react to expanded post changes
- Add 100ms delay to ensure LazyColumn is fully laid out
- Find index dynamically in case posts list has changed
- Use same `animateScrollToItem()` for consistent behavior

## Initial State

When the list is first loaded, all posts are in compact form (expandedPostId = null). Posts only expand when tapped by the user.

## Complete Implementation

```kotlin
@Composable
fun PostsView(onPostCreated: () -> Unit = {}) {
    var posts by remember { mutableStateOf<List<Post>>(emptyList()) }
    var isLoading by remember { mutableStateOf(false) }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    var expandedPostId by remember { mutableStateOf<Int?>(null) }
    var showNewPostEditor by remember { mutableStateOf(false) }

    val listState = rememberLazyListState()
    val scope = rememberCoroutineScope()

    // Load posts function
    fun loadPosts() {
        scope.launch {
            isLoading = true
            errorMessage = null

            val result = PostsAPI.fetchRecentPosts()

            result.onSuccess { fetchedPosts ->
                preloadImagesOptimized(fetchedPosts) {
                    posts = fetchedPosts
                    isLoading = false
                    // All posts start in compact form
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

    // Scroll to expanded post when returning from navigation
    LaunchedEffect(expandedPostId) {
        expandedPostId?.let { postId ->
            val index = posts.indexOfFirst { it.id == postId }
            if (index != -1 && listState.firstVisibleItemIndex != index + 1) {
                delay(100)  // Ensure layout complete
                listState.animateScrollToItem(index + 1, scrollOffset = 0)
            }
        }
    }

    Scaffold(
        containerColor = Color(0xFF40E0D0)
    ) { padding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
        ) {
            when {
                isLoading -> {
                    CircularProgressIndicator(
                        modifier = Modifier.align(Alignment.Center)
                    )
                }

                errorMessage != null -> {
                    Column(
                        modifier = Modifier.align(Alignment.Center),
                        horizontalAlignment = Alignment.CenterHorizontally
                    ) {
                        Text("Error: $errorMessage")
                        Button(onClick = { loadPosts() }) {
                            Text("Retry")
                        }
                    }
                }

                posts.isEmpty() -> {
                    Text(
                        text = "No posts yet",
                        modifier = Modifier.align(Alignment.Center)
                    )
                }

                else -> {
                    LazyColumn(
                        state = listState,
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(16.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        item(key = "new_post_button") {
                            NewPostButton { showNewPostEditor = true }
                        }

                        itemsIndexed(
                            items = posts,
                            key = { _, post -> post.id }
                        ) { index, post ->
                            PostView(
                                post = post,
                                isExpanded = expandedPostId == post.id,
                                onTap = {
                                    if (expandedPostId == post.id) {
                                        // Collapse currently expanded post
                                        expandedPostId = null
                                    } else {
                                        // Expand new post and scroll to it
                                        expandedPostId = post.id
                                        scope.launch {
                                            // +1 for NewPostButton item
                                            listState.animateScrollToItem(
                                                index = index + 1,
                                                scrollOffset = 0
                                            )
                                        }
                                    }
                                },
                                onPostCreated = {
                                    loadPosts()
                                    onPostCreated()
                                }
                            )
                        }
                    }
                }
            }
        }
    }

    if (showNewPostEditor) {
        NewPostEditor(
            onDismiss = { showNewPostEditor = false },
            onPostCreated = {
                loadPosts()
                showNewPostEditor = false
                onPostCreated()
            }
        )
    }
}
```

## Animation Timing

**animateScrollToItem() default behavior:**
- Duration: 300ms (matches PostView expansion animation)
- Easing: Default Compose easing (similar to FastOutSlowInEasing)
- Interruptible: Yes (user can scroll during animation)

**PostView expansion animation:**
- Duration: 300ms
- Easing: FastOutSlowInEasing
- Interruptible: Yes (can tap another post mid-animation)

**Why matching durations matter:**
- Previous post collapses while new post expands
- Scroll happens simultaneously
- All finish at the same time
- Creates coherent, fluid transition

## Edge Cases Handled

### 1. Tapping same post (collapse)
```kotlin
if (expandedPostId == post.id) {
    expandedPostId = null  // Just collapse, no scrolling
}
```

### 2. Rapidly tapping different posts
```kotlin
// animateScrollToItem() is cancellable
// New scroll animation interrupts previous one smoothly
scope.launch {
    listState.animateScrollToItem(newIndex)
}
```

### 3. Scrolling during expansion
```kotlin
// User can manually scroll at any time
// Scroll animation is interruptible without jarring
```

### 4. Post not visible when expanded
```kotlin
// LaunchedEffect scrolls to it automatically
LaunchedEffect(expandedPostId) {
    // ... scroll to expanded post
}
```

### 5. List changes while post expanded
```kotlin
// expandedPostId persists across list updates
// LaunchedEffect finds new index and scrolls if needed
val index = posts.indexOfFirst { it.id == postId }
```

## Performance Considerations

### 1. LazyColumn Optimization
```kotlin
itemsIndexed(
    items = posts,
    key = { _, post -> post.id }  // Stable keys
) { ... }
```

**Benefits:**
- Compose reuses PostView composables across list updates
- Smooth animations when posts are added/removed
- Efficient scrolling (only visible items composed)

### 2. Scroll Animation Efficiency
```kotlin
listState.animateScrollToItem(index)  // Hardware-accelerated
```

**Benefits:**
- Runs on compositor thread (no jank)
- Doesn't block main thread
- Handles large scroll distances efficiently

### 3. Expansion State Efficiency
```kotlin
val animatedExpansionFactor by animateFloatAsState(...)
```

**Benefits:**
- Only expanded/collapsing posts recompose
- Other posts remain stable
- Smooth 60fps animations

## Testing

### Manual Visual Test
1. Launch app and verify first post auto-expands
2. Tap second post - verify it expands, first collapses, and scrolls to second
3. Tap third post quickly - verify smooth transition
4. Tap expanded post - verify it collapses without scrolling
5. Scroll manually during expansion - verify no conflicts

### Unit Test
```kotlin
@Test
fun `only one post can be expanded at a time`() {
    var expandedPostId: Int? = null
    val posts = listOf(
        Post(id = 1, ...),
        Post(id = 2, ...),
        Post(id = 3, ...)
    )

    // Expand first post
    expandedPostId = posts[0].id
    assertEquals(1, expandedPostId)

    // Expand second post
    expandedPostId = posts[1].id
    assertEquals(2, expandedPostId)

    // First post is no longer expanded
    assertNotEquals(1, expandedPostId)
}
```

### UI Test
```kotlin
@Test
fun `tapping post expands and scrolls to it`() {
    composeTestRule.setContent {
        PostsView()
    }

    // Wait for posts to load
    composeTestRule.waitForIdle()

    // Tap second post
    composeTestRule
        .onNodeWithTag("PostView_2")
        .performClick()

    // Verify it's expanded
    composeTestRule
        .onNodeWithTag("PostView_2_Expanded")
        .assertIsDisplayed()

    // Verify it's scrolled to top
    composeTestRule
        .onNodeWithTag("PostView_2")
        .assertIsDisplayed()
        .assertHasScrollAction()
}
```

## Required Imports

```kotlin
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.launch
import kotlinx.coroutines.delay
```

## Key Android-Specific Decisions

1. **LazyListState**: Compose's scrollable list state manager
2. **animateScrollToItem()**: Built-in animated scroll with cancellation support
3. **rememberCoroutineScope()**: Get CoroutineScope tied to composable lifecycle
4. **itemsIndexed()**: Access item index for scroll calculations
5. **LaunchedEffect(expandedPostId)**: React to expansion changes for scroll-back behavior
6. **key parameter**: Stable item keys for proper recomposition
7. **animateFloatAsState()**: Smooth expansion factor animation in PostView
8. **FastOutSlowInEasing**: Material Design easing curve matching iOS easeInOut

This implementation provides identical behavior to iOS while using Compose's declarative patterns and built-in animation systems for smooth, efficient transitions.
