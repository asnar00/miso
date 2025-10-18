import SwiftUI

struct PostsView: View {
    let posts: [Post]
    let onPostCreated: () -> Void

    @State private var expandedPostId: Int? = nil
    @State private var showNewPostEditor = false
    @State private var draggedPostId: Int? = nil
    @State private var childrenViewPostId: Int? = nil  // Which post's children are we viewing
    @State private var animateToChildren: CGFloat = 0  // 0 = parent view, 1 = children view
    @State private var isDragging: Bool = false

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let screenWidth = geometry.size.width

                ZStack {
                    // Main posts content - offset based on animateToChildren
                    postsContent
                        .offset(x: -screenWidth * animateToChildren)

                    // Children view - offset based on animateToChildren
                    if let postId = (draggedPostId ?? childrenViewPostId),
                       let post = posts.first(where: { $0.id == postId }),
                       let childCount = post.childCount, childCount > 0 {
                        ChildrenPostsView(
                            parentPostId: post.id,
                            parentPostTitle: post.title,
                            onPostCreated: onPostCreated,
                            onFlickBack: {
                                // Animate back to parent
                                withAnimation(.easeOut(duration: 0.3)) {
                                    animateToChildren = 0
                                }
                                // Clear state after animation
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    childrenViewPostId = nil
                                    draggedPostId = nil
                                }
                            }
                        )
                        .offset(x: screenWidth * (1.0 - animateToChildren))
                    }
                }
            }
        }
        .navigationBarHidden(true)
    }

    var postsContent: some View {
        ZStack {
            Color(red: 64/255, green: 224/255, blue: 208/255)
                .ignoresSafeArea()

            VStack {
                if posts.isEmpty {
                    Text("No posts yet")
                        .foregroundColor(.black)
                        .padding()
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(spacing: 8) {
                                // New post button at the top
                                NewPostButton {
                                    showNewPostEditor = true
                                }

                                ForEach(posts) { post in
                                    PostView(
                                        post: post,
                                        isExpanded: expandedPostId == post.id,
                                        onTap: {
                                            if expandedPostId == post.id {
                                                // Collapse currently expanded post
                                                expandedPostId = nil
                                            } else {
                                                // Expand new post and scroll to it
                                                expandedPostId = post.id
                                                withAnimation(.easeInOut(duration: 0.3)) {
                                                    proxy.scrollTo(post.id, anchor: .top)
                                                }
                                            }
                                        },
                                        onPostCreated: onPostCreated,
                                        onFlickToChildren: {
                                            // Set which post's children to show (creates the view)
                                            draggedPostId = post.id
                                            // Let SwiftUI render the view, THEN animate
                                            DispatchQueue.main.async {
                                                withAnimation(.easeOut(duration: 0.3)) {
                                                    animateToChildren = 1.0
                                                }
                                                // Make permanent after animation
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                                    childrenViewPostId = post.id
                                                    draggedPostId = nil
                                                }
                                            }
                                        },
                                        draggedPostId: draggedPostId,
                                        animateToChildren: animateToChildren
                                    )
                                    .id(post.id)
                                }
                            }
                            .padding()
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showNewPostEditor) {
            NewPostEditor(onPostCreated: onPostCreated, parentId: nil)
        }
    }
}

