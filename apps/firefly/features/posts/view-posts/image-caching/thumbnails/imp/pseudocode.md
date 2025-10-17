# thumbnails implementation
*platform-agnostic thumbnail generation from images*

## Overview

Generates square 80×80 pixel thumbnails from images of any aspect ratio by cropping a centered square from the original image and scaling it down. This preserves the aspect ratio and shows the most relevant central portion of the image.

## Algorithm

**Input:** Original image (any dimensions, any aspect ratio)
**Output:** 80×80 pixel square thumbnail

**Steps:**

1. **Get original dimensions**
   - Read image width and height
   - Example: 3000×2000 (landscape) or 2000×3000 (portrait)

2. **Calculate crop size**
   - Find smallest dimension: `cropSize = min(width, height)`
   - This gives the largest square that fits in the image
   - Example: 3000×2000 → cropSize = 2000

3. **Calculate crop position (centered)**
   - Horizontal offset: `x = (width - cropSize) / 2`
   - Vertical offset: `y = (height - cropSize) / 2`
   - Example: 3000×2000 with cropSize 2000 → x = 500, y = 0

4. **Crop square region**
   - Extract region at position (x, y) with size (cropSize × cropSize)
   - This creates a square image showing the center of the original
   - Example: Crop 2000×2000 square from center of 3000×2000 image

5. **Scale to target size**
   - Resize cropped square to 80×80 pixels
   - Use high-quality scaling/interpolation
   - Result: 80×80 thumbnail

## Examples

**Landscape image (3000×2000):**
- Crop size: 2000×2000 (full height, centered width)
- Crop position: (500, 0)
- Crops from horizontal center, preserves vertical content
- Scales to 80×80

**Portrait image (2000×3000):**
- Crop size: 2000×2000 (full width, centered height)
- Crop position: (0, 500)
- Crops from vertical center, preserves horizontal content
- Scales to 80×80

**Square image (2000×2000):**
- Crop size: 2000×2000 (entire image)
- Crop position: (0, 0)
- No cropping needed, just scale
- Scales to 80×80

## Why This Approach

**Advantages:**
- Preserves aspect ratio (no stretching or squashing)
- Shows most relevant center content
- Consistent 80×80 output size for layout
- Works with any input aspect ratio
- Efficient - single crop + scale operation

**Alternatives not used:**
- Simple scaling: Would distort images, changing aspect ratio
- Corner cropping: Would miss important centered content
- Multiple thumbnails: Would complicate UI layout

## Integration with Cache

The thumbnail generation is part of the image cache system:

1. **When image is downloaded:**
   - Store raw compressed data in raw data cache
   - Generate thumbnail using this algorithm
   - Store 80×80 thumbnail in thumbnail cache

2. **When thumbnail is needed:**
   - Check thumbnail cache first
   - If not cached, generate from raw data using this algorithm
   - Cache result for future use

## Performance

- One-time cost when image first loaded
- Subsequent uses load from thumbnail cache (instant)
- Cropping is fast (simple pixel selection)
- Scaling is fast (80×80 is small)
- Total time: ~5-15ms per thumbnail generation

## Quality Considerations

- Use high-quality interpolation for scaling
- Avoid aliasing/jagged edges
- 80×80 is sufficient for compact view preview
- Center cropping assumes subjects are centered (common in photos)
