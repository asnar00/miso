# image caching Android/e/OS implementation

*Three-tier cache architecture using LruCache and Bitmap for efficient image storage*

## File Location

`apps/firefly/product/client/imp/eos/app/src/main/kotlin/com/miso/noobtest/ImageCache.kt`

## Three-Tier Architecture

```kotlin
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.util.LruCache

object ImageCache {
    private const val RAW_DATA_CACHE_SIZE = 500 * 1024 * 1024  // 500 MB
    private const val THUMBNAIL_CACHE_SIZE = 20 * 1024 * 1024   // 20 MB
    private const val FULL_IMAGE_CACHE_SIZE = 100 * 1024 * 1024 // 100 MB

    // Tier 1: Raw compressed image data (JPG/PNG bytes)
    private val rawDataCache = object : LruCache<String, ByteArray>(RAW_DATA_CACHE_SIZE) {
        override fun sizeOf(key: String, value: ByteArray): Int {
            return value.size
        }
    }

    // Tier 2: Decoded thumbnails (80x80 pixels)
    private val thumbnailCache = object : LruCache<String, Bitmap>(THUMBNAIL_CACHE_SIZE) {
        override fun sizeOf(key: String, value: Bitmap): Int {
            return value.byteCount
        }
    }

    // Tier 3: Decoded full-size images (LRU eviction)
    private val fullImageCache = object : LruCache<String, Bitmap>(FULL_IMAGE_CACHE_SIZE) {
        override fun sizeOf(key: String, value: Bitmap): Int {
            return value.byteCount
        }
    }

    // Get raw data (compressed bytes)
    fun getRawData(url: String): ByteArray? {
        return rawDataCache.get(url)
    }

    // Set raw data
    fun setRawData(url: String, data: ByteArray) {
        rawDataCache.put(url, data)
    }

    // Get thumbnail (80x80)
    fun getThumbnail(url: String): Bitmap? {
        val key = "$url:thumb"

        // Check thumbnail cache
        thumbnailCache.get(key)?.let { return it }

        // Generate from raw data if available
        val rawData = getRawData(url) ?: return null
        val fullBitmap = BitmapFactory.decodeByteArray(rawData, 0, rawData.size) ?: return null

        // Resize to thumbnail
        val thumbnail = Bitmap.createScaledBitmap(fullBitmap, 80, 80, true)

        // Cache and return
        thumbnailCache.put(key, thumbnail)
        return thumbnail
    }

    // Get full image
    fun getFullImage(url: String): Bitmap? {
        // Check full image cache
        fullImageCache.get(url)?.let { return it }

        // Decode from raw data if available
        val rawData = getRawData(url) ?: return null
        val image = BitmapFactory.decodeByteArray(rawData, 0, rawData.size) ?: return null

        // Cache and return
        fullImageCache.put(url, image)
        return image
    }

    // Preload images (download raw data, generate thumbnails)
    suspend fun preload(urls: List<String>) {
        urls.forEach { urlString ->
            // Skip if already cached
            if (getRawData(urlString) != null) return@forEach

            try {
                val url = URL(urlString)
                val connection = url.openConnection() as HttpURLConnection
                connection.connect()

                val data = connection.inputStream.readBytes()

                // Store raw data
                setRawData(urlString, data)

                // Pre-generate thumbnail (cheap and useful)
                getThumbnail(urlString)

                // Don't pre-decode full image (waste of memory)
            } catch (e: Exception) {
                Logger.error("[ImageCache] Failed to preload $urlString: ${e.message}")
            }
        }
    }

    // Clear all caches (useful for testing/debugging)
    fun clearAll() {
        rawDataCache.evictAll()
        thumbnailCache.evictAll()
        fullImageCache.evictAll()
    }
}
```

## Integration with Coil

For better integration with Jetpack Compose, use Coil with custom caching:

```kotlin
// Configure Coil to use our custom cache
val imageLoader = ImageLoader.Builder(context)
    .memoryCache {
        MemoryCache.Builder(context)
            .maxSizePercent(0.25)
            .build()
    }
    .diskCache {
        DiskCache.Builder()
            .directory(context.cacheDir.resolve("image_cache"))
            .maxSizeBytes(500 * 1024 * 1024) // 500 MB
            .build()
    }
    .build()

// Use in composable
AsyncImage(
    model = ImageRequest.Builder(LocalContext.current)
        .data(imageUrl)
        .memoryCacheKey(imageUrl)
        .diskCacheKey(imageUrl)
        .build(),
    contentDescription = description,
    imageLoader = imageLoader
)
```

