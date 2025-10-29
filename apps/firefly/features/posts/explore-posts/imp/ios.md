# explore posts - iOS Implementation
*Tree navigation using SwiftUI NavigationStack with unified view component*

## Overview

Implements hierarchical post navigation using SwiftUI's NavigationStack. Posts with children display a white chevron arrow with black outline and support left-swipe navigation. Child views show a custom back button with the parent's title. The root view maintains its scroll position when navigating away and back.

## Implementation Approach

**SwiftUI Pattern:** NavigationStack with path binding (List of Int)
**Unified Component:** PostsListView handles both root and child posts via optional parentPostId
**Gestures:** DragGesture for swipe left on posts (standard NavigationStack back for child views)
**Custom UI:** White oval back button with parent title, chevron arrow indicator
**State Preservation:** Root view only fetches posts when empty, preserving scroll position
**Animations:** SwiftUI's built-in navigation transitions

## Core Data Structures

### Navigation Path
```swift
@State private var navigationPath: [Int] = []
```
- Stores parentPostId for each level in navigation hierarchy
- Empty array = root level
- Append postId when navigating to children
- Remove last when going back

### API Response Structures
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

struct SinglePostResponse: Codable {
    let status: String
    let post: Post
}
```

## Product Integration

### Files Modified

1. **PostsView.swift** - Converted to thin wrapper with NavigationStack setup
2. **PostsListView.swift** - NEW FILE - unified component for root and child posts
3. **PostView.swift** - Added child indicator (white circle with black chevron) and left-swipe gesture
4. **ChildPostsView.swift** - REMOVED (functionality unified into PostsListView)
5. **NoobTest.xcodeproj/project.pbxproj** - Added PostsListView.swift reference

### 1. PostsView.swift - Thin Wrapper

Simplified to just set up NavigationStack and route to PostsListView:

```swift
struct PostsView: View {
    let onPostCreated: () -> Void
    @State private var navigationPath: [Int] = []

    var body: some View {
        NavigationStack(path: $navigationPath) {
            PostsListView(
                parentPostId: nil,  // nil = root level
                onPostCreated: onPostCreated,
                navigationPath: $navigationPath
            )
            .navigationDestination(for: Int.self) { parentPostId in
                PostsListView(
                    parentPostId: parentPostId,  // non-nil = child level
                    onPostCreated: onPostCreated,
                    navigationPath: $navigationPath
                )
            }
        }
        .navigationBarHidden(true)
    }
}
```

### 2. PostView.swift Changes

Add child indicator overlay (white circle with black chevron) and swipe gesture:

```swift
struct PostView: View {
    let post: Post
    let isExpanded: Bool
    let onTap: () -> Void
    let onPostCreated: () -> Void
    let onNavigateToChildren: ((Int) -> Void)?  // NEW

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Existing post content...

            // Child indicator overlay (white circle with black chevron)
            if (post.childCount ?? 0) > 0 {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.9))
                                .frame(width: 42, height: 42)

                            Circle()
                                .stroke(Color.black, lineWidth: 3)
                                .frame(width: 42, height: 42)

                            Image(systemName: "chevron.right")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(Color.black)
                        }
                        .padding(.trailing, -16)
                    }
                    Spacer()
                }
                .frame(height: currentHeight)
            }
        }
        .onTapGesture {
            onTap()
        }
        .gesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    // Detect left swipe (negative translation)
                    if value.translation.width < -30 && (post.childCount ?? 0) > 0 {
                        onNavigateToChildren?(post.id)
                    }
                }
        )
    }
}
```

### 3. Post.swift Changes

Add ChildrenResponse structure:

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

### 4. PostsListView.swift - New Unified Component

Handles both root posts (parentPostId = nil) and child posts (parentPostId = Int):

```swift
import SwiftUI

struct PostsListView: View {
    let parentPostId: Int?  // nil = root level, non-nil = child posts
    let onPostCreated: () -> Void
    @Binding var navigationPath: [Int]

    @State private var posts: [Post] = []
    @State private var expandedPostId: Int? = nil
    @State private var showNewPostEditor = false
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var parentPost: Post? = nil

