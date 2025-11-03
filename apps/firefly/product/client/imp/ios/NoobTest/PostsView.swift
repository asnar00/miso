import SwiftUI

struct PostsView: View {
    let initialPosts: [Post]
    let onPostCreated: () -> Void

    @State private var navigationPath: [Int] = []

    var body: some View {
        NavigationStack(path: $navigationPath) {
            PostsListView(
                parentPostId: nil,
                initialPosts: initialPosts,
                onPostCreated: onPostCreated,
                navigationPath: $navigationPath
            )
            .navigationDestination(for: Int.self) { parentPostId in
                PostsListView(
                    parentPostId: parentPostId,
                    initialPosts: [],
                    onPostCreated: onPostCreated,
                    navigationPath: $navigationPath
                )
            }
        }
    }
}

#Preview {
    PostsView(initialPosts: [], onPostCreated: {})
}
