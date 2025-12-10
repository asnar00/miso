# square images pseudocode
*display logic for square image frames*

## Core concept

When displaying an image in expanded post view:
- Frame dimensions: width = contentWidth, height = contentWidth (square)
- Content mode: fill (scale to fill frame, clip overflow)
- Clip shape: rounded rectangle matching post style

## Function modifications

### calculatedImageHeight

**Current behavior:** Returns `contentWidth / imageAspectRatio`
**New behavior:** Returns `contentWidth` (square)

```
function calculatedImageHeight(contentWidth, imageAspectRatio, addImageButtonHeight):
    if image exists:
        return contentWidth  # Square: height equals width
    else if editing:
        return addImageButtonHeight
    else:
        return 0
```

### expandedImageHeight calculations

Any direct calculation of `contentWidth / imageAspectRatio` for layout purposes should become just `contentWidth`.

## Patching instructions

In PostView:
1. Modify `calculatedImageHeight()` to return `contentWidth` instead of `contentWidth / imageAspectRatio`
2. Update any direct `contentWidth / imageAspectRatio` calculations to use `contentWidth`
3. **Critical:** Ensure `imageView` uses `.clipped()` after `.frame()` to constrain layout bounds

## Image view modifier order

The image must use this modifier sequence:
```
image
    .scaledToFill()      # Scale to fill frame (may extend beyond)
    .offset(...)         # Optional: shift for crop positioning
    .frame(w, h)         # Set visible frame size
    .clipped()           # Constrain LAYOUT bounds to frame
    .clipShape(...)      # Apply rounded corners
```

**Why `.clipped()` is critical:**
Without it, portrait images scaled to fill create layout bounds extending beyond the visible frame. This causes a "dead zone" where touches below the square image are intercepted, preventing interaction with content underneath (like body text in edit mode).
