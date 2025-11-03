# recent-posts iOS implementation

## App-Level State Management

The iOS app manages posts state at the app level in `NoobTestApp.swift` rather than in individual views. This prevents double-loading when navigating between views.

**File**: `apps/firefly/product/client/imp/ios/NoobTest/NoobTestApp.swift`

```swift
@main
struct NoobTestApp: App {
    @State private var isAuthenticated = false
    @State private var isNewUser = false
    @State private var hasSeenWelcome = false
    @State private var posts: [Post] = []
    @State private var isLoadingPosts = false
    @State private var postsError: String?

    var body: some Scene {
        WindowGroup {
            if !isAuthenticated {
                SignInView(isAuthenticated: $isAuthenticated, isNewUser: $isNewUser)
            } else if isNewUser && !hasSeenWelcome {
                let (email, _) = Storage.shared.getLoginState()
                NewUserView(email: email ?? "unknown", hasSeenWelcome: $hasSeenWelcome)
            } else {
                ZStack {
                    Color(red: 64/255, green: 224/255, blue: 208/255)  // Turquoise
                        .ignoresSafeArea()

                    if isLoadingPosts {
                        VStack(spacing: 20) {
                            Text("ᕦ(ツ)ᕤ")
                                .font(.system(size: UIScreen.main.bounds.width / 12))
                                .foregroundColor(.black)

                            ProgressView("Loading posts...")
                                .foregroundColor(.black)
                        }
                    } else if let error = postsError {
                        VStack {
                            Text("Error: \(error)")
                                .foregroundColor(.red)
                                .padding()
                            Button("Retry") {
                                fetchRecentPosts()
                            }
                            .padding()
                            .background(Color.white.opacity(0.3))
                            .cornerRadius(8)
                        }
                    } else {
                        PostsView(initialPosts: posts, onPostCreated: fetchRecentPosts)
                    }
                }
                .onAppear {
                    if posts.isEmpty && !isLoadingPosts {
                        fetchRecentPosts()
                    }
                }
            }
        }
    }

    func fetchRecentPosts() {
        isLoadingPosts = true
        postsError = nil

        PostsAPI.shared.fetchRecentPosts { result in
            switch result {
            case .success(let fetchedPosts):
                // Preload first image, then display
                preloadImagesOptimized(for: fetchedPosts) {
                    DispatchQueue.main.async {
                        self.posts = fetchedPosts
                        self.isLoadingPosts = false
                    }
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    self.postsError = error.localizedDescription
                    self.isLoadingPosts = false
                }
            }
        }
    }

    func preloadImagesOptimized(for posts: [Post], completion: @escaping () -> Void) {
        let serverURL = "http://185.96.221.52:8080"
        let imageUrls = posts.compactMap { post -> String? in
            guard let imageUrl = post.imageUrl else { return nil }
            return serverURL + imageUrl
        }

        guard !imageUrls.isEmpty else {
            completion()
            return
        }

        // Load first image, then display
        let firstUrl = imageUrls[0]
        ImageCache.shared.preload(urls: [firstUrl]) {
            completion()

            // Continue loading remaining images in background
            if imageUrls.count > 1 {
                let remainingUrls = Array(imageUrls[1...])
                ImageCache.shared.preload(urls: remainingUrls) {
                    // Background loading complete
                }
            }
        }
    }
}
```

**Key iOS-specific decisions**:
- Use `@State` in the App struct to maintain posts state across the entire app lifecycle
- Loading screen uses turquoise background: `Color(red: 64/255, green: 224/255, blue: 208/255)`
- Logo "ᕦ(ツ)ᕤ" sized at `UIScreen.main.bounds.width / 12` for consistent proportions
- Posts are passed to `PostsView` as `initialPosts` parameter to avoid re-fetching
- Use `ZStack` to layer loading UI, error UI, or posts view on top of turquoise background

## PostsAPI Integration

The iOS app uses a `PostsAPI` singleton to fetch recent posts from the server.

```swift
class PostsAPI {
    static let shared = PostsAPI()
    let serverURL = "http://185.96.221.52:8080"

    func fetchRecentPosts(completion: @escaping (Result<[Post], Error>) -> Void) {
        guard let url = URL(string: "\(serverURL)/api/posts/recent?limit=50") else {
            completion(.failure(NSError(domain: "Invalid URL", code: -1)))
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(NSError(domain: "No data", code: -1)))
                return
            }

            do {
                let postsResponse = try JSONDecoder().decode(PostsResponse.self, from: data)
                completion(.success(postsResponse.posts))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
}
```

**Key iOS-specific decisions**:
- Use `URLSession.shared.dataTask` for HTTP requests
- Use `Result<[Post], Error>` enum for type-safe success/failure handling
- Use `@escaping` closure for async callback that outlives the function scope
- Decode `PostsResponse` wrapper object, then extract `posts` array

## PostsView Integration

`PostsView` receives posts from `NoobTestApp` as the `initialPosts` parameter:

**File**: `apps/firefly/product/client/imp/ios/NoobTest/PostsView.swift`

```swift
struct PostsView: View {
    let initialPosts: [Post]
    let onPostCreated: () -> Void

    @State private var navigationPath: [Int] = []
    @State private var showNewPostEditor = false
    @State private var activeTab: ToolbarTab = .home

    var body: some View {
        ZStack {
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

            // Toolbar and new post editor...
        }
    }
}
```

**Key iOS-specific decisions**:
- Receive `initialPosts` from parent app instead of fetching internally
- Pass posts to `PostsListView` which handles display
- Use `NavigationStack` with `navigationPath` for hierarchical post navigation
- Root level posts come from `initialPosts`, child posts are fetched on-demand

## PostsListView Display

`PostsListView` displays the posts passed from `PostsView`:

**File**: `apps/firefly/product/client/imp/ios/NoobTest/PostsListView.swift`

```swift
struct PostsListView: View {
    let parentPostId: Int?  // nil = root level, non-nil = child posts
    let initialPosts: [Post]
    let onPostCreated: () -> Void
    @Binding var navigationPath: [Int]

    @State private var posts: [Post] = []
    @State private var isLoading = true

    var body: some View {
        // Display posts in ScrollView...
    }

    .onAppear {
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
```

**Key iOS-specific decisions**:
- For root level (`parentPostId == nil`), use `initialPosts` directly without fetching
- Only fetch posts for child levels (when navigating into a post's children)
- This prevents double-loading of root posts
- Set `isLoading = false` immediately when using `initialPosts`
