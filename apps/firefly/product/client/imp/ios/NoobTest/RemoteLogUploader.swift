import Foundation
import UIKit

class RemoteLogUploader {
    static let shared = RemoteLogUploader()

    private var timer: Timer?
    private let uploadInterval: TimeInterval = 60  // 60 seconds
    private let serverURL: String
    private let deviceId: String

    private init() {
        // Hardcoded server URL (same as used throughout the app)
        serverURL = "http://185.96.221.52:8080"

        // Get or create persistent device ID
        if let existingId = UserDefaults.standard.string(forKey: "remoteLogDeviceId") {
            deviceId = existingId
        } else {
            let newId = UUID().uuidString
            UserDefaults.standard.set(newId, forKey: "remoteLogDeviceId")
            deviceId = newId
        }
    }

    func startPeriodicUpload() {
        // Upload immediately on start
        uploadLogs()

        // Then schedule periodic uploads
        timer = Timer.scheduledTimer(withTimeInterval: uploadInterval, repeats: true) { [weak self] _ in
            self?.uploadLogs()
        }
        Logger.shared.info("[RemoteLogUploader] Started periodic log uploads (every \(Int(uploadInterval))s)")
    }

    func stopPeriodicUpload() {
        timer?.invalidate()
        timer = nil
        Logger.shared.info("[RemoteLogUploader] Stopped periodic log uploads")
    }

    func uploadLogs() {
        // Get log contents
        guard let logContents = Logger.shared.getLogContents() else {
            return
        }

        // Get device info
        let deviceName = UIDevice.current.name
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"

        // Get tunables
        let tunables = TunableConstants.shared.getAll()

        // Build payload
        let payload: [String: Any] = [
            "deviceId": deviceId,
            "deviceName": deviceName,
            "appVersion": appVersion,
            "buildNumber": buildNumber,
            "logs": logContents,
            "tunables": tunables
        ]

        // POST to server
        guard let url = URL(string: "\(serverURL)/api/debug/logs") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            Logger.shared.error("[RemoteLogUploader] Failed to serialize payload: \(error)")
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                Logger.shared.warning("[RemoteLogUploader] Upload failed: \(error.localizedDescription)")
                return
            }

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                Logger.shared.debug("[RemoteLogUploader] Logs uploaded successfully")
            }
        }.resume()
    }
}
