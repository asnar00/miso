# test-driven porting
*define tests first, then implement to match*

When porting features from one platform to another, we use a test-driven approach: write a `test.md` file that defines exactly what to test, then implement until the tests pass.

## The test.md File

Each feature can have a `test.md` file that specifies:

1. **UI Elements to Register** - Buttons, fields, and other UI elements that need automation IDs
2. **Logging Points** - Specific log messages emitted at key moments
3. **Test Sequences** - Step-by-step scenarios with expected log output

## Why This Works

- **Exact expectations**: Logs provide deterministic verification without flaky screenshot comparisons
- **Remote automation**: Tests run via HTTP to the device's test server
- **Quick iteration**: Restart app to reset state, run test sequence, check logs
- **Cross-platform parity**: Same test.md works for iOS and Android

## Test Sequence Format

```
### test-name
*brief description*

1. restart app
2. expect "[Component] Log message"
3. tap element-id
4. expect "[Component] Another log message"
```

## Log Message Guidelines

- Use `[ComponentName]` prefix for filtering
- Make messages readable but distinct
- Include relevant data (e.g., "Explorer changed to: search")
- Logger automatically adds `[APP]` prefix

## Running Tests

1. Forward port: `adb forward tcp:8081 tcp:8081`
2. List elements: `curl http://localhost:8081/test/list-elements`
3. Tap element: `curl -X POST "http://localhost:8081/test/tap?id=element-id"`
4. Check logs: `adb logcat -d | grep "[APP]"`

## Example test.md

See `apps/firefly/features/posts/toolbar/test.md` for a complete example.
