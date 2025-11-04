import SwiftUI

// Observable object to manage expansion state (so it can be updated from closures)
class PostsListViewModel: ObservableObject {
    @Published var expandedPostId: Int? = nil

    // Singleton for automation access
    static var current: PostsListViewModel?
}

// Unified view for displaying a list of posts, either at root level or for a specific parent
struct PostsListView: View {
    let parentPostId: Int?  // nil = root level, non-nil = child posts
    let initialPosts: [Post]
    let onPostCreated: () -> Void
    @Binding var navigationPath: [Int]

    @StateObject private var viewModel = PostsListViewModel()
    @State private var posts: [Post] = []
    @State private var showNewPostEditor = false
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var parentPost: Post? = nil
    @State private var scrollProxy: ScrollViewProxy? = nil

    let serverURL = "http://185.96.221.52:8080"

    func expandPost(_ postId: Int) {
        Logger.shared.info("[PostsListView] expandPost(\(postId)) called, viewModel=\(ObjectIdentifier(viewModel))")
        if viewModel.expandedPostId == postId {
            viewModel.expandedPostId = nil
        } else {
            Logger.shared.info("[PostsListView] Setting viewModel.expandedPostId to \(postId)")
            viewModel.expandedPostId = postId
            Logger.shared.info("[PostsListView] After setting, expandedPostId = \(String(describing: viewModel.expandedPostId))")
        }
    }

    var body: some View {
        ZStack {
            Color(red: 128/255, green: 128/255, blue: 128/255)
                .ignoresSafeArea()

            if isLoading {
                ProgressView("Loading...")
                    .foregroundColor(.black)
            } else if let error = errorMessage {
                VStack(spacing: 16) {
                    Text("Error loading posts")
                        .font(.headline)
                        .foregroundColor(.black)
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.black.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding()
                    Button("Retry") {
                        fetchPosts()
                    }
                    .padding()
                    .background(Color.white.opacity(0.3))
                    .cornerRadius(8)
                }
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 8) {
                            // Add post button at the top
                            Button(action: {
                                showNewPostEditor = true
                            }) {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 20))
                                    Text("Add Post")
                                        .font(.system(size: 17, weight: .medium))
                                }
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.white.opacity(0.3))
                                .cornerRadius(12)
                            }
                            .padding(.horizontal, 8)
                            .padding(.top, 8)

                            if posts.isEmpty {
                                Text("No posts yet")
                                    .foregroundColor(.black)
                                    .padding()
                            } else {
                                ForEach(posts) { post in
                                    PostView(
                                        post: post,
                                        isExpanded: viewModel.expandedPostId == post.id,
                                        onTap: {
                                            expandPost(post.id)
                                            withAnimation(.easeInOut(duration: 0.3)) {
                                                proxy.scrollTo(post.id, anchor: .top)
                                            }
                                        },
                                        onPostCreated: {
                                            fetchPosts()
                                            onPostCreated()
                                        },
                                        onNavigateToChildren: { postId in
                                            navigationPath.append(postId)
                                        }
                                    )
                                    .id(post.id)
                                }
                            }
                        }
                        .padding(.horizontal, 8)  // Halved from 16pt to make posts wider
                        .padding(.vertical)
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarHidden(parentPostId == nil)  // Hide nav bar for root, show for children
        .toolbar {
            if parentPostId != nil {
                ToolbarItem(placement: .principal) {
                    Text(parentPost?.title ?? "...")
                        .font(.system(size: 21, weight: .semibold))  // 25% bigger (17 * 1.25 ≈ 21)
                        .foregroundColor(.black)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .offset(x: -88)  // Move left 8pt more (was -80, now -88)
                }
            }
        }
        .sheet(isPresented: $showNewPostEditor) {
            NewPostEditor(onPostCreated: {
                fetchPosts()
                onPostCreated()
            }, onDismiss: nil, parentId: parentPostId)
        }
        .onAppear {
            // Set as current viewModel for automation access
            if parentPostId == nil {  // Only for root view
                PostsListViewModel.current = viewModel
                Logger.shared.info("[PostsListView] Set current viewModel to \(ObjectIdentifier(viewModel))")
            }

            if let parentId = parentPostId {
                fetchParentPost(parentId)
                fetchPosts()
            } else if posts.isEmpty {
                // Root level: use initial posts if available, otherwise fetch
                if !initialPosts.isEmpty {
                    posts = initialPosts
                    isLoading = false
                } else {
                    fetchPosts()
                }
            }
        }
    }

    func fetchParentPost(_ postId: Int) {
        guard let url = URL(string: "\(serverURL)/api/posts/\(postId)") else {
            return
        }

        Logger.shared.info("[PostsListView] Fetching parent post \(postId)")

        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data else { return }

            do {
                let postResponse = try JSONDecoder().decode(SinglePostResponse.self, from: data)
                DispatchQueue.main.async {
                    self.parentPost = postResponse.post
                }
            } catch {
                Logger.shared.error("[PostsListView] Error fetching parent: \(error.localizedDescription)")
            }
        }.resume()
    }

    func fetchPosts() {
        isLoading = true
        errorMessage = nil

        let urlString: String
        if let parentId = parentPostId {
            urlString = "\(serverURL)/api/posts/\(parentId)/children"
        } else {
            urlString = "\(serverURL)/api/posts/recent?limit=50"
        }

        guard let url = URL(string: urlString) else {
            isLoading = false
            errorMessage = "Invalid URL"
            return
        }

        Logger.shared.info("[PostsListView] Fetching posts (parent: \(parentPostId?.description ?? "root"))")

        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false

                if let error = error {
                    Logger.shared.error("[PostsListView] Error: \(error.localizedDescription)")
                    errorMessage = error.localizedDescription
                    return
                }

                guard let data = data else {
                    errorMessage = "No data received"
                    return
                }

                do {
                    if parentPostId != nil {
                        // Child posts - different response format
                        let childrenResponse = try JSONDecoder().decode(ChildrenResponse.self, from: data)
                        Logger.shared.info("[PostsListView] Loaded \(childrenResponse.children.count) posts")
                        self.posts = childrenResponse.children
                    } else {
                        // Root posts
                        let postsResponse = try JSONDecoder().decode(PostsResponse.self, from: data)
                        Logger.shared.info("[PostsListView] Loaded \(postsResponse.posts.count) posts")
                        self.posts = postsResponse.posts

                        // Register UI automation for first post
                        if let firstPost = self.posts.first {
                            let postId = firstPost.id
                            UIAutomationRegistry.shared.register(id: "first-post") {
                                Logger.shared.info("[PostsListView] first-post automation triggered")
                                DispatchQueue.main.async {
                                    guard let vm = PostsListViewModel.current else {
                                        Logger.shared.error("[PostsListView] No current viewModel!")
                                        return
                                    }
                                    Logger.shared.info("[PostsListView] Using current viewModel=\(ObjectIdentifier(vm))")
                                    Logger.shared.info("[PostsListView] Setting expandedPostId to \(postId)")
                                    vm.expandedPostId = postId
                                    Logger.shared.info("[PostsListView] expandedPostId now = \(String(describing: vm.expandedPostId))")
                                }
                            }
                            Logger.shared.info("[PostsListView] Registered first-post automation for post \(firstPost.id)")
                        }
                    }
                } catch {
                    Logger.shared.error("[PostsListView] Decode error: \(error.localizedDescription)")
                    errorMessage = "Failed to load posts"
                }
            }
        }.resume()
    }
}
