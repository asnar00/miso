# edit-posts iOS implementation

## Files Modified

- `NoobTest/Post.swift` - Made title, summary, body mutable (var instead of let); added optional placeholder fields from templates
- `NoobTest/PostView.swift` - Main post view with edit functionality for all three fields; custom placeholder support
- `NoobTest/PostsListView.swift` - Added onPostUpdated callback handler
- `NoobTest/ChildPostsView.swift` - Added onPostUpdated callback handler
- `NoobTest/UIAutomationRegistry.swift` - Added .uiAutomationId() modifier
- `reproduce.sh` - Simplified automated testing script
- `server/imp/py/db.py` - Added LEFT JOIN templates to all SELECT queries
- `server/imp/py/create_templates.py` - Database migration script for templates system
- `server/imp/py/grant_template_permissions.py` - Grant SELECT on templates to firefly_user

## Post.swift - Mutable Fields and Placeholders

```swift
struct Post: Codable, Identifiable, Hashable {
    let id: Int
    let userId: Int
    let parentId: Int?
    var title: String      // Changed from let to var
    var summary: String    // Changed from let to var
    var body: String       // Changed from let to var
    var imageUrl: String?  // Changed from let to var
    let createdAt: String
    let timezone: String
    let locationTag: String?
    let aiGenerated: Bool
    let authorName: String?
    let authorEmail: String?
    let childCount: Int?
    let titlePlaceholder: String?    // From templates.placeholder_title via JOIN
    let summaryPlaceholder: String?  // From templates.placeholder_summary via JOIN
    let bodyPlaceholder: String?     // From templates.placeholder_body via JOIN

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case parentId = "parent_id"
        case title
        case summary
        case body
        case imageUrl = "image_url"
        case createdAt = "created_at"
        case timezone
        case locationTag = "location_tag"
        case aiGenerated = "ai_generated"
        case authorName = "author_name"
        case authorEmail = "author_email"
        case childCount = "child_count"
        case titlePlaceholder = "placeholder_title"     // Note: snake_case from API
        case summaryPlaceholder = "placeholder_summary"
        case bodyPlaceholder = "placeholder_body"
    }
}
```

## PostView.swift Implementation

### State Variables

```swift
@State private var isEditing: Bool = false
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
@State private var originalImageAspectRatio: CGFloat = 1.0  // Save original for cancel
@State private var imageAspectRatio: CGFloat = 1.0  // Current display aspect ratio
```

### Callback

```swift
let onPostUpdated: ((Post) -> Void)?
```

### Owner Check

```swift
private var isOwnPost: Bool {
    let loginState = Storage.shared.getLoginState()
    guard let email = loginState.email else { return false }
    guard let authorEmail = post.authorEmail else { return false }
    return authorEmail.lowercased() == email.lowercased()
}
```

### Text Height Calculation

```swift
func calculateTextHeight(_ text: String, width: CGFloat, font: UIFont) -> CGFloat {
    let textView = UITextView()
    textView.font = font
    textView.text = text
    let size = textView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
    return size.height
}
```

### Dynamic Height in Body

```swift
var body: some View {
    let availableWidth: CGFloat = 350
    // Use editableImageUrl to determine if image should be shown
    let imageHeight = editableImageUrl != nil ? (availableWidth / imageAspectRatio) : 0
    let authorHeight: CGFloat = 15

    // Use editableBody for measurement (may contain unsaved edits)
    let bodyText = editableBody.isEmpty ? post.body : editableBody
    let measuredBodyHeight = calculateTextHeight(bodyText, width: availableWidth,
                                                  font: UIFont.preferredFont(forTextStyle: .body))

    // expandedHeight = titleSummary (80) + spacing (12) + image + spacing (4) + body + spacing (12) + author + bottom padding (28)
    let expandedHeight: CGFloat = 80 + 12 + imageHeight + 4 + measuredBodyHeight + 12 + authorHeight + 28

    // ... rest of view
}
```

### Title and Summary Fields

```swift
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
.padding(.leading, 16)
.padding(.vertical, 8)
.padding(.trailing, 8)
.frame(maxWidth: .infinity, alignment: .leading)
.padding(.trailing, post.imageUrl != nil ? 96 : 0)
```

### Body Text Editor

