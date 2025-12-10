# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

`miso` is a line of experiments exploring "modular specifications" - trees of short natural-language text documents called "features" that describe programs. It enables non-programmers ("domain experts") to create and maintain software by specifying programs in plain language.

**Core philosophy**:
- Find better ways for users, engineers, and agents to collaborate building software
- Create a "natural-language normal form" representation of programs
- Consider this form as defining a *family of programs* with working examples
- Allow features to be added, removed, or modified at any time
- Output stable, predictable implementations on any platform
- Specifications are kept up-to-date so code can be rebuilt from scratch or ported to multiple platforms

**Experimental nature**: Each new experiment may start from scratch or build on previous work. Previous experiments are stored in branches, and the main branch is cleared for new experiments. When working in this repo, be aware that the current state may represent work-in-progress on the latest experiment.

**Experiment Branches**: When starting a new experiment, create a branch for the current work before clearing main. Previous experiments remain accessible via their branches.

**Current experiment focus**: Multi-platform social media app (Firefly) with template-based content types and semantic search. See `apps/firefly/features/` for current feature tree.

**Project Naming**: The Xcode project and Android package are named "NoobTest" (bundle ID: `com.miso.noobtest`), while "Firefly" is the product/marketing name. Use "NoobTest" for bundle identifiers, app management commands, and debugging.

## Quick Reference

**Most Common Commands**:
```bash
# Implement feature changes
# (from repo root, after editing feature markdown files)
# Use the 'miso' skill or: git diff to find changes, then follow implementation.md

# Deploy to iOS device
cd apps/firefly/product/client/imp/ios/
./install-device.sh  # ~8-10 seconds

# Deploy to Android device
cd apps/firefly/product/client/imp/eos/
export JAVA_HOME="/opt/homebrew/opt/openjdk"
./gradlew assembleDebug && adb install -r app/build/outputs/apk/debug/app-debug.apk

# Deploy to remote server
cd apps/firefly/product/server/imp/py/
./remote-shutdown.sh
scp *.py *.txt *.sh microserver@185.96.221.52:~/firefly-server/
ssh microserver@185.96.221.52 "cd ~/firefly-server && ./start.sh"

# Test a feature
cd apps/firefly/features/infrastructure/testing/imp
pymobiledevice3 usbmux forward 8081 8081 &  # Once per session
./test-feature.sh <feature-name>

# View logs
cd apps/firefly/product/client/imp/ios/
./get-logs.sh && cat device-logs.txt
```

## Core Architecture

### Feature Specification System

Programs are specified as hierarchical markdown trees. Each feature lives in its own folder:

```
feature-name/
├── spec.md           # Feature specification (<300 words, plain language)
├── pseudocode.md     # Natural-language function definitions and patching instructions
├── ios.md            # iOS platform implementation
├── eos.md            # Android/e/OS platform implementation
├── py.md             # Python platform implementation
└── imp/              # Other artifacts (logs, test files, debugging notes)
```

**Structure**:
- `A/spec.md` → `A/B/spec.md` → `A/B/C/spec.md` (nested features)
- Each spec: `#` title, *emphasized* one-line summary, <300 words of plain language
- Keep features manageable: 4-6 children max

**Files**:
- `spec.md` - The feature specification in plain language for users
- `pseudocode.md` - Natural-language function definitions and patching instructions
- `ios.md`, `eos.md`, `py.md` - Platform-specific implementations with actual code
- `imp/` - Folder for other artifacts (logs, debugging issues, test data)

### Products vs Features

**Features**: Capability specifications with implementation details (e.g., `apps/firefly/features/`)
**Products**: Executable applications assembled from features (e.g., `apps/firefly/product/`)

The `miso/` folder contains the "IDE" - tools and platform knowledge for code generation. Apps like `firefly/` contain both their features and product code together.

Products follow the same markdown tree convention but their `imp/` folders contain actual runnable executables.

## Platform Support

Three platforms supported: **iOS**, **Android/e/OS**, and **Python**

### iOS Development

**Critical**: Always use `LD="clang"` in xcodebuild commands to avoid Homebrew linker conflicts.

