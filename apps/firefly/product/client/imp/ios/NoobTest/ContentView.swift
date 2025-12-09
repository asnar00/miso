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

    // Users badge state (new user completed profile)
    @State private var hasUsersBadge = false

    // Posts badge state (new posts by other users)
    @State private var hasPostsBadge = false

    // Invite count state
    @State private var numInvites: Int = 0

    // Latest post timestamps for incremental fetching
    @State private var latestPostTimestamp: String?
    @State private var latestSearchTimestamp: String?
    @State private var latestUsersTimestamp: String?

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
                    onResetMakePost: {
                        makePostViewId = UUID()
                        // Clear posts badge and update last viewed timestamp
                        hasPostsBadge = false
                        Storage.shared.set("last_viewed_posts", ISO8601DateFormatter().string(from: Date()))
                        // Clear app icon badge if no toolbar badges showing
                        if !hasPostsBadge && !hasSearchBadge && !hasUsersBadge {
                            UIApplication.shared.applicationIconBadgeNumber = 0
                        }
                    },
                    onResetSearch: {
                        searchViewId = UUID()
                        // Clear search badge when viewing search
                        hasSearchBadge = false
                        // Clear app icon badge if no toolbar badges showing
                        if !hasPostsBadge && !hasSearchBadge && !hasUsersBadge {
                            UIApplication.shared.applicationIconBadgeNumber = 0
                        }
                    },
                    onResetUsers: {
                        usersViewId = UUID()
                        // Clear users badge and update last viewed timestamp
                        hasUsersBadge = false
                        Storage.shared.set("last_viewed_users", ISO8601DateFormatter().string(from: Date()))
                        // Clear app icon badge if no toolbar badges showing
                        if !hasPostsBadge && !hasSearchBadge && !hasUsersBadge {
                            UIApplication.shared.applicationIconBadgeNumber = 0
                        }
                    },
                    showPostsBadge: hasPostsBadge,
                    showSearchBadge: hasSearchBadge,
                    showUsersBadge: hasUsersBadge
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

            // Initialize last viewed timestamps if not set
            if Storage.shared.getString("last_viewed_users") == nil {
                Storage.shared.set("last_viewed_users", ISO8601DateFormatter().string(from: Date()))
            }
            if Storage.shared.getString("last_viewed_posts") == nil {
                Storage.shared.set("last_viewed_posts", ISO8601DateFormatter().string(from: Date()))
            }

            // Start unified badge polling for toolbar
            pollAllBadges()
            badgePollingTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
                pollAllBadges()
            }
        }
        .onDisappear {
            badgePollingTimer?.invalidate()
            badgePollingTimer = nil
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            // Set app icon badge based on toolbar badge state
            if hasPostsBadge || hasSearchBadge || hasUsersBadge {
                UIApplication.shared.applicationIconBadgeNumber = 1
            } else {
                UIApplication.shared.applicationIconBadgeNumber = 0
            }
            // Only fetch incrementally if timestamps are set (initial load complete)
            // This prevents duplicate fetches during app startup or keyboard dismiss
            if latestPostTimestamp != nil {
                fetchNewPosts()
            }
            if latestSearchTimestamp != nil {
                fetchNewSearches()
            }
            if latestUsersTimestamp != nil {
                fetchNewUsers()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .pushNotificationReceived)) { _ in
            // When push notification received in foreground, fetch new content incrementally
            Logger.shared.info("[ContentView] Push notification received, fetching new content")
            fetchNewPosts()
            fetchNewSearches()
            fetchNewUsers()
            // Also refresh badges
            pollAllBadges()
            // Scroll to top if no post is expanded
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                NotificationCenter.default.post(name: .scrollToTopIfNotExpanded, object: nil)
            }
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
                        // Track latest timestamp for incremental fetch
                        if let newest = fetchedPosts.first {
                            self.latestPostTimestamp = newest.createdAt
                        }
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
                        self.pollAllBadges()
                        // Track latest timestamp for incremental fetch
                        if let newest = fetchedPosts.first {
                            self.latestSearchTimestamp = newest.createdAt
                        }
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
                        // Track latest timestamp for incremental fetch
                        if let newest = fetchedPosts.first {
                            self.latestUsersTimestamp = newest.createdAt
                        }
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

    // MARK: - Incremental Fetch Functions (for push notification updates)

    func fetchNewPosts() {
        Logger.shared.info("[FETCH] fetchNewPosts() called, latestPostTimestamp=\(latestPostTimestamp ?? "nil")")
        guard let after = latestPostTimestamp else {
            Logger.shared.info("[FETCH] No timestamp, falling back to fetchMakePostPosts()")
            fetchMakePostPosts()
            return
        }

        PostsAPI.shared.fetchRecentTaggedPosts(tags: ["post"], byUser: "any", after: after) { result in
            switch result {
            case .success(let newPosts):
                Logger.shared.info("[FETCH] fetchNewPosts got \(newPosts.count) new posts")
                guard !newPosts.isEmpty else {
                    Logger.shared.info("[FETCH] No new posts, skipping update")
                    return
                }
                // Filter out posts that are already in the list
                let existingIds = Set(self.makePostPosts.map { $0.id })
                let trulyNewPosts = newPosts.filter { !existingIds.contains($0.id) }

                for post in trulyNewPosts {
                    Logger.shared.info("[FETCH] PREPENDING to POSTS list: '\(post.title ?? "untitled")' (id=\(post.id))")
                }

                guard !trulyNewPosts.isEmpty else {
                    Logger.shared.info("[FETCH] All posts already in list, skipping update")
                    return
                }

                preloadImagesOptimized(for: trulyNewPosts) {
                    DispatchQueue.main.async {
                        // Prepend new posts to existing list
                        self.makePostPosts = trulyNewPosts + self.makePostPosts
                        // Update latest timestamp
                        if let newest = trulyNewPosts.first {
                            self.latestPostTimestamp = newest.createdAt
                        }
                        Logger.shared.info("[FETCH] makePostPosts now has \(self.makePostPosts.count) posts")
                    }
                }
            case .failure(let error):
                Logger.shared.error("[FETCH] Failed to fetch new posts: \(error.localizedDescription)")
            }
        }
    }

    func fetchNewSearches() {
        Logger.shared.info("[FETCH] fetchNewSearches() called, latestSearchTimestamp=\(latestSearchTimestamp ?? "nil")")
        guard let after = latestSearchTimestamp else {
            Logger.shared.info("[FETCH] No timestamp, falling back to fetchSearchPosts()")
            fetchSearchPosts()
            return
        }

        PostsAPI.shared.fetchRecentTaggedPosts(tags: ["query"], byUser: "any", after: after) { result in
            switch result {
            case .success(let newPosts):
                Logger.shared.info("[FETCH] fetchNewSearches got \(newPosts.count) new queries")
                guard !newPosts.isEmpty else {
                    Logger.shared.info("[FETCH] No new queries, skipping update")
                    return
                }
                // Filter out queries that are already in the list
                let existingIds = Set(self.searchPosts.map { $0.id })
                let trulyNewPosts = newPosts.filter { !existingIds.contains($0.id) }

                for post in trulyNewPosts {
                    Logger.shared.info("[FETCH] PREPENDING to QUERIES list: '\(post.title ?? "untitled")' (id=\(post.id))")
                }

                guard !trulyNewPosts.isEmpty else {
                    Logger.shared.info("[FETCH] All queries already in list, skipping update")
                    return
                }

                preloadImagesOptimized(for: trulyNewPosts) {
                    DispatchQueue.main.async {
                        self.searchPosts = trulyNewPosts + self.searchPosts
                        if let newest = trulyNewPosts.first {
                            self.latestSearchTimestamp = newest.createdAt
                        }
                        Logger.shared.info("[FETCH] searchPosts now has \(self.searchPosts.count) queries")
                    }
                }
            case .failure(let error):
                Logger.shared.error("[FETCH] Failed to fetch new searches: \(error.localizedDescription)")
            }
        }
    }

    func fetchNewUsers() {
        Logger.shared.info("[FETCH] fetchNewUsers() called, latestUsersTimestamp=\(latestUsersTimestamp ?? "nil")")
        guard let after = latestUsersTimestamp else {
            Logger.shared.info("[FETCH] No timestamp, falling back to fetchUsersPosts()")
            fetchUsersPosts()
            return
        }

        PostsAPI.shared.fetchRecentTaggedPosts(tags: ["profile"], byUser: "any", after: after) { result in
            switch result {
            case .success(let newPosts):
                Logger.shared.info("[FETCH] fetchNewUsers got \(newPosts.count) new users")
                guard !newPosts.isEmpty else {
                    Logger.shared.info("[FETCH] No new users, skipping update")
                    return
                }
                // Filter out users that are already in the list
                let existingIds = Set(self.usersPosts.map { $0.id })
                let trulyNewPosts = newPosts.filter { !existingIds.contains($0.id) }

                for post in trulyNewPosts {
                    Logger.shared.info("[FETCH] PREPENDING to USERS list: '\(post.title ?? "untitled")' (id=\(post.id))")
                }

                guard !trulyNewPosts.isEmpty else {
                    Logger.shared.info("[FETCH] All users already in list, skipping update")
                    return
                }

                preloadImagesOptimized(for: trulyNewPosts) {
                    DispatchQueue.main.async {
                        self.usersPosts = trulyNewPosts + self.usersPosts
                        if let newest = trulyNewPosts.first {
                            self.latestUsersTimestamp = newest.createdAt
                        }
                        Logger.shared.info("[FETCH] usersPosts now has \(self.usersPosts.count) users")
                    }
                }
            case .failure(let error):
                Logger.shared.error("[FETCH] Failed to fetch new users: \(error.localizedDescription)")
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

    func pollAllBadges() {
        // Get current user email
        guard let userEmail = Storage.shared.getLoginState().email else {
            Logger.shared.warning("[Notifications] No user email, skipping poll")
            return
        }

        let serverURL = "http://185.96.221.52:8080"
        guard let url = URL(string: "\(serverURL)/api/notifications/poll") else { return }

        // Gather query IDs from search posts
        let queryIds = searchPosts.filter { $0.template == "query" }.map { $0.id }

        // Get last viewed timestamps
        let lastViewedUsers = Storage.shared.getString("last_viewed_users") ?? ""
        let lastViewedPosts = Storage.shared.getString("last_viewed_posts") ?? ""

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "user_email": userEmail,
            "query_ids": queryIds,
            "last_viewed_users": lastViewedUsers,
            "last_viewed_posts": lastViewedPosts
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else { return }
        request.httpBody = jsonData

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                Logger.shared.error("[Notifications] Poll failed: \(error.localizedDescription)")
                return
            }

            guard let data = data else {
                Logger.shared.warning("[Notifications] No data in response")
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    let hasNewUsers = json["has_new_users"] as? Bool ?? false
                    let hasNewPosts = json["has_new_posts"] as? Bool ?? false
                    let queryBadges = json["query_badges"] as? [String: Bool] ?? [:]
                    let hasSearchBadge = queryBadges.values.contains(true)

                    DispatchQueue.main.async {
                        self.hasSearchBadge = hasSearchBadge
                        self.hasUsersBadge = hasNewUsers
                        self.hasPostsBadge = hasNewPosts
                    }
                }
            } catch {
                Logger.shared.error("[Notifications] Error parsing response: \(error.localizedDescription)")
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
