#!/bin/bash
# Build the Android screen capture app

cd "$(dirname "$0")"

echo "Building Android Screen Capture..."
swiftc -o android_screencap main.swift \
    -framework Cocoa \
    -O

if [ $? -eq 0 ]; then
    echo "Build successful: android_screencap"
else
    echo "Build failed"
    exit 1
fi
