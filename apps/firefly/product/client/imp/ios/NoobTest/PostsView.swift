import SwiftUI

struct PostsView: View {
    let posts: [Post]
    let onPostCreated: () -> Void

    @State private var expandedPostIds: Set<Int> = []
    @State private var showNewPostEditor = false

    var body: some View {
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
                                    PostCardView(
                                        post: post,
                                        isExpanded: Binding(
                                            get: { expandedPostIds.contains(post.id) },
                                            set: { expanded in
                                                if expanded {
                                                    // Collapse all other posts
                                                    expandedPostIds.removeAll()
                                                    expandedPostIds.insert(post.id)
                                                    // Scroll to top of expanded post concurrently with animation
                                                    withAnimation(.easeInOut(duration: 0.3)) {
                                                        proxy.scrollTo(post.id, anchor: .top)
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
            // Expand first post by default
            if let firstPost = posts.first {
                expandedPostIds.insert(firstPost.id)
            }
        }
        .sheet(isPresented: $showNewPostEditor) {
            NewPostEditor(onPostCreated: onPostCreated)
        }
    }
}

struct PostCardView: View {
    let post: Post
    @Binding var isExpanded: Bool
    let serverURL = "http://185.96.221.52:8080"

    @State private var isAnimatingCollapse = false
    @State private var collapseHeight: CGFloat? = nil
    @State private var measuredCompactHeight: CGFloat = 110

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

#Preview {
    PostsView(posts: [], onPostCreated: {})
}
