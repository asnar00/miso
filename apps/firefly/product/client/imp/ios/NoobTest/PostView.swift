import SwiftUI
import UIKit

// Zoomable image view using UIScrollView for proper pinch-to-zoom behavior
struct ZoomableImageView: UIViewRepresentable {
    let image: UIImage
    let size: CGSize
    let cornerRadius: CGFloat
    @Binding var isZooming: Bool

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 4.0
        scrollView.bouncesZoom = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.clipsToBounds = false  // Allow image to overflow
        scrollView.backgroundColor = .clear

        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = cornerRadius
        imageView.frame = CGRect(origin: .zero, size: size)
        imageView.tag = 100

        scrollView.addSubview(imageView)
        scrollView.contentSize = size

        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        if let imageView = scrollView.viewWithTag(100) as? UIImageView {
            imageView.image = image
            imageView.frame = CGRect(origin: .zero, size: size)
            imageView.layer.cornerRadius = cornerRadius
        }
        scrollView.contentSize = size
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIScrollViewDelegate {
        var parent: ZoomableImageView

        init(_ parent: ZoomableImageView) {
            self.parent = parent
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            return scrollView.viewWithTag(100)
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            parent.isZooming = scrollView.zoomScale > 1.0
        }

        func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
            // Always snap back to 1.0 when fingers are lifted
            UIView.animate(withDuration: 0.15, delay: 0, options: .curveEaseOut) {
                scrollView.zoomScale = 1.0
            }
            parent.isZooming = false
        }
    }
}

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
    let availableWidth: CGFloat  // Width of the post view, passed from parent
    var isEditing: Bool = false  // Passed from parent to control edit state
    var showNotificationBadge: Bool = false  // Passed from parent (polled state)
    let onTap: () -> Void
    let onPostCreated: () -> Void
    let onNavigateToChildren: ((Int) -> Void)?
    let onNavigateToProfile: ((String, Post) -> Void)?  // backLabel, profilePost
    let onNavigateToQueryResults: ((Int, String) -> Void)?  // queryPostId, backLabel
    let onPostUpdated: ((Post) -> Void)?
    let onStartEditing: (() -> Void)?  // Called when entering edit mode

    @ObservedObject var tunables = TunableConstants.shared
    let onEndEditing: (() -> Void)?  // Called when exiting edit mode
    let onDelete: (() -> Void)?  // Called when deleting post (new or after server deletion)
    var isNewPost: Bool = false  // True for unsaved posts (id < 0), affects undo button behavior
    @Binding var shouldBounceButtons: Bool  // Trigger bounce animation on edit buttons
    let serverURL = "http://185.96.221.52:8080"

    // Font scaling helper
    private var fontScale: CGFloat {
        tunables.getDouble("font-scale", default: 1.0)
    }

    // Corner roundness helper
    private var cornerRoundness: CGFloat {
        tunables.getDouble("corner-roundness", default: 1.0)
    }

    @State private var expansionFactor: CGFloat = 0.0
    @State private var imageAspectRatio: CGFloat = 1.0
    @State private var originalImageAspectRatio: CGFloat = 1.0  // Save original for cancel
    @State private var bodyTextHeight: CGFloat = 200  // Start with reasonable default
    @State private var titleSummaryHeight: CGFloat = 60  // Estimate for now
    @State private var isMeasured: Bool = false
    @State private var editableTitle: String = ""
    @State private var editableSummary: String = ""
    @State private var editableBody: String = ""
    @State private var editableImageUrl: String? = nil  // nil means image removed
    @State private var showImagePicker: Bool = false
    @State private var selectedImage: UIImage? = nil
    @State private var newImageData: Data? = nil  // Processed image data ready for upload
    @State private var showDeleteConfirmation: Bool = false
    @State private var newImage: UIImage? = nil  // Processed image for display
    @State private var authorHasProfile: Bool = true  // Assume true until checked

    // Image zoom state
    @State private var isImageZooming: Bool = false
    @State private var loadedUIImage: UIImage? = nil  // Cached UIImage for zoomable view

    // Edit button bounce animation
    @State private var editButtonScale: CGFloat = 1.0

    // Check if current user owns this post
    private var isOwnPost: Bool {
        let loginState = Storage.shared.getLoginState()
        guard let email = loginState.email else {
            Logger.shared.info("[PostView] No logged in email")
            return false
        }
        guard let authorEmail = post.authorEmail else {
            Logger.shared.info("[PostView] Post \(post.id) has no authorEmail")
            return false
        }
        let matches = authorEmail.lowercased() == email.lowercased()
        Logger.shared.info("[PostView] Post \(post.id) authorEmail: '\(authorEmail)', logged in: '\(email)', matches: \(matches)")
        return matches
    }

    // Linear interpolation helper
    func lerp(_ start: CGFloat, _ end: CGFloat, _ t: CGFloat) -> CGFloat {
        return start + (end - start) * t
    }

    // Calculate image height for layout (uses content width, not full available width)
    func calculatedImageHeight(contentWidth: CGFloat, imageAspectRatio: CGFloat, addImageButtonHeight: CGFloat) -> CGFloat {
        if editableImageUrl != nil {
            return contentWidth / imageAspectRatio
        } else if isEditing {
            return addImageButtonHeight
        } else {
            return 0
        }
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
                heading.font = .system(size: 18 * fontScale, weight: .bold)
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

    // Calculate height of text using UITextView (works reliably)
    func calculateTextHeight(_ text: String, width: CGFloat, font: UIFont) -> CGFloat {
        let textView = UITextView()
        textView.font = font
        textView.text = text
        let size = textView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return size.height
    }

    // Save post changes to server
    func savePost() {
        Logger.shared.info("[PostView] Saving post \(post.id) changes to server")

        // Get logged in user email
        let loginState = Storage.shared.getLoginState()
        guard let userEmail = loginState.email else {
            Logger.shared.error("[PostView] Cannot save: no user logged in")
            return
        }

        // Determine if this is a new post (negative ID) or an update
        let isNewPost = post.id < 0
        let endpoint = isNewPost ? "/api/posts/create" : "/api/posts/update"

        // Build request
        guard let url = URL(string: "\(serverURL)\(endpoint)") else {
            Logger.shared.error("[PostView] Invalid URL")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        // Check if we have a new image to upload
        if let imageData = newImageData {
            // Use multipart form data for image upload
            let boundary = UUID().uuidString
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

            var body = Data()

            // Add form fields
            var fields: [String: String] = [
                "email": userEmail,
                "title": editableTitle,
                "summary": editableSummary.isEmpty ? "No summary" : editableSummary,
                "body": editableBody.isEmpty ? "No content" : editableBody
            ]

            // For updates, include post_id; for new posts, optionally include parent_id and template_name
            if !isNewPost {
                fields["post_id"] = String(post.id)
            }
            if let parentId = post.parentId {
                fields["parent_id"] = String(parentId)
            }
            if isNewPost, let templateName = post.template {
                fields["template_name"] = templateName
            }

            for (key, value) in fields {
                body.append("--\(boundary)\r\n".data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
                body.append("\(value)\r\n".data(using: .utf8)!)
            }

            // Add image file
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"image\"; filename=\"image.jpg\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
            body.append(imageData)
            body.append("\r\n".data(using: .utf8)!)
            body.append("--\(boundary)--\r\n".data(using: .utf8)!)

            request.httpBody = body
            Logger.shared.info("[PostView] Uploading post with new image (\(imageData.count / 1024)KB)")
        } else {
            // Use regular form encoding if no new image
            var formData: [String: String] = [
                "email": userEmail,
                "title": editableTitle,
                "summary": editableSummary.isEmpty ? "No summary" : editableSummary,
                "body": editableBody.isEmpty ? "No content" : editableBody
            ]

            // For updates, include post_id; for new posts, optionally include parent_id and template_name
            if !isNewPost {
                formData["post_id"] = String(post.id)
                // Add image_url field (empty string means removed)
                formData["image_url"] = editableImageUrl ?? ""
            }
            if let parentId = post.parentId {
                formData["parent_id"] = String(parentId)
            }
            if isNewPost, let templateName = post.template {
                formData["template_name"] = templateName
            }

            request.httpBody = formData.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
                .joined(separator: "&")
                .data(using: .utf8)
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            Logger.shared.info("[PostView] \(isNewPost ? "Creating new post" : "Updating post") without image change")
        }

        // Send request
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                Logger.shared.error("[PostView] Save failed: \(error.localizedDescription)")
                return
            }

            if let data = data, let responseStr = String(data: data, encoding: .utf8) {
                Logger.shared.info("[PostView] Save response: \(responseStr)")

                // Check if the response indicates an error
                if let jsonData = responseStr.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                   let status = json["status"] as? String, status == "error" {
                    let message = json["message"] as? String ?? "Unknown error"
                    Logger.shared.error("[PostView] Server error: \(message)")
                    // Don't proceed with save - keep post in edit mode
                    return
                }

                // Parse response to get updated image URL if we uploaded a new image
                if self.newImageData != nil,
                   let jsonData = responseStr.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                   let postData = json["post"] as? [String: Any],
                   let imageUrl = postData["image_url"] as? String {
                    Logger.shared.info("[PostView] Server returned image URL: \(imageUrl)")
                    DispatchQueue.main.async {
                        self.editableImageUrl = imageUrl
                    }
                }
            }

            DispatchQueue.main.async {
                Logger.shared.info("[PostView] Post saved successfully, exiting edit mode")

                // Dismiss keyboard first
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)

                if isNewPost {
                    // For new posts, trigger full refresh to update all views
                    // This ensures parent posts get updated child counts and root lists get new posts
                    Logger.shared.info("[PostView] New post created, triggering full refresh")
                    self.onPostCreated()
                } else {
                    // For updates, just update the local post
                    var updatedPost = self.post
                    updatedPost.title = self.editableTitle
                    updatedPost.summary = self.editableSummary
                    updatedPost.body = self.editableBody
                    updatedPost.imageUrl = self.editableImageUrl
                    self.onPostUpdated?(updatedPost)
                }

                // Clear the new image data and exit edit mode
                self.newImageData = nil
                self.onEndEditing?()
            }
        }.resume()
    }

    private func deletePost() {
        Logger.shared.info("[PostView] Deleting post \(post.id)")

        guard let url = URL(string: "\(serverURL)/api/posts/\(post.id)") else {
            Logger.shared.error("[PostView] Invalid URL for delete")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                Logger.shared.error("[PostView] Delete error: \(error.localizedDescription)")
                return
            }

            DispatchQueue.main.async {
                Logger.shared.info("[PostView] Post \(self.post.id) deleted successfully")
                // Broadcast deletion globally so all views can remove this post
                PostDeletionNotifier.shared.notifyPostDeleted(self.post.id)
                // Call onDelete to remove this view from the interface
                self.onDelete?()
            }
        }.resume()
    }

    // Image display - shows new image or loads from URL
    @ViewBuilder
    private func imageView(width: CGFloat, height: CGFloat, imageUrl: String, zoomable: Bool = false) -> some View {
        Group {
            if imageUrl == "new_image", let displayImage = newImage {
                if zoomable {
                    ZoomableImageView(
                        image: displayImage,
                        size: CGSize(width: width, height: height),
                        cornerRadius: 12 * cornerRoundness,
                        isZooming: $isImageZooming
                    )
                    .frame(width: width, height: height)
                } else {
                    Image(uiImage: displayImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: width, height: height)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 12 * cornerRoundness))
                }
            } else {
                let fullUrl = serverURL + imageUrl
                if zoomable, let uiImage = loadedUIImage {
                    ZoomableImageView(
                        image: uiImage,
                        size: CGSize(width: width, height: height),
                        cornerRadius: 12 * cornerRoundness,
                        isZooming: $isImageZooming
                    )
                    .frame(width: width, height: height)
                } else {
                    AsyncImage(url: URL(string: fullUrl)) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: width, height: height)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 12 * cornerRoundness))
                        case .failure(_), .empty:
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: width, height: height)
                                .clipShape(RoundedRectangle(cornerRadius: 12 * cornerRoundness))
                        @unknown default:
                            EmptyView()
                        }
                    }
                }
            }
        }
    }

    // Add Image Button as a separate view to reduce body complexity
    // Extracted child indicator button (reused in both collapsed and expanded states)
    private var childIndicatorButton: some View {
        // Determine icon based on post state
        let iconName: String = {
            if (post.childCount ?? 0) > 0 || post.template == "query" {
                return "chevron.right"
            } else {
                return "plus"
            }
        }()

        return ZStack {
            Circle()
                .fill(tunables.buttonColor())
                .shadow(color: Color.black.opacity(0.4), radius: 8, x: 0, y: 4)

            Image(systemName: iconName)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.black)
        }
        .onTapGesture {
            handleChildButtonTap()
        }
        .onAppear {
            // Register this post's navigation action for UI automation
            UIAutomationRegistry.shared.register(id: "navigate-to-children-\(post.id)") {
                DispatchQueue.main.async {
                    self.handleChildButtonTap()
                }
            }
        }
    }

    // Handle child button tap with different behavior based on post state
    private func handleChildButtonTap() {
        if post.template == "query" {
            // Query posts: navigate to search results
            if let navigate = onNavigateToQueryResults {
                navigate(post.id, post.title)  // Pass post ID and use title as back label
            }
        } else {
            // All other posts: navigate to children view
            if let navigate = onNavigateToChildren {
                navigate(post.id)
            }
        }
    }

    // Layout constants
    private let thumbnailPadding: CGFloat = 8  // inset from right edge for thumbnail
    private let contentPadding: CGFloat = 18  // left padding for content
    private let compactHeight: CGFloat = 110  // height of compact post view

    private var addImageButton: some View {
        let contentWidth = availableWidth - (2 * contentPadding)
        let addImageButtonHeight: CGFloat = 50
        let buttonX: CGFloat = contentPadding
        let buttonY: CGFloat = 72  // Positioned to sit snugly below title/summary (was 80+3=83)

        return Button(action: {
            Logger.shared.info("[PostView] Add image button tapped")
            showImagePicker = true
        }) {
            HStack {
                Image(systemName: "photo.badge.plus")
                    .font(.system(size: 20))
                Text("add image")
                    .font(.system(size: 16))
            }
            .foregroundColor(.black)
            .frame(width: contentWidth, height: addImageButtonHeight)
            .background(
                RoundedRectangle(cornerRadius: 12 * cornerRoundness)
                    .fill(Color.gray.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12 * cornerRoundness)
                            .stroke(Color.black.opacity(0.3), lineWidth: 2)
                    )
            )
        }
        .offset(x: buttonX, y: buttonY)
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: $selectedImage, sourceType: .photoLibrary)
        }
        .uiAutomationId("add-image-button") {
            Logger.shared.info("[PostView] Add image button tapped (UI automation)")
        }
    }

    func processImage(_ image: UIImage) {
        Logger.shared.info("[PostView] Processing image...")

        // Log both UIImage.size and actual CGImage pixel dimensions
        if let cgImage = image.cgImage {
            Logger.shared.info("[PostView] CGImage pixel dimensions: \(cgImage.width)x\(cgImage.height)")
        }
        Logger.shared.info("[PostView] UIImage.size (accounting for orientation): \(image.size)")
        Logger.shared.info("[PostView] UIImage.imageOrientation: \(image.imageOrientation.rawValue)")

        // Step 1: Reorient image to remove orientation metadata
        let reorientedImage = image.reorientedImage()
        Logger.shared.info("[PostView] Reoriented size: \(reorientedImage.size)")

        // Step 2: Resize to max 1200px on longest edge
        let maxDimension: CGFloat = 1200
        let resizedImage = reorientedImage.resized(maxDimension: maxDimension)
        Logger.shared.info("[PostView] Resized to: \(resizedImage.size)")

        // Step 3: Convert to high-quality JPEG
        guard let imageData = resizedImage.jpegData(compressionQuality: 0.9) else {
            Logger.shared.error("[PostView] Failed to convert image to JPEG")
            return
        }
        Logger.shared.info("[PostView] JPEG size: \(imageData.count / 1024)KB")

        // Store the processed image data - it will be uploaded when user saves
        newImageData = imageData
        newImage = resizedImage

        // Update aspect ratio for layout calculations
        imageAspectRatio = resizedImage.size.width / resizedImage.size.height
        Logger.shared.info("[PostView] New image aspect ratio: \(imageAspectRatio)")

        // Set a marker URL so the display logic knows to show the new image
        editableImageUrl = "new_image"
        Logger.shared.info("[PostView] Image processed and ready for display and upload")
    }

    var body: some View {
        postContent
            .onAppear {
                // Set initial expansion state without doing any heavy work
                expansionFactor = isExpanded ? 1.0 : 0.0
                // Initialize editable content with post content
                editableTitle = post.title
                editableSummary = post.summary
                editableBody = post.body
                editableImageUrl = post.imageUrl
                // Check if author has a profile
                checkAuthorProfile()
            }
            .onChange(of: selectedImage) { oldValue, newValue in
                guard let image = newValue else { return }
                Logger.shared.info("[PostView] Image selected, processing...")
                processImage(image)
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $selectedImage, sourceType: .photoLibrary)
            }
    }

    @ViewBuilder
    private var postContent: some View {
        // Log when body is evaluated with isExpanded = true
        let _ = {
            if isExpanded && expansionFactor == 0.0 {
                Logger.shared.info("[PostView] Body evaluated for post \(post.id): isExpanded=\(isExpanded), expansionFactor=\(expansionFactor) - should trigger animation")
            }
        }()

        // Calculate expanded height based on actual content
        // Use contentWidth for image calculations (image has padding on both sides)
        let contentWidth = availableWidth - (2 * contentPadding)
        let addImageButtonHeight: CGFloat = 50
        let imageHeight = calculatedImageHeight(contentWidth: contentWidth, imageAspectRatio: imageAspectRatio, addImageButtonHeight: addImageButtonHeight)
        let authorHeight: CGFloat = 15  // Approximate height for author line

        // Calculate body text height using UIKit measurement
        // Use editableBody if we're editing, otherwise use post.body
        let bodyText = editableBody.isEmpty ? post.body : editableBody
        let measuredBodyHeight = calculateTextHeight(bodyText, width: contentWidth, font: UIFont.preferredFont(forTextStyle: .body))

        // expandedHeight = titleSummary (80) + spacing (3) + image + spacing (4) + body + spacing (12) + author + bottom padding (28)
        let expandedHeight: CGFloat = 80 + 3 + imageHeight + 4 + measuredBodyHeight + 12 + authorHeight + 28

        let currentHeight = lerp(compactHeight, expandedHeight, expansionFactor)

        let baseBrightness = tunables.getDouble("post-background-brightness", default: 0.9)
        let expandedBrightness = min(baseBrightness * 1.2, 1.0)
        let currentBrightness = lerp(baseBrightness, expandedBrightness, expansionFactor)

        let shadowRadius = lerp(2, 16, expansionFactor)
        let shadowY = lerp(0, 16, expansionFactor)
        let shadowOpacity = lerp(0.2, 0.5, expansionFactor)

        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 12 * cornerRoundness)
                .fill(Color.white.opacity(currentBrightness))
                .frame(height: currentHeight)
                .shadow(color: Color.black.opacity(shadowOpacity), radius: shadowRadius, x: 0, y: shadowY)

            // Title and summary at the top
            VStack(alignment: .leading, spacing: 4) {
                if isEditing {
                    TextField("", text: $editableTitle, prompt: Text(post.titlePlaceholder ?? "Title").foregroundColor(Color.gray.opacity(0.55)))
                        .font(.system(size: 22 * fontScale, weight: .bold))
                        .foregroundColor(.black)
                        .textFieldStyle(.plain)
                        .textInputAutocapitalization(.words)
                        .background(
                            RoundedRectangle(cornerRadius: 8 * cornerRoundness)
                                .fill(Color.gray.opacity(0.2))
                        )
                } else {
                    Text(editableTitle)
                        .font(.system(size: 22 * fontScale, weight: .bold))
                        .foregroundColor(.black)
                        .lineLimit(1)
                }

                if isEditing {
                    TextField("", text: $editableSummary, prompt: Text(post.summaryPlaceholder ?? "Summary").italic().foregroundColor(Color.gray.opacity(0.55)))
                        .font(.system(size: 15 * fontScale))
                        .italic()
                        .foregroundColor(.black.opacity(0.8))
                        .textFieldStyle(.plain)
                        .textInputAutocapitalization(.sentences)
                        .background(
                            RoundedRectangle(cornerRadius: 8 * cornerRoundness)
                                .fill(Color.gray.opacity(0.2))
                        )
                } else {
                    Text(editableSummary)
                        .font(.system(size: 15 * fontScale))
                        .italic()
                        .foregroundColor(.black.opacity(0.8))
                        .lineLimit(2)
                }
            }
            .padding(.leading, 16)  // Increased from 8pt for more text indent
            .padding(.vertical, 8)
            .padding(.trailing, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.trailing, post.imageUrl != nil ? 96 : 0)  // Leave room for thumbnail
            .background(
                ZStack {
                    // Height measurement
                    GeometryReader { geo in
                        Color.clear.preference(key: TitleSummaryHeightKey.self, value: geo.size.height)
                    }
                }
            )
            .onPreferenceChange(TitleSummaryHeightKey.self) { height in
                titleSummaryHeight = height
            }

            // Body text below the image
            if isExpanded {
                // Calculate current image dimensions and position
                let compactImageHeight: CGFloat = 80
                let compactImageY: CGFloat = (110 - 80) / 2 + 8  // Updated for new compact height
                let expandedImageY: CGFloat = 80 + 3  // Hardcoded: 80pt title/summary + 3pt spacing
                // Use imageHeight which already accounts for removed images (0 when editableImageUrl is nil)
                let expandedImageHeight = imageHeight

                let currentImageY = lerp(compactImageY, expandedImageY, expansionFactor)
                let currentImageHeight = lerp(compactImageHeight, expandedImageHeight, expansionFactor)

                // Position text below the current image position
                let bodyY = currentImageY + currentImageHeight + 4  // 4pt spacing
                let currentBodyHeight = lerp(0, measuredBodyHeight, expansionFactor)

                ZStack(alignment: .topLeading) {
                    // Grey background in edit mode
                    if isEditing {
                        RoundedRectangle(cornerRadius: 8 * cornerRoundness)
                            .fill(Color.gray.opacity(0.2))
                    }
                    TextEditor(text: $editableBody)
                        .scrollContentBackground(.hidden)  // Hide default background
                        .foregroundColor(.black)
                        .frame(width: contentWidth, height: measuredBodyHeight, alignment: .top)
                        .scrollDisabled(true)
                        .disabled(!isEditing)  // Only editable when isEditing is true
                        .textInputAutocapitalization(.sentences)
                        .onChange(of: editableBody) { _, newValue in
                            // Log when text changes - height is automatically recalculated by body view
                            let newHeight = calculateTextHeight(newValue, width: contentWidth, font: UIFont.preferredFont(forTextStyle: .body))
                            Logger.shared.info("[PostView] Body text changed, new height: \(newHeight)")
                        }
                        .uiAutomationId("edit-body-text") {
                            // Append test text for automation
                            editableBody += "\n\nThis is additional text added by automation!"
                        }

                    // Placeholder text for body
                    if isEditing && editableBody.isEmpty {
                        Text(post.bodyPlaceholder ?? "Body")
                            .foregroundColor(Color.gray.opacity(0.55))
                            .padding(.leading, 5)
                            .padding(.top, 8)
                    }
                }
                .frame(width: contentWidth, height: measuredBodyHeight)
                .clipped()
                .mask(
                    Rectangle()
                        .frame(height: currentBodyHeight)
                        .frame(maxHeight: .infinity, alignment: .top)
                )
                .offset(x: contentPadding, y: bodyY)
            }

            // Author and date - visible in both compact and expanded views
            // In compact: below title/summary
            // In expanded: below body text
            let compactAuthorY: CGFloat = 80 - 4  // Below title/summary (80pt height - 4pt to move up slightly)

            // Calculate expanded position below body text
            let compactImageHeight: CGFloat = 80
            let compactImageY: CGFloat = (110 - 80) / 2 + 8  // Updated for new compact height
            let expandedImageY: CGFloat = 80 + 3
            let expandedImageHeight = imageHeight
            let currentImageY = lerp(compactImageY, expandedImageY, expansionFactor)
            let currentImageHeight = lerp(compactImageHeight, expandedImageHeight, expansionFactor)
            let bodyY = currentImageY + currentImageHeight + 4
            let expandedAuthorY = bodyY + measuredBodyHeight + 12

            let authorY = lerp(compactAuthorY, expandedAuthorY, expansionFactor)

            HStack {
                // Author name and date on left - aligned with body text
                HStack(spacing: 8) {
                    if post.aiGenerated {
                        Text("👓 librarian")
                            .font(.system(size: 15 * fontScale * tunables.getDouble("author-font-size", default: 1.0)))
                            .foregroundColor(.black.opacity(0.5))
                    } else if let authorName = post.authorName {
                        // Make author name a button only if profile exists
                        let isProfilePost = post.template == "profile"

                        if isProfilePost || !authorHasProfile {
                            // Profile posts or authors without profiles: just display text
                            Text(authorName)
                                .font(.system(size: 15 * fontScale * tunables.getDouble("author-font-size", default: 1.0)))
                                .foregroundColor(.black.opacity(0.5))
                        } else if isExpanded {
                            // Expanded posts with profiles: make it a tappable button with background
                            Button(action: {
                                if let authorEmail = post.authorEmail {
                                    Logger.shared.info("[PostView] Author button tapped: \(authorName) (\(authorEmail))")
                                    fetchAndNavigateToProfile(authorEmail: authorEmail)
                                }
                            }) {
                                Text(authorName)
                                    .font(.system(size: 15 * fontScale * tunables.getDouble("author-font-size", default: 1.0)))
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(tunables.buttonColor())
                                    .clipShape(RoundedRectangle(cornerRadius: 6 * cornerRoundness))
                            }
                        } else {
                            // Compact posts: display as plain text (no background, no tap)
                            Text(authorName)
                                .font(.system(size: 15 * fontScale * tunables.getDouble("author-font-size", default: 1.0)))
                                .foregroundColor(.black.opacity(0.5))
                        }
                    }

                    // Add date with 16pt left padding
                    if let formattedDate = formatPostDate(post.createdAt) {
                        Text(formattedDate)
                            .font(.system(size: 15 * fontScale * tunables.getDouble("author-font-size", default: 1.0)))
                            .foregroundColor(.black.opacity(0.5))
                            .padding(.leading, 16)
                    }
                }
                .padding(.leading, 16)  // Align with body text, moved 2pts left
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .offset(x: 0, y: authorY)

            // Animated image - interpolates from thumbnail to full-size
            // Use editableImageUrl (nil if removed in edit mode)
            // Or show "Add Image" button if editing with no image
            if let imageUrl = editableImageUrl {
                let fullUrl = serverURL + imageUrl

                // Compact state: 80x80 thumbnail on top-right with padding
                let thumbnailSize: CGFloat = 80
                let compactX = availableWidth - thumbnailSize - (2 * thumbnailPadding)  // Right-aligned, inset from right edge
                let compactY: CGFloat = (compactHeight - thumbnailSize) / 2  // Vertically centered in compact post view

                // Expanded state: full-width centered below summary (matching content rectangle)
                let expandedImageWidth = contentWidth
                let expandedImageHeight = contentWidth / imageAspectRatio
                let expandedX: CGFloat = contentPadding  // Aligned with text content indent
                // Match the spacing used in height calculation (not the 8pt in outdated docs)
                let expandedY: CGFloat = 80  // Hardcoded: 80pt title/summary height

                // Interpolated values
                let currentWidth = lerp(thumbnailSize, expandedImageWidth, expansionFactor)
                let currentImageHeight = lerp(thumbnailSize, expandedImageHeight, expansionFactor)
                let currentX = lerp(compactX, expandedX, expansionFactor)
                let currentY = lerp(compactY, expandedY, expansionFactor)

                // Use zoomable image when expanded and not editing
                let useZoomable = isExpanded && !isEditing

                ZStack(alignment: .topTrailing) {
                    imageView(width: currentWidth, height: currentImageHeight, imageUrl: imageUrl, zoomable: useZoomable)
                    .task {
                        // Load aspect ratio and UIImage when image first appears
                        if imageAspectRatio == 1.0 || loadedUIImage == nil {
                            if let url = URL(string: fullUrl) {
                                do {
                                    let (data, _) = try await URLSession.shared.data(from: url)
                                    if let uiImage = UIImage(data: data) {
                                        let aspectRatio = uiImage.size.width / uiImage.size.height
                                        imageAspectRatio = aspectRatio
                                        originalImageAspectRatio = aspectRatio  // Save original
                                        loadedUIImage = uiImage  // Cache for zoomable view
                                    }
                                } catch {
                                    // Failed to load image, keep default aspect ratio
                                }
                            }
                        }
                    }

                    // Image edit buttons (only in edit mode when expanded)
                    if isEditing && isExpanded {
                        HStack(spacing: 20) {
                            // Delete image button
                            Button(action: {
                                Logger.shared.info("[PostView] Remove image button tapped")
                                editableImageUrl = nil
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(Color(red: 1.0, green: 0.5, blue: 0.5))
                                        .frame(width: 32, height: 32)
                                        .shadow(color: Color.black.opacity(0.4), radius: 8, x: 0, y: 4)
                                    Image(systemName: "trash")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.black)
                                }
                            }
                            .uiAutomationId("delete-image-button") {
                                editableImageUrl = nil
                            }

                            // Replace from photo library button
                            Button(action: {
                                Logger.shared.info("[PostView] Replace from photo library button tapped")
                                showImagePicker = true
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(tunables.buttonColor())
                                        .frame(width: 32, height: 32)
                                        .shadow(color: Color.black.opacity(0.4), radius: 8, x: 0, y: 4)
                                    Image(systemName: "photo")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.black)
                                }
                            }
                            .uiAutomationId("replace-photo-library-button") {
                                showImagePicker = true
                            }
                        }
                        .padding(8)
                    }
                }
                .offset(x: currentX, y: currentY)
            } else if isEditing && isExpanded {
                // Show "Add Image" button when editing with no image
                addImageButton
            }

            // Child indicator overlay - show if post has children OR if it's a query (search button) OR if it has no children (anyone can add)
            // Exception: profiles can only have children added by their owner
            // BUT don't show when editing
            let canAddChild = post.template == "profile" ? isOwnPost : true
            if !isEditing && ((post.childCount ?? 0) > 0 || post.template == "query" || ((post.childCount ?? 0) == 0 && canAddChild)) {
                // Interpolate size and position based on expansionFactor
                let collapsedButtonSize: CGFloat = 32
                let expandedButtonSize: CGFloat = 42
                let currentButtonSize = lerp(collapsedButtonSize, expandedButtonSize, expansionFactor)

                // Button center at availableWidth - radius + 4pt offset
                let buttonCenterX = availableWidth - (currentButtonSize / 2) + 4
                let buttonCenterY = currentHeight / 2  // Vertically centered

                childIndicatorButton
                    .frame(width: currentButtonSize, height: currentButtonSize)
                    .offset(x: buttonCenterX - currentButtonSize/2, y: buttonCenterY - currentButtonSize/2)
            }

            // Edit button overlay - positioned in bottom-right corner (only for own posts when expanded, not editing)
            if isOwnPost && isExpanded && !isEditing {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            Logger.shared.info("[PostView] Edit button tapped for post \(post.id)")
                            onStartEditing?()
                        }) {
                            Image(systemName: "pencil")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.black)
                                .frame(width: 36, height: 36)
                                .background(tunables.buttonColor())
                                .clipShape(Circle())
                                .shadow(color: Color.black.opacity(0.4), radius: 8, x: 0, y: 4)
                        }
                        .uiAutomationId("edit-button") {
                            onStartEditing?()
                        }
                        .padding(.trailing, 12)
                        .padding(.bottom, 12)
                    }
                }
                .frame(width: availableWidth, height: currentHeight)
                .opacity(expansionFactor)  // Fade in with expansion
            }

            // Edit action buttons overlay - positioned in bottom right corner (only when editing)
            if isOwnPost && isExpanded && isEditing {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        HStack(spacing: 20) {
                            // Delete button (only for saved posts, never for profiles)
                            if post.id > 0 && post.template != "profile" {
                                Button(action: {
                                    Logger.shared.info("[PostView] Delete post button tapped for post \(post.id)")
                                    showDeleteConfirmation = true
                                }) {
                                    ZStack {
                                        Circle()
                                            .fill(Color(red: 1.0, green: 0.5, blue: 0.5))
                                            .frame(width: 32, height: 32)
                                            .shadow(color: Color.black.opacity(0.4), radius: 8, x: 0, y: 4)
                                        Image(systemName: "trash")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(.black)
                                    }
                                }
                                .uiAutomationId("delete-post-button") {
                                    showDeleteConfirmation = true
                                }
                            }

                            // Undo button
                            Button(action: {
                                if isNewPost {
                                    // New post: delete it (remove from list without server call)
                                    Logger.shared.info("[PostView] Undo button tapped for new post \(post.id) - deleting")
                                    onDelete?()
                                } else {
                                    // Existing post: revert changes only, stay expanded
                                    Logger.shared.info("[PostView] Undo button tapped - reverting changes for post \(post.id)")
                                    // Dismiss keyboard first
                                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                    editableTitle = post.title
                                    editableSummary = post.summary
                                    editableBody = post.body
                                    editableImageUrl = post.imageUrl
                                    newImageData = nil
                                    newImage = nil
                                    imageAspectRatio = originalImageAspectRatio
                                    Logger.shared.info("[PostView] About to call onEndEditing")
                                    // Just exit edit mode without triggering list refresh
                                    onEndEditing?()
                                    Logger.shared.info("[PostView] onEndEditing called")
                                }
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(tunables.buttonColor())
                                        .frame(width: 32, height: 32)
                                        .shadow(color: Color.black.opacity(0.4), radius: 8, x: 0, y: 4)
                                    Image(systemName: "arrow.uturn.backward")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.black)
                                }
                            }
                            .uiAutomationId("cancel-button") {
                                Logger.shared.info("[PostView] ⚡️ cancel-button automation triggered for post \(post.id), isNewPost=\(isNewPost)")
                                if isNewPost {
                                    Logger.shared.info("[PostView] ⚡️ Calling onDelete (new post)")
                                    onDelete?()
                                } else {
                                    Logger.shared.info("[PostView] ⚡️ Reverting changes and calling onEndEditing")
                                    editableTitle = post.title
                                    editableSummary = post.summary
                                    editableBody = post.body
                                    onEndEditing?()
                                    Logger.shared.info("[PostView] ⚡️ onEndEditing completed")
                                }
                            }

                            // Save button
                            Button(action: {
                                savePost()
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(Color(red: 0.5, green: 1.0, blue: 0.5))
                                        .frame(width: 32, height: 32)
                                        .shadow(color: Color.black.opacity(0.4), radius: 8, x: 0, y: 4)
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.black)
                                }
                            }
                            .uiAutomationId("save-button") {
                                savePost()
                            }
                        }
                        .scaleEffect(editButtonScale)
                        .padding(.trailing, 12)
                        .padding(.bottom, 12)
                    }
                }
                .frame(width: availableWidth, height: currentHeight)
                .opacity(expansionFactor)  // Fade in with expansion
            }

        }
        .background(
            // Measure body text only when needed (when expanding)
            // Use TextEditor for accurate measurement of editable content
            Group {
                if isExpanded && !isMeasured {
                    TextEditor(text: .constant(post.body))
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(width: contentWidth)
                        .background(
                            GeometryReader { geo in
                                Color.clear.preference(key: BodyHeightKey.self, value: geo.size.height)
                            }
                        )
                        .onPreferenceChange(BodyHeightKey.self) { height in
                            Logger.shared.info("[PostView] TextEditor body measured height: \(height)")
                            bodyTextHeight = height
                            isMeasured = true
                        }
                        .hidden()
                }
            }
        )
        .overlay(alignment: .topTrailing) {
            if showNotificationBadge {
                Circle()
                    .fill(Color.red)
                    .stroke(Color.white, lineWidth: 2)
                    .frame(width: 12, height: 12)
                    .offset(x: -6, y: 6)
            }
        }
        .onTapGesture {
            // Disable collapse when editing
            if !isEditing {
                onTap()
            }
        }
        .gesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    // Detect left swipe (negative translation)
                    if value.translation.width < -30 && ((post.childCount ?? 0) > 0 || post.template == "query") {
                        // Check if this is a query post
                        if post.template == "query" {
                            onNavigateToQueryResults?(post.id, post.title)  // Pass post ID and title as back label
                        } else {
                            onNavigateToChildren?(post.id)
                        }
                    }
                }
        )
        .onChange(of: isExpanded) { _, newValue in
            Logger.shared.info("[PostView] ⭐️ EXPANSION ANIMATION STARTING - Post \(post.id) isExpanded changed to \(newValue)")
            if newValue {
                // Expanding - calculate and log positions
                let logContentWidth = availableWidth - (2 * contentPadding)
                let logImageHeight = editableImageUrl != nil ? (logContentWidth / imageAspectRatio) : 0
                let logBodyHeight = calculateTextHeight(editableBody, width: logContentWidth, font: UIFont.preferredFont(forTextStyle: .body))

                // Calculate positions when fully expanded using hardcoded title/summary height
                let expandedImageY: CGFloat = 80 + 3  // 80pt title/summary + 12pt spacing
                let expandedBodyY = expandedImageY + logImageHeight + 4  // 4pt spacing
                let expandedAuthorY = expandedBodyY + logBodyHeight + 12  // 12pt spacing

                Logger.shared.info("[PostView] Post \(post.id) EXPANDED POSITIONS (availableWidth=\(availableWidth)):")
                Logger.shared.info("  Title/Summary Height: 80 (hardcoded)")
                Logger.shared.info("  Image Y: \(expandedImageY) (height: \(logImageHeight))")
                Logger.shared.info("  Body Y: \(expandedBodyY) (height: \(logBodyHeight))")
                Logger.shared.info("  Author Y: \(expandedAuthorY)")

                withAnimation(.easeInOut(duration: 0.3)) {
                    expansionFactor = 1.0
                }
            } else {
                // Collapsing - animate immediately
                Logger.shared.info("[PostView] Post \(post.id) collapsing, setting expansionFactor to 0.0")
                withAnimation(.easeInOut(duration: 0.3)) {
                    expansionFactor = 0.0
                }
            }
        }
        .alert("Delete Post", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deletePost()
            }
        } message: {
            Text("Are you sure you want to permanently delete this post?")
        }
        .onChange(of: shouldBounceButtons) { _, shouldBounce in
            if shouldBounce && isEditing {
                // Trigger bounce animation
                withAnimation(.spring(response: 0.15, dampingFraction: 0.3, blendDuration: 0)) {
                    editButtonScale = 1.3
                }
                // Return to normal after a moment
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.5, blendDuration: 0)) {
                        editButtonScale = 1.0
                    }
                }
                // Reset the trigger
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    shouldBounceButtons = false
                }
            }
        }
    }

    // Format date as "day monthname year" (e.g., "15 Oct 2025")
    private func formatPostDate(_ dateString: String) -> String? {
        // Date format from server: "Wed, 15 Oct 2025 14:37:09 GMT"
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        inputFormatter.locale = Locale(identifier: "en_US_POSIX")

        guard let date = inputFormatter.date(from: dateString) else {
            return nil
        }

        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "d MMM yyyy"
        return outputFormatter.string(from: date)
    }

    // Check if the author has a profile (called on appear)
    private func checkAuthorProfile() {
        // Skip check for AI-generated posts or profile posts
        guard !post.aiGenerated, post.template != "profile", let authorEmail = post.authorEmail else {
            return
        }

        Logger.shared.info("[PostView] Checking if author \(authorEmail) has a profile")

        PostsAPI.shared.fetchUserProfile(userId: authorEmail) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let profilePost):
                    // Only consider it a valid profile if it has a non-empty title or summary
                    if let profile = profilePost {
                        let hasContent = !profile.title.isEmpty || !profile.summary.isEmpty
                        self.authorHasProfile = hasContent
                        Logger.shared.info("[PostView] Author \(authorEmail) has profile with content: \(hasContent)")
                    } else {
                        self.authorHasProfile = false
                        Logger.shared.info("[PostView] Author \(authorEmail) has no profile")
                    }
                case .failure(let error):
                    Logger.shared.warning("[PostView] Failed to check profile: \(error.localizedDescription)")
                    self.authorHasProfile = false
                }
            }
        }
    }

    // Fetch author's profile and navigate to it
    private func fetchAndNavigateToProfile(authorEmail: String) {
        Logger.shared.info("[PostView] Fetching profile for \(authorEmail)")

        PostsAPI.shared.fetchUserProfile(userId: authorEmail) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let profilePost):
                    if let profile = profilePost {
                        Logger.shared.info("[PostView] Profile found: \(profile.title), navigating...")
                        // Navigate to profile view with current post title as back label
                        if let navigate = onNavigateToProfile {
                            navigate(post.title, profile)
                        }
                    } else {
                        Logger.shared.warning("[PostView] No profile found for \(authorEmail)")
                    }
                case .failure(let error):
                    Logger.shared.error("[PostView] Failed to fetch profile: \(error.localizedDescription)")
                }
            }
        }
    }
}

