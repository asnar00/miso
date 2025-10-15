import SwiftUI

struct PostsView: View {
    @State private var posts: [Post] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var expandedPostIds: Set<Int> = []

    var body: some View {
        ZStack {
            Color(red: 64/255, green: 224/255, blue: 208/255)
                .ignoresSafeArea()

            VStack {
                if isLoading {
                    ProgressView("Loading posts...")
                        .foregroundColor(.black)
                } else if let error = errorMessage {
                    Text("Error: \(error)")
                        .foregroundColor(.red)
                        .padding()
                    Button("Retry") {
                        loadPosts()
                    }
                    .padding()
                    .background(Color.white.opacity(0.3))
                    .cornerRadius(8)
                } else if posts.isEmpty {
                    Text("No posts yet")
                        .foregroundColor(.black)
                        .padding()
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(spacing: 8) {
                                ForEach(posts) { post in
                                    PostCardView(
                                        post: post,
                                        isExpanded: Binding(
                                            get: { expandedPostIds.contains(post.id) },
                                            set: { expanded in
                                                if expanded {
                                                    // Collapse all other posts
                                                    expandedPostIds.removeAll()
                                                    expandedPostIds.insert(post.id)
                                                    // Scroll to the expanded post with slight delay for animation
                                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                                        withAnimation {
                                                            proxy.scrollTo(post.id, anchor: .center)
                                                        }
                                                    }
                                                } else {
                                                    expandedPostIds.remove(post.id)
                                                }
                                            }
                                        )
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
        .onAppear {
            loadPosts()
        }
    }

    func loadPosts() {
        isLoading = true
        errorMessage = nil

        PostsAPI.shared.fetchRecentPosts { result in
            switch result {
            case .success(let fetchedPosts):
                // Preload first image, then display immediately
                // Continue loading other images in background
                self.preloadImagesOptimized(for: fetchedPosts) {
                    DispatchQueue.main.async {
                        self.posts = fetchedPosts
                        self.isLoading = false
                        // Expand the first post by default
                        if let firstPost = fetchedPosts.first {
                            self.expandedPostIds.insert(firstPost.id)
                        }
                    }
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
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

struct PostCardView: View {
    let post: Post
    @Binding var isExpanded: Bool
    let serverURL = "http://185.96.221.52:8080"

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
                // Empty line - add spacing
                if index > 0 {
                    result.append(AttributedString("\n"))
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
            if isExpanded {
                fullView
            } else {
                compactView
            }
        }
        .padding()
        .background(Color.white.opacity(0.9))
        .cornerRadius(12)
        .shadow(radius: 2)
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isExpanded = true
            }
        }
        .gesture(
            MagnificationGesture()
                .onEnded { scale in
                    // Pinch/zoom out to collapse
                    if scale < 0.95 && isExpanded {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            isExpanded = false
                        }
                    }
                }
        )
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

            if let imageUrl = post.imageUrl {
                let fullUrl = serverURL + imageUrl
                if let cachedImage = ImageCache.shared.get(fullUrl) {
                    Image(uiImage: cachedImage)
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
    }

    var fullView: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title
            Text(post.title)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.black)

            // Summary
            Text(post.summary)
                .font(.subheadline)
                .italic()
                .foregroundColor(.black.opacity(0.8))

            // Image if available
            if let imageUrl = post.imageUrl {
                let fullUrl = serverURL + imageUrl
                if let cachedImage = ImageCache.shared.get(fullUrl) {
                    // Use cached image
                    Image(uiImage: cachedImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .cornerRadius(12)
                        .padding(.top, 8)
                        .padding(.bottom, -2)
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
                                .padding(.bottom, -2)
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

            // Metadata
            HStack {
                if let location = post.locationTag {
                    Label(location, systemImage: "location")
                        .font(.caption)
                        .foregroundColor(.black.opacity(0.6))
                }

                Spacer()

                Text(formatDate(post.createdAt))
                    .font(.caption)
                    .foregroundColor(.black.opacity(0.6))
            }

            if post.aiGenerated {
                Label("AI Generated", systemImage: "sparkles")
                    .font(.caption)
                    .foregroundColor(.purple)
            }
        }
    }

    func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }

        return dateString
    }
}

#Preview {
    PostsView()
}
