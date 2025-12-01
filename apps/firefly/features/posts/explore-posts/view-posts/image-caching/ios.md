# iOS image caching implementation
*iOS-specific implementation using NSCache and UIImage*

## Implementation in ImageCache.swift

Replace the existing single-cache implementation with three separate NSCache instances:

```swift
import UIKit

class ImageCache {
    static let shared = ImageCache()

    // Three-tier cache system
    private var rawDataCache = NSCache<NSString, NSData>()
    private var thumbnailCache = NSCache<NSString, UIImage>()
    private var fullImageCache = NSCache<NSString, UIImage>()

    private init() {
        // Raw data: 500 MB - holds compressed JPG/PNG bytes
        rawDataCache.totalCostLimit = 500 * 1024 * 1024
        rawDataCache.countLimit = 200

        // Thumbnails: 20 MB - holds 80x80 decoded images
        thumbnailCache.totalCostLimit = 20 * 1024 * 1024
        thumbnailCache.countLimit = 400

        // Full images: 100 MB - holds recently decoded full-size images
        fullImageCache.totalCostLimit = 100 * 1024 * 1024
        fullImageCache.countLimit = 10
    }

    // Get raw data (compressed bytes)
    func getRawData(_ url: String) -> Data? {
        return rawDataCache.object(forKey: url as NSString) as Data?
    }

    // Set raw data with size cost
    func setRawData(_ url: String, data: Data) {
        rawDataCache.setObject(data as NSData, forKey: url as NSString, cost: data.count)
    }

    // Get thumbnail (80x80)
    func getThumbnail(_ url: String) -> UIImage? {
        let key = url + ":thumb"
        if let cached = thumbnailCache.object(forKey: key as NSString) {
            return cached
        }

        // Generate from raw data if available
        guard let rawData = getRawData(url),
              let fullImage = UIImage(data: rawData) else {
            return nil
        }

        // Resize to thumbnail
        let thumbnail = resizeImage(fullImage, targetSize: CGSize(width: 80, height: 80))

        // Calculate cost (width * height * 4 bytes per pixel)
        let cost = 80 * 80 * 4
        thumbnailCache.setObject(thumbnail, forKey: key as NSString, cost: cost)

        return thumbnail
    }

    // Get full image
    func getFullImage(_ url: String) -> UIImage? {
        if let cached = fullImageCache.object(forKey: url as NSString) {
            return cached
        }

        // Decode from raw data if available
        guard let rawData = getRawData(url),
              let image = UIImage(data: rawData) else {
            return nil
        }

        // Calculate cost (width * height * 4 bytes per pixel)
        let cost = Int(image.size.width * image.size.height * 4)
        fullImageCache.setObject(image, forKey: url as NSString, cost: cost)

        return image
    }

    // Resize image to target size (for thumbnails)
    private func resizeImage(_ image: UIImage, targetSize: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }

    // Preload images (download raw data, generate thumbnails)
    func preload(urls: [String], completion: @escaping () -> Void) {
        let group = DispatchGroup()

        for urlString in urls {
            guard let url = URL(string: urlString) else { continue }

            // Skip if already cached
            if getRawData(urlString) != nil {
                continue
            }

            group.enter()
            URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
                defer { group.leave() }

                guard let data = data else { return }

                // Store raw data
                self?.setRawData(urlString, data: data)

                // Pre-generate thumbnail (cheap and useful)
                _ = self?.getThumbnail(urlString)

                // Don't pre-decode full image (waste of memory)
            }.resume()
        }

        group.notify(queue: .main) {
            completion()
        }
    }
}
```

## Integration with PostsView

**Compact View (PostsView.swift:189-217):**

Replace:
```swift
if let cachedImage = ImageCache.shared.get(fullUrl) {
    Image(uiImage: cachedImage)
```

With:
```swift
if let thumbnail = ImageCache.shared.getThumbnail(fullUrl) {
    Image(uiImage: thumbnail)
```

**Full View (PostsView.swift:244-269):**

Replace:
```swift
if let cachedImage = ImageCache.shared.get(fullUrl) {
    Image(uiImage: cachedImage)
```

With:
```swift
if let fullImage = ImageCache.shared.getFullImage(fullUrl) {
    Image(uiImage: fullImage)
```

## NSCache Cost Calculation

For decoded images, cost = width × height × 4 (RGBA bytes per pixel):
- 80×80 thumbnail = 25,600 bytes (~25KB)
- 2000×1500 full image = 12,000,000 bytes (~12MB)
- 4000×3000 full image = 48,000,000 bytes (~48MB)

For raw data, cost = data.count (compressed file size)
