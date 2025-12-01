# testing implementation (iOS)
*test infrastructure for iOS client*

## Overview

The testing feature runs on an HTTP server listening on port 8081. It receives test commands, executes tests, and returns results.

## Components

**TestServer** - HTTP server that handles test requests
- Listens on port 8081
- Accepts GET `/test/<feature-name>` requests
- Returns JSON with success/failure result

**TestRegistry** - Maps feature names to test functions
- Stores dictionary of feature name → test function
- Features register themselves at startup
- Supports hierarchical lookup (e.g., "firefly" tests all sub-features)

**Test protocol** - What test functions must do
- Test functions return `TestResult` with success boolean and optional error message
- Format: `TestResult(success: true)` or `TestResult(success: false, error: "reason")`

## Pseudocode

```swift
struct TestResult {
    let success: Bool
    let error: String?
}

class TestRegistry {
    static let shared = TestRegistry()
    private var tests: [String: () -> TestResult] = [:]

    func register(feature: String, test: @escaping () -> TestResult)
    func run(feature: String) -> TestResult
}

class TestServer {
    func start(port: 8081)
    func handleTestRequest(feature: String) -> String {
        let result = TestRegistry.shared.run(feature)
        return result.success ? "succeeded" : "failed because \(result.error)"
    }
}
```

## Initialization

In app startup:
```swift
TestServer.shared.start()
```

Each feature registers its test:
```swift
TestRegistry.shared.register(feature: "ping") {
    // run ping test
    return TestResult(...)
}
```