## Alternative: Pure LruCache Implementation

If not using Coil, integrate with AsyncImage like this:

```kotlin
@Composable
fun CachedImage(
    url: String,
    contentDescription: String,
    modifier: Modifier = Modifier,
    isThumbnail: Boolean = false
) {
    var bitmap by remember { mutableStateOf<Bitmap?>(null) }
    var loading by remember { mutableStateOf(true) }

    LaunchedEffect(url) {
        withContext(Dispatchers.IO) {
            bitmap = if (isThumbnail) {
                ImageCache.getThumbnail(url)
            } else {
                ImageCache.getFullImage(url)
            }

            // If not in cache, download
            if (bitmap == null) {
                try {
                    val urlObj = URL(url)
                    val connection = urlObj.openConnection() as HttpURLConnection
                    connection.connect()
                    val data = connection.inputStream.readBytes()

                    ImageCache.setRawData(url, data)
                    bitmap = if (isThumbnail) {
                        ImageCache.getThumbnail(url)
                    } else {
                        ImageCache.getFullImage(url)
                    }
                } catch (e: Exception) {
                    Logger.error("[CachedImage] Failed to load $url: ${e.message}")
                }
            }

            loading = false
        }
    }

    if (loading) {
        CircularProgressIndicator(modifier = modifier)
    } else if (bitmap != null) {
        Image(
            bitmap = bitmap!!.asImageBitmap(),
            contentDescription = contentDescription,
            modifier = modifier,
            contentScale = ContentScale.Crop
        )
    } else {
        // Placeholder for error
        Box(
            modifier = modifier.background(Color.Gray.copy(alpha = 0.3f))
        )
    }
}
```

## Usage in PostView

```kotlin
// Compact view - use thumbnail
CachedImage(
    url = "$serverURL${post.imageUrl}",
    contentDescription = post.title,
    modifier = Modifier.size(80.dp),
    isThumbnail = true
)

// Expanded view - use full image
CachedImage(
    url = "$serverURL${post.imageUrl}",
    contentDescription = post.title,
    modifier = Modifier.fillMaxWidth(),
    isThumbnail = false
)
```

## Memory Calculations

- **80×80 thumbnail** = 80 × 80 × 4 = 25,600 bytes (~25 KB)
- **2000×1500 image** = 2000 × 1500 × 4 = 12,000,000 bytes (~12 MB)
- **4000×3000 image** = 4000 × 3000 × 4 = 48,000,000 bytes (~48 MB)

LruCache automatically manages eviction based on `byteCount` for Bitmaps.

## Key Android-Specific Decisions

1. **LruCache**: Android's built-in memory cache with automatic LRU eviction
2. **Bitmap.byteCount**: Use for accurate memory size calculation
3. **BitmapFactory.decodeByteArray**: Decode compressed image data to Bitmap
4. **Bitmap.createScaledBitmap**: Resize images for thumbnails
5. **Suspending functions**: Use coroutines for async image loading
6. **Dispatchers.IO**: Perform network/disk operations on IO thread
7. **Object singleton**: Single instance accessible throughout app
8. **LaunchedEffect**: Trigger image loading when composable appears

## Required Dependencies

```kotlin
dependencies {
    // If using Coil
    implementation("io.coil-kt:coil-compose:2.5.0")
}
```

## Required Imports

```kotlin
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.util.LruCache
import java.net.URL
import java.net.HttpURLConnection
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
```

## Performance Benefits

1. **Raw data cache**: Avoid repeated network downloads (500 MB holds 100+ images)
2. **Thumbnail cache**: Keep all compact views instant (20 MB holds 400+ thumbnails)
3. **Full image cache**: Recent expanded images load instantly from memory
4. **Fast re-decode**: When full image evicted, can re-decode from raw data in ~10-30ms
5. **LRU eviction**: Automatic memory management based on actual usage patterns

This three-tier system provides the same performance benefits as iOS while using Android-native caching mechanisms.
