---
name: iphone-screen-capture
description: Start the iPhone screen capture app to mirror a connected iPhone's screen on macOS. Use when the user wants to view their iPhone screen, mirror their device, or start screen capture.
delegate: true
---

## ⚠️ DELEGATION REQUIRED

**This skill must be executed by the instruction-follower subagent.**

When you see this skill invoked, you MUST use the Task tool to delegate it:

```
Task(
    subagent_type="instruction-follower",
    description="[Brief 3-5 word description]",
    prompt="Follow the instructions in .claude/skills/iphone-screen-capture/skill.md to [complete task description]."
)
```

**DO NOT execute the instructions below directly.** The subagent will read this file and execute autonomously, then report back the results.

---


# iPhone Screen Capture

## Overview

This skill starts the iPhone screen capture application, which mirrors a connected iPhone's screen on the Mac desktop. The app automatically detects when an iPhone is connected via USB and displays its screen in a borderless window.

## When to Use

Invoke this skill when the user:
- Asks to "start screen capture"
- Wants to "see their iPhone screen"
- Wants to "mirror their iPhone"
- Mentions viewing or displaying their connected device
- Says "show me my phone"

## Prerequisites

- iPhone must be connected via USB
- The device should be trusted (user may need to tap "Trust This Computer" on iPhone)
- The skill runs a Swift app that requires AVFoundation and CoreMediaIO frameworks

## Instructions

1. Navigate to the screen capture implementation directory:
   ```bash
   cd miso/platforms/ios/development/screen-capture/imp
   ```

2. Run the screen capture script:
   ```bash
   ./iphone_screencap.sh
   ```

3. Inform the user that:
   - The script compiles and launches a Mac app that will display their iPhone screen
   - A window will appear showing "Checking..." initially
   - Once the iPhone is detected, the screen will appear in the window
   - There's a console button (">") on the right edge to view device logs
   - The app will continue running until they close it

## Expected Behavior

- The script compiles `main.swift` and runs the resulting executable
- A borderless window (390x844) appears on screen
- If an iPhone is connected, its screen appears within ~2 seconds
- If no iPhone is detected, the window shows "Waiting for iPhone..."
- The app polls for device connection every 2 seconds

## Troubleshooting

If the app doesn't show the iPhone screen:
- Check that the iPhone is physically connected via USB
- Ensure the iPhone is unlocked and the "Trust This Computer" prompt has been accepted
- The device may need to be disconnected and reconnected
- Check that no other apps are using the iPhone camera/screen capture

## Notes

- This app runs in the foreground and blocks the terminal
- To stop it, the user needs to quit the app or use Ctrl+C in the terminal
- The app creates a log file at `/Users/asnaroo/Desktop/experiments/iphonecap/app.log`
- The console feature attempts to stream device logs from the Firefly app
