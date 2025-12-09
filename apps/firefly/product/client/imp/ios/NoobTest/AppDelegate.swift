import UIKit
import UserNotifications

// Notification name for when push notification is received in foreground
extension Notification.Name {
    static let pushNotificationReceived = Notification.Name("pushNotificationReceived")
    static let scrollToTopIfNotExpanded = Notification.Name("scrollToTopIfNotExpanded")
}

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        // Set notification delegate
        UNUserNotificationCenter.current().delegate = self

        // Request notification permissions
        requestNotificationPermissions(application)

        return true
    }

    private func requestNotificationPermissions(_ application: UIApplication) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error = error {
                Logger.shared.error("[PUSH] Permission error: \(error.localizedDescription)")
                return
            }

            if granted {
                Logger.shared.info("[PUSH] Permission granted")
                DispatchQueue.main.async {
                    application.registerForRemoteNotifications()
                }
            } else {
                Logger.shared.info("[PUSH] Permission denied")
            }
        }
    }

    // MARK: - Device Token Registration

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02x", $0) }.joined()
        Logger.shared.info("[PUSH] Device token: \(tokenString)")

        // Send token to server
        registerDeviceToken(tokenString)
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        Logger.shared.error("[PUSH] Failed to register: \(error.localizedDescription)")
    }

    private func registerDeviceToken(_ token: String) {
        let deviceId = Storage.shared.getDeviceID()
        let serverURL = "http://185.96.221.52:8080"
        guard let url = URL(string: "\(serverURL)/api/notifications/register-device") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "device_id": deviceId,
            "apns_token": token
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                Logger.shared.error("[PUSH] Token registration failed: \(error.localizedDescription)")
                return
            }
            Logger.shared.info("[PUSH] Token registered with server")
        }.resume()
    }

    // MARK: - Notification Handling

    // Called when notification received while app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        Logger.shared.info("[PUSH] Received in foreground: \(notification.request.content.title)")

        // Notify ContentView to refresh posts
        NotificationCenter.default.post(name: .pushNotificationReceived, object: nil)

        // Show banner, play sound, and update badge even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }

    // Called when user taps on notification
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        Logger.shared.info("[PUSH] User tapped notification: \(response.notification.request.content.title)")
        completionHandler()
    }
}
