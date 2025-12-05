import SwiftUI

struct UpdateRequiredView: View {
    let testflightURL: String

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Icon
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)

            // Title
            Text("Update Available")
                .font(.title)
                .fontWeight(.bold)

            // Message
            Text("A new version of microclub is available. Please update to continue.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 32)

            Spacer()

            // Update button
            Button(action: openTestFlight) {
                Text("Update Now")
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
        .background(Color(.systemBackground))
    }

    func openTestFlight() {
        if let url = URL(string: testflightURL) {
            UIApplication.shared.open(url)
        }
    }
}
