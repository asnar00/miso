import SwiftUI

// Navigation destination types
enum PostsDestination: Hashable {
    case children(parentId: Int)  // Show children of a post
    case profile(backLabel: String, profilePost: Post)  // Show single profile post
    case queryResults(query: String, backLabel: String)  // Show search results for a query
}

struct PostsView: View {
    let initialPosts: [Post]
    let onPostCreated: () -> Void
    let showAddButton: Bool
    let templateName: String?  // Template name for empty state message

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
                templateName: templateName
            )
            .navigationDestination(for: PostsDestination.self) { destination in
                switch destination {
                case .children(let parentId):
                    ChildPostsListViewWrapper(
                        parentId: parentId,
                        onPostCreated: onPostCreated,
                        navigationPath: $navigationPath
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
                        templateName: nil  // Profile view doesn't need template name
                    )
                case .queryResults(let query, let backLabel):
                    QueryResultsViewWrapper(
                        query: query,
                        backLabel: backLabel,
                        onPostCreated: onPostCreated,
                        navigationPath: $navigationPath
                    )
                }
            }
        }
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(Color(red: 128/255, green: 128/255, blue: 128/255), for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
    }
}

// Wrapper to fetch parent post and determine showAddButton state
struct ChildPostsListViewWrapper: View {
    let parentId: Int
    let onPostCreated: () -> Void
    @Binding var navigationPath: [PostsDestination]

    @State private var parentPost: Post? = nil
    @State private var isLoading = true

    let serverURL = "http://185.96.221.52:8080"

    var shouldShowAddPostButton: Bool {
        guard let parent = parentPost else {
            Logger.shared.info("[ChildPostsListViewWrapper] No parent post yet")
            return false
        }

        // Profile posts have template = "profile"
        let isProfilePost = (parent.template == "profile")

        // Check if profile belongs to current user by comparing emails
        let loginState = Storage.shared.getLoginState()
        Logger.shared.info("[ChildPostsListViewWrapper] Login state: email=\(String(describing: loginState.email))")

        guard let currentEmail = loginState.email,
              let authorEmail = parent.authorEmail else {
            Logger.shared.info("[ChildPostsListViewWrapper] Missing email - currentEmail=\(String(describing: loginState.email)), authorEmail=\(String(describing: parent.authorEmail))")
            return false
        }

        let belongsToCurrentUser = (authorEmail == currentEmail)

        Logger.shared.info("[ChildPostsListViewWrapper] isProfilePost=\(isProfilePost), currentEmail=\(currentEmail), authorEmail=\(authorEmail), belongsToCurrentUser=\(belongsToCurrentUser)")

        return isProfilePost && belongsToCurrentUser
    }

    var body: some View {
        Group {
            if isLoading {
                ZStack {
                    Color(red: 128/255, green: 128/255, blue: 128/255)
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
                    templateName: nil  // Child posts don't need template name
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
    let query: String
    let backLabel: String
    let onPostCreated: () -> Void
    @Binding var navigationPath: [PostsDestination]

    @State private var posts: [Post] = []
    @State private var isLoading = true

    let serverURL = "http://185.96.221.52:8080"

    var body: some View {
        Group {
            if isLoading {
                ZStack {
                    Color(red: 128/255, green: 128/255, blue: 128/255)
                        .ignoresSafeArea()
                    ProgressView("Searching...")
                        .foregroundColor(.black)
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
                    templateName: nil
                )
            }
        }
        .onAppear {
            performSearch()
        }
    }

    func performSearch() {
        guard !query.isEmpty else {
            Logger.shared.info("[QueryResultsViewWrapper] Query is empty, skipping search")
            isLoading = false
            return
        }

        Logger.shared.info("[QueryResultsViewWrapper] Searching for: \(query)")

        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "\(serverURL)/api/search?q=\(encodedQuery)&limit=20"

        guard let url = URL(string: urlString) else {
            Logger.shared.error("[QueryResultsViewWrapper] Invalid URL: \(urlString)")
            isLoading = false
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
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
                fetchPosts(ids: results.map { $0.id })
            } catch {
                Logger.shared.error("[QueryResultsViewWrapper] Decoding error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    isLoading = false
                }
            }
        }.resume()
    }

    func fetchPosts(ids: [Int]) {
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
            self.isLoading = false
        }
    }
}

#Preview {
    PostsView(initialPosts: [], onPostCreated: {}, showAddButton: true, templateName: nil)
}
