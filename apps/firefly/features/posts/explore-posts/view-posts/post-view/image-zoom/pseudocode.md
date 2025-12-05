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

    create UIScrollView:
        minimumZoomScale = 1.0
        maximumZoomScale = 4.0
        bouncesZoom = true
        clipsToBounds = false  // Allow overflow during zoom
        showsScrollIndicators = false
        backgroundColor = clear

    create UIImageView:
        contentMode = scaleAspectFill
        clipsToBounds = true
        cornerRadius = cornerRadius
        frame = size
        tag = 100  // For finding in delegate

    add imageView to scrollView
    set scrollView.contentSize = size

    delegate methods:
        viewForZooming -> return scrollView.viewWithTag(100)

        scrollViewDidEndZooming:
            // Always snap back when fingers lifted
            animate(duration: 0.15, easeOut):
                scrollView.zoomScale = 1.0
```

## Integration with PostView

```
imageView function:
    always use ZoomableImageView for all images

    if imageUrl == "new_image" and newImage exists:
        use ZoomableImageView(newImage, size, cornerRadius)
    else if cachedUIImage exists:
        use ZoomableImageView(cachedUIImage, size, cornerRadius)
    else:
        show placeholder Rectangle while loading

state variables:
    cachedUIImage: UIImage? = nil  // Cached for zoomable view

on image load (via .task modifier):
    fetch image data from URL
    convert to UIImage and cache in cachedUIImage
```

## Key Implementation Details

- UIScrollView provides native iOS pinch-to-zoom with proper anchor point handling
- clipsToBounds = false allows image to overflow container during zoom
- Always snaps back to 1.0x on finger release (scrollViewDidEndZooming)
- 0.15s animation duration for quick, snappy feel
- UIImage cached in cachedUIImage since AsyncImage doesn't expose it
- All images use ZoomableImageView (no conditional based on edit mode)
