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
