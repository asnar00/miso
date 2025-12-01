# ui-automation iOS implementation
*SwiftUI UI automation via HTTP*

## Overview

Implements UI automation for iOS using a singleton registry that maps string IDs to UI actions. Extends the existing TestServer to handle `/test/tap` POST requests.

## Files to Create

1. **UIAutomationRegistry.swift** - NEW FILE - Singleton registry for UI elements
2. **TestServer.swift** - MODIFY - Add tap endpoint

## Implementation

### 1. Create UIAutomationRegistry.swift

Create new file at: `apps/firefly/product/client/imp/ios/NoobTest/UIAutomationRegistry.swift`

```swift
import Foundation

class UIAutomationRegistry {
    static let shared = UIAutomationRegistry()

    private var elements: [String: () -> Void] = [:]
    private let queue = DispatchQueue(label: "com.miso.ui-automation", attributes: .concurrent)

    private init() {}

    func register(id: String, action: @escaping () -> Void) {
        queue.async(flags: .barrier) {
            self.elements[id] = action
        }
    }

    func trigger(id: String) -> Bool {
        var action: (() -> Void)?

        queue.sync {
            action = elements[id]
        }

        guard let action = action else {
            return false
        }

        // Execute on main thread
        DispatchQueue.main.async {
            action()
        }

        return true
    }

    func listElements() -> [String] {
        var keys: [String] = []
        queue.sync {
            keys = Array(elements.keys)
        }
        return keys.sorted()
    }
}
```

### 2. Extend TestServer.swift

Modify TestServer to handle POST requests and add tap endpoint:

```swift
// In handleRequest method, update to support POST:

private func handleRequest(_ request: String) -> String {
    Logger.shared.info("[TESTSERVER] Received request")

    // Parse HTTP method and path
    let lines = request.split(separator: "\r\n")
    guard let firstLine = lines.first else {
        return httpResponse("Bad request", status: "400 Bad Request")
    }

    let parts = firstLine.split(separator: " ")
    guard parts.count >= 2 else {
        return httpResponse("Bad request", status: "400 Bad Request")
    }

    let method = String(parts[0])
    let path = String(parts[1])

    Logger.shared.info("[TESTSERVER] \(method) \(path)")

    // Handle POST /test/tap
    if method == "POST" && path.hasPrefix("/test/tap") {
        return handleTap(path: path)
    }

    // Handle GET /test/{feature}
    guard method == "GET" else {
        Logger.shared.error("[TESTSERVER] Method not allowed: \(method)")
        return httpResponse("Method not allowed", status: "405 Method Not Allowed")
    }

    guard path.hasPrefix("/test/") else {
        Logger.shared.error("[TESTSERVER] Path not found: \(path)")
        return httpResponse("Not found", status: "404 Not Found")
    }

    let feature = String(path.dropFirst("/test/".count))
    Logger.shared.info("[TESTSERVER] Dispatching test for feature: \(feature)")
    let result = TestRegistry.shared.run(feature: feature)

    let message = result.success ? "succeeded" : "failed because \(result.error ?? "unknown error")"
    Logger.shared.info("[TESTSERVER] Sending response: \(message)")
    return httpResponse(message, status: "200 OK")
}

// Add new handleTap method:

private func handleTap(path: String) -> String {
    // Extract id from query string: /test/tap?id=toolbar-plus
    guard let urlComponents = URLComponents(string: path),
          let queryItems = urlComponents.queryItems,
          let id = queryItems.first(where: { $0.name == "id" })?.value else {
        Logger.shared.error("[TESTSERVER] Missing id parameter in tap request")
        let json = #"{"status": "error", "message": "Missing id parameter"}"#
        return httpResponse(json, status: "400 Bad Request", contentType: "application/json")
    }

    Logger.shared.info("[TESTSERVER] Triggering UI element: \(id)")
    let success = UIAutomationRegistry.shared.trigger(id: id)

    if success {
        Logger.shared.info("[TESTSERVER] Successfully triggered: \(id)")
        let json = #"{"status": "success", "id": "\#(id)"}"#
        return httpResponse(json, status: "200 OK", contentType: "application/json")
    } else {
        Logger.shared.error("[TESTSERVER] Element not found: \(id)")
        let json = #"{"status": "error", "message": "Element not found: \#(id)"}"#
        return httpResponse(json, status: "404 Not Found", contentType: "application/json")
    }
}

// Update httpResponse helper to support JSON content type:

private func httpResponse(_ body: String, status: String = "200 OK", contentType: String = "text/plain") -> String {
    let headers = """
    HTTP/1.1 \(status)\r
    Content-Type: \(contentType); charset=utf-8\r
    Content-Length: \(body.utf8.count)\r
    Connection: close\r
    \r

    """
    return headers + body
}
```

