# live-constants iOS implementation

## TunableConstants Class

**File:** `apps/firefly/product/client/imp/ios/NoobTest/TunableConstants.swift`

**Critical implementation details:**
- Uses Documents directory for persistent storage (survives app updates)
- Bundles live-constants.json as app resource via project.pbxproj
- On first run, copies bundled JSON to Documents directory
- All changes write to Documents copy, not bundle
- Uses @Published to trigger SwiftUI re-renders when values change

```swift
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
```

## Test Server Endpoints

**File:** `apps/firefly/product/client/imp/ios/NoobTest/TestServer.swift`

Add these handler functions to the TestServer class:

```swift
private func handleGetTunables() -> String {
    let constants = TunableConstants.shared.getAll()
    if let jsonData = try? JSONSerialization.data(withJSONObject: constants, options: .prettyPrinted),
       let jsonString = String(data: jsonData, encoding: .utf8) {
        Logger.shared.info("[TESTSERVER] Returning all tunables")
        return httpResponse(jsonString, status: "200 OK", contentType: "application/json")
    }
    return httpResponse("Error serializing constants", status: "500 Internal Server Error")
}

private func handleSetTunable(path: String) -> String {
    // Extract key and value from path: /tune/:key/:value
    let pathComponents = path.split(separator: "/")
    guard pathComponents.count >= 3 else {
        return httpResponse("Invalid path format", status: "400 Bad Request")
    }

    let key = String(pathComponents[1])
    let valueStr = String(pathComponents[2])

    // Try to parse as number first, then string
    let value: Any
    if let doubleValue = Double(valueStr) {
        value = doubleValue
    } else {
        value = valueStr
    }

    TunableConstants.shared.set(key, value: value)
    Logger.shared.info("[TESTSERVER] Set tunable \(key) = \(value)")
    return httpResponse("Set \(key) = \(value)", status: "200 OK")
}

private func handleSetAllTunables(request: String) -> String {
    // Extract body from request
    let lines = request.components(separatedBy: "\r\n")
    guard let bodyIndex = lines.firstIndex(where: { $0.isEmpty }) else {
        return httpResponse("No body found", status: "400 Bad Request")
    }

    let body = lines[(bodyIndex + 1)...].joined(separator: "\r\n")
    guard let bodyData = body.data(using: .utf8),
          let json = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any] else {
        return httpResponse("Invalid JSON", status: "400 Bad Request")
    }

    TunableConstants.shared.setAll(json)
    Logger.shared.info("[TESTSERVER] Updated all tunables")
    return httpResponse("Updated all constants", status: "200 OK")
}
```

In the `handleRequest` function, add routing for these endpoints:

```swift
func handleRequest(_ request: String, connection: NWConnection) {
    // ... existing code ...

    // GET /tune - return all tunables
    if requestLine.starts(with: "GET /tune") {
        let response = handleGetTunables()
        sendResponse(connection, response)
        return
    }

    // PUT /tune/:key/:value - set single tunable
    if requestLine.starts(with: "PUT /tune/") {
        let response = handleSetTunable(path: path)
        sendResponse(connection, response)
        return
    }

    // POST /tune - set all tunables
    if requestLine.starts(with: "POST /tune") {
        let response = handleSetAllTunables(request: request)
        sendResponse(connection, response)
        return
    }

    // ... rest of existing routes ...
}
```

## App Initialization

**File:** `apps/firefly/product/client/imp/ios/NoobTest/NoobTestApp.swift`

Add to the app initialization:

```swift
init() {
    // Initialize tunable constants
    _ = TunableConstants.shared

    // ... rest of initialization
}
```

## Usage Example

**In any SwiftUI view:**

```swift
struct MyView: View {
    @ObservedObject var tunables = TunableConstants.shared

    var body: some View {
        VStack {
            // ...
        }
        .frame(height: tunables.getDouble("toolbar_height", default: 60.0))
        .background(Color(
            red: tunables.getDouble("background_red", default: 224) / 255,
            green: tunables.getDouble("background_green", default: 176) / 255,
            blue: tunables.getDouble("background_blue", default: 255) / 255
        ))
    }
}
```

## Developer Tools

### sync-tunables.sh

