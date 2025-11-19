# add child post - pseudocode

## Determine Button Icon and Behavior

```
function getChildButtonIcon(post, currentUserId):
    if post.template == "query":
        return "chevron.right"  // Query posts always show chevron (navigate to search results)
    else if post.childCount > 0:
        return "chevron.right"  // Navigate to existing children
    else if post.authorId == currentUserId:
        return "plus"  // Add first child
    else:
        return null  // Don't show button
```

## Show Button Logic

```
function shouldShowChildButton(post, currentUserId):
    return post.childCount > 0
        or post.template == "query"
        or (post.childCount == 0 and post.authorId == currentUserId)
```

## Button Visual Specifications

**Size**:
- Collapsed: 32pt diameter
- Expanded: 42pt diameter
- Smooth interpolation during expansion animation

**Position**:
- Collapsed: Right edge (350pt + 6pt padding + 32pt offset), vertically centered
- Expanded: Top right corner (16pt from top, 16pt from right + 32pt offset)
- Smooth interpolation during expansion animation

**Styling**:
- White circular background with tunable opacity ("button-colour", default 0.5)
- Black icon (size 20pt, bold weight)
- Shadow: black at 0.4 opacity, radius 8pt, offset (0, 4pt)
- Matches Add Post button, Toolbar, and Author button styling

## Handle Button Tap

```
function onChildButtonTapped(post, currentUserId):
    hasChildren = post.childCount > 0

    if post.template == "query":
        // Navigate to search results
        navigateToQueryResults(post.title)
    else if hasChildren:
        // Navigate to existing children
        navigationPath = navigationPath + [post.id]
    else if post.authorId == currentUserId:
        // Navigate to empty children view
        // Auto-creation will trigger automatically when view loads
        navigationPath = navigationPath + [post.id]
```

## Auto-Create Child Post

When navigating to a children view with zero children for an owned post:

```
function fetchPosts(parentId):
    children = api.getChildren(parentId)

    if children.isEmpty and parentPost.authorId == currentUserId:
        // Automatically create first child
        createNewPost(parentId = parentId)
```

## Refresh After Save

When a new post is saved:

```
function savePost(post, isNewPost):
    response = api.savePost(post)

    if isNewPost:
        // Trigger full refresh cascade
        // This updates:
        // - Parent post's child count
        // - Root "all posts" list
        // - All ancestor views
        onPostCreated()
    else:
        // Just update local view
        onPostUpdated(post)
```

## Add Post Button in Child Views

Show "Add Post" button in child post lists when:
- Parent post is owned by current user

This allows adding multiple children after the first one.

## Platform Implementation Notes

**iOS**:
- PostView: Dynamic icon selection in `childIndicatorButton`
- PostView: `handleChildButtonTap()` routes based on post state
- PostsListView: Auto-create logic in `fetchPosts()` after loading empty children
- PostsListView: `shouldShowAddButton` checks parent ownership
- PostView: Save calls `onPostCreated()` for new posts to trigger full refresh

**Android**:
- Similar pattern in PostCard and PostsListComposable
- Use Jetpack Compose state management for button visibility
- Handle navigation and auto-creation in ViewModel
