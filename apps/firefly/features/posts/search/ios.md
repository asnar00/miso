# Search - iOS Implementation

## Overview

Search is implemented with three new SwiftUI components and integration in NoobTestApp:
1. **FloatingSearchBar** - Collapsible search UI (circular button ↔ full search bar)
2. **SearchResultsView** - Fetches and displays search results
3. **NoobTestApp integration** - Manages search state, preserves navigation, handles keyboard dismissal
4. **Notification Badge** - Red dot indicator on query posts with new matches

**Key features**:
- **Collapsible UI**: Starts as 48pt circular button, expands to full bar with spring animation
- **Navigation preservation**: ZStack keeps PostsView alive (hidden) when searching, so clearing search restores exact position
- **Keyboard dismissal**: Transparent overlay appears when keyboard visible, tap anywhere to dismiss
- **Left-aligned**: Button sits 20pt from left edge for easy thumb access
- **Notification badges**: Red dot (8pt diameter) appears on queries with `has_new_matches=true`

## Component 1: FloatingSearchBar

**File**: `apps/firefly/product/client/imp/ios/NoobTest/FloatingSearchBar.swift`

A collapsible search component that starts as a circular button and expands to a full search bar.

### Visual Specifications - Collapsed State

- **Shape**: Circle
- **Size**: 48pt x 48pt
- **Background**: `Color(white: 0.05)` - almost black
- **Shadow**: black 30% opacity, radius 8pt, y-offset 4pt
- **Icon**: Magnifying glass, white, 20pt
- **Position**: 20pt from left edge, 4pt from bottom
- **Alignment**: `.leading` (left-aligned via `.frame(maxWidth: .infinity, alignment: .leading)`)

### Visual Specifications - Expanded State

- **Background**: `Color(white: 0.05)` - almost black
- **Corner radius**: 25pt
- **Shadow**: black 30% opacity, radius 8pt, y-offset 4pt
- **Horizontal padding**: 16pt
- **Vertical padding**: 12pt
- **Bottom padding**: 4pt from screen edge
- **Max width**: 600pt
- **Icon size**: 18pt (magnifying glass, white 60% opacity)
- **Text color**: white
- **Cursor color**: white (via `.tint(.white)`)
- **Placeholder color**: `Color.white.opacity(0.6)`

### Behavior

- **Expand**: Tap collapsed button → spring animation (response: 0.3, dampingFraction: 0.7), auto-focus text field after 0.1s
- **Collapse**: When keyboard dismissed (focus lost) and text empty → spring animation back to button
- **Debounce**: 0.5 seconds after last keystroke
- **Clear button**: Appears when text non-empty, clears text, calls `onClear()`, unfocuses field
- **Transition**: `.scale(scale: 0.8, anchor: .bottomLeading).combined(with: .opacity)`
- **UI Automation**: Auto-registers with `UIAutomationRegistry` using `.accessibilityIdentifier("search-field")`

### State Management

- `@State private var isExpanded`: Controls collapsed vs expanded state
- `@FocusState.Binding var isFocused`: Shared with parent for keyboard control
- Watches `isFocused` changes to auto-collapse when keyboard dismissed and text empty

### Complete Implementation

```swift
import SwiftUI

struct FloatingSearchBar: View {
    @Binding var searchText: String
    @FocusState.Binding var isFocused: Bool
    @State private var isExpanded = false
    let onSearch: (String) -> Void
    let onClear: () -> Void

    var body: some View {
        Group {
            if isExpanded {
                // Expanded search bar
                HStack(spacing: 12) {
                    // Search icon
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(Color.white.opacity(0.6))
                        .font(.system(size: 18))

                    // Text field
                    TextField("Search posts...", text: $searchText, prompt: Text("Search posts...").foregroundColor(Color.white.opacity(0.6)))
                        .focused($isFocused)
                        .textFieldStyle(.plain)
                        .foregroundColor(.white)
                        .tint(.white)
                        .accessibilityIdentifier("search-field")
                        .onAppear {
                            UIAutomationRegistry.shared.registerTextField(id: "search-field") { text in
                                self.searchText = text
                            }
                        }
                        .onChange(of: searchText) { oldValue, newValue in
                            if !newValue.isEmpty {
                                // Debounce search
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    if searchText == newValue {
                                        onSearch(newValue)
                                    }
                                }
                            } else {
                                onClear()
                            }
                        }

                    // Clear button
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                            onClear()
                            isFocused = false
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                                .font(.system(size: 18))
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 25)
                        .fill(Color(white: 0.05))
                        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
                )
                .frame(maxWidth: 600)
                .transition(.scale(scale: 0.8, anchor: .bottomLeading).combined(with: .opacity))
            } else {
                // Collapsed search button
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isExpanded = true
                    }
                    // Auto-focus the text field after expansion
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isFocused = true
                    }
                }) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.white)
                        .font(.system(size: 20))
                        .frame(width: 48, height: 48)
                        .background(
                            Circle()
                                .fill(Color(white: 0.05))
                                .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
                        )
                }
                .transition(.scale(scale: 0.8, anchor: .bottomLeading).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.bottom, 4)
        .onChange(of: isFocused) { oldValue, newValue in
            // Collapse when unfocused and search is empty
            if !newValue && searchText.isEmpty {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded = false
                }
            }
        }
    }
}
```

