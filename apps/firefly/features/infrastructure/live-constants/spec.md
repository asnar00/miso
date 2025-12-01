# live-constants
*adjust layout and styling constants in real-time without rebuilding*

Live constants allow interactive tuning of UI parameters during development. Constants are stored in a JSON file that serves as the single source of truth - the app reads this file at startup, and HTTP endpoints allow real-time updates that are immediately reflected in the UI and persisted to disk.

This enables rapid iteration on visual design: adjust colors, spacing, font sizes, and other parameters via simple HTTP requests, see changes immediately on device, and commit the final values to git when satisfied.

The system provides endpoints to read current values, update individual constants, or replace the entire configuration. All changes are written to the JSON file, ensuring code and runtime state stay synchronized.

Constants are referenced in code by name (e.g., `Tunable.get("toolbar_height")`), making it easy to identify tunable parameters and maintain consistency across platforms.

**Current constants in use:**
- `font-scale` (0.9) - Multiplier for all font sizes across the app
- `post-background-brightness` (0.7) - Opacity of post background (0-1)
- `author-button-darkness` (1.0) - Multiplier for author button darkness relative to post background

## Workflows

**Manual HTTP workflow:**
```bash
# Get all current values
curl http://localhost:8081/tune

# Set individual constant
curl -X PUT http://localhost:8081/tune/font-scale/0.9

# Sync current device values back to codebase
./sync-tunables.sh
```

**Auto-sync workflow (recommended):**
```bash
# Start the file watcher (from ios directory)
python3 watch-tunables.py

# Now just edit live-constants.json in any editor
# Changes automatically sync to device instantly!
```

The watcher script monitors the JSON file and POSTs updates to the device whenever you save changes, enabling seamless iteration with your favorite text editor or JSON editing tool.