// Old PostCardView - DEPRECATED, use PostView.swift instead
/*
struct PostCardView: View {
    let post: Post
    @Binding var isExpanded: Bool
    let onPostCreated: () -> Void
    let serverURL = "http://185.96.221.52:8080"

    @State private var isAnimatingCollapse = false
    @State private var collapseHeight: CGFloat? = nil
    @State private var measuredCompactHeight: CGFloat = 110

    // Custom tree icon: circle with line branching to three circles
    var treeIcon: some View {
        Canvas { context, size in
            let circleRadius: CGFloat = 3.0
            let startX = size.width * 0.15
            let midX = size.width * 0.45
            let endX = size.width * 0.85
            let centerY = size.height * 0.5
            let topY = size.height * 0.15
            let bottomY = size.height * 0.85
            let cornerRadius: CGFloat = 4.5

            // Draw horizontal line from circle to fork point
            var path = Path()
            path.move(to: CGPoint(x: startX + circleRadius, y: centerY))
            path.addLine(to: CGPoint(x: midX - cornerRadius, y: centerY))

            // Draw three branches with vertical paths and curved corners
            // Top branch
            path.addQuadCurve(to: CGPoint(x: midX, y: centerY - cornerRadius),
                            control: CGPoint(x: midX, y: centerY))
            path.addLine(to: CGPoint(x: midX, y: topY + cornerRadius))
            path.addQuadCurve(to: CGPoint(x: midX + cornerRadius, y: topY),
                            control: CGPoint(x: midX, y: topY))
            path.addLine(to: CGPoint(x: endX - circleRadius, y: topY))

            // Middle branch
            path.move(to: CGPoint(x: midX, y: centerY))
            path.addLine(to: CGPoint(x: endX - circleRadius, y: centerY))

            // Bottom branch
            path.move(to: CGPoint(x: midX, y: centerY))
            path.addQuadCurve(to: CGPoint(x: midX, y: centerY + cornerRadius),
                            control: CGPoint(x: midX, y: centerY))
            path.addLine(to: CGPoint(x: midX, y: bottomY - cornerRadius))
            path.addQuadCurve(to: CGPoint(x: midX + cornerRadius, y: bottomY),
                            control: CGPoint(x: midX, y: bottomY))
            path.addLine(to: CGPoint(x: endX - circleRadius, y: bottomY))

            context.stroke(path, with: .color(.black), lineWidth: 1.5)

            // Draw circles
            let circles = [
                CGPoint(x: startX, y: centerY),
                CGPoint(x: endX, y: topY),
                CGPoint(x: endX, y: centerY),
                CGPoint(x: endX, y: bottomY)
            ]

            for point in circles {
                context.fill(
                    Path(ellipseIn: CGRect(x: point.x - circleRadius, y: point.y - circleRadius,
                                          width: circleRadius * 2, height: circleRadius * 2)),
                    with: .color(.black)
                )
            }
        }
        .frame(width: 24, height: 24)
    }

    // Strip image markdown references and process body text
    func processBodyText(_ text: String) -> AttributedString {
        // Remove image markdown: ![alt](url)
        let pattern = "!\\[.*?\\]\\(.*?\\)"
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        let range = NSRange(text.startIndex..., in: text)
        let cleaned = regex?.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "") ?? text

        var result = AttributedString()
        let lines = cleaned.components(separatedBy: .newlines)

        for (index, line) in lines.enumerated() {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)

            if trimmedLine.isEmpty {
                // Empty line - add paragraph break only if we have content
                if !result.characters.isEmpty {
                    result.append(AttributedString("\n\n"))
                }
            } else if trimmedLine.hasPrefix("## ") {
                // H2 heading - bold and slightly larger
                if !result.characters.isEmpty {
                    result.append(AttributedString("\n"))
                }
                var heading = AttributedString(trimmedLine.dropFirst(3))
                heading.font = .system(size: 18, weight: .bold)
                result.append(heading)
                result.append(AttributedString("\n"))
            } else if trimmedLine.hasPrefix("- ") {
                // Bullet point - add bullet and indent
                if !result.characters.isEmpty && !result.characters.last!.isNewline {
                    result.append(AttributedString("\n"))
                }
                let bulletText = trimmedLine.dropFirst(2)
                var bullet = AttributedString("• ")
                bullet.font = .body
                result.append(bullet)
                var item = AttributedString(bulletText)
                item.font = .body
                result.append(item)
                result.append(AttributedString("\n"))
            } else {
                // Regular paragraph text
                if !result.characters.isEmpty && !result.characters.last!.isNewline {
                    result.append(AttributedString(" "))
                }
                var paragraph = AttributedString(trimmedLine)
                paragraph.font = .body
                result.append(paragraph)
            }
        }

        return result
    }

    var body: some View {
        Group {
            if isExpanded || isAnimatingCollapse {
                fullView
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(height: collapseHeight, alignment: .top)
                    .clipped()
            } else {
                compactView
            }
        }
        .padding()
        .background(Color.white.opacity(0.9))
        .cornerRadius(12)
        .shadow(radius: 2)
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.3)) {
                isExpanded.toggle()
            }
        }
        .onChange(of: isExpanded) { oldValue, newValue in
            if oldValue && !newValue {
                // Started collapsing - animate height down first
                isAnimatingCollapse = true
                collapseHeight = nil  // Start at full height

                // Animate height down to compact size
                withAnimation(.easeInOut(duration: 0.3)) {
                    collapseHeight = measuredCompactHeight
                }

                // After animation completes, switch to compact view
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isAnimatingCollapse = false
                    collapseHeight = nil  // Reset for next time
                }
            }
        }
    }

    var compactView: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(post.title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.black)

                Text(post.summary)
                    .font(.subheadline)
                    .italic()
                    .foregroundColor(.black.opacity(0.8))
            }

            Spacer()

            // Always show thumbnail in compact view
            if let imageUrl = post.imageUrl {
                let fullUrl = serverURL + imageUrl
                if let thumbnail = ImageCache.shared.getThumbnail(fullUrl) {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    // Fallback to AsyncImage if cache doesn't have it
                    AsyncImage(url: URL(string: fullUrl)) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        case .failure(_), .empty:
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        @unknown default:
                            EmptyView()
                        }
                    }
                }
            }
        }
        .background(
            GeometryReader { geometry in
                Color.clear.onAppear {
                    measuredCompactHeight = geometry.size.height
                }
            }
        )
    }

    var fullView: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title and summary with optional children button
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    // Title
                    Text(post.title)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.black)

                    // Summary
                    Text(post.summary)
                        .font(.subheadline)
                        .italic()
                        .foregroundColor(.black.opacity(0.8))
                }

                Spacer(minLength: 8)

                // Show children button if post has children
                if let childCount = post.childCount, childCount > 0 {
                    NavigationLink(destination: ChildrenPostsView(parentPostId: post.id, parentPostTitle: post.title, onPostCreated: onPostCreated)) {
                        treeIcon
                            .frame(width: 48, height: 48)
                            .background(Color.white)
                            .cornerRadius(8)
                            .shadow(radius: 2)
                    }
                }
            }

            // Image if available
            if let imageUrl = post.imageUrl {
                let fullUrl = serverURL + imageUrl
                if let fullImage = ImageCache.shared.getFullImage(fullUrl) {
                    // Use cached image
                    Image(uiImage: fullImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .cornerRadius(12)
                        .padding(.top, 8)
                        .padding(.bottom, 8)
                } else {
                    // Fallback to AsyncImage if cache doesn't have it (was evicted)
                    AsyncImage(url: URL(string: fullUrl)) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: .infinity)
                                .cornerRadius(12)
                                .padding(.top, 8)
                                .padding(.bottom, 8)
                        case .failure(_):
                            EmptyView()
                        case .empty:
                            ProgressView()
                                .padding(.top, 8)
                        @unknown default:
                            EmptyView()
                        }
                    }
                }
            }

            // Body text with markdown rendering
            Text(processBodyText(post.body))
                .foregroundColor(.black)
                .lineLimit(nil)
                .padding(.bottom, 8)

            // Metadata
            VStack(alignment: .leading, spacing: 4) {
                // Author or librarian badge
                if post.aiGenerated {
                    Text("👓 librarian")
                        .font(.caption)
                        .foregroundColor(.black.opacity(0.6))
                } else if let authorName = post.authorName {
                    Text(authorName)
                        .font(.caption)
                        .foregroundColor(.black.opacity(0.6))
                }

                // Location and date on same line
                HStack {
                    if let location = post.locationTag {
                        Label(location, systemImage: "location")
                            .font(.caption)
                            .foregroundColor(.black.opacity(0.6))
                    }

                    Spacer()

                    Text(post.createdAt)
                        .font(.caption)
                        .foregroundColor(.black.opacity(0.6))
                }
            }
        }
    }
}
*/

