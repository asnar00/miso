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
     * Fetch recent posts filtered by tags (template_name).
     * @param tags List of tags to filter by (e.g., ["post"], ["query"], ["profile"])
     * @param byUser "any" for all users, "current" for current user only
     * @param limit Maximum number of posts to fetch
     * @return Result with list of posts or error
     */
    suspend fun fetchRecentTaggedPosts(
        tags: List<String>,
        byUser: String = "any",
        limit: Int = 50
    ): Result<List<Post>> {
        return withContext(Dispatchers.IO) {
            try {
                val tagsParam = tags.joinToString(",")
                val userEmail = Storage.getLoginState().first ?: ""
                Logger.info("[PostsAPI] Fetching recent tagged posts (tags: $tagsParam, byUser: $byUser)")

                val url = URL("$serverURL/api/posts/recent-tagged?tags=$tagsParam&by_user=$byUser&user_email=$userEmail&limit=$limit")
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
                Logger.info("[PostsAPI] Successfully fetched ${postsResponse.posts.size} tagged posts")

                Result.success(postsResponse.posts)
            } catch (e: Exception) {
                Logger.error("[PostsAPI] Error fetching tagged posts: ${e.message}")
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

    /**
     * Update an existing post.
     * @param postId Post ID to update
     * @param title New title
     * @param summary New summary
     * @param body New body text
     * @return Result with updated post or error
     */
    suspend fun updatePost(
        postId: Int,
        title: String,
        summary: String,
        body: String
    ): Result<Post> {
        return withContext(Dispatchers.IO) {
            try {
                val userEmail = Storage.getLoginState().first ?: ""
                Logger.info("[PostsAPI] Updating post $postId")

                val url = URL("$serverURL/api/posts/update")
                val connection = url.openConnection() as HttpURLConnection

                connection.requestMethod = "POST"
                connection.doOutput = true
                connection.setRequestProperty("Content-Type", "application/x-www-form-urlencoded")
                connection.connectTimeout = 10000
                connection.readTimeout = 10000

                // Build form data
                val formData = StringBuilder()
                formData.append("post_id=${postId}")
                formData.append("&email=${java.net.URLEncoder.encode(userEmail, "UTF-8")}")
                formData.append("&title=${java.net.URLEncoder.encode(title, "UTF-8")}")
                formData.append("&summary=${java.net.URLEncoder.encode(summary, "UTF-8")}")
                formData.append("&body=${java.net.URLEncoder.encode(body, "UTF-8")}")

                connection.outputStream.use { os ->
                    os.write(formData.toString().toByteArray())
                }

                val responseCode = connection.responseCode
                if (responseCode != 200) {
                    val error = connection.errorStream?.bufferedReader()?.use { it.readText() }
                    Logger.error("[PostsAPI] Update failed with status $responseCode: $error")
                    connection.disconnect()
                    return@withContext Result.failure(Exception("Server returned status $responseCode"))
                }

                val responseText = connection.inputStream.bufferedReader().use { it.readText() }
                connection.disconnect()

                val postResponse = json.decodeFromString<SinglePostResponse>(responseText)
                Logger.info("[PostsAPI] Successfully updated post $postId")

                Result.success(postResponse.post)
            } catch (e: Exception) {
                Logger.error("[PostsAPI] Error updating post: ${e.message}")
                Result.failure(e)
            }
        }
    }
}
