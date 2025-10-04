import java.awt.Color;
import java.awt.Font;
import java.awt.Graphics2D;
import java.awt.RenderingHints;
import java.awt.image.BufferedImage;
import java.io.File;
import javax.imageio.ImageIO;

public class MakeForeground {
    public static void main(String[] args) throws Exception {
        int size = 432;  // xxxhdpi
        BufferedImage image = new BufferedImage(size, size, BufferedImage.TYPE_INT_ARGB);
        Graphics2D g = image.createGraphics();

        // Enable anti-aliasing
        g.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON);
        g.setRenderingHint(RenderingHints.KEY_TEXT_ANTIALIASING, RenderingHints.VALUE_TEXT_ANTIALIAS_ON);

        // Transparent background (no fill)

        // Black text
        g.setColor(Color.BLACK);
        // Use Arial Unicode MS for better Unicode support
        Font font = new Font("Arial Unicode MS", Font.PLAIN, 60);
        g.setFont(font);

        // Draw the full string
        String text = "ᕦ(ツ)ᕤ";
        var metrics = g.getFontMetrics();
        int x = (size - metrics.stringWidth(text)) / 2;
        int y = ((size - metrics.getHeight()) / 2) + metrics.getAscent();

        g.drawString(text, x, y);
        g.dispose();

        // Save
        ImageIO.write(image, "PNG", new File("app/src/main/res/mipmap-xxxhdpi/ic_launcher_foreground.png"));
        System.out.println("✅ Foreground icon generated: ic_launcher_foreground.png (" + size + "x" + size + ")");
    }
}
