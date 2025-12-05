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

### 1. PostsView.swift - Thin Wrapper with Conditional Add Button

Sets up NavigationStack and routes to PostsListView. For child navigation, uses ChildPostsListViewWrapper to determine Add Post button visibility:

```swift
enum PostsDestination: Hashable {
    case children(parentId: Int)
    case profile(backLabel: String, profilePost: Post)
}

struct PostsView: View {
    let initialPosts: [Post]
    let onPostCreated: () -> Void
    let showAddButton: Bool

    @State private var navigationPath: [PostsDestination] = []

    var body: some View {
        NavigationStack(path: $navigationPath) {
            PostsListView(
                parentPostId: nil,
                backLabel: nil,
                initialPosts: initialPosts,
                onPostCreated: onPostCreated,
                navigationPath: $navigationPath,
                showAddButton: showAddButton,
                initialExpandedPostId: nil
            )
            .navigationDestination(for: PostsDestination.self) { destination in
                switch destination {
                case .children(let parentId):
                    ChildPostsListViewWrapper(
                        parentId: parentId,
                        onPostCreated: onPostCreated,
                        navigationPath: $navigationPath
                    )
                case .profile(let backLabel, let profilePost):
                    PostsListView(
                        parentPostId: nil,
                        backLabel: backLabel,
                        initialPosts: [profilePost],
                        onPostCreated: onPostCreated,
                        navigationPath: $navigationPath,
                        showAddButton: false,
                        initialExpandedPostId: profilePost.id
                    )
                }
            }
        }
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(Color(red: 128/255, green: 128/255, blue: 128/255), for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
    }
}

// Wrapper to fetch parent post and determine showAddButton state
struct ChildPostsListViewWrapper: View {
    let parentId: Int
    let onPostCreated: () -> Void
    @Binding var navigationPath: [PostsDestination]

    @State private var parentPost: Post? = nil
    @State private var isLoading = true

    let serverURL = "http://185.96.221.52:8080"

    var shouldShowAddPostButton: Bool {
        guard let parent = parentPost else { return false }

        // Profile posts: only owner can add children
        if parent.template == "profile" {
            let loginState = Storage.shared.getLoginState()
            guard let currentEmail = loginState.email,
                  let authorEmail = parent.authorEmail else { return false }
            return authorEmail.lowercased() == currentEmail.lowercased()
        }

        // All other posts: anyone can add children
        return true
    }

    var body: some View {
        Group {
            if isLoading {
                ZStack {
                    Color(red: 128/255, green: 128/255, blue: 128/255)
                        .ignoresSafeArea()
                    ProgressView("Loading...")
                        .foregroundColor(.black)
                }
            } else {
                PostsListView(
                    parentPostId: parentId,
                    backLabel: nil,
                    initialPosts: [],
                    onPostCreated: onPostCreated,
                    navigationPath: $navigationPath,
                    showAddButton: shouldShowAddPostButton,
                    initialExpandedPostId: nil
                )
            }
        }
        .onAppear {
            fetchParentPost()
        }
    }

    func fetchParentPost() {
        guard let url = URL(string: "\(serverURL)/api/posts/\(parentId)") else {
            isLoading = false
            return
        }

        Logger.shared.info("[ChildPostsListViewWrapper] Fetching parent post \(parentId)")

        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data else {
                DispatchQueue.main.async {
                    isLoading = false
                }
                return
            }

            do {
                let postResponse = try JSONDecoder().decode(SinglePostResponse.self, from: data)
                DispatchQueue.main.async {
                    self.parentPost = postResponse.post
                    self.isLoading = false
                    Logger.shared.info("[ChildPostsListViewWrapper] Parent post fetched. parentId=\(postResponse.post.parentId), userId=\(postResponse.post.userId), showAddButton=\(shouldShowAddPostButton)")
                }
            } catch {
                Logger.shared.error("[ChildPostsListViewWrapper] Error fetching parent: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    isLoading = false
                }
            }
        }.resume()
    }
}
```

### 2. PostView.swift Changes