## Component 2: SearchResultsView

**File**: `apps/firefly/product/client/imp/ios/NoobTest/SearchResultsView.swift`

Receives post IDs from search API, fetches full post data, and displays using PostsView.

### Key Design

- Takes `postIds: [Int]` as input
- Fetches each post individually using `/api/posts/{id}` endpoint
- Uses `DispatchGroup` to coordinate parallel fetches
- Preserves search ranking order
- Passes fetched posts to standard `PostsView` component

### Complete Implementation

```swift
import SwiftUI

struct SearchResultsView: View {
    let postIds: [Int]
    let onPostCreated: () -> Void

    @State private var posts: [Post] = []
    @State private var isLoading = true

    let serverURL = "http://185.96.221.52:8080"

    var body: some View {
        PostsView(
            initialPosts: posts,
            onPostCreated: onPostCreated,
            showAddButton: false
        )
        .onAppear {
            fetchPosts()
        }
        .onChange(of: postIds) { oldValue, newValue in
            Logger.shared.info("[SearchResultsView] postIds changed from \(oldValue.count) to \(newValue.count)")
            fetchPosts()
        }
    }

    func fetchPosts() {
        guard !postIds.isEmpty else {
            Logger.shared.info("[SearchResultsView] No post IDs to fetch")
            posts = []
            isLoading = false
            return
        }

        Logger.shared.info("[SearchResultsView] Fetching \(postIds.count) posts")
        isLoading = true

        // Fetch posts one by one (could be optimized with batch endpoint later)
        var fetchedPosts: [Post] = []
        let group = DispatchGroup()

        for postId in postIds {
            group.enter()
            guard let url = URL(string: "\(serverURL)/api/posts/\(postId)") else {
                group.leave()
                continue
            }

            URLSession.shared.dataTask(with: url) { data, response, error in
                defer { group.leave() }

                guard let data = data else {
                    Logger.shared.error("[SearchResultsView] No data for post \(postId)")
                    return
                }

                do {
                    let postResponse = try JSONDecoder().decode(SinglePostResponse.self, from: data)
                    fetchedPosts.append(postResponse.post)
                    Logger.shared.info("[SearchResultsView] Fetched post \(postId)")
                } catch {
                    Logger.shared.error("[SearchResultsView] Failed to decode post \(postId): \(error.localizedDescription)")
                }
            }.resume()
        }

        group.notify(queue: .main) {
            Logger.shared.info("[SearchResultsView] Fetched \(fetchedPosts.count) of \(postIds.count) posts")
            // Sort by original order
            self.posts = postIds.compactMap { id in fetchedPosts.first(where: { $0.id == id }) }
            self.isLoading = false
        }
    }
}
```

## Component 3: NoobTestApp Integration

**File**: `apps/firefly/product/client/imp/ios/NoobTest/NoobTestApp.swift`

### State Variables

Add to NoobTestApp:
```swift
@State private var searchText = ""
@State private var searchResultIds: [Int] = []
@State private var isSearching = false
@FocusState private var isSearchFieldFocused: Bool  // For keyboard control
```

### View Structure

**Key design**: Use ZStack with both PostsView and SearchResultsView always alive, control visibility with opacity. This preserves navigation state when switching between normal view and search results.

