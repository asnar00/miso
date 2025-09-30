import Foundation
import AppKit

let size: CGFloat = 1024
let image = NSImage(size: NSSize(width: size, height: size))

image.lockFocus()

// Fill background with turquoise
NSColor(red: 64/255, green: 224/255, blue: 208/255, alpha: 1.0).setFill()
NSRect(x: 0, y: 0, width: size, height: size).fill()

// Draw the nøøb logo
let text = "ᕦ(ツ)ᕤ"
let font = NSFont(name: "Helvetica", size: 225) ?? NSFont.systemFont(ofSize: 225)
let attributes: [NSAttributedString.Key: Any] = [
    .font: font,
    .foregroundColor: NSColor.black
]

let attributedString = NSAttributedString(string: text, attributes: attributes)
let textSize = attributedString.size()
let point = NSPoint(x: (size - textSize.width) / 2, y: (size - textSize.height) / 2)
attributedString.draw(at: point)

image.unlockFocus()

// Convert to PNG and save
let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)!
let rep = NSBitmapImageRep(cgImage: cgImage)
let pngData = rep.representation(using: NSBitmapImageRep.FileType.png, properties: [:])!

// Output path should be provided as first command line argument
let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon.png"
try! pngData.write(to: URL(fileURLWithPath: outputPath))

print("Icon generated successfully at: \(outputPath)")