```swift
// Position text below the current image position
let bodyY = currentImageY + currentImageHeight + 4  // 4pt spacing

ZStack(alignment: .topLeading) {
    // Grey background in edit mode
    if isEditing {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.gray.opacity(0.2))
    }

    TextEditor(text: $editableBody)
        .scrollContentBackground(.hidden)
        .foregroundColor(.black)
        .frame(width: availableWidth, height: measuredBodyHeight, alignment: .top)
        .scrollDisabled(true)
        .disabled(!isEditing)  // Only editable when in edit mode
        .autocorrectionDisabled(true)  // No spell-check red lines
        .textInputAutocapitalization(.never)  // No auto-caps
        .onChange(of: editableBody) { _, newValue in
            let newHeight = calculateTextHeight(newValue, width: availableWidth,
                                                font: UIFont.preferredFont(forTextStyle: .body))
            Logger.shared.info("[PostView] Body text changed, new height: \(newHeight)")
        }
        .uiAutomationId("edit-body-text") {
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
```

### Image Display with Edit Buttons

```swift
// Display image if we have one
if let imageUrl = editableImageUrl {
    let imageWidth = availableWidth
    let imageHeight = imageWidth / imageAspectRatio
    let imageX: CGFloat = 18
    let imageY: CGFloat = 80 + 12

    ZStack(alignment: .topTrailing) {
        // Image display
        imageView(width: imageWidth, height: imageHeight, imageUrl: imageUrl)
            .offset(x: imageX, y: imageY)

        // Image edit buttons (only in edit mode)
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
}
```

### Image Display Function

```swift
@ViewBuilder
private func imageView(width: CGFloat, height: CGFloat, imageUrl: String) -> some View {
    if imageUrl == "new_image", let displayImage = newImage {
        // Display newly selected image from memory
        Image(uiImage: displayImage)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: width, height: height)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 12))
    } else {
        // Display image from server
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
    }
}
```

### Add Image Button

```swift
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
        .foregroundColor(.black)  // Black text instead of blue
        .frame(width: availableWidth, height: addImageButtonHeight)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.black.opacity(0.3), lineWidth: 2)  // Black outline
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
    .onChange(of: selectedImage) { oldValue, newValue in
        if let image = newValue {
            processImage(image)
            selectedImage = nil  // Reset for next selection
        }
    }
}
```

### Image Processing Function

```swift
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
```

### UIImage Extensions

```swift
extension UIImage {
    /// Reorients the image to remove EXIF orientation metadata
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

    /// Resizes the image so the longest edge is at most maxDimension pixels
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
```

### Edit Buttons in Author Bar

```swift
// Position author below body text: bodyY + bodyHeight + padding
let bodyY = currentImageY + currentImageHeight + 4
let authorY = bodyY + measuredBodyHeight + 12  // 12pt spacing

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
    .padding(.leading, 24)  // Align with body text left edge + 6pt

    Spacer()

    // Edit/save/cancel buttons on right (only for own posts)
    if isOwnPost {
        HStack(spacing: 8) {
            if !isEditing {
                // Not editing: single pencil button
                Button(action: {
                    Logger.shared.info("[PostView] Edit button tapped for post \(post.id)")
                    isEditing = true
                }) {
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.black.opacity(0.6))
                }
                .uiAutomationId("edit-button") {
                    isEditing = true
                }
            } else {
                // Editing: Undo arrow and checkmark buttons
                Button(action: {
                    Logger.shared.info("[PostView] Cancel button tapped - reverting changes")
                    editableTitle = post.title
                    editableSummary = post.summary
                    editableBody = post.body
                    editableImageUrl = post.imageUrl
                    newImageData = nil
                    newImage = nil
                    // Restore original aspect ratio
                    imageAspectRatio = originalImageAspectRatio
                    isEditing = false
                }) {
                    Image(systemName: "arrow.uturn.backward.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.red.opacity(0.6))
                }
                .uiAutomationId("cancel-button") {
                    editableTitle = post.title
                    editableSummary = post.summary
                    editableBody = post.body
                    isEditing = false
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
.opacity(expansionFactor)
```

### Save Function

