import SwiftUI

@main
struct NoobTestApp: App {
    @State private var isAuthenticated = false
    @State private var isNewUser = false
    @State private var hasSeenWelcome = false
    @State private var posts: [Post] = []
    @State private var isLoadingPosts = false
    @State private var postsError: String?
    @State private var searchText = ""
    @State private var searchResultIds: [Int] = []
    @State private var isSearching = false
    @FocusState private var isSearchFieldFocused: Bool

    init() {
        Logger.shared.info("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        Logger.shared.info("[APP] NoobTestApp init() called")

        // Configure larger URLCache for images
        let memoryCapacity = 50 * 1024 * 1024  // 50 MB
        let diskCapacity = 100 * 1024 * 1024   // 100 MB
        let cache = URLCache(memoryCapacity: memoryCapacity, diskCapacity: diskCapacity)
        URLCache.shared = cache

        // Check login state on startup
        let (email, _, isLoggedIn) = Storage.shared.getLoginState()
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
                let (email, _, _) = Storage.shared.getLoginState()
                NewUserView(email: email ?? "unknown", hasSeenWelcome: $hasSeenWelcome)
            } else {
                ZStack {
                    // Main content layer
                    ZStack {
                        Color(red: 64/255, green: 224/255, blue: 208/255)  // Turquoise
                            .ignoresSafeArea()

                        if isLoadingPosts {
                            VStack(spacing: 20) {
                                Text("ᕦ(ツ)ᕤ")
                                    .font(.system(size: UIScreen.main.bounds.width / 12))
                                    .foregroundColor(.black)

                                ProgressView("Loading users...")
                                    .foregroundColor(.black)
                            }
                        } else if let error = postsError {
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
                            // Keep both views alive, control visibility with ZStack
                            ZStack {
                                // Main posts view - always alive to preserve navigation state
                                PostsView(
                                    initialPosts: posts,
                                    onPostCreated: fetchRecentUsers,
                                    showAddButton: false
                                )
                                .opacity(isSearching ? 0 : 1)
                                .allowsHitTesting(!isSearching)

                                // Search results view - overlays when searching
                                if isSearching {
                                    SearchResultsView(postIds: searchResultIds, onPostCreated: fetchRecentUsers)
                                }

                                // Invisible overlay to dismiss keyboard - only when keyboard is focused
                                if isSearchFieldFocused {
                                    Color.clear
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            isSearchFieldFocused = false
                                        }
                                }
                            }
                        }
                    }
                    .onAppear {
                        if posts.isEmpty && !isLoadingPosts {
                            fetchRecentUsers()
                        }
                    }

                    // Floating search bar overlay
                    VStack {
                        Spacer()
                        FloatingSearchBar(
                            searchText: $searchText,
                            isFocused: $isSearchFieldFocused,
                            onSearch: { query in
                                performSearch(query)
                            },
                            onClear: {
                                isSearching = false
                                searchResultIds = []
                            }
                        )
                    }
                }
            }
        }
    }

    func fetchRecentUsers() {
        isLoadingPosts = true
        postsError = nil

        PostsAPI.shared.fetchRecentUsers { result in
            switch result {
            case .success(let fetchedUsers):
                // Preload first image, then display
                preloadImagesOptimized(for: fetchedUsers) {
                    DispatchQueue.main.async {
                        self.posts = fetchedUsers
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

    func performSearch(_ query: String) {
        guard !query.isEmpty else {
            Logger.shared.info("[SEARCH] Query is empty, skipping search")
            return
        }

        Logger.shared.info("[SEARCH] Setting isSearching = true")
        isSearching = true

        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "http://185.96.221.52:8080/api/search?q=\(encodedQuery)&limit=20"

        guard let url = URL(string: urlString) else {
            Logger.shared.error("[SEARCH] Invalid URL: \(urlString)")
            return
        }

        Logger.shared.info("[SEARCH] Searching for: \(query)")

        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                Logger.shared.error("[SEARCH] Error: \(error.localizedDescription)")
                return
            }

            guard let data = data else {
                Logger.shared.error("[SEARCH] No data received")
                return
            }

            do {
                struct SearchResult: Codable {
                    let id: Int
                    let relevance_score: Double
                }
                let results = try JSONDecoder().decode([SearchResult].self, from: data)
                Logger.shared.info("[SEARCH] Found \(results.count) results, dispatching to main thread")
                DispatchQueue.main.async {
                    Logger.shared.info("[SEARCH] On main thread, setting searchResultIds to \(results.count) IDs")
                    Logger.shared.info("[SEARCH] Current isSearching = \(self.isSearching)")
                    self.searchResultIds = results.map { $0.id }
                    Logger.shared.info("[SEARCH] searchResultIds updated: \(self.searchResultIds), UI should refresh now")
                }
            } catch {
                Logger.shared.error("[SEARCH] Decoding error: \(error.localizedDescription)")
            }
        }.resume()
    }
}
