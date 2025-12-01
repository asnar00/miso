# recent tagged posts
*fetch and display recent posts filtered by template tags and user*

This feature provides a unified way to fetch and display lists of posts filtered by their template tags (post type) and optionally by user.

**Parameters:**

- **tags**: Array of template names to filter by (e.g., `["post"]`, `["profile"]`, `["query"]`); [] means "all posts regardless of template name"
- **by_user**: Either `"any"` (all users) or `"current"` (logged-in user only)

**Current usage:**

- App startup shows user's saved queries: `tags=["query"]`, `by_user="current"`
- Other uses: recent users (`tags=["profile"]`, `by_user="any"`), recent posts (`tags=["post"]`, `by_user="any"`), etc.

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
- For queries: swipe left (or tap navigation button) to execute the search
- Empty state message adapts to template (e.g., "No queries yet", "No posts yet") using template's plural_name

**Add New Button:**

- Show "Add <Template>" button at top of list (e.g., "Add Post", "Add Query")
- Button text uses singular form of the template name
- When tapped: create new post with that template_name, add to top of list, expand it, and open for editing
- **Exception**: Don't show button when tags includes "profile" (profiles are special user-level posts)

**Fetch limit:** 50 most recent items
