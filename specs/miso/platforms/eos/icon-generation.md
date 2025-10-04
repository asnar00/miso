# icon-generation
*creating Android adaptive icons*

Android uses **adaptive icons** (API 26+) with separate foreground and background layers that adapt to different device shapes and visual effects.

## Icon Specifications

**Canvas size:** 108×108 dp
**Safe zone:** 66×66 dp (inner area never clipped)
**Outer margin:** 18 dp on each side (reserved for masking/effects)

## Required Densities

Generate PNG files at these pixel dimensions:

- `mipmap-mdpi`: 108×108 px (1x)
- `mipmap-hdpi`: 162×162 px (1.5x)
- `mipmap-xhdpi`: 216×216 px (2x)
- `mipmap-xxhdpi`: 324×324 px (3x)
- `mipmap-xxxhdpi`: 432×432 px (4x)

## Simple Approach: Single PNG Icon

For apps that don't need adaptive effects, use a single PNG in `mipmap-xxxhdpi`:

```
app/src/main/res/
└── mipmap-xxxhdpi/
    └── ic_launcher.png  (432×432 px)
```

Android automatically downscales for lower densities.

## Icon Generation Script

Similar to iOS, use a script to generate the icon with proper Unicode character rendering:

```kotlin
import java.awt.Color
import java.awt.Font
import java.awt.RenderingHints
import java.awt.image.BufferedImage
import java.io.File
import javax.imageio.ImageIO

fun main() {
    val size = 432  // xxxhdpi
    val image = BufferedImage(size, size, BufferedImage.TYPE_INT_ARGB)
    val g = image.createGraphics()

    // Enable anti-aliasing
    g.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON)
    g.setRenderingHint(RenderingHints.KEY_TEXT_ANTIALIASING, RenderingHints.VALUE_TEXT_ANTIALIAS_ON)

    // Turquoise background
    g.color = Color(64, 224, 208)
    g.fillRect(0, 0, size, size)

    // Black text
    g.color = Color.BLACK
    val font = Font("Helvetica", Font.PLAIN, 180)
    g.font = font

    val text = "ᕦ(ツ)ᕤ"
    val metrics = g.fontMetrics
    val x = (size - metrics.stringWidth(text)) / 2
    val y = ((size - metrics.height) / 2) + metrics.ascent

    g.drawString(text, x, y)
    g.dispose()

    // Save
    ImageIO.write(image, "PNG", File("ic_launcher.png"))
    println("✅ Icon generated: ic_launcher.png (${size}x${size})")
}
```

**Usage:**
```bash
kotlinc -script make-icon.kts
```

## Alternative: ImageMagick

If ImageMagick is installed with Unicode font support:

```bash
convert -size 432x432 xc:'rgb(64,224,208)' \
  -font Helvetica -pointsize 180 \
  -fill black -gravity center \
  -annotate +0+0 'ᕦ(ツ)ᕤ' \
  ic_launcher.png
```

## Adaptive Icon XML (Advanced)

For full adaptive icon support with separate layers:

`res/mipmap-anydpi-v26/ic_launcher.xml`:
```xml
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
```

This requires separate foreground/background assets but provides better visual effects.

## Simple Approach (Recommended for Testing)

For the NoobTest app, a single 432×432 PNG in `mipmap-xxxhdpi` is sufficient:

1. Generate icon with script or ImageMagick
2. Place in `app/src/main/res/mipmap-xxxhdpi/ic_launcher.png`
3. Reference in AndroidManifest.xml: `android:icon="@mipmap/ic_launcher"`

## Troubleshooting

**Characters render as squares**
- Use Java/Kotlin AWT with proper font support (like the script above)
- Avoid Python PIL which may lack Unicode character support

**Icon appears blurry**
- Ensure you're generating at xxxhdpi (432×432 px)
- Android will automatically downscale for lower densities

## Implementation

Working icon generation script in `icon-generation/imp/make-icon.kts`
