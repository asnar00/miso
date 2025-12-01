# setup
*creating and configuring new Android/e/OS projects*

This section covers everything needed to set up Android development, create apps, and configure them for the e/OS platform.

## Topics

### [android-sdk-installation](setup/android-sdk-installation.md)
Installing the Android SDK, Java Development Kit, Gradle, and command-line tools on macOS. Critical for all Android/e/OS development.

### [create-app](setup/create-app.md)
Creating a new Android app project using Gradle, Kotlin, and Jetpack Compose.

### [icon-generation](setup/icon-generation.md)
Generating app icons in all required sizes for Android (mipmap densities).

### [network-security-config](setup/network-security-config.md)
Configuring network security to allow HTTP connections for development (similar to iOS ATS).

### [template](setup/template/)
Ready-to-use Android app template project with Kotlin, Jetpack Compose, and Material 3.

## Quick Start

For a new Android/e/OS app in the miso system:

1. Install Android SDK with `android-sdk-installation`
2. Copy the template or create a new project with `create-app`
3. Generate app icons with `icon-generation`
4. Configure network security with `network-security-config` if needed

## Key Environment Variables

**Required for all operations:**
```bash
export JAVA_HOME="/opt/homebrew/opt/openjdk"
export ANDROID_HOME="/opt/homebrew/share/android-commandlinetools"
export PATH="$JAVA_HOME/bin:$ANDROID_HOME/platform-tools:$PATH"
```

Add these to your shell profile (`~/.zshrc` or `~/.bash_profile`) permanently.

## e/OS Compatibility

e/OS is based on Android Open Source Project (AOSP) and maintains full compatibility with standard Android development tools. No special configuration needed - everything works exactly like regular Android development.

See each sub-topic for detailed instructions.
