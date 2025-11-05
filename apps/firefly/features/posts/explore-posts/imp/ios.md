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
2. **PostsListView.swift** - Unified component for root and child posts with custom capsule back button
3. **PostView.swift** - Child indicator, left-swipe gesture, body complexity fix, inline ImagePicker
4. **ChildPostsView.swift** - DELETED (functionality unified into PostsListView)
5. **NewPostView.swift** - DELETED (replaced by inline editing in PostView)
6. **NoobTest.xcodeproj/project.pbxproj** - Removed references to deleted files

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

**Changes made:**
1. Child indicator overlay (grey circle with white chevron)
2. Left-swipe gesture for navigation to children
3. Body complexity fix (extracted 478-line body to `postContent` computed property)
4. ImagePicker moved inline from deleted NewPostView.swift

**Child indicator and swipe gesture:**

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

            // Child indicator overlay (grey semi-transparent circle with white chevron)
            if (post.childCount ?? 0) > 0 {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        ZStack {
                            Circle()
                                .fill(Color(red: 128/255, green: 128/255, blue: 128/255).opacity(0.8))
                                .frame(width: 42, height: 42)

                            Image(systemName: "chevron.right")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(Color.white)
                        }
                        .padding(.trailing, -10)
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

**Body complexity fix:**

Swift compiler has a limit on view body complexity. PostView's body was 478 lines, causing "unable to type-check this expression in reasonable time" error. Fixed by extracting main content to a separate computed property:

```swift
struct PostView: View {
    // ... properties ...

    var body: some View {
        postContent
            .onAppear { /* ... */ }
            .onChange(of: selectedImage) { /* ... */ }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $selectedImage, sourceType: imageSourceType)
            }
    }

    @ViewBuilder
    private var postContent: some View {
        // All the ZStack content (478 lines) goes here
        // This allows the compiler to type-check the body in smaller chunks
    }
}
```

**ImagePicker inline:**

Previously in NewPostView.swift (now deleted), moved inline to PostView.swift at end of file:

```swift
// MARK: - ImagePicker

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    let sourceType: UIImagePickerController.SourceType
    @Environment(\.dismiss) var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let uiImage = info[.originalImage] as? UIImage {
                parent.image = uiImage
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
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
                        .padding(.horizontal, 8)  // Halved from 16pt to make posts wider
                        .padding(.vertical)
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarHidden(parentPostId == nil)  // Hide nav bar for root, show for children
        .toolbar {
            // Custom capsule back button for child views
            if parentPostId != nil {
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
5. **Custom Capsule Back Button**: White oval button with chevron + parent title in `.navigationBarLeading` placement (replaces standard iOS back button)
6. **Circle Indicator Design**: Grey semi-transparent circle (RGB 128/128/128, 80% opacity) with white chevron, no border
7. **Edge Straddling**: Indicator positioned -10pt trailing so circle straddles post edge
8. **UI Automation**: Programmatic scroll and navigation actions registered via UIAutomationRegistry for testing
9. **Code Organization**: ImagePicker moved inline to PostView.swift; ChildPostsView and NewPostView deleted (functionality unified)

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

**Post Layout:**
- List horizontal padding: 8pt (halved from 16pt to make posts wider)
- List vertical padding: Default SwiftUI padding
- Post title/summary left padding: 16pt (increased from 8pt for more text indent)
- Post title/summary vertical padding: 8pt
- Post title/summary right padding: 8pt
- Expanded body text left offset: 18pt (increased from 10pt, aligned with title indent)
- Expanded image left offset: 18pt (increased from 10pt, aligned with text)
- Author line left offset: 18pt (increased from 10pt, aligned with text)

**Child Indicator:**
- Container: Grey circle (42pt diameter, RGB 128/128/128, 80% opacity)
- Border: None
- Icon: `chevron.right` system icon
- Icon size: 20pt, bold weight
- Icon color: White
- Position: Right edge, vertically centered, -10pt trailing padding (straddles edge)
- Only visible when `(post.childCount ?? 0) > 0`

**Navigation Bar (Child Views):**
- Custom capsule back button (white oval, 90% opacity)
- Chevron icon: `chevron.left`, 20pt semibold, black
- Parent post title: 17pt semibold, black, 1 line max
- Button padding: 12pt horizontal, 8pt vertical
- Icon-to-text spacing: 8pt
- Placement: `.navigationBarLeading` (left side)
- Navigation bar hidden for root view, shown for child views

## Gestures

**Swipe Left on Post:**
- Minimum distance: 30pt
- Condition: Post must have children (`childCount > 0`)
- Action: Navigate to child posts view (`navigationPath.append(postId)`)

**Navigate Back:**
- Method 1: Tap standard iOS back button in navigation bar
- Method 2: Swipe from left edge (standard NavigationStack gesture)
- Action: NavigationStack automatically removes last item from navigation path

**No Custom Swipe-Right Gesture:**
- Removed to allow ScrollView to scroll freely
- Standard NavigationStack edge swipe works naturally

## UI Automation

For programmatic testing, the implementation registers automation actions with UIAutomationRegistry:

**Scroll Actions (Root View Only)**:
```swift
// In PostsListView.onAppear for ScrollViewReader
if parentPostId == nil {
    for post in posts {
        let postTitle = post.title
        let postId = post.id
        UIAutomationRegistry.shared.register(id: "scroll-to-\(postTitle)") {
            DispatchQueue.main.async {
                withAnimation {
                    proxy.scrollTo(postId, anchor: .center)
                }
            }
        }
    }
}
```

**Navigation Actions (All Posts)**:
```swift
// In PostView.onAppear
UIAutomationRegistry.shared.register(id: "navigate-to-children-\(post.id)") {
    if let navigate = onNavigateToChildren {
        DispatchQueue.main.async {
            navigate(post.id)
        }
    }
}
```

**Trigger via HTTP**:
```bash
curl http://localhost:8081/trigger/scroll-to-test%20post
curl http://localhost:8081/trigger/navigate-to-children-6
```

## Testing

**Manual Test:**
1. View posts list with posts that have `childCount > 0`
2. Verify grey semi-transparent circle (42pt, 80% opacity) with white chevron appears on right edge, straddling the boundary
3. Swipe left on post with children (minimum 30pt) → child list appears
4. Verify standard iOS back button appears in navigation bar
5. Verify parent post title (21pt, semibold, black) appears to the right of back button
6. Scroll down in root view, navigate to child, tap back button
7. Verify root view scroll position is preserved (not reset to top)
8. Navigate to child view, swipe from left edge → return to parent
9. Verify ScrollView scrolls normally (up/down) without any gesture interference
10. Navigate multiple levels deep (verify title updates at each level)
11. Verify smooth NavigationStack slide animations between levels

**Programmatic Test (via UI Automation):**
```bash
# Scroll to specific post
curl http://localhost:8081/trigger/scroll-to-test%20post

# Navigate to child view
curl http://localhost:8081/trigger/navigate-to-children-6
```

**Edge Cases:**
- Post with `childCount = 0` or `null`: no arrow, no navigation
- Swipe left on post without children: no navigation, expand/collapse works
- Empty child list: shows "No posts yet" message
- Failed child fetch: shows error message with "Retry" button
- Failed parent fetch: title shows "..."
- Root view scroll position: preserved across navigation due to conditional fetching
