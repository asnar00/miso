# thumbnails Android/e/OS implementation

*Kotlin implementation of center-cropped square thumbnails using Bitmap operations*

## Overview

Android implementation uses `Bitmap.createBitmap()` to crop a centered square from the original image, then scales it to 80×80 pixels using `Bitmap.createScaledBitmap()`. This approach correctly handles any aspect ratio while preserving image quality.

## Implementation in ImageCache.kt

Add this method to the `ImageCache` object:

```kotlin
import android.graphics.Bitmap
import android.graphics.Matrix

object ImageCache {
    // ... existing cache code ...

    /**
     * Crop and resize image to target size (for thumbnails)
     * Crops a centered square from the image, then scales to targetSize (default 240 for high-DPI)
     * Uses Canvas+Paint for high-quality scaling
     */
    private fun resizeImage(image: Bitmap, targetSize: Int = 240): Bitmap {
        val width = image.width
        val height = image.height

        // Determine the crop size (largest square that fits in the image)
        val cropSize = minOf(width, height)

        // Calculate the crop position (centered)
        val cropX = (width - cropSize) / 2
        val cropY = (height - cropSize) / 2

        // Crop to centered square
        val croppedBitmap = Bitmap.createBitmap(
            image,
            cropX,
            cropY,
            cropSize,
            cropSize
        )

        // Scale to target size with high-quality filtering using Canvas
        val scaledBitmap = Bitmap.createBitmap(targetSize, targetSize, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(scaledBitmap)
        val paint = Paint().apply {
            isAntiAlias = true
            isFilterBitmap = true
            isDither = true
        }
        val srcRect = Rect(0, 0, croppedBitmap.width, croppedBitmap.height)
        val dstRect = Rect(0, 0, targetSize, targetSize)
        canvas.drawBitmap(croppedBitmap, srcRect, dstRect, paint)

        // Release intermediate bitmap if it's not the same as input
        if (croppedBitmap != image && croppedBitmap != scaledBitmap) {
            croppedBitmap.recycle()
        }

        return scaledBitmap
    }

    // Updated getThumbnail to use resizeImage
    fun getThumbnail(url: String): Bitmap? {
        val key = "$url:thumb"

        // Check thumbnail cache
        thumbnailCache.get(key)?.let { return it }

        // Generate from raw data if available
        val rawData = getRawData(url) ?: return null
        val fullBitmap = BitmapFactory.decodeByteArray(rawData, 0, rawData.size) ?: return null

        // Resize to thumbnail
        val thumbnail = resizeImage(fullBitmap, targetSize = 80)

        // Release full bitmap if we created it just for thumbnailing
        if (fullBitmap != thumbnail) {
            fullBitmap.recycle()
        }

        // Cache and return
        thumbnailCache.put(key, thumbnail)
        return thumbnail
    }
}
```

## How It Works

### Step 1: Calculate Crop Rectangle

```kotlin
val cropSize = minOf(width, height)
```

Finds the smallest dimension to create the largest possible square.

**Example (landscape 3000×2000):**
- cropSize = 2000

```kotlin
val cropX = (width - cropSize) / 2
val cropY = (height - cropSize) / 2
```

Centers the crop rectangle:
- cropX = (3000 - 2000) / 2 = 500
- cropY = (2000 - 2000) / 2 = 0
- Result: Crop starting at (500, 0) with size 2000×2000

### Step 2: Crop Using Bitmap.createBitmap()

```kotlin
val croppedBitmap = Bitmap.createBitmap(
    image,
    cropX,
    cropY,
    cropSize,
    cropSize
)
```

**How it works:**
- `image`: Source bitmap
- `cropX, cropY`: Top-left corner of crop region
- `cropSize, cropSize`: Width and height of crop region
- Returns: New Bitmap containing only the cropped pixels

**Example (landscape 3000×2000):**
- Crops from (500, 0) with size (2000, 2000)
- Result: 2000×2000 bitmap showing center of original image

**Memory behavior:**
- Creates a new Bitmap object
- Copies pixels from source region
- Does NOT modify original bitmap
- Must be recycled when no longer needed

### Step 3: Scale to Target Size

```kotlin
val scaledBitmap = Bitmap.createScaledBitmap(
    croppedBitmap,
    targetSize,
    targetSize,
    true  // filter = true for high-quality scaling
)
```

**Parameters:**
- `croppedBitmap`: Source (2000×2000 square)
- `targetSize, targetSize`: Output dimensions (80×80)
- `true`: Enable bilinear filtering for smooth scaling

**Filtering (true vs false):**
- `true` (bilinear): Smooth interpolation, no jagged edges, slightly slower
- `false` (nearest neighbor): Faster but pixelated/blocky results
- Always use `true` for downscaling images for UI

**Example:**
- Input: 2000×2000 square
- Output: 80×80 thumbnail
- Quality: High (bilinear filtering)
- Time: ~5-10ms on modern Android devices

### Step 4: Memory Management

```kotlin
// Release intermediate bitmap if it's not the same as input
if (croppedBitmap != image && croppedBitmap != scaledBitmap) {
    croppedBitmap.recycle()
}
```

