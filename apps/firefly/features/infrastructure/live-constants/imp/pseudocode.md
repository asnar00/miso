# live-constants pseudocode

## Overview
Provides a system for tunable constants stored in a JSON file that can be updated at runtime via HTTP endpoints.

## Data Structures

**LiveConstants JSON format:**
```json
{
  "toolbar_height": 60.0,
  "button_radius": 25.0,
  "background_red": 224,
  "background_green": 176,
  "background_blue": 255
}
```

## Functions

**loadConstants()**
- Read `live-constants.json` from the product client directory
- Parse JSON into in-memory dictionary
- If file doesn't exist, create it with empty object `{}`
- Return success/failure

**get(key: String) -> Any?**
- Look up key in the in-memory constants dictionary
- Return value if exists, nil otherwise
- Support type casting to Double, Int, String as needed

**set(key: String, value: Any)**
- Update in-memory dictionary with new value
- Write entire dictionary back to `live-constants.json`
- Notify observers that value changed (for UI updates)
- Return success/failure

**getAll() -> Dictionary**
- Return entire in-memory constants dictionary
- Used by GET endpoint to show current state

**setAll(constants: Dictionary)**
- Replace entire in-memory dictionary
- Write to `live-constants.json`
- Notify all observers
- Used by POST endpoint to bulk update

## HTTP Endpoints

**GET /tune**
- Call getAll()
- Return JSON response with all current constants

**PUT /tune/:key/:value**
- Parse key and value from URL
- Call set(key, value)
- Return success response

**POST /tune**
- Parse JSON body
- Call setAll() with parsed dictionary
- Return success response

## Integration Points

**App Startup:**
- Call loadConstants() during app initialization
- Must happen before any UI is rendered

**Test Server:**
- Register the three HTTP endpoints in the test server
- Endpoints should be available on port 8081

**Usage in Code:**
- Replace hardcoded constants with `Tunable.get("constant_name")`
- For SwiftUI, use `@Published` or similar to trigger re-renders
- For Android, use observable pattern to update Composables

## File Location

**JSON file:** `apps/firefly/product/client/live-constants.json`
- Shared between iOS and Android
- Checked into git as the source of truth
- On iOS: bundled with app, copied to Documents directory on first run for persistence
- On Android: read from project location

**Current constants:**
```json
{
    "font-scale": 0.9,
    "post-background-brightness": 0.7,
    "author-button-darkness": 1.0
}
```

## Developer Tools

**sync-tunables.sh** - Sync device values back to codebase
- Fetches current JSON from device via GET /tune
- Writes to live-constants.json in codebase
- Usage: `./sync-tunables.sh` from iOS directory

**watch-tunables.py** - Auto-sync file changes to device
- Watches live-constants.json for file modifications
- POSTs changes to device immediately when file is saved
- Enables seamless workflow: edit JSON in any editor, see changes instantly
- Usage: `python3 watch-tunables.py` from iOS directory
- Dependencies: `pip3 install watchdog requests`

## Patching Instructions

1. Create `apps/firefly/product/client/live-constants.json` with initial values
2. Add TunableConstants class/object to each platform
3. Initialize on app startup (before UI)
4. Add three endpoints to test server (GET /tune, PUT /tune/:key/:value, POST /tune)
5. Add JSON file as bundled resource (iOS: in project.pbxproj)
6. Create sync-tunables.sh script for pulling values from device
7. Create watch-tunables.py script for auto-syncing changes to device
8. For existing hardcoded values, migrate to JSON and update code to use Tunable.get()