**Key Documentation**: `miso/platforms/ios/`
- `setup/project-editing/spec.md` - Adding files to Xcode without GUI (edit project.pbxproj directly)
- `build-and-deploy/spec.md` - Complete USB deployment workflow
- `development/logging/spec.md` - OSLog/Logger API best practices

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

**Critical**: Set `export JAVA_HOME="/opt/homebrew/opt/openjdk"` before any Gradle command.

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

**Remote Server Details**:
- Runs on port 8080 with PostgreSQL database backend
- Automated watchdog monitoring (cron: every minute)
- Automatic crash recovery with evidence preservation in `~/firefly-server/bad/` folders
- Email notifications for unexpected failures

**Local Server**: Runs on port 8080 (same as remote) for consistency.

**Server Configuration**:
```bash
# From apps/firefly/product/server/imp/py/
# First time setup: Copy .env.example to .env
cp .env.example .env
# Edit .env to add your Anthropic API key (currently optional, embeddings use local model)
```

**First-time Model Download** (required for semantic search):
```bash
cd apps/firefly/product/server/imp/py/
python3 download_model.py  # Downloads all-mpnet-base-v2 model (~420MB)
```

**Key Dependencies**:
- PostgreSQL database (required for production server)
- Sentence transformers (all-mpnet-base-v2 model for local embeddings, ~420MB download)
- PyTorch with MPS (Metal Performance Shaders) for M2 GPU acceleration
- Local model is cached in ~/.cache/torch/sentence_transformers/

## Current Application: Firefly

Social media platform using semantic search on markdown snippets.

**Feature Tree**: `apps/firefly/features/` - Browse this directory to see all implemented features organized hierarchically.

**Key Feature Areas**:
- `infrastructure/` - Foundation systems (ping, logging, email, testing, storage, watchdog)
- `users/` - User accounts, authentication, profiles, invites
- `posts/` - Content creation, templates, navigation, semantic search
- `visual/` - UI theming (background, icon, logo)

**Technical Highlights**:
- Fragment-based semantic search using all-mpnet-base-v2 embeddings (768-dim)
- GPU-accelerated vector similarity (MPS on M-series Macs)
- Hierarchical post navigation with swipe gestures
- Template-based content types (post, profile, query)

**iOS Architecture**: `PostsListView` unified component with `navigationPath: [Int]` for hierarchical navigation. `PostView` handles individual posts. Three-button toolbar for navigation.

## Testing Infrastructure

**testing** (`apps/firefly/features/infrastructure/testing/spec.md`):
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

**iOS Scripts** (from `apps/firefly/product/client/imp/ios/`):
| Script | Purpose |
|--------|---------|
| `./install-device.sh` | Build and deploy (~8-10 seconds) |
| `./restart-app.sh` | Restart without rebuilding |
| `./stop-app.sh` | Stop app on device |
| `./get-logs.sh` | Download app.log to device-logs.txt |
| `./list-devices.sh` | List connected iOS devices |
| `./testflight-deploy.sh` | Build, archive, upload to TestFlight |
| `./sync-tunables.sh` | Sync tunable parameters |

**iOS Screenshot** (for visual verification in miso workflow):
```bash
miso/platforms/ios/development/screen-capture/imp/screenshot.sh /tmp/screenshot.png
```

**Android Commands** (from `apps/firefly/product/client/imp/eos/`):
```bash
adb shell am force-stop com.miso.noobtest  # Stop app
adb logcat | grep "NoobTest"               # View live logs
```

**Server Scripts** (from `apps/firefly/product/server/imp/py/`):
| Script | Purpose |
|--------|---------|
| `./start.sh` | Start local server (port 8080) |
| `./stop.sh` | Stop local server |
| `./remote-shutdown.sh` | Stop remote server |
| `./watchdog.sh` | Health check (cron uses this) |
| `./auto-restart.sh` | Automated server restart |
| `./emergency-restart.sh` | Force restart after crash |
| `./regenerate_embeddings.py` | Rebuild all embeddings |
| `./debug_search.py` | Test search queries |

**Remote Server Logs**:
```bash
ssh microserver@185.96.221.52 "tail -f ~/firefly-server/watchdog.log"
ssh microserver@185.96.221.52 "ls -lt ~/firefly-server/bad/"  # Crash logs
```

## Claude Code Skills

Skills in `.claude/skills/` provide automated workflows. Invoke by name or trigger phrases.

