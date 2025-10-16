# compact-view pseudocode

## Layout Structure

```
HStack (horizontal layout, top-aligned, 12pt spacing):
  VStack (left side, leading-aligned, 6pt spacing):
    Text(title) - 20pt bold, black
    Text(summary) - 14pt subheadline, italic, 80% opacity

  Spacer() - pushes content apart

  If post.imageUrl exists:
    Image (80x80pt, rounded corners 12pt, aspect fill)
```

## Height Measurement

To ensure collapse animations match the actual compact view height:

```
state: measuredCompactHeight = 110pt (initial estimate)

compactView:
  render layout as above
  attach background geometry reader:
    on appear:
      measuredCompactHeight = geometry.size.height
```

**Key decision**: Use a background GeometryReader rather than wrapping the entire view, to avoid breaking the natural layout while still capturing the true rendered height.

## Image Handling

```
fullImageUrl = serverURL + post.imageUrl

if cachedImage exists in ImageCache:
  display cachedImage
else:
  use AsyncImage fallback:
    on success: display image
    on failure/empty: display gray placeholder rectangle
```

**Key decision**: Check cache first for instant display, fall back to AsyncImage only when cache misses (rare after preloading).
