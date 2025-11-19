import Foundation
import Combine

class TunableConstants: ObservableObject {
    static let shared = TunableConstants()

    @Published private var constants: [String: Any] = [:]
    private let fileURL: URL

    private init() {
        // Use Documents directory for persistent storage
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = documentsPath.appendingPathComponent("live-constants.json")

        // If file doesn't exist in Documents, copy from bundle
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            if let bundlePath = Bundle.main.path(forResource: "live-constants", ofType: "json"),
               let bundleURL = URL(string: "file://" + bundlePath) {
                try? FileManager.default.copyItem(at: bundleURL, to: fileURL)
                Logger.shared.info("[TunableConstants] Copied live-constants.json from bundle to Documents")
            } else {
                Logger.shared.info("[TunableConstants] No bundle file, creating empty constants")
            }
        }

        loadConstants()
    }

    func loadConstants() {
        if FileManager.default.fileExists(atPath: fileURL.path) {
            do {
                let data = try Data(contentsOf: fileURL)
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    constants = json
                    Logger.shared.info("Loaded \(constants.count) constants from \(fileURL.path)")
                }
            } catch {
                Logger.shared.error("Error loading constants: \(error)")
                constants = [:]
            }
        } else {
            // Create empty file
            Logger.shared.info("No constants file found at \(fileURL.path), creating empty one")
            saveConstants()
        }
    }

    func get(_ key: String) -> Any? {
        return constants[key]
    }

    func getDouble(_ key: String, default defaultValue: Double = 0.0) -> Double {
        if let value = constants[key] as? Double {
            return value
        } else if let value = constants[key] as? Int {
            return Double(value)
        }
        return defaultValue
    }

    func getInt(_ key: String, default defaultValue: Int = 0) -> Int {
        if let value = constants[key] as? Int {
            return value
        } else if let value = constants[key] as? Double {
            return Int(value)
        }
        return defaultValue
    }

    func getString(_ key: String, default defaultValue: String = "") -> String {
        return constants[key] as? String ?? defaultValue
    }

    func set(_ key: String, value: Any) {
        constants[key] = value
        saveConstants()
        objectWillChange.send()
    }

    func getAll() -> [String: Any] {
        return constants
    }

    func setAll(_ newConstants: [String: Any]) {
        constants = newConstants
        saveConstants()
        objectWillChange.send()
    }

    private func saveConstants() {
        do {
            let data = try JSONSerialization.data(withJSONObject: constants, options: .prettyPrinted)
            try data.write(to: fileURL)
            Logger.shared.info("Saved constants to \(fileURL.path)")
        } catch {
            Logger.shared.error("Error saving constants: \(error)")
        }
    }
}