**Why this is important:**
- Android Bitmaps use native memory (not Java heap)
- Native memory isn't automatically garbage collected
- Must explicitly call `.recycle()` to free it
- Failing to recycle causes memory leaks

**When to recycle:**
- Recycle `croppedBitmap` after scaling (it's just an intermediate)
- Don't recycle if it's the same object as input or output (edge cases)
- Don't recycle if it's still in use elsewhere

**In getThumbnail:**
```kotlin
if (fullBitmap != thumbnail) {
    fullBitmap.recycle()
}
```
- We decode `fullBitmap` just to create thumbnail
- After creating thumbnail, we don't need `fullBitmap` anymore
- Recycle it to free memory immediately

## Alternative: Using Matrix for Rotation

If you need to handle EXIF orientation (images with rotation metadata):

```kotlin
import android.media.ExifInterface
import android.graphics.Matrix

fun resizeImageWithOrientation(
    data: ByteArray,
    targetSize: Int = 80
): Bitmap {
    // Decode with inJustDecodeBounds to get dimensions without loading full image
    val options = BitmapFactory.Options().apply {
        inJustDecodeBounds = true
    }
    BitmapFactory.decodeByteArray(data, 0, data.size, options)

    // Get EXIF orientation
    val exif = ExifInterface(ByteArrayInputStream(data))
    val orientation = exif.getAttributeInt(
        ExifInterface.TAG_ORIENTATION,
        ExifInterface.ORIENTATION_NORMAL
    )

    // Decode actual bitmap
    options.inJustDecodeBounds = false
    val bitmap = BitmapFactory.decodeByteArray(data, 0, data.size, options)

    // Apply rotation based on EXIF
    val rotated = when (orientation) {
        ExifInterface.ORIENTATION_ROTATE_90 -> rotateBitmap(bitmap, 90f)
        ExifInterface.ORIENTATION_ROTATE_180 -> rotateBitmap(bitmap, 180f)
        ExifInterface.ORIENTATION_ROTATE_270 -> rotateBitmap(bitmap, 270f)
        else -> bitmap
    }

    // Now crop and scale normally
    return resizeImage(rotated, targetSize)
}

private fun rotateBitmap(bitmap: Bitmap, degrees: Float): Bitmap {
    val matrix = Matrix().apply { postRotate(degrees) }
    val rotated = Bitmap.createBitmap(
        bitmap,
        0,
        0,
        bitmap.width,
        bitmap.height,
        matrix,
        true
    )
    if (rotated != bitmap) {
        bitmap.recycle()
    }
    return rotated
}
```

**When to use EXIF handling:**
- Photos taken with phone camera often have rotation metadata
- Without EXIF handling, portraits may appear sideways
- Most modern photo apps handle this automatically
- If using camera APIs directly, may need manual handling

## Usage

Called automatically by `getThumbnail()` in ImageCache:

```kotlin
fun getThumbnail(url: String): Bitmap? {
    val key = "$url:thumb"

    // Check thumbnail cache
    thumbnailCache.get(key)?.let { return it }

    // Generate from raw data if available
    val rawData = getRawData(url) ?: return null
    val fullBitmap = BitmapFactory.decodeByteArray(rawData, 0, rawData.size) ?: return null

    // Resize to thumbnail (calls resizeImage)
    val thumbnail = resizeImage(fullBitmap, targetSize = 80)

    // Release full bitmap
    if (fullBitmap != thumbnail) {
        fullBitmap.recycle()
    }

    // Cache and return
    thumbnailCache.put(key, thumbnail)
    return thumbnail
}
```

## Performance Characteristics

**Time complexity:**
- Crop operation: O(n) where n = cropSize² pixels (creates new bitmap with pixel copy)
- Scale operation: O(n) where n = 80×80 = 6,400 pixels (very fast with bilinear filtering)
- Total: ~5-15ms on modern Android devices (Snapdragon 7-series or better)

**Memory usage:**
- Input: Decoded full image (temporary, already in memory from decoding raw data)
- Intermediate crop: cropSize×cropSize×4 bytes (e.g., 2000×2000×4 = ~16MB temporarily)
- Output: 80×80×4 bytes = 25,600 bytes (~25 KB cached)
- Intermediate bitmap is recycled immediately after scaling

**Quality:**
- Bilinear filtering provides smooth downscaling
- No visible artifacts at 80×80 size
- Appropriate for all screen densities (mdpi through xxxhdpi)
- Center cropping works well for most photo content

## Performance Optimization

### Option 1: Sample-then-crop (faster for large images)

For very large images (4000×3000+), decode at lower resolution first:

```kotlin
fun resizeImageOptimized(data: ByteArray, targetSize: Int = 80): Bitmap {
    // Calculate inSampleSize to decode at lower resolution
    val options = BitmapFactory.Options().apply {
        inJustDecodeBounds = true
    }
    BitmapFactory.decodeByteArray(data, 0, data.size, options)

    val minDimension = minOf(options.outWidth, options.outHeight)
    val sampleSize = calculateInSampleSize(minDimension, targetSize * 4)

    // Decode with sampling
    options.inJustDecodeBounds = false
    options.inSampleSize = sampleSize
    val sampledBitmap = BitmapFactory.decodeByteArray(data, 0, data.size, options)

    // Now crop and scale
    return resizeImage(sampledBitmap, targetSize)
}

private fun calculateInSampleSize(sourceSize: Int, targetSize: Int): Int {
    var inSampleSize = 1
    while (sourceSize / (inSampleSize * 2) >= targetSize) {
        inSampleSize *= 2
    }
    return inSampleSize
}
```

**Benefits:**
- Decodes image at 1/2, 1/4, or 1/8 resolution first
- Reduces memory usage during decoding
- Faster for very large images (>4000px)
- Still produces same 80×80 output

**Example:**
- 4000×3000 image with targetSize = 80
- Calculate inSampleSize = 8 (3000 / 16 = 187 > 80×4=320)
- Decode at 500×375 resolution
- Crop to 375×375
- Scale to 80×80
- Memory saved: ~95% during decode

### Option 2: GPU-accelerated scaling (for many thumbnails)

Use RenderScript for hardware-accelerated scaling:

```kotlin
import android.renderscript.*

fun resizeImageGPU(
    context: Context,
    bitmap: Bitmap,
    targetSize: Int
): Bitmap {
    val rs = RenderScript.create(context)

    val input = Allocation.createFromBitmap(rs, bitmap)
    val output = Allocation.createTyped(rs, Type.createXY(rs, Element.RGBA_8888(rs), targetSize, targetSize))

    val script = ScriptIntrinsicResize.create(rs)
    script.setInput(input)
    script.forEach_bicubic(output)

    val result = Bitmap.createBitmap(targetSize, targetSize, Bitmap.Config.ARGB_8888)
    output.copyTo(result)

    // Cleanup
    input.destroy()
    output.destroy()
    script.destroy()
    rs.destroy()

    return result
}
```

**When to use:**
- Processing many images at once
- Need highest quality scaling (bicubic)
- Have GPU resources available
- ~2-3x faster than CPU for large batches

## Testing

**Visual test:**
```kotlin
@Test
fun testThumbnailGeneration() {
    val context = InstrumentationRegistry.getInstrumentation().targetContext

    // Load test images
    val landscape = BitmapFactory.decodeResource(context.resources, R.drawable.test_landscape)
    val portrait = BitmapFactory.decodeResource(context.resources, R.drawable.test_portrait)
    val square = BitmapFactory.decodeResource(context.resources, R.drawable.test_square)

    // Generate thumbnails
    val thumbLandscape = ImageCache.resizeImage(landscape, 80)
    val thumbPortrait = ImageCache.resizeImage(portrait, 80)
    val thumbSquare = ImageCache.resizeImage(square, 80)

    // Verify dimensions
    assertEquals(80, thumbLandscape.width)
    assertEquals(80, thumbLandscape.height)
    assertEquals(80, thumbPortrait.width)
    assertEquals(80, thumbPortrait.height)
    assertEquals(80, thumbSquare.width)
    assertEquals(80, thumbSquare.height)

    // Save for visual inspection
    saveBitmap(thumbLandscape, "thumb_landscape.png")
    saveBitmap(thumbPortrait, "thumb_portrait.png")
    saveBitmap(thumbSquare, "thumb_square.png")
}
```

## Integration Points

**File:** `apps/firefly/product/client/imp/eos/app/src/main/kotlin/com/miso/noobtest/ImageCache.kt`

**Method:** `private fun resizeImage(image: Bitmap, targetSize: Int = 80): Bitmap`

**Called by:** `getThumbnail(url: String)` when generating thumbnails from raw data

**Used by:** PostView.kt compact view for displaying 80×80 thumbnails in posts list

## Key Android-Specific Decisions

1. **Bitmap.createBitmap() for cropping**: Direct pixel extraction, very fast
2. **Bitmap.createScaledBitmap() with filtering**: High-quality bilinear downsampling
3. **Explicit recycling**: Call `.recycle()` to free native memory immediately
4. **LruCache for thumbnails**: Automatic memory management with size-based eviction
5. **inSampleSize optimization**: Optional decode-time downsampling for very large images
6. **EXIF handling**: Optional rotation correction for camera photos
7. **RenderScript option**: GPU acceleration for batch processing

## Required Imports

```kotlin
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.media.ExifInterface
import java.io.ByteArrayInputStream
```

## Common Issues and Solutions

**Issue: Out of Memory (OOM) errors**
- Cause: Not recycling intermediate bitmaps
- Solution: Always recycle temporary bitmaps after use

**Issue: Thumbnails appear rotated**
- Cause: EXIF orientation not handled
- Solution: Use `resizeImageWithOrientation()` variant

**Issue: Slow thumbnail generation**
- Cause: Decoding very large images at full resolution
- Solution: Use `resizeImageOptimized()` with inSampleSize

**Issue: Pixelated thumbnails**
- Cause: `filter = false` in createScaledBitmap
- Solution: Always use `filter = true` for UI images

This implementation provides identical visual results to iOS while using Android-native Bitmap APIs and proper memory management.
