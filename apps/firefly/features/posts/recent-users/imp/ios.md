# recent-users iOS implementation

## App-Level State Management

The iOS app manages users state at the app level in `NoobTestApp.swift` rather than in individual views. This prevents double-loading when navigating between views.

**File**: `apps/firefly/product/client/imp/ios/NoobTest/NoobTestApp.swift`

```swift
@main
struct NoobTestApp: App {
    @State private var isAuthenticated = false
    @State private var isNewUser = false
    @State private var hasSeenWelcome = false
    @State private var users: [Post] = []  // Changed from posts
    @State private var isLoadingUsers = false  // Changed from isLoadingPosts
    @State private var usersError: String?  // Changed from postsError

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

                    if isLoadingUsers {
                        VStack(spacing: 20) {
                            Text("ᕦ(ツ)ᕤ")
                                .font(.system(size: UIScreen.main.bounds.width / 12))
                                .foregroundColor(.black)

                            ProgressView("Loading users...")  // Changed message
                                .foregroundColor(.black)
                        }
                    } else if let error = usersError {
                        VStack {
                            Text("Error: \(error)")
                                .foregroundColor(.red)
                                .padding()
                            Button("Retry") {
                                fetchRecentUsers()
                            }
                            .padding()
                            .background(Color.white.opacity(0.3))
                            .cornerRadius(8)
                        }
                    } else {
                        PostsView(initialPosts: users, onPostCreated: fetchRecentUsers, showAddButton: false)
                    }
                }
                .onAppear {
                    if users.isEmpty && !isLoadingUsers {
                        fetchRecentUsers()  // Changed from fetchRecentPosts
                    }
                }
            }
        }
    }

    func fetchRecentUsers() {
        isLoadingUsers = true
        usersError = nil

        PostsAPI.shared.fetchRecentUsers { result in
            switch result {
            case .success(let fetchedUsers):
                // Preload first image, then display
                preloadImagesOptimized(for: fetchedUsers) {
                    DispatchQueue.main.async {
                        self.users = fetchedUsers
                        self.isLoadingUsers = false
                    }
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    self.usersError = error.localizedDescription
                    self.isLoadingUsers = false
                }
            }
        }
    }

    func preloadImagesOptimized(for users: [Post], completion: @escaping () -> Void) {
        let serverURL = "http://185.96.221.52:8080"
        let imageUrls = users.compactMap { post -> String? in
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
- Use `@State` in the App struct to maintain users state across the entire app lifecycle
- Loading screen uses turquoise background: `Color(red: 64/255, green: 224/255, blue: 208/255)`
- Logo "ᕦ(ツ)ᕤ" sized at `UIScreen.main.bounds.width / 12` for consistent proportions
- Users (profile posts) are passed to `PostsView` as `initialPosts` parameter
- Pass `showAddButton: false` to hide the "Add Post" button
- Loading message changed to "Loading users..."
- Use `ZStack` to layer loading UI, error UI, or posts view on top of turquoise background

## PostsAPI Integration

The iOS app uses a `PostsAPI` singleton to fetch recent users from the server.

**File**: `apps/firefly/product/client/imp/ios/NoobTest/PostsAPI.swift`

```swift
class PostsAPI {
    static let shared = PostsAPI()
    let serverURL = "http://185.96.221.52:8080"

    func fetchRecentUsers(completion: @escaping (Result<[Post], Error>) -> Void) {
        guard let url = URL(string: "\(serverURL)/api/users/recent") else {
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
                let usersResponse = try JSONDecoder().decode(PostsResponse.self, from: data)
                completion(.success(usersResponse.posts))
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
- Decode `PostsResponse` wrapper object (reuse existing structure), then extract `posts` array
- Endpoint: `/api/users/recent`

## PostsView Integration

`PostsView` needs to support an optional "Add Post" button parameter.

**File**: `apps/firefly/product/client/imp/ios/NoobTest/PostsView.swift`

```swift
struct PostsView: View {
    let initialPosts: [Post]
    let onPostCreated: () -> Void
    let showAddButton: Bool  // New parameter, default true for backward compatibility

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

            // Toolbar - only show Add Post button if showAddButton is true
            if showAddButton {
                VStack {
                    Spacer()
                    // ... existing Add Post button code ...
                }
            }
        }
    }
}

// Add default parameter value for backward compatibility
extension PostsView {
    init(initialPosts: [Post], onPostCreated: @escaping () -> Void) {
        self.initialPosts = initialPosts
        self.onPostCreated = onPostCreated
        self.showAddButton = true
    }
}
```

**Key iOS-specific decisions**:
- Add `showAddButton: Bool` parameter to PostsView
- Conditionally render the toolbar with Add Post button based on this parameter
- Provide a convenience initializer with default `showAddButton = true` for backward compatibility
- When called from NoobTestApp with recent-users, pass `showAddButton: false`

## Target Files

**Files to modify**:
1. `apps/firefly/product/client/imp/ios/NoobTest/NoobTestApp.swift`
   - Change state variables from `posts`/`isLoadingPosts`/`postsError` to `users`/`isLoadingUsers`/`usersError`
   - Change `fetchRecentPosts()` to `fetchRecentUsers()`
   - Change loading message to "Loading users..."
   - Pass `showAddButton: false` to PostsView

2. `apps/firefly/product/client/imp/ios/NoobTest/PostsAPI.swift`
   - Add `fetchRecentUsers()` function that calls `/api/users/recent` endpoint

3. `apps/firefly/product/client/imp/ios/NoobTest/PostsView.swift`
   - Add `showAddButton: Bool` parameter
   - Conditionally render toolbar based on this parameter
   - Add convenience initializer with default value
