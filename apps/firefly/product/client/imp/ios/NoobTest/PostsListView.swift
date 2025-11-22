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
    @Binding var isAnyPostEditing: Bool  // Track if any post is being edited (for toolbar fade)

    @ObservedObject var tunables = TunableConstants.shared

    // Corner roundness helper
    private var cornerRoundness: CGFloat {
        tunables.getDouble("corner-roundness", default: 1.0)
    }

    // Computed property: determine if we should show add button and what template to use
    private var shouldShowAddButton: Bool {
        // If custom text provided, always show button
        if customAddButtonText != nil { return true }

        // For child posts, only show if parent is owned by current user
        if let parentId = parentPostId {
            if let parent = parentPost {
                let loginState = Storage.shared.getLoginState()
                if let userEmail = loginState.email, let parentEmail = parent.authorEmail {
                    return userEmail.lowercased() == parentEmail.lowercased()
                }
            }
            return false  // Parent not loaded yet or not owned
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
        // Capitalize first letter of template name
        let template = addButtonTemplate
        return "Add " + template.prefix(1).uppercased() + template.dropFirst()
    }

    private var emptyStateMessage: String {
        // Use fetched plural name first, then fall back to first post's template
        if let pluralName = pluralName {
            return "No \(pluralName) yet"
        }
        if let firstPost = initialPosts.first, let pluralName = firstPost.pluralName {
            return "No \(pluralName) yet"
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
            Color(red: 128/255, green: 128/255, blue: 128/255)
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
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 8 * tunables.getDouble("spacing", default: 1.0)) {
                            // Add post button at the top (smart detection based on template)
                            if shouldShowAddButton {
                                Button(action: {
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
                                    .background(Color(
                                        red: tunables.getDouble("button-colour", default: 0.5),
                                        green: tunables.getDouble("button-colour", default: 0.5),
                                        blue: tunables.getDouble("button-colour", default: 0.5)
                                    ))
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
                                        isEditing: editingPostId == post.id,
                                        showNotificationBadge: badgeStates[post.id] ?? false,
                                        onTap: {
                                            // If we're editing a different post, save it first
                                            if let currentlyEditingId = editingPostId, currentlyEditingId != post.id {
                                                // Auto-save will happen in PostView via onStartEditing callback
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
                                            editingPostId = nil
                                            isAnyPostEditing = false
                                        },
                                        onDelete: {
                                            // Delete post (either unsaved or after server deletion)
                                            posts.removeAll { $0.id == post.id }
                                            editingPostId = nil
                                            isAnyPostEditing = false
                                            // If it was a saved post, refresh to update parent's child count
                                            if post.id > 0 {
                                                fetchPosts()
                                                onPostCreated()  // Notify parent to refresh
                                            }
                                        }
                                    )
                                    .id(post.id)
                                }
                            }
                        }
                        .padding(.horizontal, 8 * tunables.getDouble("spacing", default: 1.0))  // Side margins
                        .padding(.bottom)
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
                        .background(
                            Color(
                                red: tunables.getDouble("button-colour", default: 0.5),
                                green: tunables.getDouble("button-colour", default: 0.5),
                                blue: tunables.getDouble("button-colour", default: 0.5)
                            )
                        )
                        .cornerRadius(20 * cornerRoundness)
                    }
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
            Logger.shared.info("[PostsListView] onAppear called, initialPosts.count=\(initialPosts.count), posts.count=\(posts.count)")

            // Set as current viewModel for automation access
            if parentPostId == nil && backLabel == nil {  // Only for root view
                PostsListViewModel.current = viewModel
                Logger.shared.info("[PostsListView] Set current viewModel to \(ObjectIdentifier(viewModel))")
            }

            // Set initial expanded post if specified
            if let expandPostId = initialExpandedPostId {
                viewModel.expandedPostId = expandPostId
                Logger.shared.info("[PostsListView] Set initial expandedPostId to \(expandPostId)")
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
                    Logger.shared.info("[PostsListView] Using initialPosts, count=\(initialPosts.count)")
                    posts = initialPosts
                    isLoading = false
                } else {
                    Logger.shared.info("[PostsListView] No initialPosts yet, waiting for parent to provide them")
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
            Logger.shared.info("[PostsListView] initialPosts changed! old.count=\(oldValue.count), new.count=\(newValue.count)")
            if parentPostId == nil {
                Logger.shared.info("[PostsListView] Root view: updating posts to new initialPosts")
                posts = newValue
                isLoading = false
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

        Logger.shared.info("[PostsListView] Polling badges for \(queryIds.count) queries")

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
                        Logger.shared.info("[PostsListView] Updated badge states: \(self.badgeStates)")
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

                        // Auto-create a child post if we navigated to an empty child list
                        // (user tapped "+" button on their own post with no children)
                        if childrenResponse.children.isEmpty {
                            if let parent = self.parentPost, parent.authorEmail == Storage.shared.getLoginState().email {
                                Logger.shared.info("[PostsListView] Empty child list for owned post - auto-creating first child")
                                self.createNewPost()
                            }
                        }
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
        if customAddButtonText != nil {
            Logger.shared.info("[PostsListView] Custom button tapped (no action)")
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
}
