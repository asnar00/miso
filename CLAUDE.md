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

**Current experiment focus**: Multi-platform social media app with template-based content types and semantic search. Recent work includes toolbar navigation, post templates (profiles, queries), inline editing, fragment-level semantic search with GPU acceleration, and user invite system via TestFlight.

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

Social media platform using semantic search on markdown snippets (`apps/firefly.md`).

### Implemented Features

**infrastructure** (`apps/firefly/features/infrastructure/spec.md`):
- Foundation systems for development and deployment
- **ping**: HTTP health check endpoint
- **logging**: Multi-level logging (local, USB, remote)
- **email**: Send verification codes for passwordless login
- **testing**: Remote feature testing from Mac to device
- **storage**: Local data persistence (login state, cache, media)
- **watchdog**: Automatic server health monitoring and recovery system
  - Runs every minute via cron on remote server
  - Monitors `/api/ping` endpoint and PostgreSQL status
  - Automatic recovery: preserves crash logs in timestamped `bad/` folders, restarts services
  - Email notifications for unexpected failures (distinguishes from intentional shutdowns via marker file)
  - DNS requirement: Uses Google DNS (8.8.8.8, 8.8.4.4) for reliable email delivery

**users** (`apps/firefly/features/users/spec.md`):
- User accounts with email-based authentication
- Device association
- **sign-in**: Email-based login with 4-digit one-time codes (10-minute validity)
- **new-user**: New user onboarding with profile setup
- **profile**: User profile pages (name, profession, photo, bio text up to 300 words) with edit functionality
- **invite**: Invite friends via email with TestFlight link sharing (checks for existing users, tracks pending invites)

**posts** (`apps/firefly/features/posts/spec.md`):
- User-generated content with hierarchical structure (title, summary, optional image, body)
- Vector embeddings for semantic search
- Post metadata (timestamp, timezone, location, author, AI-generated flag)
- **templates**: Reusable field label sets for different post types (post, profile, query)
- **explore-posts**: Navigate through tree of posts and children with swipe gestures, preserved scroll position, multi-level hierarchy
- **recent-tagged-posts**: Fetch and display posts filtered by template tags and user, with adaptive loading/empty states
- **edit-posts**: Inline post creation and editing with image management (add/replace/delete), EXIF stripping, auto-resize
- **search**: Semantic search across all posts using fragment-level embeddings with GPU-accelerated vector similarity
- **toolbar**: Bottom navigation bar with three buttons (make post, search, users) in rounded lozenge design

**Search Implementation**:
- Fragment-based embeddings: Each post split into title, summary, and body sentences
- Vector model: all-mpnet-base-v2 (768-dimensional embeddings)
- GPU-accelerated cosine similarity for fast vector comparison
- Posts ranked by highest-scoring fragment
- Debounced search (0.5s after typing stops)
- Floating search UI: Circular button (bottom left) expands to search bar (max 600pt width)
- Navigation preserved when switching between search results and normal view

**iOS View Architecture**: Uses `PostsListView` as a unified component for both root-level and child post lists, with `navigationPath: [Int]` for hierarchical navigation. PostView handles individual post display, expand/collapse, and navigation triggers. Posts use template-based placeholder text for editing.

**Toolbar Navigation**: Three-button navigation bar at bottom of screen:
- Make Post: Shows recent posts with "Add Post" button
- Search: Shows user's saved queries with search interface
- Users: Shows all users (profiles) in the system

**visual** (`apps/firefly/features/`):
- **background**: UI background color
- **icon**: App icon
- **logo**: App logo

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

**iOS App Management** (from `apps/firefly/product/client/imp/ios/`):
```bash
./install-device.sh  # Build and deploy to device (~8-10 seconds)
./restart-app.sh     # Restart app on device without rebuilding
./stop-app.sh        # Stop app on device
./get-logs.sh        # Download app.log from device to device-logs.txt
./list-devices.sh    # List connected iOS devices
```

**iOS Screenshot Capture**:
```bash
# From miso/platforms/ios/development/screen-capture/imp/
./screenshot.sh /tmp/screenshot.png  # Capture device screenshot
# Critical for visual verification loop in miso workflow for UI changes
```

**Android App Management** (from `apps/firefly/product/client/imp/eos/`):
```bash
export JAVA_HOME="/opt/homebrew/opt/openjdk"  # Required for Gradle
./gradlew assembleDebug  # Build APK
adb install -r app/build/outputs/apk/debug/app-debug.apk  # Install
adb shell am start -n com.miso.noobtest/.MainActivity      # Start app
adb shell am force-stop com.miso.noobtest                  # Stop app
adb logcat | grep "NoobTest"  # View live logs
```

