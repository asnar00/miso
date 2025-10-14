import SwiftUI

@main
struct NoobTestApp: App {
    init() {
        Logger.shared.info("[APP] NoobTestApp init() called")
        // Start test server
        Logger.shared.info("[APP] About to start TestServer")
        TestServer.shared.start()
        Logger.shared.info("[APP] TestServer.start() returned")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
