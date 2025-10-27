---
name: miso
description: Implement feature changes by updating pseudocode, platform code, and product code from modified feature markdown files. Use when user asks to "implement features", "run miso", "update implementations", or "sync code with features".
---

# Miso Implementation Skill

## Overview

This skill implements the miso feature-to-code workflow. When feature markdown files change, it automatically propagates those changes through the implementation chain: pseudocode → platform-specific code → product code.

## Understanding Miso Features

Miso specifies programs as a tree of **features**: short (<300 word) natural-language markdown files that specify behavior.

**Feature Format**:
- Start with a `#` title
- Followed by an *emphasized* one-line summary
- Up to 300 words of natural language
- Use simple language understandable by users
- Avoid technical jargon and code

**Feature Hierarchy**:
- To add detail to feature `A.md`, create subfeature `A/B.md`
- To add detail to `A/B.md`, create subfeature `A/B/C.md`
- Keep manageable: no more than 4-6 children per feature
- Group and summarize if children get out of control

**Implementation Details** for feature `A/B/C` are stored in `A/B/C/imp/`:
- `imp/pseudocode.md`: Natural-language function definitions and patching instructions
- `imp/ios.md`, `imp/eos.md`, `imp/py.md`: Platform-specific implementations with actual code
- Other artifacts: logs, debugging notes, etc.

## The Implementation Process

When a user changes feature `A/B.md` or adds a subfeature, the implementation process ensures code is created following this routine:

**Step 1: Pseudocode**
- Check if `A/B/imp/pseudocode.md` is up-to-date
- If not, ensure changes to the feature are reflected in pseudocode
- Pseudocode uses natural language function definitions
- Include patching instructions (where/how to integrate into product)

**Step 2: Platform Code**
- Check if platform implementations (`ios.md`, `eos.md`, etc.) are up-to-date vs pseudocode
- If not, edit them to reflect the most recent pseudocode changes
- Use platform-appropriate actual code syntax (Swift, Kotlin, Python)

**Step 3: Product Code**
- Check if actual target product code is up-to-date vs platform implementations
- If not, make appropriate modifications to product code
- Follow patching instructions from platform implementation files

**Step 4: Build, Deploy, Test**
- Build and deploy the changed feature to devices/servers
- Run tests if available

## When to Use

Invoke this skill when the user:
- Says "implement features" or "run miso"
- Asks to "update implementations" or "sync code"
- Mentions implementing or deploying feature changes
- Wants to propagate feature changes to code

## Implementation Workflow

The miso implementation process follows this sequence:

### 1. Detect Changed Features

Find all feature `.md` files that have changed since the last run:
- Use `git diff` to find modified feature files in `apps/` and `miso/` directories
- Look for files matching pattern `**/*.md` but exclude `**/imp/**` files
- Track the last run timestamp (stored in `.claude/skills/miso/.last-run`)

### 2. Update Pseudocode

For each changed feature `A/B.md`:
- Check if `A/B/imp/pseudocode.md` exists
- If it exists, read both the feature and pseudocode
- Determine if pseudocode needs updating based on feature changes
- If needed, update `A/B/imp/pseudocode.md` to reflect the feature changes
- Use natural language function definitions and patching instructions

### 3. Update Platform Implementations

For each feature with updated pseudocode:
- Check for platform-specific implementations: `A/B/imp/ios.md`, `A/B/imp/eos.md`, `A/B/imp/py.md`
- For each existing platform file:
  - Read the pseudocode and platform implementation
  - Determine if platform code needs updating
  - Update platform implementation to match pseudocode
  - Use actual code syntax appropriate for the platform (Swift, Kotlin, Python)

### 4. Update Product Code

For each updated platform implementation:
- Identify the target product (look in `apps/` hierarchy to find the product path)
- Read the patching instructions from the platform implementation
- Locate the actual product code files that need modification
- Apply the changes to product code following the patching instructions
- Make minimal, targeted edits to existing code

### 5. Build, Deploy, and Test

After updating product code:
- Determine which platform was modified (iOS, Android, Python)
- Build and deploy using appropriate scripts:
  - iOS: `./install-device.sh` from product client imp/ios directory
  - Android: `export JAVA_HOME="/opt/homebrew/opt/openjdk" && ./gradlew assembleDebug && adb install -r app/build/outputs/apk/debug/app-debug.apk`
  - Python: `./remote-shutdown.sh && scp && ssh` for remote server deployment
- If a test exists for the feature, run it using `./test-feature.sh <feature-name>`

### 6. Visual Verification and Iterative Debugging (for UI changes)

For features that affect visual appearance (colors, layouts, UI elements), use an **iterative debugging cycle**:

**iOS Visual Verification Cycle**:

1. **Take Screenshot**:
   ```bash
   cd apps/firefly/product/client/imp/ios
   ./restart-app.sh
   sleep 3
   cd /Users/asnaroo/Desktop/experiments/miso/miso/platforms/ios/development/screen-capture/imp
   ./screenshot.sh /tmp/verification-screenshot.png
   ```

2. **Verify Against Specification**:
   - Read the screenshot image
   - Compare what you see to what the feature specification says
   - For color changes: Check if expected color is visible
   - For layout changes: Check if elements are positioned correctly
   - For UI elements: Check if components appear as specified

