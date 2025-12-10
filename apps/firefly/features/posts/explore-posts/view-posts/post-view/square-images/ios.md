# square images iOS implementation
*SwiftUI changes for square image display*

## File to modify

`PostView.swift`

## Changes

### 1. Update calculatedImageHeight function

Change from:
```swift
func calculatedImageHeight(contentWidth: CGFloat, imageAspectRatio: CGFloat, addImageButtonHeight: CGFloat) -> CGFloat {
    if editableImageUrl != nil {
        return contentWidth / imageAspectRatio
    } else if isEditing {
        return addImageButtonHeight
    } else {
        return 0
    }
}
```

To:
```swift
func calculatedImageHeight(contentWidth: CGFloat, imageAspectRatio: CGFloat, addImageButtonHeight: CGFloat) -> CGFloat {
    if editableImageUrl != nil {
        return contentWidth  // Square: height equals width
    } else if isEditing {
        return addImageButtonHeight
    } else {
        return 0
    }
}
```

### 2. Update direct expandedImageHeight calculation

Find any `contentWidth / imageAspectRatio` calculations and replace with `contentWidth`.

Example (around line 866):
```swift
// Before:
let expandedImageHeight = contentWidth / imageAspectRatio

// After:
let expandedImageHeight = contentWidth  // Square
```

## imageView function update

The `imageView` function must use this modifier order:

```swift
image
    .resizable()
    .scaledToFill()
    .offset(x: offsetX, y: offsetY)  // For clip-offset feature
    .frame(width: width, height: height)
    .clipped()  // CRITICAL: Constrain layout bounds
    .clipShape(RoundedRectangle(cornerRadius: 12 * cornerRoundness))
    .contentShape(Rectangle())
    .gesture(isEditing ? imageDragGesture(frameSize: width) : nil)
```

**Why `.clipped()` is required:**
- `.scaledToFill()` scales the image to fill the frame, but portrait images extend above/below the visible area
- Without `.clipped()`, the layout bounds include the full scaled image
- This creates a "dead zone" below the visible square where touches are intercepted
- Adding `.clipped()` after `.frame()` constrains both rendering AND layout bounds
- Without this fix, tapping on body text below a portrait image doesn't work in edit mode