```swift
func savePost() {
    Logger.shared.info("[PostView] Saving post \(post.id) changes to server")

    // Get logged in user email
    let loginState = Storage.shared.getLoginState()
    guard let userEmail = loginState.email else {
        Logger.shared.error("[PostView] Cannot save: no user logged in")
        return
    }

    // Build request
    guard let url = URL(string: "\(serverURL)/api/posts/update") else {
        Logger.shared.error("[PostView] Invalid URL")
        return
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"

    // Check if we have a new image to upload
    if let imageData = newImageData {
        Logger.shared.info("[PostView] Uploading new image with post update")

        // Use multipart form data for image upload
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        // Add form fields
        let fields = [
            "post_id": String(post.id),
            "email": userEmail,
            "title": editableTitle,
            "summary": editableSummary,
            "body": editableBody
        ]

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
    } else {
        // Use regular form encoding if no new image
        let formData = [
            "post_id": String(post.id),
            "email": userEmail,
            "title": editableTitle,
            "summary": editableSummary,
            "body": editableBody
        ]

        request.httpBody = formData.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
            .joined(separator: "&")
            .data(using: .utf8)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
    }

    // Send request
    URLSession.shared.dataTask(with: request) { data, response, error in
        if let error = error {
            Logger.shared.error("[PostView] Save failed: \(error.localizedDescription)")
            return
        }

        if let data = data, let responseStr = String(data: data, encoding: .utf8) {
            Logger.shared.info("[PostView] Save response: \(responseStr)")
        }

        DispatchQueue.main.async {
            Logger.shared.info("[PostView] Post saved successfully, exiting edit mode")

            // Create updated post with new values
            var updatedPost = post
            updatedPost.title = editableTitle
            updatedPost.summary = editableSummary
            updatedPost.body = editableBody

            // Update image URL based on what happened
            if editableImageUrl == nil {
                updatedPost.imageUrl = nil  // Image was deleted
            } else if editableImageUrl == "new_image" {
                // New image was uploaded - parse response to get new URL
                // For now, keep processing the response from server
                // The server returns the full post with updated imageUrl
            }

            // Clear temporary image state
            newImageData = nil
            newImage = nil
            originalImageAspectRatio = imageAspectRatio  // Save current as new baseline

            // Notify parent of the update
            onPostUpdated?(updatedPost)

            isEditing = false
        }
    }.resume()
}
```

### Initialize State and Sheet Presentation

```swift
.onAppear {
    expansionFactor = isExpanded ? 1.0 : 0.0
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
```

## PostsListView.swift - Update Handler

```swift
PostView(
    post: post,
    isExpanded: viewModel.expandedPostId == post.id,
    onTap: {
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
        navigationPath.append(postId)
    },
    onPostUpdated: { updatedPost in
        if let index = posts.firstIndex(where: { $0.id == updatedPost.id }) {
            posts[index] = updatedPost
        }
    }
)
```

## ChildPostsView.swift - Update Handler

```swift
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
    onPostCreated: {
        fetchChildPosts()
        onPostCreated()
    },
    onNavigateToChildren: { postId in
        navigationPath.append(postId)
    },
    onPostUpdated: { updatedPost in
        if let index = posts.firstIndex(where: { $0.id == updatedPost.id }) {
            posts[index] = updatedPost
        }
    }
)
```

## UIAutomationRegistry.swift - View Modifier

```swift
// SwiftUI view modifier to make any view UI-automatable
struct UIAutomationModifier: ViewModifier {
    let id: String
    let action: () -> Void

    func body(content: Content) -> some View {
        content.onAppear {
            UIAutomationRegistry.shared.register(id: id, action: action)
        }
    }
}

extension View {
    func uiAutomationId(_ id: String, action: @escaping () -> Void) -> some View {
        self.modifier(UIAutomationModifier(id: id, action: action))
    }
}
```

**Usage Pattern:**
```swift
Button(action: { /* normal action */ }) { /* content */ }
.uiAutomationId("button-name") {
    // Automation action (usually same as button action)
}
```

## reproduce.sh - Automated Testing

```bash
#!/bin/bash

set -e

echo "🔄 Running reproduce script..."

# Install and launch the app
./install-device.sh

# Wait for app to start and load posts
echo "⏳ Waiting for app to start and load posts..."
sleep 5

# Tap the first post using UI automation
echo "👆 Tapping first post..."
RESPONSE=$(curl -s -X POST "http://localhost:8081/test/tap?id=first-post")
echo "   Response: $RESPONSE"

# Wait for expansion animation
sleep 2

echo "✅ Test sequence complete!"
echo ""
echo "📋 To view logs:"
echo "   ./get-logs.sh"
```

## Key Measurements