3. **If Verification PASSES**:
   - Proceed to step 7 (Update Implementation Documentation)

4. **If Verification FAILS**:
   - **Investigate**: Search for ALL files that might contain the old implementation
   - **Example**: For background color, search: `grep -r "Color(red: 64/255" NoobTest/`
   - **Discovery**: You may find the change is needed in multiple files, not just the ones initially updated
   - **Document findings**: Note which files were missed

5. **Fix All Instances**:
   - Update ALL files that need the change
   - Rebuild: `./install-device.sh`
   - Restart: `./restart-app.sh && sleep 3`
   - **Take another screenshot**
   - Read and verify again

6. **Iterate Until Success**:
   - Repeat steps 4-5 until visual verification passes
   - Don't stop at the first failed attempt
   - Each failure teaches you about files that need updating

**Android Visual Verification Cycle**:
1. Restart: `adb shell am force-stop com.miso.noobtest && adb shell am start -n com.miso.noobtest/.MainActivity`
2. Wait: `sleep 3`
3. Screenshot: `adb exec-out screencap -p > /tmp/verification-screenshot.png`
4. Read and verify (same logic as iOS)
5. If fails: Search for missed files, fix, rebuild, repeat

**Key Insight**: Initial implementation often misses files. Visual verification catches this and drives iteration until the visible result matches the specification.

### 7. Update Implementation Documentation Post-Debug

After visual verification succeeds, **update the platform implementation files** to capture ALL the changes discovered during debugging:

1. **Review what was actually changed**:
   ```bash
   git diff apps/firefly/product/client/imp/ios/
   ```

2. **Update the platform implementation markdown** (`imp/ios.md`, `imp/eos.md`, etc.):
   - Add ALL target files that needed changes
   - Include line numbers where colors/values appear
   - Add any discovered patterns (e.g., "search all views for Color(red:")
   - Document why each file needs updating

3. **Example Update**:
   ```markdown
   ## Product Integration

   **Primary Target**: ContentView.swift
   **Additional Targets**: All views with background colors must be updated

   The following files contain backgrounds:
   1. PostsView.swift (line ~26)
   2. SignInView.swift (line ~24)
   3. NewUserView.swift (line ~10)
   4. NewPostView.swift (lines ~11, ~47)
   5. NoobTestApp.swift (line ~49)

   **Important**: Search for all instances of `Color(red:` and replace...
   ```

4. **Why This Matters**:
   - Next time miso runs, it will know to update ALL these files
   - If someone deletes the product code, the spec can rebuild it completely
   - The implementation documentation becomes the source of truth

## State Tracking

Store the last run timestamp in `.claude/skills/miso/.last-run`:
- Before starting, read this file to get the baseline for comparison
- After successful completion, update it with the current timestamp
- If the file doesn't exist, compare against the last git commit

## Key Principles

1. **Incremental**: Only process features that have actually changed
2. **Chain of Trust**: Each level (pseudocode → platform → product) builds on the previous
3. **Minimal Edits**: Make targeted changes to existing code, don't rewrite unnecessarily
4. **Verify Visually**: For UI changes, take screenshots and iterate until the result matches the spec
5. **Learn from Failures**: Each visual verification failure reveals files that were missed
6. **Update Documentation**: Capture all discovered changes in implementation files so next time is complete
7. **Track State**: Remember what was last processed to avoid redundant work

## Example Workflow

User modifies `apps/firefly/features/background.md` (changes color from turquoise to mauve):

1. **Detect**: `background.md` changed since last run
2. **Update Pseudocode**: `apps/firefly/features/background/imp/pseudocode.md` to reflect mauve color
3. **Update Platform Spec**: `apps/firefly/features/background/imp/ios.md` with new RGB values
4. **Update Product Code**: Initial change to `ContentView.swift` with RGB(224, 176, 255)
5. **Build & Deploy**: `./install-device.sh`
6. **Visual Verify (Attempt 1)**:
   - Restart app, take screenshot
   - **FAILS**: Still shows turquoise
   - Investigation: App is showing PostsView, not ContentView!
7. **Fix & Rebuild**:
   - Update `PostsView.swift` with mauve color
   - Rebuild and redeploy
8. **Visual Verify (Attempt 2)**:
   - Take screenshot again
   - **SUCCESS**: Shows mauve background
9. **Search for Remaining Instances**:
   - `grep -r "Color(red: 64/255" NoobTest/`
   - Find 5 more files with old color
10. **Update Implementation Documentation**:
    - Edit `background/imp/ios.md`
    - Add all 6 target files that need the color change
    - Include line numbers and search patterns
11. **Test**: Run `./test-feature.sh background` if test exists
12. **Track**: Update `.last-run` timestamp

**Result**: The implementation documentation now captures that 6 files need updating, not just 1. Next time, the initial implementation will be complete.

## Important Notes

- Always read before writing - understand existing code structure
- Follow platform conventions (SwiftUI for iOS, Jetpack Compose for Android)
- Respect the JAVA_HOME requirement for Android builds
- Use LD="clang" for iOS builds to avoid Homebrew linker issues
- Check git status to understand what changed in the working directory
