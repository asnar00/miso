# thumbnails iOS implementation
*Swift implementation of center-cropped square thumbnails*

## Overview

iOS implementation uses UIGraphicsImageRenderer to crop a centered square from the original image while preserving orientation metadata, then scales it to 80×80 pixels. This approach correctly handles portrait/landscape photos with EXIF orientation data.

## Implementation in ImageCache.swift

This is already implemented in the `resizeImage` method of ImageCache class:

```swift
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
```

## How It Works

### Step 1: Calculate Crop Rectangle

```swift
let cropSize = min(imageSize.width, imageSize.height)
```

Finds the smallest dimension to create the largest possible square.

**Example (landscape 3000×2000):**
- cropSize = 2000

```swift
let cropRect = CGRect(
    x: (imageSize.width - cropSize) / 2,
    y: (imageSize.height - cropSize) / 2,
    width: cropSize,
    height: cropSize
)
```

Centers the crop rectangle:
- x = (3000 - 2000) / 2 = 500
- y = (2000 - 2000) / 2 = 0
- Result: CGRect(x: 500, y: 0, width: 2000, height: 2000)

### Step 2: Crop Using UIGraphicsImageRenderer

```swift
let renderer = UIGraphicsImageRenderer(size: CGSize(width: cropSize, height: cropSize))
let croppedImage = renderer.image { context in
    let drawRect = CGRect(x: -cropRect.origin.x, y: -cropRect.origin.y,
                          width: imageSize.width, height: imageSize.height)
    image.draw(in: drawRect)
}
```

**Why UIGraphicsImageRenderer instead of CGImage cropping:**
- **Preserves orientation metadata**: Photos taken in portrait mode have EXIF orientation data. Using `cgImage.cropping()` loses this metadata, causing rotated/squashed thumbnails.
- **Respects image.draw()**: Drawing the UIImage automatically applies the correct orientation transformation.
- **Negative offset cropping**: By drawing the full image at a negative offset, we effectively crop to the desired region while maintaining orientation.

**How negative offset works:**
- Renderer creates a cropSize × cropSize canvas
- We draw the full image shifted by (-cropRect.origin.x, -cropRect.origin.y)
- Only the portion that falls within the canvas is visible
- Result: centered square crop

**Example (landscape 3000×2000):**
- Canvas: 2000×2000
- Draw at: (-500, 0) with size (3000, 2000)
- Visible portion: center 2000×2000 square

### Step 3: Scale to Target Size

```swift
let finalRenderer = UIGraphicsImageRenderer(size: targetSize)
return finalRenderer.image { _ in
    croppedImage.draw(in: CGRect(origin: .zero, size: targetSize))
}
```

- Creates renderer for 80×80 output
- Draws cropped image into 80×80 rect
- UIGraphicsImageRenderer handles high-quality scaling automatically

**Scaling quality:**
- Automatic interpolation (smooth, no jagged edges)
- Handles retina displays correctly (@2x, @3x)
- Maintains color accuracy

## Usage

Called automatically by `getThumbnail()` in ImageCache:

```swift
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

    // Resize to thumbnail (calls resizeImage)
    let thumbnail = resizeImage(fullImage, targetSize: CGSize(width: 80, height: 80))

    // Cache and return
    let cost = 80 * 80 * 4
    thumbnailCache.setObject(thumbnail, forKey: key as NSString, cost: cost)

    return thumbnail
}
```

## Performance Characteristics

**Time complexity:**
- Crop operation: O(n) where n = cropSize² pixels (renders to intermediate buffer)
- Scale operation: O(n) where n = 80×80 = 6,400 pixels (very fast)
- Total: ~10-20ms on modern iPhones

**Memory usage:**
- Input: Decoded full image (temporary, already in memory)
- Intermediate crop: cropSize×cropSize×4 bytes (e.g., 2000×2000×4 = ~16MB temporarily)
- Output: 80×80×4 bytes = 25,600 bytes (~25 KB cached)
- Intermediate buffer is released after scaling

**Quality:**
- UIGraphicsImageRenderer uses high-quality interpolation
- Properly handles EXIF orientation (no rotation issues)
- Appropriate for retina displays
- No visible artifacts at 80×80 size

## Testing

**Visual test:**
1. Load app with various image aspect ratios:
   - Landscape (3000×2000)
   - Portrait (2000×3000)
   - Square (2000×2000)
   - Panorama (4000×1000)
2. Check compact view thumbnails
3. Verify all show centered, square crops
4. Verify no stretching or distortion

**Code test:**
```swift
let testImage = UIImage(named: "test-landscape")!
let thumbnail = ImageCache.shared.resizeImage(testImage, targetSize: CGSize(width: 80, height: 80))

XCTAssertEqual(thumbnail.size.width, 80)
XCTAssertEqual(thumbnail.size.height, 80)
```

## Integration Points

**File:** `apps/firefly/product/client/imp/ios/NoobTest/ImageCache.swift`

**Method:** `resizeImage(_ image: UIImage, targetSize: CGSize) -> UIImage`

**Called by:** `getThumbnail(_ url: String)` when generating thumbnails from raw data

**Used by:** `PostsView.swift` compact view for displaying 80×80 thumbnails
