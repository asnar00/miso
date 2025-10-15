import SwiftUI

struct NewUserView: View {
    let email: String
    @Binding var hasSeenWelcome: Bool

    var body: some View {
        ZStack {
            // Background color
            Color(red: 64/255, green: 224/255, blue: 208/255)
                .ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                // Logo
                Text("ᕦ(ツ)ᕤ")
                    .font(.system(size: 100))
                    .foregroundColor(.black)

                // Welcome text
                Text("welcome")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.black)

                // User email
                Text(email)
                    .font(.title3)
                    .foregroundColor(.black.opacity(0.8))

                Spacer()

                // Get Started button
                Button(action: {
                    hasSeenWelcome = true
                    Logger.shared.info("[NewUser] User tapped Get Started")
                }) {
                    Text("Get Started")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.black)
                        .cornerRadius(10)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 60)
            }
        }
    }
}
