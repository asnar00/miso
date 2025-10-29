import SwiftUI

// Unified view for displaying a list of posts, either at root level or for a specific parent
struct PostsListView: View {
    let parentPostId: Int?  // nil = root level, non-nil = child posts
    let onPostCreated: () -> Void
    @Binding var navigationPath: [Int]

    @State private var posts: [Post] = []
    @State private var expandedPostId: Int? = nil
    @State private var showNewPostEditor = false
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var parentPost: Post? = nil

    let serverURL = "http://185.96.221.52:8080"

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
                            if posts.isEmpty {
                                Text("No posts yet")
                                    .foregroundColor(.black)
                                    .padding()
                            } else {
                                ForEach(posts) { post in
                                    PostView(
                                        post: post,
                                        isExpanded: expandedPostId == post.id,
                                        onTap: {
                                            if expandedPostId == post.id {
                                                expandedPostId = nil
                                            } else {
                                                expandedPostId = post.id
                                                withAnimation(.easeInOut(duration: 0.3)) {
                                                    proxy.scrollTo(post.id, anchor: .top)
                                                }
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
                        .padding()
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(parentPost?.title ?? "")
        .sheet(isPresented: $showNewPostEditor) {
            NewPostEditor(onPostCreated: {
                fetchPosts()
                onPostCreated()
            }, onDismiss: nil, parentId: parentPostId)
        }
        .onAppear {
            if let parentId = parentPostId {
                fetchParentPost(parentId)
                fetchPosts()
            } else if posts.isEmpty {
                // Only fetch root posts if we don't have any yet
                fetchPosts()
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
                    }
                } catch {
                    Logger.shared.error("[PostsListView] Decode error: \(error.localizedDescription)")
                    errorMessage = "Failed to load posts"
                }
            }
        }.resume()
    }
}