```swift
ZStack {
    // Main content layer
    ZStack {
        Color(red: 64/255, green: 224/255, blue: 208/255)  // Turquoise
            .ignoresSafeArea()

        if isLoadingPosts {
            // Loading indicator...
        } else if let error = postsError {
            // Error view...
        } else {
            // Keep both views alive, control visibility with ZStack
            ZStack {
                // Main posts view - always alive to preserve navigation state
                PostsView(
                    initialPosts: posts,
                    onPostCreated: fetchRecentUsers,
                    showAddButton: false
                )
                .opacity(isSearching ? 0 : 1)
                .allowsHitTesting(!isSearching)

                // Search results view - overlays when searching
                if isSearching {
                    SearchResultsView(postIds: searchResultIds, onPostCreated: fetchRecentUsers)
                }

                // Invisible overlay to dismiss keyboard - only when keyboard is focused
                if isSearchFieldFocused {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            isSearchFieldFocused = false
                        }
                }
            }
        }
    }

    // Floating search bar overlay
    VStack {
        Spacer()
        FloatingSearchBar(
            searchText: $searchText,
            isFocused: $isSearchFieldFocused,
            onSearch: { query in
                performSearch(query)
            },
            onClear: {
                isSearching = false
                searchResultIds = []
            }
        )
    }
}
```

### performSearch Function

```swift
func performSearch(_ query: String) {
    guard !query.isEmpty else {
        Logger.shared.info("[SEARCH] Query is empty, skipping search")
        return
    }

    Logger.shared.info("[SEARCH] Setting isSearching = true")
    isSearching = true

    let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
    let urlString = "http://185.96.221.52:8080/api/search?q=\(encodedQuery)&limit=20"

    guard let url = URL(string: urlString) else {
        Logger.shared.error("[SEARCH] Invalid URL: \(urlString)")
        return
    }

    Logger.shared.info("[SEARCH] Searching for: \(query)")

    URLSession.shared.dataTask(with: url) { data, response, error in
        if let error = error {
            Logger.shared.error("[SEARCH] Error: \(error.localizedDescription)")
            return
        }

        guard let data = data else {
            Logger.shared.error("[SEARCH] No data received")
            return
        }

        do {
            struct SearchResult: Codable {
                let id: Int
                let relevance_score: Double
            }
            let results = try JSONDecoder().decode([SearchResult].self, from: data)
            Logger.shared.info("[SEARCH] Found \(results.count) results, dispatching to main thread")
            DispatchQueue.main.async {
                Logger.shared.info("[SEARCH] On main thread, setting searchResultIds to \(results.count) IDs")
                Logger.shared.info("[SEARCH] Current isSearching = \(self.isSearching)")
                self.searchResultIds = results.map { $0.id }
                Logger.shared.info("[SEARCH] searchResultIds updated: \(self.searchResultIds), UI should refresh now")
            }
        } catch {
            Logger.shared.error("[SEARCH] Decoding error: \(error.localizedDescription)")
        }
    }.resume()
}
```

## Xcode Project Integration

Add new files to Xcode project:
- `NoobTest/FloatingSearchBar.swift`
- `NoobTest/SearchResultsView.swift`

Can be added manually via Xcode or using `add-file-to-project.py` script:
```bash
cd apps/firefly/product/client/imp/ios
python3 ../../../miso/platforms/ios/development/add-file-to-project.py \
    NoobTest.xcodeproj/project.pbxproj \
    NoobTest/FloatingSearchBar.swift
```

## UI Automation Support

The TextField in FloatingSearchBar auto-registers for UI automation:
```swift
.accessibilityIdentifier("search-field")
.onAppear {
    UIAutomationRegistry.shared.registerTextField(id: "search-field") { text in
        self.searchText = text
    }
}
```

Test via HTTP:
```bash
curl -X POST "http://localhost:8081/test/set-text?id=search-field&text=technology"
```

## Component 4: Notification Badge

**Purpose**: Display a red dot on query posts when they have new matches (has_new_matches=true)

### Integration Point

The notification badge is added to **PostView** component when displaying query posts.

**File**: `apps/firefly/product/client/imp/ios/NoobTest/PostView.swift`

### Visual Specifications

- **Shape**: Circle
- **Size**: 8pt diameter
- **Color**: Red `Color.red`
- **Position**: Top-right corner of post card
  - 8pt from top edge
  - 8pt from right edge
- **Layer**: Appears above post content using `.overlay(alignment: .topTrailing)`
- **Visibility**: Only shown when `post.hasNewMatches == true`

### Implementation

Add to PostView's body, wrapping the main VStack:

