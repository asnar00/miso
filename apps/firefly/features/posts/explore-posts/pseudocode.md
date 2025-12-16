# explore posts implementation
*platform-agnostic tree navigation logic*

## Overview

Enables users to navigate through the hierarchical post tree using NavigationStack with a unified PostsListView component. Posts with children display a white chevron arrow with black outline on the right edge. Swiping left on such posts navigates to a child posts view. Users can tap a back button or use standard edge swipe to return. Root view preserves scroll position when navigating away and back.

## Core Data Structures

**Navigation Path:**
- Type: List of Int (post IDs)
- Purpose: Track the navigation hierarchy
- Initial: Empty list (root level)
- Push parent post ID when navigating to children
- Pop when navigating back

**Post with Child Count:**
- id: Int
- title: String
- childCount: Int or null
- ... other post fields

## Navigation Functions

**Check if Post Has Children:**
```
function hasChildren(post: Post) -> Boolean:
    return (post.childCount != null) and (post.childCount > 0)
```

**Navigate to Children:**
```
function navigateToChildren(postId: Int):
    // Push post ID onto navigation path
    navigationPath.append(postId)
    // NavigationStack automatically shows ChildPostsView for this ID
```

**Navigate Back to Parent:**
```
function navigateBack():
    // Remove last ID from navigation path
    navigationPath.removeLast()
    // NavigationStack automatically returns to previous view
```

**Fetch Posts (Unified):**
```
function fetchPosts(parentId: Int?) -> PostsResponse:
    if parentId == null:
        // Root level - fetch recent posts
        response = httpGet("/api/posts/recent?limit=50")
        return parseJSON(response) as PostsResponse
    else:
        // Child level - fetch children of specific post
        response = httpGet("/api/posts/" + parentId + "/children")
        return parseJSON(response) as ChildrenResponse

PostsResponse:
    - status: String
    - posts: List<Post>

ChildrenResponse:
    - status: String
    - postId: Int
    - children: List<Post>
    - count: Int
```

**Conditional Fetching (State Preservation):**
```
function onViewAppear(parentId: Int?, currentPosts: List<Post>):
    if parentId != null:
        // Child view: always fetch parent and posts
        fetchParentPost(parentId)
        fetchPosts(parentId)
    else if currentPosts.isEmpty:
        // Root view: only fetch if empty (preserves scroll position)
        fetchPosts(null)
    // If root view has posts, do nothing - keeps scroll position
```

**Fetch Parent Post:**
```
function fetchParentPost(postId: Int) -> Post:
    // API call to get specific post for nav bar title
    response = httpGet("/api/posts/" + postId)
    return parseJSON(response).post
```

## UI Layout Structure

**Navigation Stack (Thin Wrapper):**
```
PostsView:
    NavigationStack(path: navigationPath):
        // Root level - parentPostId = null
        PostsListView(
            parentPostId: null,
            navigationPath: navigationPath (binding)
        )

        // Navigation destination for each pushed ID
        .navigationDestination(for: Int):
            PostsListView(
                parentPostId: pushedId,
                navigationPath: navigationPath (binding)
            )
```

**Posts List View (Unified Component):**
```
PostsListView(parentPostId: Int?):
    if parentPostId == null:
        // Root level - no custom navigation bar
        StandardNavigationBar
    else:
        // Child level - custom back button
        CustomBackButton("< {parentPostTitle}")

    // Add Post button conditional visibility and text
    if shouldShowAddPostButton(parentPostId, currentUserId):
        AddPostButton(text: getAddButtonText(parentPostId, parentPost))

    ScrollView:
        if posts.isEmpty:
            "No posts yet" message
        else:
            for each post in posts:
                PostView(post, onNavigateToChildren)

function shouldShowAddPostButton(parentPostId: Int?, currentUserEmail: String) -> Boolean:
    if parentPostId == null:
        // Root level - always show Add Post button
        return true

    // Child level - check if parent is a profile post and belongs to current user
    parentPost = fetchParentPost(parentPostId)

    // Profile posts have template = "profile"
    isProfilePost = (parentPost.template == "profile")

    // Check if profile belongs to current user by comparing emails
    belongsToCurrentUser = (parentPost.authorEmail == currentUserEmail)

    return isProfilePost and belongsToCurrentUser

function getAddButtonText(parentPostId: Int?, parentPost: Post?) -> String:
    // Child posts use "add sub-post", except profile children use "add post"
    if parentPostId != null:
        if parentPost?.template == "profile":
            return "add post"
        return "add sub-post"
    // Root level uses template-based text
    // ... (handled elsewhere based on context)
```

## Gesture Handling

**Swipe Left on Post with Children:**
```
onDragGesture(post: Post, translation: Vector):
    // Detect left swipe (minimum 30pt distance)
    if translation.x < -30 and hasChildren(post):
        navigateToChildren(post.id)
```

**Navigate Back:**
```
// Tap custom back button
onTapBackButton():
    navigateBack()
```

**No Custom Swipe-Right Gesture:**
```
// Removed to avoid conflict with image clip offset dragging in edit mode
// Users tap the back button to navigate back
```

