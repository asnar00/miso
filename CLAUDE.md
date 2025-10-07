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
- `testflight.md`: TestFlight cloud distribution
- `code-signing.md`: Certificates and provisioning profiles
- `screen-capture.md`: Screen recording from device

**Critical build issue**: Homebrew linker conflict
- If builds fail with `ld: unknown option: -platform_version`, use: `xcodebuild ... LD="clang" build`
- This forces clang as the linker instead of Homebrew's `/opt/homebrew/bin/ld`

**Build command structure**:
```bash
xcodebuild -project MyApp.xcodeproj \
    -scheme MyApp \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
    LD="clang" \
    build
```

### Android/e/OS Platform (`miso/platforms/eos/`)

Template app: `miso/platforms/eos/template/`

**Technologies**: Kotlin, Jetpack Compose, Material 3, Gradle Kotlin DSL

**Key topics**:
- `create-app.md`: Android project structure with Gradle
- `build.md`: Building with Gradle
- `usb-deploy.md`: USB deployment to devices
- `setup.md`: Android SDK setup

**Build command**:
```bash
./gradlew assembleDebug
```

### Python Platform (`miso/platforms/py/`)

Template app: `miso/platforms/py/template/`

**Technologies**: Flask, pip, virtualenv

**Key topics**:
- `create-app.md`: Creating Flask applications
- `flask-deployment.md`: Server deployment

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
