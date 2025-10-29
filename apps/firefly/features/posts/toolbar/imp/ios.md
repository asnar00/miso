# toolbar iOS implementation
*SwiftUI floating toolbar with four action buttons*

## Overview

Implements a floating toolbar at the bottom of the screen using SwiftUI's ZStack layering. The toolbar contains four SF Symbol icons (house, plus, magnifying glass, person) arranged horizontally with equal spacing.

## Files to Modify

1. **PostsView.swift** - Wrap content in ZStack and add toolbar
2. **Toolbar.swift** - NEW FILE - Create toolbar component

## Implementation

### 1. Create Toolbar.swift

Create new file at: `apps/firefly/product/client/imp/ios/NoobTest/Toolbar.swift`

```swift
import SwiftUI

enum ToolbarTab {
    case home, post, search, profile
}

struct Toolbar: View {
    @Binding var navigationPath: [Int]
    @Binding var activeTab: ToolbarTab
    let onPostButtonTap: () -> Void
    let onSearchButtonTap: () -> Void
    let onProfileButtonTap: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // Home button
                ToolbarButton(icon: "house", isActive: activeTab == .home) {
                    activeTab = .home
                    navigationPath = []
                }

                Spacer()

                // Post button
                ToolbarButton(icon: "plus", isActive: activeTab == .post) {
                    activeTab = .post
                    onPostButtonTap()
                }

                Spacer()

                // Search button
                ToolbarButton(icon: "magnifyingglass", isActive: activeTab == .search) {
                    activeTab = .search
                    onSearchButtonTap()
                }

                Spacer()

                // Profile button
                ToolbarButton(icon: "person", isActive: activeTab == .profile) {
                    activeTab = .profile
                    onProfileButtonTap()
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
            UIAutomationRegistry.shared.register(id: "toolbar-home") {
                activeTab = .home
                navigationPath = []
            }

            UIAutomationRegistry.shared.register(id: "toolbar-plus") {
                activeTab = .post
                onPostButtonTap()
            }

            UIAutomationRegistry.shared.register(id: "toolbar-search") {
                activeTab = .search
                onSearchButtonTap()
            }

            UIAutomationRegistry.shared.register(id: "toolbar-profile") {
                activeTab = .profile
                onProfileButtonTap()
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

### 2. Modify PostsView.swift

Update PostsView to wrap content in ZStack and add toolbar at bottom:

**Current structure:**
```swift
struct PostsView: View {
    let onPostCreated: () -> Void
    @State private var navigationPath: [Int] = []

    var body: some View {
        NavigationStack(path: $navigationPath) {
            PostsListView(
                parentPostId: nil,
                onPostCreated: onPostCreated,
                navigationPath: $navigationPath
            )
            .navigationDestination(for: Int.self) { parentPostId in
                PostsListView(
                    parentPostId: parentPostId,
                    onPostCreated: onPostCreated,
                    navigationPath: $navigationPath
                )
            }
        }
        .navigationBarHidden(true)
    }
}
```

**New structure with toolbar:**
```swift
struct PostsView: View {
    let onPostCreated: () -> Void
    @State private var navigationPath: [Int] = []
    @State private var showNewPostEditor = false
    @State private var activeTab: ToolbarTab = .home

