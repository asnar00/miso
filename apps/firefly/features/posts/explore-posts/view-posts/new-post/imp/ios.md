# new-post iOS implementation

*SwiftUI implementation for creating new posts*

## File Location

`apps/firefly/product/client/imp/ios/NoobTest/NewPostView.swift`

## Components

### NewPostButton

**NOTE:** The NewPostButton component is deprecated and should be removed from the product code. New posts are now triggered from a floating toolbar instead.

### NewPostEditor

```swift
struct NewPostEditor: View {
    @Environment(\.dismiss) private var dismiss
    let onPostCreated: () -> Void
    let onDismiss: (() -> Void)?  // Optional callback for custom overlay dismissal
    let parentId: Int?

    @State private var title: String = ""
    @State private var summary: String = ""
    @State private var bodyText: String = ""
    @State private var selectedImage: UIImage? = nil
    @State private var showImagePicker = false
    @State private var imageSourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var showSourceSelection = false
    @State private var isPosting = false
    @State private var postError: String? = nil
```

**onDismiss callback pattern:**

The `onDismiss` parameter is optional and supports two presentation modes:

1. **Standard `.sheet()` presentation**: Pass `nil` for `onDismiss`. The view uses `@Environment(\.dismiss)` to close itself.
2. **Custom overlay presentation**: Pass a callback that manages the overlay state (used when toolbar must remain visible). The callback sets `showNewPostEditor = false` and `activeTab = .home` in the parent view.

This dual-mode approach allows the same editor to work both with SwiftUI's built-in sheet presentation and custom ZStack overlays.

**Layout structure:**
- `NavigationView` with inline title "New Post"
- Background: turquoise `Color(red: 64/255, green: 224/255, blue: 208/255)`
- `ScrollView` containing main editing card
- Toolbar items: "Cancel" (leading), "Post" (trailing)

**Editing fields:**

All fields use `ZStack` with placeholder text that shows when empty:

1. **Title:** `TextField` with 24pt bold font, light gray background `.black.opacity(0.05)`
2. **Summary:** `TextField` with subheadline italic font, light gray background
3. **Image:**
   - When nil: button with photo icon, triggers `.confirmationDialog`
   - When set: display image with X button overlay to clear
4. **Body:** `TextEditor` with min height 200, light gray background

**Image selection dialog:**
```swift
.confirmationDialog("Choose Image Source", isPresented: $showSourceSelection) {
    Button("Camera") {
        imageSourceType = .camera
        showImagePicker = true
    }
    Button("Photo Library") {
        imageSourceType = .photoLibrary
        showImagePicker = true
    }
    Button("Cancel", role: .cancel) {}
}
.sheet(isPresented: $showImagePicker) {
    ImagePicker(image: $selectedImage, sourceType: imageSourceType)
}
```

**Toolbar buttons (Cancel and Post):**

The Cancel and Post buttons use custom styling with rounded pill-shaped backgrounds:

```swift
// Cancel button (left side)
ToolbarItem(placement: .navigationBarLeading) {
    Button(action: {
        if let onDismiss = onDismiss {
            onDismiss()  // Use callback for custom overlay
        } else {
            dismiss()    // Use environment dismiss for standard sheet
        }
    }) {
        Text("Cancel")
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.black)
            .cornerRadius(20)
    }
    .buttonStyle(.plain)
    .fixedSize()
    .onAppear {
        // Register with UI automation for programmatic testing
        UIAutomationRegistry.shared.register(id: "newpost-cancel") {
            if let onDismiss = onDismiss {
                onDismiss()
            } else {
                dismiss()
            }
        }
    }
}

// Post button (right side)
ToolbarItem(placement: .navigationBarTrailing) {
    Button(action: { postNewPost() }) {
        Group {
            if isPosting {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .black))
            } else {
                Text("Post")
                    .fontWeight(.semibold)
                    .foregroundColor(.black)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.white)
        .cornerRadius(20)
    }
    .buttonStyle(.plain)
    .fixedSize()
    .disabled(title.isEmpty || isPosting)
    .opacity(title.isEmpty ? 0.5 : 1.0)
}
```

**Critical styling details:**
- Both buttons use `.buttonStyle(.plain)` to remove default SwiftUI button styling (which adds borders)
- Both buttons use `.fixedSize()` to prevent text clipping by toolbar constraints
- Cancel: White text on black background (cornerRadius 20)
- Post: Black text on white background (cornerRadius 20), grayed out when disabled
- Horizontal padding: 16pt, Vertical padding: 8pt
- Button text is NOT clipped because of `.fixedSize()` modifier

**Posting logic:**
```swift
private func postNewPost() {
    guard !title.isEmpty else { return }

    isPosting = true
    postError = nil

    PostsAPI.shared.createPost(
        title: title,
        summary: summary.isEmpty ? "No summary" : summary,
        body: bodyText.isEmpty ? "No content" : bodyText,
        image: selectedImage,
        parentId: parentId
    ) { result in
        DispatchQueue.main.async {
            isPosting = false
            switch result {
            case .success(_):
                Logger.shared.info("[NewPost] Post created successfully")
                onPostCreated()  // Refresh posts list
                dismiss()        // Close modal
            case .failure(let error):
                Logger.shared.error("[NewPost] Failed to create post: \(error.localizedDescription)")
                postError = "Failed to post: \(error.localizedDescription)"
            }
        }
    }
}
```

### ImagePicker

UIKit bridge for camera and photo library:

```swift
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

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        func imagePickerController(_ picker: UIImagePickerController,
                                    didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let uiImage = info[.originalImage] as? UIImage {
                parent.image = uiImage
            }
            parent.dismiss()
        }
    }
}
```

## Integration with PostsView

In `PostsView.swift`:

```swift
@State private var showNewPostEditor = false

var body: some View {
    // ... existing code ...
    VStack(spacing: 8) {
        NewPostButton {
            showNewPostEditor = true
        }

        ForEach(posts) { post in
            // ... existing post views ...
        }
    }
    // ... existing code ...
    .sheet(isPresented: $showNewPostEditor) {
        NewPostEditor(onPostCreated: onPostCreated, parentId: nil)
    }
}
```

## PostsAPI Extension

The `PostsAPI.createPost` method handles multipart form data upload with image encoding (see `posts/operations/create-post/imp/ios.md` for full implementation).

## Required Imports

```swift
import SwiftUI
import PhotosUI
```

## Info.plist Requirements

For camera and photo library access:
- `NSCameraUsageDescription` - "To add photos to your posts"
- `NSPhotoLibraryUsageDescription` - "To select photos for your posts"