// View for displaying children of a post
struct ChildrenPostsView: View {
    let parentPostId: Int
    let parentPostTitle: String
    let onPostCreated: () -> Void
    let onFlickBack: () -> Void
    @State private var children: [Post] = []
    @State private var isLoading = true
    @State private var expandedPostId: Int? = nil
    @State private var showNewPostEditor = false
    let serverURL = "http://185.96.221.52:8080"

    var body: some View {
        ZStack {
            Color(red: 64/255, green: 224/255, blue: 208/255)
                .ignoresSafeArea()

            VStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                } else if children.isEmpty {
                    Text("No children posts")
                        .foregroundColor(.black)
                        .padding()
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(spacing: 8) {
                                // New post button at the top
                                NewPostButton {
                                    showNewPostEditor = true
                                }

                                ForEach(children) { post in
                                    PostView(
                                        post: post,
                                        isExpanded: expandedPostId == post.id,
                                        onTap: {
                                            if expandedPostId == post.id {
                                                expandedPostId = nil
                                            } else {
                                                expandedPostId = post.id
                                                withAnimation(.easeInOut(duration: 0.3)) {
                                                    proxy.scrollTo(post.id, anchor: .top)
                                                }
                                            }
                                        },
                                        onPostCreated: onPostCreated,
                                        onFlickToChildren: {
                                            // For now, do nothing - could add recursive navigation later
                                        },
                                        draggedPostId: nil,
                                        animateToChildren: 0
                                    )
                                    .id(post.id)
                                }
                            }
                            .padding()
                        }
                    }
                }
            }
        }
        .navigationTitle("Children of \(parentPostTitle)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            fetchChildren()
        }
        .sheet(isPresented: $showNewPostEditor) {
            NewPostEditor(onPostCreated: {
                // Reload children when a new post is created
                fetchChildren()
                // Also reload the parent recent posts view
                onPostCreated()
            }, parentId: parentPostId)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    // Check for horizontal rightward gesture
                    let horizontalAmount = abs(value.translation.width)
                    let verticalAmount = abs(value.translation.height)
                    guard value.translation.width > 0 && horizontalAmount > verticalAmount * 1.5 else { return }

                    // Calculate velocity
                    let velocity = value.predictedEndTranslation.width - value.translation.width

                    // Trigger if dragged > 50pt or flicked with velocity > 500
                    if value.translation.width > 50 || velocity > 500 {
                        onFlickBack()
                    }
                }
        )
    }

    func fetchChildren() {
        guard let url = URL(string: "\(serverURL)/api/posts/\(parentPostId)/children") else {
            Logger.shared.error("[ChildrenPostsView] Invalid URL")
            return
        }

        Logger.shared.info("[ChildrenPostsView] Fetching children for post \(parentPostId)")

        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                Logger.shared.error("[ChildrenPostsView] Error fetching children: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    isLoading = false
                }
                return
            }

            guard let data = data else {
                Logger.shared.error("[ChildrenPostsView] No data received")
                DispatchQueue.main.async {
                    isLoading = false
                }
                return
            }

            do {
                let response = try JSONDecoder().decode(ChildrenResponse.self, from: data)
                DispatchQueue.main.async {
                    children = response.children
                    isLoading = false
                    Logger.shared.info("[ChildrenPostsView] Fetched \(children.count) children")
                }
            } catch {
                Logger.shared.error("[ChildrenPostsView] Decoding error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    isLoading = false
                }
            }
        }.resume()
    }
}

struct ChildrenResponse: Codable {
    let status: String
    let postId: Int
    let children: [Post]
    let count: Int

    enum CodingKeys: String, CodingKey {
        case status
        case postId = "post_id"
        case children
        case count
    }
}

#Preview {
    PostsView(posts: [], onPostCreated: {})
}
