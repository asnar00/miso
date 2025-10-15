import SwiftUI

@main
struct NoobTestApp: App {
    @State private var isAuthenticated = false
    @State private var isNewUser = false
    @State private var hasSeenWelcome = false

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
                PostsView()
            }
        }
    }
}
