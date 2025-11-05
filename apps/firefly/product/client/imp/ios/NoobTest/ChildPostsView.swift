import SwiftUI

struct ChildPostsView: View {
    let parentPostId: Int
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
                        fetchChildPosts()
                    }
                    .padding()
                    .background(Color.white.opacity(0.3))
                    .cornerRadius(8)
                }
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 8) {
                            // New post button
                            NewPostButton {
                                showNewPostEditor = true
                            }

                            // Child posts
                            if posts.isEmpty {
                                Text("No posts yet")
                                    .foregroundColor(.black)
                                    .padding()
                            } else {
                                ForEach(posts) { post in
                                    PostView(
                                        post: post,
                                        isExpanded: expandedPostId == post.id,
                                        isEditing: false,  // No editing in child views for now
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
                                            fetchChildPosts()
                                            onPostCreated()
                                        },
                                        onNavigateToChildren: { postId in
                                            navigationPath.append(postId)
                                        },
                                        onPostUpdated: { updatedPost in
                                            if let index = posts.firstIndex(where: { $0.id == updatedPost.id }) {
                                                posts[index] = updatedPost
                                            }
                                        },
                                        onStartEditing: nil,
                                        onEndEditing: nil,
                                        onDelete: nil
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
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    navigationPath.removeLast()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.black)

                        Text(parentPost?.title ?? "...")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.black)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.9))
                    .clipShape(Capsule())
                }
            }
        }
        .sheet(isPresented: $showNewPostEditor) {
            NewPostEditor(onPostCreated: {
                fetchChildPosts()
                onPostCreated()
            }, onDismiss: nil, parentId: parentPostId)
        }
        .onAppear {
            fetchParentPost()
            fetchChildPosts()
        }
    }

    func fetchParentPost() {
        guard let url = URL(string: "\(serverURL)/api/posts/\(parentPostId)") else {
            return
        }

        Logger.shared.info("[ChildPostsView] Fetching parent post \(parentPostId)")

        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data else { return }

            do {
                let postResponse = try JSONDecoder().decode(SinglePostResponse.self, from: data)
                DispatchQueue.main.async {
                    self.parentPost = postResponse.post
                }
            } catch {
                Logger.shared.error("[ChildPostsView] Error fetching parent: \(error.localizedDescription)")
            }
        }.resume()
    }

    func fetchChildPosts() {
        isLoading = true
        errorMessage = nil

        guard let url = URL(string: "\(serverURL)/api/posts/\(parentPostId)/children") else {
            isLoading = false
            errorMessage = "Invalid URL"
            return
        }

        Logger.shared.info("[ChildPostsView] Fetching posts for parent \(parentPostId)")

        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false

                if let error = error {
                    Logger.shared.error("[ChildPostsView] Error: \(error.localizedDescription)")
                    errorMessage = error.localizedDescription
                    return
                }

                guard let data = data else {
                    errorMessage = "No data received"
                    return
                }

                do {
                    let childrenResponse = try JSONDecoder().decode(ChildrenResponse.self, from: data)
                    Logger.shared.info("[ChildPostsView] Loaded \(childrenResponse.children.count) posts")
                    self.posts = childrenResponse.children
                } catch {
                    Logger.shared.error("[ChildPostsView] Decode error: \(error.localizedDescription)")
                    errorMessage = "Failed to load posts"
                }
            }
        }.resume()
    }
}
