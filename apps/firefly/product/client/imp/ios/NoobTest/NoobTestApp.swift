import SwiftUI

@main
struct NoobTestApp: App {
    @State private var isAuthenticated = false
    @State private var isNewUser = false
    @State private var hasSeenWelcome = false
    @State private var posts: [Post] = []
    @State private var isLoadingPosts = false
    @State private var postsError: String?

    init() {
        Logger.shared.info("[APP] NoobTestApp init() called")

        // Configure larger URLCache for images
        let memoryCapacity = 50 * 1024 * 1024  // 50 MB
        let diskCapacity = 100 * 1024 * 1024   // 100 MB
        let cache = URLCache(memoryCapacity: memoryCapacity, diskCapacity: diskCapacity)
        URLCache.shared = cache

        // Check login state on startup
        let (email, isLoggedIn) = Storage.shared.getLoginState()
        _isAuthenticated = State(initialValue: isLoggedIn && email != nil)

        if isLoggedIn && email != nil {
            Logger.shared.info("[APP] User already logged in: \(email!)")
            // Existing users have already seen welcome
            _hasSeenWelcome = State(initialValue: true)
        } else {
            Logger.shared.info("[APP] No user logged in, showing sign-in")
        }

        // Start test server
        Logger.shared.info("[APP] About to start TestServer")
        TestServer.shared.start()
        Logger.shared.info("[APP] TestServer.start() returned")
    }

    var body: some Scene {
        WindowGroup {
            if !isAuthenticated {
                SignInView(isAuthenticated: $isAuthenticated, isNewUser: $isNewUser)
            } else if isNewUser && !hasSeenWelcome {
                // Get email from storage for welcome screen
                let (email, _) = Storage.shared.getLoginState()
                NewUserView(email: email ?? "unknown", hasSeenWelcome: $hasSeenWelcome)
            } else {
                ZStack {
                    Color(red: 64/255, green: 224/255, blue: 208/255)
                        .ignoresSafeArea()

                    if isLoadingPosts {
                        ProgressView("Loading posts...")
                            .foregroundColor(.black)
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
                        PostsView(posts: posts, onPostCreated: fetchRecentPosts)
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
