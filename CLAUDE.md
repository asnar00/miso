# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

`miso` is an experimental system for natural language programming. It enables non-programmers to create and maintain software by specifying programs as trees of short natural-language markdown documents called "features".

**Key philosophy**: This is a line of experiments. Each new experiment may start from scratch or build on previous work. Previous experiments are stored in branches, and the main branch is cleared for new experiments. When working in this repo, be aware that the current state may represent work-in-progress on the latest experiment.

**Current experiment focus**: Tree-based post exploration (experiment 22.1). Recent work includes implementing hierarchical post navigation with swipe gestures and preserved scroll positions.

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
- **new-user**: New user onboarding with profile setup

**posts** (`apps/firefly/features/posts.md`):
- User-generated content with hierarchical structure (title, summary, optional image, body)
- Vector embeddings for semantic search
- Post metadata (timestamp, timezone, location, author, AI-generated flag)
- **view-posts**: Display posts with compact/expanded views, markdown formatting, image caching with thumbnails
- **recent-posts**: Fetch and display recent posts
- **new-post**: Create new posts
- **explore-posts**: Navigate through tree of posts and children with swipe gestures, preserved scroll position, multi-level hierarchy

**iOS View Architecture**: Uses `PostsListView` as a unified component for both root-level and child post lists, with `navigationPath: [Int]` for hierarchical navigation. PostView handles individual post display, expand/collapse, and navigation triggers.

**visual** (`apps/firefly/features/`):
- **background**: UI background color
- **icon**: App icon
- **logo**: App logo

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

**iOS Screenshot Capture**:
```bash
# From miso/platforms/ios/development/screen-capture/imp/
./screenshot.sh /tmp/screenshot.png  # Capture device screenshot
# Useful for visual verification of UI changes
```

**Android App Management** (from `apps/firefly/product/client/imp/eos/`):
```bash
adb shell am force-stop com.miso.noobtest          # Stop app
adb shell am start -n com.miso.noobtest/.MainActivity  # Start app
./mirror.sh  # Mirror project structure (if available)
```

**Server Management** (from `apps/firefly/product/server/imp/py/`):
```bash
./start.sh   # Start local Flask server
./stop.sh    # Stop local Flask server
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
- Updates `imp/pseudocode.md` to reflect feature changes
- Propagates changes to platform implementations (`imp/ios.md`, `imp/eos.md`, `imp/py.md`)
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
- Ensures feature.md, pseudocode.md, and platform.md reflect final working code
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

### Skill Delegation Pattern

Complex skills use **delegation** to save context:
- Skills with `delegate: true` in frontmatter spawn autonomous sub-agents
- Agent executes the skill independently using its own context budget
- Only final result returns to foreground conversation
- **Saves 80-90% of context tokens** for multi-step workflows

Delegated skills: `ios-deploy-usb`, `eos-deploy-usb`, `py-deploy-remote`, `miso`

Inline skills: All restart, stop, logs, and screen capture commands (simpler, faster)

**Delegation Behavior (Repository Convention)**:

When invoking a skill, always check the YAML frontmatter for `delegate: true`. If present, you MUST:

1. Use the Task tool with `subagent_type="instruction-follower"`
2. Provide the skill file path in the prompt: `.claude/skills/{skill-name}/skill.md`
3. Give clear context: "Follow the instructions in .claude/skills/{skill-name}/skill.md to [brief description]"
4. Let the sub-agent execute autonomously without intervention
5. When the sub-agent completes, summarize its final report for the user

Example delegation:
```python
# User says: "Deploy to iPhone"
# Skill loads, you see delegate: true in frontmatter

Task(
    subagent_type="instruction-follower",
    description="Deploy iOS app to device",
    prompt="Follow the instructions in .claude/skills/ios-deploy-usb/skill.md to build and deploy the iOS app to the connected iPhone via USB."
)
```

This pattern ensures complex workflows execute efficiently without consuming foreground context.

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
2. **Create features**: Follow format in `miso/features.md`
3. **Implement**: Add code to `imp/` subdirectories with platform-specific files
4. **Deploy**: Use platform-specific scripts (`install-device.sh`, etc.)
5. **Test**: Use `./test-feature.sh <feature>` to verify functionality

**The Implementation Process** (detailed in `miso/features/implementation.md`):
When features change, propagate through: feature → pseudocode → platform code → product code → build/test. The miso skill automates this workflow. For UI changes, includes iterative visual verification with screenshots.

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
