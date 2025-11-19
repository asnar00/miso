import SwiftUI
import OSLog

struct ContentView: View {
    @State private var currentExplorer: ToolbarExplorer = .makePost

    // Three separate post arrays for each explorer
    @State private var makePostPosts: [Post] = []
    @State private var searchPosts: [Post] = []
    @State private var usersPosts: [Post] = []

    // Loading states
    @State private var isLoadingMakePost = true
    @State private var isLoadingSearch = true
    @State private var isLoadingUsers = true

    // Error states
    @State private var makePostError: String?
    @State private var searchError: String?
    @State private var usersError: String?

    // Restart state
    @State private var isRestarting = false

    var body: some View {
        ZStack {
            // Background color
            Color(red: 128/255, green: 128/255, blue: 128/255)
                .ignoresSafeArea()

            // Main content - three separate PostsView instances
            // Each maintains its own navigation state
            Group {
                switch currentExplorer {
                case .makePost:
                    if isLoadingMakePost {
                        VStack(spacing: 20) {
                            Text("ᕦ(ツ)ᕤ")
                                .font(.system(size: UIScreen.main.bounds.width / 12))
                                .foregroundColor(.black)
                            ProgressView("Loading posts...")
                                .foregroundColor(.black)
                        }
                    } else if let error = makePostError {
                        VStack(spacing: 15) {
                            Text("Error: \(error)")
                                .foregroundColor(.red)
                                .padding()
                            if isRestarting {
                                ProgressView("Restarting server...")
                                    .foregroundColor(.black)
                            } else {
                                Button("Restart Server") {
                                    restartServer()
                                }
                                .padding()
                                .background(Color.orange.opacity(0.8))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                            }
                        }
                    } else {
                        PostsView(initialPosts: makePostPosts, onPostCreated: { fetchMakePostPosts() }, showAddButton: true, templateName: "post", customAddButtonText: nil)
                    }

                case .search:
                    if isLoadingSearch {
                        VStack(spacing: 20) {
                            Text("ᕦ(ツ)ᕤ")
                                .font(.system(size: UIScreen.main.bounds.width / 12))
                                .foregroundColor(.black)
                            ProgressView("Loading queries...")
                                .foregroundColor(.black)
                        }
                    } else if let error = searchError {
                        VStack(spacing: 15) {
                            Text("Error: \(error)")
                                .foregroundColor(.red)
                                .padding()
                            if isRestarting {
                                ProgressView("Restarting server...")
                                    .foregroundColor(.black)
                            } else {
                                Button("Restart Server") {
                                    restartServer()
                                }
                                .padding()
                                .background(Color.orange.opacity(0.8))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                            }
                        }
                    } else {
                        PostsView(initialPosts: searchPosts, onPostCreated: { fetchSearchPosts() }, showAddButton: true, templateName: "query", customAddButtonText: nil)
                    }

                case .users:
                    if isLoadingUsers {
                        VStack(spacing: 20) {
                            Text("ᕦ(ツ)ᕤ")
                                .font(.system(size: UIScreen.main.bounds.width / 12))
                                .foregroundColor(.black)
                            ProgressView("Loading users...")
                                .foregroundColor(.black)
                        }
                    } else if let error = usersError {
                        VStack(spacing: 15) {
                            Text("Error: \(error)")
                                .foregroundColor(.red)
                                .padding()
                            if isRestarting {
                                ProgressView("Restarting server...")
                                    .foregroundColor(.black)
                            } else {
                                Button("Restart Server") {
                                    restartServer()
                                }
                                .padding()
                                .background(Color.orange.opacity(0.8))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                            }
                        }
                    } else {
                        PostsView(initialPosts: usersPosts, onPostCreated: { fetchUsersPosts() }, showAddButton: true, templateName: "profile", customAddButtonText: "Invite Friend")
                    }
                }
            }

            // Floating toolbar at bottom - always on top
            VStack {
                Spacer()
                Toolbar(currentExplorer: $currentExplorer)
                    .ignoresSafeArea(.keyboard)  // Keep toolbar visible when keyboard appears
            }
        }
        .onAppear {
            // Fetch all three explorers' data on startup
            fetchMakePostPosts()
            fetchSearchPosts()
            fetchUsersPosts()
        }
    }

    // MARK: - Fetch Functions

    func fetchMakePostPosts() {
        isLoadingMakePost = true
        makePostError = nil

        PostsAPI.shared.fetchRecentTaggedPosts(tags: ["post"], byUser: "any") { result in
            switch result {
            case .success(let fetchedPosts):
                preloadImagesOptimized(for: fetchedPosts) {
                    DispatchQueue.main.async {
                        self.makePostPosts = fetchedPosts
                        self.isLoadingMakePost = false
                    }
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    self.makePostError = error.localizedDescription
                    self.isLoadingMakePost = false
                }
            }
        }
    }

    func fetchSearchPosts() {
        isLoadingSearch = true
        searchError = nil

        PostsAPI.shared.fetchRecentTaggedPosts(tags: ["query"], byUser: "current") { result in
            switch result {
            case .success(let fetchedPosts):
                preloadImagesOptimized(for: fetchedPosts) {
                    DispatchQueue.main.async {
                        self.searchPosts = fetchedPosts
                        self.isLoadingSearch = false
                    }
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    self.searchError = error.localizedDescription
                    self.isLoadingSearch = false
                }
            }
        }
    }

    func fetchUsersPosts() {
        isLoadingUsers = true
        usersError = nil

        PostsAPI.shared.fetchRecentTaggedPosts(tags: ["profile"], byUser: "any") { result in
            switch result {
            case .success(let fetchedPosts):
                preloadImagesOptimized(for: fetchedPosts) {
                    DispatchQueue.main.async {
                        self.usersPosts = fetchedPosts
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

    func restartServer() {
        isRestarting = true

        PostsAPI.shared.restartServer { result in
            switch result {
            case .success:
                Logger.shared.info("[ContentView] Server restart initiated, waiting 6 seconds...")
                // Wait 6 seconds for server to restart
                DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
                    self.isRestarting = false
                    // Clear errors and retry all failed requests
                    self.fetchMakePostPosts()
                    self.fetchSearchPosts()
                    self.fetchUsersPosts()
                }
            case .failure(let error):
                Logger.shared.error("[ContentView] Failed to restart server: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.isRestarting = false
                    // Show error on current tab
                    switch self.currentExplorer {
                    case .makePost:
                        self.makePostError = "Failed to restart: \(error.localizedDescription)"
                    case .search:
                        self.searchError = "Failed to restart: \(error.localizedDescription)"
                    case .users:
                        self.usersError = "Failed to restart: \(error.localizedDescription)"
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
