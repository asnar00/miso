package com.miso.noobtest

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import java.net.HttpURLConnection
import java.net.URL

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
}
