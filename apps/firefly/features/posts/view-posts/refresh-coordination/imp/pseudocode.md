# refresh-coordination pseudocode

## Callback Pattern

Use a closure/callback pattern to propagate refresh requests up the view hierarchy.

```
type RefreshCallback = () -> void
```

## View Hierarchy

```
MainContentView
  └─> PostsView(onPostCreated: fetchRecentPosts)
       └─> PostCardView(onPostCreated: fetchRecentPosts)
            └─> NavigationLink → ChildrenPostsView(onPostCreated: fetchRecentPosts)
                 └─> PostCardView(onPostCreated: fetchRecentPosts)
                      └─> NavigationLink → ChildrenPostsView(onPostCreated: fetchRecentPosts)
                           └─> ... (recursive)
```

**Key principle**: Each view passes the SAME callback down to its children, so refreshes propagate all the way up to the root.

## Implementation at Each Level

### Root Level (MainContentView)

```
function fetchRecentPosts():
  call API to get recent posts
  update posts state
  trigger UI refresh

PostsView(onPostCreated: fetchRecentPosts)
```

### PostsView Level

```
receives: onPostCreated callback
passes to: all PostCardView children

PostCardView(
  post: post,
  isExpanded: binding,
  onPostCreated: onPostCreated  // pass through unchanged
)
```

### PostCardView Level

```
receives: onPostCreated callback
passes to: NavigationLink destination (ChildrenPostsView)

NavigationLink(destination: ChildrenPostsView(
  parentPostId: post.id,
  parentPostTitle: post.title,
  onPostCreated: onPostCreated  // pass through unchanged
))
```

### ChildrenPostsView Level

```
receives: onPostCreated callback
maintains: local fetchChildren function

on new post created:
  call fetchChildren()        // refresh local view
  call onPostCreated()        // refresh all parent views

passes to:
  - NewPostEditor callback
  - Child PostCardView instances (for recursive navigation)
```

## Post Creation Flow

```
User taps "New Post" in ChildrenPostsView:
  show NewPostEditor sheet with:
    parentId: parentPostId
    callback: () => {
      fetchChildren()      // refresh this children view
      onPostCreated()      // refresh all parent views
    }

When post is created:
  1. NewPostEditor posts to API
  2. On success, calls the callback
  3. Callback executes both fetchChildren() and onPostCreated()
  4. fetchChildren() refreshes current view
  5. onPostCreated() bubbles up to MainContentView
  6. MainContentView calls fetchRecentPosts()
  7. All views now show latest data
```

## Benefits

- **Simple**: Just pass a closure through the view hierarchy
- **Scalable**: Works at any depth of navigation
- **Decoupled**: Views don't need to know about parent structure
- **Consistent**: All views refresh simultaneously after post creation

## Alternative Approaches (Not Used)

❌ **Global state manager**: Overkill for this use case
❌ **Notification system**: More complex than needed
❌ **Polling**: Wasteful and delayed
✅ **Callback propagation**: Simple and immediate
