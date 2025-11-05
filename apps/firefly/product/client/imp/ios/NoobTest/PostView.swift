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
    var isEditing: Bool = false  // Passed from parent to control edit state
    let onTap: () -> Void
    let onPostCreated: () -> Void
    let onNavigateToChildren: ((Int) -> Void)?
    let onPostUpdated: ((Post) -> Void)?
    let onStartEditing: (() -> Void)?  // Called when entering edit mode
    let onEndEditing: (() -> Void)?  // Called when exiting edit mode
    let onDelete: (() -> Void)?  // Called when deleting unsaved post (nil for saved posts)
    let serverURL = "http://185.96.221.52:8080"

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
    @State private var showImageSourcePicker: Bool = false
    @State private var showImagePicker: Bool = false
    @State private var imageSourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var selectedImage: UIImage? = nil
    @State private var newImageData: Data? = nil  // Processed image data ready for upload
    @State private var newImage: UIImage? = nil  // Processed image for display

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

    // Calculate image height for layout
    func calculatedImageHeight(availableWidth: CGFloat, imageAspectRatio: CGFloat, addImageButtonHeight: CGFloat) -> CGFloat {
        if editableImageUrl != nil {
            return availableWidth / imageAspectRatio
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

            // For updates, include post_id; for new posts, optionally include parent_id
            if !isNewPost {
                fields["post_id"] = String(post.id)
            }
            if let parentId = post.parentId {
                fields["parent_id"] = String(parentId)
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

            // For updates, include post_id; for new posts, optionally include parent_id
            if !isNewPost {
                formData["post_id"] = String(post.id)
                // Add image_url field (empty string means removed)
                formData["image_url"] = editableImageUrl ?? ""
            }
            if let parentId = post.parentId {
                formData["parent_id"] = String(parentId)
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

                if isNewPost {
                    // For new posts, parse the response to get the real post ID
                    if let data = data,
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let postData = json["post"] as? [String: Any],
                       let newPostId = postData["id"] as? Int {
                        Logger.shared.info("[PostView] New post created with ID: \(newPostId)")

                        // Create updated post with real ID from server
                        var updatedPost = self.post
                        updatedPost.id = newPostId
                        updatedPost.title = self.editableTitle
                        updatedPost.summary = self.editableSummary
                        updatedPost.body = self.editableBody
                        updatedPost.imageUrl = self.editableImageUrl

                        // Update the post in place (replaces temp post with real one)
                        self.onPostUpdated?(updatedPost)
                    } else {
                        Logger.shared.error("[PostView] Failed to parse new post ID from response")
                        // Fall back to refresh if parsing fails
                        self.onPostCreated()
                    }
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

    // Image display - shows new image or loads from URL
    @ViewBuilder
    private func imageView(width: CGFloat, height: CGFloat, imageUrl: String) -> some View {
        if imageUrl == "new_image", let displayImage = newImage {
            Image(uiImage: displayImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: width, height: height)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 12))
        } else {
            let fullUrl = serverURL + imageUrl
            AsyncImage(url: URL(string: fullUrl)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: width, height: height)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                case .failure(_), .empty:
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: width, height: height)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                @unknown default:
                    EmptyView()
                }
            }
        }
    }

    // Add Image Button as a separate view to reduce body complexity
    private var addImageButton: some View {
        let availableWidth: CGFloat = 350
        let addImageButtonHeight: CGFloat = 50
        let buttonX: CGFloat = 18
        let buttonY: CGFloat = 80 + 12

        return Button(action: {
            Logger.shared.info("[PostView] Add image button tapped")
            showImageSourcePicker = true
        }) {
            HStack {
                Image(systemName: "photo.badge.plus")
                    .font(.system(size: 20))
                Text("Add Image")
                    .font(.system(size: 16))
            }
            .foregroundColor(.black)
            .frame(width: availableWidth, height: addImageButtonHeight)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.black.opacity(0.3), lineWidth: 2)
                    )
            )
        }
        .offset(x: buttonX, y: buttonY)
        .confirmationDialog("Add Image", isPresented: $showImageSourcePicker) {
            Button("Take Photo") {
                imageSourceType = .camera
                showImagePicker = true
            }
            Button("Choose from Library") {
                imageSourceType = .photoLibrary
                showImagePicker = true
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: $selectedImage, sourceType: imageSourceType)
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
            }
            .onChange(of: selectedImage) { oldValue, newValue in
                guard let image = newValue else { return }
                Logger.shared.info("[PostView] Image selected, processing...")

                // Process image - it will be uploaded when user saves
                processImage(image)
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $selectedImage, sourceType: imageSourceType)
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

        let compactHeight: CGFloat = 100

        // Calculate expanded height based on actual content
        let availableWidth: CGFloat = 350  // Approximate - account for padding
        let addImageButtonHeight: CGFloat = 50
        let imageHeight = calculatedImageHeight(availableWidth: availableWidth, imageAspectRatio: imageAspectRatio, addImageButtonHeight: addImageButtonHeight)
        let authorHeight: CGFloat = 15  // Approximate height for author line

        // Calculate body text height using UIKit measurement
        // Use editableBody if we're editing, otherwise use post.body
        let bodyText = editableBody.isEmpty ? post.body : editableBody
        let measuredBodyHeight = calculateTextHeight(bodyText, width: availableWidth, font: UIFont.preferredFont(forTextStyle: .body))

        // expandedHeight = titleSummary (80) + spacing (12) + image + spacing (4) + body + spacing (12) + author + bottom padding (28)
        let expandedHeight: CGFloat = 80 + 12 + imageHeight + 4 + measuredBodyHeight + 12 + authorHeight + 28

        let currentHeight = lerp(compactHeight, expandedHeight, expansionFactor)

        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.9))
                .frame(height: currentHeight)
                .shadow(radius: 2)

            // Title and summary at the top
            VStack(alignment: .leading, spacing: 4) {
                if isEditing {
                    TextField("", text: $editableTitle, prompt: Text(post.titlePlaceholder ?? "Title").foregroundColor(Color.gray.opacity(0.55)))
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.black)
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled(true)
                        .textInputAutocapitalization(.never)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.2))
                        )
                } else {
                    Text(editableTitle)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.black)
                        .lineLimit(1)
                }

                if isEditing {
                    TextField("", text: $editableSummary, prompt: Text(post.summaryPlaceholder ?? "Summary").italic().foregroundColor(Color.gray.opacity(0.55)))
                        .font(.system(size: 15))
                        .italic()
                        .foregroundColor(.black.opacity(0.8))
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled(true)
                        .textInputAutocapitalization(.never)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.2))
                        )
                } else {
                    Text(editableSummary)
                        .font(.system(size: 15))
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
                let compactImageY: CGFloat = (100 - 80) / 2 + 8
                let expandedImageY: CGFloat = 80 + 12  // Hardcoded: 80pt title/summary + 12pt spacing (was 16)
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
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.2))
                    }
                    TextEditor(text: $editableBody)
                        .scrollContentBackground(.hidden)  // Hide default background
                        .foregroundColor(.black)
                        .frame(width: availableWidth, height: measuredBodyHeight, alignment: .top)
                        .scrollDisabled(true)
                        .disabled(!isEditing)  // Only editable when isEditing is true
                        .autocorrectionDisabled(true)  // Disable autocorrection
                        .textInputAutocapitalization(.never)  // Disable auto-capitalization
                        .onChange(of: editableBody) { _, newValue in
                            // Log when text changes - height is automatically recalculated by body view
                            let newHeight = calculateTextHeight(newValue, width: availableWidth, font: UIFont.preferredFont(forTextStyle: .body))
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
                .frame(width: availableWidth, height: measuredBodyHeight)
                .clipped()
                .mask(
                    Rectangle()
                        .frame(height: currentBodyHeight)
                        .frame(maxHeight: .infinity, alignment: .top)
                )
                .offset(x: 18, y: bodyY)
            }

            // Author - fades in when expanded
            if isExpanded {
                // Calculate position below body text
                let compactImageHeight: CGFloat = 80
                let compactImageY: CGFloat = (100 - 80) / 2 + 8
                let expandedImageY: CGFloat = 80 + 12  // Same as body text calculation
                // Use imageHeight which already accounts for removed images (0 when editableImageUrl is nil)
                let expandedImageHeight = imageHeight

                let currentImageY = lerp(compactImageY, expandedImageY, expansionFactor)
                let currentImageHeight = lerp(compactImageHeight, expandedImageHeight, expansionFactor)

                // Position author below body text: bodyY + bodyHeight + padding
                let bodyY = currentImageY + currentImageHeight + 4  // Same as body text Y
                let authorY = bodyY + measuredBodyHeight + 12  // Below body text with 12pt spacing (was 16pt, 24pt originally)

                HStack {
                    // Author name on left - aligned with body text
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
                    .padding(.leading, 24)  // 18pt + 6pt = 24pt

                    Spacer()

                    // Edit/save/cancel buttons on right (only for own posts)
                    if isOwnPost {
                        HStack(spacing: 8) {
                            if !isEditing {
                                // Edit mode: single pencil button
                                Button(action: {
                                    Logger.shared.info("[PostView] Edit button tapped for post \(post.id)")
                                    onStartEditing?()
                                }) {
                                    Image(systemName: "pencil.circle.fill")
                                        .font(.system(size: 32))
                                        .foregroundColor(.black.opacity(0.6))
                                }
                                .uiAutomationId("edit-button") {
                                    onStartEditing?()
                                }
                            } else {
                                // Editing mode: undo and tick buttons
                                Button(action: {
                                    if let onDelete = onDelete {
                                        // New post: delete it
                                        Logger.shared.info("[PostView] Delete button tapped for new post \(post.id)")
                                        onDelete()
                                    } else {
                                        // Existing post: revert changes
                                        Logger.shared.info("[PostView] Cancel button tapped - reverting changes")
                                        editableTitle = post.title
                                        editableSummary = post.summary
                                        editableBody = post.body
                                        editableImageUrl = post.imageUrl
                                        newImageData = nil
                                        newImage = nil
                                        imageAspectRatio = originalImageAspectRatio
                                        onEndEditing?()
                                    }
                                }) {
                                    Image(systemName: "arrow.uturn.backward.circle.fill")
                                        .font(.system(size: 32))
                                        .foregroundColor(.red.opacity(0.6))
                                }
                                .uiAutomationId("cancel-button") {
                                    if let onDelete = onDelete {
                                        onDelete()
                                    } else {
                                        editableTitle = post.title
                                        editableSummary = post.summary
                                        editableBody = post.body
                                        onEndEditing?()
                                    }
                                }

                                Button(action: {
                                    savePost()
                                }) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 32))
                                        .foregroundColor(.green.opacity(0.6))
                                }
                                .uiAutomationId("save-button") {
                                    savePost()
                                }
                            }
                        }
                        .padding(.trailing, 18)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .offset(x: 0, y: authorY)
                .opacity(expansionFactor)  // Fade in with expansion
            }

            // Animated image - interpolates from thumbnail to full-size
            // Use editableImageUrl (nil if removed in edit mode)
            // Or show "Add Image" button if editing with no image
            if let imageUrl = editableImageUrl {
                let fullUrl = serverURL + imageUrl

                // Compact state: 80x80 thumbnail on top-right with padding
                let thumbnailSize: CGFloat = 80
                let compactX = availableWidth - 80 + 20  // Right-aligned, moved right by 12pt for reduced list padding
                let compactY: CGFloat = (100 - thumbnailSize) / 2  // Vertically centered in 100px compact post view

                // Expanded state: full-width centered below summary (matching content rectangle)
                let expandedWidth = availableWidth
                let expandedHeight = availableWidth / imageAspectRatio
                let expandedX: CGFloat = 18  // Increased from 10pt to align with text indent
                // Match the spacing used in height calculation (not the 8pt in outdated docs)
                let expandedY: CGFloat = 80  // Hardcoded: 80pt title/summary height

                // Interpolated values
                let currentWidth = lerp(thumbnailSize, expandedWidth, expansionFactor)
                let currentHeight = lerp(thumbnailSize, expandedHeight, expansionFactor)
                let currentX = lerp(compactX, expandedX, expansionFactor)
                let currentY = lerp(compactY, expandedY, expansionFactor)

                ZStack(alignment: .topTrailing) {
                    imageView(width: currentWidth, height: currentHeight, imageUrl: imageUrl)
                    .task {
                        // Load aspect ratio when image first appears
                        if imageAspectRatio == 1.0 {
                            if let url = URL(string: fullUrl) {
                                do {
                                    let (data, _) = try await URLSession.shared.data(from: url)
                                    if let uiImage = UIImage(data: data) {
                                        let aspectRatio = uiImage.size.width / uiImage.size.height
                                        imageAspectRatio = aspectRatio
                                        originalImageAspectRatio = aspectRatio  // Save original
                                    }
                                } catch {
                                    // Failed to load image, keep default aspect ratio
                                }
                            }
                        }
                    }

                    // Image edit buttons (only in edit mode when expanded)
                    if isEditing && isExpanded {
                        HStack(spacing: 8) {
                            // Delete image button
                            Button(action: {
                                Logger.shared.info("[PostView] Remove image button tapped")
                                editableImageUrl = nil
                            }) {
                                Image(systemName: "trash.circle.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(.red.opacity(0.8))
                                    .background(Circle().fill(Color.white))
                            }
                            .uiAutomationId("delete-image-button") {
                                editableImageUrl = nil
                            }

                            // Replace from photo library button
                            Button(action: {
                                Logger.shared.info("[PostView] Replace from photo library button tapped")
                                imageSourceType = .photoLibrary
                                showImagePicker = true
                            }) {
                                Image(systemName: "photo.circle.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(.blue.opacity(0.8))
                                    .background(Circle().fill(Color.white))
                            }
                            .uiAutomationId("replace-photo-library-button") {
                                imageSourceType = .photoLibrary
                                showImagePicker = true
                            }

                            // Take new photo with camera button
                            Button(action: {
                                Logger.shared.info("[PostView] Take new photo button tapped")
                                imageSourceType = .camera
                                showImagePicker = true
                            }) {
                                Image(systemName: "camera.circle.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(.green.opacity(0.8))
                                    .background(Circle().fill(Color.white))
                            }
                            .uiAutomationId("replace-camera-button") {
                                imageSourceType = .camera
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

            // Child indicator overlay (right arrow in opaque circle)
            // Position at the right edge of the card, drawn AFTER image so it appears on top
            if (post.childCount ?? 0) > 0 {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        ZStack {
                            Circle()
                                .fill(Color(red: 128/255, green: 128/255, blue: 128/255).opacity(0.8))
                                .frame(width: 42, height: 42)

                            Image(systemName: "chevron.right")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(Color.white)
                        }
                        .padding(.trailing, -10)  // Position straddling the right edge
                        .onTapGesture {
                            if let navigate = onNavigateToChildren {
                                navigate(post.id)
                            }
                        }
                        .onAppear {
                            // Register this post's navigation action
                            UIAutomationRegistry.shared.register(id: "navigate-to-children-\(post.id)") {
                                if let navigate = onNavigateToChildren {
                                    DispatchQueue.main.async {
                                        navigate(post.id)
                                    }
                                }
                            }
                        }
                    }
                    Spacer()
                }
                .frame(height: currentHeight)
            }

        }
        .background(
            // Measure body text only when needed (when expanding)
            // Use TextEditor for accurate measurement of editable content
            Group {
                if isExpanded && !isMeasured {
                    TextEditor(text: .constant(post.body))
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(width: 350)
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
                    if value.translation.width < -30 && (post.childCount ?? 0) > 0 {
                        onNavigateToChildren?(post.id)
                    }
                }
        )
        .onChange(of: isExpanded) { _, newValue in
            Logger.shared.info("[PostView] ⭐️ EXPANSION ANIMATION STARTING - Post \(post.id) isExpanded changed to \(newValue)")
            if newValue {
                // Expanding - calculate and log positions
                let availableWidth: CGFloat = 350
                let imageHeight = editableImageUrl != nil ? (availableWidth / imageAspectRatio) : 0
                let measuredBodyHeight = calculateTextHeight(editableBody, width: availableWidth, font: UIFont.preferredFont(forTextStyle: .body))

                // Calculate positions when fully expanded using hardcoded title/summary height
                let expandedImageY: CGFloat = 80 + 12  // 80pt title/summary + 12pt spacing
                let expandedBodyY = expandedImageY + imageHeight + 4  // 4pt spacing
                let expandedAuthorY = expandedBodyY + measuredBodyHeight + 12  // 12pt spacing (was 16pt, 24pt originally)

                Logger.shared.info("[PostView] Post \(post.id) EXPANDED POSITIONS:")
                Logger.shared.info("  Title/Summary Height: 80 (hardcoded)")
                Logger.shared.info("  Image Y: \(expandedImageY) (height: \(imageHeight))")
                Logger.shared.info("  Body Y: \(expandedBodyY) (height: \(measuredBodyHeight))")
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
