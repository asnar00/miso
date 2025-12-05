import SwiftUI

// Navigation destination types
enum PostsDestination: Hashable {
    case children(parentId: Int)  // Show children of a post
    case profile(backLabel: String, profilePost: Post)  // Show single profile post
    case queryResults(queryPostId: Int, backLabel: String)  // Show search results for a query
}

struct PostsView: View {
    let initialPosts: [Post]
    let onPostCreated: () -> Void
    let showAddButton: Bool
    let templateName: String?  // Template name for empty state message
    let customAddButtonText: String?  // Optional custom button text
    let onAddButtonTapped: (() -> Void)?  // Optional custom action for add button
    @Binding var isAnyPostEditing: Bool  // Track if any post is being edited
    @Binding var editCurrentUserProfile: Bool  // Trigger edit mode on current user's profile
    @ObservedObject var tunables = TunableConstants.shared

    @State private var navigationPath: [PostsDestination] = []

    var body: some View {
        NavigationStack(path: $navigationPath) {
            PostsListView(
                parentPostId: nil,
                backLabel: nil,
                initialPosts: initialPosts,
                onPostCreated: onPostCreated,
                navigationPath: $navigationPath,
                showAddButton: showAddButton,
                initialExpandedPostId: nil,
                templateName: templateName,
                customAddButtonText: customAddButtonText,
                onAddButtonTapped: onAddButtonTapped,
                isAnyPostEditing: $isAnyPostEditing,
                editCurrentUserProfile: $editCurrentUserProfile
            )
            .navigationDestination(for: PostsDestination.self) { destination in
                switch destination {
                case .children(let parentId):
                    ChildPostsListViewWrapper(
                        parentId: parentId,
                        onPostCreated: onPostCreated,
                        navigationPath: $navigationPath,
                        isAnyPostEditing: $isAnyPostEditing
                    )
                case .profile(let backLabel, let profilePost):
                    PostsListView(
                        parentPostId: nil,
                        backLabel: backLabel,
                        initialPosts: [profilePost],
                        onPostCreated: onPostCreated,
                        navigationPath: $navigationPath,
                        showAddButton: false,
                        initialExpandedPostId: profilePost.id,
                        templateName: nil,  // Profile view doesn't need template name
                        customAddButtonText: nil,
                        onAddButtonTapped: nil,
                        isAnyPostEditing: $isAnyPostEditing,
                        editCurrentUserProfile: .constant(false)
                    )
                case .queryResults(let queryPostId, let backLabel):
                    QueryResultsViewWrapper(
                        queryPostId: queryPostId,
                        backLabel: backLabel,
                        onPostCreated: onPostCreated,
                        navigationPath: $navigationPath,
                        isAnyPostEditing: $isAnyPostEditing
                    )
                }
            }
        }
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(tunables.backgroundColor(), for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
        .onChange(of: navigationPath) { oldPath, newPath in
            // When navigating back (path gets shorter), reset editing state
            if newPath.count < oldPath.count && isAnyPostEditing {
                isAnyPostEditing = false
            }
        }
    }
}

// Wrapper to fetch parent post and determine showAddButton state
struct ChildPostsListViewWrapper: View {
    let parentId: Int
    let onPostCreated: () -> Void
    @Binding var navigationPath: [PostsDestination]
    @Binding var isAnyPostEditing: Bool
    @ObservedObject var tunables = TunableConstants.shared

    @State private var parentPost: Post? = nil
    @State private var isLoading = true

    let serverURL = "http://185.96.221.52:8080"

    var shouldShowAddPostButton: Bool {
        guard let parent = parentPost else {
            Logger.shared.info("[ChildPostsListViewWrapper] No parent post yet")
            return false
        }

        // Profile posts: only owner can add children
        if parent.template == "profile" {
            let loginState = Storage.shared.getLoginState()
            guard let currentEmail = loginState.email,
                  let authorEmail = parent.authorEmail else {
                return false
            }
            return authorEmail.lowercased() == currentEmail.lowercased()
        }

        // All other posts: anyone can add children
        return true
    }

    var body: some View {
        Group {
            if isLoading {
                ZStack {
                    tunables.backgroundColor()
                        .ignoresSafeArea()
                    ProgressView("Loading...")
                        .foregroundColor(.black)
                }
            } else {
                PostsListView(
                    parentPostId: parentId,
                    backLabel: nil,
                    initialPosts: [],
                    onPostCreated: onPostCreated,
                    navigationPath: $navigationPath,
                    showAddButton: shouldShowAddPostButton,
                    initialExpandedPostId: nil,
                    templateName: nil,  // Child posts don't need template name
                    customAddButtonText: nil,
                    onAddButtonTapped: nil,
                    isAnyPostEditing: $isAnyPostEditing,
                    editCurrentUserProfile: .constant(false)
                )
            }
        }
        .onAppear {
            fetchParentPost()
        }
    }

    func fetchParentPost() {
        guard let url = URL(string: "\(serverURL)/api/posts/\(parentId)") else {
            isLoading = false
            return
        }

        Logger.shared.info("[ChildPostsListViewWrapper] Fetching parent post \(parentId)")

        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data else {
                DispatchQueue.main.async {
                    isLoading = false
                }
                return
            }

            do {
                let postResponse = try JSONDecoder().decode(SinglePostResponse.self, from: data)
                DispatchQueue.main.async {
                    self.parentPost = postResponse.post
                    self.isLoading = false
                    Logger.shared.info("[ChildPostsListViewWrapper] Parent post fetched. parentId=\(postResponse.post.parentId), userId=\(postResponse.post.userId), showAddButton=\(shouldShowAddPostButton)")
                }
            } catch {
                Logger.shared.error("[ChildPostsListViewWrapper] Error fetching parent: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    isLoading = false
                }
            }
        }.resume()
    }
}

