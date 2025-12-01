# Profile Feature - iOS Implementation

## API Extensions

**File:** `apps/firefly/product/client/imp/ios/NoobTest/Post.swift`

Add these methods to the `PostsAPI` class:

```swift
// Fetch user's profile post
func fetchUserProfile(userId: Int, completion: @escaping (Result<Post?, Error>) -> Void) {
    guard let url = URL(string: "\(serverURL)/api/users/\(userId)/profile") else {
        completion(.failure(NSError(domain: "Invalid URL", code: -1)))
        return
    }

    Logger.shared.info("[PostsAPI] Fetching profile for user \(userId)")

    URLSession.shared.dataTask(with: url) { data, response, error in
        if let error = error {
            Logger.shared.error("[PostsAPI] Error fetching profile: \(error.localizedDescription)")
            completion(.failure(error))
            return
        }

        guard let data = data else {
            Logger.shared.error("[PostsAPI] No data received")
            completion(.failure(NSError(domain: "No data", code: -1)))
            return
        }

        do {
            let profileResponse = try JSONDecoder().decode(ProfileResponse.self, from: data)
            Logger.shared.info("[PostsAPI] Successfully fetched profile")
            completion(.success(profileResponse.profile))
        } catch {
            Logger.shared.error("[PostsAPI] JSON decode error: \(error.localizedDescription)")
            completion(.failure(error))
        }
    }.resume()
}

// Create a new profile post
func createProfile(title: String, summary: String, body: String, image: UIImage?, completion: @escaping (Result<Post, Error>) -> Void) {
    guard let url = URL(string: "\(serverURL)/api/users/profile/create") else {
        completion(.failure(NSError(domain: "Invalid URL", code: -1)))
        return
    }

    // Get user email
    let loginState = Storage.shared.getLoginState()
    guard let email = loginState.email, loginState.isLoggedIn else {
        Logger.shared.error("[PostsAPI] User not logged in")
        completion(.failure(NSError(domain: "Not authenticated", code: 401)))
        return
    }

    Logger.shared.info("[PostsAPI] Creating profile for user: \(email)")

    // Get current timezone
    let timezone = TimeZone.current.identifier

    // Create multipart form data
    let boundary = UUID().uuidString
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

    var requestBody = Data()

    // Add text fields
    let fields = [
        "email": email,
        "title": title,
        "summary": summary,
        "body": body,
        "timezone": timezone
    ]

    for (key, value) in fields {
        requestBody.append("--\(boundary)\r\n".data(using: .utf8)!)
        requestBody.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
        requestBody.append("\(value)\r\n".data(using: .utf8)!)
    }

    // Add image if present
    if let image = image, let imageData = image.jpegData(compressionQuality: 0.8) {
        requestBody.append("--\(boundary)\r\n".data(using: .utf8)!)
        requestBody.append("Content-Disposition: form-data; name=\"image\"; filename=\"profile.jpg\"\r\n".data(using: .utf8)!)
        requestBody.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        requestBody.append(imageData)
        requestBody.append("\r\n".data(using: .utf8)!)
    }

    requestBody.append("--\(boundary)--\r\n".data(using: .utf8)!)
    request.httpBody = requestBody

    URLSession.shared.dataTask(with: request) { data, response, error in
        if let error = error {
            Logger.shared.error("[PostsAPI] Error creating profile: \(error.localizedDescription)")
            completion(.failure(error))
            return
        }

        guard let data = data else {
            Logger.shared.error("[PostsAPI] No data received")
            completion(.failure(NSError(domain: "No data", code: -1)))
            return
        }

        do {
            let profileResponse = try JSONDecoder().decode(ProfileResponse.self, from: data)
            Logger.shared.info("[PostsAPI] Successfully created profile")
            completion(.success(profileResponse.profile))
        } catch {
            Logger.shared.error("[PostsAPI] JSON decode error: \(error.localizedDescription)")
            if let responseString = String(data: data, encoding: .utf8) {
                Logger.shared.error("[PostsAPI] Response: \(responseString)")
            }
            completion(.failure(error))
        }
    }.resume()
}

// Update an existing profile post
func updateProfile(postId: Int, title: String, summary: String, body: String, image: UIImage?, completion: @escaping (Result<Post, Error>) -> Void) {
    guard let url = URL(string: "\(serverURL)/api/users/profile/update") else {
        completion(.failure(NSError(domain: "Invalid URL", code: -1)))
        return
    }

    // Get user email
    let loginState = Storage.shared.getLoginState()
    guard let email = loginState.email, loginState.isLoggedIn else {
        Logger.shared.error("[PostsAPI] User not logged in")
        completion(.failure(NSError(domain: "Not authenticated", code: 401)))
        return
    }

    Logger.shared.info("[PostsAPI] Updating profile \(postId) for user: \(email)")

    // Create multipart form data
    let boundary = UUID().uuidString
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

    var requestBody = Data()

    // Add text fields
    let fields = [
        "post_id": String(postId),
        "email": email,
        "title": title,
        "summary": summary,
        "body": body
    ]

    for (key, value) in fields {
        requestBody.append("--\(boundary)\r\n".data(using: .utf8)!)
        requestBody.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
        requestBody.append("\(value)\r\n".data(using: .utf8)!)
    }

    // Add image if present
    if let image = image, let imageData = image.jpegData(compressionQuality: 0.8) {
        requestBody.append("--\(boundary)\r\n".data(using: .utf8)!)
        requestBody.append("Content-Disposition: form-data; name=\"image\"; filename=\"profile.jpg\"\r\n".data(using: .utf8)!)
        requestBody.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        requestBody.append(imageData)
        requestBody.append("\r\n".data(using: .utf8)!)
    }

    requestBody.append("--\(boundary)--\r\n".data(using: .utf8)!)
    request.httpBody = requestBody

    URLSession.shared.dataTask(with: request) { data, response, error in
        if let error = error {
            Logger.shared.error("[PostsAPI] Error updating profile: \(error.localizedDescription)")
            completion(.failure(error))
            return
        }

        guard let data = data else {
            Logger.shared.error("[PostsAPI] No data received")
            completion(.failure(NSError(domain: "No data", code: -1)))
            return
        }

        do {
            let profileResponse = try JSONDecoder().decode(ProfileResponse.self, from: data)
            Logger.shared.info("[PostsAPI] Successfully updated profile")
            completion(.success(profileResponse.profile))
        } catch {
            Logger.shared.error("[PostsAPI] JSON decode error: \(error.localizedDescription)")
            if let responseString = String(data: data, encoding: .utf8) {
                Logger.shared.error("[PostsAPI] Response: \(responseString)")
            }
            completion(.failure(error))
        }
    }.resume()
}
```

