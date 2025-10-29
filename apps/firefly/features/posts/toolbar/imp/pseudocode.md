# toolbar implementation
*platform-agnostic toolbar specification*

## Overview

A floating toolbar at the bottom of the screen with four action buttons: home, post, search, and profile. The toolbar floats above the content and remains visible at all times.

## Visual Specification

**Toolbar Container:**
- Position: Bottom of screen, floating above content
- Background: White with 95% opacity, extends to bottom edge of screen
- Shadow: Subtle shadow to lift toolbar above content (2pt radius)
- Button area height: 50 points
- Buttons positioned 15pt from top edge of toolbar
- Background extends below buttons to screen bottom (using ignoresSafeArea)

**Button Layout:**
- Four buttons arranged horizontally with equal spacing
- Each button centered in its allocated space
- Horizontal padding: 40 points (buttons moved inward from edges)
- Buttons evenly distributed across remaining width with Spacers

**Button Design:**
- Icon size: 24 points
- Icon color: Black (normal state), highlighted when active
- Tappable area: 44x44 points minimum (accessibility)
- No text labels, icons only

**Button Icons:**
- Home: "house" icon
- Post: "plus" icon
- Search: "magnifyingglass" icon (note: one word, no dot)
- Profile: "person" icon

**Active State Highlighting:**
- One button is always highlighted to show current view
- Default: "home" button is highlighted on launch
- Highlight persists after button press
- Visual treatment: Gray rounded square background behind the active button icon

## State Management

**Active Button State:**
```
enum ToolbarButton:
    home, post, search, profile

state activeButton: ToolbarButton = home  // Default to home
```

## Button Actions

**Home Button:**
```
function onHomeButtonTap():
    activeButton = home
    // Navigate to root level (clear navigation path)
    navigationPath = []
    // This returns user to "most recent posts" view
```

**Post Button:**
```
function onPostButtonTap():
    activeButton = post
    // Open new post editor modal
    // Pass current parentPostId if in child view, null if at root
    currentParentId = navigationPath.isEmpty ? null : navigationPath.last
    showNewPostEditor(parentId: currentParentId)
```

**Search Button:**
```
function onSearchButtonTap():
    activeButton = search
    // TODO: Navigate to semantic search page
    // For now, no-op or show "coming soon" message
```

**Profile Button:**
```
function onProfileButtonTap():
    activeButton = profile
    // TODO: Navigate to user's main profile post
    // For now, no-op or show "coming soon" message
```

## Integration

**In PostsView:**
- Wrap main content in ZStack (or equivalent overlay system)
- Place toolbar as top layer of ZStack
- Toolbar positioned at bottom with safe area padding
- Main content (NavigationStack with PostsListView) fills available space

**Patching Instructions:**

1. **Modify PostsView.swift** (or equivalent):
   - Wrap existing NavigationStack in ZStack
   - Add Toolbar component at bottom of ZStack
   - Pass navigationPath binding to toolbar (for home button)
   - Pass showNewPostEditor state to toolbar (for post button)
   - Wire up button actions

2. **Create Toolbar component** (new file):
   - Takes parameters:
     - navigationPath: Binding to [Int] (for home button)
     - onPostButtonTap: () -> Void (for post button)
     - onSearchButtonTap: () -> Void (for search button - optional/future)
     - onProfileButtonTap: () -> Void (for profile button - optional/future)
   - Returns a view with 4 buttons in horizontal layout
   - Floats at bottom with white background and shadow

## Layout Pseudo-Structure

```
PostsView:
    ZStack:
        // Main content layer
        NavigationStack(path: navigationPath):
            PostsListView(...)

        // Toolbar layer (floating on top)
        VStack:
            Spacer()  // Push toolbar to bottom
            Toolbar(
                navigationPath: $navigationPath,
                onPostButtonTap: { showNewPostEditor = true },
                onSearchButtonTap: { /* TODO */ },
                onProfileButtonTap: { /* TODO */ }
            )
```

## Platform Notes

**iOS (SwiftUI):**
- Use ZStack for layering
- Use VStack with Spacer to push toolbar to bottom
- SF Symbols for icons: "house", "plus", "magnifyingglass", "person"
- Note: "magnifyingglass" is one word (not "magnifying.glass")

**Android (Jetpack Compose):**
- Use Box for layering
- Use Scaffold with bottomBar or manual overlay
- Material Icons: "Home", "Add", "Search", "Person"

## Behavior Details

**Toolbar Persistence:**
- Toolbar visible at all levels of navigation (root and child views)
- Toolbar floats above scrolling content
- Does not scroll away with content

**Post Button Context:**
- At root level: creates top-level post (parentId = null)
- In child view: creates child post with current post as parent

**Home Button:**
- At root level: no-op (already home)
- In child view: pops entire navigation stack to return to root
- Can optimize: only show/enable when navigationPath is not empty

## Future Enhancements

- Search button: implement semantic search navigation
- Profile button: navigate to user's profile post
- Active state highlighting: highlight current section (e.g., home button when at root)
- Badge notifications: show count of new posts/messages
