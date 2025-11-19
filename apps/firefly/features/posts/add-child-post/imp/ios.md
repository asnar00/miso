# add child post - iOS implementation

## File: PostView.swift

### 1. Update button visibility condition (line ~917)

Shows the child indicator button when post has children, is a query, OR is an owned post with no children:

```swift
// Child indicator overlay - show if post has children OR if it's a query (search button) OR if it's an own post with no children
if (post.childCount ?? 0) > 0 || post.template == "query" || ((post.childCount ?? 0) == 0 && isOwnPost) {
    // Interpolate size and position based on expansionFactor
    let collapsedSize: CGFloat = 32
    let expandedSize: CGFloat = 42
    let currentSize = lerp(collapsedSize, expandedSize, expansionFactor)

    // Collapsed: right edge with -6pt padding + 32pt, vertically centered
    // Expanded: 16pt from top, 16pt from right + 32pt
    let collapsedX: CGFloat = 350 + 6 + 32 - (collapsedSize / 2)
    let expandedX: CGFloat = 350 - 16 + 32 - (expandedSize / 2)
    let currentX = lerp(collapsedX, expandedX, expansionFactor)

    let collapsedY: CGFloat = currentHeight / 2  // Vertically centered
    let expandedY: CGFloat = 16 + (expandedSize / 2)  // 16pt from top
    let currentY = lerp(collapsedY, expandedY, expansionFactor)

    childIndicatorButton
        .frame(width: currentSize, height: currentSize)
        .offset(x: currentX - currentSize/2, y: currentY - currentSize/2)
}
```

### 2. Dynamic icon selection in childIndicatorButton (line ~363)

The button dynamically chooses between chevron and plus icons:

```swift
private var childIndicatorButton: some View {
    // Determine icon based on post state
    let iconName: String = {
        if (post.childCount ?? 0) > 0 || post.template == "query" {
            return "chevron.right"
        } else {
            return "plus"
        }
    }()

    let buttonColour = tunables.getDouble("button-colour", default: 0.5)

    return ZStack {
        Circle()
            .fill(Color.white.opacity(buttonColour))
            .shadow(color: Color.black.opacity(0.4), radius: 8, x: 0, y: 4)

        Image(systemName: iconName)
            .font(.system(size: 20, weight: .bold))
            .foregroundColor(Color.black)
    }
    .onTapGesture {
        handleChildButtonTap()
    }
    .onAppear {
        // Register this post's navigation action for UI automation
        UIAutomationRegistry.shared.register(id: "navigate-to-children-\(post.id)") {
            DispatchQueue.main.async {
                self.handleChildButtonTap()
            }
        }
    }
}
```

### 3. Handle button tap with routing logic (line ~378)

Routes to different behaviors based on post state:

```swift
// Handle child button tap with different behavior based on post state
private func handleChildButtonTap() {
    let hasChildren = (post.childCount ?? 0) > 0

    if post.template == "query" {
        // Query posts: navigate to search results
        if let navigate = onNavigateToQueryResults {
            navigate(post.title, post.title)
        }
    } else if hasChildren {
        // Posts with children: navigate to children view
        if let navigate = onNavigateToChildren {
            navigate(post.id)
        }
    } else if isOwnPost {
        // Own posts with zero children: navigate and signal auto-create
        if let navigate = onNavigateToChildren {
            navigate(post.id)
            // PostsListView will detect this and auto-create a child post
        }
    }
}
```

### 4. Save triggers full refresh for new posts (line ~288)

When a new post is saved, trigger `onPostCreated()` to refresh all views:

```swift
if isNewPost {
    // For new posts, trigger full refresh to update all views
    // This ensures parent posts get updated child counts and root lists get new posts
    Logger.shared.info("[PostView] New post created, triggering full refresh")
    self.onPostCreated()
} else {
    // For updates, just update the local post
    var updatedPost = self.post
    updatedPost.title = self.editableTitle
    updatedPost.summary = self.editableSummary
    updatedPost.body = self.editableBody
    updatedPost.imageUrl = self.editableImageUrl
    self.onPostUpdated?(updatedPost)
}
```

## File: PostsListView.swift

### 5. Auto-create child in fetchPosts (line ~418)

After loading empty children for an owned post, automatically create first child:

```swift
if parentPostId != nil {
    // Child posts - different response format
    let childrenResponse = try JSONDecoder().decode(ChildrenResponse.self, from: data)
    Logger.shared.info("[PostsListView] Loaded \(childrenResponse.children.count) posts")
    self.posts = childrenResponse.children

    // Auto-create a child post if we navigated to an empty child list
    // (user tapped "+" button on their own post with no children)
    if childrenResponse.children.isEmpty {
        if let parent = self.parentPost, parent.authorEmail == Storage.shared.getLoginState().email {
            Logger.shared.info("[PostsListView] Empty child list for owned post - auto-creating first child")
            self.createNewPost()
        }
    }
}
```

### 6. Show Add Post button in child views (line ~32)

Enable "Add Post" button in child post lists when parent is owned by current user:

```swift
private var shouldShowAddButton: Bool {
    // If custom text provided, always show button
    if customAddButtonText != nil { return true }

    // For child posts, only show if parent is owned by current user
    if let parentId = parentPostId {
        if let parent = parentPost {
            let loginState = Storage.shared.getLoginState()
            if let userEmail = loginState.email, let parentEmail = parent.authorEmail {
                return userEmail.lowercased() == parentEmail.lowercased()
            }
        }
        return false  // Parent not loaded yet or not owned
    }

    // Root level: show unless it's a profile list
    guard let firstPost = posts.first else { return showAddButton }
    return firstPost.template != "profile"
}
```

## Testing

**UI Automation**: The button is registered with ID `navigate-to-children-{postId}` and can be triggered via:

```bash
curl -X POST 'http://localhost:8081/test/tap?id=navigate-to-children-28'
```

**Expected behavior**:
1. Tapping "+" on a post with no children navigates to empty children view
2. New post automatically created in edit mode
3. Saving the post triggers full refresh
4. Navigating back shows ">" instead of "+" (child count updated)
5. New post appears in root "all posts" list