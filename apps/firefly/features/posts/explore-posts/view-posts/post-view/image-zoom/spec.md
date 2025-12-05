# image-zoom
*Pinch-to-zoom on expanded post images with snap-back on release*

When viewing an expanded post with an image, users can pinch to zoom in on the image for a closer look. The zoomed image can be panned around. When the user releases their fingers, the image smoothly snaps back to its original size.

**How it works:**
- Tap a post to expand it
- Pinch outward on the image to zoom in (up to 4x magnification)
- While zoomed, drag to pan around the image
- Release fingers to snap back to normal size

**Visual behavior:**
- The zoom overlay appears seamlessly over the base image
- Zooming is smooth and responsive
- On release, the image animates back to 1x scale over 0.15 seconds
- The zoom feature is disabled while editing a post

**Technical approach:**
- Uses a UIScrollView overlay that's always present when expanded
- The overlay image is invisible at 1x scale
- When zoom exceeds 1.01x, the overlay becomes visible
- UIScrollView handles pinch gestures natively (no SwiftUI gesture interference)
