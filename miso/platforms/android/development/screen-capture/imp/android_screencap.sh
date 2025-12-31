#!/bin/bash
# Launch the Android screen capture app
# Builds if necessary, then runs

cd "$(dirname "$0")"

# Build if executable doesn't exist or main.swift is newer
if [ ! -f android_screencap ] || [ main.swift -nt android_screencap ]; then
    echo "Building..."
    ./build.sh
    if [ $? -ne 0 ]; then
        echo "Build failed"
        exit 1
    fi
fi

# Check prerequisites
if ! command -v adb &> /dev/null; then
    echo "Error: adb not found. Install with: brew install android-platform-tools"
    exit 1
fi

if ! command -v scrcpy &> /dev/null; then
    echo "Error: scrcpy not found. Install with: brew install scrcpy"
    exit 1
fi

# Run the app
./android_screencap
