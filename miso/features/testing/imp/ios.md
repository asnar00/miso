# testing - iOS Implementation
*iOS/Swift/XCTest testing details*

## Overview

iOS tests use XCTest framework and run on iOS Simulator via xcodebuild.

## Setup Requirements

**One-time setup**: Add test target to Xcode project

1. Open project in Xcode
2. Select project in navigator
3. Click `+` at bottom of targets list
4. Choose "Unit Testing Bundle"
5. Name it `ProductNameTests` (e.g., `NoobTestTests`)
6. Set "Target to be Tested" to your app target
7. Add `FeatureTests.swift` to the test target

See product's `TESTING_SETUP.md` for detailed instructions.

## Test File Structure

**Product test file**: `apps/product/client/imp/ios/ProductTests/FeatureTests.swift`

```swift
import XCTest

class FeatureTests: XCTestCase {

    // Feature: ping
    func test_ping_serverResponds() {
        // Generated from features/ping/imp/tests-ios.md
    }

    func test_ping_detectsServerRunning() {
        // Generated from features/ping/imp/tests-ios.md
    }

    // ... more tests
}
```

## Test Code Format

Feature tests in `features/name/imp/tests-ios.md`:

```swift
func test_featureName_scenario() {
    let expectation = XCTestExpectation(description: "Test description")

    // Test code using URLSession, XCTAssert, etc.

    expectation.fulfill()
    wait(for: [expectation], timeout: 5.0)
}
```

## Running Tests

### Single Feature

```bash
cd apps/product/client/imp/ios
./test-feature.sh featureName
```

Executes:
```bash
xcodebuild test \
    -project Product.xcodeproj \
    -scheme Product \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
    -only-testing:ProductTests/FeatureTests/test_featureName_* \
    LD="clang"
```

### All Tests

```bash
cd apps/product/client/imp/ios
./test-all.sh
```

Executes:
```bash
xcodebuild test \
    -project Product.xcodeproj \
    -scheme Product \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
    -enableCodeCoverage YES \
    LD="clang"
```

## Key Details

**Test Runner**: xcodebuild
**Test Framework**: XCTest
**Execution Environment**: iOS Simulator
**Async Handling**: XCTestExpectation with wait(for:timeout:)
**Assertions**: XCTAssert family (XCTAssertEqual, XCTAssertTrue, etc.)

**Critical**: Always include `LD="clang"` to avoid Homebrew linker conflicts

## Test Results

Results are:
- Streamed to console in real-time
- Saved to `test-results.log`
- Include pass/fail status for each test
- Show execution time

## Dependencies

- Xcode and command-line tools
- iOS Simulator
- Test target configured in Xcode project

## Example: ping Feature

From `apps/firefly/features/ping/imp/tests-ios.md`:

```swift
func test_ping_serverResponds() {
    let serverURL = "http://192.168.1.76:8080"
    let expectation = XCTestExpectation(description: "Server responds to ping")

    guard let url = URL(string: "\(serverURL)/api/ping") else {
        XCTFail("Invalid URL")
        return
    }

    URLSession.shared.dataTask(with: url) { data, response, error in
        XCTAssertNil(error, "Request should not error")

        if let httpResponse = response as? HTTPURLResponse {
            XCTAssertEqual(httpResponse.statusCode, 200, "Should return 200 OK")
        }

        expectation.fulfill()
    }.resume()

    wait(for: [expectation], timeout: 5.0)
}
```

Generated into: `apps/firefly/product/client/imp/ios/NoobTestTests/FeatureTests.swift`

Run with: `./test-feature.sh ping`
