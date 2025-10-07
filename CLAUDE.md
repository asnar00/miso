# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

`miso` is an experimental system for natural language programming. It allows non-programmers to create and maintain software by specifying programs as trees of short natural-language markdown documents called "features" (or "snippets").

**Key philosophy**: This is a line of experiments. Each new experiment may start from scratch or build on previous work. Previous experiments are stored in branches, and the main branch is cleared for new experiments.

## Core Concepts

### Features
- Programs are specified as trees of markdown files in the `miso/` directory
- Each feature is a short (<300 words) natural-language specification
- Format: `#` title, followed by an *emphasized* one-line summary, then plain-language description
- Avoid technical jargon - should be understandable by domain experts without programming knowledge
- Features are nested: `A.md` → `A/B.md` → `A/B/C.md`
- Keep features manageable (4-6 children max)

### Products
- Executable applications assembled from features
- Stored in `apps/` directory
- Follow the same markdown tree convention as features
- Their `imp/` folders contain actual executables

### Implementation Details
- For feature `A/B/C`, implementations go in `A/B/C/imp/`
- `imp/pseudocode.md`: Natural-language function definitions and patching instructions
- Platform-specific versions: `imp/ios.md`, `imp/android.md`, etc.
- Contains actual code, tests, logs, and debugging artifacts

## Platform Support

Three platforms currently supported: **iOS**, **Android/e/OS**, and **Python**

### iOS Platform (`miso/platforms/ios/`)

Template app: `miso/platforms/ios/template/`

**Key topics**:
- `create-app.md`: Creating Xcode projects from command line
- `build.md`: Building with xcodebuild
- `simulator.md`: Running iOS simulators
- `usb-deploy.md`: Fast USB deployment (~8 seconds)
- `build-and-deploy.md`: Complete build and USB deployment workflow
- `testflight.md`: TestFlight cloud distribution
- `code-signing.md`: Certificates and provisioning profiles
- `screen-capture.md`: Screen recording from device

**Critical build issue**: Homebrew linker conflict
- If builds fail with `ld: unknown option: -platform_version`, use: `xcodebuild ... LD="clang" build`
- This forces clang as the linker instead of Homebrew's `/opt/homebrew/bin/ld`

**Build for simulator**:
```bash
xcodebuild -project MyApp.xcodeproj \
    -scheme MyApp \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
    LD="clang" \
    build
```

**Build and deploy to USB device**:
```bash
# Find device ID
DEVICE_ID=$(xcodebuild -project MyApp.xcodeproj -scheme MyApp -showdestinations 2>&1 | \
    grep "platform:iOS," | grep -v "Simulator" | grep -v "placeholder" | \
    sed -n 's/.*id:\([^,]*\).*/\1/p' | head -1)

# Build for device
xcodebuild -project MyApp.xcodeproj \
    -scheme MyApp \
    -destination "id=$DEVICE_ID" \
    -allowProvisioningUpdates \
    LD="clang" \
    build

# Find built app
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData/MyApp-*/Build/Products/Debug-iphoneos/MyApp.app -type d | head -1)

# Install
xcrun devicectl device install app --device "$DEVICE_ID" "$APP_PATH"
```

### Android/e/OS Platform (`miso/platforms/eos/`)

Template app: `miso/platforms/eos/template/`

**Technologies**: Kotlin, Jetpack Compose, Material 3, Gradle Kotlin DSL

**Key topics**:
- `create-app.md`: Android project structure with Gradle
- `build.md`: Building with Gradle
- `usb-deploy.md`: USB deployment to devices
- `build-and-deploy.md`: Complete build and USB deployment workflow
- `setup.md`: Android SDK setup

**Critical requirement**: Set JAVA_HOME before any Gradle commands:
```bash
export JAVA_HOME="/opt/homebrew/opt/openjdk"
```

**Build and deploy to USB device**:
```bash
# Check device connected
adb devices

# Build APK
export JAVA_HOME="/opt/homebrew/opt/openjdk"
./gradlew assembleDebug

# Install (output at: app/build/outputs/apk/debug/app-debug.apk)
adb install -r app/build/outputs/apk/debug/app-debug.apk

# Launch (replace package name)
adb shell am start -n com.package.name/.MainActivity
```

### Python Platform (`miso/platforms/py/`)

Template app: `miso/platforms/py/template/`

**Technologies**: Flask, pip, virtualenv

**Key topics**:
- `create-app.md`: Creating Flask applications
- `flask-deployment.md`: Server deployment
- `build-and-deploy.md`: Complete deployment workflow to remote server

**Deploy to remote server** (example for Firefly server at `192.168.1.76`):
```bash
# Stop running server
curl -X POST http://192.168.1.76:8080/api/shutdown

# Copy files
scp *.py *.txt *.sh microserver@192.168.1.76:~/firefly-server/

# Start server
ssh microserver@192.168.1.76 "cd ~/firefly-server && ./start.sh"

# Verify
curl http://192.168.1.76:8080/api/ping
```

## Repository Structure

```
miso/
├── miso/                    # Feature specifications
│   ├── platforms/           # Platform-specific knowledge
│   │   ├── ios/            # iOS development
│   │   ├── eos/            # Android/e/OS development
│   │   └── py/             # Python/Flask development
│   ├── platforms.md        # Platform overview
│   ├── features.md         # Feature system specification
│   └── products.md         # Product system specification
├── apps/                    # Executable products
│   └── firefly/            # Example: semantic search social media app
├── miso.md                 # System overview
└── readme.md               # Project description
```

## Working with this Repository

1. **Understanding the codebase**: Start by reading `miso.md` and the relevant platform docs in `miso/platforms/`
2. **Creating new features**: Add markdown files following the feature format in `miso/features.md`
3. **Implementation**: Store working code in `imp/` subdirectories
4. **Testing platform code**: Each platform has template apps and working implementations in `imp/` directories
5. **Building**: Use platform-specific build commands (see platform docs)

## Current Application

**firefly** (`apps/firefly.md`): A social media platform based on semantic search, storing markdown snippets in a vector database for natural-language queries.
