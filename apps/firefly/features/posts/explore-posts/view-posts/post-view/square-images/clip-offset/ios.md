# clip offset iOS implementation
*SwiftUI drag gesture and offset calculation*

## Files to modify

1. `Post.swift` - Add clip offset fields
2. `PostView.swift` - Display with offset, drag gesture when editing
3. `PostsAPI.swift` - Include clip offset in API calls

## 1. Post.swift changes

Add fields to Post struct:
```swift
struct Post: Codable, Identifiable {
    // ... existing fields ...
    var clipOffsetX: Double?  // -1 to 1, default 0 (centered)
    var clipOffsetY: Double?  // -1 to 1, default 0 (centered)
}
```

CodingKeys:
```swift
case clipOffsetX = "clip_offset_x"
case clipOffsetY = "clip_offset_y"
```

## 2. PostView.swift changes

### Add state for editing clip offset
```swift
@State private var editableClipOffsetX: Double = 0
@State private var editableClipOffsetY: Double = 0
@State private var dragStartOffsetX: Double = 0
@State private var dragStartOffsetY: Double = 0
```

### Initialize on appear
```swift
editableClipOffsetX = post.clipOffsetX ?? 0
editableClipOffsetY = post.clipOffsetY ?? 0
```

### Calculate pixel offset from normalized offset
```swift
func calculateImagePixelOffset(frameSize: CGFloat, imageAspectRatio: CGFloat, clipOffsetX: Double, clipOffsetY: Double) -> (CGFloat, CGFloat) {
    if imageAspectRatio > 1 {
        // Landscape: can move horizontally
        let scaledWidth = frameSize * imageAspectRatio
        let maxOffsetX = (scaledWidth - frameSize) / 2
        return (CGFloat(clipOffsetX) * maxOffsetX, 0)
    } else {
        // Portrait: can move vertically
        let scaledHeight = frameSize / imageAspectRatio
        let maxOffsetY = (scaledHeight - frameSize) / 2
        return (0, CGFloat(clipOffsetY) * maxOffsetY)
    }
}
```

### Update imageView function
```swift
private func imageView(width: CGFloat, height: CGFloat, imageUrl: String) -> some View {
    let (offsetX, offsetY) = calculateImagePixelOffset(
        frameSize: width,
        aspectRatio: imageAspectRatio,
        clipOffsetX: editableClipOffsetX,
        clipOffsetY: editableClipOffsetY
    )

    // ... existing image loading code ...

    image
        .resizable()
        .scaledToFill()
        .offset(x: offsetX, y: offsetY)  // Apply offset BEFORE frame
        .frame(width: width, height: height)
        .clipped()  // CRITICAL: Constrain layout bounds to frame
        .clipShape(RoundedRectangle(cornerRadius: 12 * cornerRoundness))
        .contentShape(Rectangle())
        .gesture(isEditing ? imageDragGesture(frameSize: width) : nil)
}
```

**Important modifier order:**
1. `.scaledToFill()` - scales image to fill frame (may extend beyond)
2. `.offset()` - shifts the scaled image for crop positioning
3. `.frame()` - sets the visible frame size
4. `.clipped()` - constrains layout bounds (prevents touch dead zones)
5. `.clipShape()` - applies rounded corners
6. `.contentShape()` - defines hit-testing area
7. `.gesture()` - attaches drag gesture when editing

**Why `.clipped()` is critical:**
Without `.clipped()`, portrait images scaled to fill create a layout that extends above/below the visible frame. This causes a "dead zone" where touches are intercepted by the image view even though it's visually clipped. Adding `.clipped()` after `.frame()` constrains both the visual rendering AND the layout bounds.

### Drag gesture for editing
```swift
func imageDragGesture(frameSize: CGFloat) -> some Gesture {
    DragGesture()
        .onChanged { value in
            if imageAspectRatio > 1 {
                // Landscape: horizontal drag
                let scaledWidth = frameSize * imageAspectRatio
                let maxOffsetX = (scaledWidth - frameSize) / 2
                let deltaX = value.translation.width / maxOffsetX
                editableClipOffsetX = max(-1, min(1, dragStartOffsetX + deltaX))
            } else {
                // Portrait: vertical drag
                let scaledHeight = frameSize / imageAspectRatio
                let maxOffsetY = (scaledHeight - frameSize) / 2
                let deltaY = value.translation.height / maxOffsetY
                editableClipOffsetY = max(-1, min(1, dragStartOffsetY + deltaY))
            }
        }
        .onEnded { _ in
            dragStartOffsetX = editableClipOffsetX
            dragStartOffsetY = editableClipOffsetY
        }
}
```

### Remember drag start on edit begin
When entering edit mode:
```swift
dragStartOffsetX = editableClipOffsetX
dragStartOffsetY = editableClipOffsetY
```

### Include in save request
When saving, include clip offsets in the update payload.

## 3. PostsAPI.swift changes

Add clip offset to update request body:
```swift
"clip_offset_x": clipOffsetX,
"clip_offset_y": clipOffsetY
```

## 4. Server changes (py.md)

Add columns to posts table:
```sql
clip_offset_x REAL DEFAULT 0,
clip_offset_y REAL DEFAULT 0
```

Include in POST/PUT handlers and SELECT queries.

## Key implementation notes

- Offset is normalized (-1 to 1) for storage, converted to pixels for display
- Drag only affects the relevant axis based on aspect ratio
- Square images (aspect ratio = 1) have no adjustment - entire image visible
- Backwards compatible: missing fields default to 0 (centered)
- Gesture only active when `isEditing` is true
- **Must use `.clipped()` after `.frame()`** to prevent touch dead zones on portrait images
- Reset clip offsets to (0, 0) when selecting a new image
