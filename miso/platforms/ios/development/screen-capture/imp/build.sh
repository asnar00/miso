#!/bin/bash

# Build iPhone Screen Capture app bundle

echo "Building iPhone Screen Capture..."

# Compile the Swift source
swiftc main.swift -o iphone_screencap
if [ $? -ne 0 ]; then
    echo "❌ Compilation failed"
    exit 1
fi

echo "✓ Compiled successfully"

# Copy the binary to the app bundle
cp iphone_screencap iPhoneScreenCap.app/Contents/MacOS/iPhoneScreenCap

echo "✓ Updated app bundle"
echo "✅ Build complete!"
echo ""
echo "You can now:"
echo "  - Run from terminal: ./iphone_screencap"
echo "  - Launch from Dock: open iPhoneScreenCap.app"
echo "  - Add to Dock: drag iPhoneScreenCap.app to Dock"
