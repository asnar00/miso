import SwiftUI
import PhotosUI

struct ProfileEditor: View {
    let profile: Post?
    let onSave: (Post) -> Void
    let onDismiss: () -> Void

    @State private var name: String
    @State private var tagline: String
    @State private var about: String
    @State private var selectedImage: PhotosPickerItem?
    @State private var profileImage: UIImage?
    @State private var isSaving = false

    init(profile: Post?, onSave: @escaping (Post) -> Void, onDismiss: @escaping () -> Void) {
        self.profile = profile
        self.onSave = onSave
        self.onDismiss = onDismiss

        _name = State(initialValue: profile?.title ?? "")
        _tagline = State(initialValue: profile?.summary ?? "")
        _about = State(initialValue: profile?.body ?? "")
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Basic Info")) {
                    TextField("Name", text: $name)
                    TextField("Profession / Mission", text: $tagline)
                }

                Section(header: Text("Photo")) {
                    PhotosPicker(selection: $selectedImage, matching: .images) {
                        if let profileImage = profileImage {
                            Image(uiImage: profileImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 200)
                                .clipped()
                                .cornerRadius(8)
                        } else if let imageUrl = profile?.imageUrl {
                            AsyncImage(url: URL(string: "http://185.96.221.52:8080\(imageUrl)")) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                ProgressView()
                            }
                            .frame(height: 200)
                            .clipped()
                            .cornerRadius(8)
                        } else {
                            Text("Tap to add photo")
                                .foregroundColor(.gray)
                        }
                    }
                }

                Section(header: Text("About (up to 300 words)")) {
                    TextEditor(text: $about)
                        .frame(minHeight: 200)
                }
            }
            .navigationTitle(profile == nil ? "Create Profile" : "Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onDismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveProfile()
                    }
                    .disabled(name.isEmpty || tagline.isEmpty || about.isEmpty || isSaving)
                }
            }
        }
        .onChange(of: selectedImage) { newValue in
            Task {
                if let data = try? await newValue?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    profileImage = image
                }
            }
        }
    }

    private func saveProfile() {
        isSaving = true

        if let profile = profile {
            // Update existing profile
            PostsAPI.shared.updateProfile(
                postId: profile.id,
                title: name,
                summary: tagline,
                body: about,
                image: profileImage
            ) { result in
                DispatchQueue.main.async {
                    isSaving = false
                    switch result {
                    case .success(let updatedProfile):
                        onSave(updatedProfile)
                    case .failure(let error):
                        Logger.shared.error("[ProfileEditor] Failed to update profile: \(error.localizedDescription)")
                    }
                }
            }
        } else {
            // Create new profile
            PostsAPI.shared.createProfile(
                title: name,
                summary: tagline,
                body: about,
                image: profileImage
            ) { result in
                DispatchQueue.main.async {
                    isSaving = false
                    switch result {
                    case .success(let newProfile):
                        onSave(newProfile)
                    case .failure(let error):
                        Logger.shared.error("[ProfileEditor] Failed to create profile: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
}
