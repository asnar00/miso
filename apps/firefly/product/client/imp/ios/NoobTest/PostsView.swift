import SwiftUI

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

            // Custom sheet overlay (instead of .sheet modifier)
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
                .ignoresSafeArea(.keyboard)
            }
        }
    }
}

#Preview {
    PostsView(onPostCreated: {})
}
