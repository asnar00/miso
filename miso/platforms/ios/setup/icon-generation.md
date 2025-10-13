# icon-generation
*creating iOS app icons with proper Unicode character rendering*

iOS app icons must be 1024x1024 PNG files. Creating them programmatically ensures proper rendering of special Unicode characters.

## The Challenge

Standard image libraries (like Python's PIL) don't properly render complex Unicode characters, especially:
- Canadian Aboriginal Syllabics (ᕦ, ᕤ)
- Emoji combinations
- Right-to-left text

These render as boxes (□) instead of the actual glyphs.

## The Solution: Use macOS Native APIs

macOS's AppKit/CoreGraphics handles all Unicode properly through system font rendering.

## Implementation

The icon generation script uses Swift with AppKit:

```swift
import Foundation
import AppKit

let size: CGFloat = 1024
let image = NSImage(size: NSSize(width: size, height: size))

image.lockFocus()

// Fill background
NSColor(red: 64/255, green: 224/255, blue: 208/255, alpha: 1.0).setFill()
NSRect(x: 0, y: 0, width: size, height: size).fill()

// Draw text with proper Unicode rendering
let text = "ᕦ(ツ)ᕤ"
let font = NSFont(name: "Helvetica", size: 225) ?? NSFont.systemFont(ofSize: 225)
let attributes: [NSAttributedString.Key: Any] = [
    .font: font,
    .foregroundColor: NSColor.black
]

let attributedString = NSAttributedString(string: text, attributes: attributes)
let textSize = attributedString.size()
let point = NSPoint(x: (size - textSize.width) / 2,
                    y: (size - textSize.height) / 2)
attributedString.draw(at: point)

image.unlockFocus()

// Save as PNG
let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)!
let rep = NSBitmapImageRep(cgImage: cgImage)
let pngData = rep.representation(using: .png, properties: [:])!
try! pngData.write(to: URL(fileURLWithPath: outputPath))
```

## Key Points

1. **NSImage creates 2x resolution by default** on Retina displays
   - Use `sips -z 1024 1024 icon.png` to resize if needed

2. **Font selection matters**
   - Use system fonts (Helvetica, SF Pro) for best Unicode support
   - Avoid custom fonts unless you've tested the characters

3. **Sizing**
   - Icon: 1024x1024 pixels
   - Text size depends on content (typically 180-225pt for short text)

4. **Colors**
   - Use `NSColor` for proper color space handling
   - Example turquoise: `NSColor(red: 64/255, green: 224/255, blue: 208/255, alpha: 1.0)`

## Usage

```bash
swift make-icon.swift output-path.png
```

See `icon-generation/imp/make-icon.swift` for the complete, working implementation.