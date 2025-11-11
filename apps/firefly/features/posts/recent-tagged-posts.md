# recent tagged posts
*fetch and display recent posts filtered by template tags and user*

This feature provides a unified way to fetch and display lists of posts filtered by their template tags (post type) and optionally by user.

**Parameters:**

- **tags**: Array of template names to filter by (e.g., `["post"]`, `["profile"]`, `["query"]`)
- **by_user**: Either `"any"` (all users) or `"current"` (logged-in user only)

**Current usage:**

- App startup shows recent users: `tags=["profile"]`, `by_user="any"`
- Future uses: my queries (`tags=["query"]`, `by_user="current"`), recent posts (`tags=["post"]`, `by_user="any"`), etc.

**Sorting:**

- For profiles: Sorted by user's last_activity timestamp (most recent first)
- For other posts: Sorted by post creation date (newest first)

**Loading behavior:**

- Show turquoise background (RGB 64/224/208) with black "ᕦ(ツ)ᕤ" logo (1/12 screen width) above loading message
- Loading message adapts to content type: "Loading users..." for profiles, "Loading posts..." for posts, "Loading queries..." for queries
- Once posts are fetched, preload the first image before displaying the list
- Continue loading remaining images in the background
- If fetching fails, show an error message with a retry button on the turquoise background

**Display:**

- Posts displayed using the view-posts component
- All posts start in compact view
- Tap any post to expand and read full content
- For profiles: swipe left (or tap navigation button) to see all posts by that user
- For profiles: no "Add Post" button is shown

**Fetch limit:** 50 most recent items
