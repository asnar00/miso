# toolbar iOS implementation
*SwiftUI floating toolbar with three explorer buttons*

## Overview

Implements a sleek, rounded lozenge toolbar at the bottom of the screen using SwiftUI. The toolbar floats above content with a strong shadow, creating a modern, polished appearance. It contains three SF Symbol icons (speech bubble, magnifying glass, two people) arranged horizontally with equal spacing in a light grey pill-shaped container. Each button switches to a different explorer view showing different filtered content.

## Files to Modify

1. **ContentView.swift** - Add explorer switching logic and toolbar
2. **Toolbar.swift** - NEW FILE - Create toolbar component

**No new explorer view files needed** - reuses existing PostsView, UsersView, and ProfileView

## Implementation

### 1. Create Toolbar.swift

Create new file at: `apps/firefly/product/client/imp/ios/NoobTest/Toolbar.swift`

```swift
import SwiftUI

enum ToolbarExplorer {
    case makePost, search, users
}

struct Toolbar: View {
    @Binding var currentExplorer: ToolbarExplorer
    @ObservedObject var tunables = TunableConstants.shared
    let onResetMakePost: () -> Void
    let onResetSearch: () -> Void
    let onResetUsers: () -> Void
    var showPostsBadge: Bool = false
    var showSearchBadge: Bool = false
    var showUsersBadge: Bool = false

    var body: some View {
        HStack(spacing: 0) {
            // Make Post button
            ToolbarButton(icon: "bubble.left", isActive: currentExplorer == .makePost, showBadge: showPostsBadge) {
                if currentExplorer == .makePost {
                    onResetMakePost()
                } else {
                    currentExplorer = .makePost
                    // Don't reset - preserve navigation state when switching tabs
                }
            }

            Spacer()

            // Search button
            ToolbarButton(icon: "magnifyingglass", isActive: currentExplorer == .search, showBadge: showSearchBadge) {
                if currentExplorer == .search {
                    onResetSearch()
                } else {
                    currentExplorer = .search
                }
            }

            Spacer()

            // Users button
            ToolbarButton(icon: "person.2", isActive: currentExplorer == .users, showBadge: showUsersBadge) {
                if currentExplorer == .users {
                    onResetUsers()
                } else {
                    currentExplorer = .users
                    // Don't reset - preserve navigation state when switching tabs
                }
            }
        }
        .padding(.horizontal, 66)  // Moves outer buttons inward toward center
        .padding(.vertical, 16)    // 30% taller than original
        .background(
            tunables.buttonColor()  // Uses tunable RGB 255/178/127 * brightness
                .cornerRadius(12 * tunables.getDouble("corner-roundness", default: 1.0))  // Matches posts
                .shadow(color: Color.black.opacity(0.4), radius: 12, x: 0, y: 4)
        )
        .padding(.horizontal, 8 * tunables.getDouble("spacing", default: 1.0))  // Same width as posts
        .offset(y: 34)             // Bottom edge aligned with screen bottom
        .onAppear {
            // Register toolbar buttons with UI automation
            UIAutomationRegistry.shared.register(id: "toolbar-makepost") {
                currentExplorer = .makePost
            }

            UIAutomationRegistry.shared.register(id: "toolbar-search") {
                currentExplorer = .search
            }

            UIAutomationRegistry.shared.register(id: "toolbar-users") {
                currentExplorer = .users
            }
        }
    }
}

struct ToolbarButton: View {
    let icon: String
    let isActive: Bool
    var showBadge: Bool = false
    let action: () -> Void
    @ObservedObject var tunables = TunableConstants.shared

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 20))   // Reduced from 24
                .foregroundColor(.black)
                .frame(width: 35, height: 35)  // Reduced from 44x44
                .background(
                    isActive ? tunables.buttonHighlightColor() : Color.clear  // 80% brightness
                )
                .cornerRadius(6)  // Reduced from 8
                .overlay(alignment: .topTrailing) {
                    if showBadge {
                        Circle()
                            .fill(Color.red)
                            .stroke(Color.white, lineWidth: 2)
                            .frame(width: 10, height: 10)
                            .offset(x: 2, y: -2)
                    }
                }
        }
    }
}
```

### 2. Modify ContentView.swift

Update ContentView to create three explorer instances with data fetching and state management:

