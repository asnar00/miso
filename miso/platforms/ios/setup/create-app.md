# create-app
*creating an iOS application from scratch using command-line tools*

Creating an iOS app from the command line requires setting up an Xcode project structure with several key files.

## Required Files

An iOS SwiftUI app needs:
- **Project file** (`.xcodeproj/project.pbxproj`) - Xcode's project definition in a specific XML format
- **Swift source files** - App entry point and views
- **Info.plist** - App metadata and configuration
- **Assets.xcassets** - Icon and asset catalog

## Key Challenges

1. **Project file format** - The `.pbxproj` file uses a proprietary format with unique IDs. A template is easier than generating from scratch.
2. **Bundle identifier** - Must be unique (e.g., `com.yourname.appname`)
3. **Team ID** - Required for code signing (found via `security find-certificate`)
4. **Minimum iOS version** - Set to iOS 17.0 for modern features

## Project Structure

```
YourApp/
├── YourApp.xcodeproj/
│   └── project.pbxproj          # Xcode project definition
├── YourApp/
│   ├── YourAppApp.swift         # @main entry point
│   ├── ContentView.swift        # Main view
│   ├── Info.plist               # App metadata
│   └── Assets.xcassets/         # Icons and assets
│       ├── Contents.json
│       └── AppIcon.appiconset/
│           ├── Contents.json
│           └── icon.png         # 1024x1024 icon
└── ExportOptions.plist          # For TestFlight export
```

## Implementation

See `create-app/imp/` for:
- Template `project.pbxproj` file with placeholders
- Script to generate new project from template
- Example source files