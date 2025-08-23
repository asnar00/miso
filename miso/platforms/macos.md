# macos
*native apple applications*

Use template projects created by xcode instead of constructing from scratch. Ask the user to build a project if you don't have one.

Use OSA commands to xcode to build or stop an application, rather than building from the command line.

Use OSAscript messages to apps to control them.

Use self-built logging to files rather than system logs.

## clone template

**Automated approach (recommended):**
Use the clone script to create a new macOS tool:
```bash
cd platforms/~macos
python3 clone-template.py TOOLNAME
```

This script automatically handles:
- creating directory structure: `tools/~TOOLNAME/code/macos/`
- copying template files
- renaming all directories and files appropriately
- updating project.pbxproj references
- updating Swift source code struct names and comments

**Manual approach (for reference):**
- copy entire template directory: `cp -r platforms/~macos/template/* tools/~TOOLNAME/code/macos/`
- rename project files: `mv template.xcodeproj TOOLNAME.xcodeproj && mv template TOOLNAME`  
- rename Swift files: `mv templateApp.swift TOOLNAMEApp.swift && mv template.entitlements TOOLNAME.entitlements`
- update project references: replace all "template" with "TOOLNAME" in `TOOLNAME.xcodeproj/project.pbxproj`
- update Swift code: change struct names from `templateApp` to `TOOLNAMEApp`

## monitor builds

Use the `build-and-check` script to verify builds succeed:

- runs build command via OSA  
- waits for completion
- checks if target app is running
- reports success or failure
- attempts to extract error info from recent build logs if failed

Build logs are stored in `~/Library/Developer/Xcode/DerivedData/TOOLNAME-*/Logs/Build/*.xcactivitylog` (binary format).