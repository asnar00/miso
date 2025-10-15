# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

`miso` is an experimental system for natural language programming. It enables non-programmers to create and maintain software by specifying programs as trees of short natural-language markdown documents called "features".

**Key philosophy**: This is a line of experiments. Each new experiment may start from scratch or build on previous work. Previous experiments are stored in branches, and the main branch is cleared for new experiments. When working in this repo, be aware that the current state may represent work-in-progress on the latest experiment.

## Core Architecture

### Feature Specification System

Programs are specified as hierarchical markdown trees in `miso/`:

**Structure**:
- `A.md` → `A/B.md` → `A/B/C.md` (nested features)
- Each feature: `#` title, *emphasized* one-line summary, <300 words of plain language
- Implementation details go in `A/B/C/imp/` subdirectories
- Keep features manageable: 4-6 children max

**Implementation Hierarchy**:
- `imp/pseudocode.md` - Natural-language function definitions and patching instructions
- `imp/{platform}.md` - Platform-specific implementations (ios, eos, py)
- `imp/` also contains actual code files and debugging artifacts

### Products vs Features

**Features** (`miso/`): Reusable capability specifications with implementation details
**Products** (`apps/`): Executable applications assembled from features

Products follow the same markdown tree convention but their `imp/` folders contain actual runnable executables.

## Platform Support

Three platforms supported: **iOS**, **Android/e/OS**, and **Python**

### Critical Platform Issues

**iOS Homebrew Linker Conflict**:
```bash
# Always use LD="clang" to avoid Homebrew linker errors
xcodebuild ... LD="clang" build
```

**Android JAVA_HOME Requirement**:
```bash
# Set before any Gradle command
export JAVA_HOME="/opt/homebrew/opt/openjdk"
```

### iOS Development

**Key Documentation**: `miso/platforms/ios/`
- `project-editing.md` - Adding files to Xcode without GUI (edit project.pbxproj directly)
- `build-and-deploy.md` - Complete USB deployment workflow
- `logging.md` - OSLog/Logger API best practices

**Quick Deploy** (from `apps/firefly/product/client/imp/ios/`):
```bash
./install-device.sh  # Finds device, builds, deploys (~8-10 seconds)
```

**Manual Build and Deploy**:
```bash
# Find device
DEVICE_ID=$(xcodebuild -project NoobTest.xcodeproj -scheme NoobTest -showdestinations 2>&1 | \
    grep "platform:iOS," | grep -v "Simulator" | grep -v "placeholder" | \
    sed -n 's/.*id:\([^,]*\).*/\1/p' | head -1)

# Build
xcodebuild -project NoobTest.xcodeproj \
    -scheme NoobTest \
    -destination "id=$DEVICE_ID" \
    -allowProvisioningUpdates \
    LD="clang" \
    build

# Find and install
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData/NoobTest-*/Build/Products/Debug-iphoneos/NoobTest.app -type d | head -1)
xcrun devicectl device install app --device "$DEVICE_ID" "$APP_PATH"
```

### Android/e/OS Development

**Key Documentation**: `miso/platforms/eos/`
**Technologies**: Kotlin, Jetpack Compose, Material 3, Gradle Kotlin DSL

**Quick Deploy** (from `apps/firefly/product/client/imp/eos/`):
```bash
export JAVA_HOME="/opt/homebrew/opt/openjdk"
./gradlew assembleDebug
adb install -r app/build/outputs/apk/debug/app-debug.apk
adb shell am start -n com.miso.noobtest/.MainActivity
```

### Python/Flask Development

**Key Documentation**: `miso/platforms/py/`

**Remote Server Deployment** (Firefly server at `185.96.221.52:8080`):
```bash
# From apps/firefly/product/server/imp/py/
./remote-shutdown.sh  # Stop remote server
scp *.py *.txt *.sh microserver@185.96.221.52:~/firefly-server/
ssh microserver@185.96.221.52 "cd ~/firefly-server && ./start.sh"
curl http://185.96.221.52:8080/api/ping  # Verify
```

## Current Application: Firefly

Social media platform using semantic search on markdown snippets (`apps/firefly.md`).

