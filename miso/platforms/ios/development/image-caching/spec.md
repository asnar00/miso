# image caching
*fast, responsive image loading in SwiftUI with preloading and in-memory caching*

## Overview

For smooth, instant image display in iOS apps, especially when showing lists of posts or content with images, you need a multi-layered caching approach that combines URLCache for network efficiency with an in-memory cache of decoded UIImage objects.

## The Problem with AsyncImage

SwiftUI's built-in `AsyncImage` can cause visible loading delays even when image data is cached because:

1. **On-demand decoding**: Even if the image data is in URLCache, AsyncImage decodes the image every time it's displayed
2. **No preloading**: AsyncImage only starts loading when the view appears
3. **Loading states**: You see spinners or blank spaces while images load

**Result**: When expanding a post from compact to full view, you feel a "loading" delay even with good network caching.

## Solution: Custom ImageCache with UIImage Objects

Create a cache that stores fully decoded `UIImage` objects, not just raw data:

```swift
import UIKit

class ImageCache {
    static let shared = ImageCache()
    private var cache = NSCache<NSString, UIImage>()

    private init() {
        cache.countLimit = 100              // Max 100 images
        cache.totalCostLimit = 50 * 1024 * 1024  // 50MB memory
    }

    func get(_ url: String) -> UIImage? {
        return cache.object(forKey: url as NSString)
    }

    func set(_ url: String, image: UIImage) {
        cache.setObject(image, forKey: url as NSString)
    }

    func preload(urls: [String], completion: @escaping () -> Void) {
        let group = DispatchGroup()

        for urlString in urls {
            guard let url = URL(string: urlString) else { continue }

            // Skip if already cached
            if get(urlString) != nil {
                continue
            }

            group.enter()
            URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
                defer { group.leave() }

                guard let data = data,
                      let image = UIImage(data: data) else {
                    return
                }

                self?.set(urlString, image: image)
            }.resume()
        }

        group.notify(queue: .main) {
            completion()
        }
    }
}
```

### Key Benefits

- **NSCache**: Automatically manages memory, evicts old images under pressure
- **Decoded images**: `UIImage(data: data)` does decoding work up front
- **Instant display**: SwiftUI just renders the ready-to-use UIImage
- **Skip duplicates**: Checks cache before downloading

## URLCache Configuration

Configure URLCache at app startup for better network caching:

```swift
// In your App's init()
let memoryCapacity = 50 * 1024 * 1024  // 50 MB
let diskCapacity = 100 * 1024 * 1024   // 100 MB
let cache = URLCache(memoryCapacity: memoryCapacity, diskCapacity: diskCapacity)
URLCache.shared = cache
```

This works alongside ImageCache:
- **URLCache**: Reduces network requests (disk + memory cache of raw data)
- **ImageCache**: Reduces decoding work (memory cache of decoded images)

## Priority Loading Pattern

When loading a list of posts, show the first post immediately while loading others in background:

```swift
func preloadImagesOptimized(for posts: [Post], completion: @escaping () -> Void) {
    let serverURL = "http://your-server.com"
    let imageUrls = posts.compactMap { post -> String? in
        guard let imageUrl = post.imageUrl else { return nil }
        return serverURL + imageUrl
    }

    guard !imageUrls.isEmpty else {
        completion()
        return
    }

    // Load first image, then display
    let firstUrl = imageUrls[0]
    ImageCache.shared.preload(urls: [firstUrl]) {
        completion()  // UI shows posts now

        // Continue loading remaining images in background
        if imageUrls.count > 1 {
            let remainingUrls = Array(imageUrls[1...])
            ImageCache.shared.preload(urls: remainingUrls) {
                // Background loading complete
            }
        }
    }
}
```

### Why This Works

1. **Fast initial display**: Only wait for first image, not hundreds
2. **Progressive loading**: Remaining images load while user reads
3. **No blocking**: Background loading doesn't affect UI responsiveness

## SwiftUI Integration

Replace `AsyncImage` with direct `Image(uiImage:)` that checks the cache:

**Before (slow)**:
```swift
AsyncImage(url: URL(string: serverURL + post.imageUrl)) { image in
    image
        .resizable()
        .aspectRatio(contentMode: .fit)
} placeholder: {
    ProgressView()  // User sees loading spinner
}
```

**After (instant)**:
```swift
if let imageUrl = post.imageUrl,
   let cachedImage = ImageCache.shared.get(serverURL + imageUrl) {
    Image(uiImage: cachedImage)
        .resizable()
        .aspectRatio(contentMode: .fit)
}
```

No placeholder needed - the image is already in memory, fully decoded.

## Complete Workflow

### 1. App Startup
Configure URLCache in your App's `init()`.

### 2. Load Data
When fetching posts/content from server:

```swift
PostsAPI.shared.fetchRecentPosts { result in
    switch result {
    case .success(let fetchedPosts):
        self.preloadImagesOptimized(for: fetchedPosts) {
            DispatchQueue.main.async {
                self.posts = fetchedPosts
                self.isLoading = false
            }
        }
    case .failure(let error):
        // Handle error
    }
}
```

### 3. Display Images
Use cached images directly in SwiftUI views.

## Performance Characteristics

**Initial load time**:
- Without optimization: Wait for all images
- With optimization: Wait for first image only (~100-500ms)

**Expand/scroll time**:
- Without optimization: 100-300ms decode + display lag
- With optimization: <10ms instant display from cache

**Memory usage**:
- 50MB cache limit (configurable)
- NSCache automatically evicts under memory pressure

## When to Use This Pattern

✅ **Use when**:
- Displaying lists of images (social feeds, galleries, catalogs)
- Users frequently revisit the same images
- Smooth, instant image appearance is important
- You have control over image loading timing

❌ **Don't use when**:
- Displaying single images rarely
- Images are very large (>5MB each)
- AsyncImage's built-in handling is sufficient
- Memory constraints are tight

## Common Pitfalls

1. **Forgetting to preload**: Cache is empty until you call `preload()`
2. **Loading too many**: Don't preload hundreds of images at startup
3. **Not checking cache first**: Always check `get()` before downloading
4. **Memory leaks**: Use `[weak self]` in closures

## Testing

To verify instant display:
1. Clear app and relaunch
2. First load: Should see first post quickly
3. Expand/collapse posts: Should be instant (no loading feel)
4. Scroll through list: Images appear immediately

Look for:
- No blank spaces where images should be
- No loading spinners on expand/collapse
- Smooth animations without stuttering
