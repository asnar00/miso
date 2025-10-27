# post-view iOS implementation

## State Variables

```swift
@State private var expansionFactor: CGFloat = 0.0  // 0.0 = compact, 1.0 = expanded
@State private var imageAspectRatio: CGFloat = 1.0  // loaded asynchronously
@State private var bodyTextHeight: CGFloat = 200  // measured on first expand
@State private var titleSummaryHeight: CGFloat = 60  // measured dynamically
@State private var isMeasured: Bool = false  // tracks body text measurement
```

## Constants

```swift
let compactHeight: CGFloat = 100
let availableWidth: CGFloat = 350  // content width
let authorHeight: CGFloat = 15  // approximate author line height
```

## Height Calculation

```swift
let imageHeight = post.imageUrl != nil ? (availableWidth / imageAspectRatio) : 0
let expandedHeight: CGFloat = titleSummaryHeight + 16 + imageHeight + 16 + bodyTextHeight + 24 + authorHeight + 16

let currentHeight = lerp(compactHeight, expandedHeight, expansionFactor)
```

## Image Position and Size Interpolation

```swift
// Compact state (thumbnail)
let compactWidth: CGFloat = 80
let compactHeight: CGFloat = 80
let compactX = availableWidth - 80 + 8  // right-aligned with 8pt padding
let compactY: CGFloat = (100 - 80) / 2 + 8  // vertically centered with top padding

// Expanded state (full image)
let expandedWidth = availableWidth
let expandedHeight = availableWidth / imageAspectRatio
let expandedX: CGFloat = 10  // aligned with content left edge
let expandedY = titleSummaryHeight + 8  // below title/summary

// Interpolated values
let currentWidth = lerp(compactWidth, expandedWidth, expansionFactor)
let currentHeight = lerp(compactHeight, expandedHeight, expansionFactor)
let currentX = lerp(compactX, expandedX, expansionFactor)
let currentY = lerp(compactY, expandedY, expansionFactor)
```

## Image Rendering with Aspect Ratio Loading

```swift
AsyncImage(url: URL(string: fullUrl)) { phase in
    switch phase {
    case .success(let image):
        image
            .resizable()
            .aspectRatio(contentMode: .fill)  // fills frame maintaining aspect ratio
            .frame(width: currentWidth, height: currentHeight)
            .clipped()  // clips overflow
            .clipShape(RoundedRectangle(cornerRadius: 12))
    case .failure(_), .empty:
        Rectangle()
            .fill(Color.gray.opacity(0.3))
            .frame(width: currentWidth, height: currentHeight)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    @unknown default:
        EmptyView()
    }
}
.offset(x: currentX, y: currentY)
.task {
    // Load aspect ratio asynchronously
    if imageAspectRatio == 1.0 {
        if let url = URL(string: fullUrl) {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let uiImage = UIImage(data: data) {
                    imageAspectRatio = uiImage.size.width / uiImage.size.height
                }
            } catch {
                // Failed to load, keep default 1.0 aspect ratio
            }
        }
    }
}
```

**Key detail**: Using `.task` to load aspect ratio asynchronously avoids blocking the UI. The view renders with default 1.0 aspect ratio initially, then updates when actual ratio loads.

## Body Text Positioning

**Critical**: Body text position must track the current image position:

```swift
if isExpanded && isMeasured {
    // Recalculate current image dimensions (same calculation as image rendering)
    let compactImageHeight: CGFloat = 80
    let compactImageY: CGFloat = (100 - 80) / 2 + 8
    let expandedImageY = titleSummaryHeight + 8
    let expandedImageHeight = availableWidth / imageAspectRatio

    let currentImageY = lerp(compactImageY, expandedImageY, expansionFactor)
    let currentImageHeight = lerp(compactImageHeight, expandedImageHeight, expansionFactor)

    // Position body text below current image position
    let bodyY = currentImageY + currentImageHeight + 16
    let currentBodyHeight = lerp(0, bodyTextHeight, expansionFactor)

    Text(processBodyText(post.body))
        .foregroundColor(.black)
        .frame(width: availableWidth, alignment: .leading)
        .frame(height: bodyTextHeight, alignment: .top)
        .clipped()
        .mask(
            Rectangle()
                .frame(height: currentBodyHeight)
                .frame(maxHeight: .infinity, alignment: .top)
        )
        .offset(x: 10, y: bodyY)
}
```

**Why this works**: By recalculating `currentImageY` and `currentImageHeight` each frame, the body text stays "stuck" to the bottom of the image as it animates.

## Body Text Measurement

**Critical**: Measure the *formatted* text for accurate heights:

```swift
.background(
    // Measure body text only when needed (when expanding)
    // Use formatted text for accurate measurement
    Group {
        if isExpanded && !isMeasured {
            Text(processBodyText(post.body))
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: 350)
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(key: BodyHeightKey.self, value: geo.size.height)
                    }
                )
                .onPreferenceChange(BodyHeightKey.self) { height in
                    bodyTextHeight = height
                    isMeasured = true
                }
                .hidden()
        }
    }
)
```

