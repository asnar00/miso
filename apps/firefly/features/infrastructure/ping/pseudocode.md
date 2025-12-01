# ping implementation
*platform-agnostic server health check*

## Overview

The ping feature provides a simple health check mechanism allowing clients to verify the server is running and accessible. The client periodically sends requests to a known endpoint, and the server responds with a status message.

## Server Side

### Endpoint

**Path**: `/api/ping`
**Method**: GET
**Authentication**: None required

### Response

**Success (HTTP 200):**
```json
{
    "status": "ok",
    "message": "Firefly server is running"
}
```

**Server error (HTTP 500):**
```json
{
    "status": "error",
    "message": "Error description"
}
```

### Implementation

```
function handlePing():
    return {
        status: "ok",
        message: "Firefly server is running"
    }
```

Simple endpoint that always returns success when server is running. No database queries, no business logic - just a quick acknowledgment.

## Client Side

### Configuration

**Server URL**: Configurable endpoint (e.g., `http://192.168.1.76:8080`)
**Ping interval**: Typically 1 second while app has focus
**Timeout**: 2-3 seconds per request

### Connection States

- **Connected**: Server responded with status "ok"
- **Disconnected**: Request failed, timed out, or returned error

### Ping Loop

```
function startPingLoop():
    while appHasFocus:
        sendPing()
        wait(1 second)

function sendPing():
    try:
        response = httpGet(serverURL + "/api/ping")
        if response.status == 200 and response.data.status == "ok":
            setConnectionState("connected")
        else:
            setConnectionState("disconnected")
    catch error:
        setConnectionState("disconnected")
```

### Lifecycle

**On app start / gain focus:**
- Start ping loop
- Send immediate ping
- Continue periodic pings

**On app lose focus / background:**
- Stop ping loop
- Preserve last known connection state

**On network change:**
- Reset connection state
- Send immediate ping

## UI Integration

Connection state typically affects UI:
- **Connected**: Normal turquoise background
- **Disconnected**: Gray background or warning indicator

The UI should update immediately when connection state changes.

## Error Handling

**Network errors:**
- DNS resolution failure
- Connection refused
- Connection timeout
- SSL/TLS errors

**Server errors:**
- HTTP 500 (server error)
- HTTP 404 (endpoint not found)
- Malformed JSON response

All errors result in "disconnected" state.

## Testing

**Test ping endpoint:**
```
curl http://localhost:8080/api/ping
```

**Expected response:**
```
{"status":"ok","message":"Firefly server is running"}
```

**Test client behavior:**
1. Start app with server running → should show "connected"
2. Stop server while app running → should transition to "disconnected"
3. Restart server → should transition back to "connected"
4. Check background changes color based on connection state

## Performance Considerations

- Ping requests are lightweight (no database access)
- 1-second interval balances responsiveness and network usage
- Async requests don't block UI
- Failed pings timeout quickly (2-3 seconds max)
- No retry logic needed (next ping happens in 1 second anyway)

## Future Enhancements

Potential improvements:
- Adaptive ping interval (slower when disconnected)
- Include server version in ping response
- Include server load/health metrics
- Exponential backoff when repeatedly disconnected
- Notification when connection restored after long disconnection
