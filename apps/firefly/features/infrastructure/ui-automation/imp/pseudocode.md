# ui-automation implementation
*platform-agnostic UI automation specification*

## Overview

Extends the existing test server (port 8081) to support programmatic UI interaction. UI elements register themselves with unique IDs, and HTTP endpoints trigger their actions.

## Data Structures

**UIElement Registration:**
```
struct UIElementRegistration:
    id: String              // e.g., "toolbar-plus"
    action: () -> Void      // Closure to execute
```

**Registry:**
```
class UIAutomationRegistry:
    elements: Map<String, () -> Void>

    register(id: String, action: () -> Void)
    trigger(id: String) -> Result
```

## HTTP API

**Endpoint: POST /test/tap**

Query parameter: `id` (required)

Example: `POST http://localhost:8081/test/tap?id=toolbar-plus`

**Success Response:**
```json
{
    "status": "success",
    "id": "toolbar-plus"
}
```

**Error Response:**
```json
{
    "status": "error",
    "message": "Element not found: toolbar-plus"
}
```

## Registration Pattern

**In UI Code:**
```
onAppear:
    UIAutomationRegistry.shared.register(
        id: "toolbar-plus",
        action: {
            // Execute button action
            showNewPostEditor = true
        }
    )
```

**Registry Behavior:**
- Elements register on view appearance
- Re-registration with same ID updates action
- Registry persists for app lifetime
- Thread-safe access required

## Trigger Mechanism

**Server receives POST /test/tap?id=X:**
1. Extract `id` parameter from query string
2. Look up action in registry
3. If found: Execute action on main thread, return success
4. If not found: Return error with message

**Main Thread Execution:**
- Critical: UI actions must execute on main thread
- Use dispatch/post to main thread/looper
- Ensure synchronous return after dispatch

## Integration with TestServer

**Extend existing TestServer:**
```
class TestServer:
    // Existing test endpoints
    handleTest(path: String) -> Response

    // New automation endpoint
    handleTap(id: String) -> Response:
        result = UIAutomationRegistry.shared.trigger(id)
        if result.success:
            return {"status": "success", "id": id}
        else:
            return {"status": "error", "message": result.error}
```

**Route registration:**
- Add `/test/tap` to TestServer routing
- Parse query parameters
- Call handleTap with extracted ID

## Example Usage

**From command line:**
```bash
# Trigger toolbar plus button
curl -X POST http://localhost:8081/test/tap?id=toolbar-plus

# Wait for animation
sleep 0.5

# Capture screenshot
cd /path/to/screen-capture
./screenshot.sh /tmp/new-post-editor.png
```

**In test scripts:**
```bash
# Test new post workflow
curl -X POST http://localhost:8081/test/tap?id=toolbar-plus
sleep 0.5
./screenshot.sh /tmp/step1-editor-open.png

curl -X POST http://localhost:8081/test/tap?id=post-cancel
sleep 0.3
./screenshot.sh /tmp/step2-editor-closed.png
```

## Patching Instructions

**1. Create UIAutomationRegistry class:**
- File: `UIAutomationRegistry.swift` (iOS) or `UIAutomationRegistry.kt` (Android)
- Singleton pattern
- Thread-safe dictionary/map
- register() and trigger() methods

**2. Extend TestServer:**
- Add handleTap() method
- Register `/test/tap` route
- Parse query parameters
- Return JSON responses

**3. Update UI elements:**
- In Toolbar.swift: Register "toolbar-plus", "toolbar-home", etc.
- In other interactive elements: Register with descriptive IDs
- Use onAppear/onCreate for registration

**4. Add to Xcode project (iOS):**
- Add UIAutomationRegistry.swift to project
- Update project.pbxproj

## Platform Notes

**iOS:**
- Use DispatchQueue.main.async for main thread execution
- TestServer already runs background thread
- SF Symbols unaffected

**Android:**
- Use Handler(Looper.getMainLooper()).post for main thread
- TestServer uses background thread
- Material icons unaffected

## Security Considerations

- Only available when test server is running (dev builds)
- Port 8081 requires USB forwarding or local network
- Not exposed in production builds
- No authentication required (local testing only)
