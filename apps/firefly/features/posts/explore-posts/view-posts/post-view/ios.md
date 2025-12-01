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
let compactX = availableWidth - 80 + 20  // right-aligned, moved right by 12pt for reduced list padding
let compactY: CGFloat = (100 - 80) / 2 + 8  // vertically centered with top padding

// Expanded state (full image)
let expandedWidth = availableWidth
let expandedHeight = availableWidth / imageAspectRatio
let expandedX: CGFloat = 18  // aligned with text content indent
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
        .offset(x: 18, y: bodyY)  // Increased from 10pt for more left indent
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
.padding(.leading, 16)  // Increased from 8pt for more text indent
.padding(.vertical, 8)
.padding(.trailing, 8)
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
        // Author name and date with 8pt spacing
        HStack(spacing: 8) {
            if post.aiGenerated {
                Text("👓 librarian")
                    .font(.subheadline)
                    .foregroundColor(.black.opacity(0.5))
            } else if let authorName = post.authorName {
                Text(authorName)
                    .font(.subheadline)
                    .foregroundColor(.black.opacity(0.5))
            }

            // Add formatted date with 16pt left padding
            if let formattedDate = formatPostDate(post.createdAt) {
                Text(formattedDate)
                    .font(.subheadline)
                    .foregroundColor(.black.opacity(0.5))
                    .padding(.leading, 16)
            }
        }
        .padding(.leading, 24)  // 18pt + 6pt = 24pt

        Spacer()

        // Edit/save/cancel buttons (if applicable)
        // ...
    }
    .frame(maxWidth: .infinity)
    .offset(x: 0, y: authorY)
    .opacity(expansionFactor)  // fade in with expansion
}
```

**Date Formatting Function:**

```swift
// Format date as "day monthname year" (e.g., "15 Oct 2025")
private func formatPostDate(_ dateString: String) -> String? {
    // Date format from server: "Wed, 15 Oct 2025 14:37:09 GMT"
    let inputFormatter = DateFormatter()
    inputFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
    inputFormatter.locale = Locale(identifier: "en_US_POSIX")

    guard let date = inputFormatter.date(from: dateString) else {
        return nil
    }

    let outputFormatter = DateFormatter()
    outputFormatter.dateFormat = "d MMM yyyy"
    return outputFormatter.string(from: date)
}
```

**Key details**:
- Only rendered when `isExpanded && isMeasured` (not visible in compact view)
- Position tracks image via same recalculation pattern
- Opacity tied to `expansionFactor` for smooth fade-in
- Author name and date in HStack with 8pt spacing
- Date has additional 16pt left padding for visual separation
- Date format: "day monthname year" (e.g., "5 Nov 2025")
- Input format from server: "Wed, 05 Nov 2025 14:37:09 GMT"

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
        .padding(.leading, 16)  // Increased from 8pt for more text indent
        .padding(.vertical, 8)
        .padding(.trailing, 8)
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
                .offset(x: 18, y: bodyY)  // Increased from 10pt for more left indent
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
            .offset(x: 18, y: authorY)  // Increased from 10pt for more left indent
            .opacity(expansionFactor)
        }

        // Animated image
        if let imageUrl = post.imageUrl {
            let fullUrl = serverURL + imageUrl

            let compactWidth: CGFloat = 80
            let compactHeight: CGFloat = 80
            let compactX = availableWidth - 80 + 20
            let compactY: CGFloat = (compactHeight - 80) / 2 + 8

            let expandedWidth = availableWidth
            let expandedHeight = availableWidth / imageAspectRatio
            let expandedX: CGFloat = 18
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

## Author Navigation

### Author Button Display

Author names are displayed as clickable lozenge buttons only if the author has a profile with content (non-empty title or summary). Profile posts themselves and authors without profiles show plain text:

```swift
// State to track if author has a profile
@State private var authorHasProfile: Bool = true  // Assume true until checked

// Author name and date section
HStack(spacing: 8) {
    if post.aiGenerated {
        Text("👓 librarian")
            .font(.subheadline)
            .foregroundColor(.black.opacity(0.5))
    } else if let authorName = post.authorName {
        // Make author name a button only if profile exists
        let isProfilePost = post.template == "profile"

        if isProfilePost || !authorHasProfile {
            // Profile posts or authors without profiles: just display text
            Text(authorName)
                .font(.subheadline)
                .foregroundColor(.black.opacity(0.5))
        } else {
            // Regular posts with profiles: make it a tappable button
            Button(action: {
                if let authorEmail = post.authorEmail {
                    Logger.shared.info("[PostView] Author button tapped: \(authorName) (\(authorEmail))")
                    fetchAndNavigateToProfile(authorEmail: authorEmail)
                }
            }) {
                Text(authorName)
                    .font(.subheadline)
                    .foregroundColor(.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(red: 0.85, green: 0.85, blue: 0.85))
                    .clipShape(Capsule())
            }
        }
    }

    // Add date with 16pt left padding
    if let formattedDate = formatPostDate(post.createdAt) {
        Text(formattedDate)
            .font(.subheadline)
            .foregroundColor(.black.opacity(0.5))
            .padding(.leading, 16)
    }
}
```

### Date Formatting

```swift
// Format date as "day monthname year" (e.g., "5 Nov 2025")
private func formatPostDate(_ dateString: String) -> String? {
    // Date format from server: "Wed, 15 Oct 2025 14:37:09 GMT"
    let inputFormatter = DateFormatter()
    inputFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
    inputFormatter.locale = Locale(identifier: "en_US_POSIX")

    guard let date = inputFormatter.date(from: dateString) else {
        return nil
    }

    let outputFormatter = DateFormatter()
    outputFormatter.dateFormat = "d MMM yyyy"
    return outputFormatter.string(from: date)
}
```

### Profile Check on Appear

When the view appears, check if the author has a profile with content to determine whether to show the button:

```swift
// Check if the author has a profile (called on appear)
private func checkAuthorProfile() {
    // Skip check for AI-generated posts or profile posts
    guard !post.aiGenerated, post.template != "profile", let authorEmail = post.authorEmail else {
        return
    }

    Logger.shared.info("[PostView] Checking if author \(authorEmail) has a profile")

    PostsAPI.shared.fetchUserProfile(userId: authorEmail) { result in
        DispatchQueue.main.async {
            switch result {
            case .success(let profilePost):
                // Only consider it a valid profile if it has a non-empty title or summary
                if let profile = profilePost {
                    let hasContent = !profile.title.isEmpty || !profile.summary.isEmpty
                    self.authorHasProfile = hasContent
                    Logger.shared.info("[PostView] Author \(authorEmail) has profile with content: \(hasContent)")
                } else {
                    self.authorHasProfile = false
                    Logger.shared.info("[PostView] Author \(authorEmail) has no profile")
                }
            case .failure(let error):
                Logger.shared.warning("[PostView] Failed to check profile: \(error.localizedDescription)")
                self.authorHasProfile = false
            }
        }
    }
}

