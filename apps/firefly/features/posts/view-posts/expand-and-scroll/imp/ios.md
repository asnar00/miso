# expand-and-scroll iOS implementation

## State Variables

```swift
@State private var expandedPostId: Int? = nil
```

## ScrollViewReader Integration

```swift
ScrollViewReader { proxy in
    ScrollView {
        VStack(spacing: 8) {
            ForEach(posts) { post in
                PostView(
                    post: post,
                    isExpanded: expandedPostId == post.id,
                    onTap: {
                        if expandedPostId == post.id {
                            // Collapse currently expanded post
                            expandedPostId = nil
                        } else {
                            // Expand new post and scroll to it
                            expandedPostId = post.id
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo(post.id, anchor: .top)
                            }
                        }
                    }
                )
                .id(post.id)
            }
        }
        .padding()
    }
}
```

**Key decisions**:
- Use `ScrollViewReader` with `.id(post.id)` on each view to enable programmatic scrolling
- Pass `isExpanded` as a boolean to each PostView; the PostView handles its own `expansionFactor` animation
- Centralize tap handling and scrolling at the list level

## PostView expansionFactor Handling

Within PostView, the `isExpanded` binding drives the animation:

```swift
struct PostView: View {
    let post: Post
    let isExpanded: Bool
    let onTap: () -> Void

    @State private var expansionFactor: CGFloat = 0.0

    var body: some View {
        // ... layout using expansionFactor ...
        .onTapGesture {
            onTap()
        }
        .onChange(of: isExpanded) { _, newValue in
            withAnimation(.easeInOut(duration: 0.3)) {
                expansionFactor = newValue ? 1.0 : 0.0
            }
        }
    }
}
```

**Key decision**: PostView owns its `expansionFactor` and animates it based on the `isExpanded` prop, keeping view-level animation concerns separate from list-level coordination.

## Scroll-to-Expanded on Navigation Return

```swift
.onAppear {
    if let expandedId = expandedPostId {
        // Small delay to ensure layout is complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation {
                proxy.scrollTo(expandedId, anchor: .top)
            }
        }
    }
}
```

When returning from navigation (e.g., after viewing children), scroll back to the expanded post.

## First Post Auto-Expansion

```swift
case .success(let fetchedPosts):
    self.preloadImagesOptimized(for: fetchedPosts) {
        DispatchQueue.main.async {
            self.posts = fetchedPosts
            self.isLoading = false
            // Expand the first post by default
            if let firstPost = fetchedPosts.first {
                self.expandedPostId = firstPost.id
            }
        }
    }
```

**Key decision**: Auto-expand first post after images are preloaded but before displaying to user, ensuring smooth initial presentation.
