# edit-posts iOS implementation

## Files Modified

- `NoobTest/Post.swift` - Made title, summary, body, imageUrl mutable (var instead of let); added optional placeholder fields from templates
- `NoobTest/PostView.swift` - Main post view with unified edit functionality for both new and existing posts; handles create vs update; custom placeholder support; button repositioning (edit actions at bottom-right); delete confirmation dialog; delete post functionality
- `NoobTest/PostsListView.swift` - Added inline post creation with createNewPost() function; removed modal sheet; added editing state tracking; updated onPostUpdated to handle temp post replacement; global deletion listener; isAnyPostEditing binding for toolbar fade
- `NoobTest/PostDeletionNotifier.swift` - NEW: Global singleton for broadcasting post deletion events across all views
- `NoobTest/PostsView.swift` - Updated to pass isAnyPostEditing binding through navigation hierarchy
- `NoobTest/ContentView.swift` - Added isAnyPostEditing state; toolbar fade-out and interaction disabling during edit mode
- `NoobTest/SearchResultsView.swift` - Added isAnyPostEditing state variable for PostsView compatibility
- `NoobTest/ChildPostsView.swift` - Updated PostView calls to match new signature with edit callbacks
- `NoobTest/UIAutomationRegistry.swift` - Added .uiAutomationId() modifier
- `reproduce.sh` - Simplified automated testing script
- `server/imp/py/db.py` - Fixed create_post() to use template_name instead of placeholder columns; added error logging with traceback; added delete_post() method
- `server/imp/py/app.py` - Updated create_post call to pass template_name='post'; added detailed logging; added DELETE endpoint for posts
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

## PostDeletionNotifier.swift - Global Deletion Broadcasting

```swift
import Foundation
import Combine

/// Global singleton that broadcasts post deletion events to all views
class PostDeletionNotifier: ObservableObject {
    static let shared = PostDeletionNotifier()

    /// Published property that emits the ID of deleted posts
    @Published var deletedPostId: Int? = nil

    private init() {}

    /// Call this when a post is deleted to notify all observers
    func notifyPostDeleted(_ postId: Int) {
        Logger.shared.info("[PostDeletionNotifier] Broadcasting deletion of post \(postId)")
        DispatchQueue.main.async {
            self.deletedPostId = postId
        }
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
@State private var showImagePicker: Bool = false
@State private var selectedImage: UIImage? = nil
@State private var newImageData: Data? = nil  // Processed image data ready for upload
@State private var newImage: UIImage? = nil  // Processed image for display
@State private var originalImageAspectRatio: CGFloat = 1.0  // Save original for cancel
@State private var imageAspectRatio: CGFloat = 1.0  // Current display aspect ratio
@State private var editButtonScale: CGFloat = 1.0  // For bounce animation
```

### Parameters

