import SwiftUI

// Observable object to manage expansion and editing state (so it can be updated from closures)
class PostsListViewModel: ObservableObject {
    @Published var expandedPostId: Int? = nil
    @Published var editingPostId: Int? = nil

    // Singleton for automation access
    static var current: PostsListViewModel?
}

// Unified view for displaying a list of posts, either at root level or for a specific parent
struct PostsListView: View {
    let parentPostId: Int?  // nil = root level, non-nil = child posts
    let backLabel: String?  // Custom label for back button (if not using parentPost title)
    let initialPosts: [Post]
    let onPostCreated: () -> Void
    @Binding var navigationPath: [PostsDestination]
    let showAddButton: Bool  // Whether to show the "Add Post" button
    let initialExpandedPostId: Int?  // Post ID to expand initially
    let templateName: String?  // Template name for this list (e.g., "query", "post", "profile")
    let customAddButtonText: String?  // Optional custom text for the add button
    let onAddButtonTapped: (() -> Void)?  // Optional custom action for add button
    @Binding var isAnyPostEditing: Bool  // Track if any post is being edited (for toolbar fade)
    @Binding var editCurrentUserProfile: Bool  // Trigger edit mode on current user's profile

    @ObservedObject var tunables = TunableConstants.shared

    // Corner roundness helper
    private var cornerRoundness: CGFloat {
        tunables.getDouble("corner-roundness", default: 1.0)
    }

    // Back button view (extracted to simplify toolbar)
    private var backButton: some View {
        Button(action: {
            navigationPath.removeLast()
        }) {
            HStack(spacing: 8) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .semibold))
                Text(backLabel ?? parentPost?.title ?? "...")
                    .font(.system(size: 17, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundColor(.black)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(tunables.buttonColor())
            .cornerRadius(24 * cornerRoundness)
        }
    }

    // Computed property: determine if we should show add button and what template to use
    private var shouldShowAddButton: Bool {
        // If showAddButton is explicitly false, respect that
        if !showAddButton { return false }

        // If custom text provided, always show button
        if customAddButtonText != nil { return true }

        // For child posts: anyone can add, except for profiles (only owner can add)
        if parentPostId != nil {
            if let parent = parentPost {
                // If parent is a profile, only owner can add children
                if parent.template == "profile" {
                    let loginState = Storage.shared.getLoginState()
                    if let userEmail = loginState.email, let parentEmail = parent.authorEmail {
                        return userEmail.lowercased() == parentEmail.lowercased()
                    }
                    return false
                }
                // For all other posts, anyone can add children
                return true
            }
            return false  // Parent not loaded yet
        }

        // Root level: show unless it's a profile list
        guard let firstPost = posts.first else { return showAddButton }
        return firstPost.template != "profile"
    }

    private var addButtonTemplate: String {
        // Determine template from first post
        if let firstPost = posts.first, let template = firstPost.template {
            return template
        }
        // Default to "query" for root level (since that's what we're showing now)
        // TODO: Make this more robust by passing template type explicitly
        return parentPostId == nil ? "query" : "post"
    }

    private var addButtonText: String {
        // Use custom text if provided
        if let customText = customAddButtonText {
            return customText
        }
        // Child posts use "add sub-post", except for profile children which use "add post"
        if parentPostId != nil {
            if parentPost?.template == "profile" {
                return "add post"
            }
            return "add sub-post"
        }
        // Lowercase template name (map "query" to "search" for display)
        let template = addButtonTemplate
        if template == "query" {
            return "new search"
        }
        return "add " + template.lowercased()
    }

    private var emptyStateMessage: String {
        // Use fetched plural name first, then fall back to first post's template
        // Map "queries" to "searches" for display
        if let pluralName = pluralName {
            let displayName = pluralName == "queries" ? "searches" : pluralName
            return "No \(displayName) yet"
        }
        if let firstPost = initialPosts.first, let pluralName = firstPost.pluralName {
            let displayName = pluralName == "queries" ? "searches" : pluralName
            return "No \(displayName) yet"
        }
        return "No posts yet"
    }

