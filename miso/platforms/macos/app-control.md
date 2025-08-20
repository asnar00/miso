# app-control
*starting and stopping macOS applications built with Xcode*

When Xcode builds a SwiftUI app, the executable is located at:
`~/Library/Developer/Xcode/DerivedData/[project-name-hash]/Build/Products/Debug/[appname].app/Contents/MacOS/[appname]`

## Rebuilding an app
Use AppleScript to tell Xcode IDE to rebuild:
```bash
osascript -e 'tell application "Xcode" to build active workspace document'
```

## Starting an app
**Preferred method** (brings app to front automatically):
```bash
open "/path/to/app.app"
```

**Alternative method** (runs executable directly):
```bash
"/path/to/app.app/Contents/MacOS/appname"
```

## Stopping an app
Kill the process by name:
```bash
pkill -f appname
```

The DerivedData path includes a hash that's unique per project and location, so you may need to search:
```bash
find ~/Library/Developer/Xcode/DerivedData -name "appname.app" -type d
```