**Complete working implementation:**
```swift
import SwiftUI
import OSLog

struct ContentView: View {
    @State private var currentExplorer: ToolbarExplorer = .makePost

    // Three separate post arrays for each explorer
    @State private var makePostPosts: [Post] = []
    @State private var searchPosts: [Post] = []
    @State private var usersPosts: [Post] = []

    // Loading states
    @State private var isLoadingMakePost = true
    @State private var isLoadingSearch = true
    @State private var isLoadingUsers = true

    // Error states
    @State private var makePostError: String?
    @State private var searchError: String?
    @State private var usersError: String?

    // Reset triggers - changing these IDs forces view recreation
    @State private var makePostViewId = UUID()
    @State private var searchViewId = UUID()
    @State private var usersViewId = UUID()

    // Search badge state (any query has new matches)
    @State private var hasSearchBadge = false
    @State private var badgePollingTimer: Timer? = nil

    var body: some View {
        ZStack {
            // Background color
            Color(red: 128/255, green: 128/255, blue: 128/255)
                .ignoresSafeArea()

            // Main content - three separate PostsView instances kept in memory
            // Each maintains its own navigation state independently
            // Use ZStack to layer them and show/hide with opacity
            ZStack {
                // Make Post view
                Group {
                    if isLoadingMakePost {
                        VStack(spacing: 20) {
                            Text("ᕦ(ツ)ᕤ")
                                .font(.system(size: UIScreen.main.bounds.width / 12))
                                .foregroundColor(.black)
                            ProgressView("Loading posts...")
                                .foregroundColor(.black)
                        }
                    } else if let error = makePostError {
                        VStack {
                            Text("Error: \(error)")
                                .foregroundColor(.red)
                                .padding()
                            Button("Retry") {
                                fetchMakePostPosts()
                            }
                            .padding()
                            .background(Color.white.opacity(0.3))
                            .cornerRadius(8)
                        }
                    } else {
                        PostsView(initialPosts: makePostPosts, onPostCreated: { fetchMakePostPosts() }, showAddButton: true, templateName: "post", customAddButtonText: nil)
                            .id(makePostViewId)
                    }
                }
                .opacity(currentExplorer == .makePost ? 1 : 0)
                .allowsHitTesting(currentExplorer == .makePost)
                .zIndex(currentExplorer == .makePost ? 1 : 0)

                // Search view
                Group {
                    if isLoadingSearch {
                        VStack(spacing: 20) {
                            Text("ᕦ(ツ)ᕤ")
                                .font(.system(size: UIScreen.main.bounds.width / 12))
                                .foregroundColor(.black)
                            ProgressView("Loading queries...")
                                .foregroundColor(.black)
                        }
                    } else if let error = searchError {
                        VStack {
                            Text("Error: \(error)")
                                .foregroundColor(.red)
                                .padding()
                            Button("Retry") {
                                fetchSearchPosts()
                            }
                            .padding()
                            .background(Color.white.opacity(0.3))
                            .cornerRadius(8)
                        }
                    } else {
                        PostsView(initialPosts: searchPosts, onPostCreated: { fetchSearchPosts() }, showAddButton: true, templateName: "query", customAddButtonText: nil)
                            .id(searchViewId)
                    }
                }
                .opacity(currentExplorer == .search ? 1 : 0)
                .allowsHitTesting(currentExplorer == .search)
                .zIndex(currentExplorer == .search ? 1 : 0)

                // Users view
                Group {
                    if isLoadingUsers {
                        VStack(spacing: 20) {
                            Text("ᕦ(ツ)ᕤ")
                                .font(.system(size: UIScreen.main.bounds.width / 12))
                                .foregroundColor(.black)
                            ProgressView("Loading users...")
                                .foregroundColor(.black)
                        }
                    } else if let error = usersError {
                        VStack {
                            Text("Error: \(error)")
                                .foregroundColor(.red)
                                .padding()
                            Button("Retry") {
                                fetchUsersPosts()
                            }
                            .padding()
                            .background(Color.white.opacity(0.3))
                            .cornerRadius(8)
                        }
                    } else {
                        PostsView(initialPosts: usersPosts, onPostCreated: { fetchUsersPosts() }, showAddButton: true, templateName: "profile", customAddButtonText: "Invite Friend")
                            .id(usersViewId)
                    }
                }
                .opacity(currentExplorer == .users ? 1 : 0)
                .allowsHitTesting(currentExplorer == .users)
                .zIndex(currentExplorer == .users ? 1 : 0)
            }

            // Floating toolbar at bottom - always on top
            VStack {
                Spacer()
                Toolbar(
                    currentExplorer: $currentExplorer,
                    onResetMakePost: { makePostViewId = UUID() },
                    onResetSearch: { searchViewId = UUID() },
                    onResetUsers: { usersViewId = UUID() },
                    showSearchBadge: hasSearchBadge
                )
                .ignoresSafeArea(.keyboard)  // Keep toolbar visible when keyboard appears
            }
        }
        .onAppear {
            // Fetch all three explorers' data on startup
            fetchMakePostPosts()
            fetchSearchPosts()
            fetchUsersPosts()

            // Start badge polling for toolbar
            pollSearchBadges()
            badgePollingTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
                pollSearchBadges()
            }
        }
        .onDisappear {
            badgePollingTimer?.invalidate()
            badgePollingTimer = nil
        }
    }

    // MARK: - Fetch Functions

    func fetchMakePostPosts() {
        isLoadingMakePost = true
        makePostError = nil

        PostsAPI.shared.fetchRecentTaggedPosts(tags: ["post"], byUser: "any") { result in
            switch result {
            case .success(let fetchedPosts):
                preloadImagesOptimized(for: fetchedPosts) {
                    DispatchQueue.main.async {
                        self.makePostPosts = fetchedPosts
                        self.isLoadingMakePost = false
                    }
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    self.makePostError = error.localizedDescription
                    self.isLoadingMakePost = false
                }
            }
        }
    }

    func fetchSearchPosts() {
        isLoadingSearch = true
        searchError = nil

        PostsAPI.shared.fetchRecentTaggedPosts(tags: ["query"], byUser: "any") { result in
            switch result {
            case .success(let fetchedPosts):
                preloadImagesOptimized(for: fetchedPosts) {
                    DispatchQueue.main.async {
                        self.searchPosts = fetchedPosts
                        self.isLoadingSearch = false
                        self.pollSearchBadges()  // Check badges after loading
                    }
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    self.searchError = error.localizedDescription
                    self.isLoadingSearch = false
                }
            }
        }
    }

    func fetchUsersPosts() {
        isLoadingUsers = true
        usersError = nil

        PostsAPI.shared.fetchRecentTaggedPosts(tags: ["profile"], byUser: "any") { result in
            switch result {
            case .success(let fetchedPosts):
                preloadImagesOptimized(for: fetchedPosts) {
                    DispatchQueue.main.async {
                        self.usersPosts = fetchedPosts
                        self.isLoadingUsers = false
                    }
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    self.usersError = error.localizedDescription
                    self.isLoadingUsers = false
                }
            }
        }
    }

    func preloadImagesOptimized(for posts: [Post], completion: @escaping () -> Void) {
        let serverURL = "http://185.96.221.52:8080"
        let imageUrls = posts.compactMap { post -> String? in
            guard let imageUrl = post.imageUrl else { return nil }
            return serverURL + imageUrl
        }

        guard !imageUrls.isEmpty else {
            completion()
            return
        }

        // Load first image, then display
        let firstUrl = imageUrls[0]
        ImageCache.shared.preload(urls: [firstUrl]) {
            completion()

            // Continue loading remaining images in background
            if imageUrls.count > 1 {
                let remainingUrls = Array(imageUrls[1...])
                ImageCache.shared.preload(urls: remainingUrls) {
                    // Background loading complete
                }
            }
        }
    }

    func pollSearchBadges() {
        // Only poll if we have search posts loaded
        let queryPosts = searchPosts.filter { $0.template == "query" }
        guard !queryPosts.isEmpty else { return }

        let queryIds = queryPosts.map { $0.id }

        // Get current user email
        guard let userEmail = Storage.shared.getLoginState().email else { return }

        let serverURL = "http://185.96.221.52:8080"
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

        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data else { return }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Bool] {
                    DispatchQueue.main.async {
                        // Check if any query has a badge
                        let anyBadge = json.values.contains(true)
                        self.hasSearchBadge = anyBadge
                    }
                }
            } catch {
                Logger.shared.error("[ContentView] Error parsing badge response: \(error.localizedDescription)")
            }
        }.resume()
    }
}
```