    var body: some View {
        ZStack {
            // Main content
            NavigationStack(path: $navigationPath) {
                PostsListView(
                    parentPostId: nil,
                    onPostCreated: onPostCreated,
                    navigationPath: $navigationPath
                )
                .navigationDestination(for: Int.self) { parentPostId in
                    PostsListView(
                        parentPostId: parentPostId,
                        onPostCreated: onPostCreated,
                        navigationPath: $navigationPath
                    )
                }
            }
            .navigationBarHidden(true)

            // Custom sheet overlay (instead of .sheet modifier)
            // CRITICAL: Using .sheet() would cover the toolbar. We use a custom overlay instead.
            if showNewPostEditor {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        showNewPostEditor = false
                    }

                VStack {
                    Spacer()
                    let currentParentId = navigationPath.isEmpty ? nil : navigationPath.last
                    NewPostEditor(
                        onPostCreated: {
                            onPostCreated()
                            showNewPostEditor = false
                            activeTab = .home
                        },
                        onDismiss: {
                            withAnimation {
                                showNewPostEditor = false
                                activeTab = .home
                            }
                        },
                        parentId: currentParentId
                    )
                    .frame(maxHeight: .infinity)
                    .transition(.move(edge: .bottom))
                }
            }

            // Floating toolbar at bottom - always on top
            VStack {
                Spacer()
                Toolbar(
                    navigationPath: $navigationPath,
                    activeTab: $activeTab,
                    onPostButtonTap: {
                        withAnimation {
                            showNewPostEditor = true
                        }
                    },
                    onSearchButtonTap: {
                        // TODO: Navigate to search
                    },
                    onProfileButtonTap: {
                        // TODO: Navigate to profile
                    }
                )
                .ignoresSafeArea(.keyboard)  // Keep toolbar visible when keyboard appears
            }
        }
    }
}
```

## Key Changes Summary

1. **New state variable**: `@State private var showNewPostEditor = false` in PostsView
2. **Wrapped in ZStack**: NavigationStack wrapped in ZStack to allow overlay
3. **Added toolbar layer**: VStack with Spacer pushing Toolbar to bottom
4. **Moved sheet modifier**: NewPostEditor sheet moved to PostsView level (was in PostsListView)
5. **Context-aware parentId**: Post button uses `navigationPath.last` for parentId when in child view

## Xcode Project Integration

Add `Toolbar.swift` to Xcode project:

**Using project.pbxproj:**
1. Generate new UUID for file reference
2. Add file reference to PBXFileReference section
3. Add file to PBXSourcesBuildPhase
4. Add file to PBXGroup (NoobTest group)

**Or manually in Xcode:**
1. Right-click NoobTest folder → Add Files to "NoobTest"
2. Select Toolbar.swift
3. Ensure "NoobTest" target is checked

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
- **Icons**: SF Symbols - "house", "plus", "magnifyingglass" (one word!), "person"

## Behavior

**Home button**: Clears navigationPath to return to root
**Post button**: Opens NewPostEditor with appropriate parentId
**Search button**: No-op (TODO)
**Profile button**: No-op (TODO)

**Post button context awareness**:
- Root level: parentId = nil → creates top-level post
- Child view: parentId = navigationPath.last → creates child of current parent

**Active tab state management**:
- After posting or canceling NewPostEditor, activeTab resets to .home
- This ensures correct visual feedback (home button highlighted instead of + button)
- Reset happens in both onPostCreated and onDismiss callbacks

## Notes

- Toolbar remains visible during navigation transitions
- Toolbar floats above scrolling content in PostsListView
- **CRITICAL**: Cannot use `.sheet()` modifier for NewPostEditor - sheets cover the entire view hierarchy including toolbar
- **Solution**: Custom overlay with ZStack layering - NewPostEditor appears as conditional view in ZStack below toolbar layer
- **Background dimming**: Semi-transparent black overlay (0.3 opacity) behind editor, dismissible on tap
- **Animation**: `withAnimation` on showNewPostEditor state change provides slide-up transition
- Keyboard does not push toolbar up (ignoresSafeArea(.keyboard))
- **Critical**: SF Symbol for search is "magnifyingglass" (one word), NOT "magnifying.glass" (with dot)
- **UI Automation**: Toolbar buttons registered with UIAutomationRegistry for programmatic testing
- **Layout structure**: VStack wraps HStack of buttons, with zero-height Spacer below to extend background to screen bottom
- **Bottom edge alignment**: Background uses `.ignoresSafeArea(edges: .bottom)` to extend flush with screen edge
- **Button positioning**: Buttons positioned 15pt from top edge for optimal thumb reach and visual balance

## Xcode Project Files

Added `Toolbar.swift` to project via project.pbxproj editing:
- File location: `NoobTest/Toolbar.swift`
- Contains both `Toolbar` and `ToolbarButton` structs
- Added to PBXBuildFile, PBXFileReference, PBXGroup, and PBXSourcesBuildPhase sections
