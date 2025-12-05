# image-zoom pseudocode

## Overview

Wraps post images in a zoomable container using UIScrollView for proper iOS pinch-to-zoom behavior with gesture-centered zooming.

## ZoomableImageView

```
struct ZoomableImageView:
    inputs:
        image: UIImage
        size: CGSize
        cornerRadius: CGFloat
        isZooming: Binding<Bool>

    create UIScrollView:
        minimumZoomScale = 1.0
        maximumZoomScale = 4.0
        bouncesZoom = true
        clipsToBounds = false  // Allow overflow during zoom
        showsScrollIndicators = false

    create UIImageView:
        contentMode = scaleAspectFill
        clipsToBounds = true
        cornerRadius = cornerRadius
        frame = size

    add imageView to scrollView
    set scrollView.contentSize = size

    delegate methods:
        viewForZooming -> return imageView

        scrollViewDidZoom:
            isZooming = (zoomScale > 1.0)

        scrollViewDidEndZooming:
            // Always snap back when fingers lifted
            animate(duration: 0.15, easeOut):
                scrollView.zoomScale = 1.0
            isZooming = false
```

## Integration with PostView

```
when rendering image in expanded post:
    if isExpanded AND NOT isEditing:
        use ZoomableImageView(image, size, cornerRadius, isZooming)
    else:
        use standard AsyncImage or Image view

state variables:
    isImageZooming: Bool = false
    loadedUIImage: UIImage? = nil  // Cached for zoomable view

on image load:
    cache UIImage for use in ZoomableImageView
```

## Key Implementation Details

- UIScrollView provides native iOS pinch-to-zoom with proper anchor point handling
- clipsToBounds = false allows image to overflow container during zoom
- Always snaps back to 1.0x on finger release (scrollViewDidEndZooming)
- 0.15s animation duration for quick, snappy feel
- UIImage must be cached separately since AsyncImage doesn't expose it
