#!/bin/bash

echo "🔧 Setting up Android development environment..."

# Install packages
brew install openjdk@17
brew install gradle
brew install --cask android-commandlinetools

# Set environment variables
export JAVA_HOME="/opt/homebrew/opt/openjdk@17"
export ANDROID_HOME="/opt/homebrew/share/android-commandlinetools"
export PATH="/opt/homebrew/opt/openjdk@17/bin:$ANDROID_HOME/platform-tools:$PATH"

# Accept SDK license
mkdir -p $ANDROID_HOME/licenses
echo "24333f8a63b6825ea9c5514f83c2829b004d1fee" > $ANDROID_HOME/licenses/android-sdk-license

# Install SDK components
sdkmanager --sdk_root=$ANDROID_HOME "platform-tools" "platforms;android-35" "build-tools;35.0.0"

echo "✅ Android development environment ready!"
echo ""
echo "Add these lines to ~/.zshrc:"
echo 'export JAVA_HOME="/opt/homebrew/opt/openjdk@17"'
echo 'export ANDROID_HOME="/opt/homebrew/share/android-commandlinetools"'
echo 'export PATH="/opt/homebrew/opt/openjdk@17/bin:$ANDROID_HOME/platform-tools:$PATH"'