// Called in onAppear
.onAppear {
    // Set initial expansion state without animation
    expansionFactor = isExpanded ? 1.0 : 0.0
    // Initialize editable content with post content
    editableTitle = post.title
    editableSummary = post.summary
    editableBody = post.body
    editableImageUrl = post.imageUrl
    // Check if author has a profile
    checkAuthorProfile()
}
```

### Profile Fetching and Navigation

```swift
// Fetch author's profile and navigate to it
private func fetchAndNavigateToProfile(authorEmail: String) {
    Logger.shared.info("[PostView] Fetching profile for \(authorEmail)")

    PostsAPI.shared.fetchUserProfile(userId: authorEmail) { result in
        DispatchQueue.main.async {
            switch result {
            case .success(let profilePost):
                if let profile = profilePost {
                    Logger.shared.info("[PostView] Profile found: \(profile.title), navigating...")
                    // Navigate to profile view with current post title as back label
                    if let navigate = onNavigateToProfile {
                        navigate(post.title, profile)
                    }
                } else {
                    Logger.shared.warning("[PostView] No profile found for \(authorEmail)")
                }
            case .failure(let error):
                Logger.shared.error("[PostView] Failed to fetch profile: \(error.localizedDescription)")
            }
        }
    }
}
```

### Navigation Structure

PostView receives an `onNavigateToProfile` callback that takes `(backLabel: String, profilePost: Post)`:

```swift
// In PostView
let onNavigateToProfile: ((String, Post) -> Void)?

// In PostsListView
PostView(
    post: post,
    // ... other params ...
    onNavigateToProfile: { backLabel, profilePost in
        navigationPath.append(.profile(backLabel: backLabel, profilePost: profilePost))
    }
)
```

### Navigation Destination Handling

```swift
// In PostsView.swift
enum PostsDestination: Hashable {
    case children(parentId: Int)  // Show children of a post
    case profile(backLabel: String, profilePost: Post)  // Show single profile post
}

.navigationDestination(for: PostsDestination.self) { destination in
    switch destination {
    case .children(let parentId):
        PostsListView(
            parentPostId: parentId,
            backLabel: nil,
            initialPosts: [],
            onPostCreated: onPostCreated,
            navigationPath: $navigationPath,
            showAddButton: true,
            initialExpandedPostId: nil
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
```

### Post Model

The Post struct includes a `template` field mapped to `template_name` in the API:

```swift
struct Post: Codable, Identifiable, Hashable {
    // ... other fields ...
    let template: String?

    enum CodingKeys: String, CodingKey {
        // ... other cases ...
        case template = "template_name"
    }
}
```

### Server API

**Endpoint**: `GET /api/users/{email}/profile`

**Response**:
```json
{
    "status": "success",
    "profile": {
        "id": 22,
        "user_id": 5,
        "parent_id": -1,
        "title": "asnaroo",
        "summary": "fix all the things",
        "body": "I'm a self-taught...",
        "image_url": "/uploads/407431e70f764516ae11b45bcae71a92.jpg",
        "created_at": "Fri, 31 Oct 2025 12:57:21 GMT",
        "timezone": "UTC",
        "location_tag": null,
        "ai_generated": false,
        "template_name": "profile",
        "placeholder_title": "name",
        "placeholder_summary": "mission",
        "placeholder_body": "personal statement",
        "author_name": "asnaroo",
        "author_email": "test@example.com",
        "child_count": 0
    }
}
```

**Critical**: The profile API must return both `author_name` (the profile title) and `author_email` (the user's email) for proper display and edit button functionality.

**Database query** (`db.py:get_user_profile`):
```sql
SELECT
    p.id, p.user_id, p.parent_id, p.title, p.summary, p.body,
    p.image_url, p.created_at, p.timezone, p.location_tag, p.ai_generated,
    p.template_name,
    t.placeholder_title, t.placeholder_summary, t.placeholder_body,
    p.title as author_name,
    u.email as author_email,
    0 as child_count
FROM posts p
LEFT JOIN users u ON p.user_id = u.id
LEFT JOIN templates t ON p.template_name = t.name
WHERE p.user_id = %s AND p.parent_id = -1
LIMIT 1
```
