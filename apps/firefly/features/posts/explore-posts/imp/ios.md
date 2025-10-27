# explore posts - iOS Implementation
*Tree navigation using SwiftUI NavigationStack with custom gestures and back button*

## Overview

Implements hierarchical post navigation using SwiftUI's NavigationStack. Posts with children display a white chevron arrow with black outline and support left-swipe navigation. Child views show a custom back button with the parent's title and support swipe-right-from-anywhere to return.

## Implementation Approach

**SwiftUI Pattern:** NavigationStack with path binding (List of Int)
**Gestures:** DragGesture for swipe left (on posts) and swipe right (in child view)
**Custom UI:** White oval back button with parent title, chevron arrow indicator
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

1. **PostsView.swift** - Root posts view with NavigationStack
2. **PostView.swift** - Add child indicator and left-swipe gesture
3. **Post.swift** - Add ChildrenResponse struct
4. **ChildPostsView.swift** - NEW FILE for child posts view

### 1. PostsView.swift Changes

Add NavigationStack wrapper with path binding:

```swift
struct PostsView: View {
    // Add navigation state
    @State private var navigationPath: [Int] = []

    var body: some View {
        NavigationStack(path: $navigationPath) {
            postsContent
                .navigationDestination(for: Int.self) { parentPostId in
                    ChildPostsView(
                        parentPostId: parentPostId,
                        onPostCreated: onPostCreated,
                        navigationPath: $navigationPath
                    )
                }
        }
        .navigationBarHidden(true)
    }

    // In ForEach PostView calls, add:
    PostView(
        post: post,
        isExpanded: expandedPostId == post.id,
        onTap: { /* expand/collapse */ },
        onPostCreated: onPostCreated,
        onNavigateToChildren: { postId in
            navigationPath.append(postId)
        }
    )
}
```

### 2. PostView.swift Changes

Add child indicator overlay and swipe gesture:

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

            // Child indicator overlay (right arrow)
            if (post.childCount ?? 0) > 0 {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(Color.white)
                            .background(
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundColor(Color.black)
                                    .offset(x: -1, y: -1)
                            )
                            .background(
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundColor(Color.black)
                                    .offset(x: 1, y: -1)
                            )
                            .background(
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundColor(Color.black)
                                    .offset(x: -1, y: 1)
                            )
                            .background(
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundColor(Color.black)
                                    .offset(x: 1, y: 1)
                            )
                            .padding(.trailing, -8)
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

### 4. ChildPostsView.swift - New File

```swift
import SwiftUI

struct ChildPostsView: View {
    let parentPostId: Int
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
                        fetchChildPosts()
                    }
                    .padding()
                    .background(Color.white.opacity(0.3))
                    .cornerRadius(8)
                }
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 8) {
                            NewPostButton {
                                showNewPostEditor = true
                            }

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
                                            fetchChildPosts()
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
        .navigationBarBackButtonHidden(true)
        .toolbar {
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
        .highPriorityGesture(
            DragGesture()
                .onEnded { value in
                    // Swipe right from anywhere to go back
                    if value.translation.width > 100 {
                        navigationPath.removeLast()
                    }
                }
        )
        .sheet(isPresented: $showNewPostEditor) {
            NewPostEditor(onPostCreated: {
                fetchChildPosts()
                onPostCreated()
            }, parentId: parentPostId)
        }
        .onAppear {
            fetchParentPost()
            fetchChildPosts()
        }
    }

    func fetchParentPost() {
        guard let url = URL(string: "\(serverURL)/api/posts/\(parentPostId)") else {
            return
        }

        Logger.shared.info("[ChildPostsView] Fetching parent post \(parentPostId)")

        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data else { return }

            do {
                let postResponse = try JSONDecoder().decode(SinglePostResponse.self, from: data)
                DispatchQueue.main.async {
                    self.parentPost = postResponse.post
                }
            } catch {
                Logger.shared.error("[ChildPostsView] Error fetching parent: \(error.localizedDescription)")
            }
        }.resume()
    }

    func fetchChildPosts() {
        isLoading = true
        errorMessage = nil

        guard let url = URL(string: "\(serverURL)/api/posts/\(parentPostId)/children") else {
            isLoading = false
            errorMessage = "Invalid URL"
            return
        }

        Logger.shared.info("[ChildPostsView] Fetching posts for parent \(parentPostId)")

        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false

                if let error = error {
                    Logger.shared.error("[ChildPostsView] Error: \(error.localizedDescription)")
                    errorMessage = error.localizedDescription
                    return
                }

                guard let data = data else {
                    errorMessage = "No data received"
                    return
                }

                do {
                    let childrenResponse = try JSONDecoder().decode(ChildrenResponse.self, from: data)
                    Logger.shared.info("[ChildPostsView] Loaded \(childrenResponse.children.count) posts")
                    self.posts = childrenResponse.children
                } catch {
                    Logger.shared.error("[ChildPostsView] Decode error: \(error.localizedDescription)")
                    errorMessage = "Failed to load posts"
                }
            }
        }.resume()
    }
}
```

## API Endpoints Used

1. **Get child posts:**
   ```
   GET /api/posts/{parentPostId}/children

   Returns: {
     "status": "success",
     "post_id": 6,
     "children": [...],
     "count": 4
   }
   ```

2. **Get parent post:**
   ```
   GET /api/posts/{postId}

   Returns: {
     "status": "success",
     "post": {...}
   }
   ```

## Visual Design

**Child Indicator:**
- Icon: `chevron.right` system icon
- Size: 32pt, bold weight
- Color: White foreground with black outline (4 offset copies at ±1pt)
- Position: Right edge, vertically centered, -8pt trailing padding
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
- Action: Navigate to child posts view

**Swipe Right in Child View:**
- Minimum distance: 100pt
- Start position: Anywhere in view (not just left edge)
- Action: Navigate back to parent
- Priority: `.highPriorityGesture` to override ScrollView

**Tap Back Button:**
- Action: Navigate back to parent (`navigationPath.removeLast()`)

## Testing

**Manual Test:**
1. View posts list with posts that have `childCount > 0`
2. Verify white chevron with black outline appears on right edge
3. Swipe left on post with children → child list appears
4. Verify back button shows "< {parent title}"
5. Tap back button → return to parent list
6. Navigate to child view, swipe right from center of screen → return to parent
7. Navigate multiple levels deep
8. Verify smooth NavigationStack animations

**Edge Cases:**
- Post with `childCount = 0` or `null`: no arrow, no navigation
- Swipe left on post without children: no navigation, expand/collapse works
- Empty child list: shows "No posts yet" with "Create a new post" button
- Failed child fetch: shows error message with "Retry" button
- Failed parent fetch: back button shows "..."
