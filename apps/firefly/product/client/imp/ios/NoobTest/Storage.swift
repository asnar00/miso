import Foundation

class Storage {
    static let shared = Storage()
    private let defaults = UserDefaults.standard

    private init() {}

    // Login state
    func saveLoginState(email: String, userId: Int, isLoggedIn: Bool) {
        defaults.set(email, forKey: "user_email")
        defaults.set(userId, forKey: "user_id")
        defaults.set(isLoggedIn, forKey: "is_logged_in")
    }

    func getLoginState() -> (email: String?, userId: Int?, isLoggedIn: Bool) {
        let email = defaults.string(forKey: "user_email")
        let userId = defaults.object(forKey: "user_id") as? Int
        let isLoggedIn = defaults.bool(forKey: "is_logged_in")
        return (email, userId, isLoggedIn)
    }

    func clearLoginState() {
        defaults.removeObject(forKey: "user_email")
        defaults.removeObject(forKey: "user_id")
        defaults.removeObject(forKey: "is_logged_in")
    }

    // Device ID
    func getDeviceID() -> String {
        if let existingID = defaults.string(forKey: "device_id") {
            return existingID
        }

        let newID = UUID().uuidString
        defaults.set(newID, forKey: "device_id")
        return newID
    }

    // Generic storage operations
    func set(_ key: String, _ value: Any) {
        defaults.set(value, forKey: key)
    }

    func get(_ key: String) -> Any? {
        return defaults.object(forKey: key)
    }

    func getString(_ key: String) -> String? {
        return defaults.string(forKey: key)
    }

    func getInt(_ key: String) -> Int? {
        let value = defaults.object(forKey: key)
        return value as? Int
    }

    func getBool(_ key: String) -> Bool {
        return defaults.bool(forKey: key)
    }

    func remove(_ key: String) {
        defaults.removeObject(forKey: key)
    }

    func listKeys() -> [String] {
        return Array(defaults.dictionaryRepresentation().keys).sorted()
    }

    func listAll() -> [(String, String)] {
        let dict = defaults.dictionaryRepresentation()
        return dict.map { (key, value) in
            return (key, "\(value)")
        }.sorted { $0.0 < $1.0 }
    }

    func clearAll() {
        if let bundleID = Bundle.main.bundleIdentifier {
            defaults.removePersistentDomain(forName: bundleID)
        }
    }
}

// Test function
func testStorage() -> TestResult {
    Logger.shared.info("[TEST:storage] Starting storage test")

    // Save test data
    Logger.shared.info("[TEST:storage] Saving test data...")
    Storage.shared.set("test_key_1", "test_value_1")
    Storage.shared.set("test_key_2", "test_value_2")
    Storage.shared.set("test_number", 42)
    Storage.shared.set("test_bool", true)
    Logger.shared.info("[TEST:storage] Test data saved")

    // Retrieve and verify strings
    Logger.shared.info("[TEST:storage] Verifying string retrieval...")
    guard let value1 = Storage.shared.getString("test_key_1"),
          value1 == "test_value_1" else {
        Logger.shared.error("[TEST:storage] Failed to retrieve test_key_1")
        return TestResult(success: false, error: "Failed to retrieve test_key_1")
    }
    Logger.shared.info("[TEST:storage] String retrieval OK: test_key_1 = '\(value1)'")

    // Verify number
    Logger.shared.info("[TEST:storage] Verifying number retrieval...")
    let number = Storage.shared.getInt("test_number")
    guard number == 42 else {
        Logger.shared.error("[TEST:storage] Failed to retrieve test_number: got \(String(describing: number))")
        return TestResult(success: false, error: "Failed to retrieve test_number: got \(String(describing: number))")
    }
    Logger.shared.info("[TEST:storage] Number retrieval OK: test_number = \(number!)")

    // Verify boolean
    Logger.shared.info("[TEST:storage] Verifying boolean retrieval...")
    let bool = Storage.shared.getBool("test_bool")
    guard bool == true else {
        Logger.shared.error("[TEST:storage] Failed to retrieve test_bool")
        return TestResult(success: false, error: "Failed to retrieve test_bool")
    }
    Logger.shared.info("[TEST:storage] Boolean retrieval OK: test_bool = \(bool)")

    // List all keys
    Logger.shared.info("[TEST:storage] Listing all keys...")
    let keys = Storage.shared.listKeys()
    Logger.shared.info("[TEST:storage] Found \(keys.count) keys")
    guard keys.contains("test_key_1") else {
        Logger.shared.error("[TEST:storage] test_key_1 not in keys list")
        return TestResult(success: false, error: "test_key_1 not in keys list")
    }
    Logger.shared.info("[TEST:storage] Key listing OK")

    // Clear test data
    Logger.shared.info("[TEST:storage] Clearing test data...")
    Storage.shared.remove("test_key_1")
    Storage.shared.remove("test_key_2")
    Storage.shared.remove("test_number")
    Storage.shared.remove("test_bool")
    Logger.shared.info("[TEST:storage] Test data removed")

    // Verify cleared
    Logger.shared.info("[TEST:storage] Verifying data was cleared...")
    if Storage.shared.getString("test_key_1") != nil {
        Logger.shared.error("[TEST:storage] Failed to clear test_key_1")
        return TestResult(success: false, error: "Failed to clear test_key_1")
    }
    Logger.shared.info("[TEST:storage] Clear verification OK")

    Logger.shared.info("[TEST:storage] All storage operations passed!")
    return TestResult(success: true)
}
