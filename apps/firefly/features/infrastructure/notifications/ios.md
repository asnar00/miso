# notifications - iOS implementation
*APNs push notifications, live updates, and incremental fetching*

## Prerequisites

1. **Enable Push Notifications capability** in Xcode:
   - Select project → Signing & Capabilities → + Capability → Push Notifications

2. **Enable Background Modes** (optional, for silent pushes):
   - Select project → Signing & Capabilities → + Capability → Background Modes
   - Check "Remote notifications"

---

## AppDelegate.swift

Handles push notification registration, token management, and foreground notification display:

```swift
import UIKit
import UserNotifications

// Notification name for when push notification is received in foreground
extension Notification.Name {
    static let pushNotificationReceived = Notification.Name("pushNotificationReceived")
    static let scrollToTopIfNotExpanded = Notification.Name("scrollToTopIfNotExpanded")
}

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        // Set notification delegate
        UNUserNotificationCenter.current().delegate = self

        // Request notification permissions
        requestNotificationPermissions(application)

        return true
    }

    private func requestNotificationPermissions(_ application: UIApplication) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error = error {
                Logger.shared.error("[PUSH] Permission error: \(error.localizedDescription)")
                return
            }

            if granted {
                Logger.shared.info("[PUSH] Permission granted")
                DispatchQueue.main.async {
                    application.registerForRemoteNotifications()
                }
            } else {
                Logger.shared.info("[PUSH] Permission denied")
            }
        }
    }

    // MARK: - Device Token Registration

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02x", $0) }.joined()
        Logger.shared.info("[PUSH] Device token: \(tokenString)")

        // Send token to server
        registerDeviceToken(tokenString)
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        Logger.shared.error("[PUSH] Failed to register: \(error.localizedDescription)")
    }

    private func registerDeviceToken(_ token: String) {
        let deviceId = Storage.shared.getDeviceID()
        let serverURL = "http://185.96.221.52:8080"
        guard let url = URL(string: "\(serverURL)/api/notifications/register-device") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "device_id": deviceId,
            "apns_token": token
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                Logger.shared.error("[PUSH] Token registration failed: \(error.localizedDescription)")
                return
            }
            Logger.shared.info("[PUSH] Token registered with server")
        }.resume()
    }

    // MARK: - Notification Handling

    // Called when notification received while app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        Logger.shared.info("[PUSH] Received in foreground: \(notification.request.content.title)")

        // Notify ContentView to refresh posts
        NotificationCenter.default.post(name: .pushNotificationReceived, object: nil)

        // Show banner, play sound, and update badge even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }

    // Called when user taps on notification
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        Logger.shared.info("[PUSH] User tapped notification: \(response.notification.request.content.title)")
        completionHandler()
    }
}
```

---

## ContentView.swift - Push Notification Handlers

Add these `.onReceive` handlers to the main view body:

```swift
// State for timestamp tracking
@State private var latestPostTimestamp: String?
@State private var latestSearchTimestamp: String?
@State private var latestUsersTimestamp: String?

var body: some View {
    // ... existing view code ...
    .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
        // Set app icon badge based on toolbar badge state
        if hasPostsBadge || hasSearchBadge || hasUsersBadge {
            UIApplication.shared.applicationIconBadgeNumber = 1
        } else {
            UIApplication.shared.applicationIconBadgeNumber = 0
        }
        // Only fetch incrementally if timestamps are set (initial load complete)
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
```

---

## ContentView.swift - Incremental Fetch Functions

```swift
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
```

---

## Post.swift - API with `after` Parameter

Add `after` parameter to the fetch function:

```swift
func fetchRecentTaggedPosts(tags: [String], byUser: String, after: String? = nil, completion: @escaping (Result<[Post], Error>) -> Void) {
    var queryItems = [
        URLQueryItem(name: "tags", value: tags.joined(separator: ",")),
        URLQueryItem(name: "by_user", value: byUser)
    ]

    // Add after parameter for incremental fetch
    if let after = after {
        queryItems.append(URLQueryItem(name: "after", value: after))
    }

    // ... rest of existing implementation
}
```

---

## PostsListView.swift - Scroll to Top Handler

Add state and handler for scroll-to-top notification:

```swift
@State private var scrollProxy: ScrollViewProxy?

var body: some View {
    ScrollViewReader { proxy in
        ScrollView {
            LazyVStack {
                // ... existing content
            }
            .onAppear {
                // Capture scroll proxy for external scroll control
                scrollProxy = proxy
            }
        }
    }
    .onReceive(NotificationCenter.default.publisher(for: .scrollToTopIfNotExpanded)) { _ in
        // Only scroll to top if no post is currently expanded
        if viewModel.expandedPostId == nil, let firstPost = posts.first {
            Logger.shared.info("[PostsListView] Scrolling to top (no post expanded)")
            withAnimation(.easeInOut(duration: 0.3)) {
                scrollProxy?.scrollTo(firstPost.id, anchor: .top)
            }
        }
    }
}
```

---

## NoobTestApp.swift Integration

```swift
@main
struct NoobTestApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // ... rest of existing code
}
```

---

## Testing

1. Build and deploy to physical device (push notifications don't work in simulator)
2. Accept notification permission when prompted
3. Check logs for "[PUSH] Device token: ..." message
4. Verify token is sent to server via "[PUSH] Token registered with server" log
5. Have another user create a post
6. Verify:
   - Push notification banner appears
   - New post appears at top of posts list
   - If no post is expanded, list scrolls to top
   - App badge shows "1" if toolbar has any badge dots
