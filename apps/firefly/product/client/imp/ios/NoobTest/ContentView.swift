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

    init() {
        // Register ping test
        TestRegistry.shared.register(feature: "ping") {
            return Self.testPingFeature()
        }
    }

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
        // Check immediately on startup
        testConnection()

        // Then check every 1 second
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            testConnection()
        }
    }

    func testConnection() {
        guard let url = URL(string: "\(serverURL)/api/ping") else {
            backgroundColor = Color.gray
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    // Connection failed - gray background
                    backgroundColor = Color.gray
                    return
                }

                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 200 {
                        // Connection successful - turquoise background
                        backgroundColor = Color(red: 64/255, green: 224/255, blue: 208/255)
                    } else {
                        // Server returned error - gray background
                        backgroundColor = Color.gray
                    }
                }
            }
        }.resume()
    }

    // Test function for ping feature
    static func testPingFeature() -> TestResult {
        Logger.shared.info("[TEST:ping] Starting ping test")

        let serverURL = "http://185.96.221.52:8080"
        Logger.shared.info("[TEST:ping] Server URL: \(serverURL)")
        guard let url = URL(string: "\(serverURL)/api/ping") else {
            Logger.shared.error("[TEST:ping] Invalid server URL")
            return TestResult(success: false, error: "Invalid server URL")
        }

        var result = TestResult(success: false, error: "Timeout")
        let semaphore = DispatchSemaphore(value: 0)

        Logger.shared.info("[TEST:ping] Sending HTTP request...")
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                Logger.shared.error("[TEST:ping] Connection failed: \(error.localizedDescription)")
                result = TestResult(success: false, error: "Connection failed: \(error.localizedDescription)")
                semaphore.signal()
                return
            }

            if let httpResponse = response as? HTTPURLResponse {
                Logger.shared.info("[TEST:ping] Received response with status: \(httpResponse.statusCode)")
                if httpResponse.statusCode == 200 {
                    Logger.shared.info("[TEST:ping] Ping successful!")
                    result = TestResult(success: true)
                } else {
                    Logger.shared.error("[TEST:ping] Unexpected status code: \(httpResponse.statusCode)")
                    result = TestResult(success: false, error: "Server returned status \(httpResponse.statusCode)")
                }
            }
            semaphore.signal()
        }.resume()

        Logger.shared.info("[TEST:ping] Waiting for response (timeout: 2s)...")
        let timedOut = semaphore.wait(timeout: .now() + 2.0)
        if timedOut == .timedOut {
            Logger.shared.error("[TEST:ping] Request timed out")
        }

        return result
    }
}

#Preview {
    ContentView()
}
