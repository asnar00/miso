# compact-view iOS implementation

## SwiftUI View Structure

```swift
@State private var measuredCompactHeight: CGFloat = 110

var compactView: some View {
    HStack(alignment: .top, spacing: 12) {
        VStack(alignment: .leading, spacing: 6) {
            Text(post.title)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.black)

            Text(post.summary)
                .font(.subheadline)
                .italic()
                .foregroundColor(.black.opacity(0.8))
        }

        Spacer()

        if let imageUrl = post.imageUrl {
            let fullUrl = serverURL + imageUrl
            if let cachedImage = ImageCache.shared.get(fullUrl) {
                Image(uiImage: cachedImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                AsyncImage(url: URL(string: fullUrl)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    case .failure(_), .empty:
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    @unknown default:
                        EmptyView()
                    }
                }
            }
        }
    }
    .background(
        GeometryReader { geometry in
            Color.clear.onAppear {
                measuredCompactHeight = geometry.size.height
            }
        }
    )
}
```

## Key iOS-Specific Decisions

**GeometryReader Placement**: Attached as a background modifier rather than wrapping the content. This allows the HStack to maintain its natural sizing while still reporting its height.

**Image Caching**: Use `ImageCache.shared.get(fullUrl)` to check cache first, returning `UIImage?`. Only create `AsyncImage` when cache misses.

**Color Opacity**: Use `.opacity(0.8)` modifier on text color for the summary's 80% opacity effect.

**Clip Shape**: Use `.clipShape(RoundedRectangle(cornerRadius: 12))` rather than `.cornerRadius()` for the image, as it provides cleaner clipping for the aspect-fill image.
