# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

`miso` is a system for natural-language programming. Programs are specified as trees of short (<300 word) markdown documents called "features". Non-programmers can create and maintain software by writing plain-language specifications.

**Current experiment**: Multi-platform social media app (Firefly) with semantic search. See `apps/firefly/features/` for the feature tree.

**Project Naming**: Xcode/Android projects use "NoobTest" (bundle ID: `com.miso.noobtest`). "Firefly" is the product name.

**Experimental nature**: Each experiment may start fresh. Previous experiments are stored in branches before clearing main.

## Quick Reference

```bash
# Implement feature changes (use the 'miso' skill)
# Or manually: git diff → update pseudocode → platform code → product code → build

# Deploy to iOS (~8-10 seconds)
cd apps/firefly/product/client/imp/ios && ./install-device.sh

# Deploy to Android
cd apps/firefly/product/client/imp/android
export JAVA_HOME="/opt/homebrew/opt/openjdk"
./gradlew assembleDebug && adb install -r app/build/outputs/apk/debug/app-debug.apk

# Deploy Python server to remote
cd apps/firefly/product/server/imp/py
./remote-shutdown.sh && scp *.py *.txt *.sh microserver@185.96.221.52:~/firefly-server/
ssh microserver@185.96.221.52 "cd ~/firefly-server && ./start.sh"

# Test a feature (requires port forwarding: pymobiledevice3 usbmux forward 8081 8081 &)
cd apps/firefly/features/infrastructure/testing/imp && ./test-feature.sh <feature-name>

# View iOS logs
cd apps/firefly/product/client/imp/ios && ./get-logs.sh && cat device-logs.txt
```

## Core Architecture

### Feature System

Each feature is a folder containing:
```
feature-name/
├── spec.md           # User-facing specification (<300 words, plain language)
├── pseudocode.md     # Natural-language functions + patching instructions
├── ios.md            # iOS implementation (Swift)
├── android.md        # Android implementation (Kotlin)
├── py.md             # Python implementation
└── imp/              # Artifacts (logs, test files)
```

Features nest hierarchically: `A/spec.md` → `A/B/spec.md` → `A/B/C/spec.md`. Keep to 4-6 children max.

### Implementation Flow

The `miso` skill automates this chain when spec.md files change:
1. **spec.md** → **pseudocode.md**: Convert user requirements to natural-language functions with patching instructions
2. **pseudocode.md** → **platform files**: Generate actual code (ios.md, android.md, py.md)
3. **platform files** → **product code**: Apply patches to `apps/*/product/` files
4. **Build & Deploy**: Run platform scripts
5. **Visual Verify** (UI changes): Screenshot → compare to spec → iterate until match
6. **Post-debug cleanup**: Update all docs to reflect final working implementation

### Products vs Features

