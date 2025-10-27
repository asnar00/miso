# background implementation
*platform-agnostic visual connection indicator*

## Overview

Provides immediate visual feedback about server connectivity by changing the app's background color. Works in conjunction with the ping feature to reflect real-time connection status.

## States and Colors

**Connected:**
- Background color: Grey (RGB: 128, 128, 128)
- Indicates: Server is reachable and responding

**Disconnected:**
- Background color: Dark Red (RGB: 139, 0, 0)
- Indicates: Server unreachable, network error, or server error

## State Management

**Background Color Variable:**
- Type: Color
- Initial value: Dark Red (disconnected until first successful ping)
- Updated by: Ping result handler

## Integration with Ping

The background feature listens to ping results and updates accordingly:

```
function onPingSuccess():
    setBackgroundColor(grey)

function onPingFailure():
    setBackgroundColor(darkRed)
```

## UI Implementation

**Full-screen background:**
- Background fills entire screen (ignores safe areas)
- Content is layered on top of background
- Color changes are animated smoothly by UI framework

**Layout structure:**
```
ZStack:
    - Background color layer (fullscreen)
    - Content layer (logo, posts, etc.)
```

## Behavior Timeline

**App launch:**
1. Initialize with dark red background (disconnected)
2. Start ping loop
3. On first successful ping: transition to grey
4. Continue updating based on ping results

**During use:**
- Ping succeeds every second → stays grey
- Ping fails → immediately turns dark red
- Ping succeeds after failure → immediately returns to grey

**Transitions:**
- Color transitions should be smooth (not jarring)
- No delay between ping result and color change
- Updates happen on main UI thread

## Visual Design

**Color values:**
- Grey: RGB(128, 128, 128) or #808080
- Dark Red: RGB(139, 0, 0) or #8B0000

**Accessibility:**
- Sufficient contrast with black text
- Don't rely solely on color for connection status
- Consider adding text/icon indicator for accessibility

## Error States

All error conditions result in dark red background:
- Network timeout
- DNS resolution failure
- Server returns error (non-200 status)
- Malformed response
- Connection refused

## Platform Considerations

Different platforms may implement color management differently:
- iOS: SwiftUI Color type
- Android: Color resource or ARGB integer
- Web: CSS color value

The interface (setBackgroundColor) remains the same across platforms.

## Testing

**Manual test:**
1. Start app with server running → should be grey
2. Stop server → should turn dark red within ~1 second
3. Start server → should turn grey within ~1 second
4. Verify color transitions are smooth

**Automated test:**
1. Mock ping success → verify grey
2. Mock ping failure → verify dark red
3. Verify initial state is dark red

## Performance

- Color updates are lightweight (just property changes)
- No computation or network calls
- Updates happen on main thread (UI updates must be on main thread)
- Smooth transitions handled by platform UI framework
