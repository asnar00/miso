# edit-posts pseudocode

## Data Structures

```
Post {
    id: integer
    title: string (mutable)
    summary: string (mutable)
    body: string (mutable)
    imageUrl: string? (mutable)
    authorEmail: string
    ... other fields
}

EditState {
    isEditing: boolean
    editableTitle: string
    editableSummary: string
    editableBody: string
    editableImageUrl: string?  // nil means image removed, "new_image" means new image pending
    newImage: Image?  // Processed image for immediate display
    newImageData: bytes?  // Processed JPEG data ready for upload
    originalImageAspectRatio: float  // For restoration on cancel
    imageAspectRatio: float  // Current display aspect ratio
}
```

## Core Functions

### checkOwnership()
```
function checkOwnership(post, currentUserEmail):
    if currentUserEmail is null: return false
    if post.authorEmail is null: return false
    return post.authorEmail.lowercase() == currentUserEmail.lowercase()
```

### enterEditMode()
```
function enterEditMode():
    isEditing = true
    // editableTitle, editableSummary, editableBody already contain current values
    // UI shows X and checkmark buttons in author bar
    // Title, summary, and body become editable TextFields
    // Grey backgrounds appear around editable sections
```

### cancelEdit()
```
function cancelEdit(post):
    editableTitle = post.title  // Revert to saved state
    editableSummary = post.summary
    editableBody = post.body
    editableImageUrl = post.imageUrl
    newImage = null
    newImageData = null
    imageAspectRatio = originalImageAspectRatio  // Restore original aspect ratio
    isEditing = false
    // UI shows pencil button, all fields become read-only
```

### deleteImage()
```
function deleteImage():
    editableImageUrl = null  // Mark image as removed
    // Layout recalculates to remove image space
    // Add Image button becomes visible
```

### addImage()
```
function addImage():
    // Show dialog: Take Photo or Choose from Library
    showImageSourcePicker()
```

### onImageSelected(rawImage)
```
function onImageSelected(rawImage):
    processedImage = processImage(rawImage)
    // processedImage contains both display image and upload data
    newImage = processedImage.displayImage
    newImageData = processedImage.jpegData

    // Update aspect ratio for layout
    imageAspectRatio = newImage.width / newImage.height

    // Mark that we have a new image
    editableImageUrl = "new_image"

    // Image displays immediately in the post
```

### processImage(image)
```
function processImage(image):
    // Step 1: Remove EXIF orientation and reorient pixel data
    // UIImage.size already accounts for orientation metadata
    // Redraw the image to embed orientation into pixels
    reorientedImage = redrawImage(image, targetSize: image.size)

    // Step 2: Resize to maximum 1200 pixels on longest edge
    maxDimension = 1200
    currentMaxDimension = max(reorientedImage.width, reorientedImage.height)

    if currentMaxDimension <= maxDimension:
        resizedImage = reorientedImage  // Already small enough
    else:
        scale = maxDimension / currentMaxDimension
        newWidth = reorientedImage.width * scale
        newHeight = reorientedImage.height * scale
        resizedImage = redrawImage(reorientedImage, targetSize: (newWidth, newHeight))

    // Step 3: Encode as high-quality JPEG
    jpegData = encodeJPEG(resizedImage, quality: 0.9)

    return {
        displayImage: resizedImage,
        jpegData: jpegData
    }
```

### redrawImage(image, targetSize)
```
function redrawImage(image, targetSize):
    // Create graphics context with target size
    context = createGraphicsContext(targetSize, opaque: false, scale: 1.0)

    // Draw image into context (this embeds any rotation/orientation)
    image.drawInRect(origin: (0, 0), size: targetSize)

    // Extract redrawn image
    redrawnImage = getImageFromContext(context)
    closeContext(context)

    return redrawnImage
```

### saveEdit(post)
```
function saveEdit(post):
    if newImageData != null:
        // Use multipart form data for image upload
        request = createMultipartRequest()
        request.url = "/api/posts/update"
        request.method = POST

        // Add text fields
        request.addField("post_id", post.id)
        request.addField("email", currentUserEmail)
        request.addField("title", editableTitle)
        request.addField("summary", editableSummary)
        request.addField("body", editableBody)

        // Add image file
        request.addFile("image", filename: "image.jpg", data: newImageData, contentType: "image/jpeg")
    else:
        // Use regular form encoding if no new image
        request = {
            method: POST,
            url: "/api/posts/update",
            contentType: "application/x-www-form-urlencoded",
            body: {
                post_id: post.id,
                email: currentUserEmail,
                title: editableTitle,
                summary: editableSummary,
                body: editableBody
            }
        }

    response = sendRequest(request)

    if response.status == "success":
        // Update the post object with new values
        post.title = editableTitle
        post.summary = editableSummary
        post.body = editableBody
        if editableImageUrl == null:
            post.imageUrl = null  // Image was deleted
        else if response.post.imageUrl != null:
            post.imageUrl = response.post.imageUrl  // New image URL from server

        // Clear temporary image state
        newImage = null
        newImageData = null
        originalImageAspectRatio = imageAspectRatio  // Save new ratio as baseline

        // Notify parent to update posts array
        onPostUpdated(post)

        isEditing = false
        // UI shows pencil button, all fields become read-only
    else:
        showError(response.message)
```