- **Features** (`apps/firefly/features/`): Specifications with implementation details
- **Products** (`apps/firefly/product/`): Actual runnable code assembled from features
- **miso/** (`miso/`): Platform knowledge and tools for code generation

## Platform Support

### iOS

**Critical**: Always use `LD="clang"` in xcodebuild to avoid Homebrew linker conflicts.

| Script | Purpose |
|--------|---------|
| `./install-device.sh` | Build and deploy (~8-10s) |
| `./restart-app.sh` | Restart without rebuild |
| `./stop-app.sh` | Stop app on device |
| `./get-logs.sh` | Download logs to device-logs.txt |
| `./list-devices.sh` | List connected devices |
| `./sync-tunables.sh` | Sync tunable parameters |
| `./testflight-deploy.sh` | Full TestFlight pipeline |

**Key docs**: `miso/platforms/ios/` (project editing, USB deployment, logging)

### Android

**Critical**: Set `export JAVA_HOME="/opt/homebrew/opt/openjdk"` before Gradle.

```bash
./gradlew assembleDebug && adb install -r app/build/outputs/apk/debug/app-debug.apk
adb shell am force-stop com.miso.noobtest  # Stop app
adb logcat | grep "NoobTest"               # Live logs
```

**Key docs**: `miso/platforms/android/` (Kotlin, Jetpack Compose, Material 3)

### Python/Flask

**Remote server** (`185.96.221.52:8080`): PostgreSQL backend, watchdog monitoring (cron), crash recovery with evidence in `~/firefly-server/bad/`.

| Script | Purpose |
|--------|---------|
| `./start.sh` | Start local server (port 8080) |
| `./stop.sh` | Stop local server |
| `./remote-shutdown.sh` | Stop remote server |
| `./watchdog.sh` | Monitor and auto-restart server |
| `./regenerate_embeddings.py` | Rebuild all embeddings |

**First-time setup**:
```bash
cp .env.example .env  # Add API keys if needed
python3 download_model.py  # Downloads all-mpnet-base-v2 (~420MB)
```

**Dependencies**: PostgreSQL, sentence-transformers, PyTorch with MPS (M-series GPU)

## Current Application: Firefly

Social media platform with semantic search on markdown snippets.

**Feature Areas** (`apps/firefly/features/`):
- `infrastructure/` - Foundation (ping, logging, testing, storage, watchdog)
- `users/` - Authentication, profiles, invites
- `posts/` - Content, templates, navigation, semantic search

**Technical Highlights**:
- Fragment-based semantic search (all-mpnet-base-v2, 768-dim embeddings)
- GPU-accelerated similarity (MPS on M-series Macs)
- Hierarchical post navigation with swipe gestures

**Key Source Files**:
- iOS: `apps/firefly/product/client/imp/ios/NoobTest/` - Swift files (PostsListView, PostView, ContentView)
- Android: `apps/firefly/product/client/imp/android/app/src/main/kotlin/com/miso/noobtest/`
- Server: `apps/firefly/product/server/imp/py/` - `app.py` (Flask routes), `db.py` (PostgreSQL), `embeddings.py` (semantic search)

## Testing

Remote feature testing from Mac to device via USB (runs in real app, not simulator).

```bash
# Setup once per session
pymobiledevice3 usbmux forward 8081 8081 &

# Run test
cd apps/firefly/features/infrastructure/testing/imp
./test-feature.sh ping
```

**Register new tests**:
```swift
// iOS
TestRegistry.shared.register(feature: "myfeature") { TestResult(success: true) }
```
```kotlin
// Android
TestRegistry.register("myfeature") { TestResult(success = true) }
```

## Visual Verification

For UI changes, take screenshots to verify results match specs:
```bash
# iOS
miso/platforms/ios/development/screen-capture/imp/screenshot.sh /tmp/screenshot.png

# Android
adb exec-out screencap -p > /tmp/screenshot.png
```

## UI Automation

The app exposes HTTP endpoints for programmatic UI interaction during testing:
```bash
# Trigger a registered UI element (requires test server running)
curl http://localhost:8081/ui/tap?element=<element-id>
```

Register elements in code via `UIAutomationRegistry` (iOS) or equivalent Android registry.

## Claude Code Skills

Skills in `.claude/skills/` provide automated workflows. Skills marked with `delegate: true` spawn sub-agents to save context tokens.

**Core Skills**:
| Skill | Purpose |
|-------|---------|
| `miso` | Full feature-to-code pipeline with visual verification |
| `post-debug-cleanup` | Update specs after debugging iterations |

**State Tracking**: The miso skill tracks its last run in `.claude/skills/miso/.last-run` to process only changed features.

**Delegated Skills** (multi-step, run as sub-agents):
- `ios-deploy-usb`, `android-deploy-usb`, `py-deploy-remote` - Complex deployment workflows

**Inline Skills** (quick, run directly):
- **iOS**: `ios-restart-app`, `ios-stop-app`, `ios-watch-logs`, `ios-add-file`, `ios-testflight-upload`, `iphone-screen-capture`
- **Android**: `android-restart-app`, `android-stop-app`, `android-watch-logs`, `android-screen-capture`
- **Server**: `py-start-local`, `py-stop-local`, `py-server-logs`

**Utilities**: `ui-tap` (trigger UI elements via HTTP), `make-skill`, `update-skill`

## Common Errors

| Error | Fix |
|-------|-----|
| `clang: error: linker command failed` | Add `LD="clang"` to xcodebuild |
| `JAVA_HOME is not set` | `export JAVA_HOME="/opt/homebrew/opt/openjdk"` |
| `No devices found` | Unlock iPhone, tap "Trust This Computer?" |
| Port 8081 not responding | `pymobiledevice3 usbmux forward 8081 8081 &` |
| Remote server not responding | `./remote-shutdown.sh` then redeploy |

## Repository Structure

```
miso/
├── miso/                           # Platform knowledge and tools
│   └── platforms/                  # iOS, Android, Python docs
├── apps/
│   └── firefly/
│       ├── features/               # Feature specs (hierarchical folders with spec.md)
│       └── product/
│           ├── client/imp/
│           │   ├── ios/NoobTest/   # Swift source files
│           │   └── android/        # Kotlin/Gradle project
│           └── server/imp/py/      # Python Flask server
├── .claude/skills/                 # Claude Code automation skills
└── readme.md
```

## Git Workflow

```bash
# Starting a new experiment - preserve current work first
git checkout -b experiment-N && git push -u origin experiment-N
git checkout main && git rm -rf * && git commit -m "Start experiment N+1"
```
