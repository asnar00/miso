import SwiftUI

// Navigation destination types
enum PostsDestination: Hashable {
    case children(parentId: Int)  // Show children of a post
    case profile(backLabel: String, profilePost: Post)  // Show single profile post
}

struct PostsView: View {
    let initialPosts: [Post]
    let onPostCreated: () -> Void

    @State private var navigationPath: [PostsDestination] = []

    var body: some View {
        NavigationStack(path: $navigationPath) {
            PostsListView(
                parentPostId: nil,
                backLabel: nil,
                initialPosts: initialPosts,
                onPostCreated: onPostCreated,
                navigationPath: $navigationPath,
                showAddButton: true,
                initialExpandedPostId: nil
            )
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
        }
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(Color(red: 128/255, green: 128/255, blue: 128/255), for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
    }
}

#Preview {
    PostsView(initialPosts: [], onPostCreated: {})
}