Add response structure after `ChildrenResponse`:

```swift
struct ProfileResponse: Codable {
    let status: String
    let profile: Post?
}
```

## UI Components

**File:** `apps/firefly/product/client/imp/ios/NoobTest/PostsView.swift`

Update the profile button handler and add state:

```swift
// Add these state variables after line 9:
@State private var showProfileView = false
@State private var profilePost: Post? = nil
@State private var isLoadingProfile = false

// Replace the onProfileButtonTap closure (line ~75) with:
onProfileButtonTap: {
    isLoadingProfile = true
    let loginState = Storage.shared.getLoginState()

    if let userId = loginState.userId {
        PostsAPI.shared.fetchUserProfile(userId: userId) { result in
            DispatchQueue.main.async {
                isLoadingProfile = false
                switch result {
                case .success(let profile):
                    profilePost = profile
                    showProfileView = true
                case .failure(let error):
                    Logger.shared.error("[PostsView] Failed to fetch profile: \(error.localizedDescription)")
                }
            }
        }
    } else {
        isLoadingProfile = false
        Logger.shared.error("[PostsView] No user ID found")
    }
}
```

Add profile view presentation in the ZStack (after the toolbar, around line 80):

```swift
// Profile view overlay
if showProfileView {
    Color.black.opacity(0.3)
        .ignoresSafeArea()
        .onTapGesture {
            showProfileView = false
        }

    ProfileView(
        profile: profilePost,
        onDismiss: {
            showProfileView = false
        },
        onProfileUpdated: { updatedProfile in
            profilePost = updatedProfile
        }
    )
    .transition(.move(edge: .bottom))
}
```

