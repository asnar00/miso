# ping - e/OS Implementation
*Kotlin/Jetpack Compose implementation of server ping feature*

## Overview

Implement periodic server connectivity checking in the e/OS client app using OkHttp to make HTTP requests to the server's `/api/ping` endpoint.

## Server Configuration

```kotlin
private const val SERVER_URL = "http://192.168.1.76:8080"
```

## Implementation

### 1. Add Dependencies to build.gradle.kts

```kotlin
dependencies {
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
}
```

### 2. Add State Variables to MainActivity

```kotlin
private var backgroundColor by mutableStateOf(Color.Gray)
private var checkJob: Job? = null
```

- `backgroundColor`: Changes based on server connectivity (turquoise = connected, gray = disconnected)
- `checkJob`: Coroutine job for periodic checking

### 3. Modify Composable to Use Background Color

```kotlin
@Composable
fun MainScreen() {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(backgroundColor),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = "ᕦ(ツ)ᕤ",
            fontSize = 120.sp,
            color = Color.Black
        )
    }

    LaunchedEffect(Unit) {
        startPeriodicCheck()
    }

    DisposableEffect(Unit) {
        onDispose {
            checkJob?.cancel()
        }
    }
}
```

### 4. Add Periodic Check Function

```kotlin
private fun startPeriodicCheck() {
    checkJob = CoroutineScope(Dispatchers.IO).launch {
        while (isActive) {
            testConnection()
            delay(1000) // Check every 1 second
        }
    }
}
```

### 5. Add Connection Test Function

```kotlin
private val client = OkHttpClient.Builder()
    .connectTimeout(2, TimeUnit.SECONDS)
    .readTimeout(2, TimeUnit.SECONDS)
    .build()

private suspend fun testConnection() {
    try {
        val request = Request.Builder()
            .url("$SERVER_URL/api/ping")
            .build()

        val response = client.newCall(request).execute()

        withContext(Dispatchers.Main) {
            if (response.isSuccessful) {
                // Connection successful - show turquoise
                backgroundColor = Color(0xFF40E0D0)
            } else {
                // Server returned error
                backgroundColor = Color.Gray
            }
        }
    } catch (e: Exception) {
        // Connection failed
        withContext(Dispatchers.Main) {
            backgroundColor = Color.Gray
        }
    }
}
```

## AndroidManifest.xml Configuration

Android apps require permission to access the internet. Add to `AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET" />
```

To allow HTTP (non-HTTPS) connections, add to the `<application>` tag:

```xml
<application
    android:usesCleartextTraffic="true"
    ...>
```

Or for more security, create `res/xml/network_security_config.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <domain-config cleartextTrafficPermitted="true">
        <domain includeSubdomains="false">192.168.1.76</domain>
    </domain-config>
</network-security-config>
```

And reference it in AndroidManifest.xml:

```xml
<application
    android:networkSecurityConfig="@xml/network_security_config"
    ...>
```

## Product Integration

**Target**: `apps/firefly/product/client/imp/eos/app/src/main/java/com/miso/firefly/MainActivity.kt`

Update the MainActivity to include the ping functionality.

**Target**: `apps/firefly/product/client/imp/eos/app/src/main/AndroidManifest.xml`

Add the INTERNET permission and cleartext traffic configuration.

## Behavior

- App starts with gray background
- When server is reachable, background becomes turquoise
- When server becomes unreachable, background becomes gray
- Checks connection every 1 second
- Logo remains visible at all times

## Testing

1. Start server: `ssh microserver@192.168.1.76 "cd ~/firefly-server && ./start.sh"`
2. Build and install e/OS app: `./gradlew assembleDebug && adb install -r app/build/outputs/apk/debug/app-debug.apk`
3. App should show turquoise background
4. Stop server: `curl -X POST http://192.168.1.76:8080/api/shutdown`
5. App background should turn gray within 1 second
6. Restart server
7. App background should turn turquoise again