**Key detail**: Using `processBodyText()` for measurement (not plain `post.body`) ensures the measured height matches the rendered height, accounting for headings, bullets, and line breaks.

## PreferenceKey for Height Measurement

```swift
struct BodyHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct TitleSummaryHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
```

## Title/Summary with Dynamic Height Measurement

```swift
VStack(alignment: .leading, spacing: 4) {
    Text(post.title)
        .font(.system(size: 22, weight: .bold))
        .foregroundColor(.black)
        .lineLimit(1)

    Text(post.summary)
        .font(.system(size: 15))
        .italic()
        .foregroundColor(.black.opacity(0.8))
        .lineLimit(2)
}
.padding(8)
.frame(maxWidth: .infinity, alignment: .leading)
.padding(.trailing, post.imageUrl != nil ? 96 : 0)  // leave room for thumbnail
.background(
    GeometryReader { geo in
        Color.clear.preference(key: TitleSummaryHeightKey.self, value: geo.size.height)
    }
)
.onPreferenceChange(TitleSummaryHeightKey.self) { height in
    titleSummaryHeight = height
}
```

## Author Metadata with Fade-In

```swift
if isExpanded && isMeasured {
    // Calculate position (tracking image position as above)
    let compactImageHeight: CGFloat = 80
    let compactImageY: CGFloat = (100 - 80) / 2 + 8
    let expandedImageY = titleSummaryHeight + 8
    let expandedImageHeight = availableWidth / imageAspectRatio

    let currentImageY = lerp(compactImageY, expandedImageY, expansionFactor)
    let currentImageHeight = lerp(compactImageHeight, expandedImageHeight, expansionFactor)
    let authorY = currentImageY + currentImageHeight + 16 + bodyTextHeight + 24

    HStack {
        if post.aiGenerated {
            Text("👓 librarian")
                .font(.subheadline)
                .foregroundColor(.black.opacity(0.5))
        } else if let authorName = post.authorName {
            Text(authorName)
                .font(.subheadline)
                .foregroundColor(.black.opacity(0.5))
        }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .offset(x: 10, y: authorY)  // aligned with content left edge
    .opacity(expansionFactor)  // fade in with expansion
}
```

**Key details**:
- Only rendered when `isExpanded && isMeasured` (not visible in compact view)
- Position tracks image via same recalculation pattern
- Opacity tied to `expansionFactor` for smooth fade-in
- Left-aligned with content at x: 10

## Complete Layout Structure

