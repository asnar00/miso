import SwiftUI

// Preference key for body height measurement
struct BodyHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// Preference key for title+summary height measurement
struct TitleSummaryHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// Minimal post view - compact rectangle with thumbnail on right
struct PostView: View {
    let post: Post
    let isExpanded: Bool
    let onTap: () -> Void
    let onPostCreated: () -> Void
    let onFlickToChildren: () -> Void
    let draggedPostId: Int?
    let animateToChildren: CGFloat
    let serverURL = "http://185.96.221.52:8080"

    @State private var expansionFactor: CGFloat = 0.0
    @State private var imageAspectRatio: CGFloat = 1.0
    @State private var bodyTextHeight: CGFloat = 200  // Start with reasonable default
    @State private var titleSummaryHeight: CGFloat = 60  // Estimate for now
    @State private var isMeasured: Bool = false

    // Linear interpolation helper
    func lerp(_ start: CGFloat, _ end: CGFloat, _ t: CGFloat) -> CGFloat {
        return start + (end - start) * t
    }

    // Process body text with markdown
    func processBodyText(_ text: String) -> AttributedString {
        let pattern = "!\\[.*?\\]\\(.*?\\)"
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        let range = NSRange(text.startIndex..., in: text)
        let cleaned = regex?.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "") ?? text

