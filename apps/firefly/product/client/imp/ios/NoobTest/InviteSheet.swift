import SwiftUI

struct InviteSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var email: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String = ""
    @State private var showSuccess: Bool = false
    @State private var inviteMessage: String = ""
    @State private var testflightLink: String = ""
    @State private var copiedMessage: Bool = false

    let serverURL = "http://185.96.221.52:8080"

    var body: some View {
        NavigationView {
            if showSuccess {
                successView
            } else {
                inputView
            }
        }
    }

    var inputView: some View {
        VStack(spacing: 20) {
            Text("Invite a Friend")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.top)

            TextField("Friend's name", text: $name)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .autocapitalization(.words)
                .disabled(isLoading)
                .padding(.horizontal)

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
                    Text("Invite")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.black)
                        .cornerRadius(10)
                }
            }
            .disabled(isLoading || name.isEmpty || email.isEmpty)
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

    var successView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)

            Text("Invite Created!")
                .font(.title)
                .fontWeight(.bold)

            Text("Send this link to \(name):")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            // Link box
            Text(testflightLink)
                .font(.body)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .padding(.horizontal, 32)

            Button(action: copyLink) {
                HStack {
                    Image(systemName: copiedMessage ? "checkmark" : "doc.on.doc")
                    Text(copiedMessage ? "Copied!" : "Copy Link")
                }
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(copiedMessage ? Color.green : Color.blue)
                .cornerRadius(10)
            }
            .padding(.horizontal, 32)

            Spacer()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }

    func copyLink() {
        UIPasteboard.general.string = testflightLink
        copiedMessage = true
        Logger.shared.info("[Invite] Link copied to clipboard")

        // Reset after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            copiedMessage = false
        }
    }

    func sendInvite() {
        errorMessage = ""
        isLoading = true

        guard let url = URL(string: "\(serverURL)/api/invite") else {
            errorMessage = "Invalid server URL"
            isLoading = false
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let deviceID = Storage.shared.getDeviceID()
        let body: [String: Any] = [
            "name": name.trimmingCharacters(in: .whitespaces),
            "email": email.lowercased().trimmingCharacters(in: .whitespaces),
            "device_id": deviceID
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false

                if let error = error {
                    errorMessage = "Connection error: \(error.localizedDescription)"
                    return
                }

                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let status = json["status"] as? String else {
                    errorMessage = "Invalid response from server"
                    return
                }

                if status == "already_exists" {
                    let existingName = json["user_name"] as? String ?? "User"
                    errorMessage = "\(existingName) is already signed up!"
                    Logger.shared.info("[Invite] User \(email) already exists")
                } else if status == "invite_created" {
                    if let message = json["invite_message"] as? String,
                       let link = json["testflight_link"] as? String {
                        inviteMessage = message
                        testflightLink = link
                        showSuccess = true
                        Logger.shared.info("[Invite] Created invite for \(email)")
                    }
                } else {
                    errorMessage = json["message"] as? String ?? "Failed to create invite"
                }
            }
        }.resume()
    }
}

#Preview {
    InviteSheet()
}
