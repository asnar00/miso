# build-and-deploy
*compiling Android/e/OS apps and deploying to devices*

This section covers building Android applications with Gradle and deploying them to USB-connected devices via ADB (Android Debug Bridge).

## Topics

### [build](build-and-deploy/build.md)
Compiling Android apps using Gradle, managing dependencies, and understanding the build system (Gradle Kotlin DSL).

### [usb-deploy](build-and-deploy/usb-deploy.md)
Deploying apps directly to USB-connected Android/e/OS devices using ADB.

### [complete-workflow](build-and-deploy/complete-workflow.md)
End-to-end guide: build, install, and launch in one workflow.

## Quick Workflow

The fastest development cycle for USB-connected devices:

```bash
# 1. Build and deploy
export JAVA_HOME="/opt/homebrew/opt/openjdk"
./gradlew assembleDebug
adb install -r app/build/outputs/apk/debug/app-debug.apk
adb shell am start -n com.miso.noobtest/.MainActivity

# 2. Or use the convenience script
./install-device.sh        # ~2-5 seconds after first build
```

## Key Concepts

**Gradle**: The build system for Android. Uses Kotlin DSL for build configuration (`build.gradle.kts`).

**APK Location**: Built apps are in `app/build/outputs/apk/debug/app-debug.apk` after `assembleDebug`.

**ADB**: Android Debug Bridge - command-line tool for communicating with Android devices.

**JAVA_HOME**: **Critical** - must be set before any Gradle commands or you'll get "Unable to locate a Java Runtime" error.

**Package Name**: Used to identify and launch your app (e.g., `com.miso.noobtest`).

## Typical Timeline

- **First build**: ~15-20 seconds (downloads dependencies)
- **Incremental builds**: ~1-2 seconds
- **APK installation**: ~1-2 seconds
- **App launch**: <1 second

Total USB deployment: **~2-5 seconds** from code change to running on device (after initial setup).

## Essential Commands

```bash
# Check connected devices
adb devices

# Build debug APK
./gradlew assembleDebug

# Install (replace existing)
adb install -r app/build/outputs/apk/debug/app-debug.apk

# Launch app
adb shell am start -n PACKAGE_NAME/.MainActivity

# Restart app
adb shell am force-stop PACKAGE_NAME && adb shell am start -n PACKAGE_NAME/.MainActivity

# Stop app
adb shell am force-stop PACKAGE_NAME
```

## Environment Setup

**Always set before Gradle commands:**
```bash
export JAVA_HOME="/opt/homebrew/opt/openjdk"
```

Add to shell profile permanently:
```bash
echo 'export JAVA_HOME="/opt/homebrew/opt/openjdk"' >> ~/.zshrc
source ~/.zshrc
```

## Detailed Guides

See the subtopics above for complete documentation on each aspect of building and deployment. For troubleshooting build and deployment issues, see `troubleshooting.md`.
