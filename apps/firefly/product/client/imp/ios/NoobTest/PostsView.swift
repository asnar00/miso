import SwiftUI

// Navigation destination types
enum PostsDestination: Hashable {
    case children(parentId: Int)  // Show children of a post
    case profile(backLabel: String, profilePost: Post)  // Show single profile post
}

struct PostsView: View {
    let initialPosts: [Post]
    let onPostCreated: () -> Void
    let showAddButton: Bool

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
                initialExpandedPostId: nil
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
                    initialExpandedPostId: nil
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

#Preview {
    PostsView(initialPosts: [], onPostCreated: {}, showAddButton: true)
}
