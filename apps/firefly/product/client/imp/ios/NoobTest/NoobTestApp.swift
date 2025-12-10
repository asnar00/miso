import SwiftUI

@main
struct NoobTestApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @State private var isAuthenticated = false
    @State private var isNewUser = false
    @State private var hasSeenWelcome = false
    @State private var posts: [Post] = []
    @State private var isLoadingPosts = false
    @State private var postsError: String?
    @State private var requiresUpdate = false
    @State private var testflightURL = ""
    @State private var versionCheckComplete = false
    @State private var shouldEditProfile = false

    init() {
        Logger.shared.info("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        Logger.shared.info("[APP] NoobTestApp init() called")

        // Initialize tunable constants
        _ = TunableConstants.shared
        Logger.shared.info("[APP] TunableConstants initialized")

        // Configure larger URLCache for images
        let memoryCapacity = 50 * 1024 * 1024  // 50 MB
        let diskCapacity = 100 * 1024 * 1024   // 100 MB
        let cache = URLCache(memoryCapacity: memoryCapacity, diskCapacity: diskCapacity)
        URLCache.shared = cache

        // Check login state on startup
        let (email, _, _, isLoggedIn) = Storage.shared.getLoginState()
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

        // Start remote log uploads
        RemoteLogUploader.shared.startPeriodicUpload()
    }

    var body: some Scene {
        WindowGroup {
            if requiresUpdate {
                UpdateRequiredView(testflightURL: testflightURL)
            } else if !versionCheckComplete {
                // Show loading while checking version
                ProgressView("Checking for updates...")
                    .onAppear {
                        checkVersion()
                    }
            } else if !isAuthenticated {
                SignInView(isAuthenticated: $isAuthenticated, isNewUser: $isNewUser)
            } else if isNewUser && !hasSeenWelcome {
                // Get name and email from storage for welcome screen
                let (email, _, name, _) = Storage.shared.getLoginState()
                NewUserView(name: name ?? "Friend", email: email ?? "unknown", hasSeenWelcome: $hasSeenWelcome, shouldEditProfile: $shouldEditProfile)
            } else {
                ContentView(shouldEditProfile: $shouldEditProfile)
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active && oldPhase == .background {
                Logger.shared.info("[APP] App returned from background, checking version")
                checkVersion()
            }
        }
    }

    func checkVersion() {
        // Skip version check for test users
        let (email, _, name, _) = Storage.shared.getLoginState()
        if email == "test@example.com" || name == "asnaroo" {
            Logger.shared.info("[VERSION] Skipping version check for test user")
            versionCheckComplete = true
            return
        }

        let serverURL = "http://185.96.221.52:8080"
        guard let url = URL(string: "\(serverURL)/api/version") else {
            versionCheckComplete = true
            return
        }

        // Get app's build number
        let appBuild = Int(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0") ?? 0

        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                if let data = data,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let serverBuild = json["latest_build"] as? Int,
                   let tfURL = json["testflight_url"] as? String {

                    Logger.shared.info("[VERSION] App build: \(appBuild), Server build: \(serverBuild)")

                    if appBuild < serverBuild {
                        Logger.shared.info("[VERSION] Update required!")
                        testflightURL = tfURL
                        requiresUpdate = true
                    }
                }
                versionCheckComplete = true
            }
        }.resume()
    }

    func fetchRecentUsers() {
        isLoadingPosts = true
        postsError = nil

        PostsAPI.shared.fetchRecentTaggedPosts(tags: ["query"], byUser: "current") { result in
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

}
