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
        let cost = Int(image.size.width * image.size.height * image.scale * image.scale * 4)
        fullImageCache.setObject(image, forKey: url as NSString, cost: cost)

        return image
    }

    // Crop and resize image to target size (for thumbnails)
    // Crops a centered square from the image, then scales to target size
    private func resizeImage(_ image: UIImage, targetSize: CGSize) -> UIImage {
        let imageSize = image.size

        // Determine the crop size (largest square that fits in the image)
        let cropSize = min(imageSize.width, imageSize.height)

        // Calculate the crop rectangle (centered)
        let cropRect = CGRect(
            x: (imageSize.width - cropSize) / 2,
            y: (imageSize.height - cropSize) / 2,
            width: cropSize,
            height: cropSize
        )

        // Use UIGraphicsImageRenderer to properly handle orientation
        // This approach respects the image's orientation metadata
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: cropSize, height: cropSize))
        let croppedImage = renderer.image { context in
            // Draw the portion we want to keep
            let drawRect = CGRect(x: -cropRect.origin.x, y: -cropRect.origin.y,
                                  width: imageSize.width, height: imageSize.height)
            image.draw(in: drawRect)
        }

        // Scale the cropped square to target size
        let finalRenderer = UIGraphicsImageRenderer(size: targetSize)
        return finalRenderer.image { _ in
            croppedImage.draw(in: CGRect(origin: .zero, size: targetSize))
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
