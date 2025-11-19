# toolbar implementation
*platform-agnostic toolbar specification*

## Overview

A floating toolbar at the bottom of the screen with four action buttons: home, post, search, and profile. The toolbar floats above the content and remains visible at all times.

## Visual Specification

**Toolbar Container:**
- Position: Floating lozenge at bottom of screen, 12pt from bottom edge
- Shape: Rounded rectangle with 25pt corner radius
- Background: Solid light grey (RGB 0.7, 0.7, 0.7)
- Maximum width: 300pt (centered on screen with 16pt horizontal insets)
- Shadow: Strong depth shadow (40% black opacity, 12pt blur radius, 4pt y-offset)
- Internal padding: 33pt horizontal, 14pt vertical

**Button Layout:**
- Three buttons arranged horizontally with equal spacing
- Each button centered in its allocated space
- Buttons evenly distributed across width with Spacers between them

**Button Design:**
- Icon size: 24 points
- Icon color: Black
- Tappable area: 44x44 points minimum (accessibility)
- Active state: Dark grey rounded background (50% grey opacity, 8pt corner radius)
- No text labels, icons only

**Button Icons:**
- Make Post: "bubble.left" icon (speech bubble)
- Search: "magnifyingglass" icon (note: one word, no dot)
- Users: "person.2" icon (two people)

**Active State Highlighting:**
- Not currently implemented (each button shows independent view)
- Future: Could highlight active explorer

## State Management

**Explorer State:**
```
// Each button shows a different explorer view that remembers its state
enum ToolbarExplorer:
    makePost, search, users

state currentExplorer: ToolbarExplorer = makePost  // Default explorer

// Three separate post arrays (fetched on startup, cached in memory)
state makePostPosts: [Post] = []
state searchPosts: [Post] = []
state usersPosts: [Post] = []

// Loading states for each explorer
state isLoadingMakePost: Boolean = true
state isLoadingSearch: Boolean = true
state isLoadingUsers: Boolean = true

// Error states for each explorer
state makePostError: String? = null
state searchError: String? = null
state usersError: String? = null
```

## Data Fetching (On Startup)

All three explorers fetch their data in parallel when the app starts:

**Make Post Explorer:**
```
function fetchMakePostPosts():
    isLoadingMakePost = true
    makePostError = null

    API.fetchRecentTaggedPosts(tags: ["post"], byUser: "any"):
        onSuccess(posts):
            preloadFirstImage(posts)
            makePostPosts = posts
            isLoadingMakePost = false
        onFailure(error):
            makePostError = error.message
            isLoadingMakePost = false
```

**Search Explorer:**
```
function fetchSearchPosts():
    isLoadingSearch = true
    searchError = null

    API.fetchRecentTaggedPosts(tags: ["query"], byUser: "current"):
        onSuccess(posts):
            preloadFirstImage(posts)
            searchPosts = posts
            isLoadingSearch = false
        onFailure(error):
            searchError = error.message
            isLoadingSearch = false
```

**Users Explorer:**
```
function fetchUsersPosts():
    isLoadingUsers = true
    usersError = null

    API.fetchRecentTaggedPosts(tags: ["profile"], byUser: "any"):
        onSuccess(posts):
            preloadFirstImage(posts)
            usersPosts = posts
            isLoadingUsers = false
        onFailure(error):
            usersError = error.message
            isLoadingUsers = false
```

## Button Actions

Each button simply switches the currentExplorer state. No data fetching happens on button tap (data is already loaded):

**Make Post Button:**
```
function onMakePostButtonTap():
    currentExplorer = makePost
    // Immediately shows cached makePostPosts
```

**Search Button:**
```
function onSearchButtonTap():
    currentExplorer = search
    // Immediately shows cached searchPosts
```

**Users Button:**
```
function onUsersButtonTap():
    currentExplorer = users
    // Immediately shows cached usersPosts
```

## Integration