**New File:** `apps/firefly/product/client/imp/ios/NoobTest/ProfileView.swift`

```swift
import SwiftUI

struct ProfileView: View {
    let profile: Post?
    let onDismiss: () -> Void
    let onProfileUpdated: (Post) -> Void

    @State private var showEditor = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(profile == nil ? "Create Profile" : "Profile")
                    .font(.headline)
                    .padding()

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .foregroundColor(.gray)
                        .padding()
                }
            }
            .background(Color.white)

            if let profile = profile {
                // Show existing profile
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        // Title (Name)
                        Text(profile.title)
                            .font(.title)
                            .fontWeight(.bold)

                        // Summary (Profession/Mission)
                        Text(profile.summary)
                            .font(.subheadline)
                            .foregroundColor(.gray)

                        // Image if present
                        if let imageUrl = profile.imageUrl {
                            AsyncImage(url: URL(string: "http://185.96.221.52:8080\(imageUrl)")) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                ProgressView()
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 200)
                            .clipped()
                            .cornerRadius(8)
                        }

                        // Body text
                        Text(profile.body)
                            .font(.body)

                        Spacer()
                    }
                    .padding()
                }

                // Edit button (pen icon)
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            showEditor = true
                        }) {
                            Image(systemName: "pencil")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                                .frame(width: 56, height: 56)
                                .background(Color.black)
                                .clipShape(Circle())
                                .shadow(radius: 4)
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 80)  // Above toolbar
                    }
                }
            } else {
                // No profile yet - show create button
                VStack {
                    Spacer()
                    Text("You don't have a profile yet")
                        .foregroundColor(.gray)
                        .padding()
                    Button("Create Profile") {
                        showEditor = true
                    }
                    .padding()
                    .background(Color.black)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    Spacer()
                }
            }
        }
        .background(Color.white)
        .cornerRadius(20)
        .padding()
        .sheet(isPresented: $showEditor) {
            ProfileEditor(
                profile: profile,
                onSave: { updatedProfile in
                    onProfileUpdated(updatedProfile)
                    showEditor = false
                },
                onDismiss: {
                    showEditor = false
                }
            )
        }
    }
}
```

**New File:** `apps/firefly/product/client/imp/ios/NoobTest/ProfileEditor.swift`

```swift
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
```

## Storage Extension

**File:** `apps/firefly/product/client/imp/ios/NoobTest/Storage.swift`

Add `userId` to `LoginState`:

Find the `LoginState` struct and add:
```swift
struct LoginState: Codable {
    let isLoggedIn: Bool
    let email: String?
    let userId: Int?  // Add this line
}
```

Update `saveLoginState` to accept userId:
```swift
func saveLoginState(isLoggedIn: Bool, email: String?, userId: Int?) {
    let loginState = LoginState(isLoggedIn: isLoggedIn, email: email, userId: userId)
    // ... rest of function
}
```

## Patching Instructions

1. **Add API methods to Post.swift** - Add the three new methods and ProfileResponse struct to the PostsAPI class
2. **Update PostsView.swift** - Add state variables and update onProfileButtonTap handler, add profile view overlay
3. **Create ProfileView.swift** - New file with profile display component
4. **Create ProfileEditor.swift** - New file with profile editing component
5. **Update Storage.swift** - Add userId to LoginState struct and update saveLoginState
6. **Update sign-in flow** - When user signs in, save the userId from the server response

The files need to be added to the Xcode project using the ios-add-file skill.
