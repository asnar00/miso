# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Miso ("make it so") is an experimental framework for building software using modular specifications - trees of short natural-language text snippets describing programs. This is a specification-first approach where programs are described in natural language before implementation.

## Core Architecture

The project uses a hierarchical structure of markdown files to represent modular specifications:

- **Snippets** (`miso/snippets.md`): Small natural-language markdown documents that describe system components. Each snippet has a title, emphasized summary, and content under 300 words. Snippets can have up to 6 children and reference others via "soft links".

- **Tools** (`miso/tools/`): Computer programs that perform repeatable actions, from CLI utilities to desktop apps. Tools implement features and store code/artifacts in `toolname~/imp/platform/` folders (where `platform` is the target platform like `macos`).

- **Platforms** (`miso/platforms/`): Platform-specific expertise for operating systems, languages, and SDKs. Contains implementation knowledge, tips, and examples.

- **Concerns** (`miso/concerns/`): Cross-cutting features that affect multiple other features. Features can indicate they're affected by concerns using soft-links.

- **Howtos** (`miso/howtos/`): Instructions for agents or users, containing bullet-point action lists. Can invoke specific actions using `inline-code` notation.

## Current Implementation Details

### macOS SwiftUI Applications

The project currently implements several macOS SwiftUI applications:

- **hello**: Simple greeting app located in `miso/tools/~hello/imp/macos/hello/`
- **viewer**: Snippet tree explorer app located in `miso/tools/~viewer/imp/macos/viewer/`
- **screenshot**: Window capture tool located in `miso/tools/~screenshot/imp/macos/`

### Building and Running Applications

**Building Xcode Projects:**
Due to environment conflicts with Homebrew tools, use AppleScript to invoke Xcode IDE directly instead of `xcodebuild`:
```bash
osascript -e 'tell application "Xcode" to build active workspace document'
```

**Running Applications:**
- Preferred method: `open "/path/to/app.app"`
- Direct execution: `"/path/to/app.app/Contents/MacOS/appname"`
- Find built apps: `find ~/Library/Developer/Xcode/DerivedData -name "appname.app" -type d`

**Stopping Applications:**
```bash
pkill -f appname
```

### Application Architecture

**Viewer App Structure:**
- Uses SwiftUI with a sidebar-only layout (narrow left column)
- Implements breadcrumb navigation for snippet hierarchies
- Features markdown preview rendering and clickable children lists
- Supports remote control via AppleScript events

**AppleScript Remote Control:**
The viewer accepts commands for automation:
```bash
# Test command
osascript -e 'tell application "viewer" to «event MISOHELO»'

# Navigation command
osascript -e 'tell application "viewer" to «event MISOGOTO» given «class PATH»:"tools/viewer"'
```

### Helper Scripts

- `send_viewer_command.sh`: Sends commands to viewer app via file-based communication

## Development Workflow

1. **Adding features**: Create new markdown snippets under the appropriate category
2. **Implementing tools**: Place implementations in `toolname~/imp/platform/` structure
3. **Building apps**: Use AppleScript to invoke Xcode IDE builds
4. **Testing apps**: Use `open` command or direct executable paths
5. **Remote control**: Use AppleScript events for viewer automation

## Key Principles

- Each experiment starts fresh or builds on previous ones (stored in branches)
- Main branch is always cleared for new experiments
- Specifications define families of programs plus working examples
- Features should be modifiable by users at any time
- Implementations should be stable and predictable across platforms
- Tools should NOT call external APIs but CAN be called by agents