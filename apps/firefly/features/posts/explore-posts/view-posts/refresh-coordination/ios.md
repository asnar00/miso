# refresh-coordination implementation (iOS)

## Callback Type Definition

Swift closures are used for the callback pattern:

```swift
typealias PostCreatedCallback = () -> Void
```

No explicit type alias needed - Swift's `() -> Void` closure syntax is clear and idiomatic.

## Root Level - MainContentView

**File**: `MainContentView.swift`

**Location**: Lines 37-44

```swift
func fetchRecentPosts() {
    PostsAPI.shared.getRecentPosts(limit: 50) { result in
        switch result {
        case .success(let fetchedPosts):
            posts = fetchedPosts
        case .failure(let error):
            errorMessage = "Failed to load posts: \(error.localizedDescription)"
        }
    }
}
```

Passed to PostsView (MainContentView.swift:90):

```swift
PostsView(onPostCreated: fetchRecentPosts)
```

**Key point**: `fetchRecentPosts` is the root refresh function that gets propagated through the entire view hierarchy.

## PostsView Level

**File**: `PostsView.swift`

**Location**: Line 25

```swift
struct PostsView: View {
    let onPostCreated: () -> Void
    // ... other properties ...
}
```

Passes callback to all PostCardView children (PostsView.swift:38-58):

```swift
ForEach(posts) { post in
    PostCardView(
        post: post,
        isExpanded: Binding(/* ... */),
        onPostCreated: onPostCreated  // Pass through unchanged
    )
    .id(post.id)
}
```

**Key point**: PostsView doesn't modify or wrap the callback - it passes it through directly.

## PostCardView Level

**File**: `PostsView.swift`

**Location**: Line 84

```swift
struct PostCardView: View {
    let post: Post
    @Binding var isExpanded: Bool
    let onPostCreated: () -> Void
    // ... other properties ...
}
```

Passes callback to NavigationLink destination (PostCardView.swift:310-330):

```swift
if isExpanded, let childCount = post.childCount, childCount > 0 {
    NavigationLink(destination: ChildrenPostsView(
        parentPostId: post.id,
        parentPostTitle: post.title,
        onPostCreated: onPostCreated  // Pass through unchanged
    )) {
        // Arrow button UI
    }
}
```

**Key point**: Callback propagates through navigation hierarchy automatically.

## ChildrenPostsView Level

**File**: `PostsView.swift`

**Location**: Line 409

```swift
struct ChildrenPostsView: View {
    let parentPostId: Int
    let parentPostTitle: String
    let onPostCreated: () -> Void

    @State private var children: [Post] = []
    // ... other state ...

    func fetchChildren() {
        // Fetch child posts from API
    }
}
```

Dual refresh on post creation (ChildrenPostsView.swift:465-470):

```swift
.sheet(isPresented: $showNewPostEditor) {
    NewPostEditor(onPostCreated: {
        // Reload children when a new post is created
        fetchChildren()
        // Also reload the parent recent posts view
        onPostCreated()
    }, parentId: parentPostId)
}
```

**Key behavior**:
1. Calls local `fetchChildren()` to refresh current view
2. Calls `onPostCreated()` to trigger refresh up the hierarchy

Passes callback to child PostCardViews (for recursive navigation):

```swift
ForEach(children) { post in
    PostCardView(
        post: post,
        isExpanded: Binding(/* ... */),
        onPostCreated: onPostCreated  // Pass through for recursive children
    )
}
```

## NewPostEditor Integration

**File**: `NewPostView.swift`

**Location**: Line 32

```swift
struct NewPostEditor: View {
    @Environment(\.dismiss) var dismiss
    let onPostCreated: () -> Void
    let parentId: Int?
    // ... other properties ...
}
```

Calls callback after successful post creation (NewPostView.swift:222-235):

```swift
PostsAPI.shared.createPost(
    title: title,
    summary: summary.isEmpty ? "No summary" : summary,
    body: bodyText.isEmpty ? "No content" : bodyText,
    image: selectedImage,
    parentId: parentId
) { result in
    switch result {
    case .success:
        onPostCreated()  // Trigger refresh
        dismiss()        // Close sheet
    case .failure(let error):
        errorMessage = "Failed to create post: \(error.localizedDescription)"
    }
}
```

**Key point**: Callback only called on successful post creation, ensuring refreshes only happen when needed.

## Execution Flow Example

**Scenario**: User creates new post in children view

```
1. User taps "New Post" in ChildrenPostsView (depth 2)
2. NewPostEditor appears with callback:
   () => { fetchChildren(); onPostCreated(); }
3. User submits post
4. API call succeeds
5. NewPostEditor calls callback
6. Callback executes:
   a. fetchChildren() refreshes ChildrenPostsView
   b. onPostCreated() is MainContentView.fetchRecentPosts
   c. fetchRecentPosts() refreshes root PostsView
7. Both views now show new post
8. Sheet dismisses
```

## Memory Management

Swift's ARC handles closure capture automatically:

- `onPostCreated` callback is captured by reference (not copied)
- No retain cycles because closures don't capture `self` in passed-through callbacks
- Automatic cleanup when views are deallocated

**No manual memory management needed** - Swift handles it correctly.

## Testing

```bash
# Build and deploy
cd /Users/asnaroo/Desktop/experiments/miso/apps/firefly/product/client/imp/ios
./install-device.sh

# Test refresh coordination:
# 1. Open app and note posts in main feed
# 2. Navigate to children of a post
# 3. Create new child post
# 4. Verify new post appears in children view
# 5. Go back to main feed
# 6. Verify new post appears in main feed (refresh worked)
```

## Benefits of This Approach

✅ **Simple**: Just pass closures through view hierarchy
✅ **SwiftUI-idiomatic**: Uses standard closure patterns
✅ **Type-safe**: Compiler catches missing callbacks
✅ **No boilerplate**: No protocols or delegates needed
✅ **Performant**: Only refreshes when needed
✅ **Testable**: Easy to inject mock callbacks
