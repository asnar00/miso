# new-post Android/e/OS implementation

*Jetpack Compose + Kotlin implementation for creating new posts*

## File Location

`apps/firefly/product/client/imp/eos/app/src/main/kotlin/com/miso/noobtest/NewPostView.kt`

## Components

### NewPostButton

```kotlin
@Composable
fun NewPostButton(onTap: () -> Unit) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .clickable { onTap() }
            .padding(horizontal = 16.dp, vertical = 8.dp),
        colors = CardDefaults.cardColors(
            containerColor = Color.White.copy(alpha = 0.9f)
        ),
        shape = RoundedCornerShape(12.dp),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            horizontalArrangement = Arrangement.Start,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                imageVector = Icons.Default.AddCircle,
                contentDescription = "New post",
                modifier = Modifier.size(32.dp),
                tint = Color(0xFF40E0D0)  // Turquoise
            )
            Spacer(modifier = Modifier.width(12.dp))
            Text(
                text = "Create a new post",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
                color = Color.Black.copy(alpha = 0.7f)
            )
        }
    }
}
```

**Usage in PostsView:**
```kotlin
var showNewPostEditor by remember { mutableStateOf(false) }

LazyColumn {
    item {
        NewPostButton { showNewPostEditor = true }
    }
    items(posts) { post ->
        // ... post views ...
    }
}

if (showNewPostEditor) {
    NewPostEditor(
        onDismiss = { showNewPostEditor = false },
        onPostCreated = {
            loadPosts()  // Refresh list
            showNewPostEditor = false
        }
    )
}
```

### NewPostEditor

```kotlin
@Composable
fun NewPostEditor(
    onDismiss: () -> Unit,
    onPostCreated: () -> Unit,
    parentId: Int? = null
) {
    var title by remember { mutableStateOf("") }
    var summary by remember { mutableStateOf("") }
    var bodyText by remember { mutableStateOf("") }
    var selectedImage by remember { mutableStateOf<Bitmap?>(null) }
    var showImageSourceDialog by remember { mutableStateOf(false) }
    var isPosting by remember { mutableStateOf(false) }
    var postError by remember { mutableStateOf<String?>(null) }

    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    // Image picker launchers
    val cameraLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.TakePicturePreview()
    ) { bitmap ->
        bitmap?.let { selectedImage = it }
    }

    val galleryLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.GetContent()
    ) { uri ->
        uri?.let {
            val bitmap = MediaStore.Images.Media.getBitmap(context.contentResolver, it)
            selectedImage = bitmap
        }
    }
```

