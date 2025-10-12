import SwiftUI
import OSLog

struct ContentView: View {
    // Server configuration
    let serverURL = "http://185.96.221.52:8080"

    // Logger
    let logger = Logger.shared

    // State variables for ping and background features
    @State private var backgroundColor = Color.gray
    @State private var timer: Timer?

    var body: some View {
        ZStack {
            // Background color changes based on connection status
            backgroundColor
                .ignoresSafeArea()

            // Logo at 75% width - using GeometryReader to calculate size
            GeometryReader { geometry in
                Text("ᕦ(ツ)ᕤ")
                    .font(.system(size: geometry.size.width * 0.75 * 0.25))
                    .foregroundColor(.black)
                    .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
        .onAppear { startPeriodicCheck() }
        .onDisappear { timer?.invalidate() }
    }

    func startPeriodicCheck() {
        logger.info("App started, beginning periodic connection checks")

        // Check immediately on startup
        testConnection()

        // Then check every 1 second
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            testConnection()
        }
    }

    func testConnection() {
        logger.info("------------ ping")

        guard let url = URL(string: "\(serverURL)/api/ping") else {
            logger.error("Invalid server URL: \(serverURL)")
            backgroundColor = Color.gray
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    // Connection failed - gray background
                    logger.warning("Connection failed: \(error.localizedDescription)")
                    backgroundColor = Color.gray
                    return
                }

                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 200 {
                        // Connection successful - turquoise background
                        logger.debug("Connection successful - status 200")
                        backgroundColor = Color(red: 64/255, green: 224/255, blue: 208/255)
                    } else {
                        // Server returned error - gray background
                        logger.warning("Unexpected status code: \(httpResponse.statusCode)")
                        backgroundColor = Color.gray
                    }
                }
            }
        }.resume()
    }
}

#Preview {
    ContentView()
}
