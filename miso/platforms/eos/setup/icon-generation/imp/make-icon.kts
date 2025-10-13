import java.awt.Color
import java.awt.Font
import java.awt.RenderingHints
import java.awt.image.BufferedImage
import java.io.File
import javax.imageio.ImageIO

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
