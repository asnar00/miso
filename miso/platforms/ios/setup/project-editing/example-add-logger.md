# Example: Adding Logger.swift to NoobTest

This shows the actual process used to add Logger.swift to the NoobTest project without Xcode.

## 1. Create the Swift File

First, create the file in the project directory:

```bash
cat > NoobTest/Logger.swift << 'EOF'
import Foundation
import UIKit

class Logger {
    static let shared = Logger()

    static func log(_ message: String) {
        shared.logMessage(message)
    }

    private func logMessage(_ message: String) {
        let timestamp = Date().timeIntervalSince1970
        let formattedTime = ISO8601DateFormatter().string(from: Date())
        print("\(formattedTime) | \(message)")
    }
}
EOF
```

## 2. Generate UUIDs

```bash
BUILD_UUID=$(uuidgen | tr -d '-' | tr '[:upper:]' '[:lower:]')
FILE_UUID=$(uuidgen | tr -d '-' | tr '[:upper:]' '[:lower:]')

echo "Build UUID: $BUILD_UUID"
echo "File UUID: $FILE_UUID"
```

## 3. Edit project.pbxproj

Open `NoobTest.xcodeproj/project.pbxproj` in a text editor.

### Add to PBXBuildFile section

After `/* Begin PBXBuildFile section */`:

```
        A1B2C3D4E5F678901234567890ABCDEF /* Logger.swift in Sources */ = {
            isa = PBXBuildFile;
            fileRef = FEDCBA0987654321FEDCBA0987654321 /* Logger.swift */;
        };
```

### Add to PBXFileReference section

After `/* Begin PBXFileReference section */`:

```
        FEDCBA0987654321FEDCBA0987654321 /* Logger.swift */ = {
            isa = PBXFileReference;
            lastKnownFileType = sourcecode.swift;
            path = Logger.swift;
            sourceTree = "<group>";
        };
```

### Add to PBXGroup section

Find the NoobTest group (look for `/* NoobTest */ = {`) and add to children array:

```
        XXXXXXXX /* NoobTest */ = {
            isa = PBXGroup;
            children = (
                YYYYYYYY /* NoobTestApp.swift */,
                ZZZZZZZZ /* ContentView.swift */,
                WWWWWWWW /* TestServer.swift */,
                FEDCBA0987654321FEDCBA0987654321 /* Logger.swift */,
                ...
            );
```

### Add to PBXSourcesBuildPhase section

Find the Sources build phase and add to files array:

```
        SSSSSSSS /* Sources */ = {
            isa = PBXSourcesBuildPhase;
            buildActionMask = 2147483647;
            files = (
                TTTTTTTT /* NoobTestApp.swift in Sources */,
                UUUUUUUU /* ContentView.swift in Sources */,
                VVVVVVVV /* TestServer.swift in Sources */,
                A1B2C3D4E5F678901234567890ABCDEF /* Logger.swift in Sources */,
            );
```

## 4. Verify the Build

```bash
xcodebuild -project NoobTest.xcodeproj \
    -scheme NoobTest \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
    LD="clang" \
    build
```

If successful, the file is now part of the project!

## 5. Use the New Code

In any Swift file, you can now call:

```swift
Logger.log("🚀 App starting")
```

## Notes

- The UUIDs must be unique within the project
- The file must physically exist at the path specified
- Comments like `/* Logger.swift */` are helpful but optional
- Always test the build after editing

This technique was successfully used in the Firefly iOS client to add logging functionality without opening Xcode.
