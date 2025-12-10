# clip offset pseudocode
*data model and display logic for adjustable image cropping*

## Data model

Add to Post:
```
clipOffsetX: float  // -1.0 to 1.0, default 0 (centered)
clipOffsetY: float  // -1.0 to 1.0, default 0 (centered)
```

Offset meaning:
- 0 = centered (default)
- -1 = show left/top edge
- +1 = show right/bottom edge

## Display logic

When displaying image in square frame:

```
function calculateImageOffset(imageAspectRatio, frameSize, clipOffsetX, clipOffsetY):
    if imageAspectRatio > 1:  // Landscape (wider than tall)
        // Image is scaled to fill height, excess width is clipped
        scaledWidth = frameSize * imageAspectRatio
        maxOffsetX = (scaledWidth - frameSize) / 2
        offsetX = clipOffsetX * maxOffsetX
        offsetY = 0  // No vertical movement possible
    else:  // Portrait (taller than wide)
        // Image is scaled to fill width, excess height is clipped
        scaledHeight = frameSize / imageAspectRatio
        maxOffsetY = (scaledHeight - frameSize) / 2
        offsetX = 0  // No horizontal movement possible
        offsetY = clipOffsetY * maxOffsetY

    return (offsetX, offsetY)
```

## Edit gesture logic

When editing and dragging on image:

```
function handleImageDrag(dragDelta, imageAspectRatio, frameSize):
    if imageAspectRatio > 1:  // Landscape
        scaledWidth = frameSize * imageAspectRatio
        maxOffsetX = (scaledWidth - frameSize) / 2
        // Convert drag pixels to normalized offset
        newOffsetX = clamp(currentOffsetX + dragDelta.x / maxOffsetX, -1, 1)
        return (newOffsetX, 0)
    else:  // Portrait
        scaledHeight = frameSize / imageAspectRatio
        maxOffsetY = (scaledHeight - frameSize) / 2
        newOffsetY = clamp(currentOffsetY + dragDelta.y / maxOffsetY, -1, 1)
        return (0, newOffsetY)
```

## Server API changes

Update post endpoint to accept and return:
- `clip_offset_x`: float (-1 to 1)
- `clip_offset_y`: float (-1 to 1)

Default to 0 for posts without these fields (backwards compatible).

## Patching instructions

1. **Post model**: Add clipOffsetX, clipOffsetY fields (client and server)
2. **PostView image display**: Apply calculated offset to image position
3. **PostView edit mode**: Add drag gesture to image when editing
4. **PostsAPI**: Include clip offset in post create/update requests
5. **Server**: Store and return clip offset fields
