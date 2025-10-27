package com.miso.noobtest

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.media.ExifInterface
import android.util.LruCache
import androidx.compose.runtime.mutableStateOf
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.ByteArrayInputStream
import java.net.HttpURLConnection
import java.net.URL

/**
 * Three-tier image cache for efficient image storage and retrieval.
 *
 * Tier 1: Raw compressed image data (JPG/PNG bytes) - 500 MB
 * Tier 2: Decoded thumbnails (80x80 pixels) - 20 MB (not currently used)
 * Tier 3: Decoded full-size images (LRU eviction) - 500 MB (~30 images)
 */
object ImageCache {
    private const val RAW_DATA_CACHE_SIZE = 500 * 1024 * 1024  // 500 MB
    private const val THUMBNAIL_CACHE_SIZE = 20 * 1024 * 1024   // 20 MB (not used currently)
    private const val FULL_IMAGE_CACHE_SIZE = 500 * 1024 * 1024 // 500 MB (~30 images)

    // Reactive state map for thumbnails - PostViews can observe these
    private val thumbnailStates = mutableMapOf<String, androidx.compose.runtime.MutableState<Bitmap?>>()

    // Reactive state map for full images
    private val fullImageStates = mutableMapOf<String, androidx.compose.runtime.MutableState<Bitmap?>>()

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

    /**
     * Get observable state for a thumbnail.
     * PostViews can observe this state to reactively update when thumbnail becomes available.
     */
    fun getThumbnailState(url: String): androidx.compose.runtime.State<Bitmap?> {
        synchronized(thumbnailStates) {
            return thumbnailStates.getOrPut(url) {
                mutableStateOf(getThumbnail(url))
            }
        }
    }

    /**
     * Get observable state for a full image.
     * PostViews can observe this state to reactively update when full image becomes available.
     */
    fun getFullImageState(url: String): androidx.compose.runtime.State<Bitmap?> {
        synchronized(fullImageStates) {
            return fullImageStates.getOrPut(url) {
                mutableStateOf(getFullImage(url))
            }
        }
    }

    /**
     * Get raw compressed data for an image
     */
    fun getRawData(url: String): ByteArray? {
        return rawDataCache.get(url)
    }

    /**
     * Get image aspect ratio without full decode (fast)
     * Returns width/height ratio, or 1.0 if not available
     * (No EXIF handling needed - server images are pre-rotated)
     */
    fun getAspectRatio(url: String): Float {
        val rawData = getRawData(url) ?: return 1f

        val options = BitmapFactory.Options().apply {
            inJustDecodeBounds = true
        }
        BitmapFactory.decodeByteArray(rawData, 0, rawData.size, options)

        return if (options.outWidth > 0 && options.outHeight > 0) {
            options.outWidth.toFloat() / options.outHeight.toFloat()
        } else {
            1f
        }
    }

    /**
     * Store raw compressed data for an image
     */
    fun setRawData(url: String, data: ByteArray) {
        rawDataCache.put(url, data)
    }

    /**
     * Get thumbnail (80x80 center-cropped) for an image
     * Generates from raw data if not cached
     * Uses inSampleSize to decode at lower resolution for efficiency
     * (No EXIF handling needed - server images are pre-rotated)
     */
    fun getThumbnail(url: String): Bitmap? {
        val key = "$url:thumb"

        // Check thumbnail cache
        thumbnailCache.get(key)?.let {
            Logger.info("[ImageCache] Thumbnail from cache: $url")
            return it
        }

        // Generate from raw data if available
        val rawData = getRawData(url) ?: run {
            Logger.info("[ImageCache] No raw data for: $url")
            return null
        }

        Logger.info("[ImageCache] Generating thumbnail for: $url")

        // Get dimensions without decoding full image
        val options = BitmapFactory.Options().apply {
            inJustDecodeBounds = true
        }
        BitmapFactory.decodeByteArray(rawData, 0, rawData.size, options)

        // Calculate inSampleSize (decode at lower resolution)
        val minDimension = minOf(options.outWidth, options.outHeight)
        val targetSize = 320  // Decode at ~320x320 for 80x80 thumbnail (4x oversample for quality)
        var inSampleSize = 1
        while (minDimension / (inSampleSize * 2) >= targetSize) {
            inSampleSize *= 2
        }

        // Decode bitmap at lower resolution (rotation already baked in by server)
        options.inJustDecodeBounds = false
        options.inSampleSize = inSampleSize
        val sampledBitmap = BitmapFactory.decodeByteArray(rawData, 0, rawData.size, options) ?: return null

        // Resize to thumbnail
        val thumbnail = resizeImage(sampledBitmap, targetSize = 80)

        // Release sampled bitmap
        if (sampledBitmap != thumbnail) {
            sampledBitmap.recycle()
        }

        // Cache and return
        thumbnailCache.put(key, thumbnail)
        Logger.info("[ImageCache] Thumbnail generated and cached: $url, isNull=${thumbnail == null}")

        // Update reactive state if it exists
        synchronized(thumbnailStates) {
            thumbnailStates[url]?.value = thumbnail
        }

        return thumbnail
    }

