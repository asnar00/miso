package com.miso.noobtest

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.util.LruCache
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.withContext
import java.net.URL

/**
 * Image cache for preloading and caching decoded Bitmap objects.
 * Uses LruCache to automatically manage memory and evict old images under pressure.
 */
class ImageCache private constructor() {
    companion object {
        val shared = ImageCache()
    }

    // Calculate cache size as 1/8 of available heap memory
    private val maxMemory = (Runtime.getRuntime().maxMemory() / 1024).toInt() // in KB
    private val cacheSize = maxMemory / 8 // Use 1/8 of available memory

    private val cache = object : LruCache<String, Bitmap>(cacheSize) {
        override fun sizeOf(key: String, bitmap: Bitmap): Int {
            // Return size in KB
            return bitmap.byteCount / 1024
        }
    }

    fun get(url: String): Bitmap? {
        return cache.get(url)
    }

    fun set(url: String, bitmap: Bitmap) {
        cache.put(url, bitmap)
    }

    /**
     * Preload images from URLs in background.
     * Downloads and decodes images, storing them in cache.
     * @param urls List of image URLs to preload
     * @param completion Callback invoked on main thread when all images loaded
     */
    suspend fun preload(urls: List<String>, completion: () -> Unit) {
        withContext(Dispatchers.IO) {
            // Create async tasks for each image
            val tasks = urls.map { urlString ->
                async {
                    // Skip if already cached
                    if (get(urlString) != null) {
                        return@async
                    }

                    try {
                        val url = URL(urlString)
                        val connection = url.openConnection()
                        connection.connect()

                        val inputStream = connection.getInputStream()
                        val bitmap = BitmapFactory.decodeStream(inputStream)
                        inputStream.close()

                        if (bitmap != null) {
                            set(urlString, bitmap)
                            Logger.info("[ImageCache] Preloaded image: $urlString (${bitmap.byteCount / 1024}KB)")
                        }
                    } catch (e: Exception) {
                        Logger.error("[ImageCache] Failed to preload $urlString: ${e.message}")
                    }
                }
            }

            // Wait for all tasks to complete
            tasks.awaitAll()
        }

        // Invoke completion on main thread
        withContext(Dispatchers.Main) {
            completion()
        }
    }
}