// Wrapper view that fetches search results for a query
struct QueryResultsViewWrapper: View {
    let queryPostId: Int
    let backLabel: String
    let onPostCreated: () -> Void
    @Binding var navigationPath: [PostsDestination]
    @Binding var isAnyPostEditing: Bool
    @ObservedObject var tunables = TunableConstants.shared

    @State private var posts: [Post] = []
    @State private var isLoading = true

    let serverURL = "http://185.96.221.52:8080"

    var body: some View {
        Group {
            if isLoading {
                ZStack {
                    tunables.backgroundColor()
                        .ignoresSafeArea()
                    VStack(spacing: 20) {
                        Text("ᕦ(ツ)ᕤ")
                            .font(.system(size: UIScreen.main.bounds.width / 12))
                            .foregroundColor(.black)
                        ProgressView("Searching...")
                            .foregroundColor(.black)
                    }
                }
            } else {
                PostsListView(
                    parentPostId: nil,
                    backLabel: backLabel,
                    initialPosts: posts,
                    onPostCreated: onPostCreated,
                    navigationPath: $navigationPath,
                    showAddButton: false,
                    initialExpandedPostId: nil,
                    templateName: nil,
                    customAddButtonText: nil,
                    onAddButtonTapped: nil,
                    isAnyPostEditing: $isAnyPostEditing,
                    editCurrentUserProfile: .constant(false)
                )
            }
        }
        .onAppear {
            performSearch()
        }
    }

    func performSearch() {
        let startTime = Date()
        Logger.shared.info("[QueryResultsViewWrapper] Searching with query post ID: \(queryPostId)")

        // Get user email for recording view
        let userEmail = Storage.shared.getLoginState().email ?? ""
        let encodedEmail = userEmail.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        let urlString = "\(serverURL)/api/search?query_id=\(queryPostId)&limit=20&user_email=\(encodedEmail)"

        guard let url = URL(string: urlString) else {
            Logger.shared.error("[QueryResultsViewWrapper] Invalid URL: \(urlString)")
            isLoading = false
            return
        }

        Logger.shared.info("[QueryResultsViewWrapper] ⏱️ Search request sent at \(startTime)")
        URLSession.shared.dataTask(with: url) { data, response, error in
            let endTime = Date()
            let duration = endTime.timeIntervalSince(startTime)
            Logger.shared.info("[QueryResultsViewWrapper] ⏱️ Search response received in \(String(format: "%.2f", duration)) seconds")
            if let error = error {
                Logger.shared.error("[QueryResultsViewWrapper] Error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    isLoading = false
                }
                return
            }

            guard let data = data else {
                Logger.shared.error("[QueryResultsViewWrapper] No data received")
                DispatchQueue.main.async {
                    isLoading = false
                }
                return
            }

            do {
                struct SearchResult: Codable {
                    let id: Int
                    let relevance_score: Double
                }
                let results = try JSONDecoder().decode([SearchResult].self, from: data)
                Logger.shared.info("[QueryResultsViewWrapper] Found \(results.count) results")

                // Fetch full post details for each result
                fetchPosts(ids: results.map { $0.id }, scores: results.map { ($0.id, $0.relevance_score) })
            } catch {
                Logger.shared.error("[QueryResultsViewWrapper] Decoding error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    isLoading = false
                }
            }
        }.resume()
    }

    func fetchPosts(ids: [Int], scores: [(Int, Double)]) {
        guard !ids.isEmpty else {
            DispatchQueue.main.async {
                posts = []
                isLoading = false
            }
            return
        }

        var fetchedPosts: [Post] = []
        let group = DispatchGroup()

        for postId in ids {
            group.enter()
            guard let url = URL(string: "\(serverURL)/api/posts/\(postId)") else {
                group.leave()
                continue
            }

            URLSession.shared.dataTask(with: url) { data, response, error in
                defer { group.leave() }

                guard let data = data else {
                    Logger.shared.error("[QueryResultsViewWrapper] No data for post \(postId)")
                    return
                }

                do {
                    let postResponse = try JSONDecoder().decode(SinglePostResponse.self, from: data)
                    fetchedPosts.append(postResponse.post)
                    Logger.shared.info("[QueryResultsViewWrapper] Fetched post \(postId)")
                } catch {
                    Logger.shared.error("[QueryResultsViewWrapper] Failed to decode post \(postId): \(error.localizedDescription)")
                }
            }.resume()
        }

        group.notify(queue: .main) {
            Logger.shared.info("[QueryResultsViewWrapper] Fetched \(fetchedPosts.count) of \(ids.count) posts")
            // Sort by original order
            self.posts = ids.compactMap { id in fetchedPosts.first(where: { $0.id == id }) }

            // Log search results with titles and scores
            Logger.shared.info("=== SEARCH RESULTS ===")
            for (postId, score) in scores {
                if let post = self.posts.first(where: { $0.id == postId }) {
                    Logger.shared.info("[\(String(format: "%.4f", score))] \(post.title)")
                }
            }
            Logger.shared.info("=== END SEARCH RESULTS ===")

            self.isLoading = false
        }
    }
}

#Preview {
    @Previewable @State var isEditing = false
    @Previewable @State var editProfile = false
    PostsView(initialPosts: [], onPostCreated: {}, showAddButton: true, templateName: nil, customAddButtonText: nil, onAddButtonTapped: nil, isAnyPostEditing: $isEditing, editCurrentUserProfile: $editProfile)
}
