# toolbar iOS implementation
*SwiftUI floating toolbar with three explorer buttons*

## Overview

Implements a floating toolbar at the bottom of the screen using SwiftUI's ZStack layering. The toolbar contains three SF Symbol icons (speech bubble, magnifying glass, two people) arranged horizontally with equal spacing. Each button switches to a different explorer view.

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

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // Make Post button
                ToolbarButton(icon: "bubble.left", isActive: currentExplorer == .makePost) {
                    currentExplorer = .makePost
                }

                Spacer()

                // Search button
                ToolbarButton(icon: "magnifyingglass", isActive: currentExplorer == .search) {
                    currentExplorer = .search
                }

                Spacer()

                // Users button
                ToolbarButton(icon: "person.2", isActive: currentExplorer == .users) {
                    currentExplorer = .users
                }
            }
            .padding(.horizontal, 40)
            .padding(.top, 15)  // Move buttons down 15pt
            .frame(height: 50)  // Toolbar height

            // Spacer to extend background to bottom
            Spacer()
                .frame(height: 0)
        }
        .background(
            Color.white.opacity(0.95)
                .ignoresSafeArea(edges: .bottom)
        )
        .shadow(radius: 2)
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
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.black)
                .frame(width: 44, height: 44)
                .background(
                    isActive ? Color.gray.opacity(0.3) : Color.clear
                )
                .cornerRadius(8)
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

    var body: some View {
        ZStack {
            // Background color
            Color(red: 128/255, green: 128/255, blue: 128/255)
                .ignoresSafeArea()

            // Main content - three separate PostsView instances
            // Each maintains its own navigation state
            Group {
                switch currentExplorer {
                case .makePost:
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
                        PostsView(initialPosts: makePostPosts, onPostCreated: { fetchMakePostPosts() }, showAddButton: true, templateName: "post")
                    }

                case .search:
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
                        PostsView(initialPosts: searchPosts, onPostCreated: { fetchSearchPosts() }, showAddButton: true, templateName: "query")
                    }

                case .users:
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
                        PostsView(initialPosts: usersPosts, onPostCreated: { fetchUsersPosts() }, showAddButton: false, templateName: "profile")
                    }
                }
            }

            // Floating toolbar at bottom - always on top
            VStack {
                Spacer()
                Toolbar(currentExplorer: $currentExplorer)
                    .ignoresSafeArea(.keyboard)  // Keep toolbar visible when keyboard appears
            }
        }
        .onAppear {
            // Fetch all three explorers' data on startup
            fetchMakePostPosts()
            fetchSearchPosts()
            fetchUsersPosts()
        }
    }

    // MARK: - Fetch Functions

    func fetchMakePostPosts() {
        isLoadingMakePost = true
        makePostError = nil

        PostsAPI.shared.fetchRecentTaggedPosts(tags: ["post"], byUser: "current") { result in
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

        PostsAPI.shared.fetchRecentTaggedPosts(tags: ["query"], byUser: "current") { result in
            switch result {
            case .success(let fetchedPosts):
                preloadImagesOptimized(for: fetchedPosts) {
                    DispatchQueue.main.async {
                        self.searchPosts = fetchedPosts
                        self.isLoadingSearch = false
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
}
```

## Key Changes Summary

1. **State Management**: Three separate post arrays (makePostPosts, searchPosts, usersPosts) with corresponding loading and error states
2. **Data Fetching**: Three fetch functions that call `PostsAPI.shared.fetchRecentTaggedPosts()` with different tags:
   - Make Post: `tags: ["post"], byUser: "current"`
   - Search: `tags: ["query"], byUser: "current"`
   - Users: `tags: ["profile"], byUser: "any"`
3. **Parallel Loading**: All three explorers fetch data in parallel on app startup (.onAppear)
4. **Loading States**: Each explorer shows "ᕦ(ツ)ᕤ" logo with ProgressView while loading
5. **Error Handling**: Each explorer has error state with retry button
6. **Explorer Switching**: Switch statement shows appropriate PostsView based on currentExplorer
7. **Image Preloading**: First image preloaded before display, remaining images load in background
8. **Toolbar Layer**: Floats at bottom above all content, ignores keyboard

## Xcode Project Integration

Add new file to Xcode project:

**File to add:**
1. `Toolbar.swift` - Contains `ToolbarExplorer` enum, `Toolbar` view, and `ToolbarButton` view

**Using ios-add-file skill:**
Can use the ios-add-file skill or add manually via project.pbxproj editing

## Visual Appearance

- **Button container height**: 50pt (.frame(height: 50))
- **Button vertical position**: 15pt from top (.padding(.top, 15))
- **Icon size**: 24pt (.system(size: 24))
- **Tappable area**: 44x44pt per button (.frame(width: 44, height: 44))
- **Background**: White at 95% opacity (Color.white.opacity(0.95))
- **Background extends to screen bottom**: Uses .ignoresSafeArea(edges: .bottom)
- **Shadow**: 2pt radius (.shadow(radius: 2))
- **Horizontal padding**: 40pt (.padding(.horizontal, 40)) - buttons moved inward from edges
- **Layout**: VStack with HStack containing 4 buttons with Spacers between them for equal distribution
- **Bottom alignment**: VStack with zero-height Spacer extends background to screen bottom
- **Icons**: SF Symbols - "bubble.left", "magnifyingglass" (one word!), "person.2"

## Behavior

**Make Post button**: Switches to makePost explorer showing current user's posts
**Search button**: Switches to search explorer showing current user's queries
**Users button**: Switches to users explorer showing all users

**Explorer State Independence**:
- Each PostsView instance maintains its own @State variables
- When you switch away and back, the explorer remembers:
  - Navigation path (which child posts you were viewing)
  - Scroll position
  - Loaded posts
- SwiftUI preserves state for views that exist but aren't currently visible

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
  - Make Post: current user's posts
  - Search: current user's queries
  - Users: all users
