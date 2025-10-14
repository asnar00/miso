# ping test (Android)
*Kotlin implementation of ping connectivity test*

## Test function

```kotlin
fun testPingFeature(): TestResult {
    return try {
        val url = URL("http://185.96.221.52:8080/api/ping")
        val connection = url.openConnection() as HttpURLConnection
        connection.requestMethod = "GET"
        connection.connectTimeout = 2000
        connection.readTimeout = 2000

        val responseCode = connection.responseCode
        connection.disconnect()

        if (responseCode == 200) {
            TestResult(success = true)
        } else {
            TestResult(success = false, error = "Server returned status $responseCode")
        }
    } catch (e: Exception) {
        TestResult(success = false, error = "Connection failed: ${e.message}")
    }
}
```

## Registration

In MainActivity.onCreate:
```kotlin
TestRegistry.register("ping") {
    testPingFeature()
}
```
