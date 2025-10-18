# children-view pseudocode

## Component Structure

**ChildrenPostsView**:
- Takes parent post ID and parent post title as parameters
- Takes onPostCreated callback for refreshing parent view
- Maintains its own list of child posts
- Maintains its own expandedPostIds state

## Initialization

```
on view appear:
  fetch children from API
  display loading spinner until data arrives
```

## Data Fetching

```
function fetchChildren():
  call GET /api/posts/{parentPostId}/children
  parse response into list of Post objects
  update children state
  trigger UI refresh
```

## UI Layout

```
NavigationView with title: "children of {parentPostTitle}"

ScrollView:
  "New Post" button at top

  ForEach child in children:
    PostCardView(
      post: child,
      isExpanded: binding to expandedPostIds,
      onPostCreated: onPostCreated
    )
```

**Key points**:
- Uses same PostCardView component as main feed
- Each child can itself have children (recursive structure)
- Expansion state independent from parent view

## Creating New Child Posts

```
on "New Post" button tapped:
  show NewPostEditor as sheet
  pass parentId = parentPostId
  pass callback that:
    - refreshes this children view (fetchChildren)
    - refreshes parent view (call onPostCreated)
```

This ensures both the children view and the main feed stay in sync when new posts are created.

## Navigation

Uses NavigationStack for smooth slide animations:
- Arrow button navigates TO this view
- Back button returns to parent view
- Parent view's expandedPostIds preserved across navigation
