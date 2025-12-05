# image-zoom iOS implementation

## ZoomableImageOverlay Component

Located at top of `PostView.swift`:

```swift
// MARK: - ZoomableImageOverlay (always present when expanded, invisible at scale 1.0)

struct ZoomableImageOverlay: UIViewRepresentable {
    let image: UIImage
    let size: CGSize
    let cornerRadius: CGFloat
    @Binding var isZooming: Bool  // True when user is actively zooming (scale > 1)

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 4.0
        scrollView.bouncesZoom = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.clipsToBounds = false  // Allow image to overflow during zoom
        scrollView.backgroundColor = .clear

        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = cornerRadius
        imageView.frame = CGRect(origin: .zero, size: size)
        imageView.tag = 100
        imageView.alpha = 0  // Start invisible - only show when zooming

        scrollView.addSubview(imageView)
        scrollView.contentSize = size

        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        if let imageView = scrollView.viewWithTag(100) as? UIImageView {
            imageView.image = image
            imageView.frame = CGRect(origin: .zero, size: size)
            imageView.layer.cornerRadius = cornerRadius
        }
        scrollView.contentSize = size
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIScrollViewDelegate {
        var parent: ZoomableImageOverlay

        init(_ parent: ZoomableImageOverlay) {
            self.parent = parent
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            return scrollView.viewWithTag(100)
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            // Show the overlay image when zooming starts (scale > 1)
            if let imageView = scrollView.viewWithTag(100) {
                let isZooming = scrollView.zoomScale > 1.01
                imageView.alpha = isZooming ? 1.0 : 0.0

                // Update binding on main thread
                DispatchQueue.main.async {
                    self.parent.isZooming = isZooming
                }
            }
        }

        func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
            // Snap back to 1.0 and hide overlay
            UIView.animate(withDuration: 0.15, delay: 0, options: .curveEaseOut) {
                scrollView.zoomScale = 1.0
                if let imageView = scrollView.viewWithTag(100) {
                    imageView.alpha = 0.0
                }
            } completion: { _ in
                DispatchQueue.main.async {
                    self.parent.isZooming = false
                }
            }
        }
    }
}
```

## State Variables in PostView

```swift
// Zoom overlay state
@State private var isZooming: Bool = false  // True when user is actively zooming
@State private var cachedUIImage: UIImage? = nil  // Cached for zoom overlay
```

## Image Display with Zoom Overlay

In the image display section of `postContent`:

```swift
ZStack(alignment: .topTrailing) {
    // Base image layer
    imageView(width: currentWidth, height: currentImageHeight, imageUrl: imageUrl)
    .task {
        // Load image to get aspect ratio and cache for zoom overlay
        if cachedUIImage == nil && imageUrl != "new_image" {
            if let url = URL(string: fullUrl) {
                do {
                    let (data, _) = try await URLSession.shared.data(from: url)
                    if let uiImage = UIImage(data: data) {
                        cachedUIImage = uiImage
                        let aspectRatio = uiImage.size.width / uiImage.size.height
                        imageAspectRatio = aspectRatio
                        originalImageAspectRatio = aspectRatio  // Save original
                    }
                } catch {
                    // Failed to load image, keep default aspect ratio
                }
            }
        }
    }

    // Zoom overlay - always present when expanded (but invisible at scale 1.0)
    // The UIScrollView handles pinch gestures directly
    if expansionFactor >= 0.99 && !isEditing, let zoomImage = (imageUrl == "new_image" ? newImage : cachedUIImage) {
        ZoomableImageOverlay(
            image: zoomImage,
            size: CGSize(width: currentWidth, height: currentImageHeight),
            cornerRadius: 12 * cornerRoundness,
            isZooming: $isZooming
        )
        .frame(width: currentWidth, height: currentImageHeight)
    }

    // ... edit buttons follow
}
```

## Key Implementation Notes

1. **No SwiftUI gestures**: Unlike earlier attempts, we don't use `MagnificationGesture`. SwiftUI gestures capture events before UIKit can receive them.

2. **Always-present overlay**: The `ZoomableImageOverlay` is always in the view hierarchy when expanded. This ensures the `UIScrollView` receives pinch gestures directly.

3. **Invisible at rest**: The image inside the overlay has `alpha = 0` at scale 1.0. This lets the base `AsyncImage` show through while the overlay captures gestures.

4. **Visibility threshold**: The overlay image becomes visible when `zoomScale > 1.01`. This small threshold prevents flickering at exactly 1.0.

5. **Snap-back animation**: When zooming ends, the image animates back to 1.0 scale over 0.15 seconds with ease-out timing.

6. **Expansion gating**: The overlay only appears when `expansionFactor >= 0.99` to avoid gesture conflicts during expand/collapse animations.

7. **Edit mode disabled**: Zoom is disabled while editing (`!isEditing`) to prevent accidental zooms while managing images.