        var result = AttributedString()
        let lines = cleaned.components(separatedBy: .newlines)

        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)

            if trimmedLine.isEmpty {
                if !result.characters.isEmpty {
                    result.append(AttributedString("\n\n"))
                }
            } else if trimmedLine.hasPrefix("## ") {
                if !result.characters.isEmpty {
                    result.append(AttributedString("\n"))
                }
                var heading = AttributedString(trimmedLine.dropFirst(3))
                heading.font = .system(size: 18, weight: .bold)
                result.append(heading)
                result.append(AttributedString("\n"))
            } else if trimmedLine.hasPrefix("- ") {
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
        let compactHeight: CGFloat = 100

        // Calculate expanded height based on actual content
        let availableWidth: CGFloat = 350  // Approximate - account for padding
        let imageHeight = post.imageUrl != nil ? (availableWidth / imageAspectRatio) : 0
        let authorHeight: CGFloat = 15  // Approximate height for author line
        let expandedHeight: CGFloat = titleSummaryHeight + 16 + imageHeight + 16 + bodyTextHeight + 24 + authorHeight + 16

        let currentHeight = lerp(compactHeight, expandedHeight, expansionFactor)

        // Link circle constants
        let linkCircleSize: CGFloat = 12
        let linkLineThickness: CGFloat = 4
        let linkY: CGFloat = 48  // Aligned with thumbnail center: 8 (compactY) + 40 (half of 80)

        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.9))
                .frame(height: currentHeight)
                .shadow(radius: 2)

            // Rightward link (if post has children)
            if let childCount = post.childCount, childCount > 0 {
                // Link line extending right
                Rectangle()
                    .fill(Color.black)
                    .frame(width: 100, height: linkLineThickness)
                    .offset(x: availableWidth + 10 + linkCircleSize/2, y: linkY + linkCircleSize/2 - linkLineThickness/2)

                // Circle
                Circle()
                    .fill(Color.black)
                    .frame(width: linkCircleSize, height: linkCircleSize)
                    .offset(x: availableWidth + 10 + linkCircleSize/2, y: linkY)
            }

            // Leftward link (if post has parent)
            if post.parentId != nil {
                // Link line extending left
                Rectangle()
                    .fill(Color.black)
                    .frame(width: 100, height: linkLineThickness)
                    .offset(x: -100, y: linkY + linkCircleSize/2 - linkLineThickness/2)

                // Circle
                Circle()
                    .fill(Color.black)
                    .frame(width: linkCircleSize, height: linkCircleSize)
                    .offset(x: -linkCircleSize/2, y: linkY)
            }

            // Title and summary at the top
            VStack(alignment: .leading, spacing: 4) {
                Text(post.title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.black)
                    .lineLimit(1)

                Text(post.summary)
                    .font(.system(size: 15))
                    .italic()
                    .foregroundColor(.black.opacity(0.8))
                    .lineLimit(2)
            }
            .padding(8)
            .padding(.leading, linkCircleSize)  // Extra left padding to clear the link circle
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.trailing, post.imageUrl != nil ? (96 + 2 * linkCircleSize) : 0)  // Leave room for thumbnail (adjusted for symmetry)
            .background(
                GeometryReader { geo in
                    Color.clear.preference(key: TitleSummaryHeightKey.self, value: geo.size.height)
                }
            )
            .onPreferenceChange(TitleSummaryHeightKey.self) { height in
                titleSummaryHeight = height
            }

            // Body text below the image
            if isExpanded && isMeasured {
                // Calculate current image dimensions and position
                let compactImageHeight: CGFloat = 80
                let compactImageY: CGFloat = (100 - 80) / 2 + 8
                let expandedImageY = titleSummaryHeight + 8
                let expandedImageHeight = availableWidth / imageAspectRatio

                let currentImageY = lerp(compactImageY, expandedImageY, expansionFactor)
                let currentImageHeight = lerp(compactImageHeight, expandedImageHeight, expansionFactor)

                // Position text below the current image position
                let bodyY = currentImageY + currentImageHeight + 16
                let currentBodyHeight = lerp(0, bodyTextHeight, expansionFactor)

                Text(processBodyText(post.body))
                    .foregroundColor(.black)
                    .frame(width: availableWidth, alignment: .leading)
                    .frame(height: bodyTextHeight, alignment: .top)
                    .clipped()
                    .mask(
                        Rectangle()
                            .frame(height: currentBodyHeight)
                            .frame(maxHeight: .infinity, alignment: .top)
                    )
                    .offset(x: 10, y: bodyY)
            }

            // Author - fades in when expanded
            if isExpanded && isMeasured {
                // Calculate position below body text
                let compactImageHeight: CGFloat = 80
                let compactImageY: CGFloat = (100 - 80) / 2 + 8
                let expandedImageY = titleSummaryHeight + 8
                let expandedImageHeight = availableWidth / imageAspectRatio

                let currentImageY = lerp(compactImageY, expandedImageY, expansionFactor)
                let currentImageHeight = lerp(compactImageHeight, expandedImageHeight, expansionFactor)
                let authorY = currentImageY + currentImageHeight + 16 + bodyTextHeight + 24  // Below body text with spacing

                HStack {
                    if post.aiGenerated {
                        Text("👓 librarian")
                            .font(.subheadline)
                            .foregroundColor(.black.opacity(0.5))
                    } else if let authorName = post.authorName {
                        Text(authorName)
                            .font(.subheadline)
                            .foregroundColor(.black.opacity(0.5))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .offset(x: 10, y: authorY)  // Align with content left edge
                .opacity(expansionFactor)  // Fade in with expansion
            }

            // Animated image - interpolates from thumbnail to full-size
            if let imageUrl = post.imageUrl {
                let fullUrl = serverURL + imageUrl

                // Compact state: 80x80 thumbnail on top-right with padding
                let compactWidth: CGFloat = 80
                let compactHeight: CGFloat = 80
                let compactX = availableWidth - 80 + 8 - (2 * linkCircleSize)  // Right-aligned, inset for symmetry
                let compactY: CGFloat = (compactHeight - 80) / 2 + 8  // Vertically centered in compact view with top padding

                // Expanded state: full-width centered below summary (matching content rectangle)
                let expandedWidth = availableWidth
                let expandedHeight = availableWidth / imageAspectRatio
                let expandedX: CGFloat = 10  // Aligned with content rectangle left edge (centered with padding)
                let expandedY = titleSummaryHeight + 8  // Below summary

                // Interpolated values
                let currentWidth = lerp(compactWidth, expandedWidth, expansionFactor)
                let currentHeight = lerp(compactHeight, expandedHeight, expansionFactor)
                let currentX = lerp(compactX, expandedX, expansionFactor)
                let currentY = lerp(compactY, expandedY, expansionFactor)

                AsyncImage(url: URL(string: fullUrl)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: currentWidth, height: currentHeight)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    case .failure(_), .empty:
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: currentWidth, height: currentHeight)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    @unknown default:
                        EmptyView()
                    }
                }
                .offset(x: currentX, y: currentY)
                .task {
                    // Load aspect ratio when image first appears
                    if imageAspectRatio == 1.0 {
                        if let url = URL(string: fullUrl) {
                            do {
                                let (data, _) = try await URLSession.shared.data(from: url)
                                if let uiImage = UIImage(data: data) {
                                    imageAspectRatio = uiImage.size.width / uiImage.size.height
                                }
                            } catch {
                                // Failed to load image, keep default aspect ratio
                            }
                        }
                    }
                }
            }
        }
        .background(
            // Measure body text only when needed (when expanding)
            // Use formatted text for accurate measurement
            Group {
                if isExpanded && !isMeasured {
                    Text(processBodyText(post.body))
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(width: 350)
                        .background(
                            GeometryReader { geo in
                                Color.clear.preference(key: BodyHeightKey.self, value: geo.size.height)
                            }
                        )
                        .onPreferenceChange(BodyHeightKey.self) { height in
                            bodyTextHeight = height
                            isMeasured = true
                        }
                        .hidden()
                }
            }
        )
        .opacity({
            // If this is the dragged post or not navigating, stay opaque
            if draggedPostId == post.id || animateToChildren == 0 {
                return 1.0
            } else {
                // Fade out other posts during navigation
                return 1.0 - animateToChildren
            }
        }())
        .simultaneousGesture(
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    // Check if we have children
                    guard let childCount = post.childCount, childCount > 0 else { return }

                    // Check for horizontal leftward gesture
                    let horizontalAmount = abs(value.translation.width)
                    let verticalAmount = abs(value.translation.height)
                    guard value.translation.width < 0 && horizontalAmount > verticalAmount * 1.5 else { return }

                    // Calculate velocity
                    let velocity = value.predictedEndTranslation.width - value.translation.width

                    // Trigger if dragged > 50pt or flicked with velocity > 500
                    if value.translation.width < -50 || velocity < -500 {
                        onFlickToChildren()
                    }
                }
        )
        .onTapGesture {
            onTap()
        }
        .onChange(of: isExpanded) { _, newValue in
            if newValue {
                // Expanding - animate immediately with default aspect ratio
                withAnimation(.easeInOut(duration: 0.3)) {
                    expansionFactor = 1.0
                }
            } else {
                // Collapsing - animate immediately
                withAnimation(.easeInOut(duration: 0.3)) {
                    expansionFactor = 0.0
                }
            }
        }
        .onAppear {
            // Set initial expansion state without doing any heavy work
            expansionFactor = isExpanded ? 1.0 : 0.0
        }
    }
}
