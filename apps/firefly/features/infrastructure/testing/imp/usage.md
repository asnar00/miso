# Using the Testing Feature
*How to run tests on your phone from your Mac*

## Setup

### 1. Start USB Port Forwarding

The test server runs on port 8081 on your phone. Forward it to your Mac:

```bash
# Start port forwarding (keep running in background)
pymobiledevice3 usbmux forward 8081 8081 &
```

### 2. Launch Your App

Make sure the app is running on your phone:

**iOS**:
```bash
cd apps/firefly/product/client/imp/ios
./install-device.sh  # Build and install
xcrun devicectl device process launch --device <DEVICE_ID> com.miso.noobtest
```

**Android** (future):
```bash
cd apps/firefly/product/client/imp/eos
./install-device.sh  # Build and install
adb shell am start -n com.miso.noobtest/.MainActivity
```

## Running Tests

### Quick Test

From anywhere:
```bash
cd apps/firefly/features/testing/imp
./test-feature.sh ping
```

Output:
```
🧪 Testing feature: ping
✅ Test ping: succeeded
```

Or if it fails:
```
🧪 Testing feature: ping
❌ Test ping: failed because Connection failed: The request timed out
```

### Manual Test

You can also test directly with curl:
```bash
curl http://localhost:8081/test/ping
# Returns: "succeeded" or "failed because XXX"
```

## Adding New Tests

To make a feature testable:

1. **Write test.md** - Document what the test does
   ```markdown
   # myfeature test
   *verify myfeature works correctly*

   Test checks that myfeature does X and returns Y.
   ```

2. **Write platform test code** - In `myfeature/imp/ios/test.md`:
   ```swift
   func testMyFeature() -> TestResult {
       // Test your feature
       if (success) {
           return TestResult(success: true)
       } else {
           return TestResult(success: false, error: "reason")
       }
   }
   ```

3. **Register the test** - In your feature's code:
   ```swift
   TestRegistry.shared.register(feature: "myfeature") {
       return testMyFeature()
   }
   ```

4. **Run it**:
   ```bash
   ./test-feature.sh myfeature
   ```

## Troubleshooting

**"Connection refused"**:
- Check port forwarding is running: `pgrep -f "pymobiledevice3 usbmux forward"`
- Restart forwarding if needed

**"failed to connect to port: 8081"** (in pymobiledevice3 output):
- App isn't running on the phone
- TestServer didn't start (check logs with `Logger.shared`)

**Test returns wrong result**:
- Check test implementation in `feature/imp/ios/test.md`
- Verify test is registered in app startup code
- Use `Logger.shared.info()` in test code to debug
