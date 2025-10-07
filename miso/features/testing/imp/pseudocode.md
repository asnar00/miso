# testing - Implementation Overview
*General workflow and structure for the testing framework*

## Test Structure

For feature `A/B/C`:

```
A/B/C/
├── A/B/C.md              # Feature specification
└── imp/
    ├── tests.md          # Test descriptions (what to test)
    ├── tests-ios.md      # iOS XCTest implementation
    ├── tests-py.md       # Python pytest implementation
    └── tests-eos.md      # Android JUnit implementation
```

### tests.md Format

Natural language test specifications:

```markdown
## Test Cases

### 1. Test Name
**Description**: What this tests

**Steps**:
1. Setup step
2. Action step
3. Verification step

**Expected Result**: What should happen
```

### Platform Test Files

Actual test code in platform-specific format:
- `tests-ios.md`: Swift XCTest functions
- `tests-py.md`: Python pytest functions
- `tests-eos.md`: Kotlin JUnit tests

## Product Integration

Tests are generated into product test suites:

**iOS**: `apps/product/client/imp/ios/ProductTests/FeatureTests.swift`
**Python**: `apps/product/server/imp/py/tests/test_features.py`
**Android**: `apps/product/client/imp/eos/app/src/test/FeatureTests.kt`

Each test function is named `test_featureName_scenario()` and contains code from the corresponding feature test file.

## Running Tests

### Development Loop (Single Feature)

```bash
./test-feature.sh featureName
```

Runs only tests for the specified feature, providing fast feedback during development.

### Pre-Ship Validation (All Features)

```bash
./test-all.sh
```

Runs all tests to ensure nothing is broken before shipping.

## Test Results

Tests output to:
1. **Console**: Real-time progress and results
2. **Log file**: `test-results.log` in the product directory

Example output:
```
======================================
Testing feature: ping
Time: Tue Oct  7 12:16:36 BST 2025
======================================
✓ test_ping_serverResponds PASSED
✓ test_ping_detectsServerRunning PASSED
✓ test_ping_detectsServerDown PASSED
======================================
✅ Feature 'ping' tests passed!
```

## Workflow

### 1. Write Feature Spec
Create `A/B/C.md` with natural language description

### 2. Specify Tests
Create `A/B/C/imp/tests.md` describing what to test

### 3. Implement Platform Tests
For each platform, create test code in `tests-platform.md`

### 4. Generate Product Tests
Code from feature test files is compiled into product test suites

### 5. Development Loop
```bash
./test-feature.sh myfeature  # Iterate until passing
```

### 6. Pre-Ship Validation
```bash
./test-all.sh  # All tests must pass
```

## Example: ping Feature

**Spec**: `apps/firefly/features/ping.md`
- Client pings server periodically
- Background color shows connection status

**Tests**: `apps/firefly/features/ping/imp/tests.md`
1. Server responds to ping endpoint
2. Client detects server running
3. Client detects server down

**Platform Tests**:
- `tests-ios.md` - Three XCTest functions using URLSession
- `tests-py.md` - Three pytest functions using requests

**Generated Files**:
- `apps/firefly/product/client/imp/ios/NoobTestTests/FeatureTests.swift`
- `apps/firefly/product/server/imp/py/tests/test_features.py`

**Running**:
```bash
./test-feature.sh ping
✅ 3 tests passed in 0.18s
```

## Test Script Implementation

### test-feature.sh

Runs tests for a single feature:
1. Accepts feature name as argument
2. Checks for test infrastructure
3. Runs only tests matching `test_featureName_*`
4. Outputs results to console and log file
5. Returns exit code (0=pass, non-zero=fail)

### test-all.sh

Runs all tests:
1. Checks for test infrastructure
2. Runs complete test suite
3. Outputs results to console and log file
4. Returns exit code (0=pass, non-zero=fail)

Both scripts:
- Use platform-specific test runners
- Save timestamped results to `test-results.log`
- Display clear pass/fail status
- Handle missing dependencies gracefully

## Platform-Specific Details

See platform-specific implementation files for details:
- `ios.md` - iOS/Swift/XCTest details
- `py.md` - Python/pytest details
- `eos.md` - Android/Kotlin/JUnit details
