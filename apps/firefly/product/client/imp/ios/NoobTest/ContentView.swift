import SwiftUI
import OSLog

struct ContentView: View {
    @Binding var shouldEditProfile: Bool
    @ObservedObject var tunables = TunableConstants.shared
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

    // Reset triggers - changing these IDs forces view recreation
    @State private var makePostViewId = UUID()
    @State private var searchViewId = UUID()
    @State private var usersViewId = UUID()

    // Track if any post is being edited (to fade out toolbar)
    @State private var isAnyPostEditing = false

    // Invite sheet state
    @State private var showInviteSheet = false

    // New user profile editing state
    @State private var editingNewUserProfile = false

    // Search badge state (any query has new matches)
    @State private var hasSearchBadge = false
    @State private var badgePollingTimer: Timer? = nil

    // Invite count state
    @State private var numInvites: Int = 0

    var body: some View {
        ZStack {
            // Background color
            tunables.backgroundColor()
                .ignoresSafeArea()

            // Main content - three separate PostsView instances kept in memory
            // Each maintains its own navigation state independently
            // Use ZStack to layer them and show/hide with opacity
            ZStack {
                // Make Post view
                Group {
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
                        PostsView(initialPosts: makePostPosts, onPostCreated: { fetchMakePostPosts() }, showAddButton: true, templateName: "post", customAddButtonText: nil, onAddButtonTapped: nil, isAnyPostEditing: $isAnyPostEditing, editCurrentUserProfile: .constant(false))
                            .id(makePostViewId)
                    }
                }
                .opacity(currentExplorer == .makePost ? 1 : 0)
                .allowsHitTesting(currentExplorer == .makePost)
                .zIndex(currentExplorer == .makePost ? 1 : 0)

                // Search view
                Group {
                    if isLoadingSearch {
                        VStack(spacing: 20) {
                            Text("ᕦ(ツ)ᕤ")
                                .font(.system(size: UIScreen.main.bounds.width / 12))
                                .foregroundColor(.black)
                            ProgressView("Loading searches...")
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
                        PostsView(initialPosts: searchPosts, onPostCreated: { fetchSearchPosts() }, showAddButton: true, templateName: "query", customAddButtonText: nil, onAddButtonTapped: nil, isAnyPostEditing: $isAnyPostEditing, editCurrentUserProfile: .constant(false))
                            .id(searchViewId)
                    }
                }
                .opacity(currentExplorer == .search ? 1 : 0)
                .allowsHitTesting(currentExplorer == .search)
                .zIndex(currentExplorer == .search ? 1 : 0)

                // Users view
                Group {
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
                        PostsView(initialPosts: usersPosts, onPostCreated: { fetchUsersPosts() }, showAddButton: numInvites > 0, templateName: "profile", customAddButtonText: "invite friend", onAddButtonTapped: { showInviteSheet = true }, isAnyPostEditing: $isAnyPostEditing, editCurrentUserProfile: $editingNewUserProfile)
                            .id(usersViewId)
                            .sheet(isPresented: $showInviteSheet, onDismiss: { fetchInviteCount() }) {
                                InviteSheet()
                            }
                    }
                }
                .opacity(currentExplorer == .users ? 1 : 0)
                .allowsHitTesting(currentExplorer == .users)
                .zIndex(currentExplorer == .users ? 1 : 0)
            }

            // Floating toolbar at bottom - always on top
            VStack {
                Spacer()
                Toolbar(
                    currentExplorer: $currentExplorer,
                    onResetMakePost: { makePostViewId = UUID() },
                    onResetSearch: { searchViewId = UUID() },
                    onResetUsers: { usersViewId = UUID() },
                    showSearchBadge: hasSearchBadge
                )
                .opacity(isAnyPostEditing ? 0 : 1)  // Fade out when editing
                .allowsHitTesting(!isAnyPostEditing)  // Disable interaction when editing
                .animation(.easeInOut(duration: 0.3), value: isAnyPostEditing)  // Smooth fade
                .ignoresSafeArea(.keyboard)  // Keep toolbar visible when keyboard appears
            }
        }
        .onAppear {
            // Check if new user needs to edit profile
            if shouldEditProfile {
                currentExplorer = .users
                editingNewUserProfile = true
                shouldEditProfile = false
            }

            // Fetch all three explorers' data on startup
            fetchMakePostPosts()
            fetchSearchPosts()
            fetchUsersPosts()
            fetchInviteCount()

            // Start badge polling for toolbar
            pollSearchBadges()
            badgePollingTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
                pollSearchBadges()
            }
        }
        .onDisappear {
            badgePollingTimer?.invalidate()
            badgePollingTimer = nil
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

        PostsAPI.shared.fetchRecentTaggedPosts(tags: ["query"], byUser: "any") { result in
            switch result {
            case .success(let fetchedPosts):
                preloadImagesOptimized(for: fetchedPosts) {
                    DispatchQueue.main.async {
                        self.searchPosts = fetchedPosts
                        self.isLoadingSearch = false
                        // Poll badges now that search posts are loaded
                        self.pollSearchBadges()
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

    func pollSearchBadges() {
        // Only poll if we have search posts loaded
        let queryPosts = searchPosts.filter { $0.template == "query" }
        guard !queryPosts.isEmpty else { return }

        let queryIds = queryPosts.map { $0.id }

        // Get current user email
        guard let userEmail = Storage.shared.getLoginState().email else { return }

        let serverURL = "http://185.96.221.52:8080"
        guard let url = URL(string: "\(serverURL)/api/queries/badges") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "user_email": userEmail,
            "query_ids": queryIds
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else { return }
        request.httpBody = jsonData

        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data else { return }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Bool] {
                    DispatchQueue.main.async {
                        // Check if any query has a badge
                        let anyBadge = json.values.contains(true)
                        self.hasSearchBadge = anyBadge
                    }
                }
            } catch {
                Logger.shared.error("[ContentView] Error parsing badge response: \(error.localizedDescription)")
            }
        }.resume()
    }

    func fetchInviteCount() {
        let deviceId = Storage.shared.getDeviceID()
        let serverURL = "http://185.96.221.52:8080"
        guard let url = URL(string: "\(serverURL)/api/user/invites?device_id=\(deviceId)") else { return }

        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data else { return }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let count = json["num_invites"] as? Int {
                    DispatchQueue.main.async {
                        self.numInvites = count
                        Logger.shared.info("[ContentView] User has \(count) invites remaining")
                    }
                }
            } catch {
                Logger.shared.error("[ContentView] Error parsing invite count: \(error.localizedDescription)")
            }
        }.resume()
    }
}

#Preview {
    @Previewable @State var editProfile = false
    ContentView(shouldEditProfile: $editProfile)
}