**Server Management** (from `apps/firefly/product/server/imp/py/`):
```bash
./start.sh            # Start local Flask server on port 8080
./stop.sh             # Stop local Flask server
./remote-shutdown.sh  # Stop remote server (185.96.221.52)

# View watchdog logs on remote server
ssh microserver@185.96.221.52 "tail -f ~/firefly-server/watchdog.log"

# Check saved crash logs
ssh microserver@185.96.221.52 "ls -lt ~/firefly-server/bad/"
```

**Server Development/Debugging Scripts** (from `apps/firefly/product/server/imp/py/`):
```bash
./regenerate_embeddings.py  # Rebuild all post embeddings from scratch
./debug_search.py           # Test search functionality with sample queries
./test_similarity.py        # Test embedding similarity computation
./emergency-restart.sh      # Force restart server with cleanup
./auto-restart.sh           # Restart server with automatic recovery
./send_watchdog_email.py    # Test watchdog email notifications
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

## Claude Code Skills

This repository includes a comprehensive skills system in `.claude/skills/` that provides automated workflows for common development tasks. Skills can be invoked by name or triggered by natural language phrases.

### Core Workflow Skills

**miso** - Automated feature-to-code implementation pipeline:
- Detects changed feature markdown files using git diff
- Updates `pseudocode.md` to reflect feature changes
- Propagates changes to platform implementations (`ios.md`, `eos.md`, `py.md`)
- Updates actual product code following patching instructions
- Builds, deploys, and tests the changes
- For UI changes: includes visual verification cycle with screenshots to ensure visible results match specs
- Iteratively debugs until visual verification passes
- Invoke with: "implement features", "run miso", "update implementations"

**make-skill** - Create new Claude Code skills:
- Generates skill directory and SKILL.md with proper structure
- Includes YAML frontmatter and documentation sections
- Use when creating automated workflows
- Invoke with: "create a skill", "make a skill", "add a skill"

**update-skill** - Improve existing skills based on usage:
- Analyzes what went wrong during skill execution
- Updates skill documentation with learnings
- Adds prerequisites, troubleshooting steps, or clarifications
- Use after resolving skill issues to prevent recurrence
- Invoke with: "update the skill", "improve the skill", "fix the skill instructions"

**post-debug-cleanup** - Document completed implementations:
- Updates feature specs and implementation docs after debugging iterations
- Ensures spec.md, pseudocode.md, and platform.md reflect final working code
- Captures exact details: measurements, API endpoints, gesture thresholds
- Preserves institutional knowledge from debugging process
- Use after feature implementation with multiple debugging rounds
- Invoke with: "post-debug cleanup", "document what we did", "clean up the implementation docs"

### Platform Skills

**iOS Skills** (`.claude/skills/ios-*`):
- `ios-deploy-usb` - Build and deploy to iPhone via USB (~8-10 seconds)
- `ios-restart-app` - Restart app on device without rebuilding
- `ios-stop-app` - Stop app running on device
- `ios-watch-logs` - Stream real-time logs from iPhone
- `ios-add-file` - Add Swift files to Xcode project without opening Xcode
- `ios-testflight-upload` - Build, archive, upload to TestFlight, and submit for Beta App Review
- `iphone-screen-capture` - Mirror iPhone screen on Mac using scrcpy

**Android/e/OS Skills** (`.claude/skills/eos-*`):
- `eos-deploy-usb` - Build and deploy to Android device via USB (~2-5 seconds)
- `eos-restart-app` - Restart app on device without rebuilding
- `eos-stop-app` - Stop app running on device
- `eos-watch-logs` - Stream real-time logcat from Android device
- `eos-screen-capture` - Mirror Android screen using scrcpy

**Python/Server Skills** (`.claude/skills/py-*`):
- `py-deploy-remote` - Deploy Flask server to remote machine (185.96.221.52)
- `py-start-local` - Start local Flask development server
- `py-stop-local` - Stop local Flask server
- `py-server-logs` - View server logs (local or remote)

**UI Automation Skills** (`.claude/skills/`):
- `ui-tap` - Trigger UI elements programmatically via HTTP for automated testing. Use when you need to press buttons, interact with UI, or verify UI changes without manual intervention. Invoke with "tap the X button", "press X", "trigger X".

### Using Skills

Skills are invoked automatically when you use trigger phrases:
```bash
# Examples:
"Deploy to iPhone" → invokes ios-deploy-usb
"Run miso" → invokes miso implementation workflow
"Watch iOS logs" → invokes ios-watch-logs
"Create a new skill for X" → invokes make-skill
```

Or explicitly by name via the Skill tool in Claude Code.

## Working with This Repository

1. **Start**: Read `miso.md` and relevant platform docs in `miso/platforms/{platform}/`
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
