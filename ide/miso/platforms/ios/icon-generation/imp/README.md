# Icon Generation

This script generates the app icon for the test application.

## Usage

```bash
swift make-icon.swift [output-path]
```

If no output path is specified, the icon will be saved as `icon.png` in the current directory.

## Example

```bash
swift make-icon.swift ../test/imp/ios/NoobTest/Assets.xcassets/AppIcon.appiconset/icon.png
```

## Technical Notes

- Uses AppKit's NSImage for proper Unicode character rendering
- Helvetica font at 225pt provides good visual balance at icon sizes
- The turquoise color (RGB: 64, 224, 208) matches the app background
- The output is exactly 1024x1024 pixels as required by iOS asset catalogs