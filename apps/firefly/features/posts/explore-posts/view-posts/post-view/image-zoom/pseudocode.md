# image-zoom pseudocode

## Overview

Pinch-to-zoom on expanded post images using an invisible overlay approach. A UIScrollView-based overlay sits on top of the base image, handling pinch gestures natively. The overlay image is invisible at scale 1.0 and becomes visible when zooming.

## Key Insight

SwiftUI's MagnificationGesture captures pinch events before UIKit views can receive them. Solution: have the UIScrollView always present (but invisible) so it receives gestures directly.

## State Variables

```
isZooming: Bool = false        // True when actively zooming (scale > 1.01)
cachedUIImage: UIImage? = nil  // Cached image for zoom overlay
```

## ZoomableImageOverlay Component

```
ZoomableImageOverlay(image, size, cornerRadius, isZooming binding):
    // UIScrollView setup
    scrollView.minimumZoomScale = 1.0
    scrollView.maximumZoomScale = 4.0
    scrollView.bouncesZoom = true
    scrollView.clipsToBounds = false  // Allow overflow during zoom

    // ImageView inside scrollView
    imageView.contentMode = .fill
    imageView.alpha = 0  // Start invisible

    // Delegate callbacks:
    viewForZooming():
        return imageView

    scrollViewDidZoom(scale):
        if scale > 1.01:
            imageView.alpha = 1.0
            isZooming = true
        else:
            imageView.alpha = 0.0
            isZooming = false

    scrollViewDidEndZooming(scale):
        animate(duration: 0.15):
            scrollView.zoomScale = 1.0
            imageView.alpha = 0.0
        then:
            isZooming = false
```

## Image Display with Zoom Overlay

```
// In post view, when displaying image:
ZStack:
    // Base image layer (always visible)
    imageView(width, height, imageUrl)

    // Zoom overlay - present when fully expanded, not editing
    if expansionFactor >= 0.99 && !isEditing && cachedUIImage != nil:
        ZoomableImageOverlay(
            image: cachedUIImage,
            size: (width, height),
            cornerRadius: 12 * cornerRoundness,
            isZooming: $isZooming
        )
```

## Image Caching

```
// Load image on appear to cache for zoom
.task:
    if cachedUIImage == nil && imageUrl != "new_image":
        data = fetch(fullUrl)
        cachedUIImage = UIImage(data)
        imageAspectRatio = width / height
```

## Key Parameters

- Minimum zoom: 1.0x
- Maximum zoom: 4.0x
- Visibility threshold: 1.01x (overlay becomes visible above this)
- Snap-back animation: 0.15 seconds, ease-out curve
- Expansion threshold: 0.99 (overlay only present when nearly fully expanded)
