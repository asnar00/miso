# applescript-commands
*remote control via OSA script events*

The viewer accepts AppleScript commands for remote control and automation, enabling agents and scripts to control the app programmatically.

## Available Commands

### Hello Command
Simple test command that logs a greeting.

**Usage**:
```bash
osascript -e 'tell application "viewer" to «event MISOHELO»'
```

**Result**: Logs "hello world" with timestamp

### Goto Command  
Navigate to a specific snippet path in the viewer.

**Usage**:
```bash
osascript -e 'tell application "viewer" to «event MISOGOTO» given «class PATH»:"tools/viewer"'
```

**Parameters**:
- `PATH`: Snippet path (e.g., "tools/viewer", "miso/platforms/macos")

**Result**: Navigates the viewer to the specified snippet and logs the navigation

## Implementation
Commands use AppleScript event handling with:
- **Event class**: `MISO` (fourCharCode)
- **Event IDs**: `HELO` (hello), `GOTO` (navigation)
- **Parameter keys**: `PATH` for navigation commands

All commands include logging for debugging and verification.