**In PostsView:**
- Wrap main content in ZStack (or equivalent overlay system)
- Place toolbar as top layer of ZStack
- Toolbar positioned at bottom with safe area padding
- Main content (NavigationStack with PostsListView) fills available space

**Patching Instructions:**

1. **Modify ContentView.swift** (or main app view):
   - Add state for current explorer and three post arrays
   - Add loading and error states for each explorer
   - Create three fetch functions (fetchMakePostPosts, fetchSearchPosts, fetchUsersPosts)
   - Call all three fetch functions in .onAppear
   - Switch between three PostsView instances based on currentExplorer
   - Show loading/error states appropriately
   - Add Toolbar component at bottom of ZStack

2. **Create Toolbar.swift** (new file):
   - Define ToolbarExplorer enum (makePost, search, users)
   - Create Toolbar view that takes currentExplorer binding
   - Create ToolbarButton view for individual buttons
   - Returns a view with 3 buttons in horizontal layout
   - Floats at bottom with white background and shadow
   - Each button updates currentExplorer when tapped

3. **No new explorer views needed:**
   - All three explorers use PostsView (separate instances)
   - Each PostsView instance gets its own initialPosts array
   - Each PostsView instance maintains its own @State for navigationPath
   - Explorer-specific parameters: showAddButton, templateName

## Layout Pseudo-Structure

```
ContentView:
    .onAppear:
        fetchMakePostPosts()  // Parallel fetch
        fetchSearchPosts()    // Parallel fetch
        fetchUsersPosts()     // Parallel fetch

    ZStack:
        Background(gray)

        // Main content layer - switch between explorers
        switch currentExplorer:
            case .makePost:
                if isLoadingMakePost:
                    LoadingView("Loading posts...")
                else if makePostError:
                    ErrorView(makePostError, retryAction: fetchMakePostPosts)
                else:
                    PostsView(
                        initialPosts: makePostPosts,
                        onPostCreated: fetchMakePostPosts,
                        showAddButton: true,
                        templateName: "post"
                    )
            case .search:
                if isLoadingSearch:
                    LoadingView("Loading queries...")
                else if searchError:
                    ErrorView(searchError, retryAction: fetchSearchPosts)
                else:
                    PostsView(
                        initialPosts: searchPosts,
                        onPostCreated: fetchSearchPosts,
                        showAddButton: true,
                        templateName: "query"
                    )
            case .users:
                if isLoadingUsers:
                    LoadingView("Loading users...")
                else if usersError:
                    ErrorView(usersError, retryAction: fetchUsersPosts)
                else:
                    PostsView(
                        initialPosts: usersPosts,
                        onPostCreated: fetchUsersPosts,
                        showAddButton: false,
                        templateName: "profile"
                    )

        // Toolbar layer (floating on top)
        VStack:
            Spacer()  // Push toolbar to bottom
            Toolbar(currentExplorer: $currentExplorer)
```

## Platform Notes

**iOS (SwiftUI):**
- Use ZStack for layering
- Use VStack with Spacer to push toolbar to bottom
- SF Symbols for icons: "bubble.left", "magnifyingglass", "person.2"
- Note: "magnifyingglass" is one word (not "magnifying.glass")

**Android (Jetpack Compose):**
- Use Box for layering
- Use Scaffold with bottomBar or manual overlay
- Material Icons: "ChatBubbleOutline" (or "Message"), "Search", "People", "Person"

## Behavior Details

**Toolbar Persistence:**
- Toolbar visible at all times
- Toolbar floats above content in each explorer
- Does not scroll away with content
- Remains accessible from any view

**Explorer State Persistence:**
- Each explorer remembers its own state independently
- Switching between explorers preserves scroll position and navigation state
- User can switch between explorers and return to where they left off

**Initial State:**
- App launches showing Make Post explorer by default
- Other explorers are created lazily when first accessed

## Future Enhancements

- Implement actual explorer views (currently only structure is defined)
- Add active state highlighting to show which explorer is current
- Badge notifications: show count of new posts/messages/queries
- Smooth transitions between explorers