// MARK: - UIImage Extensions for Image Processing

extension UIImage {
    /// Reorients the image to remove EXIF orientation metadata
    /// Returns a new image with the pixel data rotated to match the orientation
    func reorientedImage() -> UIImage {
        // Always redraw the image to ensure pixel data matches display orientation
        // UIImage.size already accounts for orientation, so we draw into that size
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        defer { UIGraphicsEndImageContext() }

        draw(in: CGRect(origin: .zero, size: size))

        guard let redrawnImage = UIGraphicsGetImageFromCurrentImageContext() else {
            return self
        }

        return redrawnImage
    }

    /// Legacy orientation-based reorientation (kept for reference but not used)
    func reorientedImageOld() -> UIImage {
        // If image is already in .up orientation, return as-is
        if imageOrientation == .up {
            return self
        }

        // Calculate the transform needed to reorient the image
        var transform = CGAffineTransform.identity

        switch imageOrientation {
        case .down, .downMirrored:
            transform = transform.translatedBy(x: size.width, y: size.height)
            transform = transform.rotated(by: .pi)
        case .left, .leftMirrored:
            transform = transform.translatedBy(x: size.width, y: 0)
            transform = transform.rotated(by: .pi / 2)
        case .right, .rightMirrored:
            transform = transform.translatedBy(x: 0, y: size.height)
            transform = transform.rotated(by: -.pi / 2)
        default:
            break
        }

        switch imageOrientation {
        case .upMirrored, .downMirrored:
            transform = transform.translatedBy(x: size.width, y: 0)
            transform = transform.scaledBy(x: -1, y: 1)
        case .leftMirrored, .rightMirrored:
            transform = transform.translatedBy(x: size.height, y: 0)
            transform = transform.scaledBy(x: -1, y: 1)
        default:
            break
        }

        // Create a context and apply the transform
        guard let cgImage = self.cgImage,
              let colorSpace = cgImage.colorSpace,
              let context = CGContext(
                data: nil,
                width: Int(size.width),
                height: Int(size.height),
                bitsPerComponent: cgImage.bitsPerComponent,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: cgImage.bitmapInfo.rawValue
              ) else {
            return self
        }

        context.concatenate(transform)

        // Draw the image
        switch imageOrientation {
        case .left, .leftMirrored, .right, .rightMirrored:
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: size.height, height: size.width))
        default:
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        }

        // Create new image from context
        guard let newCGImage = context.makeImage() else {
            return self
        }

        return UIImage(cgImage: newCGImage)
    }

    /// Resizes the image so the longest edge is at most maxDimension pixels
    /// Maintains aspect ratio
    func resized(maxDimension: CGFloat) -> UIImage {
        let currentMaxDimension = max(size.width, size.height)

        // If image is already smaller than max, return as-is
        if currentMaxDimension <= maxDimension {
            return self
        }

        // Calculate new size maintaining aspect ratio
        let scale = maxDimension / currentMaxDimension
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        // Create a graphics context and draw the resized image
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        defer { UIGraphicsEndImageContext() }

        draw(in: CGRect(origin: .zero, size: newSize))

        guard let resizedImage = UIGraphicsGetImageFromCurrentImageContext() else {
            return self
        }

        return resizedImage
    }
}

// MARK: - ImagePicker

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    let sourceType: UIImagePickerController.SourceType
    @Environment(\.dismiss) var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let uiImage = info[.originalImage] as? UIImage {
                parent.image = uiImage
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
