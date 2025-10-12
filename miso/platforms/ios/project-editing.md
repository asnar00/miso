# project-editing
*adding files to xcode projects without using xcode*

You can add source files to an Xcode project by directly editing the `project.pbxproj` file. This allows command-line workflows without opening Xcode.

## File Structure

The `project.pbxproj` file is an XML-like text file with several key sections:
- `PBXBuildFile` - files to compile
- `PBXFileReference` - file paths and types
- `PBXGroup` - folder organization in project navigator
- `PBXSourcesBuildPhase` - files to include in build

## Adding a Swift File

To add a file like `Logger.swift` to a target:

### 1. Generate UUIDs
```bash
uuidgen  # e.g. A1B2C3D4E5F6...
uuidgen  # e.g. F6E5D4C3B2A1...
```

### 2. Add to PBXBuildFile section
```
/* Begin PBXBuildFile section */
    A1B2C3D4E5F6... /* Logger.swift in Sources */ = {
        isa = PBXBuildFile;
        fileRef = F6E5D4C3B2A1... /* Logger.swift */;
    };
```

### 3. Add to PBXFileReference section
```
/* Begin PBXFileReference section */
    F6E5D4C3B2A1... /* Logger.swift */ = {
        isa = PBXFileReference;
        lastKnownFileType = sourcecode.swift;
        path = Logger.swift;
        sourceTree = "<group>";
    };
```

### 4. Add to PBXGroup section
Find your app's group (usually named after the target) and add to `children`:
```
    XXXX /* MyApp */ = {
        isa = PBXGroup;
        children = (
            YYYY /* AppDelegate.swift */,
            ZZZZ /* ContentView.swift */,
            F6E5D4C3B2A1... /* Logger.swift */,
        );
```

### 5. Add to PBXSourcesBuildPhase section
Find the "Sources" phase and add to `files`:
```
    SSSS /* Sources */ = {
        isa = PBXSourcesBuildPhase;
        buildActionMask = 2147483647;
        files = (
            TTTT /* AppDelegate.swift in Sources */,
            UUUU /* ContentView.swift in Sources */,
            A1B2C3D4E5F6... /* Logger.swift in Sources */,
        );
```

## Tips

- Use consistent UUID generation (uuidgen or python uuid.uuid4())
- Comments like `/* Logger.swift */` are optional but helpful
- Order doesn't matter within sections
- Always backup project.pbxproj before editing
- Test with `xcodebuild build` after changes

## Automation

You can script this with sed/awk or write a Python script to parse and modify the file programmatically.

Example workflow:
```bash
# 1. Create the Swift file
cat > MyApp/Logger.swift << 'EOF'
class Logger {
    static func log(_ msg: String) {
        print(msg)
    }
}
EOF

# 2. Generate UUIDs
BUILD_UUID=$(uuidgen | tr -d '-')
FILE_UUID=$(uuidgen | tr -d '-')

# 3. Edit project.pbxproj with sed commands
# (See full implementation in add-file-to-xcode.sh script)

# 4. Verify build still works
xcodebuild -project MyApp.xcodeproj -scheme MyApp build
```

This technique was successfully used to add Logger.swift to the NoobTest project without opening Xcode.
