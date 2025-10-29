import SwiftUI
import PhotosUI

struct NewPostButton: View {
    let onTap: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 32))
                .foregroundColor(Color(red: 128/255, green: 128/255, blue: 128/255))

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

struct NewPostEditor: View {
    @Environment(\.dismiss) private var dismiss
    let onPostCreated: () -> Void
    let onDismiss: (() -> Void)?
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

    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 128/255, green: 128/255, blue: 128/255)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // Main editing card (matches PostView style)
                        VStack(alignment: .leading, spacing: 8) {
                            // Title field (bold, large - like post title)
                            ZStack(alignment: .leading) {
                                if title.isEmpty {
                                    Text("Title")
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundColor(.black.opacity(0.3))
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                }
                                TextField("", text: $title)
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.black)
                                    .padding(12)
                            }
                            .background(Color.black.opacity(0.05))
                            .cornerRadius(8)

                            // Summary field (italic - like post summary)
                            ZStack(alignment: .leading) {
                                if summary.isEmpty {
                                    Text("Summary")
                                        .font(.subheadline)
                                        .italic()
                                        .foregroundColor(.black.opacity(0.3))
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                }
                                TextField("", text: $summary)
                                    .font(.subheadline)
                                    .italic()
                                    .foregroundColor(.black.opacity(0.8))
                                    .padding(12)
                            }
                            .background(Color.black.opacity(0.05))
                            .cornerRadius(8)

                            // Image selection/display
                            if let image = selectedImage {
                                ZStack(alignment: .topTrailing) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(maxWidth: .infinity)
                                        .cornerRadius(12)
                                        .padding(.top, 8)
                                        .padding(.bottom, 8)

                                    Button(action: {
                                        selectedImage = nil
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 28))
                                            .foregroundColor(.white)
                                            .background(Color.black.opacity(0.6))
                                            .clipShape(Circle())
                                    }
                                    .padding(12)
                                }
                            } else {
                                Button(action: {
                                    showSourceSelection = true
                                }) {
                                    HStack {
                                        Image(systemName: "photo.on.rectangle.angled")
                                            .font(.system(size: 20))
                                        Text("Image")
                                            .font(.body)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(12)
                                    .background(Color.black.opacity(0.05))
                                    .foregroundColor(.black.opacity(0.5))
                                    .cornerRadius(8)
                                }
                                .padding(.top, 4)
                                .padding(.bottom, 4)
                            }

                            // Body text editor (like post body)
                            ZStack(alignment: .topLeading) {
                                if bodyText.isEmpty {
                                    Text("Body")
                                        .font(.body)
                                        .foregroundColor(.black.opacity(0.3))
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 20)
                                }
                                TextEditor(text: $bodyText)
                                    .font(.body)
                                    .foregroundColor(.black)
                                    .frame(minHeight: 200)
                                    .scrollContentBackground(.hidden)
                                    .padding(8)
                            }
                            .background(Color.black.opacity(0.05))
                            .cornerRadius(8)
                        }
                        .padding()
                        .background(Color.white.opacity(0.9))
                        .cornerRadius(12)
                        .shadow(radius: 2)

                        // Error message
                        if let error = postError {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.caption)
                                .padding()
                                .background(Color.white.opacity(0.9))
                                .cornerRadius(8)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("New Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        if let onDismiss = onDismiss {
                            onDismiss()
                        } else {
                            dismiss()
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
                        UIAutomationRegistry.shared.register(id: "newpost-cancel") {
                            if let onDismiss = onDismiss {
                                onDismiss()
                            } else {
                                dismiss()
                            }
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        postNewPost()
                    }) {
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
            }
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
        }
    }

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
                    // Reload posts list
                    onPostCreated()
                    // Dismiss editor
                    dismiss()
                case .failure(let error):
                    Logger.shared.error("[NewPost] Failed to create post: \(error.localizedDescription)")
                    postError = "Failed to post: \(error.localizedDescription)"
                }
            }
        }
    }
}

// Image Picker wrapper for UIImagePickerController
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
