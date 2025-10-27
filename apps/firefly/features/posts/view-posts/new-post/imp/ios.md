# new-post iOS implementation

*SwiftUI implementation for creating new posts*

## File Location

`apps/firefly/product/client/imp/ios/NoobTest/NewPostView.swift`

## Components

### NewPostButton

```swift
struct NewPostButton: View {
    let onTap: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 32))
                .foregroundColor(Color(red: 64/255, green: 224/255, blue: 208/255))

            Text("Create a new post")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.black.opacity(0.7))

            Spacer()
        }
        .padding()
        .background(Color.white.opacity(0.9))
        .cornerRadius(12)
        .shadow(radius: 2)
        .onTapGesture {
            onTap()
        }
    }
}
```

**Usage in PostsView:**
- Add at top of VStack before ForEach(posts)
- Call `showNewPostEditor = true` in onTap handler

### NewPostEditor

```swift
struct NewPostEditor: View {
    @Environment(\.dismiss) var dismiss
    let onPostCreated: () -> Void
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

**Post button:**
```swift
ToolbarItem(placement: .navigationBarTrailing) {
    Button(action: { postNewPost() }) {
        if isPosting {
            ProgressView()
        } else {
            Text("Post").fontWeight(.semibold)
        }
    }
    .foregroundColor(title.isEmpty ? .gray : .black)
    .disabled(title.isEmpty || isPosting)
}
```

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