## Key Changes Summary

1. **State Management**: Three separate post arrays (makePostPosts, searchPosts, usersPosts) with corresponding loading and error states
2. **Data Fetching**: Three fetch functions that call `PostsAPI.shared.fetchRecentTaggedPosts()` with different tags:
   - Make Post: `tags: ["post"], byUser: "any"` (shows all users' posts)
   - Search: `tags: ["query"], byUser: "any"` (shows all users' queries)
   - Users: `tags: ["profile"], byUser: "any"` (shows all users)
3. **Parallel Loading**: All three explorers fetch data in parallel on app startup (.onAppear)
4. **Loading States**: Each explorer shows "ᕦ(ツ)ᕤ" logo with ProgressView while loading
5. **Error Handling**: Each explorer has error state with retry button
6. **Explorer Switching**: Switch statement shows appropriate PostsView based on currentExplorer
7. **Image Preloading**: First image preloaded before display, remaining images load in background
8. **Toolbar Design**: Sleek rounded lozenge (300pt max width, 20pt corner radius, tunable button color)
9. **Toolbar Shadow**: Strong depth shadow (40% opacity, 12pt blur, 4pt offset) for elevated appearance
10. **Toolbar Position**: 16pt offset from bottom edge, centered with 16pt screen insets
11. **Notification Badges**: Red notification dot (10pt) with 2pt white stroke on each toolbar button:
    - Posts badge: new posts from other users since last viewed
    - Search badge: any saved query has new matches
    - Users badge: new user completed their profile since last viewed
12. **Badge Polling**: Polls `/api/notifications/poll` every 5 seconds and on startup

## Xcode Project Integration

Add new file to Xcode project:

**File to add:**
1. `Toolbar.swift` - Contains `ToolbarExplorer` enum, `Toolbar` view, and `ToolbarButton` view

**Using ios-add-file skill:**
Can use the ios-add-file skill or add manually via project.pbxproj editing

## Visual Appearance

- **Toolbar shape**: Rounded lozenge matching posts (12 * cornerRoundness)
- **Width**: Same as posts (uses same horizontal padding formula: 8 * spacing tunable)
- **Background**: Tunable button color (tunables.buttonColor() - RGB 255/178/127 * brightness)
- **Shadow**: Strong depth shadow (40% black opacity, 12pt blur radius, 4pt y-offset)
- **Position**: Bottom edge aligned with screen bottom (.offset(y: 34))
- **Screen insets**: Same as posts (.padding(.horizontal, 8 * spacing tunable))
- **Internal padding**: 66pt horizontal (buttons moved inward), 16pt vertical (30% taller than original)
- **Icon size**: 20pt (.system(size: 20))
- **Tappable area**: 35x35pt per button (.frame(width: 35, height: 35))
- **Active button highlight**: 80% of button color brightness (tunables.buttonHighlightColor())
- **Layout**: HStack containing 3 buttons with Spacers between them for equal distribution
- **Icons**: SF Symbols - "bubble.left", "magnifyingglass" (one word!), "person.2"

## Behavior

**Button Actions:**
- **Make Post button**: Switches to makePost explorer showing all recent posts from all users
- **Search button**: Switches to search explorer showing all users' saved searches
- **Users button**: Switches to users explorer showing all users

**State Preservation (switching between tabs):**
- Switching tabs does NOT reset the view
- Each tab remembers its navigation state, scroll position, expanded posts
- Example: drill into post 10 on posts tab, switch to queries, switch back → still at post 10

**Reset Behavior (tapping active tab again):**
- Tapping the already-active tab resets that explorer
- Clears navigation history, returns to top-level view
- Also clears that tab's notification badge and updates "last viewed" timestamp

**Explorer State Independence**:
- All three PostsView instances exist simultaneously in a ZStack
- Hidden views use `opacity(0)` and `allowsHitTesting(false)`
  - Not rendered to screen (GPU skips drawing)
  - No touch events processed
  - Still consume memory and perform layout calculations
- Each PostsView instance maintains its own @State variables (navigationPath, scroll, etc.)
- When you switch away and back, the explorer remembers everything:
  - Navigation path (which child posts you were viewing)
  - Scroll position
  - Expanded/collapsed state
  - All loaded data
- SwiftUI preserves state because views remain in hierarchy

**Reset Mechanism:**
- Each PostsView has a unique `.id(viewId)` where viewId is a UUID
- Tapping the active toolbar button calls a reset callback
- Reset callback generates a new UUID: `viewId = UUID()`
- Changing the view ID forces SwiftUI to destroy and recreate that PostsView
- Recreated view starts fresh with no navigation history

## Notes

- Toolbar remains visible at all times, floating above all explorer content
- Toolbar floats above scrolling content in PostsListView
- Keyboard does not push toolbar up (ignoresSafeArea(.keyboard))
- **Critical**: SF Symbol for search is "magnifyingglass" (one word), NOT "magnifying.glass" (with dot)
- **UI Automation**: Toolbar buttons registered with UIAutomationRegistry for programmatic testing
- **Layout structure**: VStack wraps HStack of buttons, with zero-height Spacer below to extend background to screen bottom
- **Bottom edge alignment**: Background uses `.ignoresSafeArea(edges: .bottom)` to extend flush with screen edge
- **Button positioning**: Buttons positioned 15pt from top edge for optimal thumb reach and visual balance
- **Three explorers**: All use PostsView, each is a separate instance with independent state
- **Each explorer shows different content**:
  - Make Post: all users' posts (social feed experience)
  - Search: current user's queries
  - Users: all users

**Add Post button positioning** (in PostsListView.swift):
  - Same width as posts (no extra horizontal padding)
  - No top padding (sits flush with top of scroll area)
  - Creates visual alignment with posts and toolbar