**File:** `apps/firefly/product/client/imp/ios/sync-tunables.sh`

Pulls current tunable values from device back to codebase:

```bash
#!/bin/bash
# Sync tunable constants from device back to codebase

set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
JSON_FILE="$PROJECT_DIR/../../live-constants.json"

echo "📥 Fetching current tunable values from device..."
curl -s http://localhost:8081/tune | python3 -m json.tool > "$JSON_FILE"

echo "✅ Synced tunables to: $JSON_FILE"
echo ""
cat "$JSON_FILE"
```

**Usage:** `./sync-tunables.sh` from iOS directory

### watch-tunables.py

**File:** `apps/firefly/product/client/imp/ios/watch-tunables.py`

Watches the JSON file for changes and auto-syncs to device:

```python
#!/usr/bin/env python3
"""
Live Constants File Watcher

Watches live-constants.json for changes and automatically syncs to the device.
This enables a seamless workflow: edit the JSON file in any editor, and changes
are immediately reflected on the device.

Usage:
    python3 watch-tunables.py

Requirements:
    pip3 install watchdog requests
"""

import json
import time
import os
import requests
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler

class JSONWatcher(FileSystemEventHandler):
    def __init__(self, json_path, device_url):
        self.json_path = os.path.abspath(json_path)
        self.device_url = device_url
        print(f"👀 Watching {self.json_path}")
        print(f"📡 Device URL: {self.device_url}")
        # Sync initial state
        self.sync_to_device()

    def on_modified(self, event):
        # Check if the modified file is our JSON file
        if os.path.abspath(event.src_path) == self.json_path:
            print(f"\n📝 Detected change in {os.path.basename(self.json_path)}")
            self.sync_to_device()

    def sync_to_device(self):
        try:
            with open(self.json_path, 'r') as f:
                data = json.load(f)

            response = requests.post(
                f"{self.device_url}/tune",
                json=data,
                timeout=2
            )

            if response.status_code == 200:
                print(f"✅ Synced to device: {json.dumps(data, indent=2)}")
            else:
                print(f"❌ Server returned status {response.status_code}")

        except FileNotFoundError:
            print(f"❌ Error: File not found at {self.json_path}")
        except json.JSONDecodeError as e:
            print(f"❌ Error: Invalid JSON - {e}")
        except requests.exceptions.RequestException as e:
            print(f"❌ Error: Could not reach device - {e}")
        except Exception as e:
            print(f"❌ Unexpected error: {e}")

def main():
    # Configuration
    json_path = "../../live-constants.json"
    device_url = "http://localhost:8081"

    # Resolve absolute path for watching
    json_dir = os.path.dirname(os.path.abspath(json_path))

    # Create watcher
    watcher = JSONWatcher(json_path, device_url)

    # Set up file observer
    observer = Observer()
    observer.schedule(watcher, path=json_dir, recursive=False)
    observer.start()

    print(f"\n🔄 Auto-sync enabled. Edit the JSON file and changes will appear instantly!")
    print(f"Press Ctrl+C to stop watching.\n")

    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        print("\n\n👋 Stopping watcher...")
        observer.stop()

    observer.join()

if __name__ == "__main__":
    main()
```

**Usage:** `python3 watch-tunables.py` from iOS directory
**Dependencies:** `pip3 install watchdog requests`

## Patching Instructions

1. Create `apps/firefly/product/client/live-constants.json` with initial values
2. Create `apps/firefly/product/client/imp/ios/NoobTest/TunableConstants.swift` with the code above
3. Add TunableConstants.swift to Xcode project (use ios-add-file skill or edit project.pbxproj)
4. Add live-constants.json as bundled resource in project.pbxproj
5. Update `apps/firefly/product/client/imp/ios/NoobTest/TestServer.swift` to add the three endpoint handlers
6. Update `apps/firefly/product/client/imp/ios/NoobTest/NoobTestApp.swift` to initialize TunableConstants
7. Create `apps/firefly/product/client/imp/ios/sync-tunables.sh` script
8. Create `apps/firefly/product/client/imp/ios/watch-tunables.py` script
9. Make scripts executable: `chmod +x sync-tunables.sh watch-tunables.py`
