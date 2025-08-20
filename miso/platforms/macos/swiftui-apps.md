# swiftui-apps
*building and running SwiftUI applications on macOS*

SwiftUI apps on macOS follow standard Xcode patterns but have some specific behaviors.

## Project structure
- Main app file: `AppName/AppNameApp.swift` with `@main` attribute
- Content views: Separate `.swift` files for UI components
- Resources: Assets, entitlements, etc.

## Window behavior
SwiftUI apps don't automatically come to foreground when launched from command line. Use `open` command instead of direct executable:

**Correct**: `open "/path/to/App.app"`
**Problematic**: `"/path/to/App.app/Contents/MacOS/App"`

## Build artifacts
Xcode places built apps in:
`~/Library/Developer/Xcode/DerivedData/[project-hash]/Build/Products/Debug/App.app`

The project hash is unique per project location, so use `find` to locate:
```bash
find ~/Library/Developer/Xcode/DerivedData -name "App.app" -type d
```