```swift
var isNewPost: Bool = false  // True for unsaved posts (id < 0), affects undo button behavior
@Binding var shouldBounceButtons: Bool  // Trigger bounce animation on edit buttons
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
            .textInputAutocapitalization(.words)  // Word capitalization for titles
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
            .textInputAutocapitalization(.sentences)
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
        .textInputAutocapitalization(.sentences)  // Capitalize first letter of sentences
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
                    showImagePicker = true
                }) {
                    Image(systemName: "photo.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.blue.opacity(0.8))
                        .background(Circle().fill(Color.white))
                }
                .uiAutomationId("replace-photo-library-button") {
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
        showImagePicker = true
    }) {
        HStack {
            Image(systemName: "photo.badge.plus")
                .font(.system(size: 20))
            Text("add image")
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
    .sheet(isPresented: $showImagePicker) {
        ImagePicker(image: $selectedImage, sourceType: .photoLibrary)
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

### Save Function - Handles Both Create and Update

```swift
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
```

### Delete Post Function - Permanently Removes Post

```swift
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
```

### Button Overlays - Positioned with Tunable Constants

Edit button appears in bottom-right when not editing. When editing, action buttons (delete/undo/save) appear in the same bottom-right position:

```swift
// Edit button overlay - positioned in bottom-right corner (only for own posts when expanded, not editing)
if isOwnPost && isExpanded && !isEditing {
    VStack {
        Spacer()
        HStack {
            Spacer()
            Button(action: {
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
    .opacity(expansionFactor)
}

// Edit action buttons overlay - positioned in bottom right corner (only when editing)
if isOwnPost && isExpanded && isEditing {
    VStack {
        Spacer()
        HStack {
            Spacer()
            HStack(spacing: 20) {  // Hardcoded 20pt spacing
                // Delete button (only for saved posts, never for profiles)
                if post.id > 0 && post.template != "profile" {
                    Button(action: {
                        showDeleteConfirmation = true
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color(red: 1.0, green: 0.5, blue: 0.5))  // Light red
                                .frame(width: 32, height: 32)
                                .shadow(color: Color.black.opacity(0.4), radius: 8, x: 0, y: 4)
                            Image(systemName: "trash")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.black)
                        }
                    }
                }

                // Undo button
                Button(action: {
                    if isNewPost {
                        // New post: delete it
                        onDelete?()
                    } else {
                        // Existing post: revert changes, stay expanded
                        editableTitle = post.title
                        editableSummary = post.summary
                        editableBody = post.body
                        editableImageUrl = post.imageUrl
                        newImageData = nil
                        newImage = nil
                        imageAspectRatio = originalImageAspectRatio
                        onEndEditing?()  // Exit edit mode without refreshing list
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(tunables.buttonColor())  // Peach
                            .frame(width: 32, height: 32)
                            .shadow(color: Color.black.opacity(0.4), radius: 8, x: 0, y: 4)
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.black)
                    }
                }

                // Save button
                Button(action: {
                    savePost()
                }) {
                    ZStack {
                        Circle()
                            .fill(Color(red: 0.5, green: 1.0, blue: 0.5))  // Light green
                            .frame(width: 32, height: 32)
                            .shadow(color: Color.black.opacity(0.4), radius: 8, x: 0, y: 4)
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.black)
                    }
                }
            }
            .scaleEffect(editButtonScale)  // For bounce animation
            .padding(.trailing, 12)
            .padding(.bottom, 12)
        }
    }
    .frame(width: availableWidth, height: currentHeight)
    .opacity(expansionFactor)
}

// Bounce animation handler
.onChange(of: shouldBounceButtons) { _, shouldBounce in
    if shouldBounce && isEditing {
        // Quick scale up with spring
        withAnimation(.spring(response: 0.15, dampingFraction: 0.3, blendDuration: 0)) {
            editButtonScale = 1.3
        }
        // Bounce back to normal
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5, blendDuration: 0)) {
                editButtonScale = 1.0
            }
        }
        // Reset trigger
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            shouldBounceButtons = false
        }
    }
}

// Delete confirmation alert
.alert("Delete Post", isPresented: $showDeleteConfirmation) {
    Button("Cancel", role: .cancel) {}
    Button("Delete", role: .destructive) {
        deletePost()
    }
} message: {
    Text("Are you sure you want to permanently delete this post?")
}
```

**Key Details:**
- Edit action buttons: Circle backgrounds with black icons and drop shadows
- Delete: light red (RGB 255/128/128), Undo: peach (buttonColor), Save: light green (RGB 128/255/128)
- Button spacing: 20pt (hardcoded)
- Bounce animation: scales to 1.3x then back to 1.0x with spring physics
- Triggered when user tries to tap another post while editing
- Delete button hidden for profile posts
- Undo uses isNewPost flag to determine behavior (delete vs revert)

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
    ImagePicker(image: $selectedImage, sourceType: .photoLibrary)
}
```

## PostsListView.swift - Inline Post Creation

### State Variables

```swift
@State private var editingPostId: Int? = nil  // Track which post is being edited
@State private var shouldBounceEditButtons: Bool = false  // Trigger bounce animation
```

### Tap Blocking During Edit

```swift
// In onTap handler for each PostView:
onTap: {
    // Block taps on other posts while editing
    guard editingPostId == nil else {
        // Trigger bounce animation on edit buttons to signal user
        shouldBounceEditButtons = true
        return
    }
    expandPost(post.id)
    withAnimation(.easeInOut(duration: 0.3)) {
        proxy.scrollTo(post.id, anchor: .top)
    }
}
```

### Create New Post Function

```swift
func createNewPost() {
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
            titlePlaceholder: "Title",  // Default "post" template
            summaryPlaceholder: "Summary",
            bodyPlaceholder: "Body"
        )

        // Insert at beginning of posts array
        self.posts.insert(newPost, at: 0)

        // Expand it and enter edit mode
        self.viewModel.expandedPostId = -1
        self.editingPostId = -1

        Logger.shared.info("[PostsListView] New post created and expanded in edit mode")
    }
}
```

### PostView Integration

