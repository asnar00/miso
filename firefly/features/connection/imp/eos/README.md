# Android/e/OS Connection Implementation
*Jetpack Compose + Kotlin Coroutines implementation of server connection monitoring*

## Implementation Overview

The Android implementation uses Jetpack Compose for UI, Kotlin coroutines for asynchronous operations, and OkHttp for HTTP networking.

## Key Components

### MainActivity Class
```kotlin
class MainActivity : ComponentActivity() {
    private val client = OkHttpClient()
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            // Compose UI content
        }
    }
    
    private suspend fun testConnection(): Boolean { ... }
}
```

**OkHttpClient**: Reusable HTTP client instance for making network requests

### State Management

```kotlin
var isConnected by remember { mutableStateOf(false) }
val scope = rememberCoroutineScope()
```

- `isConnected`: Compose state variable that tracks connection status
- `scope`: Coroutine scope tied to the composable's lifecycle

### Lifecycle-Aware Connection Loop

```kotlin
LaunchedEffect(Unit) {
    scope.launch {
        while (true) {
            isConnected = testConnection()
            delay(1000) // Wait 1 second
        }
    }
}
```

**LaunchedEffect(Unit)**:
- Runs when composable enters composition
- Automatically cancelled when composable leaves composition
- `Unit` key means it runs once and doesn't restart

**Infinite loop**:
- Continuously checks connection while app is active
- Suspends for 1 second between checks with `delay(1000)`
- Updates UI by assigning result to `isConnected`

### Connection Testing

```kotlin
private suspend fun testConnection(): Boolean {
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
                true
            } else {
                Log.d("NoobTest", "Connection failed: ${response.code}")
                false
            }
        } catch (e: IOException) {
            Log.e("NoobTest", "Connection error: ${e.message}")
            false
        }
    }
}
```

**Key details**:
- `suspend fun`: Coroutine function that can be paused/resumed
- `withContext(Dispatchers.IO)`: Switches to I/O thread pool for network call
- `Request.Builder()`: OkHttp API for building HTTP requests
- `response.isSuccessful`: Checks if status code is 2xx
- `IOException`: Catches network errors (connection refused, timeout, etc.)
- Returns `Boolean` status for immediate UI update

### Thread Management

- **Main thread**: Compose UI and state updates
- **IO dispatcher**: Network calls via `withContext(Dispatchers.IO)`
- Automatic context switching ensures:
  - Network doesn't block UI
  - State updates happen on main thread safely

## Platform Configuration

### AndroidManifest.xml - Permissions
```xml
<uses-permission android:name="android.permission.INTERNET" />

<application
    android:networkSecurityConfig="@xml/network_security_config">
    ...
</application>
```

**INTERNET permission**: Required for all network access  
**networkSecurityConfig**: References custom security configuration

### network_security_config.xml - HTTP Access
```xml
<network-security-config>
    <base-config cleartextTrafficPermitted="true" />
</network-security-config>
```

Allows HTTP connections (Android blocks HTTP by default from API 28+).

### build.gradle.kts - Dependencies
```kotlin
// Network
implementation("com.squareup.okhttp3:okhttp:4.12.0")

// Coroutines
implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")
```

**OkHttp**: Modern HTTP client for Android  
**Coroutines**: Kotlin's concurrency framework

## Files

- **MainActivity.kt**: Activity with Compose UI and connection logic
- **AndroidManifest.xml**: Permissions and security config reference
- **res/xml/network_security_config.xml**: HTTP cleartext permission
- **build.gradle.kts**: Dependency declarations

## Debugging

Use `adb logcat` to view connection logs:
```bash
adb logcat | grep NoobTest
```

Logs show:
- "Attempting connection..." - Each check attempt
- "Response code: 200" - HTTP status received
- "Connection successful!" - Successful connection
- "Connection error: ..." - Network failures

## Testing

Deploy to device and observe:
- Connection status updates when server becomes reachable/unreachable
- Status changes reflected in UI
- Logs in logcat showing connection attempts every second
- Test by toggling WiFi/airplane mode to simulate connection loss
