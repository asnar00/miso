# Search - iOS Implementation

## Overview

Search is implemented with three new SwiftUI components and integration in NoobTestApp:
1. **FloatingSearchBar** - Collapsible search UI (circular button ↔ full search bar)
2. **SearchResultsView** - Fetches and displays search results
3. **NoobTestApp integration** - Manages search state, preserves navigation, handles keyboard dismissal

**Key features**:
- **Collapsible UI**: Starts as 48pt circular button, expands to full bar with spring animation
- **Navigation preservation**: ZStack keeps PostsView alive (hidden) when searching, so clearing search restores exact position
- **Keyboard dismissal**: Transparent overlay appears when keyboard visible, tap anywhere to dismiss
- **Left-aligned**: Button sits 20pt from left edge for easy thumb access

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

## Key Implementation Details

1. **Why return IDs not full posts?**
   - Ensures search results have ALL fields (including `child_count`)
   - Reuses existing `/api/posts/{id}` endpoint
   - Maintains consistency between search and regular posts

2. **Debounce timing**: 0.5 seconds prevents excessive API calls while typing

3. **Search result ordering**: SearchResultsView preserves ranking order from search API

4. **ZStack overlay pattern**: FloatingSearchBar stays on top regardless of content changes

5. **iOS 17 compatibility**: Uses new `.onChange(of:)` API with both old and new value parameters
