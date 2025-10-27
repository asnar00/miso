# explore posts implementation
*platform-agnostic tree navigation logic*

## Overview

Enables users to navigate through the hierarchical post tree using NavigationStack. Posts with children display a white chevron arrow with black outline on the right edge. Swiping left on such posts navigates to a child posts view. Users can tap a back button or swipe right anywhere in the child view to return.

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

**Fetch Child Posts:**
```
function fetchChildPosts(parentId: Int) -> ChildrenResponse:
    // API call to get children of specific post
    response = httpGet("/api/posts/" + parentId + "/children")
    return parseJSON(response) as ChildrenResponse

ChildrenResponse:
    - status: String
    - postId: Int
    - children: List<Post>
    - count: Int
```

**Fetch Parent Post:**
```
function fetchParentPost(postId: Int) -> Post:
    // API call to get specific post for nav bar title
    response = httpGet("/api/posts/" + postId)
    return parseJSON(response).post
```

## UI Layout Structure

**Navigation Stack:**
```
NavigationStack(path: navigationPath):
    // Root level - shows all root posts
    PostsView(
        posts: allRootPosts,
        onNavigateToChildren: navigateToChildren
    )

    // Navigation destination for each pushed ID
    .navigationDestination(for: Int):
        ChildPostsView(
            parentPostId: pushedId,
            navigationPath: navigationPath (binding)
        )
```

**Child Posts View:**
```
ChildPostsView:
    - Navigation bar with custom back button
    - Back button shows: "< {parentPostTitle}"
    - ScrollView with child posts
    - "Create a new post" button at top
```

## Gesture Handling

**Swipe Left on Post with Children:**
```
onDragGesture(post: Post, translation: Vector):
    // Detect left swipe (minimum 30px distance)
    if translation.x < -30 and hasChildren(post):
        navigateToChildren(post.id)
```

**Swipe Right in Child View:**
```
onDragGesture(translation: Vector):
    // Detect right swipe (minimum 100px distance)
    // Works from anywhere in the child view
    if translation.x > 100:
        navigateBack()
```

**Tap Back Button:**
```
onTapBackButton():
    navigateBack()
```

## Visual Indicators

**Child Indicator (Right Arrow):**
```
function shouldShowChildIndicator(post: Post) -> Boolean:
    return hasChildren(post)

function renderChildIndicator():
    // White chevron.right icon, size 32pt
    // Positioned at right edge with -8pt trailing padding (straddles edge)
    // Black outline using 4 offset copies (±1pt in x and y)
    // Vertically and horizontally centered in post height
    // Only visible when post has children
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

The explore-posts feature wraps and extends view-posts:

**Patching Instructions:**

1. **Wrap PostsView in NavigationStack** (in ContentView or parent):
   - Add `@State navigationPath: [Int] = []`
   - Wrap PostsView in `NavigationStack(path: $navigationPath)`
   - Add `.navigationDestination(for: Int.self)` showing ChildPostsView

2. **Modify PostView** to add child indicator and navigation gesture:
   - Add `onNavigateToChildren: ((Int) -> Void)?` parameter
   - Add child indicator overlay (white chevron with black outline) when `(post.childCount ?? 0) > 0`
   - Add `.gesture(DragGesture(...))` to detect left swipe and call `onNavigateToChildren?(post.id)`

3. **Create ChildPostsView**:
   - Takes `parentPostId: Int` and `@Binding navigationPath: [Int]`
   - Fetches child posts from `/api/posts/{parentPostId}/children`
   - Fetches parent post from `/api/posts/{parentPostId}` for title
   - Shows custom back button with `.navigationBarBackButtonHidden(true)`
   - Adds `.highPriorityGesture(DragGesture())` for swipe-right-to-go-back

**Key Points:**
- PostsView shows root level posts
- ChildPostsView shows children of a specific post
- NavigationStack manages the view hierarchy
- Both use the same PostView component

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
    // Show "Create a new post" button
```

## Testing

**Manual Test:**
1. View posts list with posts that have children (childCount > 0)
2. Verify white arrow with black outline appears on right edge of posts with children
3. Swipe left on post with children → child list appears with parent title in back button
4. Tap back button → return to parent list
5. Navigate to child view, swipe right from anywhere → return to parent list
6. Navigate multiple levels deep
7. Verify NavigationStack animations

**Edge Cases:**
- Post with childCount = 0 or null (no arrow shown)
- Fetch child posts fails (shows error message with retry)
- Empty child list (shows "No posts yet")
- Parent post fetch fails (back button shows "...")
