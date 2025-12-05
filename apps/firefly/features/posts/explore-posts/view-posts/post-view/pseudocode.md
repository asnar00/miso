# post-view pseudocode

## Parameters

```
availableWidth: Float  // passed from parent view, calculated as screenWidth - (2 * horizontalPadding)
```

## State

```
expansionFactor: Float = 0.0  // 0.0 = compact, 1.0 = expanded
imageAspectRatio: Float = 1.0  // loaded asynchronously from actual image
bodyTextHeight: Float = 200  // measured once on first expand using formatted text
titleSummaryHeight: Float = 60  // measured dynamically as title/summary renders
isMeasured: Boolean = false  // tracks whether we've measured body text yet
```

## Constants

```
compactHeight = 100pt
authorHeight = 15pt  // approximate height for author line
thumbnailPadding = 8pt  // inset from right edge for thumbnail
contentPadding = 18pt  // left padding for content
```

## Height Calculation

The expanded view height is computed from measured components:

```
imageHeight = (post has image) ? (availableWidth / imageAspectRatio) : 0
expandedHeight = titleSummaryHeight + 16 + imageHeight + 16 + bodyTextHeight + 24 + authorHeight + 16

currentHeight = lerp(compactHeight, expandedHeight, expansionFactor)
```

**Key detail**: Spacing is: title/summary → 16pt → image → 16pt → body → 24pt → author → 16pt bottom padding

## Image Position and Size

### Compact State (Thumbnail)
```
thumbnailSize = 80pt
compactWidth = thumbnailSize
compactHeight = thumbnailSize
compactX = availableWidth - thumbnailSize - thumbnailPadding  // inset from right edge
compactY = (compactHeight - thumbnailSize) / 2  // vertically centered in compact view
                           // NOTE: On Android, subtract Box padding (8pt) if coordinates are relative to padded area
```

### Expanded State (Full Image)
```
expandedWidth = availableWidth - (2 * contentPadding)  // image width with padding on both sides
expandedHeight = expandedWidth / imageAspectRatio
expandedX = contentPadding  // aligned with content left edge
expandedY = titleSummaryHeight + 8  // below title/summary with spacing
```

### Current Interpolated Values
```
currentWidth = lerp(compactWidth, expandedWidth, expansionFactor)
currentHeight = lerp(compactHeight, expandedHeight, expansionFactor)
currentX = lerp(compactX, expandedX, expansionFactor)
currentY = lerp(compactY, expandedY, expansionFactor)
```

**Key detail**: Image uses `.fill` aspect mode with clipping, maintaining aspect ratio at all expansion levels.

## Image Aspect Ratio Loading

```
when image first appears:
  if imageAspectRatio == 1.0:
    load image data from URL asynchronously
    extract width and height from image metadata
    imageAspectRatio = width / height
```

**Key detail**: Aspect ratio is loaded asynchronously to avoid blocking UI. Default 1.0 (square) is used until actual ratio loads.

## Body Text Positioning

**Critical detail**: Body text position is recalculated each frame to stay "stuck" to the bottom of the image.

```
// Recalculate current image position and height (same as image rendering)
currentImageY = lerp(compactImageY, expandedImageY, expansionFactor)
currentImageHeight = lerp(compactImageHeight, expandedImageHeight, expansionFactor)

// Position body text below current image position
bodyY = currentImageY + currentImageHeight + 16
currentBodyHeight = lerp(0, bodyTextHeight, expansionFactor)
```

Body text is always positioned relative to the *current* image position, not a fixed position. This makes the text move down smoothly with the image during expansion.

## Body Text Measurement

**Critical detail**: Measure the *formatted* text, not plain text, for accurate heights.

```
when expanding for the first time AND not yet measured:
  measure height of processBodyText(post.body) at availableWidth
  bodyTextHeight = measured height
  isMeasured = true
```

