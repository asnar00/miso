# invite - iOS Implementation
*SwiftUI implementation for invite feature*

## InviteSheet View

Create new file `InviteSheet.swift`:

```swift
import SwiftUI

struct InviteSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var email: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String = ""
    @State private var showShareSheet: Bool = false
    @State private var shareMessage: String = ""

    let serverURL = "http://185.96.221.52:8080"

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Invite a Friend")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.top)

                TextField("friend@example.com", text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .keyboardType(.emailAddress)
                    .disabled(isLoading)
                    .padding(.horizontal)

                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.horizontal)
                }

                Button(action: sendInvite) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    } else {
                        Text("Send Invite")
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.black)
                            .cornerRadius(10)
                    }
                }
                .disabled(isLoading || email.isEmpty)
                .padding(.horizontal)

                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(activityItems: [shareMessage])
        }
    }

    func sendInvite() {
        errorMessage = ""
        isLoading = true

        guard let url = URL(string: "\\(serverURL)/api/invite") else {
            errorMessage = "Invalid server URL"
            isLoading = false
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let deviceID = Storage.shared.getDeviceID()
        let body: [String: Any] = [
            "email": email.lowercased().trimmingCharacters(in: .whitespaces),
            "device_id": deviceID
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false

                if let error = error {
                    errorMessage = "Connection error: \\(error.localizedDescription)"
                    return
                }

                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let status = json["status"] as? String else {
                    errorMessage = "Invalid response from server"
                    return
                }

                if status == "already_exists" {
                    errorMessage = "User already signed up!"
                    // Optionally: navigate to their profile or refresh users list
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        dismiss()
                    }
                } else if status == "invite_created" {
                    if let testflightLink = json["testflight_link"] as? String {
                        shareMessage = "Join me on Firefly! Download via TestFlight: \\(testflightLink)"
                        showShareSheet = true
                        Logger.shared.info("[Invite] Showing share sheet for \\(email)")
                    }
                } else {
                    errorMessage = json["message"] as? String ?? "Failed to create invite"
                }
            }
        }.resume()
    }
}
```

## ShareSheet (UIKit Wrapper)

Create new file `ShareSheet.swift`:

```swift
import SwiftUI
import UIKit

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
```

## Update ContentView

Modify `ContentView.swift` to show InviteSheet when "Invite Friend" button is tapped:

```swift
// Add state variable
@State private var showInviteSheet = false

// Modify PostsView for users tab
PostsView(
    initialPosts: usersPosts,
    onPostCreated: { fetchUsersPosts() },
    showAddButton: true,
    templateName: "profile",
    customAddButtonText: "Invite Friend",
    onAddButtonTapped: {
        // Show invite sheet instead of creating a post
        showInviteSheet = true
    },
    isAnyPostEditing: $isAnyPostEditing
)
.id(usersViewId)
.sheet(isPresented: $showInviteSheet) {
    InviteSheet()
}
```

## Update PostsView

Modify `PostsView.swift` to accept optional `onAddButtonTapped` callback:

```swift
struct PostsView: View {
    // ... existing parameters ...
    var onAddButtonTapped: (() -> Void)? = nil

    // In addPostButton:
    Button(action: {
        if let customAction = onAddButtonTapped {
            customAction()
        } else {
            // Existing add post logic
            createNewPost()
        }
    }) {
        // ... button UI ...
    }
}
```

## Notes

- `InviteSheet` handles both email checking and share sheet presentation
- `ShareSheet` wraps UIKit's `UIActivityViewController` for SwiftUI
- The "Invite Friend" button in Users tab triggers the invite flow instead of creating a profile post
- Share sheet allows user to choose sharing method (Messages, Email, WhatsApp, etc.)