## Visual Indicators

**Child Indicator (White Circle with Chevron):**
```
function shouldShowChildIndicator(post: Post) -> Boolean:
    return hasChildren(post)

function renderChildIndicator(isExpanded: Boolean):
    // White circle with two animated states:

    // Collapsed state:
    //   - 32pt diameter
    //   - X position: 350 + 6 + 32 - (32/2) = 372pt from left edge
    //   - Y position: vertically centered (currentHeight / 2)

    // Expanded state:
    //   - 42pt diameter
    //   - X position: 350 - 16 + 32 - (42/2) = 345pt from left edge
    //   - Y position: 16 + (42/2) = 37pt from top

    // Both states:
    //   - White fill: 95% opacity
    //   - Deep shadow: color black 40% opacity, radius 8pt, x-offset 0, y-offset 4pt
    //   - Black chevron.right icon: 20pt, bold weight

    // Animation:
    //   - Use expansionFactor (0.0 to 1.0) to interpolate between states
    //   - Size: lerp(32, 42, expansionFactor)
    //   - X position: lerp(collapsedX, expandedX, expansionFactor)
    //   - Y position: lerp(collapsedY, expandedY, expansionFactor)
    //   - Synchronized with card expansion animation (0.3s easeInOut)
```

**Custom Back Button:**
```
function renderBackButton(parentTitle: String):
    // White oval capsule containing:
    //   - chevron.left icon (20pt, semibold, black)
    //   - parent post title (17pt, semibold, black, line limit 1)
    // Horizontal padding: 12pt, Vertical padding: 8pt
    // Background: white 90% opacity
    // Positioned in navigation bar leading area
```

## Animation

**Navigation Transitions:**
```
// NavigationStack provides automatic slide transitions
// Duration: ~300ms
// Easing: Standard system easing
```

## Integration with view-posts

The explore-posts feature refactors and extends view-posts:

**Patching Instructions:**

1. **Create PostsListView.swift** (new unified component):
   - Takes `parentPostId: Int?`, `onPostCreated: () -> Void`, `@Binding navigationPath: [Int]`
   - When `parentPostId == null`: root level, fetch from `/api/posts/recent?limit=50`
   - When `parentPostId != null`: child level, fetch from `/api/posts/{parentPostId}/children`
   - Conditional fetching in `.onAppear`: only fetch root posts if `posts.isEmpty`
   - Conditional toolbar: only show custom back button when `parentPostId != null`
   - Conditional Add Post button: show based on `shouldShowAddPostButton()` logic
   - Access current user email from `Storage.shared.getLoginState().email`
   - Compare parent post's `authorEmail` with current user's email
   - Check parent post's `template` field to identify profile posts (template == "profile")
   - Add to Xcode project using project.pbxproj

2. **Simplify PostsView.swift** to thin wrapper:
   - Add `@State navigationPath: [Int] = []`
   - Wrap in `NavigationStack(path: $navigationPath)`
   - Use `PostsListView(parentPostId: nil, ...)` for root
   - Add `.navigationDestination(for: Int.self)` showing `PostsListView(parentPostId: pushedId, ...)`

3. **Modify PostView.swift** to add child indicator and navigation gesture:
   - Add `onNavigateToChildren: ((Int) -> Void)?` parameter
   - Add child indicator overlay: white circle (42pt, 90% opacity) with black stroke (3pt) and black chevron (20pt, bold)
   - Position indicator at right edge with -16pt trailing padding
   - Add `.gesture(DragGesture(minimumDistance: 30))` to detect left swipe and call `onNavigateToChildren?(post.id)`

4. **Remove ChildPostsView.swift** from project (no longer needed - unified into PostsListView)

**Key Points:**
- PostsView is now a thin NavigationStack wrapper
- PostsListView handles both root and child posts (unified component)
- Root view preserves scroll position via conditional fetching
- No custom swipe-right gesture (uses standard NavigationStack edge swipe)
- Both root and child use the same PostView component

## Error Handling

**Failed Child Fetch:**
```
onFetchChildrenError(error):
    // Show error message in child view
    // Display "Error loading posts" with error text
    // Show "Retry" button
    // Keep navigation (don't pop back)
```

**Empty Child List:**
```
onEmptyChildList():
    // Navigate normally
    // Show "No posts yet" message
```

## Testing

**Manual Test:**
1. View posts list with posts that have children (childCount > 0)
2. Verify white arrow with black outline appears on right edge of posts with children
3. Swipe left on post with children → child list appears with parent title in back button
4. Scroll down in root view, navigate to child, tap back button
5. Verify root view scroll position is preserved (not reset to top)
6. Navigate to child view, swipe from left edge → return to parent
7. Verify ScrollView scrolls normally (up/down) without interference
8. Navigate multiple levels deep
9. Verify smooth NavigationStack animations

**Edge Cases:**
- Post with childCount = 0 or null (no arrow shown)
- Fetch child posts fails (shows error message with retry)
- Empty child list (shows "No posts yet")
- Parent post fetch fails (back button shows "...")
- Root view scroll position preserved across navigation (conditional fetching)
