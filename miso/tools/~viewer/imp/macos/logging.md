# logging
*timestamped output for debugging and monitoring*

The viewer includes a global `log()` function that outputs timestamped messages for debugging and monitoring app behavior.

## Log Output
- **Dual output**: Writes to both stdout and log file simultaneously  
- **Timestamp format**: `[YYYY-MM-DD HH:MM:SS.SSS]` with millisecond precision
- **File location**: `/Users/asnaroo/Desktop/experiments/miso/miso/tools/~viewer/viewer.log`
- **Console prefix**: `LOG:` for easy identification in terminal output

## Usage
Call `log("message")` from anywhere in the Swift code:

```swift
log("User navigated to tools/viewer")
log("Command received: \(commandType)")
```

## Agent Integration
Agents can read logs directly using the Read tool or monitor real-time output when running the app from terminal, enabling full visibility into app behavior during development and debugging.