**Changes made:**
1. Child indicator overlay (grey circle with white chevron)
2. Left-swipe gesture for navigation to children
3. Body complexity fix (extracted 478-line body to `postContent` computed property)
4. ImagePicker moved inline from deleted NewPostView.swift

**Child indicator with smooth animation and swipe gesture:**

Target file: `NoobTest/PostView.swift`

The button uses `expansionFactor` (0.0 to 1.0) to smoothly interpolate between collapsed and expanded states, matching the card's expansion animation.

```swift
struct PostView: View {
    let post: Post
    let isExpanded: Bool
    let onTap: () -> Void
    let onPostCreated: () -> Void
    let onNavigateToChildren: ((Int) -> Void)?

    @State private var expansionFactor: CGFloat = 0.0  // Drives animation

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Existing post content...

            // Child indicator overlay - animated using expansionFactor
            // Hidden during edit mode to avoid interfering with edit controls
            if !isEditing && (post.childCount ?? 0) > 0 {
                // Interpolate size and position based on expansionFactor
                let collapsedSize: CGFloat = 32
                let expandedSize: CGFloat = 42
                let currentSize = lerp(collapsedSize, expandedSize, expansionFactor)

                // Collapsed: right edge with -6pt padding + 32pt, vertically centered
                // Expanded: 16pt from top, 16pt from right + 32pt
                let collapsedX: CGFloat = 350 + 6 + 32 - (collapsedSize / 2)  // = 372pt
                let expandedX: CGFloat = 350 - 16 + 32 - (expandedSize / 2)   // = 345pt
                let currentX = lerp(collapsedX, expandedX, expansionFactor)

                let collapsedY: CGFloat = currentHeight / 2  // Vertically centered
                let expandedY: CGFloat = 16 + (expandedSize / 2)  // = 37pt from top
                let currentY = lerp(collapsedY, expandedY, expansionFactor)

                childIndicatorButton
                    .frame(width: currentSize, height: currentSize)
                    .offset(x: currentX - currentSize/2, y: currentY - currentSize/2)
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
        .onChange(of: isExpanded) { oldValue, newValue in
            if newValue {
                // Expanding - animate expansionFactor to 1.0
                withAnimation(.easeInOut(duration: 0.3)) {
                    expansionFactor = 1.0
                }
            } else {
                // Collapsing - animate expansionFactor to 0.0
                withAnimation(.easeInOut(duration: 0.3)) {
                    expansionFactor = 0.0
                }
            }
        }
    }

    // Extracted child indicator button (reused throughout animation)
    private var childIndicatorButton: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.95))
                .shadow(color: Color.black.opacity(0.4), radius: 8, x: 0, y: 4)

            Image(systemName: "chevron.right")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Color.black)
        }
        .onTapGesture {
            if let navigate = onNavigateToChildren {
                navigate(post.id)
            }
        }
        .onAppear {
            // Register this post's navigation action for UI automation
            UIAutomationRegistry.shared.register(id: "navigate-to-children-\(post.id)") {
                if let navigate = onNavigateToChildren {
                    DispatchQueue.main.async {
                        navigate(post.id)
                    }
                }
            }
        }
    }
}
```

