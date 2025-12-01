# Storage Implementation - iOS

*iOS-specific local storage using UserDefaults, CoreData, and FileManager*

## Key-Value Storage: UserDefaults

Use `UserDefaults` for simple login state:

```swift
import Foundation

class Storage {
    static let shared = Storage()
    private let defaults = UserDefaults.standard

    // Login state
    func saveLoginState(email: String, isLoggedIn: Bool) {
        defaults.set(email, forKey: "user_email")
        defaults.set(isLoggedIn, forKey: "is_logged_in")
    }

    func getLoginState() -> (email: String?, isLoggedIn: Bool) {
        let email = defaults.string(forKey: "user_email")
        let isLoggedIn = defaults.bool(forKey: "is_logged_in")
        return (email, isLoggedIn)
    }

    func clearLoginState() {
        defaults.removeObject(forKey: "user_email")
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
        return defaults.integer(forKey: key)
    }

    func getBool(_ key: String) -> Bool {
        return defaults.bool(forKey: key)
    }

    func remove(_ key: String) {
        defaults.removeObject(forKey: key)
    }

    func listKeys() -> [String] {
        return Array(defaults.dictionaryRepresentation().keys)
    }

    func clearAll() {
        if let bundleID = Bundle.main.bundleIdentifier {
            defaults.removePersistentDomain(forName: bundleID)
        }
    }
}
```

## Using in App Initialization

In `NoobTestApp.swift` or main app file:

```swift
@main
struct NoobTestApp: App {
    @State private var isLoggedIn = false
    @State private var userEmail: String?

    var body: some Scene {
        WindowGroup {
            if isLoggedIn, let email = userEmail {
                MainView(email: email)
            } else {
                LoginView(onLogin: { email in
                    self.userEmail = email
                    self.isLoggedIn = true
                    Storage.shared.saveLoginState(email: email, isLoggedIn: true)
                })
            }
        }
        .onAppear {
            // Check storage on startup
            let (email, loggedIn) = Storage.shared.getLoginState()
            self.userEmail = email
            self.isLoggedIn = loggedIn
        }
    }
}
```

## Future: Structured Storage with CoreData

For cached posts and complex data:

```swift
// Create CoreData model for Post
// Use NSPersistentContainer to manage storage
// Query cached posts with NSFetchRequest
```

## Future: File Storage

For images and media:

```swift
func saveImage(_ image: UIImage, filename: String) {
    guard let data = image.jpegData(compressionQuality: 0.8) else { return }
    let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    let filePath = documentsPath.appendingPathComponent(filename)

    try? data.write(to: filePath)
}

func loadImage(filename: String) -> UIImage? {
    let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    let filePath = documentsPath.appendingPathComponent(filename)

    guard let data = try? Data(contentsOf: filePath) else { return nil }
    return UIImage(data: data)
}
```

## Testing

Verify storage works:

```swift
func testStorage() -> TestResult {
    // Save test data
    Storage.shared.set("test_key_1", "test_value_1")
    Storage.shared.set("test_key_2", "test_value_2")
    Storage.shared.set("test_number", 42)
    Storage.shared.set("test_bool", true)

    // Retrieve and verify strings
    guard let value1 = Storage.shared.getString("test_key_1"),
          value1 == "test_value_1" else {
        return TestResult(success: false, error: "Failed to retrieve test_key_1")
    }

    // Verify number
    let number = Storage.shared.getInt("test_number")
    guard number == 42 else {
        return TestResult(success: false, error: "Failed to retrieve test_number")
    }

    // Verify boolean
    let bool = Storage.shared.getBool("test_bool")
    guard bool == true else {
        return TestResult(success: false, error: "Failed to retrieve test_bool")
    }

    // List all keys
    let keys = Storage.shared.listKeys()
    guard keys.contains("test_key_1") else {
        return TestResult(success: false, error: "test_key_1 not in keys list")
    }

    // Clear test data
    Storage.shared.remove("test_key_1")
    Storage.shared.remove("test_key_2")
    Storage.shared.remove("test_number")
    Storage.shared.remove("test_bool")

    // Verify cleared
    if Storage.shared.getString("test_key_1") != nil {
        return TestResult(success: false, error: "Failed to clear test_key_1")
    }

    return TestResult(success: true)
}
```

Register the test in app startup:

```swift
TestRegistry.shared.register(feature: "storage") {
    return testStorage()
}
```

## Important Notes

- UserDefaults is automatically synced to disk
- Don't store sensitive data (like passwords) in UserDefaults - use Keychain for that
- UserDefaults persists across app updates but is deleted on uninstall
- Maximum practical size for UserDefaults: ~1MB