**Modal presentation:**
```kotlin
ModalBottomSheet(
    onDismissRequest = onDismiss,
    sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
    containerColor = Color(0xFF40E0D0)  // Turquoise background
) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("New Post") },
                navigationIcon = {
                    IconButton(onClick = onDismiss) {
                        Icon(Icons.Default.Close, "Cancel")
                    }
                },
                actions = {
                    TextButton(
                        onClick = { postNewPost(...) },
                        enabled = title.isNotEmpty() && !isPosting
                    ) {
                        if (isPosting) {
                            CircularProgressIndicator(modifier = Modifier.size(24.dp))
                        } else {
                            Text("Post", fontWeight = FontWeight.SemiBold)
                        }
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = Color.Transparent
                )
            )
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .verticalScroll(rememberScrollState())
                .padding(16.dp)
        ) {
            Card(
                modifier = Modifier.fillMaxWidth(),
                colors = CardDefaults.cardColors(
                    containerColor = Color.White.copy(alpha = 0.9f)
                ),
                shape = RoundedCornerShape(12.dp)
            ) {
                Column(modifier = Modifier.padding(16.dp)) {
                    // Title field
                    OutlinedTextField(
                        value = title,
                        onValueChange = { title = it },
                        placeholder = { Text("Title") },
                        textStyle = MaterialTheme.typography.headlineSmall.copy(
                            fontWeight = FontWeight.Bold
                        ),
                        modifier = Modifier.fillMaxWidth(),
                        singleLine = true,
                        colors = OutlinedTextFieldDefaults.colors(
                            unfocusedContainerColor = Color.Black.copy(alpha = 0.05f),
                            focusedContainerColor = Color.Black.copy(alpha = 0.05f)
                        )
                    )

                    Spacer(modifier = Modifier.height(8.dp))

                    // Summary field
                    OutlinedTextField(
                        value = summary,
                        onValueChange = { summary = it },
                        placeholder = { Text("Summary") },
                        textStyle = MaterialTheme.typography.bodyMedium.copy(
                            fontStyle = FontStyle.Italic
                        ),
                        modifier = Modifier.fillMaxWidth(),
                        singleLine = true,
                        colors = OutlinedTextFieldDefaults.colors(
                            unfocusedContainerColor = Color.Black.copy(alpha = 0.05f),
                            focusedContainerColor = Color.Black.copy(alpha = 0.05f)
                        )
                    )

                    Spacer(modifier = Modifier.height(8.dp))

                    // Image section
                    if (selectedImage != null) {
                        Box {
                            Image(
                                bitmap = selectedImage!!.asImageBitmap(),
                                contentDescription = "Selected image",
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .clip(RoundedCornerShape(12.dp)),
                                contentScale = ContentScale.FillWidth
                            )
                            IconButton(
                                onClick = { selectedImage = null },
                                modifier = Modifier
                                    .align(Alignment.TopEnd)
                                    .padding(8.dp)
                                    .background(
                                        Color.Black.copy(alpha = 0.6f),
                                        CircleShape
                                    )
                            ) {
                                Icon(
                                    Icons.Default.Close,
                                    "Remove image",
                                    tint = Color.White
                                )
                            }
                        }
                    } else {
                        Button(
                            onClick = { showImageSourceDialog = true },
                            modifier = Modifier.fillMaxWidth(),
                            colors = ButtonDefaults.buttonColors(
                                containerColor = Color.Black.copy(alpha = 0.05f),
                                contentColor = Color.Black.copy(alpha = 0.5f)
                            )
                        ) {
                            Icon(Icons.Default.AddAPhoto, "Add image")
                            Spacer(modifier = Modifier.width(8.dp))
                            Text("Image")
                        }
                    }

                    Spacer(modifier = Modifier.height(8.dp))

                    // Body field
                    OutlinedTextField(
                        value = bodyText,
                        onValueChange = { bodyText = it },
                        placeholder = { Text("Body") },
                        modifier = Modifier
                            .fillMaxWidth()
                            .heightIn(min = 200.dp),
                        textStyle = MaterialTheme.typography.bodyMedium,
                        colors = OutlinedTextFieldDefaults.colors(
                            unfocusedContainerColor = Color.Black.copy(alpha = 0.05f),
                            focusedContainerColor = Color.Black.copy(alpha = 0.05f)
                        )
                    )
                }
            }

            // Error message
            postError?.let { error ->
                Spacer(modifier = Modifier.height(16.dp))
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    colors = CardDefaults.cardColors(
                        containerColor = Color.White.copy(alpha = 0.9f)
                    )
                ) {
                    Text(
                        text = error,
                        color = MaterialTheme.colorScheme.error,
                        style = MaterialTheme.typography.bodySmall,
                        modifier = Modifier.padding(16.dp)
                    )
                }
            }
        }
    }
}

// Image source selection dialog
if (showImageSourceDialog) {
    AlertDialog(
        onDismissRequest = { showImageSourceDialog = false },
        title = { Text("Choose Image Source") },
        text = null,
        confirmButton = {
            TextButton(onClick = {
                cameraLauncher.launch(null)
                showImageSourceDialog = false
            }) {
                Text("Camera")
            }
        },
        dismissButton = {
            Column {
                TextButton(onClick = {
                    galleryLauncher.launch("image/*")
                    showImageSourceDialog = false
                }) {
                    Text("Photo Library")
                }
                TextButton(onClick = { showImageSourceDialog = false }) {
                    Text("Cancel")
                }
            }
        }
    )
}
```

**Posting logic:**
```kotlin
fun postNewPost(
    title: String,
    summary: String,
    bodyText: String,
    selectedImage: Bitmap?,
    parentId: Int?,
    onSuccess: () -> Unit,
    onError: (String) -> Unit
) {
    scope.launch {
        try {
            PostsAPI.createPost(
                title = title,
                summary = summary.ifEmpty { "No summary" },
                body = bodyText.ifEmpty { "No content" },
                image = selectedImage,
                parentId = parentId
            )
            Logger.info("[NewPost] Post created successfully")
            onSuccess()
        } catch (e: Exception) {
            Logger.error("[NewPost] Failed to create post: ${e.message}")
            onError("Failed to post: ${e.message}")
        }
    }
}
```

## Required Dependencies

In `app/build.gradle.kts`:

```kotlin
dependencies {
    // Activity result contracts for image picking
    implementation("androidx.activity:activity-compose:1.8.0")

    // For image loading and manipulation
    implementation("io.coil-kt:coil-compose:2.5.0")
}
```

## Required Permissions

In `AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
<!-- For Android 12 and below -->
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"
    android:maxSdkVersion="32" />
```

## PostsAPI Extension

Add to `PostsAPI.kt`:

```kotlin
suspend fun createPost(
    title: String,
    summary: String,
    body: String,
    image: Bitmap?,
    parentId: Int?
): Result<Int> {
    return withContext(Dispatchers.IO) {
        try {
            val url = URL("$SERVER_URL/api/posts/create")
            val connection = url.openConnection() as HttpURLConnection

            // Multipart form data implementation
            // (see posts/operations/create-post/imp/eos.md for full implementation)

            Result.success(postId)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
}
```

## Required Imports

```kotlin
import androidx.compose.material3.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import android.graphics.Bitmap
import android.provider.MediaStore
```