- **Title/Summary height:** 80pt (hardcoded - TextFields don't measure reliably)
- **Available width for text:** 350pt
- **Spacing below title/summary:** 12pt
- **Spacing below image (above body):** 4pt
- **Spacing below body text:** 12pt
- **Bottom padding below author:** 28pt
- **Author name left indent:** 24pt (18pt base + 6pt adjustment)
- **Button size:** 32pt
- **Button spacing:** 8pt between buttons (in image edit buttons HStack)
- **Button trailing padding:** 18pt (author bar edit buttons)
- **Image edit buttons padding:** 8pt (entire button group)
- **Grey background opacity:** 0.1 (10%)
- **Corner radius:** 8pt for text fields, 12pt for images and Add Image button
- **Add Image button:** 350pt wide, 50pt tall
- **Image processing:** Max 1200px on longest edge, JPEG quality 0.9
- **Image edit button colors:** Red (trash), Blue (photo library), Green (camera)

## Layout Formula

```
imageY = 80 + 12
bodyY = imageY + imageHeight + 4
authorY = bodyY + bodyTextHeight + 12

expandedHeight = 80 + 12 + imageHeight + 4 + bodyTextHeight + 12 + 15 + 28
```

## Server API Endpoint

**URL:** `http://185.96.221.52:8080/api/posts/update`

**Method:** POST

**Content-Type:**
- `application/x-www-form-urlencoded` (text-only updates)
- `multipart/form-data` (when uploading image)

**Request Parameters:**
- `post_id`: integer (required)
- `email`: string (required) - for authentication
- `title`: string (required)
- `summary`: string (required)
- `body`: string (required)
- `image`: file (optional) - JPEG image, processed client-side

**Response:**
```json
{
    "status": "success",
    "post": {
        "id": 22,
        "title": "Updated Title",
        "summary": "Updated Summary",
        "body": "Updated Body...",
        "author_email": "test@example.com",
        "author_name": "asnaroo",
        ...
    }
}
```

## Testing

### Prerequisites

1. Port forwarding active: `pymobiledevice3 usbmux forward 8081 8081 &`
2. App running on device
3. User logged in as owner of a post

### Manual Testing

1. Expand a post you own → pencil button appears in author bar
2. Tap pencil button → all three fields become editable with grey backgrounds
3. Edit title, summary, and/or body text → height adjusts dynamically
4. Tap X button → all changes discarded, returns to read-only
5. Edit again, tap checkmark → all changes saved to server and persisted

### Automated Testing

```bash
cd apps/firefly/product/client/imp/ios
./reproduce.sh
```

Verify in logs:
- "Saving post X changes to server"
- "Save response: {\"status\":\"success\"...}"
- "Post saved successfully, exiting edit mode"

## Disable Collapse During Editing

```swift
.onTapGesture {
    // Disable collapse when editing
    if !isEditing {
        onTap()
    }
}
```

This prevents accidental collapse of the post while editing. The user must explicitly save or cancel to exit edit mode.

## Key Implementation Details

1. **TextField Measurement Issue**: TextFields report 0.0 height with GeometryReader, so we hardcode title/summary section to 80pt

2. **State Management**: Editable copies (`editableTitle`, `editableSummary`, `editableBody`, `editableImageUrl`) persist between edit sessions and contain either saved or unsaved edits

3. **Image State Handling**:
   - `editableImageUrl == nil`: Image has been deleted
   - `editableImageUrl == "new_image"`: New image pending upload
   - `editableImageUrl == post.imageUrl`: Original image unchanged
   - `newImage`: Processed UIImage for immediate display
   - `newImageData`: Processed JPEG bytes for upload

4. **Image Processing**:
   - UIImage.size already accounts for EXIF orientation metadata
   - Redraw image into graphics context to embed orientation in pixels
   - Resize to max 1200px on longest edge while preserving aspect ratio
   - Encode as JPEG with 0.9 quality (90%)
   - Process on main thread (fast enough for typical images)

5. **Aspect Ratio Management**:
   - `originalImageAspectRatio`: Saved on image load, restored on cancel
   - `imageAspectRatio`: Current display ratio, updates when new image selected
   - Used for height calculations: `imageHeight = width / aspectRatio`

6. **Display Logic**:
   - New images (imageUrl == "new_image"): Display from `newImage` UIImage
   - Server images: Display via AsyncImage with URL
   - No changes needed to display code when switching between sources
   - Task modifier loads original aspect ratio asynchronously

7. **Upload Architecture**:
   - Images upload with post updates, not separately
   - Multipart form data used when `newImageData != nil`
   - Regular form encoding used for text-only updates
   - Server returns updated post with new image URL

8. **Post Updates**: After successful save, the post object is updated and propagated to parent via `onPostUpdated` callback, ensuring cancel button reverts to saved state

9. **Button Positioning**: Edit buttons are integrated into the author bar HStack rather than overlaid, creating a cohesive UI

10. **Dynamic Height**: Body text height recalculates on every keystroke, image height recalculates when image changes, triggering layout updates for smooth editing experience

11. **Edit Mode Protection**: Tapping on the post background or image does not collapse the post when in edit mode, preventing accidental data loss

12. **ImagePicker Reuse**: Uses existing ImagePicker struct from NewPostView.swift, preventing duplicate definitions

13. **Compiler Timeout Mitigation**: Complex views extracted to computed properties (`addImageButton`) and functions (`imageView()`) to reduce body complexity

14. **Sheet Presentation**: The `.sheet(isPresented: $showImagePicker)` modifier is attached to the main view body (after `.onChange`), allowing any button in the view to trigger image selection by setting `showImagePicker = true`

15. **Three-Button Image Editing**: When editing a post with an image, three buttons appear in an HStack:
   - Trash button (red) directly removes the image
   - Photo library button (blue) directly opens the photo picker with `.photoLibrary` source
   - Camera button (green) directly opens the camera with `.camera` source
   - No confirmation dialog needed - user choice is explicit via button selection
   - All three buttons set `imageSourceType` and `showImagePicker` to trigger the sheet

## Database Schema and Server Implementation

### Templates Table

The system uses a normalized database design with a `templates` table:

```sql
CREATE TABLE templates (
    name TEXT PRIMARY KEY,
    placeholder_title TEXT NOT NULL,
    placeholder_summary TEXT NOT NULL,
    placeholder_body TEXT NOT NULL
);

-- Default templates
INSERT INTO templates (name, placeholder_title, placeholder_summary, placeholder_body)
VALUES
    ('post', 'Title', 'Summary', 'Body'),
    ('profile', 'name', 'mission', 'personal statement');
```

### Posts Table

Posts reference templates via `template_name` column:

```sql
ALTER TABLE posts
ADD COLUMN template_name TEXT DEFAULT 'post';

-- Example: Set specific post to use profile template
UPDATE posts
SET template_name = 'profile'
WHERE title = 'asnaroo';
```

### Server Database Queries

All SELECT queries in `db.py` include a LEFT JOIN with templates:

```python
cur.execute("""
    SELECT p.id, p.user_id, p.parent_id, p.title, p.summary, p.body, p.image_url,
           p.created_at, p.timezone, p.location_tag, p.ai_generated,
           p.template_name,
           t.placeholder_title, t.placeholder_summary, t.placeholder_body,
           COALESCE(u.name, u.email) as author_name,
           u.email as author_email,
           COUNT(children.id) as child_count
    FROM posts p
    LEFT JOIN users u ON p.user_id = u.id
    LEFT JOIN templates t ON p.template_name = t.name
    LEFT JOIN posts children ON children.parent_id = p.id
    GROUP BY p.id, u.email, u.name, t.placeholder_title, t.placeholder_summary, t.placeholder_body
    ORDER BY p.created_at DESC
    LIMIT %s
""", (limit,))
```

### Migration Scripts

**create_templates.py**: Creates templates table, adds template_name column, migrates data, drops old columns
**grant_template_permissions.py**: Grants SELECT permission on templates to firefly_user

```python
# Must use microserver user for schema changes
db_config = {
    'host': 'localhost',
    'port': '5432',
    'database': 'firefly',
    'user': 'microserver',
    'password': ''
}

# After creating templates table, grant permissions:
cur.execute("GRANT SELECT ON templates TO firefly_user")
```

### Benefits of Templates Architecture

1. **Reusability**: Multiple posts can share the same template
2. **Maintainability**: Change placeholder text for all posts using a template by updating one row
3. **Extensibility**: Add new templates without altering posts table schema
4. **Separation of Concerns**: Template definitions separate from post data

### API Response Format

Posts returned from API include placeholder fields from the joined templates table:

```json
{
    "id": 22,
    "title": "asnaroo",
    "summary": "fix all the things",
    "body": "I'm a self-taught ninja...",
    "template_name": "profile",
    "placeholder_title": "name",
    "placeholder_summary": "mission",
    "placeholder_body": "personal statement",
    ...
}
```

The iOS app maps these via CodingKeys:
- `placeholder_title` → `titlePlaceholder`
- `placeholder_summary` → `summaryPlaceholder`
- `placeholder_body` → `bodyPlaceholder`