```swift
VStack(...) {
    // Existing post content
}
.overlay(alignment: .topTrailing) {
    if post.hasNewMatches == true {
        Circle()
            .fill(Color.red)
            .frame(width: 8, height: 8)
            .offset(x: -8, y: 8)
    }
}
```

### Data Model Update

**File**: `apps/firefly/product/client/imp/ios/NoobTest/Post.swift`

Add `hasNewMatches` field to Post struct:

```swift
struct Post: Codable, Identifiable, Hashable {
    // ... existing fields ...
    let hasNewMatches: Bool?

    enum CodingKeys: String, CodingKey {
        // ... existing cases ...
        case hasNewMatches = "has_new_matches"
    }
}
```

## Key Implementation Details

1. **Why return IDs not full posts?**
   - Ensures search results have ALL fields (including `child_count`)
   - Reuses existing `/api/posts/{id}` endpoint
   - Maintains consistency between search and regular posts

2. **Debounce timing**: 0.5 seconds prevents excessive API calls while typing

3. **Search result ordering**: SearchResultsView preserves ranking order from search API

4. **ZStack overlay pattern**: FloatingSearchBar stays on top regardless of content changes

5. **iOS 17 compatibility**: Uses new `.onChange(of:)` API with both old and new value parameters

6. **Notification badge positioning**: Uses `.overlay(alignment: .topTrailing)` with negative offset to position badge 8pt from edges

## Component 4: Badge Polling System

**Purpose**: Dynamically update notification badges on query posts based on server-side timestamp comparison.

### Architecture

**Badge State Management**:
- Parent view (PostsListView) polls `/api/queries/badges` every 5 seconds
- Maintains `badgeStates: [Int: Bool]` dictionary (query ID → badge visibility)
- Passes badge state down to PostView via `showNotificationBadge` parameter
- PostView has no local badge state - purely displays what parent provides

**Timestamp Logic** (server-side):
- Each query has `last_match_added_at` timestamp (updated when matches added)
- Each user-query pair has `last_viewed_at` in `query_views` table
- Badge shows when: `last_match_added_at > last_viewed_at` (or never viewed)
- Badge hides when: user views query (server records view time)

### PostsListView.swift - Badge Polling

**New state variables**:
```swift
@State private var badgeStates: [Int: Bool] = [:]  // Track badge state per post ID
@State private var pollingTimer: Timer? = nil  // Timer for regular polling
```

**Polling function**:
```swift
func pollQueryBadges() {
    // Only poll if we're showing queries
    let queryPosts = posts.filter { $0.template == "query" }
    guard !queryPosts.isEmpty else { return }

    let queryIds = queryPosts.map { $0.id }

    // Get current user email
    guard let userEmail = Storage.shared.getLoginState().email else { return }

    guard let url = URL(string: "\(serverURL)/api/queries/badges") else { return }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    let body: [String: Any] = [
        "user_email": userEmail,
        "query_ids": queryIds
    ]

    guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else { return }
    request.httpBody = jsonData

    Logger.shared.info("[PostsListView] Polling badges for \(queryIds.count) queries")

    URLSession.shared.dataTask(with: request) { data, response, error in
        guard let data = data else { return }

        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Bool] {
                DispatchQueue.main.async {
                    // Convert string keys back to Int
                    for (key, value) in json {
                        if let queryId = Int(key) {
                            self.badgeStates[queryId] = value
                        }
                    }
                    Logger.shared.info("[PostsListView] Updated badge states: \(self.badgeStates)")
                }
            }
        } catch {
            Logger.shared.error("[PostsListView] Error parsing badge response: \(error.localizedDescription)")
        }
    }.resume()
}
```

**Lifecycle management** (in .onAppear / .onDisappear):
```swift
.onAppear {
    // ... existing onAppear code ...

    // Start badge polling for query lists
    pollQueryBadges()  // Poll immediately
    pollingTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
        pollQueryBadges()
    }
}
.onDisappear {
    // Stop polling when view disappears
    pollingTimer?.invalidate()
    pollingTimer = nil
}
```

**Passing badge state to PostView**:
```swift
ForEach(posts) { post in
    PostView(
        post: post,
        isExpanded: viewModel.expandedPostId == post.id,
        isEditing: editingPostId == post.id,
        showNotificationBadge: badgeStates[post.id] ?? false,  // Pass polled state
        onTap: { /* ... */ },
        // ... other callbacks ...
    )
}
```

### PostView.swift - Badge Display

