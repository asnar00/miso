package com.miso.noobtest

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

// Post model matching server schema
@Serializable
data class Post(
    val id: Int,
    @SerialName("user_id") val userId: Int,
    @SerialName("parent_id") val parentId: Int? = null,
    val title: String,
    val summary: String,
    val body: String,
    @SerialName("image_url") val imageUrl: String? = null,
    @SerialName("created_at") val createdAt: String,
    val timezone: String,
    @SerialName("location_tag") val locationTag: String? = null,
    @SerialName("ai_generated") val aiGenerated: Boolean,
    @SerialName("author_name") val authorName: String? = null,
    @SerialName("child_count") val childCount: Int = 0
)

// API response structures
@Serializable
data class PostsResponse(
    val status: String,
    val posts: List<Post>
)

@Serializable
data class SinglePostResponse(
    val status: String,
    val post: Post
)
