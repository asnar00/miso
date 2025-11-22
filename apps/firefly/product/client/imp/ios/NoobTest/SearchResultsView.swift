import SwiftUI

struct SearchResultsView: View {
    let postIds: [Int]
    let onPostCreated: () -> Void

    @State private var posts: [Post] = []
    @State private var isLoading = true
    @State private var isAnyPostEditing = false

    let serverURL = "http://185.96.221.52:8080"

    var body: some View {
        PostsView(
            initialPosts: posts,
            onPostCreated: onPostCreated,
            showAddButton: false,
            templateName: nil,  // Search results don't need template name
            customAddButtonText: nil,
            isAnyPostEditing: $isAnyPostEditing
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