```swift
var body: some View {
    let compactHeight: CGFloat = 100
    let availableWidth: CGFloat = 350
    let imageHeight = post.imageUrl != nil ? (availableWidth / imageAspectRatio) : 0
    let authorHeight: CGFloat = 15
    let expandedHeight: CGFloat = titleSummaryHeight + 16 + imageHeight + 16 + bodyTextHeight + 24 + authorHeight + 16
    let currentHeight = lerp(compactHeight, expandedHeight, expansionFactor)

    ZStack(alignment: .topLeading) {
        // Background
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.white.opacity(0.9))
            .frame(height: currentHeight)
            .shadow(radius: 2)

        // Title and summary (always visible)
        VStack(alignment: .leading, spacing: 4) {
            Text(post.title)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.black)
                .lineLimit(1)

            Text(post.summary)
                .font(.system(size: 15))
                .italic()
                .foregroundColor(.black.opacity(0.8))
                .lineLimit(2)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.trailing, post.imageUrl != nil ? 96 : 0)
        .background(
            GeometryReader { geo in
                Color.clear.preference(key: TitleSummaryHeightKey.self, value: geo.size.height)
            }
        )
        .onPreferenceChange(TitleSummaryHeightKey.self) { height in
            titleSummaryHeight = height
        }

        // Body text (tracks image position)
        if isExpanded && isMeasured {
            let compactImageHeight: CGFloat = 80
            let compactImageY: CGFloat = (100 - 80) / 2 + 8
            let expandedImageY = titleSummaryHeight + 8
            let expandedImageHeight = availableWidth / imageAspectRatio

            let currentImageY = lerp(compactImageY, expandedImageY, expansionFactor)
            let currentImageHeight = lerp(compactImageHeight, expandedImageHeight, expansionFactor)
            let bodyY = currentImageY + currentImageHeight + 16
            let currentBodyHeight = lerp(0, bodyTextHeight, expansionFactor)

            Text(processBodyText(post.body))
                .foregroundColor(.black)
                .frame(width: availableWidth, alignment: .leading)
                .frame(height: bodyTextHeight, alignment: .top)
                .clipped()
                .mask(
                    Rectangle()
                        .frame(height: currentBodyHeight)
                        .frame(maxHeight: .infinity, alignment: .top)
                )
                .offset(x: 10, y: bodyY)
        }

        // Author metadata (tracks image + body position, fades in)
        if isExpanded && isMeasured {
            let compactImageHeight: CGFloat = 80
            let compactImageY: CGFloat = (100 - 80) / 2 + 8
            let expandedImageY = titleSummaryHeight + 8
            let expandedImageHeight = availableWidth / imageAspectRatio

            let currentImageY = lerp(compactImageY, expandedImageY, expansionFactor)
            let currentImageHeight = lerp(compactImageHeight, expandedImageHeight, expansionFactor)
            let authorY = currentImageY + currentImageHeight + 16 + bodyTextHeight + 24

            HStack {
                if post.aiGenerated {
                    Text("👓 librarian")
                        .font(.subheadline)
                        .foregroundColor(.black.opacity(0.5))
                } else if let authorName = post.authorName {
                    Text(authorName)
                        .font(.subheadline)
                        .foregroundColor(.black.opacity(0.5))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .offset(x: 10, y: authorY)
            .opacity(expansionFactor)
        }

        // Animated image
        if let imageUrl = post.imageUrl {
            let fullUrl = serverURL + imageUrl

            let compactWidth: CGFloat = 80
            let compactHeight: CGFloat = 80
            let compactX = availableWidth - 80 + 8
            let compactY: CGFloat = (compactHeight - 80) / 2 + 8

            let expandedWidth = availableWidth
            let expandedHeight = availableWidth / imageAspectRatio
            let expandedX: CGFloat = 10
            let expandedY = titleSummaryHeight + 8

            let currentWidth = lerp(compactWidth, expandedWidth, expansionFactor)
            let currentHeight = lerp(compactHeight, expandedHeight, expansionFactor)
            let currentX = lerp(compactX, expandedX, expansionFactor)
            let currentY = lerp(compactY, expandedY, expansionFactor)

            AsyncImage(url: URL(string: fullUrl)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: currentWidth, height: currentHeight)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                case .failure(_), .empty:
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: currentWidth, height: currentHeight)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                @unknown default:
                    EmptyView()
                }
            }
            .offset(x: currentX, y: currentY)
            .task {
                if imageAspectRatio == 1.0 {
                    if let url = URL(string: fullUrl) {
                        do {
                            let (data, _) = try await URLSession.shared.data(from: url)
                            if let uiImage = UIImage(data: data) {
                                imageAspectRatio = uiImage.size.width / uiImage.size.height
                            }
                        } catch {
                            // Keep default aspect ratio
                        }
                    }
                }
            }
        }
    }
    .background(
        // Measurement for body text
        Group {
            if isExpanded && !isMeasured {
                Text(processBodyText(post.body))
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(width: 350)
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(key: BodyHeightKey.self, value: geo.size.height)
                        }
                    )
                    .onPreferenceChange(BodyHeightKey.self) { height in
                        bodyTextHeight = height
                        isMeasured = true
                    }
                    .hidden()
            }
        }
    )
    .onTapGesture {
        onTap()
    }
    .onChange(of: isExpanded) { _, newValue in
        if newValue {
            // Expanding
            withAnimation(.easeInOut(duration: 0.3)) {
                expansionFactor = 1.0
            }
        } else {
            // Collapsing
            withAnimation(.easeInOut(duration: 0.3)) {
                expansionFactor = 0.0
            }
        }
    }
    .onAppear {
        // Set initial expansion state without animation
        expansionFactor = isExpanded ? 1.0 : 0.0
    }
}
```

## Linear Interpolation Helper

```swift
func lerp(_ start: CGFloat, _ end: CGFloat, _ t: CGFloat) -> CGFloat {
    return start + (end - start) * t
}
```

## Key iOS-Specific Decisions

1. **ZStack with absolute positioning**: Use `.offset()` for full control over interpolated positions
2. **PreferenceKey pattern**: Measure dynamic heights (title/summary, body text) without blocking UI
3. **`.task` modifier**: Load image aspect ratio asynchronously using URLSession
4. **Formatted text measurement**: Use `processBodyText()` for measurement, not plain text
5. **Position recalculation**: Body text and author position recalculate each frame to track image
6. **Conditional rendering**: Author only renders when `isExpanded && isMeasured`
7. **Opacity for fade**: Use `.opacity(expansionFactor)` for smooth author fade-in
8. **`.fill` with `.clipped()`**: Maintain image aspect ratio while filling frame
9. **SwiftUI reactivity**: All interpolated values recompute automatically when `expansionFactor` changes
10. **`.background()` for measurement**: Hidden measurement views don't affect layout

## Performance Considerations

1. **Measure once**: Body text height measured only on first expand (`isMeasured` flag)
2. **Async aspect ratio**: Image dimensions loaded asynchronously to avoid UI blocking
3. **No ImageCache calls**: Direct AsyncImage usage eliminates preloading overhead
4. **Efficient interpolation**: Simple linear interpolation is fast and smooth

This implementation creates a smooth, continuous animation that can be interrupted and reversed at any point without visual glitches.
