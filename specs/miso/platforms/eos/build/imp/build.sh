#!/bin/bash

echo "🔨 Building NoobTest debug APK..."
./gradlew assembleDebug

if [ $? -eq 0 ]; then
    echo "✅ Build complete!"
    echo "📦 APK: app/build/outputs/apk/debug/app-debug.apk"
else
    echo "❌ Build failed"
    exit 1
fi