    let serverURL = "http://185.96.221.52:8080"

    var body: some View {
        ZStack {
            Color(red: 128/255, green: 128/255, blue: 128/255)
                .ignoresSafeArea()

            if isLoading {
                ProgressView("Loading...")
                    .foregroundColor(.black)
            } else if let error = errorMessage {
                VStack(spacing: 16) {
                    Text("Error loading posts")
                        .font(.headline)
                        .foregroundColor(.black)
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.black.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding()
                    Button("Retry") {
                        fetchPosts()
                    }
                    .padding()
                    .background(Color.white.opacity(0.3))
                    .cornerRadius(8)
                }
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 8) {
                            if posts.isEmpty {
                                Text("No posts yet")
                                    .foregroundColor(.black)
                                    .padding()
                            } else {
                                ForEach(posts) { post in
                                    PostView(
                                        post: post,
                                        isExpanded: expandedPostId == post.id,
                                        onTap: {
                                            if expandedPostId == post.id {
                                                expandedPostId = nil
                                            } else {
                                                expandedPostId = post.id
                                                withAnimation(.easeInOut(duration: 0.3)) {
                                                    proxy.scrollTo(post.id, anchor: .top)
                                                }
                                            }
                                        },
                                        onPostCreated: {
                                            fetchPosts()
                                            onPostCreated()
                                        },
                                        onNavigateToChildren: { postId in
                                            navigationPath.append(postId)
                                        }
                                    )
                                    .id(post.id)
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Only show custom back button for child views
            if let parentId = parentPostId {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        navigationPath.removeLast()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.black)

                            Text(parentPost?.title ?? "...")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.black)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.9))
                        .clipShape(Capsule())
                    }
                }
            }
        }
        .sheet(isPresented: $showNewPostEditor) {
            NewPostEditor(onPostCreated: {
                fetchPosts()
                onPostCreated()
            }, parentId: parentPostId)
        }
        .onAppear {
            if let parentId = parentPostId {
                // Child view: always fetch parent and posts
                fetchParentPost(parentId)
                fetchPosts()
            } else if posts.isEmpty {
                // Root view: only fetch if empty (preserves scroll position)
                fetchPosts()
            }
        }
    }

    func fetchParentPost(_ postId: Int) {
        guard let url = URL(string: "\(serverURL)/api/posts/\(postId)") else {
            return
        }

        Logger.shared.info("[PostsListView] Fetching parent post \(postId)")

        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data else { return }

            do {
                let postResponse = try JSONDecoder().decode(SinglePostResponse.self, from: data)
                DispatchQueue.main.async {
                    self.parentPost = postResponse.post
                }
            } catch {
                Logger.shared.error("[PostsListView] Error fetching parent: \(error.localizedDescription)")
            }
        }.resume()
    }

    func fetchPosts() {
        isLoading = true
        errorMessage = nil

        let urlString: String
        if let parentId = parentPostId {
            urlString = "\(serverURL)/api/posts/\(parentId)/children"
        } else {
            urlString = "\(serverURL)/api/posts/recent?limit=50"  // Root uses /recent endpoint
        }

        guard let url = URL(string: urlString) else {
            isLoading = false
            errorMessage = "Invalid URL"
            return
        }

        Logger.shared.info("[PostsListView] Fetching posts (parent: \(parentPostId?.description ?? "root"))")

        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false

                if let error = error {
                    Logger.shared.error("[PostsListView] Error: \(error.localizedDescription)")
                    errorMessage = error.localizedDescription
                    return
                }

                guard let data = data else {
                    errorMessage = "No data received"
                    return
                }

                do {
                    if parentPostId != nil {
                        // Child posts - decode ChildrenResponse
                        let childrenResponse = try JSONDecoder().decode(ChildrenResponse.self, from: data)
                        Logger.shared.info("[PostsListView] Loaded \(childrenResponse.children.count) posts")
                        self.posts = childrenResponse.children
                    } else {
                        // Root posts - decode PostsResponse
                        let postsResponse = try JSONDecoder().decode(PostsResponse.self, from: data)
                        Logger.shared.info("[PostsListView] Loaded \(postsResponse.posts.count) posts")
                        self.posts = postsResponse.posts
                    }
                } catch {
                    Logger.shared.error("[PostsListView] Decode error: \(error.localizedDescription)")
                    errorMessage = "Failed to load posts"
                }
            }
        }.resume()
    }
}
```

**Key Design Decisions:**

1. **Unified Component**: Single PostsListView handles both root and child posts via optional `parentPostId` parameter
2. **State Preservation**: Root view only fetches when `posts.isEmpty`, keeping scroll position intact when navigating back
3. **Different Endpoints**: Root uses `/api/posts/recent?limit=50`, children use `/api/posts/{id}/children`
4. **No Scroll-Blocking Gestures**: Removed `.highPriorityGesture` to allow ScrollView to scroll freely without interference
5. **Conditional Toolbar**: Custom back button only appears for child views (when `parentPostId != nil`)
6. **Circle Indicator Design**: Changed from simple chevron with outline to white circle with black border and centered chevron
7. **Edge Straddling**: Indicator positioned -16pt trailing (instead of -8pt) so circle straddles post edge more prominently

## API Endpoints Used

1. **Get recent posts (root level):**
   ```
   GET /api/posts/recent?limit=50

   Returns: {
     "status": "success",
     "posts": [...]
   }
   ```

2. **Get child posts:**
   ```
   GET /api/posts/{parentPostId}/children

   Returns: {
     "status": "success",
     "post_id": 6,
     "children": [...],
     "count": 4
   }
   ```

3. **Get parent post (for back button title):**
   ```
   GET /api/posts/{postId}

   Returns: {
     "status": "success",
     "post": {...}
   }
   ```

## Visual Design

**Child Indicator:**
- Container: White circle (42pt diameter, 90% opacity)
- Border: Black stroke (3pt width)
- Icon: `chevron.right` system icon
- Icon size: 20pt, bold weight
- Icon color: Black
- Position: Right edge, vertically centered, -16pt trailing padding (straddles edge)
- Only visible when `(post.childCount ?? 0) > 0`

**Custom Back Button:**
- White oval capsule (Capsule shape)
- Contents: `chevron.left` (20pt, semibold) + parent post title (17pt, semibold, 1 line)
- Padding: 12pt horizontal, 8pt vertical
- Background: White 90% opacity
- Position: Navigation bar leading area

## Gestures

**Swipe Left on Post:**
- Minimum distance: 30pt
- Condition: Post must have children (`childCount > 0`)
- Action: Navigate to child posts view (`navigationPath.append(postId)`)

**Navigate Back:**
- Method 1: Tap custom back button in toolbar
- Method 2: Use standard NavigationStack swipe-from-left-edge gesture
- Action: Remove last item from navigation path (`navigationPath.removeLast()`)

**No Custom Swipe-Right Gesture:**
- Removed to allow ScrollView to scroll freely
- Standard NavigationStack edge swipe works naturally

## Testing

**Manual Test:**
1. View posts list with posts that have `childCount > 0`
2. Verify white circle (42pt) with black outline (3pt) and black chevron appears on right edge, straddling the boundary
3. Swipe left on post with children (minimum 30pt) → child list appears
4. Verify back button shows "< {parent title}" in white oval capsule
5. Scroll down in root view, navigate to child, tap back button
6. Verify root view scroll position is preserved (not reset to top)
7. Navigate to child view, swipe from left edge → return to parent
8. Verify ScrollView scrolls normally (up/down) without any gesture interference
9. Navigate multiple levels deep (verify back button updates at each level)
10. Verify smooth NavigationStack slide animations between levels

**Edge Cases:**
- Post with `childCount = 0` or `null`: no arrow, no navigation
- Swipe left on post without children: no navigation, expand/collapse works
- Empty child list: shows "No posts yet" message
- Failed child fetch: shows error message with "Retry" button
- Failed parent fetch: back button shows "..."
- Root view scroll position: preserved across navigation due to conditional fetching
