# Connection Logic
*Platform-agnostic pseudocode for server connection monitoring*

## Overview

The connection monitoring system continuously checks server availability and updates connection status.

## Core Algorithm

```
CONSTANTS:
  SERVER_URL = "http://185.96.221.52:8080/api/ping"
  CHECK_INTERVAL = 1 second
  STATUS_CONNECTED = true
  STATUS_DISCONNECTED = false

STATE:
  connectionStatus = DISCONNECTED

LIFECYCLE:
  When app becomes active:
    Start connection monitoring loop

  When app becomes inactive:
    Stop connection monitoring loop

CONNECTION MONITORING LOOP:
  While app is active:
    result = testConnection()
    connectionStatus = result
    wait CHECK_INTERVAL

FUNCTION testConnection():
  Try:
    response = HTTP_GET(SERVER_URL)
    If response.statusCode == 200:
      Log("Connection successful")
      Return STATUS_CONNECTED
    Else:
      Log("Connection failed with code: " + response.statusCode)
      Return STATUS_DISCONNECTED
  Catch error:
    Log("Connection error: " + error.message)
    Return STATUS_DISCONNECTED
```

## Platform Requirements

### iOS
- Use `Timer.scheduledTimer` for periodic checks
- Run network calls on background queue (URLSession handles this)
- Start timer in `.onAppear`, invalidate in `.onDisappear`
- Configure App Transport Security to allow HTTP

### Android
- Use Kotlin coroutines with `LaunchedEffect` for lifecycle-aware loop
- Run network calls on `Dispatchers.IO` dispatcher
- Use `OkHttpClient` for HTTP requests
- Configure network security config to permit cleartext traffic

## Error Handling

All network errors should:
- Be logged for debugging
- Result in disconnected status
- Not crash the app
- Allow retry on next check interval

## Security Notes

Both platforms require configuration to allow HTTP traffic:
- **iOS**: `NSAppTransportSecurity` with `NSAllowsArbitraryLoads`
- **Android**: Network security config with `cleartextTrafficPermitted`

This is acceptable for development/testing but should use HTTPS in production.