### Core Workflow Skills

| Skill | Purpose | Trigger Phrases |
|-------|---------|-----------------|
| `miso` | Feature-to-code pipeline: spec.md → pseudocode → platform code → product code → build/deploy. Visual verification for UI changes. | "implement features", "run miso" |
| `make-skill` | Create new skill with YAML frontmatter | "create a skill", "make a skill" |
| `update-skill` | Improve skill docs after troubleshooting | "update the skill", "fix the skill" |
| `post-debug-cleanup` | Update specs after debugging iterations | "post-debug cleanup", "document what we did" |

### Platform Skills

| Skill | Purpose |
|-------|---------|
| `ios-deploy-usb` | Build and deploy to iPhone (~8-10s) |
| `ios-restart-app` | Restart without rebuilding |
| `ios-stop-app` | Stop app on device |
| `ios-watch-logs` | Stream real-time logs |
| `ios-add-file` | Add Swift files to Xcode project |
| `ios-testflight-upload` | Full TestFlight upload pipeline |
| `iphone-screen-capture` | Mirror iPhone screen |
| `eos-deploy-usb` | Build and deploy to Android (~2-5s) |
| `eos-restart-app` | Restart without rebuilding |
| `eos-stop-app` | Stop app on device |
| `eos-watch-logs` | Stream logcat |
| `eos-screen-capture` | Mirror Android screen via scrcpy |
| `py-deploy-remote` | Deploy to remote server |
| `py-start-local` | Start local Flask server |
| `py-stop-local` | Stop local Flask server |
| `py-server-logs` | View local/remote server logs |
| `ui-tap` | Trigger UI elements via HTTP |

## Common Errors & Quick Fixes

| Error | Fix |
|-------|-----|
| `clang: error: linker command failed` | Add `LD="clang"` to xcodebuild |
| `JAVA_HOME is not set` | `export JAVA_HOME="/opt/homebrew/opt/openjdk"` |
| `No devices found` | Unlock iPhone, tap "Trust This Computer?" |
| Port 8081 not responding | `pymobiledevice3 usbmux forward 8081 8081 &` |
| Remote server not responding | `./remote-shutdown.sh` then redeploy |

## Working with This Repository

1. **Start**: Read `miso/spec.md` and relevant platform docs in `miso/platforms/{platform}/`
2. **Create features**: Follow format in `miso/features/spec.md`
3. **Implement**: Add `pseudocode.md` and platform files (`ios.md`, `eos.md`, `py.md`) alongside `spec.md`
4. **Deploy**: Use platform-specific scripts (`install-device.sh`, etc.)
5. **Test**: Use `./test-feature.sh <feature>` to verify functionality

**The Implementation Process** (detailed in `miso/features/implementation/spec.md`):
When features change, propagate through: feature → pseudocode → platform code → product code → build/test. The miso skill automates this workflow. For UI changes, includes iterative visual verification with screenshots.

**Git Workflow for Experiments**:
```bash
# Starting a new experiment - preserve current work first
git checkout -b experiment-N  # Create branch for current experiment
git push -u origin experiment-N
git checkout main
git rm -rf *  # Clear main for new experiment
git commit -m "Start experiment N+1"

# View previous experiments
git branch -a  # List all branches to see past experiments
git checkout experiment-N  # Switch to previous experiment
```

## Repository Structure

```
miso/
├── miso/                    # Feature specifications and platform knowledge
│   ├── platforms/           # iOS, Android/e/OS, Python development guides
│   ├── features/spec.md     # Feature system specification
│   └── products/spec.md     # Product system specification
├── apps/                    # Executable products
│   └── firefly/             # Current app: semantic search social media
│       ├── features/        # Feature specs (each feature is a folder with spec.md)
│       │   ├── infrastructure/  # Foundational systems
│       │   │   ├── spec.md      # Infrastructure spec
│       │   │   └── ping/        # Subfeature folder
│       │   │       ├── spec.md
│       │   │       ├── pseudocode.md
│       │   │       ├── ios.md
│       │   │       └── py.md
│       │   └── ...
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

## Working Files

- `scribbles.md` - Personal scratch pad for ideas, todo lists, and experiment notes (not committed with sensitive content)
