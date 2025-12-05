# image-zoom iOS implementation

## ZoomableImageView

Located at the top of `PostView.swift`:

```swift
import UIKit

struct ZoomableImageView: UIViewRepresentable {
    let image: UIImage
    let size: CGSize
    let cornerRadius: CGFloat

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
        Coordinator()
    }

    class Coordinator: NSObject, UIScrollViewDelegate {
        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            return scrollView.viewWithTag(100)
        }

        func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
            // Snap back to 1.0 when fingers are lifted
            UIView.animate(withDuration: 0.15, delay: 0, options: .curveEaseOut) {
                scrollView.zoomScale = 1.0
            }
        }
    }
}
```

## State Variables in PostView

```swift
@State private var cachedUIImage: UIImage? = nil  // Cached UIImage for ZoomableImageView
```

## imageView Function

Always uses ZoomableImageView for all images:

```swift
// Image display - uses ZoomableImageView for pinch-to-zoom support
@ViewBuilder
private func imageView(width: CGFloat, height: CGFloat, imageUrl: String) -> some View {
    if imageUrl == "new_image", let displayImage = newImage {
        // New image being added - use ZoomableImageView
        ZoomableImageView(
            image: displayImage,
            size: CGSize(width: width, height: height),
            cornerRadius: 12 * cornerRoundness
        )
        .frame(width: width, height: height)
        .clipped()
    } else if let uiImage = cachedUIImage {
        // Cached image available - use ZoomableImageView
        ZoomableImageView(
            image: uiImage,
            size: CGSize(width: width, height: height),
            cornerRadius: 12 * cornerRoundness
        )
        .frame(width: width, height: height)
        .clipped()
    } else {
        // Loading state - show placeholder while we load
        Rectangle()
            .fill(Color.gray.opacity(0.3))
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: 12 * cornerRoundness))
    }
}
```

## Image Loading and Caching

```swift
ZStack(alignment: .topTrailing) {
    imageView(width: currentWidth, height: currentImageHeight, imageUrl: imageUrl)
    .task {
        // Load image and cache it for ZoomableImageView
        if cachedUIImage == nil && imageUrl != "new_image" {
            if let url = URL(string: fullUrl) {
                do {
                    let (data, _) = try await URLSession.shared.data(from: url)
                    if let uiImage = UIImage(data: data) {
                        cachedUIImage = uiImage
                        let aspectRatio = uiImage.size.width / uiImage.size.height
                        imageAspectRatio = aspectRatio
                        originalImageAspectRatio = aspectRatio
                    }
                } catch {
                    // Failed to load image, keep default aspect ratio
                }
            }
        }
    }
}
```

## Key Implementation Notes

- Uses `UIViewRepresentable` to wrap `UIScrollView` in SwiftUI
- `clipsToBounds = false` on scrollView allows zoomed image to overflow
- `imageView.tag = 100` used to find the image view in delegate methods
- UIImage cached in `cachedUIImage` since AsyncImage doesn't expose the underlying UIImage
- All images use ZoomableImageView (no conditional based on edit mode or expansion state)
- Coordinator class doesn't need parent reference since it doesn't track zoom state
