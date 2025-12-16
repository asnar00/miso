package com.miso.noobtest

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.launch

@Composable
fun PostsView() {
    var posts by remember { mutableStateOf<List<Post>>(emptyList()) }
    var isLoading by remember { mutableStateOf(false) }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    var expandedPostId by remember { mutableStateOf<Int?>(null) }
    var showNewPostEditor by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()
    val listState = rememberLazyListState()

    // Load posts on first composition
    LaunchedEffect(Unit) {
        isLoading = true
        val result = PostsAPI.shared.fetchRecentPosts()
        result.fold(
            onSuccess = { fetchedPosts ->
                posts = fetchedPosts
                isLoading = false
            },
            onFailure = { error ->
                errorMessage = error.message ?: "Unknown error"
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
                                isLoading = true
                                errorMessage = null
                                val result = PostsAPI.shared.fetchRecentPosts()
                                result.fold(
                                    onSuccess = { posts = it; isLoading = false },
                                    onFailure = { errorMessage = it.message ?: "Unknown error"; isLoading = false }
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
                    contentPadding = PaddingValues(start = 8.dp, end = 8.dp, top = 48.dp, bottom = 8.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    // New Post Button
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
                                    // Expand new post and scroll to it instantly (no animation)
                                    expandedPostId = post.id
                                    scope.launch {
                                        // Instant scroll - happens immediately while expand animation plays
                                        // +1 to account for NewPostButton item
                                        // scrollOffset = 0 aligns post top with content area top (48dp below screen top, just below camera)
                                        listState.scrollToItem(
                                            index = index + 1,
                                            scrollOffset = 0
                                        )
                                    }
                                }
                            }
                        )
                    }
                }
            }
        }
    }

    // New Post Editor modal
    if (showNewPostEditor) {
        NewPostEditor(
            onDismiss = { showNewPostEditor = false },
            onPostCreated = {
                showNewPostEditor = false
                // Reload posts after creating new one
                scope.launch {
                    isLoading = true
                    val result = PostsAPI.shared.fetchRecentPosts()
                    result.fold(
                        onSuccess = { fetchedPosts ->
                            posts = fetchedPosts
                            isLoading = false
                        },
                        onFailure = { error ->
                            errorMessage = error.message ?: "Unknown error"
                            isLoading = false
                        }
                    )
                }
            }
        )
    }
}

