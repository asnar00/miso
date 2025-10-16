# expand-and-scroll iOS implementation

## State Variables

```swift
@State private var expandedPostIds: Set<Int> = []
@State private var isAnimatingCollapse = false
@State private var collapseHeight: CGFloat? = nil
@State private var measuredCompactHeight: CGFloat = 110
```

## ScrollViewReader Integration

```swift
ScrollViewReader { proxy in
    ScrollView {
        VStack(spacing: 8) {
            ForEach(posts) { post in
                PostCardView(
                    post: post,
                    isExpanded: Binding(
                        get: { expandedPostIds.contains(post.id) },
                        set: { expanded in
                            if expanded {
                                // Collapse all other posts
                                expandedPostIds.removeAll()
                                expandedPostIds.insert(post.id)
                                // Scroll to top of expanded post concurrently
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    proxy.scrollTo(post.id, anchor: .top)
                                }
                            } else {
                                expandedPostIds.remove(post.id)
                            }
                        }
                    )
                )
                .id(post.id)
            }
        }
        .padding()
    }
}
```

**Key decision**: Use `ScrollViewReader` with `.id(post.id)` on each card to enable programmatic scrolling to specific posts.

## Tap Gesture for Expand/Collapse

```swift
.onTapGesture {
    withAnimation(.easeInOut(duration: 0.3)) {
        isExpanded.toggle()
    }
}
```

**Key decisions**:
- Use `.toggle()` to flip between expanded and collapsed states
- Use `.easeInOut` instead of spring animation to avoid bounce effect, providing a smoother, more predictable animation
- Single tap gesture handles both expand (when compact) and collapse (when expanded)

## Collapse Animation Handler

```swift
.onChange(of: isExpanded) { oldValue, newValue in
    if oldValue && !newValue {
        // Started collapsing
        isAnimatingCollapse = true
        collapseHeight = nil  // Start at full height

        // Animate height down to compact size
        withAnimation(.easeInOut(duration: 0.3)) {
            collapseHeight = measuredCompactHeight
        }

        // After animation completes, switch to compact view
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isAnimatingCollapse = false
            collapseHeight = nil
        }
    }
}
```

**Key decision**: Use `onChange` to detect collapse start, then coordinate the height animation with a delayed view swap.

## View Rendering During Animation

```swift
var body: some View {
    Group {
        if isExpanded || isAnimatingCollapse {
            fullView
                .fixedSize(horizontal: false, vertical: true)
                .frame(height: collapseHeight, alignment: .top)
                .clipped()
        } else {
            compactView
        }
    }
    .padding()
    .background(Color.white.opacity(0.9))
    .cornerRadius(12)
    .shadow(radius: 2)
}
```

**Key iOS-specific decisions**:
- `.fixedSize(horizontal: false, vertical: true)` - Prevents vertical layout recalculation during animation
- `.frame(height: collapseHeight, alignment: .top)` - Animatable height with top alignment
- `.clipped()` - Clips overflow content from the bottom
- Keep showing fullView during animation (`isAnimatingCollapse`) to maintain content stability

## First Post Auto-Expansion

```swift
case .success(let fetchedPosts):
    self.preloadImagesOptimized(for: fetchedPosts) {
        DispatchQueue.main.async {
            self.posts = fetchedPosts
            self.isLoading = false
            // Expand the first post by default
            if let firstPost = fetchedPosts.first {
                self.expandedPostIds.insert(firstPost.id)
            }
        }
    }
```

**Key decision**: Auto-expand first post after images are preloaded but before displaying to user, ensuring smooth initial presentation.