**Key implementation details:**
- Uses single view structure throughout animation (not if/else branches)
- Interpolates all properties: size, x-position, y-position
- Synchronized with card expansion via shared `expansionFactor` state
- Shadow creates depth without outline
- Button is tappable throughout animation

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

    // Determine if the Add Post button should be shown
    private var shouldShowAddButton: Bool {
        // If showAddButton is explicitly false, respect that (e.g., search results)
        if !showAddButton { return false }

        // If custom text provided, always show button
        if customAddButtonText != nil { return true }

        // For child posts: anyone can add, except for profiles (only owner can add)
        if parentPostId != nil {
            if let parent = parentPost {
                if parent.template == "profile" {
                    let loginState = Storage.shared.getLoginState()
                    if let userEmail = loginState.email, let parentEmail = parent.authorEmail {
                        return userEmail.lowercased() == parentEmail.lowercased()
                    }
                    return false
                }
                // For all other posts, anyone can add children
                return true
            }
            return false  // Parent not loaded yet
        }

        // Root level: show unless it's a profile list
        guard let firstPost = posts.first else { return showAddButton }
        return firstPost.template != "profile"
    }

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
        .navigationBarBackButtonHidden(true)  // Hide standard back button
        .toolbar {
            // Custom back button for child views (no background)
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
                    }
                }
            }
        }
        .simultaneousGesture(
            parentPostId != nil ?
                DragGesture(minimumDistance: 30)
                    .onChanged { value in
                        Logger.shared.info("[PostsListView] Drag changed: translation.width = \(value.translation.width), translation.height = \(value.translation.height)")
                    }
                    .onEnded { value in
                        Logger.shared.info("[PostsListView] Drag ended: translation.width = \(value.translation.width), translation.height = \(value.translation.height)")
                        // Swipe right to go back (positive x translation, at least 50pt, and more horizontal than vertical)
                        if value.translation.width > 50 && abs(value.translation.width) > abs(value.translation.height) {
                            Logger.shared.info("[PostsListView] Swipe right detected! Going back...")
                            navigationPath.removeLast()
                        } else {
                            Logger.shared.info("[PostsListView] Not a swipe right (width=\(value.translation.width), height=\(value.translation.height))")
                        }
                    }
                : nil
        )
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
4. **Custom Back Button**: Simple chevron + text without background, using `.navigationBarBackButtonHidden(true)` to hide standard button
5. **Custom Swipe Gesture**: `.simultaneousGesture()` with DragGesture to allow swipe-right from anywhere (not just edge)
6. **Swipe Detection**: Minimum 50pt horizontal movement, must be more horizontal than vertical (`abs(width) > abs(height)`)
7. **Gesture Compatibility**: Uses `.simultaneousGesture()` to work alongside ScrollView's vertical scrolling
8. **Circle Indicator Design**: Grey semi-transparent circle (RGB 128/128/128, 80% opacity) with white chevron, no border
9. **Edge Straddling**: Indicator positioned -10pt trailing so circle straddles post edge
10. **UI Automation**: Programmatic scroll and navigation actions registered via UIAutomationRegistry for testing
11. **Code Organization**: ImagePicker moved inline to PostView.swift; ChildPostsView and NewPostView deleted (functionality unified)

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
- Custom back button (no background)
- Chevron icon: `chevron.left`, 20pt semibold, black
- Parent post title: 17pt semibold, black, 1 line max
- Icon-to-text spacing: 8pt
- Placement: `.navigationBarLeading` (left side)
- Standard back button hidden with `.navigationBarBackButtonHidden(true)`
- Navigation bar hidden for root view, shown for child views

## Gestures

**Swipe Left on Post:**
- Minimum distance: 30pt
- Condition: Post must have children (`childCount > 0`)
- Action: Navigate to child posts view (`navigationPath.append(postId)`)

**Swipe Right to Go Back:**
- Works from anywhere on the screen (not just edge)
- Minimum distance: 30pt (DragGesture parameter)
- Minimum horizontal movement: 50pt
- Must be more horizontal than vertical: `abs(width) > abs(height)`
- Implementation: `.simultaneousGesture()` with DragGesture
- Action: `navigationPath.removeLast()`
- Logging: Logs drag changes and final decision for debugging

**Custom Back Button:**
- Tap action: `navigationPath.removeLast()`
- Shows chevron + parent post title
- No background (simple text button)

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
4. Verify custom back button appears in navigation bar (chevron + parent title, no background)
5. Tap back button → return to parent view
6. Navigate to child view again
7. Swipe right from anywhere on the screen (minimum 50pt horizontal, more horizontal than vertical) → return to parent
8. Scroll down in root view, navigate to child, go back
9. Verify root view scroll position is preserved (not reset to top)
10. Verify ScrollView scrolls normally (up/down) without gesture interference
11. Navigate multiple levels deep (verify title updates at each level)
12. Verify smooth NavigationStack slide animations between levels
13. Check logs for drag gesture debugging output

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
