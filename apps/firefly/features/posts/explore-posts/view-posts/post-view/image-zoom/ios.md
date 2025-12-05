# image-zoom iOS implementation

## ZoomableImageView

Located at the top of `PostView.swift`:

```swift
import UIKit

struct ZoomableImageView: UIViewRepresentable {
    let image: UIImage
    let size: CGSize
    let cornerRadius: CGFloat
    @Binding var isZooming: Bool

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 4.0
        scrollView.bouncesZoom = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.clipsToBounds = false  // Allow image to overflow
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
        Coordinator(self)
    }

    class Coordinator: NSObject, UIScrollViewDelegate {
        var parent: ZoomableImageView

        init(_ parent: ZoomableImageView) {
            self.parent = parent
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            return scrollView.viewWithTag(100)
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            parent.isZooming = scrollView.zoomScale > 1.0
        }

        func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
            // Always snap back to 1.0 when fingers are lifted
            UIView.animate(withDuration: 0.15, delay: 0, options: .curveEaseOut) {
                scrollView.zoomScale = 1.0
            }
            parent.isZooming = false
        }
    }
}
```

## State Variables in PostView

```swift
// Image zoom state
@State private var isImageZooming: Bool = false
@State private var loadedUIImage: UIImage? = nil  // Cached UIImage for zoomable view
```

## imageView Function

Updated to support zoomable mode:

```swift
private func imageView(width: CGFloat, height: CGFloat, imageUrl: String, zoomable: Bool = false) -> some View {
    Group {
        if imageUrl == "new_image", let displayImage = newImage {
            if zoomable {
                ZoomableImageView(
                    image: displayImage,
                    size: CGSize(width: width, height: height),
                    cornerRadius: 12 * cornerRoundness,
                    isZooming: $isImageZooming
                )
                .frame(width: width, height: height)
            } else {
                // Standard Image view
            }
        } else {
            if zoomable, let uiImage = loadedUIImage {
                ZoomableImageView(...)
            } else {
                // Standard AsyncImage view
            }
        }
    }
}
```

## Usage in Expanded Post

```swift
// Use zoomable image when expanded and not editing
let useZoomable = isExpanded && !isEditing

ZStack(alignment: .topTrailing) {
    imageView(width: currentWidth, height: currentImageHeight, imageUrl: imageUrl, zoomable: useZoomable)
    .task {
        // Load and cache UIImage for zoomable view
        if loadedUIImage == nil {
            // Fetch and cache...
            loadedUIImage = uiImage
        }
    }
}
```

## Key Implementation Notes

- Uses `UIViewRepresentable` to wrap `UIScrollView` in SwiftUI
- `clipsToBounds = false` on scrollView allows zoomed image to overflow
- `imageView.tag = 100` used to find the image view in delegate methods
- UIImage cached in `loadedUIImage` since AsyncImage doesn't expose the underlying UIImage
- Zoomable mode only enabled when `isExpanded && !isEditing`