### 3. Register Toolbar Buttons

Update Toolbar.swift to register buttons with the automation registry:

```swift
// In Toolbar struct, add registration on appear:

var body: some View {
    HStack(spacing: 0) {
        // Home button
        ToolbarButton(icon: "house", isActive: activeTab == .home) {
            activeTab = .home
            navigationPath = []
        }

        Spacer()

        // Post button
        ToolbarButton(icon: "plus", isActive: activeTab == .post) {
            activeTab = .post
            onPostButtonTap()
        }

        Spacer()

        // Search button
        ToolbarButton(icon: "magnifyingglass", isActive: activeTab == .search) {
            activeTab = .search
            onSearchButtonTap()
        }

        Spacer()

        // Profile button
        ToolbarButton(icon: "person", isActive: activeTab == .profile) {
            activeTab = .profile
            onProfileButtonTap()
        }
    }
    .padding(.horizontal, 24)
    .padding(.vertical, 8)
    .frame(height: 60)
    .background(Color.white.opacity(0.95))
    .shadow(radius: 2)
    .onAppear {
        // Register toolbar buttons with automation registry
        UIAutomationRegistry.shared.register(id: "toolbar-home") {
            activeTab = .home
            navigationPath = []
        }

        UIAutomationRegistry.shared.register(id: "toolbar-plus") {
            activeTab = .post
            onPostButtonTap()
        }

        UIAutomationRegistry.shared.register(id: "toolbar-search") {
            activeTab = .search
            onSearchButtonTap()
        }

        UIAutomationRegistry.shared.register(id: "toolbar-profile") {
            activeTab = .profile
            onProfileButtonTap()
        }
    }
}
```

## Xcode Project Integration

Add `UIAutomationRegistry.swift` to Xcode project:

**Using project.pbxproj:**
1. Generate new UUID for file reference
2. Add file reference to PBXFileReference section
3. Add file to PBXSourcesBuildPhase
4. Add file to PBXGroup (NoobTest group)

## Testing

**Setup port forwarding** (if not already running):
```bash
pymobiledevice3 usbmux forward 8081 8081 &
```

**Trigger toolbar plus button:**
```bash
# IMPORTANT: Quote the URL to prevent shell interpretation of query parameters
curl -X POST 'http://localhost:8081/test/tap?id=toolbar-plus'
```

**Expected response:**
```json
{"status": "success", "id": "toolbar-plus"}
```

**Expected UI result**: New post editor appears over main content with toolbar remaining visible at bottom

**Test other toolbar buttons:**
```bash
curl -X POST 'http://localhost:8081/test/tap?id=toolbar-home'
curl -X POST 'http://localhost:8081/test/tap?id=toolbar-search'
curl -X POST 'http://localhost:8081/test/tap?id=toolbar-profile'
```

**Error response (element not found):**
```json
{"status": "error", "message": "Element not found: invalid-id"}
```

## Notes

- Actions execute on main thread via DispatchQueue.main.async
- Registry is thread-safe using concurrent queue with barriers
- Elements register on view appearance
- Re-registration updates action
- Only available when test server is running (dev builds)
- Requires USB port forwarding or local network access

## Common Element IDs

- `toolbar-home` - Home button
- `toolbar-plus` - Post/create button
- `toolbar-search` - Search button
- `toolbar-profile` - Profile button

## Future Enhancements

- Text input support
- Gesture simulation
- Element state verification
- Screenshot coordination
- Batch action support
