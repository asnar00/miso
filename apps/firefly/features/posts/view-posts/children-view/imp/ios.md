# children-view implementation (iOS)

## Component Definition

**File**: `PostsView.swift`

**Location**: Lines 409-490

```swift
struct ChildrenPostsView: View {
    let parentPostId: Int
    let parentPostTitle: String
    let onPostCreated: () -> Void

    @State private var children: [Post] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showNewPostEditor = false
    @State private var expandedPostIds: Set<Int> = []

    let serverURL = "http://185.96.221.52:8080"

    var body: some View {
        // ... implementation ...
    }
}
```

**Parameters**:
- `parentPostId`: ID of the parent post whose children we're displaying
- `parentPostTitle`: Title of parent post (for display in navigation title)
- `onPostCreated`: Callback closure to refresh parent view when new post created

**State variables**:
- `children`: Array of child posts fetched from API
- `isLoading`: Loading state for spinner
- `errorMessage`: Error message if fetch fails
- `showNewPostEditor`: Controls sheet presentation for creating new child
- `expandedPostIds`: Set tracking which posts are expanded (independent from parent view)

## UI Structure

```swift
ScrollView {
    VStack(spacing: 0) {
        // "New Post" button
        Button(action: { showNewPostEditor = true }) {
            HStack {
                Image(systemName: "plus.circle.fill")
                Text("New Post")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.white.opacity(0.9))
            .cornerRadius(12)
        }
        .padding()

        // Child posts
        ScrollViewReader { proxy in
            ForEach(children) { post in
                PostCardView(
                    post: post,
                    isExpanded: Binding(
                        get: { expandedPostIds.contains(post.id) },
                        set: { /* expand/collapse logic */ }
                    ),
                    onPostCreated: onPostCreated
                )
                .id(post.id)
            }
        }
    }
}
.navigationTitle("children of \(parentPostTitle)")
.navigationBarTitleDisplayMode(.inline)
```

**Key UI decisions**:
- Uses `.inline` title display mode for compact header
- "New Post" button uses plus.circle.fill icon
- Reuses PostCardView component for consistency
- Each child can have its own children (recursive navigation)

## Data Fetching

```swift
func fetchChildren() {
    isLoading = true
    errorMessage = nil

    guard let url = URL(string: "\(serverURL)/api/posts/\(parentPostId)/children") else {
        errorMessage = "Invalid URL"
        isLoading = false
        return
    }

    URLSession.shared.dataTask(with: url) { data, response, error in
        DispatchQueue.main.async {
            isLoading = false

            if let error = error {
                errorMessage = "Error: \(error.localizedDescription)"
                return
            }

            guard let data = data else {
                errorMessage = "No data received"
                return
            }

            do {
                let response = try JSONDecoder().decode(ChildrenResponse.self, from: data)
                children = response.children
            } catch {
                errorMessage = "Failed to parse: \(error.localizedDescription)"
            }
        }
    }.resume()
}
```

**Called**: In `.onAppear` modifier to fetch data when view appears

## Response Model

```swift
struct ChildrenResponse: Codable {
    let status: String
    let postId: Int
    let children: [Post]
    let count: Int

    enum CodingKeys: String, CodingKey {
        case status
        case postId = "post_id"
        case children
        case count
    }
}
```

**Location**: PostsView.swift:491

## Creating New Child Posts

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
- Passes `parentId` to NewPostEditor so new posts are created as children
- On post creation, calls BOTH:
  - `fetchChildren()` to refresh this children view
  - `onPostCreated()` to refresh parent view up the hierarchy

This dual refresh ensures data consistency across all views.

## Navigation Integration

Navigated to from PostCardView via NavigationLink:

```swift
NavigationLink(destination: ChildrenPostsView(
    parentPostId: post.id,
    parentPostTitle: post.title,
    onPostCreated: onPostCreated
)) {
    // Arrow button
}
```

**Navigation flow**:
1. User taps arrow button on expanded post (if it has children)
2. NavigationStack pushes ChildrenPostsView with slide animation
3. ChildrenPostsView fetches and displays children
4. Back button returns to parent view
5. Parent view's scroll position and expansion state preserved

## Testing

```bash
# Build and deploy
cd /Users/asnaroo/Desktop/experiments/miso/apps/firefly/product/client/imp/ios
./install-device.sh

# Test flow:
# 1. Open app and view recent posts
# 2. Expand "test post" (post #6)
# 3. Tap arrow button on right edge
# 4. Should navigate to children view with title "children of test post"
# 5. Should see child posts (e.g., "beer", "cherry pie")
# 6. Tap "New Post" to create new child
# 7. Verify both children view and parent view refresh
```