### Implemented Features

**infrastructure** (`apps/firefly/features/infrastructure.md`):
- Foundation systems for development and deployment
- **ping**: HTTP health check endpoint
- **logging**: Multi-level logging (local, USB, remote)
- **email**: Send verification codes for passwordless login
- **testing**: Remote feature testing from Mac to device
- **storage**: Local data persistence (login state, cache, media)

**users** (`apps/firefly/features/users.md`):
- User accounts with email-based authentication
- Device association
- **sign-in**: Email-based login with 4-digit one-time codes (10-minute validity)
- **sign-up**: New user onboarding with profile setup and tutorial

**posts** (`apps/firefly/features/posts.md`):
- User-generated content with hierarchical structure
- Vector embeddings for semantic search

**background** (`apps/firefly/features/background.md`):
- UI background color

## Testing Infrastructure

**testing** (`apps/firefly/features/infrastructure/testing.md`):
- Remote feature testing from Mac to device via USB
- Tests run in real app environment, not simulator

**Quick Test** (requires port forwarding):
```bash
# Setup once (keep running)
pymobiledevice3 usbmux forward 8081 8081 &

# Run test
cd apps/firefly/features/infrastructure/testing/imp
./test-feature.sh ping  # Tests any registered feature
```

**Manual Test**:
```bash
curl http://localhost:8081/test/ping
# Returns: "succeeded" or "failed because XXX"
```

**Add New Test**: Register in platform code:
```swift
// iOS
TestRegistry.shared.register(feature: "myfeature") {
    return TestResult(success: true)  // or false with error
}
```
```kotlin
// Android
TestRegistry.register("myfeature") {
    TestResult(success = true)  // or false with error
}
```

## Development Utilities

**iOS App Management** (from `apps/firefly/product/client/imp/ios/`):
```bash
./restart-app.sh  # Restart app on device
./stop-app.sh     # Stop app on device
./get-logs.sh     # Download app.log from device
```

**Android App Management** (from `apps/firefly/product/client/imp/eos/`):
```bash
adb shell am force-stop com.miso.noobtest          # Stop app
adb shell am start -n com.miso.noobtest/.MainActivity  # Start app
```

**Debugging with Device Logs**:
```bash
# iOS: Download logs from device
cd apps/firefly/product/client/imp/ios/
./get-logs.sh  # Downloads app.log to device-logs.txt

# View logs
cat device-logs.txt

# iOS: Stream live logs (requires device ID)
log stream --device <DEVICE_ID> --predicate 'subsystem == "com.miso.noobtest"'
```

## Working with This Repository

1. **Start**: Read `miso.md` and relevant platform docs in `miso/platforms/{platform}/`
2. **Create features**: Follow format in `miso/features.md`
3. **Implement**: Add code to `imp/` subdirectories with platform-specific files
4. **Deploy**: Use platform-specific scripts (`install-device.sh`, etc.)
5. **Test**: Use `./test-feature.sh <feature>` to verify functionality

## Repository Structure

```
miso/
├── miso/                    # Feature specifications and platform knowledge
│   ├── platforms/           # iOS, Android/e/OS, Python development guides
│   ├── features.md          # Feature system specification
│   └── products.md          # Product system specification
├── apps/                    # Executable products
│   └── firefly/             # Current app: semantic search social media
│       ├── features/        # Feature specs (infrastructure, users, posts, etc.)
│       │   └── infrastructure/  # Foundational systems (ping, logging, email, testing)
│       └── product/         # Actual implementation
│           ├── client/imp/  # iOS and Android clients
│           └── server/imp/  # Python Flask server
├── miso.md                  # System overview
└── readme.md                # Project description
```

## Key Differences from Standard Development

1. **Natural Language Specs**: Features are markdown, not code comments
2. **Multi-Platform from Single Spec**: One feature markdown → multiple platform implementations
3. **Command-Line First**: All builds/deploys via shell scripts, minimal IDE usage
4. **Rapid USB Deployment**: iOS deployment in ~8-10 seconds, not TestFlight
5. **Implementation Separation**: Specs in `miso/`, executables in `apps/`
