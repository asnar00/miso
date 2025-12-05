import SwiftUI

struct NewUserView: View {
    let name: String
    let email: String
    @Binding var hasSeenWelcome: Bool
    @Binding var shouldEditProfile: Bool

    @State private var isCreatingProfile = false

    var body: some View {
        ZStack {
            // Background color
            Color(red: 255/255, green: 178/255, blue: 127/255)
                .ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                // Logo
                Text("ᕦ(ツ)ᕤ")
                    .font(.system(size: 50))
                    .foregroundColor(.black)
                    .padding(.top, 38)  // Move down by ~75% of height

                // Welcome text with name
                VStack(spacing: 8) {
                    Text("welcome")
                        .font(.largeTitle)
                        .foregroundColor(.black)
                    Text("\(name)!")
                        .font(.largeTitle)
                        .foregroundColor(.black)
                }

                Spacer()

                // Instruction text
                Text("next, please fill in your user profile so that other microclub members can see you.")
                    .font(.body)
                    .foregroundColor(.black.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                // Get Started button - creates profile then opens for editing
                Button(action: {
                    getStarted()
                }) {
                    if isCreatingProfile {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.black)
                            .cornerRadius(10)
                    } else {
                        Text("get started")
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.black)
                            .cornerRadius(10)
                    }
                }
                .disabled(isCreatingProfile)
                .padding(.horizontal, 40)
                .padding(.bottom, 60)
                .onAppear {
                    UIAutomationRegistry.shared.register(id: "newuser-getstarted") {
                        self.getStarted()
                    }
                }
            }
        }
    }

    func getStarted() {
        guard !isCreatingProfile else { return }
        isCreatingProfile = true

        Logger.shared.info("[NewUserView] Creating profile for new user: \(name)")

        // Create profile with user's name
        PostsAPI.shared.createProfile(title: name, summary: "", body: "", image: nil) { result in
            DispatchQueue.main.async {
                self.isCreatingProfile = false

                switch result {
                case .success(let profile):
                    Logger.shared.info("[NewUserView] Profile created successfully: \(profile.id)")
                    self.shouldEditProfile = true
                    self.hasSeenWelcome = true

                case .failure(let error):
                    Logger.shared.error("[NewUserView] Failed to create profile: \(error.localizedDescription)")
                    // Still proceed - the profile will be created on demand when needed
                    self.shouldEditProfile = true
                    self.hasSeenWelcome = true
                }
            }
        }
    }
}