**Parameter addition**:
```swift
struct PostView: View {
    let post: Post
    let isExpanded: Bool
    var isEditing: Bool = false
    var showNotificationBadge: Bool = false  // NEW: Passed from parent (polled state)
    // ... other properties ...
}
```

**Badge overlay** (added to main content):
```swift
var body: some View {
    // ... main post content ...

    .overlay(alignment: .topTrailing) {
        if showNotificationBadge {
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
                .offset(x: -8, y: 8)
        }
    }
}
```

**Visual specs**:
- Shape: Circle
- Size: 8pt diameter
- Color: `Color.red` (standard iOS red)
- Position: 8pt from top edge, 8pt from right edge
- Implementation: `.overlay(alignment: .topTrailing)` with `.offset(x: -8, y: 8)`
- The negative offsets move the badge inward from the trailing/top edges

### PostsView.swift - Recording Query Views

**In QueryResultsViewWrapper.performSearch()**:
```swift
func performSearch() {
    let startTime = Date()
    Logger.shared.info("[QueryResultsViewWrapper] Searching with query post ID: \(queryPostId)")

    // Get user email for recording view
    let userEmail = Storage.shared.getLoginState().email ?? ""
    let encodedEmail = userEmail.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

    let urlString = "\(serverURL)/api/search?query_id=\(queryPostId)&limit=20&user_email=\(encodedEmail)"

    guard let url = URL(string: urlString) else {
        Logger.shared.error("[QueryResultsViewWrapper] Invalid URL: \(urlString)")
        isLoading = false
        return
    }

    // ... rest of search implementation ...
}
```

**Key points**:
- Add `&user_email=` parameter to `/api/search` endpoint
- URL-encode email to handle special characters (e.g., `+` in email addresses)
- Server records view time when this endpoint is called
- Next badge poll will reflect the updated view time (badge disappears)

### Data Flow

1. **PostsListView appears** → Immediate call to `pollQueryBadges()`
2. **Every 5 seconds** → Timer fires, calls `pollQueryBadges()` again
3. **Server responds** → JSON like `{"30": true, "31": false, "32": true, "35": false}`
4. **Update badgeStates** → Dictionary updated on main thread
5. **SwiftUI re-renders** → PostViews automatically show/hide badges based on new state
6. **User taps ">" button** → Navigate to QueryResultsView
7. **performSearch() called** → Includes `user_email` parameter
8. **Server records view** → Updates `query_views.last_viewed_at` for this user
9. **Next poll (within 5s)** → Badge disappears for that query

### Post.swift - Data Model (Deprecated Field)

```swift
struct Post: Codable, Identifiable, Hashable {
    let id: Int
    // ... other fields ...
    let hasNewMatches: Bool?  // Deprecated: kept for API compatibility, not used

    enum CodingKeys: String, CodingKey {
        // ... other cases ...
        case hasNewMatches = "has_new_matches"
    }
}
```

**Note**: The `hasNewMatches` field is no longer used. Badge state comes exclusively from the polling endpoint, which provides per-user badge state using timestamp comparison.

### API Endpoint

**URL**: `POST http://185.96.221.52:8080/api/queries/badges`

**Request**:
```json
{
    "user_email": "test@example.com",
    "query_ids": [30, 31, 32, 35]
}
```

**Response**:
```json
{
    "30": false,
    "31": true,
    "32": true,
    "35": true
}
```

**Response logic** (per query):
- `true`: New matches added after user last viewed this query (or never viewed)
- `false`: User has viewed query since last match was added (or no matches exist)

### Multi-User Support

The timestamp-based architecture ensures proper multi-user behavior:
- Each user has independent `last_viewed_at` in `query_views` table
- User A viewing a query doesn't clear badge for User B
- Badge reappears when new matches added after user's last view
- Ready for future query sharing features (public queries, collaborative searches, etc.)

### Performance Considerations

**Polling overhead**:
- Single POST request for all visible queries (batch operation)
- Fires every 5 seconds only when query list is visible
- Stops immediately when user navigates away (onDisappear)
- Server response is lightweight (just boolean flags, no post data)

**Network efficiency**:
- Batches all query IDs into single request (not one request per query)
- Uses POST with JSON body (cleaner than long GET query strings)
- Server does single database query with LEFT JOIN (efficient)

**UI responsiveness**:
- Async network call doesn't block main thread
- Updates dispatched to main queue only
- SwiftUI automatically re-renders only affected views
- No manual view refresh needed
