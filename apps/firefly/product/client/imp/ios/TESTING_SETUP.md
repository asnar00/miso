# iOS Testing Setup

## One-Time Setup: Add Test Target to Xcode

The test files have been created in `NoobTestTests/FeatureTests.swift`. To enable testing, you need to add a test target to the Xcode project **once**:

### Steps:

1. Open `NoobTest.xcodeproj` in Xcode
2. Select the project in the navigator (top-level "NoobTest")
3. Click the `+` button at the bottom of the targets list
4. Choose "Unit Testing Bundle" template
5. Name it `NoobTestTests`
6. Set "Target to be Tested" to `NoobTest`
7. Click Finish

8. In the project navigator, find the newly created `NoobTestTests` folder
9. Delete the default test file Xcode created
10. Right-click the `NoobTestTests` folder → "Add Files to NoobTest..."
11. Navigate to and select `NoobTestTests/FeatureTests.swift`
12. Ensure "NoobTestTests" target is checked
13. Click Add

14. Select the `NoobTestTests` target
15. Go to "Build Settings"
16. Search for "Other Linker Flags"
17. Ensure it includes `-ObjC` if needed

### Verify Setup:

Build the test target:
```bash
xcodebuild -project NoobTest.xcodeproj \
    -scheme NoobTest \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
    -enableCodeCoverage YES \
    LD="clang" \
    build-for-testing
```

## After Setup

Once the test target is configured, use the provided scripts:

- `./test-feature.sh ping` - Test specific feature
- `./test-all.sh` - Run all tests

Results are saved to `test-results.log`
