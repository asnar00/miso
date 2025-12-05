# image-zoom
*pinch-to-zoom on post images with smooth snap-back*

Users can zoom into any post image using the standard pinch-to-zoom gesture. This allows closer inspection of image details without leaving the post view.

**Gesture Behavior:**
- Pinch outward on an image to zoom in
- The image grows beyond its container, overlapping surrounding UI temporarily
- The zoom centers on the pinch gesture location (standard iOS UIScrollView behavior)
- Only the image zooms - surrounding UI stays at normal size

**Zoom Limits:**
- Minimum scale: 1.0x (original size)
- Maximum scale: 4.0x (prevents excessive zoom)

**Release Behavior:**
- When the user lifts their fingers, the image immediately snaps back to 1.0x scale
- Animation uses ease-out timing (0.15s duration) for a quick, snappy feel
- The image returns to its original size and position

**Interaction Notes:**
- All images use ZoomableImageView for consistent zoom behavior
- Uses UIScrollView wrapped in UIViewRepresentable for proper iOS pinch behavior
- The zoom gesture feels responsive and tracks fingers accurately around pinch center
