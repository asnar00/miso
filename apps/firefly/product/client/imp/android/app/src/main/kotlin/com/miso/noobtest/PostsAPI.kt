package com.miso.noobtest

import android.graphics.Bitmap
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import java.io.ByteArrayOutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.util.UUID

/**
 * API client for fetching posts from the server.
 */
class PostsAPI private constructor() {
    companion object {
        val shared = PostsAPI()
    }

    private val serverURL = "http://185.96.221.52:8080"
    private val json = Json {
        ignoreUnknownKeys = true
        isLenient = true
    }

    /**
     * Fetch recent posts from server.
     * @param limit Maximum number of posts to fetch (default: 50)
     * @return Result with list of posts or error
     */
    suspend fun fetchRecentPosts(limit: Int = 50): Result<List<Post>> {
        return withContext(Dispatchers.IO) {
            try {
                Logger.info("[PostsAPI] Fetching recent posts (limit: $limit)")

                val url = URL("$serverURL/api/posts/recent?limit=$limit")
                val connection = url.openConnection() as HttpURLConnection
                connection.requestMethod = "GET"
                connection.connectTimeout = 5000
                connection.readTimeout = 5000

                val responseCode = connection.responseCode
                if (responseCode != 200) {
                    Logger.error("[PostsAPI] Server returned status $responseCode")
                    connection.disconnect()
                    return@withContext Result.failure(Exception("Server returned status $responseCode"))
                }

                val responseText = connection.inputStream.bufferedReader().use { it.readText() }
                connection.disconnect()

                val postsResponse = json.decodeFromString<PostsResponse>(responseText)
                Logger.info("[PostsAPI] Successfully fetched ${postsResponse.posts.size} posts")

                Result.success(postsResponse.posts)
            } catch (e: Exception) {
                Logger.error("[PostsAPI] Error fetching posts: ${e.message}")
                Result.failure(e)
            }
        }
    }

    /**
     * Fetch single post by ID.
     * @param id Post ID
     * @return Result with post or error
     */
    suspend fun fetchPost(id: Int): Result<Post> {
        return withContext(Dispatchers.IO) {
            try {
                Logger.info("[PostsAPI] Fetching post $id")

                val url = URL("$serverURL/api/posts/$id")
                val connection = url.openConnection() as HttpURLConnection
                connection.requestMethod = "GET"
                connection.connectTimeout = 5000
                connection.readTimeout = 5000

                val responseCode = connection.responseCode
                if (responseCode != 200) {
                    Logger.error("[PostsAPI] Server returned status $responseCode")
                    connection.disconnect()
                    return@withContext Result.failure(Exception("Server returned status $responseCode"))
                }

                val responseText = connection.inputStream.bufferedReader().use { it.readText() }
                connection.disconnect()

                val postResponse = json.decodeFromString<SinglePostResponse>(responseText)
                Logger.info("[PostsAPI] Successfully fetched post $id")

                Result.success(postResponse.post)
            } catch (e: Exception) {
                Logger.error("[PostsAPI] Error fetching post: ${e.message}")
                Result.failure(e)
            }
        }
    }

    /**
     * Create a new post with multipart form data.
     * @param title Post title
     * @param summary Post summary
     * @param body Post body text
     * @param image Optional image bitmap
     * @param parentId Optional parent post ID for replies
     * @return Result with new post ID or error
     */
    suspend fun createPost(
        title: String,
        summary: String,
        body: String,
        image: Bitmap?,
        parentId: Int? = null
    ): Result<Int> {
        return withContext(Dispatchers.IO) {
            try {
                Logger.info("[PostsAPI] Creating new post: $title")

                val url = URL("$serverURL/api/posts")
                val connection = url.openConnection() as HttpURLConnection

                val boundary = "Boundary-${UUID.randomUUID()}"

                connection.requestMethod = "POST"
                connection.doOutput = true
                connection.setRequestProperty("Content-Type", "multipart/form-data; boundary=$boundary")
                connection.connectTimeout = 30000  // 30 seconds for upload
                connection.readTimeout = 30000

                val outputStream = connection.outputStream
                val writer = outputStream.bufferedWriter()

                // Write title field
                writer.write("--$boundary\r\n")
                writer.write("Content-Disposition: form-data; name=\"title\"\r\n\r\n")
                writer.write("$title\r\n")

                // Write summary field
                writer.write("--$boundary\r\n")
                writer.write("Content-Disposition: form-data; name=\"summary\"\r\n\r\n")
                writer.write("$summary\r\n")

                // Write body field
                writer.write("--$boundary\r\n")
                writer.write("Content-Disposition: form-data; name=\"body\"\r\n\r\n")
                writer.write("$body\r\n")

                // Write parent_id if provided
                if (parentId != null) {
                    writer.write("--$boundary\r\n")
                    writer.write("Content-Disposition: form-data; name=\"parent_id\"\r\n\r\n")
                    writer.write("$parentId\r\n")
                }

                writer.flush()

                // Write image if provided
                if (image != null) {
                    writer.write("--$boundary\r\n")
                    writer.write("Content-Disposition: form-data; name=\"image\"; filename=\"image.jpg\"\r\n")
                    writer.write("Content-Type: image/jpeg\r\n\r\n")
                    writer.flush()

                    // Convert bitmap to JPEG bytes
                    val byteArrayOutputStream = ByteArrayOutputStream()
                    image.compress(Bitmap.CompressFormat.JPEG, 90, byteArrayOutputStream)
                    val imageBytes = byteArrayOutputStream.toByteArray()

                    outputStream.write(imageBytes)
                    outputStream.flush()

                    writer.write("\r\n")
                }

                // Write closing boundary
                writer.write("--$boundary--\r\n")
                writer.flush()
                writer.close()

                val responseCode = connection.responseCode
                if (responseCode != 200 && responseCode != 201) {
                    val error = connection.errorStream?.bufferedReader()?.use { it.readText() }
                    Logger.error("[PostsAPI] Server returned status $responseCode: $error")
                    connection.disconnect()
                    return@withContext Result.failure(Exception("Server returned status $responseCode"))
                }

                val responseText = connection.inputStream.bufferedReader().use { it.readText() }
                connection.disconnect()

                val postResponse = json.decodeFromString<SinglePostResponse>(responseText)
                Logger.info("[PostsAPI] Successfully created post with ID ${postResponse.post.id}")

                Result.success(postResponse.post.id)
            } catch (e: Exception) {
                Logger.error("[PostsAPI] Error creating post: ${e.message}")
                Result.failure(e)
            }
        }
    }
}
