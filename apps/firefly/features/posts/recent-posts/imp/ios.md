# recent-posts iOS implementation

## PostsAPI Integration

The iOS app uses a `PostsAPI` singleton to fetch recent posts from the server.

```swift
class PostsAPI {
    static let shared = PostsAPI()
    let serverURL = "http://185.96.221.52:8080"

    func fetchRecentPosts(completion: @escaping (Result<[Post], Error>) -> Void) {
        guard let url = URL(string: "\(serverURL)/api/posts/recent") else {
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
                let posts = try JSONDecoder().decode([Post].self, from: data)
                completion(.success(posts))
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
- Use `JSONDecoder()` to parse JSON into Swift `Post` structs

## PostsView State Management

```swift
struct PostsView: View {
    @State private var posts: [Post] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var expandedPostIds: Set<Int> = []

    var body: some View {
        ZStack {
            Color(red: 64/255, green: 224/255, blue: 208/255)
                .ignoresSafeArea()

            VStack {
                if isLoading {
                    ProgressView("Loading posts...")
                        .foregroundColor(.black)
                } else if let error = errorMessage {
                    Text("Error: \(error)")
                        .foregroundColor(.red)
                        .padding()
                    Button("Retry") {
                        loadPosts()
                    }
                } else if posts.isEmpty {
                    Text("No posts yet")
                        .foregroundColor(.black)
                        .padding()
                } else {
                    // ScrollView with posts...
                }
            }
        }
        .onAppear {
            loadPosts()
        }
    }

    func loadPosts() {
        isLoading = true
        errorMessage = nil

        PostsAPI.shared.fetchRecentPosts { result in
            switch result {
            case .success(let fetchedPosts):
                self.preloadImagesOptimized(for: fetchedPosts) {
                    DispatchQueue.main.async {
                        self.posts = fetchedPosts
                        self.isLoading = false
                        // Expand first post
                        if let firstPost = fetchedPosts.first {
                            self.expandedPostIds.insert(firstPost.id)
                        }
                    }
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}
```

**Key iOS-specific decisions**:
- Use `@State` for view-local mutable state
- Use `ZStack` to layer turquoise background behind content
- Use `ProgressView` for loading spinner
- Use `.onAppear` modifier to trigger initial load
- Use `DispatchQueue.main.async` to update UI state from background completion handlers
- Use `switch` on `Result` enum for clean success/failure handling

## Image Preloading Implementation

```swift
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
```

**Key iOS-specific decisions**:
- Use `compactMap` to filter out posts without images and map to full URLs
- Use `Array(imageUrls[1...])` to create array slice of remaining URLs
- Use nested completion handlers to sequence first-image load, display, then background load
- Rely on `ImageCache.shared` singleton for actual download and caching logic
