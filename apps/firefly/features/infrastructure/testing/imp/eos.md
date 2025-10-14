# testing implementation (Android)
*test infrastructure for Android client*

## Overview

The testing feature runs on an HTTP server listening on port 8081. It receives test commands, executes tests, and returns results.

## Components

**TestServer** - HTTP server using NanoHTTPD
- Listens on port 8081
- Accepts GET `/test/<feature-name>` requests
- Returns plain text with success/failure result

**TestRegistry** - Maps feature names to test functions
- Stores map of feature name → test function
- Features register themselves at startup
- Supports hierarchical lookup (e.g., "firefly" tests all sub-features)

**Test protocol** - What test functions must do
- Test functions return `TestResult` with success boolean and optional error message
- Format: `TestResult(success = true)` or `TestResult(success = false, error = "reason")`

## Pseudocode

```kotlin
data class TestResult(
    val success: Boolean,
    val error: String? = null
)

object TestRegistry {
    private val tests = mutableMapOf<String, () -> TestResult>()

    fun register(feature: String, test: () -> TestResult)
    fun run(feature: String): TestResult
}

class TestServer(port: Int = 8081) : NanoHTTPD(port) {
    override fun serve(session: IHTTPSession): Response {
        val uri = session.uri
        if (uri.startsWith("/test/")) {
            val feature = uri.removePrefix("/test/")
            val result = TestRegistry.run(feature)
            val message = if (result.success) "succeeded"
                         else "failed because ${result.error}"
            return newFixedLengthResponse(message)
        }
        return newFixedLengthResponse(Response.Status.NOT_FOUND, MIME_PLAINTEXT, "Not found")
    }
}
```

## Initialization

In MainActivity.onCreate:
```kotlin
TestServer().start()
```

Each feature registers its test:
```kotlin
TestRegistry.register("ping") {
    // run ping test
    TestResult(...)
}
```