    /**
     * Check if full image is already decoded in cache (fast, no decoding)
     */
    fun hasFullImage(url: String): Bitmap? {
        return fullImageCache.get(url)
    }

    /**
     * Get full-size decoded image
     * Decodes from raw data if not cached
     * (No EXIF handling needed - server images are pre-rotated)
     */
    fun getFullImage(url: String): Bitmap? {
        // Check full image cache
        fullImageCache.get(url)?.let { return it }

        // Decode from raw data if available
        val rawData = getRawData(url) ?: return null

        // Decode bitmap (rotation already baked in by server)
        val image = BitmapFactory.decodeByteArray(rawData, 0, rawData.size) ?: return null

        // Cache and return
        fullImageCache.put(url, image)

        // Update reactive state if it exists
        synchronized(fullImageStates) {
            fullImageStates[url]?.value = image
        }

        return image
    }

    /**
     * Crop and resize image to target size (for thumbnails)
     * Crops a centered square from the image, then scales to targetSize x targetSize
     */
    private fun resizeImage(image: Bitmap, targetSize: Int = 80): Bitmap {
        val width = image.width
        val height = image.height

        // Determine the crop size (largest square that fits in the image)
        val cropSize = minOf(width, height)

        // Calculate the crop position (centered)
        val cropX = (width - cropSize) / 2
        val cropY = (height - cropSize) / 2

        // Crop to centered square
        val croppedBitmap = Bitmap.createBitmap(
            image,
            cropX,
            cropY,
            cropSize,
            cropSize
        )

        // Scale to target size with high-quality filtering
        val scaledBitmap = Bitmap.createScaledBitmap(
            croppedBitmap,
            targetSize,
            targetSize,
            true  // filter = true for high-quality scaling
        )

        // Release intermediate bitmap if it's not the same as input
        if (croppedBitmap != image && croppedBitmap != scaledBitmap) {
            croppedBitmap.recycle()
        }

        return scaledBitmap
    }

    /**
     * Preload thumbnails only (download raw data, generate thumbnails)
     * @param urls List of image URLs to preload
     */
    suspend fun preloadThumbnails(urls: List<String>) {
        withContext(Dispatchers.IO) {
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

                    // Pre-generate thumbnail
                    getThumbnail(urlString)

                    Logger.info("[ImageCache] Preloaded thumbnail $urlString (${data.size / 1024}KB)")
                } catch (e: Exception) {
                    Logger.error("[ImageCache] Failed to preload $urlString: ${e.message}")
                }
            }
        }
    }

    /**
     * Preload full images (download raw data, decode full images)
     * @param urls List of image URLs to preload
     */
    suspend fun preloadFullImages(urls: List<String>) {
        withContext(Dispatchers.IO) {
            urls.forEach { urlString ->
                // Skip if already cached
                if (getRawData(urlString) != null && getFullImage(urlString) != null) return@forEach

                try {
                    val url = URL(urlString)
                    val connection = url.openConnection() as HttpURLConnection
                    connection.connect()

                    val data = connection.inputStream.readBytes()

                    // Store raw data
                    setRawData(urlString, data)

                    // Pre-decode full image
                    getFullImage(urlString)

                    Logger.info("[ImageCache] Preloaded full image $urlString (${data.size / 1024}KB)")
                } catch (e: Exception) {
                    Logger.error("[ImageCache] Failed to preload $urlString: ${e.message}")
                }
            }
        }
    }

    /**
     * Preload images (download raw data, generate thumbnails) - legacy function
     * @param urls List of image URLs to preload
     */
    suspend fun preload(urls: List<String>) {
        preloadThumbnails(urls)
    }

    /**
     * Clear all caches (useful for testing/debugging)
     */
    fun clearAll() {
        rawDataCache.evictAll()
        thumbnailCache.evictAll()
        fullImageCache.evictAll()
    }
}
