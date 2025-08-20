# xcodebuild-issues
*common problems when building from command line vs Xcode IDE*

The `xcodebuild` command line tool and Xcode IDE use the same underlying build system, but can behave differently in practice.

## Linker conflicts
If you have Homebrew development tools installed (like `lld` from the `binutils` package), `xcodebuild` may try to use the wrong linker, causing errors like:
```
ld.lld: error: unknown argument '-Xlinker'
ld.lld: error: unknown argument '-dynamiclib'
```

## Solutions
1. **Use AppleScript to invoke Xcode IDE directly**:
   ```bash
   osascript -e 'tell application "Xcode" to build active workspace document'
   ```
   This bypasses environment issues entirely.

The AppleScript approach is most reliable since it uses exactly the same build process as clicking "Build" in Xcode IDE.