### calculateTextHeight(text, width)
```
function calculateTextHeight(text, availableWidth):
    // Use platform text measurement API
    textView = createTextView()
    textView.text = text
    textView.width = availableWidth
    size = textView.measureSize()
    return size.height
```

## Layout Calculations

**Key Measurements:**
- Title/Summary section: hardcoded to 80pt (TextFields don't measure reliably)
- Available width for body text: 350pt
- Spacing below title/summary: 12pt
- Spacing above body text (below image): 4pt
- Spacing below body text: 12pt
- Bottom padding below author: 28pt
- Author name left indent: 24pt
- Button size: 32pt
- Button spacing: 8pt

**Height Calculation:**
```
compactHeight = 100pt

// Use editableImageUrl to determine if image should be shown
hasImage = (editableImageUrl != null)
imageHeight = hasImage ? (availableWidth / imageAspectRatio) : 0

expandedHeight =
    80pt (title/summary - hardcoded) +
    12pt (spacing) +
    imageHeight +
    4pt (spacing) +
    bodyTextHeight +
    12pt (spacing) +
    authorHeight (15pt) +
    28pt (bottom padding)
```

**Position Calculations:**
```
imageY = 80 + 12  // Title/summary height + spacing
bodyY = imageY + imageHeight + 4  // Image position + image height + spacing
authorY = bodyY + bodyTextHeight + 12  // Body position + body height + spacing
```

**Dynamic Height:**
As user edits text:
1. Recalculate bodyTextHeight = calculateTextHeight(editableBody, 350pt)
2. Recalculate expandedHeight with new bodyTextHeight
3. Reposition author: authorY = bodyY + bodyTextHeight + 12pt
4. UI automatically adjusts layout with animation

## Visual Design

**Edit Mode Indicators:**
- Grey background: `Color.gray.opacity(0.1)` with 8pt corner radius
- Applied to title/summary container and body text container

**Text Fields (Edit Mode):**
- Title: 22pt bold, single line, plain style
- Summary: 15pt italic, up to 2 lines when collapsed, plain style
- Body: system body font, multi-line TextEditor, scrolling disabled, dynamic height
- All fields: autocorrection disabled, autocapitalization disabled

**Buttons in Author Bar:**
- Not editing: pencil.circle.fill icon, 32pt, black at 60% opacity
- Editing: arrow.uturn.backward.circle.fill (undo, red 60%) and checkmark.circle.fill (green 60%)
- Positioned: right side of author bar with 8pt spacing, 18pt trailing padding
- Author name: 24pt leading padding

**Image Controls (Edit Mode Only):**

When image exists - three buttons in HStack overlaid on top-right of image:
- Delete image button: trash.circle.fill icon, 32pt, red 80% opacity, white circle background
- Photo library button: photo.circle.fill icon, 32pt, blue 80% opacity, white circle background
- Camera button: camera.circle.fill icon, 32pt, green 80% opacity, white circle background
- HStack spacing: 8pt between buttons
- Overall padding: 8pt around button group

When no image exists - Add Image button:
- 350pt wide, 50pt tall, black text/outline
- Black text with "photo.badge.plus" icon
- Light grey background (10% opacity)
- Black border (30% opacity, 2pt width)
- 12pt corner radius
- Positioned at imageY coordinate

## Server API

### POST /api/posts/update

**URL:** `http://185.96.221.52:8080/api/posts/update`

**Method:** POST

**Content-Type:**
- `application/x-www-form-urlencoded` (text-only updates)
- `multipart/form-data` (when uploading image)

**Request Parameters (Form Data):**
```
post_id: integer (required)
email: string (required) - for authentication
title: string (required)
summary: string (required)
body: string (required)
image: file (optional) - JPEG image data, max 1200px, quality 0.9
```

**Response:**
```json
{
    "status": "success",
    "post": {
        "id": 22,
        "title": "Updated Title",
        "summary": "Updated Summary",
        "body": "Updated Body Text",
        "author_email": "test@example.com",
        "author_name": "asnaroo",
        ...
    }
}
```

## Patching Instructions

### Post Model
```
// Make title, summary, body, imageUrl mutable
struct Post:
    let id: Int
    var title: String      // Changed from let to var
    var summary: String    // Changed from let to var
    var body: String       // Changed from let to var
    var imageUrl: String?  // Changed from let to var
    let authorEmail: String
    ... other fields
```

### PostView (or equivalent)

**Add State:**
```
state isEditing: boolean = false
state editableTitle: string = ""
state editableSummary: string = ""
state editableBody: string = ""
state editableImageUrl: string? = null
state showImageSourcePicker: boolean = false
state showImagePicker: boolean = false
state imageSourceType: SourceType = PhotoLibrary
state selectedImage: Image? = null
state newImageData: bytes? = null
state newImage: Image? = null
state originalImageAspectRatio: float = 1.0
state imageAspectRatio: float = 1.0
```

**Add Callback:**
```
callback onPostUpdated: (Post) -> Void
```

**Add Title/Summary Edit Fields (in title/summary section):**
```
if isEditing:
    TextField("Title", text: editableTitle)
        .font(size: 22, weight: bold)
        .autocorrectionDisabled()
        .autocapitalizationDisabled()

    TextField("Summary", text: editableSummary)
        .font(size: 15, italic)
        .autocorrectionDisabled()
        .autocapitalizationDisabled()
else:
    Text(editableTitle)
        .font(size: 22, weight: bold)
        .lineLimit(1)

    Text(editableSummary)
        .font(size: 15, italic)
        .lineLimit(2)

// Add grey background when editing
if isEditing:
    RoundedRectangle(cornerRadius: 8)
        .fill(Color.gray.opacity(0.1))
```

**Modify Body Text Display:**
```
ZStack:
    if isEditing:
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.gray.opacity(0.1))

    TextEditor(text: editableBody)
        .disabled(not isEditing)
        .autocorrectionDisabled()
        .autocapitalizationDisabled()
        .scrollDisabled(true)
        .onChange(editableBody):
            // Trigger height recalculation
```

**Add Edit Buttons in Author Bar:**
```
HStack:
    // Author name (left side)
    Text(authorName)
        .padding(.leading, 24pt)

    Spacer()

    // Edit buttons (right side, only for owner)
    if isOwner:
        if not isEditing:
            Button(icon: pencil.circle.fill, size: 32pt):
                onClick: enterEditMode()
        else:
            Button(icon: xmark.circle.fill, size: 32pt, color: red):
                onClick: cancelEdit()
            Button(icon: checkmark.circle.fill, size: 32pt, color: green):
                onClick: saveEdit()
        .padding(.trailing, 18pt)

// Position at authorY coordinate
.offset(y: authorY)
```

**Add Image Display Logic:**
```
function displayImage(imageUrl, width, height):
    if imageUrl == "new_image" and newImage != null:
        // Show newly selected image from memory
        return Image(newImage)
            .resizable()
            .aspectRatio(contentMode: fill)
            .frame(width, height)
            .clipped()
    else:
        // Show image from server URL
        fullUrl = serverURL + imageUrl
        return AsyncImage(url: fullUrl)
            .aspectRatio(contentMode: fill)
            .frame(width, height)
            .clipped()
```

**Add Image Controls (Edit Mode):**
```
if isEditing:
    if editableImageUrl != null:
        // Show three buttons in HStack over image (top-right corner)
        HStack(spacing: 8pt):
            // Delete button
            Button(icon: trash.circle.fill, color: red, background: white circle):
                onClick: deleteImage()

            // Photo library button
            Button(icon: photo.circle.fill, color: blue, background: white circle):
                onClick:
                    imageSourceType = photoLibrary
                    showImagePicker = true

            // Camera button
            Button(icon: camera.circle.fill, color: green, background: white circle):
                onClick:
                    imageSourceType = camera
                    showImagePicker = true
        // Position in top-right corner of image with 8pt padding
    else:
        // Show Add Image button
        Button(text: "Add Image", icon: photo.badge.plus):
            onClick: addImage()
        // Confirmation dialog: Take Photo or Choose from Library
        // Opens image picker with selected source
        // When image selected: onImageSelected(selectedImage)

// Image picker sheet (present when showImagePicker = true)
Sheet(isPresented: showImagePicker):
    ImagePicker(selectedImage, imageSourceType)
    // When image selected: onImageSelected(selectedImage) via onChange
```

**Initialize on Appear:**
```
onAppear:
    editableTitle = post.title
    editableSummary = post.summary
    editableBody = post.body
    editableImageUrl = post.imageUrl

    // Load and save original aspect ratio
    if post.imageUrl != null:
        imageData = fetchImageData(post.imageUrl)
        image = decodeImage(imageData)
        aspectRatio = image.width / image.height
        imageAspectRatio = aspectRatio
        originalImageAspectRatio = aspectRatio
```

**Parent View Update Handler:**
```
PostView(
    post: post,
    onPostUpdated: { updatedPost in
        // Find and update post in posts array
        if let index = posts.firstIndex(where: { $0.id == updatedPost.id }):
            posts[index] = updatedPost
    }
)
```

**Disable Collapse During Editing:**
```
onTapGesture:
    // Only allow collapse when not editing
    if not isEditing:
        onTap()  // Collapse/expand toggle
```

## UI Automation

For testing, register UI automation hooks:

```
register("edit-button"):
    isEditing = true

register("cancel-button"):
    editableTitle = post.title
    editableSummary = post.summary
    editableBody = post.body
    isEditing = false

register("save-button"):
    saveEdit(post)

register("edit-body-text"):
    editableBody += "\n\nTest text added by automation!"

register("delete-image-button"):
    editableImageUrl = null

register("replace-photo-library-button"):
    imageSourceType = photoLibrary
    showImagePicker = true

register("replace-camera-button"):
    imageSourceType = camera
    showImagePicker = true

register("add-image-button"):
    showImageSourcePicker = true
```