```swift
PostView(
    post: post,
    isExpanded: viewModel.expandedPostId == post.id,
    availableWidth: postWidth,
    isEditing: editingPostId == post.id,
    onTap: {
        // Block taps on other posts while editing
        guard editingPostId == nil else {
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
    onPostUpdated: { updatedPost in
        // Check if this is a new post being updated with real ID
        if post.id < 0 && updatedPost.id > 0 {
            // Replace temporary post with real one
            if let index = posts.firstIndex(where: { $0.id == post.id }) {
                posts[index] = updatedPost
                editingPostId = nil
                isAnyPostEditing = false
                viewModel.expandedPostId = updatedPost.id
            }
        } else if let index = posts.firstIndex(where: { $0.id == updatedPost.id }) {
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
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    },
    onDelete: {
        // Called for both new posts (undo) and saved posts (after server delete)
        posts.removeAll { $0.id == post.id }
        editingPostId = nil
        isAnyPostEditing = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        // For saved posts, refresh to update parent's child count
        if post.id > 0 {
            fetchPosts()
            onPostCreated()
        }
    },
    isNewPost: post.id < 0,  // Flag for undo button behavior
    shouldBounceButtons: $shouldBounceEditButtons
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
- **Image edit button colors:** Red (trash), Blue (photo library)

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

9. **Button Positioning**:
   - Edit button group overlaid in top-right corner at `(edit-button-x - offset, 16pt)` where offset is 32pt when not editing, 80pt when editing
   - Navigate-to-children button stays at right edge `(350 + 6 + 32pt, vertically centered)`, maintaining position during expansion
   - Delete post button (saved posts only) overlaid in bottom-right corner at `(334pt, currentHeight - 48pt)`
   - Button positions use tunable constants for fine-tuning (edit-button-x, edit-button-spacing)
   - All buttons use .offset() for precise positioning with .opacity(expansionFactor) for smooth fade-in

10. **Dynamic Height**: Body text height recalculates on every keystroke, image height recalculates when image changes, triggering layout updates for smooth editing experience

11. **Edit Mode Protection**: Tapping on the post background or image does not collapse the post when in edit mode, preventing accidental data loss

12. **ImagePicker Reuse**: Uses existing ImagePicker struct from NewPostView.swift, preventing duplicate definitions

13. **Compiler Timeout Mitigation**: Complex views extracted to computed properties (`addImageButton`) and functions (`imageView()`) to reduce body complexity

14. **Sheet Presentation**: The `.sheet(isPresented: $showImagePicker)` modifier is attached to the main view body (after `.onChange`), allowing any button in the view to trigger image selection by setting `showImagePicker = true`

15. **Two-Button Image Editing**: When editing a post with an image, two buttons appear in an HStack:
   - Trash button (red) directly removes the image
   - Photo library button (blue) directly opens the photo picker
   - No confirmation dialog needed - tapping opens photo library directly

16. **Delete Post Functionality**: For saved posts (post.id > 0) in edit mode:
   - Red trash button appears in bottom-right corner as part of edit action buttons group
   - Tapping trash button shows confirmation alert instead of immediate deletion
   - Alert title: "Delete Post", message: "Are you sure you want to permanently delete this post?"
   - Alert buttons: "Cancel" (role: .cancel), "Delete" (role: .destructive)
   - On confirmation, sends HTTP DELETE request to `/api/posts/{post_id}` endpoint
   - On success, broadcasts deletion via `PostDeletionNotifier.shared.notifyPostDeleted(post.id)`
   - Global notification system removes post from all `PostsListView` instances throughout app
   - Post disappears from main list, search results, child views simultaneously
   - Uses `.onReceive(PostDeletionNotifier.shared.$deletedPostId)` in PostsListView to listen for deletions
   - `PostDeletionNotifier` is a singleton ObservableObject with `@Published var deletedPostId: Int?`

17. **Toolbar Fade During Editing**: The bottom toolbar becomes invisible and non-interactive during post editing:
   - Editing state tracked via `@State private var isAnyPostEditing: Bool` in ContentView
   - Passed as `@Binding` through PostsView → PostsListView hierarchy
   - PostsListView updates binding when `onStartEditing`/`onEndEditing` callbacks fire
   - Toolbar applies `.opacity(isAnyPostEditing ? 0 : 1)` for fade effect
   - Toolbar applies `.allowsHitTesting(!isAnyPostEditing)` to disable interaction when transparent
   - Fade animation: `.animation(.easeInOut(duration: 0.3), value: isAnyPostEditing)`
   - Prevents toolbar from obscuring edit action buttons at bottom of screen
   - Toolbar fades back in when user saves, cancels, or deletes post

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