The formatted text includes:
- Heading formatting (18pt bold for ## headings)
- Bullet points (• prefix)
- Line break processing
- Image tag removal

This measurement only happens once on first expand (controlled by `isMeasured` flag).

## Author Metadata

**Critical detail**: Author metadata is hidden in compact view and fades in during expansion.

### Compact State
```
Author is not rendered (or has opacity = 0)
```

### Expanded State
```
authorX = 10pt  // aligned with content left edge
authorY = currentImageY + currentImageHeight + 16 + bodyTextHeight + 24
authorOpacity = expansionFactor  // fades in smoothly
```

**Key detail**: Author position also tracks the current image position, maintaining consistent spacing below body text.

## Text Formatting

### Title
```
font = 22pt bold
color = black
lineLimit = 1 (truncates with ellipsis)
```

### Summary
```
font = 15pt italic
color = black 80% opacity
lineLimit = 2 (truncates with ellipsis)
```

### Author
```
font = 15pt * fontScale * author-font-size (tunables)
color = black 50% opacity
prefix = "👓 librarian" if AI-generated, otherwise author name
button color (when clickable) = RGB where R=G=B=button-colour tunable (default 0.5)
```

## Navigate-to-Children Button

Posts with children (or query posts) show a circular button on the right side:

```
collapsedButtonSize = 32pt
expandedButtonSize = 42pt
currentButtonSize = lerp(collapsedButtonSize, expandedButtonSize, expansionFactor)

// Button center is positioned so 3/4 of radius overlaps post, 1/4 extends beyond
buttonCenterX = availableWidth - (currentButtonSize / 4)
buttonCenterY = currentHeight / 2  // vertically centered
```

## Edit Controls Positioning

Edit button and save/cancel/delete buttons right-align with the post's right edge:

```
editButtonX = availableWidth - editButtonSize - editButtonPadding
editControlsRightEdge = availableWidth - editButtonPadding
```

## Layout Strategy

All elements positioned in a ZStack with absolute positioning:

```
ZStack(alignment: topLeading):
  Background (rounded rectangle with shadow)
  Title/Summary (top-left, leaves room for thumbnail when compact)
  Image (interpolated position and size)
  Body Text (tracks image position, clipped to currentBodyHeight)
  Author (tracks image + body position, opacity = expansionFactor)
  Navigate-to-children button (right side, 3/4 overlapping post)
  Edit button / Edit controls (right-aligned with post edge)
```

## Interpolation Helper

```
function lerp(start, end, t):
  return start + (end - start) * t
```

## Animation

```
when user taps to toggle:
  if currently expanded:
    animate expansionFactor to 0.0 over 0.3s with easeInOut
  else:
    animate expansionFactor to 1.0 over 0.3s with easeInOut
```

**Key decision**: Single continuous parameter means animation can be interrupted mid-flight and reversed smoothly without jarring view swaps. All elements update automatically as expansionFactor changes.

## Expansion Visual Effects

When a post expands, it receives visual emphasis through animated effects:

### Background Brightness
```
baseBrightness = tunables.getDouble("post-background-brightness", default: 0.9)
expandedBrightness = min(baseBrightness * 1.2, 1.0)  // 120% brightness, clamped
currentBrightness = lerp(baseBrightness, expandedBrightness, expansionFactor)

background = Color.white.opacity(currentBrightness)
```

### Drop Shadow
```
shadowRadius = lerp(2, 16, expansionFactor)
shadowY = lerp(0, 16, expansionFactor)
shadowOpacity = lerp(0.2, 0.5, expansionFactor)

shadow = (color: Color.black.opacity(shadowOpacity), radius: shadowRadius, x: 0, y: shadowY)
```

### Z-Ordering
Expanded posts must render above collapsed posts to ensure shadows display correctly:
```
zIndex = (isExpanded) ? 1 : 0
```

**Key detail**: Without zIndex, posts later in the ForEach render on top of earlier posts, covering their shadows.

## Measurement Pattern

Use platform's measurement APIs to dynamically measure:

1. **Title/Summary height**: Measured as view renders using geometry reader
2. **Body text height**: Measured once on first expand using formatted text at fixed width
3. **Image aspect ratio**: Loaded asynchronously from image metadata

These measurements feed into the height calculation for smooth, accurate animations.
