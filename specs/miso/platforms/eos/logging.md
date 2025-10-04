# Logging
*Debugging Android/e/OS apps with logcat*

Android provides a built-in logging system accessible via `adb logcat` that captures app and system logs.

## Adding Logs to Code

Use Android's `Log` class in Kotlin:

```kotlin
import android.util.Log

// Log levels (from verbose to critical)
Log.v("TAG", "Verbose message")
Log.d("TAG", "Debug message")
Log.i("TAG", "Info message")
Log.w("TAG", "Warning message")
Log.e("TAG", "Error message")
```

**Best practices**:
- Use consistent tag names (often the class name or app name)
- Use appropriate log levels (debug for development, error for failures)
- Include context in messages (values, state, what operation is happening)

## Viewing Logs

### View all logs from connected device
```bash
adb logcat
```

### Filter by tag
```bash
adb logcat | grep "TAG"
```

### Filter by app name
```bash
adb logcat | grep "AppName"
```

### View recent logs (dump mode)
```bash
adb logcat -d
```

Shows buffered logs without staying attached.

### Clear log buffer
```bash
adb logcat -c
```

Useful before testing to see only new logs.

### Combine clear and view
```bash
adb logcat -c && sleep 2 && adb logcat -d | grep "TAG"
```

Clears logs, waits briefly, then dumps only new logs.

## Example Usage

From our connection monitoring implementation:

```kotlin
private suspend fun testConnection(): Color {
    return withContext(Dispatchers.IO) {
        try {
            Log.d("NoobTest", "Attempting connection...")
            val request = Request.Builder()
                .url("http://185.96.221.52:8080/api/ping")
                .build()

            val response = client.newCall(request).execute()
            Log.d("NoobTest", "Response code: ${response.code}")
            
            if (response.isSuccessful) {
                Log.d("NoobTest", "Connection successful!")
                Color(0xFF40E0D0)
            } else {
                Log.d("NoobTest", "Connection failed: ${response.code}")
                Color.Gray
            }
        } catch (e: IOException) {
            Log.e("NoobTest", "Connection error: ${e.message}")
            Color.Gray
        }
    }
}
```

Viewing these logs:
```bash
adb logcat | grep NoobTest
```

Output:
```
10-03 18:13:31.203 13096 13121 D NoobTest: Attempting connection...
10-03 18:13:31.423 13096 13121 D NoobTest: Response code: 200
10-03 18:13:31.424 13096 13121 D NoobTest: Connection successful!
```

## Log Message Format

```
MM-DD HH:MM:SS.mmm  PID   TID  LEVEL TAG: Message
```

- **MM-DD HH:MM:SS.mmm**: Timestamp
- **PID**: Process ID
- **TID**: Thread ID
- **LEVEL**: V/D/I/W/E (Verbose/Debug/Info/Warning/Error)
- **TAG**: String identifier
- **Message**: Log content

## Advanced Filtering

### By log level
```bash
adb logcat *:E  # Show only errors
adb logcat *:W  # Show warnings and above
```

### By process ID
```bash
adb logcat --pid=13096
```

### Save to file
```bash
adb logcat > app-logs.txt
```

## Production Considerations

- Debug/Verbose logs should be removed or disabled in production builds
- Use ProGuard/R8 to strip log calls in release builds
- Never log sensitive information (passwords, tokens, personal data)
