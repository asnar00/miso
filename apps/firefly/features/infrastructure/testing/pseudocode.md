# testing implementation
*platform-agnostic remote testing infrastructure*

## Overview

Enables automated feature testing by running test commands from a development machine and executing them on the actual device. Tests run in the real app environment, catching issues that simulators might miss.

## Architecture

The testing system has three main components:

### 1. TestServer

HTTP server running on the device that handles test requests.

**Properties:**
- `port`: Integer - listening port (8081)
- `isRunning`: Boolean - server state

**Methods:**
- `start() → void`: Start listening for test requests
- `stop() → void`: Stop the server
- `handleRequest(feature) → String`: Execute test and return result

**Endpoints:**
- `GET /test/<feature-name>`: Run test for specified feature

**Response format:**
- Success: "succeeded"
- Failure: "failed because <error message>"

### 2. TestRegistry

Registry mapping feature names to test functions.

**Properties:**
- `tests`: Dictionary<String, TestFunction> - feature name to test function mapping

**Methods:**
- `register(featureName, testFunction) → void`: Register a test for a feature
- `run(featureName) → TestResult`: Execute test and return result
- `isRegistered(featureName) → Boolean`: Check if test exists

**Hierarchical testing:**
- Can test entire feature trees
- "firefly" tests all sub-features
- "firefly/users" tests users and all child features

### 3. TestResult

Structure representing test outcome.

**Properties:**
- `success`: Boolean - whether test passed
- `error`: String (optional) - error message if test failed

**Constructors:**
- `TestResult(success: true)`: Passing test
- `TestResult(success: false, error: "reason")`: Failing test with explanation

## Test Lifecycle

**App startup:**
1. Initialize TestServer singleton
2. Start server on port 8081
3. Each feature registers its test function with TestRegistry

**When test command received:**
1. TestServer receives GET `/test/<feature-name>`
2. Extract feature name from URL
3. Look up test in TestRegistry
4. Execute test function
5. Get TestResult
6. Format response string
7. Return response to caller

**Test execution:**
1. Test function is called
2. Test performs feature-specific checks
3. Test returns TestResult with success/failure

## Writing Tests

Each feature should register a test function:

```
TestRegistry.register("feature-name", testFunction)
```

Test function signature:
```
testFunction() → TestResult
```

Example test patterns:

**Simple check:**
```
function testPing() {
    if (canConnectToServer()) {
        return TestResult(success: true)
    } else {
        return TestResult(success: false, error: "Cannot connect to server")
    }
}
```

**Multi-step test:**
```
function testSignIn() {
    // Step 1
    if (!canSendEmail()) {
        return TestResult(success: false, error: "Email send failed")
    }

    // Step 2
    if (!canVerifyCode()) {
        return TestResult(success: false, error: "Code verification failed")
    }

    return TestResult(success: true)
}
```

## Communication

**Setup:**
- Device must be connected via USB
- Port 8081 on device must be forwarded to port 8081 on Mac
- Forwarding typically done with platform-specific tools (pymobiledevice3, adb)

**Test command:**
```
curl http://localhost:8081/test/<feature-name>
```

**Response:**
- "succeeded" - test passed
- "failed because XXX" - test failed with reason

## Integration Points

**App initialization:**
- Start TestServer as early as possible in app lifecycle
- Before any features need testing

**Feature registration:**
- Each feature registers test in initialization or onAppear
- Registration happens once, usually in app startup sequence

**Testing from Mac:**
- Use curl or dedicated test script
- Scripts can test multiple features sequentially
- Results can be logged or displayed

## Error Handling

**Server failures:**
- Port already in use
- Network permission denied
- Server crash during test

**Test failures:**
- Test function throws exception
- Feature not registered
- Test timeout

**Network failures:**
- Connection lost during test
- Response not received
- Malformed request

## Thread Safety

- TestRegistry uses thread-safe dictionary
- Test execution may need synchronization if tests modify shared state
- Server handles one request at a time (serial processing recommended)

## Performance

- Tests should complete quickly (< 2 seconds typical)
- Long-running tests should have timeout
- Server should not block app UI
- Test execution happens on background thread
