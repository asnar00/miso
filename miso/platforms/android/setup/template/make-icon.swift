import Foundation
import AppKit

let size: CGFloat = 432
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()

// Turquoise background
NSColor(red: 64/255, green: 224/255, blue: 208/255, alpha: 1.0).setFill()
NSRect(x: 0, y: 0, width: size, height: size).fill()

// Black text
let text = "ᕦ(ツ)ᕤ"
let font = NSFont(name: "Helvetica", size: 180) ?? NSFont.systemFont(ofSize: 180)
let attributes: [NSAttributedString.Key: Any] = [
    .font: font,
    .foregroundColor: NSColor.black
]

let attributedString = NSAttributedString(string: text, attributes: attributes)
let textSize = attributedString.size()
let point = NSPoint(x: (size - textSize.width) / 2, y: (size - textSize.height) / 2)
attributedString.draw(at: point)

image.unlockFocus()

// Save as PNG
if let tiffData = image.tiffRepresentation,
   let bitmapImage = NSBitmapImageRep(data: tiffData),
   let pngData = bitmapImage.representation(using: .png, properties: [:]) {
    let url = URL(fileURLWithPath: "app/src/main/res/mipmap-xxxhdpi/ic_launcher.png")
    try? pngData.write(to: url)
    print("✅ Icon generated: ic_launcher.png (\(Int(size))x\(Int(size)))")
}
