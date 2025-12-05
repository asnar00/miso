import Foundation
import Combine
import SwiftUI

class TunableConstants: ObservableObject {
    static let shared = TunableConstants()

    @Published private var constants: [String: Any] = [:]
    private let fileURL: URL

    private init() {
        // Use Documents directory for persistent storage
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = documentsPath.appendingPathComponent("live-constants.json")

        // Check if build number changed - if so, replace constants from bundle
        let currentBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        let savedBuild = UserDefaults.standard.string(forKey: "lastTunablesBuildNumber") ?? "0"

        if currentBuild != savedBuild {
            // Delete existing constants file to force refresh from bundle
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try? FileManager.default.removeItem(at: fileURL)
            }
            // Save new build number
            UserDefaults.standard.set(currentBuild, forKey: "lastTunablesBuildNumber")
        }

        // If file doesn't exist in Documents, copy from bundle
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            if let bundlePath = Bundle.main.path(forResource: "live-constants", ofType: "json") {
                let bundleURL = URL(fileURLWithPath: bundlePath)
                try? FileManager.default.copyItem(at: bundleURL, to: fileURL)
            }
        }

        loadConstants()
        mergeBundleDefaults()
    }

    private func mergeBundleDefaults() {
        guard let bundlePath = Bundle.main.path(forResource: "live-constants", ofType: "json"),
              let bundleData = try? Data(contentsOf: URL(fileURLWithPath: bundlePath)),
              let bundleConstants = try? JSONSerialization.jsonObject(with: bundleData) as? [String: Any] else {
            return
        }

        var updated = false
        for (key, value) in bundleConstants {
            if constants[key] == nil {
                constants[key] = value
                updated = true
            }
        }

        if updated {
            saveConstants()
        }
    }

    func loadConstants() {
        if FileManager.default.fileExists(atPath: fileURL.path) {
            do {
                let data = try Data(contentsOf: fileURL)
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    constants = json
                }
            } catch {
                constants = [:]
            }
        } else {
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

    /// Returns the button colour based on base RGB values modified by brightness
    func buttonColor() -> Color {
        let r = getDouble("button-colour-r", default: 255) / 255.0
        let g = getDouble("button-colour-g", default: 178) / 255.0
        let b = getDouble("button-colour-b", default: 127) / 255.0
        let brightness = getDouble("button-brightness", default: 1.0)

        return Color(
            red: r * brightness,
            green: g * brightness,
            blue: b * brightness
        )
    }

    /// Returns the button highlight colour (1.2x the standard button colour, clamped to 1.0)
    func buttonHighlightColor() -> Color {
        let r = getDouble("button-colour-r", default: 255) / 255.0
        let g = getDouble("button-colour-g", default: 178) / 255.0
        let b = getDouble("button-colour-b", default: 127) / 255.0
        let brightness = getDouble("button-brightness", default: 1.0) * 1.2

        return Color(
            red: min(r * brightness, 1.0),
            green: min(g * brightness, 1.0),
            blue: min(b * brightness, 1.0)
        )
    }

    /// Returns the background colour
    func backgroundColor() -> Color {
        let r = getDouble("background-colour-r", default: 0) / 255.0
        let g = getDouble("background-colour-g", default: 0) / 255.0
        let b = getDouble("background-colour-b", default: 0) / 255.0

        return Color(red: r, green: g, blue: b)
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
        } catch {
            // Silent fail
        }
    }
}