    @StateObject private var viewModel = PostsListViewModel()
    @State private var posts: [Post] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var parentPost: Post? = nil
    @State private var scrollProxy: ScrollViewProxy? = nil
    @State private var editingPostId: Int? = nil  // Track which post is being edited
    @State private var pluralName: String? = nil  // Fetched plural name for template
    @State private var badgeStates: [Int: Bool] = [:]  // Track badge state per post ID
    @State private var pollingTimer: Timer? = nil  // Timer for badge polling
    @State private var shouldBounceEditButtons: Bool = false  // Trigger bounce animation on edit buttons

    let serverURL = "http://185.96.221.52:8080"

    func expandPost(_ postId: Int) {
        Logger.shared.info("[PostsListView] expandPost(\(postId)) called, viewModel=\(ObjectIdentifier(viewModel))")
        if viewModel.expandedPostId == postId {
            viewModel.expandedPostId = nil
        } else {
            Logger.shared.info("[PostsListView] Setting viewModel.expandedPostId to \(postId)")
            viewModel.expandedPostId = postId
            Logger.shared.info("[PostsListView] After setting, expandedPostId = \(String(describing: viewModel.expandedPostId))")
        }
    }

    var body: some View {
        ZStack {
            tunables.backgroundColor()
                .ignoresSafeArea()

            if isLoading {
                ProgressView("Loading...")
                    .foregroundColor(.black)
            } else if let error = errorMessage {
                VStack(spacing: 16) {
                    Text("Error loading posts")
                        .font(.headline)
                        .foregroundColor(.black)
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.black.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding()
                    Button("Retry") {
                        fetchPosts()
                    }
                    .padding()
                    .background(Color.white.opacity(0.3))
                    .cornerRadius(8 * cornerRoundness)
                }
            } else {
                GeometryReader { geometry in
                    let horizontalPadding: CGFloat = 8 * tunables.getDouble("spacing", default: 1.0)
                    let postWidth = geometry.size.width - (2 * horizontalPadding)

                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(spacing: 8 * tunables.getDouble("spacing", default: 1.0)) {
                            // Add post button at the top (smart detection based on template)
                            if shouldShowAddButton {
                                Button(action: {
                                    // Block add post while editing
                                    guard editingPostId == nil else {
                                        Logger.shared.info("[PostsListView] Ignoring add post tap - currently editing post \(editingPostId!)")
                                        shouldBounceEditButtons = true
                                        return
                                    }
                                    createNewPost()
                                }) {
                                    HStack {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.system(size: 20))
                                        Text(addButtonText)
                                            .font(.system(size: 17, weight: .medium))
                                    }
                                    .foregroundColor(.black)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(tunables.buttonColor().opacity(editingPostId == nil ? 1.0 : 0.4))
                                    .cornerRadius(12 * cornerRoundness)
                                }
                                .padding(.horizontal, 8)
                                .padding(.top, 4)
                            }

                            if posts.isEmpty {
                                Text(emptyStateMessage)
                                    .foregroundColor(.black)
                                    .padding()
                            } else {
                                ForEach(posts) { post in
                                    PostView(
                                        post: post,
                                        isExpanded: viewModel.expandedPostId == post.id,
                                        availableWidth: postWidth,
                                        isEditing: editingPostId == post.id,
                                        showNotificationBadge: badgeStates[post.id] ?? false,
                                        onTap: {
                                            // Ignore taps on other posts while editing
                                            guard editingPostId == nil else {
                                                Logger.shared.info("[PostsListView] Ignoring tap on post \(post.id) - currently editing post \(editingPostId!)")
                                                // Trigger bounce animation on edit buttons to signal user
                                                shouldBounceEditButtons = true
                                                return
                                            }
                                            expandPost(post.id)
                                            withAnimation(.easeInOut(duration: 0.3)) {
                                                proxy.scrollTo(post.id, anchor: .top)
                                            }
                                        },
                                        onPostCreated: {
                                            fetchPosts()
                                            onPostCreated()
                                        },
                                        onNavigateToChildren: { postId in
                                            navigationPath.append(.children(parentId: postId))
                                        },
                                        onNavigateToProfile: { backLabel, profilePost in
                                            navigationPath.append(.profile(backLabel: backLabel, profilePost: profilePost))
                                        },
                                        onNavigateToQueryResults: { queryPostId, backLabel in
                                            navigationPath.append(.queryResults(queryPostId: queryPostId, backLabel: backLabel))
                                        },
                                        onPostUpdated: { updatedPost in
                                            // Check if this is a new post being updated with real ID
                                            if post.id < 0 && updatedPost.id > 0 {
                                                // Replace temporary post with real one
                                                if let index = posts.firstIndex(where: { $0.id == post.id }) {
                                                    posts[index] = updatedPost
                                                    // Update editing state to track new ID
                                                    editingPostId = nil
                                                    isAnyPostEditing = false
                                                    // Update expansion state to new ID
                                                    viewModel.expandedPostId = updatedPost.id
                                                }
                                            } else if let index = posts.firstIndex(where: { $0.id == updatedPost.id }) {
                                                // Regular update - same ID
                                                posts[index] = updatedPost
                                            }
                                        },
                                        onStartEditing: {
                                            editingPostId = post.id
                                            isAnyPostEditing = true
                                        },
                                        onEndEditing: {
                                            Logger.shared.info("[PostsListView] ⚡️ onEndEditing called for post \(post.id)")
                                            Logger.shared.info("[PostsListView] ⚡️ BEFORE: editingPostId=\(String(describing: editingPostId)), isAnyPostEditing=\(isAnyPostEditing)")
                                            editingPostId = nil
                                            isAnyPostEditing = false
                                            Logger.shared.info("[PostsListView] ⚡️ AFTER: editingPostId=\(String(describing: editingPostId)), isAnyPostEditing=\(isAnyPostEditing)")
                                            // Dismiss keyboard
                                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                            Logger.shared.info("[PostsListView] ⚡️ Keyboard dismissed")
                                        },
                                        onDelete: {
                                            // Delete post - remove from local array
                                            posts.removeAll { $0.id == post.id }
                                            editingPostId = nil
                                            isAnyPostEditing = false
                                            // Dismiss keyboard
                                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                            // If it was a saved post, refresh to update parent's child count
                                            if post.id > 0 {
                                                fetchPosts()
                                                onPostCreated()  // Notify parent to refresh
                                            }
                                        },
                                        isNewPost: post.id < 0,  // Pass flag to distinguish new vs existing posts
                                        shouldBounceButtons: $shouldBounceEditButtons
                                    )
                                    .id(post.id)
                                    .zIndex(viewModel.expandedPostId == post.id ? 1 : 0)
                                }
                            }
                        }
                        .padding(.horizontal, 8 * tunables.getDouble("spacing", default: 1.0))  // Side margins
                        .padding(.bottom)
                        .onAppear {
                            // Capture scroll proxy for external scroll control
                            scrollProxy = proxy
                        }
                    }
                }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarHidden(parentPostId == nil && backLabel == nil)  // Hide nav bar for root, show for children or profile
        .navigationBarBackButtonHidden(true)  // Hide standard back button
        .toolbar {
            if parentPostId != nil || backLabel != nil {
                ToolbarItem(placement: .navigationBarLeading) {
                    backButton
                }
            }
        }
        .simultaneousGesture(
            (parentPostId != nil || backLabel != nil) ?
                DragGesture(minimumDistance: 30)
                    .onChanged { value in
                        Logger.shared.info("[PostsListView] Drag changed: translation.width = \(value.translation.width), translation.height = \(value.translation.height)")
                    }
                    .onEnded { value in
                        Logger.shared.info("[PostsListView] Drag ended: translation.width = \(value.translation.width), translation.height = \(value.translation.height)")
                        // Swipe right to go back (positive x translation, at least 50pt, and more horizontal than vertical)
                        if value.translation.width > 50 && abs(value.translation.width) > abs(value.translation.height) {
                            Logger.shared.info("[PostsListView] Swipe right detected! Going back...")
                            navigationPath.removeLast()
                        } else {
                            Logger.shared.info("[PostsListView] Not a swipe right (width=\(value.translation.width), height=\(value.translation.height))")
                        }
                    }
                : nil
        )
        .onAppear {
            Logger.shared.info("[PostsListView] onAppear called - parentPostId=\(String(describing: parentPostId)), backLabel=\(String(describing: backLabel)), templateName=\(String(describing: templateName))")
            // Set as current viewModel for automation access (only for makePost tab - templateName="post")
            if parentPostId == nil && backLabel == nil && templateName == "post" {
                PostsListViewModel.current = viewModel
                Logger.shared.info("[PostsListView] Set as current viewModel for makePost tab")
            }

            // Set initial expanded post if specified
            if let expandPostId = initialExpandedPostId {
                viewModel.expandedPostId = expandPostId
            }

            // Fetch plural name for template if provided
            if let template = templateName {
                fetchPluralName(for: template)
            }

            if let parentId = parentPostId {
                fetchParentPost(parentId)
                fetchPosts()
            } else if posts.isEmpty {
                // Root level: use initial posts (provided by parent view)
                if !initialPosts.isEmpty {
                    posts = initialPosts
                    isLoading = false

                    // Register UI automation for first post (only for makePost tab - templateName="post")
                    if templateName == "post", let firstPost = initialPosts.first {
                        let postId = firstPost.id
                        UIAutomationRegistry.shared.register(id: "first-post") {
                            Logger.shared.info("[PostsListView] first-post automation triggered")
                            DispatchQueue.main.async {
                                guard let vm = PostsListViewModel.current else {
                                    Logger.shared.error("[PostsListView] No current viewModel!")
                                    return
                                }
                                Logger.shared.info("[PostsListView] Setting expandedPostId to \(postId)")
                                vm.expandedPostId = postId
                            }
                        }
                        Logger.shared.info("[PostsListView] Registered first-post automation for post \(firstPost.id)")
                    }

                    // Check if we need to edit profile on initial load (not just onChange)
                    if editCurrentUserProfile {
                        triggerEditCurrentUserProfile()
                    }
                } else {
                    // Don't fetch - wait for initialPosts to be provided via onChange
                    isLoading = false
                }
            }

            // Start badge polling for query lists
            pollQueryBadges()  // Poll immediately
            pollingTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
                pollQueryBadges()
            }
        }
        .onDisappear {
            // Stop polling when view disappears
            pollingTimer?.invalidate()
            pollingTimer = nil
        }
        .onChange(of: initialPosts) { oldValue, newValue in
            Logger.shared.info("[PostsListView] ⭐️ initialPosts onChange triggered, templateName=\(String(describing: templateName)), oldCount=\(oldValue.count), newCount=\(newValue.count), changed=\(newValue != oldValue)")
            if parentPostId == nil {
                // Only update if posts actually changed (prevent unnecessary resets)
                if newValue != oldValue {
                    Logger.shared.info("[PostsListView] ⭐️ Updating posts from initialPosts - THIS CAUSES VIEW RECREATION")
                    posts = newValue
                    isLoading = false

                    // Check if we need to edit current user's profile after posts load
                    if editCurrentUserProfile {
                        triggerEditCurrentUserProfile()
                    }
                } else {
                    Logger.shared.info("[PostsListView] ⭐️ Posts unchanged, NOT updating")
                }
            }
        }
        .onChange(of: editCurrentUserProfile) { oldValue, newValue in
            if newValue && !posts.isEmpty {
                triggerEditCurrentUserProfile()
            }
        }
        .onReceive(PostDeletionNotifier.shared.$deletedPostId) { deletedPostId in
            guard let deletedId = deletedPostId else { return }
            Logger.shared.info("[PostsListView] Received deletion notification for post \(deletedId)")
            // Remove the deleted post from this view's posts array
            if let index = posts.firstIndex(where: { $0.id == deletedId }) {
                Logger.shared.info("[PostsListView] Removing post \(deletedId) from posts array")
                posts.remove(at: index)
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

    func pollQueryBadges() {
        // Only poll if we're showing queries
        let queryPosts = posts.filter { $0.template == "query" }
        guard !queryPosts.isEmpty else { return }

        let queryIds = queryPosts.map { $0.id }

        // Get current user email
        guard let userEmail = Storage.shared.getLoginState().email else { return }

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

        // Logger.shared.info("[PostsListView] Polling badges for \(queryIds.count) queries")

        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data else { return }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Bool] {
                    DispatchQueue.main.async {
                        // Convert string keys back to Int
                        for (key, value) in json {
                            if let queryId = Int(key) {
                                self.badgeStates[queryId] = value
                            }
                        }
                        // Logger.shared.info("[PostsListView] Updated badge states: \(self.badgeStates)")
                    }
                }
            } catch {
                Logger.shared.error("[PostsListView] Error parsing badge response: \(error.localizedDescription)")
            }
        }.resume()
    }

    func fetchPluralName(for templateName: String) {
        guard let url = URL(string: "\(serverURL)/api/templates/\(templateName)") else {
            return
        }

        Logger.shared.info("[PostsListView] Fetching plural name for template: \(templateName)")

        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data else { return }

            do {
                struct TemplateResponse: Codable {
                    let status: String
                    let template: TemplateInfo
                }

                struct TemplateInfo: Codable {
                    let name: String
                    let pluralName: String?

                    enum CodingKeys: String, CodingKey {
                        case name
                        case pluralName = "plural_name"
                    }
                }

                let templateResponse = try JSONDecoder().decode(TemplateResponse.self, from: data)
                DispatchQueue.main.async {
                    self.pluralName = templateResponse.template.pluralName
                    Logger.shared.info("[PostsListView] Set plural name to: \(self.pluralName ?? "nil")")
                }
            } catch {
                Logger.shared.error("[PostsListView] Error fetching template: \(error.localizedDescription)")
            }
        }.resume()
    }

    func fetchParentPost(_ postId: Int) {
        guard let url = URL(string: "\(serverURL)/api/posts/\(postId)") else {
            return
        }

        Logger.shared.info("[PostsListView] Fetching parent post \(postId)")

        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data else { return }

            do {
                let postResponse = try JSONDecoder().decode(SinglePostResponse.self, from: data)
                DispatchQueue.main.async {
                    self.parentPost = postResponse.post
                }
            } catch {
                Logger.shared.error("[PostsListView] Error fetching parent: \(error.localizedDescription)")
            }
        }.resume()
    }

    func fetchPosts() {
        isLoading = true
        errorMessage = nil

        let urlString: String
        if let parentId = parentPostId {
            urlString = "\(serverURL)/api/posts/\(parentId)/children"
        } else {
            urlString = "\(serverURL)/api/posts/recent?limit=50"
        }

        guard let url = URL(string: urlString) else {
            isLoading = false
            errorMessage = "Invalid URL"
            return
        }

        Logger.shared.info("[PostsListView] Fetching posts (parent: \(parentPostId?.description ?? "root"))")

        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false

                if let error = error {
                    Logger.shared.error("[PostsListView] Error: \(error.localizedDescription)")
                    errorMessage = error.localizedDescription
                    return
                }

                guard let data = data else {
                    errorMessage = "No data received"
                    return
                }

                do {
                    if parentPostId != nil {
                        // Child posts - different response format
                        let childrenResponse = try JSONDecoder().decode(ChildrenResponse.self, from: data)
                        Logger.shared.info("[PostsListView] Loaded \(childrenResponse.children.count) posts")
                        self.posts = childrenResponse.children
                        // Empty lists show "Add Child Post" button - no auto-creation
                    } else {
                        // Root posts
                        let postsResponse = try JSONDecoder().decode(PostsResponse.self, from: data)
                        Logger.shared.info("[PostsListView] Loaded \(postsResponse.posts.count) posts")
                        self.posts = postsResponse.posts

                        // Register UI automation for first post
                        if let firstPost = self.posts.first {
                            let postId = firstPost.id
                            UIAutomationRegistry.shared.register(id: "first-post") {
                                Logger.shared.info("[PostsListView] first-post automation triggered")
                                DispatchQueue.main.async {
                                    guard let vm = PostsListViewModel.current else {
                                        Logger.shared.error("[PostsListView] No current viewModel!")
                                        return
                                    }
                                    Logger.shared.info("[PostsListView] Using current viewModel=\(ObjectIdentifier(vm))")
                                    Logger.shared.info("[PostsListView] Setting expandedPostId to \(postId)")
                                    vm.expandedPostId = postId
                                    Logger.shared.info("[PostsListView] expandedPostId now = \(String(describing: vm.expandedPostId))")
                                }
                            }
                            Logger.shared.info("[PostsListView] Registered first-post automation for post \(firstPost.id)")
                        }
                    }
                } catch {
                    Logger.shared.error("[PostsListView] Decode error: \(error.localizedDescription)")
                    errorMessage = "Failed to load posts"
                }
            }
        }.resume()
    }

    func createNewPost() {
        // Do nothing if custom button text is provided (demo button)
        if let customAction = onAddButtonTapped {
            Logger.shared.info("[PostsListView] Custom button tapped")
            customAction()
            return
        }

        Logger.shared.info("[PostsListView] Creating new blank post")

        // Get current user email for author
        let loginState = Storage.shared.getLoginState()
        guard let userEmail = loginState.email else {
            Logger.shared.error("[PostsListView] Cannot create post: no user logged in")
            return
        }

        // Fetch user profile to get their name
        guard let url = URL(string: "\(serverURL)/api/users/\(userEmail.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")/profile") else {
            Logger.shared.error("[PostsListView] Invalid profile URL")
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let profile = json["profile"] as? [String: Any],
                  let userName = profile["title"] as? String else {
                Logger.shared.error("[PostsListView] Failed to fetch user name, using email")
                // Fall back to using email as name
                self.insertNewPost(email: userEmail, name: userEmail)
                return
            }

            Logger.shared.info("[PostsListView] Fetched user name: \(userName)")
            self.insertNewPost(email: userEmail, name: userName)
        }.resume()
    }

    private func insertNewPost(email: String, name: String) {
        DispatchQueue.main.async {
            // Use the template from the current list
            let templateName = self.addButtonTemplate

            // Create a blank post with temporary negative ID
            let newPost = Post(
                id: -1,  // Temporary ID for unsaved post
                userId: 0,  // Will be set by server
                parentId: self.parentPostId,
                title: "",
                summary: "",
                body: "",
                imageUrl: nil,
                createdAt: "",
                timezone: "",
                locationTag: nil,
                aiGenerated: false,
                authorName: name,  // Use actual user name
                authorEmail: email,
                childCount: 0,
                titlePlaceholder: "Title",  // Will be updated from template
                summaryPlaceholder: "Summary",
                bodyPlaceholder: "Body",
                template: templateName,  // Use template from current list
                pluralName: nil,  // Will be fetched from server when post is saved
                hasNewMatches: nil
            )

            // Insert at beginning of posts array
            self.posts.insert(newPost, at: 0)

            // Expand it and enter edit mode
            self.viewModel.expandedPostId = -1
            self.editingPostId = -1
            self.isAnyPostEditing = true

            Logger.shared.info("[PostsListView] New post created and expanded in edit mode")
        }
    }

    func triggerEditCurrentUserProfile() {
        // Find the current user's profile
        let loginState = Storage.shared.getLoginState()
        guard let userEmail = loginState.email else {
            editCurrentUserProfile = false
            return
        }

        // Find profile post belonging to current user
        if let profilePost = posts.first(where: { $0.authorEmail?.lowercased() == userEmail.lowercased() && $0.template == "profile" }) {
            // Expand and edit the profile
            viewModel.expandedPostId = profilePost.id
            editingPostId = profilePost.id
            isAnyPostEditing = true
        }

        // Clear the flag
        editCurrentUserProfile = false
    }
}
