import java.awt.Font;
import java.awt.GraphicsEnvironment;

public class DebugFont {
    public static void main(String[] args) {
        // List available fonts
        System.out.println("Available fonts:");
        String[] fonts = GraphicsEnvironment.getLocalGraphicsEnvironment().getAvailableFontFamilyNames();
        for (String font : fonts) {
            if (font.toLowerCase().contains("helvetica") ||
                font.toLowerCase().contains("arial") ||
                font.toLowerCase().contains("sans")) {
                System.out.println("  - " + font);
            }
        }

        // Test if font can render our characters
        Font font = new Font(Font.SANS_SERIF, Font.PLAIN, 60);
        System.out.println("\nTesting characters:");
        System.out.println("ᕦ (U+1566): " + font.canDisplay('\u1566'));
        System.out.println("( (U+0028): " + font.canDisplay('\u0028'));
        System.out.println("ツ (U+30C4): " + font.canDisplay('\u30C4'));
        System.out.println(") (U+0029): " + font.canDisplay('\u0029'));
        System.out.println("ᕤ (U+1564): " + font.canDisplay('\u1564'));
    }
}
